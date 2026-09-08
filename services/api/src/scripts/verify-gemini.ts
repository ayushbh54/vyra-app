/**
 * One command to find out whether your Gemini key actually works.
 *
 *   pnpm --filter @vyra/api verify:gemini
 *
 * This exists because "AI is integrated" is not the same as "AI works on your
 * machine". A revoked key, a renamed model, or a corporate proxy all produce a
 * failure at the worst possible moment — the first live demo. This makes that
 * failure happen now, on your terms, with a message that says what to fix.
 *
 * It never prints the key, not even partially.
 */

import { GeminiError, loadGeminiConfig, GeminiClient } from '../ai/gemini';
import { generateRecipe, RecipeGenerationError } from '../ai/recipe';

const ok = (msg: string) => console.log(`  \x1b[32m✓\x1b[0m ${msg}`);
const bad = (msg: string) => console.log(`  \x1b[31m✗\x1b[0m ${msg}`);
const info = (msg: string) => console.log(`    ${msg}`);

async function main(): Promise<void> {
  console.log('\n  VYRA — Gemini connection check\n');

  // 1. Is a key present at all?
  let config;
  try {
    config = loadGeminiConfig();
  } catch {
    bad('GEMINI_API_KEY is not set');
    info('Add it to .env:  GEMINI_API_KEY=your_key_here');
    info('Get a key at:    https://aistudio.google.com/apikey');
    info('');
    info('VYRA still runs without this. Only recipe generation and food');
    info('scanning are affected — everything else works.');
    process.exit(1);
  }

  ok(`Key found (${config.apiKey.length} characters)`);
  info(`Text model:   ${config.textModel}`);
  info(`Vision model: ${config.visionModel}`);
  info(`Endpoint:     ${config.baseUrl}/interactions`);
  console.log('');

  // 2. Does a real call succeed?
  const client = new GeminiClient(config);
  try {
    const reply = await client.generateText({
      prompt: 'Reply with exactly the word: connected',
      temperature: 0,
    });
    ok(`Gemini responded: "${reply.slice(0, 60)}"`);
  } catch (error) {
    if (error instanceof GeminiError) {
      bad(`Gemini call failed — ${error.kind}`);
      info(error.message);
      if (error.kind === 'invalid_key') {
        info('');
        info('The key was rejected. Common causes:');
        info('  · the key was revoked or regenerated in AI Studio');
        info('  · the key belongs to a project without the Gemini API enabled');
        info('  · an extra space or newline was pasted into .env');
      }
      if (error.kind === 'upstream_error' && error.status === 404) {
        info('');
        info(`404 usually means the model name is wrong: ${config.textModel}`);
        info('Check https://ai.google.dev/gemini-api/docs/models');
      }
    } else {
      bad((error as Error).message);
    }
    process.exit(1);
  }

  // 3. Does the part VYRA actually depends on work — schema-constrained JSON,
  //    with the diet filter enforced on top?
  console.log('');
  try {
    const result = await generateRecipe(client, {
      ingredients: ['palak', 'paneer', 'rice'],
      preference: 'veg_no_egg',
    });
    ok(`Recipe generated: "${result.recipe.title}"`);
    info(`${result.recipe.ingredients.length} ingredients, ${result.recipe.steps.length} steps`);
    info(`Diet filter: ${result.dietFilterEnforced ? 'caught and corrected a violation' : 'passed first time'}`);
    info(`Contains egg: ${result.recipe.containsEgg} · contains meat: ${result.recipe.containsMeat}`);

    if (result.recipe.containsEgg || result.recipe.containsMeat) {
      bad('A vegetarian request returned egg or meat — the diet guard has a hole.');
      process.exit(1);
    }
  } catch (error) {
    if (error instanceof RecipeGenerationError) {
      bad(`Recipe generation failed — ${error.reason}`);
      info(error.userMessage);
    } else {
      bad((error as Error).message);
    }
    process.exit(1);
  }

  console.log('\n  \x1b[32mGemini is working.\x1b[0m Nothing else to configure.\n');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
