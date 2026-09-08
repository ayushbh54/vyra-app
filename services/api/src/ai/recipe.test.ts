/**
 * AI recipe pipeline tests.
 *
 * These run with a FAKE transport, so the whole Gemini integration — prompting,
 * schema, retry, diet enforcement, failure handling — is proven without an API
 * key and without a network. That matters twice over: CI has no key, and a demo
 * should never be the first time this code path executes.
 */
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

import { GeminiClient, extractInteractionText, type GeminiTransport } from './gemini';
import { generateRecipe, RecipeGenerationError } from './recipe';

// ---------------------------------------------------------------------------
// Fake transport
// ---------------------------------------------------------------------------

const CONFIG = {
  apiKey: 'test-key',
  textModel: 'gemini-3.7-flash',
  visionModel: 'gemini-3.6-flash',
  maxOutputTokens: 2048,
  timeoutMs: 5000,
  maxRetries: 0,
  baseUrl: 'https://example.invalid/v1beta',
};

/**
 * Builds a realistic Interactions API response.
 *
 * The leading `thought` step is not padding — a real response usually starts
 * with one, and it carries NO `content` array. Any parser that reads steps[0]
 * crashes on it, so every fixture here includes it deliberately.
 */
function geminiReply(payload: unknown): Response {
  return new Response(
    JSON.stringify({
      id: 'v1_test',
      status: 'completed',
      object: 'interaction',
      model: 'gemini-3.7-flash',
      steps: [
        { type: 'thought', signature: 'EvEFCu4FAQw' },
        { type: 'model_output', content: [{ type: 'text', text: JSON.stringify(payload) }] },
      ],
    }),
    { status: 200, headers: { 'content-type': 'application/json' } },
  );
}

/** Returns each queued payload in order, recording the prompts it was sent. */
function scriptedTransport(payloads: unknown[]) {
  const prompts: string[] = [];
  let call = 0;
  const transport: GeminiTransport = async (_url, init) => {
    const body = JSON.parse(String(init.body));
    // `input`, not `contents` — the Interactions API request shape.
    prompts.push(body.input);
    const payload = payloads[Math.min(call, payloads.length - 1)];
    call++;
    return geminiReply(payload);
  };
  return { transport, prompts, calls: () => call };
}

const VEG_RECIPE = {
  title: 'Palak Paneer',
  ingredients: [
    { name: 'spinach', quantity: '250 g' },
    { name: 'paneer', quantity: '150 g' },
  ],
  steps: ['Blanch the spinach.', 'Blend to a puree.', 'Add paneer and simmer.'],
  cookTimeMin: 25,
  regionTag: 'North Indian',
  nutrition: { calories: 320, proteinG: 18, fatG: 20, carbsG: 14, fiberG: 4, sugarG: 3 },
};

const EGG_RECIPE = {
  ...VEG_RECIPE,
  title: 'Paneer Bhurji with Egg',
  ingredients: [...VEG_RECIPE.ingredients, { name: 'egg', quantity: '2' }],
};

const SNEAKY_STOCK_RECIPE = {
  ...VEG_RECIPE,
  title: 'Vegetable Pulao',
  steps: ['Fry the spices.', 'Add a chicken stock cube.', 'Simmer the rice.'],
};

// ---------------------------------------------------------------------------
describe('happy path', () => {
  it('generates a compliant recipe on the first attempt', async () => {
    const { transport, calls } = scriptedTransport([VEG_RECIPE]);
    const client = new GeminiClient(CONFIG, transport);

    const result = await generateRecipe(client, {
      ingredients: ['spinach', 'paneer'],
      preference: 'veg_no_egg',
    });

    assert.equal(calls(), 1);
    assert.equal(result.attempts, 1);
    assert.equal(result.dietFilterEnforced, false);
    assert.equal(result.recipe.title, 'Palak Paneer');
    assert.equal(result.recipe.isAiGenerated, true);
  });

  it('always attaches the AI-estimate disclaimer', async () => {
    const { transport } = scriptedTransport([VEG_RECIPE]);
    const result = await generateRecipe(new GeminiClient(CONFIG, transport), {
      ingredients: ['spinach'],
      preference: 'veg_no_egg',
    });
    assert.match(result.disclaimer, /estimate/i);
  });

  it('derives containsEgg/containsMeat from verification, not from the model', async () => {
    const { transport } = scriptedTransport([EGG_RECIPE]);
    const result = await generateRecipe(new GeminiClient(CONFIG, transport), {
      ingredients: ['paneer', 'egg'],
      preference: 'veg_with_egg',
    });
    assert.equal(result.recipe.containsEgg, true);
    assert.equal(result.recipe.containsMeat, false);
  });

  it('states the diet rule in the prompt', async () => {
    const { transport, prompts } = scriptedTransport([VEG_RECIPE]);
    await generateRecipe(new GeminiClient(CONFIG, transport), {
      ingredients: ['spinach'],
      preference: 'veg_no_egg',
    });
    assert.match(prompts[0]!, /STRICTLY VEGETARIAN WITHOUT EGG/);
  });
});

// ---------------------------------------------------------------------------
describe('diet enforcement — the guarantee', () => {
  /**
   * The scenario the whole module exists for: the model ignores the instruction.
   */
  it('rejects an egg recipe for a no-egg user and retries', async () => {
    const { transport, prompts, calls } = scriptedTransport([EGG_RECIPE, VEG_RECIPE]);
    const result = await generateRecipe(new GeminiClient(CONFIG, transport), {
      ingredients: ['paneer', 'spinach'],
      preference: 'veg_no_egg',
    });

    assert.equal(calls(), 2, 'should have retried once');
    assert.equal(result.attempts, 2);
    assert.equal(result.dietFilterEnforced, true);
    assert.equal(result.recipe.containsEgg, false);
  });

  it('tells the model exactly what was wrong on retry', async () => {
    const { transport, prompts } = scriptedTransport([EGG_RECIPE, VEG_RECIPE]);
    await generateRecipe(new GeminiClient(CONFIG, transport), {
      ingredients: ['paneer'],
      preference: 'veg_no_egg',
    });
    assert.match(prompts[1]!, /previous attempt was rejected/);
    assert.match(prompts[1]!, /egg/);
  });

  it('catches meat hidden in a cooking step, not just the ingredient list', async () => {
    const { transport } = scriptedTransport([SNEAKY_STOCK_RECIPE, VEG_RECIPE]);
    const result = await generateRecipe(new GeminiClient(CONFIG, transport), {
      ingredients: ['rice', 'peas'],
      preference: 'veg_no_egg',
    });
    assert.equal(result.dietFilterEnforced, true);
    assert.equal(result.recipe.title, 'Palak Paneer');
  });

  /**
   * If the model will not comply, we fail. We never serve the violating recipe.
   */
  it('fails honestly rather than serving a violating recipe', async () => {
    const { transport, calls } = scriptedTransport([EGG_RECIPE]);   // always non-compliant
    await assert.rejects(
      () =>
        generateRecipe(new GeminiClient(CONFIG, transport), {
          ingredients: ['egg'],
          preference: 'veg_no_egg',
        }),
      (error: unknown) => {
        assert.ok(error instanceof RecipeGenerationError);
        assert.equal(error.reason, 'diet_unsatisfiable');
        assert.match(error.userMessage, /Nothing was saved/);
        return true;
      },
    );
    assert.equal(calls(), 3, 'should stop after the retry budget');
  });

  it('does not restrict a non-vegetarian user', async () => {
    const { transport, calls } = scriptedTransport([
      { ...VEG_RECIPE, title: 'Chicken Curry', ingredients: [{ name: 'chicken', quantity: '500 g' }] },
    ]);
    const result = await generateRecipe(new GeminiClient(CONFIG, transport), {
      ingredients: ['chicken'],
      preference: 'non_veg',
    });
    assert.equal(calls(), 1);
    assert.equal(result.recipe.containsMeat, true);
  });
});

// ---------------------------------------------------------------------------
describe('failure handling', () => {
  it('rejects an empty ingredient list before calling the API', async () => {
    let called = false;
    const transport: GeminiTransport = async () => {
      called = true;
      return geminiReply(VEG_RECIPE);
    };
    await assert.rejects(
      () =>
        generateRecipe(new GeminiClient(CONFIG, transport), {
          ingredients: ['  ', ''],
          preference: 'veg_no_egg',
        }),
      /at least one ingredient/,
    );
    assert.equal(called, false, 'must not waste an API call on invalid input');
  });

  it('surfaces a friendly message when Gemini is rate limited', async () => {
    const transport: GeminiTransport = async () => new Response('{}', { status: 429 });
    await assert.rejects(
      () =>
        generateRecipe(new GeminiClient(CONFIG, transport), {
          ingredients: ['rice'],
          preference: 'non_veg',
        }),
      (error: unknown) => {
        assert.ok(error instanceof RecipeGenerationError);
        assert.equal(error.reason, 'ai_unavailable');
        assert.match(error.userMessage, /wait a minute/i);
        return true;
      },
    );
  });

  it('never leaks internals into a user-facing message', async () => {
    const transport: GeminiTransport = async () => new Response('{}', { status: 500 });
    try {
      await generateRecipe(new GeminiClient(CONFIG, transport), {
        ingredients: ['rice'],
        preference: 'non_veg',
      });
      assert.fail('should have thrown');
    } catch (error) {
      const message = (error as RecipeGenerationError).userMessage;
      assert.doesNotMatch(message, /gemini/i);
      assert.doesNotMatch(message, /500/);
      assert.doesNotMatch(message, /api/i);
    }
  });

  it('handles a markdown-fenced response despite the schema constraint', async () => {
    const transport: GeminiTransport = async () =>
      new Response(
        JSON.stringify({
          status: 'completed',
          steps: [
            { type: 'thought', signature: 'x' },
            {
              type: 'model_output',
              content: [{ type: 'text', text: '```json\n' + JSON.stringify(VEG_RECIPE) + '\n```' }],
            },
          ],
        }),
        { status: 200 },
      );
    const result = await generateRecipe(new GeminiClient(CONFIG, transport), {
      ingredients: ['spinach'],
      preference: 'veg_no_egg',
    });
    assert.equal(result.recipe.title, 'Palak Paneer');
  });

  it('surfaces a clear message when the API key is rejected', async () => {
    const transport: GeminiTransport = async () =>
      new Response(JSON.stringify({ error: { message: 'API key not valid' } }), { status: 400 });
    await assert.rejects(
      () =>
        generateRecipe(new GeminiClient(CONFIG, transport), {
          ingredients: ['rice'],
          preference: 'non_veg',
        }),
      (error: unknown) => {
        assert.ok(error instanceof RecipeGenerationError);
        assert.equal(error.reason, 'ai_unavailable');
        return true;
      },
    );
  });
});

// ---------------------------------------------------------------------------
describe('Interactions response parsing', () => {
  /**
   * The trap this integration is most likely to fall into. A real response
   * begins with a `thought` step that has no `content` array, so any parser
   * that reads steps[0] crashes on a perfectly successful call.
   */
  it('skips the leading thought step instead of crashing on it', () => {
    const text = extractInteractionText({
      status: 'completed',
      steps: [
        { type: 'thought' },
        { type: 'model_output', content: [{ type: 'text', text: 'hello' }] },
      ],
    });
    assert.equal(text, 'hello');
  });

  it('skips tool-call steps and finds the model output after them', () => {
    const text = extractInteractionText({
      steps: [
        { type: 'thought' },
        { type: 'function_call' },
        { type: 'function_result' },
        { type: 'model_output', content: [{ type: 'text', text: 'after tools' }] },
      ],
    });
    assert.equal(text, 'after tools');
  });

  it('joins multiple text chunks in one model output', () => {
    const text = extractInteractionText({
      steps: [
        { type: 'model_output', content: [{ type: 'text', text: 'a' }, { type: 'text', text: 'b' }] },
      ],
    });
    assert.equal(text, 'ab');
  });

  it('ignores non-text content entries', () => {
    const text = extractInteractionText({
      steps: [
        { type: 'model_output', content: [{ type: 'image' }, { type: 'text', text: 'only this' }] },
      ],
    });
    assert.equal(text, 'only this');
  });

  it('returns empty rather than throwing when there is no model output', () => {
    assert.equal(extractInteractionText({ steps: [{ type: 'thought' }] }), '');
    assert.equal(extractInteractionText({}), '');
  });
});
