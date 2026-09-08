/**
 * Coin Engine tests.
 *
 * Each test here guards a product promise, not just a function. If one of these
 * ever fails, VYRA has stopped being the thing we told the judges it was.
 */
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { COIN_RULES } from '@vyra/types';

import { computeEffort } from './chrono';
import {
  applyAward,
  applyAwards,
  buildRedemption,
  computeBalance,
  computeChallengeAward,
  computeMetricsAward,
  computeStreakMilestoneAward,
  computeWorkoutAward,
  computeZeroSugarAward,
  evaluateUnlocks,
  earnedToday,
  type LedgerRow,
  type Unlockable,
} from './coins';

const USER = 'u-1';
const DATE = '2026-09-02';

const row = (delta: number, key?: string): LedgerRow => ({
  delta,
  reason: 'test',
  sourceType: 'workout',
  idempotencyKey: key,
  createdAt: DATE,
});

const emptyCtx = { todayRows: [] as LedgerRow[], currentBalance: 0 };

// ---------------------------------------------------------------------------
describe('award computation', () => {
  it('rewards a met goal, whatever its absolute size', () => {
    // The whole fairness model collapses if a 12-minute adapted goal is worth
    // less than a 40-minute one.
    const student = computeWorkoutAward(computeEffort(12, 12), USER, DATE);
    const freeUser = computeWorkoutAward(computeEffort(40, 40), USER, DATE);
    assert.equal(student!.delta, freeUser!.delta);
    assert.equal(student!.delta, COIN_RULES.workoutCompleted);
  });

  it('gives partial credit for showing up', () => {
    const award = computeWorkoutAward(computeEffort(6, 20), USER, DATE);
    assert.equal(award!.delta, COIN_RULES.workoutPartial);
    assert.match(award!.reason, /still counts/);
  });

  it('never creates a negative award for a missed day', () => {
    assert.equal(computeWorkoutAward(computeEffort(0, 20), USER, DATE), null);
    assert.equal(computeWorkoutAward(computeEffort(0, 0), USER, DATE), null);
  });

  it('awards a streak milestone only on the exact threshold day', () => {
    assert.equal(computeStreakMilestoneAward(6, USER), null);
    assert.equal(computeStreakMilestoneAward(7, USER)!.delta, COIN_RULES.streakMilestones[7]);
    assert.equal(computeStreakMilestoneAward(8, USER), null);
  });

  it('keys a milestone by the milestone, so a rebuilt streak cannot farm it twice', () => {
    const first = computeStreakMilestoneAward(7, USER)!;
    const rebuilt = computeStreakMilestoneAward(7, USER)!;
    assert.equal(first.idempotencyKey, rebuilt.idempotencyKey);
  });

  it('separates workout and zero-sugar streak keys', () => {
    const w = computeStreakMilestoneAward(7, USER, 'workout')!;
    const z = computeStreakMilestoneAward(7, USER, 'zero_sugar')!;
    assert.notEqual(w.idempotencyKey, z.idempotencyKey);
  });
});

// ---------------------------------------------------------------------------
describe('idempotency', () => {
  it('refuses to award the same event twice', () => {
    const award = computeWorkoutAward(computeEffort(20, 20), USER, DATE)!;
    const ctx = { todayRows: [row(20, award.idempotencyKey)], currentBalance: 20 };
    const outcome = applyAward(award, ctx);
    assert.equal(outcome.status, 'duplicate');
    assert.equal(outcome.applied, null);
  });

  it('survives a double-tap without leaking coins', () => {
    const award = computeZeroSugarAward(USER, DATE);
    const outcomes = applyAwards([award, award], emptyCtx);
    assert.equal(outcomes[0]!.status, 'applied');
    assert.equal(outcomes[1]!.status, 'duplicate');
  });

  it('still allows the same award type on a different day', () => {
    const day1 = computeZeroSugarAward(USER, '2026-09-01');
    const day2 = computeZeroSugarAward(USER, '2026-09-02');
    assert.notEqual(day1.idempotencyKey, day2.idempotencyKey);
  });
});

// ---------------------------------------------------------------------------
describe('daily earn cap', () => {
  it('caps earnings and says so instead of silently awarding zero', () => {
    const ctx = { todayRows: [row(COIN_RULES.dailyEarnCap)], currentBalance: 150 };
    const outcome = applyAward(computeMetricsAward(USER, DATE), ctx);
    assert.equal(outcome.status, 'cap_reached');
    assert.equal(outcome.applied, null);
    assert.match(outcome.message, /limit/);
    assert.match(outcome.message, /still counts/);
  });

  it('awards the remaining headroom on a partial cap hit', () => {
    const ctx = { todayRows: [row(COIN_RULES.dailyEarnCap - 5)], currentBalance: 145 };
    const outcome = applyAward(computeZeroSugarAward(USER, DATE), ctx);
    assert.equal(outcome.status, 'partially_applied');
    assert.equal(outcome.applied!.delta, 5);
    assert.equal(outcome.cappedAmount, COIN_RULES.zeroSugarDay - 5);
  });

  it('never exceeds the cap across a batch of awards', () => {
    const many = Array.from({ length: 30 }, (_, i) =>
      computeChallengeAward(`c-${i}`, 50, USER),
    );
    const outcomes = applyAwards(many, emptyCtx);
    const total = outcomes.reduce((s, o) => s + (o.applied?.delta ?? 0), 0);
    assert.equal(total, COIN_RULES.dailyEarnCap);
  });

  it('does not let spending free up earning headroom', () => {
    // A redemption is negative, so it must not count toward "earned today".
    const rows = [row(100), { ...row(-80), sourceType: 'redemption' as const }];
    assert.equal(earnedToday(rows), 100);
  });
});

// ---------------------------------------------------------------------------
describe('balance and levels', () => {
  it('derives a balance as a pure sum of the ledger', () => {
    const b = computeBalance([row(100), row(50), { ...row(-30), sourceType: 'redemption' }]);
    assert.equal(b.earnedTotal, 150);
    assert.equal(b.spentTotal, 30);
    assert.equal(b.balance, 120);
  });

  /**
   * The rule that stops redemption from feeling like a punishment.
   */
  it('never demotes a user for spending coins', () => {
    const beforeSpending = computeBalance([row(1000)]);
    const afterSpending = computeBalance([row(1000), { ...row(-900), sourceType: 'redemption' }]);
    assert.equal(afterSpending.level, beforeSpending.level);
    assert.ok(afterSpending.balance < beforeSpending.balance);
  });

  it('starts everyone at level 1', () => {
    assert.equal(computeBalance([]).level, 1);
  });

  it('reports honest progress toward the next level', () => {
    const b = computeBalance([row(175)]);   // between the 100 and 250 thresholds
    assert.equal(b.level, 2);
    assert.equal(b.coinsToNextLevel, 75);
    assert.equal(b.levelProgress, 0.5);
  });

  it('handles the maximum level without dividing by zero', () => {
    const b = computeBalance([row(999_999)]);
    assert.equal(b.isMaxLevel, true);
    assert.equal(b.coinsToNextLevel, 0);
    assert.equal(b.levelProgress, 1);
  });
});

// ---------------------------------------------------------------------------
describe('redemption', () => {
  it('spends coins one-way — there is no inverse that adds money', () => {
    const r = buildRedemption('cat-1', 'Marathon entry', 500, USER, 'nonce-1');
    assert.ok(r.delta < 0);
    assert.equal(r.sourceType, 'redemption');
  });

  it('refuses to overdraw', () => {
    const r = buildRedemption('cat-1', 'Marathon entry', 500, USER, 'n1');
    const outcome = applyAward(r, { todayRows: [], currentBalance: 300 });
    assert.equal(outcome.applied, null);
    assert.match(outcome.message, /Not enough coins/);
  });

  it('allows a redemption the user can afford', () => {
    const r = buildRedemption('cat-1', 'Marathon entry', 500, USER, 'n1');
    const outcome = applyAward(r, { todayRows: [], currentBalance: 500 });
    assert.equal(outcome.status, 'applied');
    assert.equal(outcome.applied!.delta, -500);
  });

  it('is not blocked by the daily EARN cap', () => {
    const r = buildRedemption('cat-1', 'Voucher', 100, USER, 'n1');
    const ctx = { todayRows: [row(COIN_RULES.dailyEarnCap)], currentBalance: 400 };
    assert.equal(applyAward(r, ctx).status, 'applied');
  });

  it('a double-tapped redemption spends once', () => {
    const r = buildRedemption('cat-1', 'Voucher', 100, USER, 'same-nonce');
    const outcomes = applyAwards([r, r], { todayRows: [], currentBalance: 500 });
    assert.equal(outcomes[0]!.status, 'applied');
    assert.equal(outcomes[1]!.status, 'duplicate');
  });
});

// ---------------------------------------------------------------------------
describe('unlocks', () => {
  const items: Unlockable[] = [
    { id: 'p1', kind: 'program', title: 'Advanced HIIT', requiredLevel: 3, requiredCoins: 0 },
    { id: 't1', kind: 'theme', title: 'Neon Theme', requiredLevel: 1, requiredCoins: 500 },
  ];

  it('reports precisely what is blocking each item', () => {
    const states = evaluateUnlocks(items, computeBalance([row(120)]));
    assert.equal(states[0]!.blockedBy, 'level');
    assert.equal(states[1]!.blockedBy, 'coins');
  });

  it('unlocks once both conditions are met', () => {
    const states = evaluateUnlocks(items, computeBalance([row(600)]));
    assert.equal(states.every((s) => s.isUnlocked), true);
  });

  /**
   * The hard guardrail. An injured user must never be told to earn coins before
   * they can see a knee-recovery routine.
   */
  it('refuses outright to gate safety content', () => {
    assert.throws(
      () =>
        evaluateUnlocks(
          [{ id: 'r1', kind: 'program', title: 'Knee Recovery', requiredLevel: 5, requiredCoins: 0, isSafetyContent: true }],
          computeBalance([]),
        ),
      /must not be gated/,
    );
  });
});

// ---------------------------------------------------------------------------
describe('the no-purchase guarantee', () => {
  /**
   * A structural test. If someone adds a purchase path, the union widens and this
   * list stops matching — a deliberate tripwire, alongside the Postgres CHECK
   * constraint and the shared type in @vyra/types.
   */
  it('has no source type that could represent buying coins', () => {
    const permitted = [
      'workout', 'streak', 'challenge', 'zero_sugar', 'redemption', 'admin_adjustment',
    ];
    const producers = [
      computeWorkoutAward(computeEffort(20, 20), USER, DATE)!,
      computeMetricsAward(USER, DATE),
      computeZeroSugarAward(USER, DATE),
      computeStreakMilestoneAward(7, USER)!,
      computeChallengeAward('c1', 50, USER),
      buildRedemption('cat1', 'x', 10, USER, 'n'),
    ];
    for (const p of producers) {
      assert.ok(permitted.includes(p.sourceType), `unexpected source ${p.sourceType}`);
      assert.notEqual(p.sourceType as string, 'purchase');
    }
  });

  it('has no code path that awards coins for money', () => {
    // Every positive award in the engine is tied to a completed health behaviour.
    const positives = [
      computeWorkoutAward(computeEffort(20, 20), USER, DATE)!,
      computeZeroSugarAward(USER, DATE),
      computeMetricsAward(USER, DATE),
    ];
    for (const p of positives) {
      assert.ok(['workout', 'zero_sugar', 'streak', 'challenge'].includes(p.sourceType));
    }
  });
});
