/**
 * =============================================================================
 * AI FOOD PHOTO SCAN
 * =============================================================================
 * Turns a photo of a meal into an editable list of estimated food items —
 * never a silently-logged diary entry.
 *
 * The core constraint, and why it shapes this whole module: a vision model
 * estimating calories from a photo is a guess, not a measurement. It cannot
 * see portion depth, hidden oil, or what's under a garnish. dietGuard.ts
 * exists because "trust the prompt" is not good enough for a dietary rule
 * that must never be violated; the same distrust applies here to numbers
 * that must never be presented as more certain than they are. So:
 *
 *   1. CONSTRAIN the output to a JSON schema at the API level.   (structure)
 *   2. ASK the model to self-report a confidence per item.       (honesty)
 *   3. ATTACH a disclaimer to every response, unconditionally.   (never lies)
 *   4. NEVER write to the diary here — this module only scans.   (see route)
 *
 * The actual diary write happens after the user reviews/corrects these
 * numbers in the app and logs them through a separate call — there is no
 * meal-logging endpoint yet in this codebase (checked: /v1/tracking is
 * biometrics, /v1/sugar is sugar-only, /v1/food/check is a diet-rule
 * warning). This module intentionally stops at "scan" for that reason.
 * =============================================================================
 */

import { DISCLAIMERS } from '@vyra/types';
import { GeminiClient, GeminiError } from './gemini';

// -----------------------------------------------------------------------------
// Output schema — enforced by the Gemini API, not merely requested in prose
// -----------------------------------------------------------------------------

const FOOD_SCAN_SCHEMA = {
  type: 'object',
  properties: {
    items: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          portion: { type: 'string' }, // e.g. "1 medium bowl (~250g)" — words, not a false-precision gram figure
          calories: { type: 'number' },
          proteinG: { type: 'number' },
          carbsG: { type: 'number' },
          fatG: { type: 'number' },
          fiberG: { type: 'number' },
          // Self-reported by the model. Not a guarantee of accuracy — a low
          // score just tells the user which items most need a manual check.
          confidence: { type: 'string', enum: ['high', 'medium', 'low'] },
        },
        required: ['name', 'portion', 'calories', 'proteinG', 'carbsG', 'fatG', 'fiberG', 'confidence'],
      },
    },
  },
  required: ['items'],
} as const;

interface RawFoodScanItem {
  name: string;
  portion: string;
  calories: number;
  proteinG: number;
  carbsG: number;
  fatG: number;
  fiberG: number;
  confidence: 'high' | 'medium' | 'low';
}

interface RawFoodScan {
  items: RawFoodScanItem[];
}

// -----------------------------------------------------------------------------
// Prompting
// -----------------------------------------------------------------------------

const SYSTEM_INSTRUCTION = `You are a careful nutrition-estimation assistant for the VYRA wellness app, looking at a photo of a meal.

Rules you must follow:
- Identify every distinct food item you can actually see. Do not invent items that are not visible.
- Estimate portion size in plain words a person would use (e.g. "1 medium bowl", "2 rotis", "1 cup") — never claim a false-precision exact gram weight.
- Give realistic calorie and macro estimates per item, based on the visible portion. Do not exaggerate protein.
- Rate your own confidence per item as "high", "medium" or "low" — low whenever lighting, angle, mixed/hidden ingredients or an unfamiliar dish make the estimate uncertain. Be honest here; this is shown to the user.
- If nothing edible is visible in the photo, return an empty items array. Do not guess a meal that isn't there.`;

const PROMPT =
  'Identify each food item visible in this photo. For each item, estimate: name, portion size, ' +
  'calories, protein_g, carbs_g, fat_g, fiber_g, and your confidence in that estimate. ' +
  'Return one entry per distinct food item as JSON matching the required schema.';

// -----------------------------------------------------------------------------
// Result types
// -----------------------------------------------------------------------------

export interface FoodScanItem {
  name: string;
  portion: string;
  calories: number;
  proteinG: number;
  carbsG: number;
  fatG: number;
  fiberG: number;
  confidence: 'high' | 'medium' | 'low';
}

export interface FoodScanResult {
  items: FoodScanItem[];
  /** Always populated — never let this look more certain than it is. */
  disclaimer: string;
}

export class FoodScanError extends Error {
  constructor(
    readonly kind: 'invalid_input' | 'ai_unavailable' | 'no_food_detected',
    readonly userMessage: string,
  ) {
    super(userMessage);
    this.name = 'FoodScanError';
  }
}

// -----------------------------------------------------------------------------
// Scanning
// -----------------------------------------------------------------------------

export async function analyzeFoodPhoto(
  client: GeminiClient,
  params: { imageBase64: string; mimeType: string },
): Promise<FoodScanResult> {
  const imageBase64 = params.imageBase64?.trim();
  const mimeType = params.mimeType?.trim();

  if (!imageBase64) {
    throw new FoodScanError('invalid_input', 'Please provide a photo to scan.');
  }
  if (!mimeType || !/^image\/(jpeg|jpg|png|webp|heic|heif)$/i.test(mimeType)) {
    throw new FoodScanError('invalid_input', 'Unsupported image type. Use JPEG, PNG, WEBP or HEIC.');
  }

  let raw: RawFoodScan;
  try {
    raw = await client.generateJson<RawFoodScan>({
      prompt: PROMPT,
      systemInstruction: SYSTEM_INSTRUCTION,
      image: { mimeType, dataBase64: imageBase64 },
      responseSchema: FOOD_SCAN_SCHEMA as unknown as Record<string, unknown>,
      // Low temperature: this is estimation, not creative generation — we want
      // the model's best single guess, not variety across retries.
      temperature: 0.2,
    });
  } catch (error) {
    if (error instanceof GeminiError) {
      throw new FoodScanError('ai_unavailable', error.userMessage);
    }
    throw error;
  }

  const items: FoodScanItem[] = (raw.items ?? []).map((i) => ({
    name: i.name,
    portion: i.portion,
    calories: i.calories,
    proteinG: i.proteinG,
    carbsG: i.carbsG,
    fatG: i.fatG,
    fiberG: i.fiberG,
    confidence: i.confidence,
  }));

  if (items.length === 0) {
    throw new FoodScanError(
      'no_food_detected',
      'No food items were recognisable in that photo. Try a clearer, closer shot.',
    );
  }

  return {
    items,
    // See constants.ts note in the accompanying report — reusing the existing
    // AI-nutrition disclaimer key. Add a food-scan-specific key there if you
    // want wording that explicitly says "review and correct before logging".
    disclaimer: DISCLAIMERS.aiNutrition,
  };
}
