/**
 * =============================================================================
 * DIET GUARD — server-side enforcement of the user's dietary preference
 * =============================================================================
 * This module exists because of one rule in the product spec:
 *
 *     "Must hard-enforce the user's stored diet filter server-side after
 *      generation (don't trust the prompt alone)"
 *
 * Why that rule is right, concretely:
 *
 *   - An LLM told "vegetarian, no eggs" will still occasionally return a recipe
 *     with an egg wash, mayonnaise, Worcestershire sauce (anchovies), gelatin in
 *     a dessert, or a "chicken stock cube" in the seasoning line.
 *   - For a Jain or strict-vegetarian user in India, serving that is not a bug.
 *     It is a violation of something they consider non-negotiable, and it destroys
 *     trust in the entire app instantly.
 *
 * So generation is treated as UNTRUSTED INPUT. Every recipe passes this filter
 * before it can be saved or shown. If it fails, we regenerate — and if it fails
 * repeatedly, we return an honest error rather than a compromised recipe.
 *
 * The lexicon is written for Indian kitchens: Hindi and regional terms alongside
 * English, and the non-obvious animal-derived ingredients that catch people out.
 *
 * Pure module. No network, no database — fully unit-testable.
 * =============================================================================
 */

import type { DietPreference } from '@vyra/types';

// -----------------------------------------------------------------------------
// Lexicons
// -----------------------------------------------------------------------------

/**
 * Meat, poultry, fish and seafood — English, Hindi and common regional terms.
 * Matched as whole words, so "buttermilk" is not flagged for containing "butter".
 */
const MEAT_TERMS: readonly string[] = [
  // Poultry & red meat
  'chicken', 'murgh', 'murga', 'kukkad',
  'mutton', 'lamb', 'goat', 'bakra', 'gosht', 'ghosht',
  'beef', 'veal', 'pork', 'ham', 'bacon', 'sausage', 'salami', 'pepperoni',
  'keema', 'qeema', 'mince', 'minced meat', 'meat',
  'liver', 'kaleji', 'brain', 'trotters', 'paya',
  'turkey', 'duck', 'quail', 'batair', 'rabbit',
  'tikka boti', 'seekh kebab', 'shami kebab',
  // Fish & seafood
  'fish', 'machli', 'machhli', 'meen',
  'prawn', 'prawns', 'shrimp', 'jhinga', 'crab', 'kekda', 'lobster',
  'squid', 'calamari', 'octopus', 'clam', 'mussel', 'oyster', 'scallop',
  'tuna', 'salmon', 'sardine', 'anchovy', 'anchovies', 'mackerel', 'bombil',
  'pomfret', 'rohu', 'katla', 'hilsa', 'surmai', 'rawas',
  // Derived / hidden
  'gelatin', 'gelatine', 'lard', 'tallow', 'suet', 'schmaltz',
  'bone broth', 'meat stock', 'chicken stock', 'beef stock', 'fish stock',
  'chicken broth', 'beef broth', 'fish sauce', 'oyster sauce',
  'worcestershire', 'shrimp paste', 'bonito', 'dashi',
  'rennet', 'animal rennet', 'carmine', 'cochineal',
  'isinglass', 'collagen', 'keratin',
  'chicken powder', 'meat masala', 'chicken masala',
];

/** Eggs — including the forms people forget are eggs. */
const EGG_TERMS: readonly string[] = [
  'egg', 'eggs', 'anda', 'ande', 'andaa', 'muttai', 'dim',
  'egg white', 'egg yolk', 'yolk', 'albumen', 'egg wash',
  'omelette', 'omelet', 'bhurji egg', 'egg bhurji', 'akuri',
  'meringue', 'meringues', 'mayonnaise', 'mayo', 'aioli',
  'hollandaise', 'custard', 'creme anglaise', 'egg noodles',
  'eggless', // handled specially below — see stripNegations
  'lecithin (egg)', 'egg powder', 'liquid egg', 'century egg',
];

/**
 * Phrases that mean the OPPOSITE of a flagged term and must not trigger a match.
 * "Eggless cake" contains "egg" but is safe; "mock mutton" is a soya dish.
 */
/**
 * Prefixes that negate whatever product word follows them.
 * "egg-free mayonnaise" must not flag on "mayonnaise".
 */
const NEGATION_PREFIXES: readonly string[] = [
  'eggless', 'egg-free', 'egg free',
  'vegan', 'plant-based', 'plant based', 'veg', 'vegetarian',
  'mock', 'faux', 'imitation', 'meatless', 'meat-free', 'meat free',
];

/** Products that commonly appear behind one of those prefixes. */
const NEGATABLE_PRODUCTS: readonly string[] = [
  'mayonnaise', 'mayo', 'aioli', 'custard', 'meringue', 'omelette', 'omelet',
  'noodles', 'egg noodles', 'cake', 'brownie', 'pudding', 'gelatin', 'gelatine',
  'meat', 'chicken', 'mutton', 'fish', 'sausage', 'bacon', 'prawn', 'keema',
  'stock', 'broth', 'rennet',
];

/**
 * Built by combining every prefix with every product, plus standalone phrases.
 *
 * Generated rather than hand-listed because the hand-written version missed
 * "egg-free mayonnaise" — it stripped "egg-free" and then flagged the leftover
 * "mayonnaise". Enumerating the combinations removes a whole class of that bug
 * instead of patching one instance of it.
 */
const NEGATION_PHRASES: readonly string[] = [
  ...NEGATION_PREFIXES.flatMap((prefix) =>
    NEGATABLE_PRODUCTS.map((product) => `${prefix} ${product}`),
  ),
  'eggless', 'egg-free', 'egg free', 'without egg', 'no egg', 'sans egg',
  'meatless', 'meat-free', 'meat free', 'without meat', 'no meat',
  'soya chaap', 'soy chaap', 'soya granules', 'soya nuggets',
  'jackfruit', 'kathal', 'banana blossom', 'fishless',
  'vegetable stock', 'microbial rennet',
];

// -----------------------------------------------------------------------------
// Matching
// -----------------------------------------------------------------------------

/**
 * Removes negated phrases before matching.
 *
 * Order matters: we strip "eggless" first, so the remaining text no longer
 * contains "egg". Without this, every eggless cake would be rejected — and an
 * over-strict filter that blocks safe food is its own kind of failure.
 */
function stripNegations(text: string): string {
  let out = ` ${text.toLowerCase()} `;
  // Longest first, so "eggless mayonnaise" is removed before "eggless".
  const ordered = [...NEGATION_PHRASES].sort((a, b) => b.length - a.length);
  for (const phrase of ordered) {
    out = out.split(phrase).join(' ');
  }
  return out;
}

/** Whole-word / whole-phrase match, so "buttermilk" never matches "butter". */
function containsTerm(haystack: string, term: string): boolean {
  const escaped = term.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return new RegExp(`(^|[^a-z])${escaped}([^a-z]|$)`, 'i').test(haystack);
}

function findTerms(text: string, lexicon: readonly string[]): string[] {
  const cleaned = stripNegations(text);
  const hits = new Set<string>();
  for (const term of lexicon) {
    if (term === 'eggless') continue;   // negation marker, not an ingredient
    if (containsTerm(cleaned, term)) hits.add(term);
  }
  return [...hits];
}

// -----------------------------------------------------------------------------
// Public API
// -----------------------------------------------------------------------------

export interface DietAnalysis {
  containsMeat: boolean;
  containsEgg: boolean;
  meatTerms: string[];
  eggTerms: string[];
}

/**
 * Analyses arbitrary recipe text — title, ingredients and steps together.
 * Steps are included deliberately: an egg wash usually appears only in step 4.
 */
export function analyseDietContent(parts: {
  title?: string;
  ingredients?: Array<{ name: string; quantity?: string } | string>;
  steps?: string[];
}): DietAnalysis {
  const ingredientText = (parts.ingredients ?? [])
    .map((i) => (typeof i === 'string' ? i : i.name))
    .join(' | ');

  const text = [parts.title ?? '', ingredientText, (parts.steps ?? []).join(' | ')].join(' | ');

  const meatTerms = findTerms(text, MEAT_TERMS);
  const eggTerms = findTerms(text, EGG_TERMS);

  return {
    containsMeat: meatTerms.length > 0,
    containsEgg: eggTerms.length > 0,
    meatTerms,
    eggTerms,
  };
}

export interface DietVerdict {
  allowed: boolean;
  analysis: DietAnalysis;
  /** Machine-readable reason, for retry logic and metrics. */
  violation: 'meat_for_vegetarian' | 'egg_for_no_egg_vegetarian' | null;
  /** User-facing explanation. Shown only if we give up after retries. */
  message: string;
  /** Fed back into the regeneration prompt so the retry is actually informed. */
  retryHint: string | null;
}

/**
 * The gate. Nothing reaches a user without passing this.
 *
 * Note the asymmetry, which is intentional: a non-vegetarian user is never
 * blocked from a vegetarian recipe. The filter only ever protects a stricter
 * preference from a looser output, never the reverse.
 */
export function checkDietCompliance(
  parts: Parameters<typeof analyseDietContent>[0],
  preference: DietPreference,
): DietVerdict {
  const analysis = analyseDietContent(parts);

  if (preference === 'non_veg') {
    return { allowed: true, analysis, violation: null, message: '', retryHint: null };
  }

  if (analysis.containsMeat) {
    return {
      allowed: false,
      analysis,
      violation: 'meat_for_vegetarian',
      message:
        'We could not produce a recipe matching your vegetarian preference from these ingredients. Nothing was saved.',
      retryHint:
        `The previous attempt contained non-vegetarian items (${analysis.meatTerms.join(', ')}). ` +
        `Produce a strictly vegetarian recipe with no meat, poultry, fish, seafood, or any ` +
        `animal-derived ingredient such as gelatin, lard, fish sauce or animal rennet.`,
    };
  }

  if (preference === 'veg_no_egg' && analysis.containsEgg) {
    return {
      allowed: false,
      analysis,
      violation: 'egg_for_no_egg_vegetarian',
      message:
        'We could not produce an egg-free recipe from these ingredients. Nothing was saved.',
      retryHint:
        `The previous attempt contained egg (${analysis.eggTerms.join(', ')}). ` +
        `Produce a recipe with no egg in any form — no egg wash, no mayonnaise, no custard, ` +
        `no meringue. Eggless substitutes such as flax or curd are acceptable.`,
    };
  }

  return { allowed: true, analysis, violation: null, message: '', retryHint: null };
}

/**
 * Flags a scanned or barcoded food that falls outside the user's preference.
 *
 * This does NOT block logging. If someone ate it, they ate it, and a diary that
 * refuses to record reality is useless. It warns, and lets them log it anyway.
 */
export function dietWarningForFood(
  food: { name: string; containsEgg: boolean; containsMeat: boolean },
  preference: DietPreference,
): string | null {
  if (preference === 'non_veg') return null;

  if (food.containsMeat) {
    return `${food.name} appears to contain non-vegetarian ingredients, which is outside your stated preference. You can still log it.`;
  }
  if (preference === 'veg_no_egg' && food.containsEgg) {
    return `${food.name} appears to contain egg, which is outside your stated preference. You can still log it.`;
  }
  return null;
}

/** Exported for the admin content console, which lints the curated library. */
export const DIET_LEXICON = { MEAT_TERMS, EGG_TERMS, NEGATION_PHRASES } as const;
