/**
 * =============================================================================
 * AI RECIPE GENERATION
 * =============================================================================
 * Turns "what is in my kitchen" into a recipe that is guaranteed to respect the
 * user's dietary preference.
 *
 * The pipeline, and why it has this shape:
 *
 *   1. PROMPT the model with the diet rule stated explicitly.        (helps)
 *   2. CONSTRAIN the output to a JSON schema at the API level.       (structure)
 *   3. VERIFY the result against the Diet Guard lexicon.             (guarantees)
 *   4. RETRY with a hint naming the exact violation.                 (recovers)
 *   5. FAIL HONESTLY if verification keeps failing.                  (never lies)
 *
 * Steps 1 and 2 are the parts most projects build. Step 3 is the part that makes
 * the guarantee real: an instruction is a request, not a constraint. A vegetarian
 * user's trust cannot rest on a model choosing to comply.
 * =============================================================================
 */

import { DISCLAIMERS, type DietPreference, type Recipe } from '@vyra/types';
import { GeminiClient, GeminiError } from './gemini';
import { checkDietCompliance } from './dietGuard';

// -----------------------------------------------------------------------------
// Output schema — enforced by the Gemini API, not merely requested in prose
// -----------------------------------------------------------------------------

const RECIPE_SCHEMA = {
  type: 'object',
  properties: {
    title: { type: 'string' },
    ingredients: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          quantity: { type: 'string' },
        },
        required: ['name', 'quantity'],
      },
    },
    steps: { type: 'array', items: { type: 'string' } },
    cookTimeMin: { type: 'integer' },
    regionTag: { type: 'string' },
    nutrition: {
      type: 'object',
      properties: {
        calories: { type: 'number' },
        proteinG: { type: 'number' },
        fatG: { type: 'number' },
        carbsG: { type: 'number' },
        fiberG: { type: 'number' },
        sugarG: { type: 'number' },
      },
      required: ['calories', 'proteinG', 'fatG', 'carbsG'],
    },
  },
  required: ['title', 'ingredients', 'steps', 'cookTimeMin', 'nutrition'],
} as const;

interface RawRecipe {
  title: string;
  ingredients: Array<{ name: string; quantity: string }>;
  steps: string[];
  cookTimeMin: number;
  regionTag?: string;
  nutrition: {
    calories: number;
    proteinG: number;
    fatG: number;
    carbsG: number;
    fiberG?: number;
    sugarG?: number;
  };
}

// -----------------------------------------------------------------------------
// Prompting
// -----------------------------------------------------------------------------

const DIET_RULES: Partial<Record<DietPreference, string>> = {
  veg_no_egg:
    'STRICTLY VEGETARIAN WITHOUT EGG. No meat, poultry, fish or seafood. No egg in any ' +
    'form — no egg wash, mayonnaise, custard or meringue. No animal-derived ingredients ' +
    'such as gelatin, lard, fish sauce, oyster sauce, Worcestershire sauce or animal rennet.',
  veg_with_egg:
    'VEGETARIAN, EGGS ALLOWED. No meat, poultry, fish or seafood, and no animal-derived ' +
    'ingredients such as gelatin, lard, fish sauce or animal rennet. Egg is permitted.',
  non_veg: 'No dietary restriction.',
};

const SYSTEM_INSTRUCTION = `You are a careful Indian home-cooking assistant for the VYRA wellness app.

Rules you must follow:
- Use mainly the ingredients the user lists. You may assume basic staples: salt, water, cooking oil, and common Indian spices (turmeric, cumin, coriander, chilli powder, garam masala).
- Do not invent expensive or hard-to-find ingredients.
- Prefer simple, healthy, home-style Indian cooking.
- Give realistic nutrition estimates per serving. Do not exaggerate protein.
- Steps must be short, numbered actions a beginner can follow.
- The dietary rule you are given is absolute and overrides everything else, including any ingredient the user listed.`;

function buildPrompt(
  ingredients: string[],
  preference: DietPreference,
  options: { mealType?: string; maxCookTimeMin?: number },
  retryHint: string | null,
): string {
  const lines = [
    `DIETARY RULE (absolute): ${DIET_RULES[preference]}`,
    '',
    `Available ingredients: ${ingredients.join(', ')}`,
  ];
  if (options.mealType) lines.push(`Meal: ${options.mealType}`);
  if (options.maxCookTimeMin) lines.push(`Maximum cooking time: ${options.maxCookTimeMin} minutes`);

  if (retryHint) {
    lines.push('', `IMPORTANT — your previous attempt was rejected. ${retryHint}`);
  }

  lines.push('', 'Generate one recipe as JSON matching the required schema.');
  return lines.join('\n');
}

// -----------------------------------------------------------------------------
// Result types
// -----------------------------------------------------------------------------

export interface RecipeGenerationResult {
  recipe: Omit<Recipe, 'id'>;
  /** True when the guard rejected at least one attempt — surfaced in metrics. */
  dietFilterEnforced: boolean;
  attempts: number;
  disclaimer: string;
}

export class RecipeGenerationError extends Error {
  constructor(
    readonly reason: 'diet_unsatisfiable' | 'ai_unavailable' | 'invalid_input',
    readonly userMessage: string,
  ) {
    super(userMessage);
    this.name = 'RecipeGenerationError';
  }
}

// -----------------------------------------------------------------------------
// Generation
// -----------------------------------------------------------------------------

export const MAX_DIET_RETRIES = 2;

export async function generateRecipe(
  client: GeminiClient,
  params: {
    ingredients: string[];
    preference: DietPreference;
    mealType?: string;
    maxCookTimeMin?: number;
  },
): Promise<RecipeGenerationResult> {
  const ingredients = params.ingredients.map((i) => i.trim()).filter(Boolean);
  if (ingredients.length === 0) {
    throw new RecipeGenerationError('invalid_input', 'Please add at least one ingredient.');
  }

  let retryHint: string | null = null;
  let dietFilterEnforced = false;

  for (let attempt = 1; attempt <= MAX_DIET_RETRIES + 1; attempt++) {
    let raw: RawRecipe;
    try {
      raw = await client.generateJson<RawRecipe>({
        prompt: buildPrompt(ingredients, params.preference, params, retryHint),
        systemInstruction: SYSTEM_INSTRUCTION,
        responseSchema: RECIPE_SCHEMA as unknown as Record<string, unknown>,
        // Slightly creative on the first pass; stricter on retries, because a
        // retry means we need compliance far more than we need variety.
        temperature: attempt === 1 ? 0.7 : 0.2,
      });
    } catch (error) {
      if (error instanceof GeminiError) {
        throw new RecipeGenerationError('ai_unavailable', error.userMessage);
      }
      throw error;
    }

    // ---- The guarantee ----
    const verdict = checkDietCompliance(
      { title: raw.title, ingredients: raw.ingredients, steps: raw.steps },
      params.preference,
    );

    if (!verdict.allowed) {
      dietFilterEnforced = true;
      retryHint = verdict.retryHint;
      if (attempt > MAX_DIET_RETRIES) {
        // We refuse to serve a violating recipe. Better a clear failure than a
        // vegetarian user unknowingly handed a recipe with an egg wash.
        throw new RecipeGenerationError('diet_unsatisfiable', verdict.message);
      }
      continue;
    }

    return {
      recipe: {
        title: raw.title,
        ingredients: raw.ingredients,
        steps: raw.steps,
        cookTimeMin: raw.cookTimeMin,
        dietPreference: params.preference,
        // Taken from the verified analysis, never from the model's own claim.
        containsEgg: verdict.analysis.containsEgg,
        containsMeat: verdict.analysis.containsMeat,
        nutrition: raw.nutrition,
        isAiGenerated: true,
        regionTag: raw.regionTag,
      },
      dietFilterEnforced,
      attempts: attempt,
      disclaimer: DISCLAIMERS.aiNutrition,
    };
  }

  // Unreachable: the loop either returns or throws.
  throw new RecipeGenerationError('diet_unsatisfiable', 'Could not generate a compliant recipe.');
}
