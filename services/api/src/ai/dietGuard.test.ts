/**
 * Diet Guard tests.
 *
 * This is the highest-stakes filter in VYRA. Serving a strict vegetarian a recipe
 * with an egg wash is not a cosmetic bug — it breaks something the user considers
 * non-negotiable. These tests are the reason we can promise it does not happen.
 */
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

import { analyseDietContent, checkDietCompliance, dietWarningForFood } from './dietGuard';

describe('detecting meat', () => {
  it('catches obvious English terms', () => {
    for (const item of ['chicken breast', 'mutton curry', 'pork belly', 'prawn masala']) {
      assert.equal(analyseDietContent({ title: item }).containsMeat, true, item);
    }
  });

  it('catches Hindi and regional terms', () => {
    for (const item of ['murgh makhani', 'keema matar', 'machli fry', 'gosht biryani', 'jhinga']) {
      assert.equal(analyseDietContent({ title: item }).containsMeat, true, item);
    }
  });

  /**
   * The failures that actually happen in practice — an LLM adds a stock cube or
   * a sauce and the dish is no longer vegetarian, while still being called one.
   */
  it('catches hidden animal-derived ingredients', () => {
    const hidden = [
      'gelatin', 'chicken stock cube', 'fish sauce', 'oyster sauce',
      'worcestershire sauce', 'lard', 'bone broth', 'animal rennet', 'anchovies',
    ];
    for (const item of hidden) {
      assert.equal(
        analyseDietContent({ ingredients: [{ name: item }] }).containsMeat,
        true,
        `missed hidden ingredient: ${item}`,
      );
    }
  });

  it('catches meat mentioned only in a cooking step', () => {
    // A very common real failure: the ingredient list is clean, step 4 is not.
    const a = analyseDietContent({
      title: 'Fried Rice',
      ingredients: [{ name: 'rice' }, { name: 'peas' }],
      steps: ['Boil the rice.', 'Add a chicken stock cube for flavour.'],
    });
    assert.equal(a.containsMeat, true);
  });
});

describe('detecting egg', () => {
  it('catches direct references in several languages', () => {
    for (const item of ['egg curry', 'anda bhurji', 'muttai poriyal', 'omelette']) {
      assert.equal(analyseDietContent({ title: item }).containsEgg, true, item);
    }
  });

  it('catches egg hidden inside other foods', () => {
    for (const item of ['mayonnaise', 'meringue', 'custard powder', 'egg noodles', 'aioli']) {
      assert.equal(
        analyseDietContent({ ingredients: [{ name: item }] }).containsEgg,
        true,
        `missed: ${item}`,
      );
    }
  });

  it('catches an egg wash buried in the method', () => {
    const a = analyseDietContent({
      title: 'Veg Puff',
      ingredients: [{ name: 'flour' }, { name: 'potato' }],
      steps: ['Roll the pastry.', 'Brush with egg wash.', 'Bake.'],
    });
    assert.equal(a.containsEgg, true);
  });
});

describe('not over-blocking safe food', () => {
  /**
   * An over-strict filter is its own failure mode. Rejecting an eggless cake
   * teaches the user the feature is broken and they stop using it.
   */
  it('allows eggless and meat-free substitutes', () => {
    const safe = [
      'eggless chocolate cake',
      'egg-free mayonnaise',
      'vegan mayo sandwich',
      'soya chaap tikka',
      'mock mutton curry',
      'jackfruit biryani',
      'kathal ki sabzi',
      'microbial rennet paneer',
      'vegetable stock',
    ];
    for (const item of safe) {
      const a = analyseDietContent({ title: item });
      assert.equal(a.containsMeat, false, `wrongly flagged meat: ${item}`);
      assert.equal(a.containsEgg, false, `wrongly flagged egg: ${item}`);
    }
  });

  it('does not match a term inside a longer unrelated word', () => {
    // 'buttermilk' vs 'butter', 'hammer' vs 'ham', 'grape' vs 'ape'
    for (const item of ['buttermilk chaas', 'hammered copper pan', 'grape juice', 'mushroom']) {
      const a = analyseDietContent({ title: item });
      assert.equal(a.containsMeat, false, `false positive: ${item}`);
    }
  });

  it('allows plain vegetarian food', () => {
    const a = analyseDietContent({
      title: 'Palak Paneer',
      ingredients: [{ name: 'spinach' }, { name: 'paneer' }, { name: 'ginger' }],
      steps: ['Blanch the spinach.', 'Add paneer cubes.'],
    });
    assert.equal(a.containsMeat, false);
    assert.equal(a.containsEgg, false);
  });
});

describe('compliance gate', () => {
  const eggRecipe = { title: 'Egg Fried Rice', ingredients: [{ name: 'egg' }], steps: [] };
  const meatRecipe = { title: 'Chicken Biryani', ingredients: [{ name: 'chicken' }], steps: [] };
  const vegRecipe = { title: 'Dal Tadka', ingredients: [{ name: 'toor dal' }], steps: [] };

  it('blocks meat for both vegetarian preferences', () => {
    for (const pref of ['veg_no_egg', 'veg_with_egg'] as const) {
      const v = checkDietCompliance(meatRecipe, pref);
      assert.equal(v.allowed, false);
      assert.equal(v.violation, 'meat_for_vegetarian');
    }
  });

  it('blocks egg for a no-egg vegetarian', () => {
    const v = checkDietCompliance(eggRecipe, 'veg_no_egg');
    assert.equal(v.allowed, false);
    assert.equal(v.violation, 'egg_for_no_egg_vegetarian');
  });

  it('allows egg for a vegetarian who eats eggs', () => {
    assert.equal(checkDietCompliance(eggRecipe, 'veg_with_egg').allowed, true);
  });

  it('never blocks a stricter recipe for a looser preference', () => {
    // A non-vegetarian is not prevented from seeing dal.
    assert.equal(checkDietCompliance(vegRecipe, 'non_veg').allowed, true);
    assert.equal(checkDietCompliance(meatRecipe, 'non_veg').allowed, true);
    assert.equal(checkDietCompliance(vegRecipe, 'veg_no_egg').allowed, true);
  });

  it('produces a retry hint naming the exact offending term', () => {
    const v = checkDietCompliance(eggRecipe, 'veg_no_egg');
    assert.ok(v.retryHint, 'a rejection must tell the model what went wrong');
    assert.match(v.retryHint!, /egg/);
  });

  it('tells the user nothing was saved, rather than showing a bad recipe', () => {
    const v = checkDietCompliance(meatRecipe, 'veg_no_egg');
    assert.match(v.message, /Nothing was saved/);
  });
});

describe('food logging warnings', () => {
  it('warns but does not block, because a diary must record reality', () => {
    const warning = dietWarningForFood(
      { name: 'Chicken Sandwich', containsEgg: false, containsMeat: true },
      'veg_no_egg',
    );
    assert.ok(warning);
    assert.match(warning!, /can still log it/);
  });

  it('stays quiet for a non-vegetarian user', () => {
    assert.equal(
      dietWarningForFood({ name: 'Chicken Sandwich', containsEgg: false, containsMeat: true }, 'non_veg'),
      null,
    );
  });

  it('stays quiet when the food matches the preference', () => {
    assert.equal(
      dietWarningForFood({ name: 'Dal Rice', containsEgg: false, containsMeat: false }, 'veg_no_egg'),
      null,
    );
  });

  it('warns a no-egg vegetarian about egg, but not a veg_with_egg user', () => {
    const food = { name: 'Mayo Sandwich', containsEgg: true, containsMeat: false };
    assert.ok(dietWarningForFood(food, 'veg_no_egg'));
    assert.equal(dietWarningForFood(food, 'veg_with_egg'), null);
  });
});
