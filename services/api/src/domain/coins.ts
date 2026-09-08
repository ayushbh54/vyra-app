/**
 * =============================================================================
 * VYRA COIN ENGINE
 * =============================================================================
 * Coins are EARNED ONLY. There is no shop, no ads, no purchase path, and no
 * function in this file that can create one.
 *
 * Design rules, and why each exists:
 *
 *  1. APPEND-ONLY LEDGER. A balance is SUM(delta), never a stored mutable number.
 *     A stored balance can be corrupted by a failed transaction and then silently
 *     drifts forever. A sum can always be re-derived and audited end to end.
 *
 *  2. IDEMPOTENCY KEYS. Every award carries a deterministic key. A retried request
 *     (flaky mobile network, user double-tap) awards once, not twice. This is the
 *     single most common way reward systems leak currency.
 *
 *  3. DAILY EARN CAP. A hard ceiling per day. This is not stinginess — it removes
 *     the incentive to grind, and it caps the value of any cheating exploit, so
 *     fraud stops being profitable.
 *
 *  4. DETERMINISTIC REWARDS. Fixed amounts for real completions. No random drops,
 *     no loot boxes, no variable-ratio schedule. Variable rewards are what make
 *     gambling mechanics work, and we are building a health habit, not a slot
 *     machine. The reinforcement here comes from frequency, not uncertainty.
 *
 *  5. NO NEGATIVE BALANCE. Redemption is refused rather than allowed to overdraw.
 *
 * Pure module: no database, no clock. Everything is passed in, so every rule
 * above is unit-testable.
 * =============================================================================
 */

import { COIN_RULES, LEVEL_THRESHOLDS } from '@vyra/types';
import type { EffortResult } from './chrono';

// -----------------------------------------------------------------------------
// Types
// -----------------------------------------------------------------------------

/**
 * The complete set of ways a coin can enter or leave the system.
 * There is deliberately no 'purchase' member. Adding one would require changing
 * this union, the Postgres CHECK constraint, and the shared type in @vyra/types —
 * three visible places, so it can never happen quietly.
 */
export type CoinSource =
  | 'workout'
  | 'streak'
  | 'challenge'
  | 'zero_sugar'
  | 'redemption'
  | 'admin_adjustment';

export interface CoinAward {
  delta: number;
  reason: string;
  sourceType: CoinSource;
  sourceId?: string;
  /** Deterministic: the same real-world event always produces the same key. */
  idempotencyKey: string;
}

export interface LedgerRow {
  delta: number;
  reason: string;
  sourceType: CoinSource;
  /** The specific thing this event was about (a challenge id, a catalog item id, ...).
   *  Optional and additive — existing rows/call sites without it keep working. */
  sourceId?: string;
  idempotencyKey?: string;
  createdAt: string;
}

export interface AwardOutcome {
  /** What was actually written. null when nothing was written. */
  applied: CoinAward | null;
  /** Amount requested before the daily cap was applied. */
  requestedDelta: number;
  /** Amount lost to the daily cap, so the UI can say so honestly. */
  cappedAmount: number;
  status: 'applied' | 'partially_applied' | 'duplicate' | 'cap_reached' | 'nothing_to_award';
  /** User-facing message. Never silently award 0 and show a celebration. */
  message: string;
}

// -----------------------------------------------------------------------------
// Award computation — what a given event is worth
// -----------------------------------------------------------------------------

/**
 * Workout award, keyed to the Chrono Engine's effort label.
 *
 * Note this rewards EFFORT RATIO, not absolute minutes: a student who completed
 * their 12-minute adapted goal earns exactly what someone completing a 40-minute
 * goal earns. The coin economy would undermine the whole fairness model otherwise.
 */
export function computeWorkoutAward(
  effort: EffortResult,
  userId: string,
  date: string,
): CoinAward | null {
  const key = `workout:${userId}:${date}`;

  switch (effort.label) {
    case 'met':
    case 'exceeded':
      return {
        delta: COIN_RULES.workoutCompleted,
        reason: 'Completed your daily movement goal',
        sourceType: 'workout',
        sourceId: date,
        idempotencyKey: key,
      };
    case 'partial':
      return {
        delta: COIN_RULES.workoutPartial,
        reason: 'Partial workout — showing up still counts',
        sourceType: 'workout',
        sourceId: date,
        idempotencyKey: key,
      };
    case 'rest_day':
    case 'missed':
      // A rest day earns nothing, but is never penalised either. There is no
      // negative coin event for missing a day anywhere in this engine.
      return null;
  }
}

export function computeMetricsAward(userId: string, date: string): CoinAward {
  return {
    delta: COIN_RULES.allMetricsLogged,
    reason: 'Logged all your health metrics',
    sourceType: 'workout',
    sourceId: date,
    idempotencyKey: `metrics:${userId}:${date}`,
  };
}

export function computeZeroSugarAward(userId: string, date: string): CoinAward {
  return {
    delta: COIN_RULES.zeroSugarDay,
    reason: 'A full zero-added-sugar day',
    sourceType: 'zero_sugar',
    sourceId: date,
    idempotencyKey: `zerosugar:${userId}:${date}`,
  };
}

export function computeDietAward(userId: string, date: string): CoinAward {
  return {
    delta: COIN_RULES.dietDayOnTarget,
    reason: 'Hit your nutrition targets',
    sourceType: 'workout',
    sourceId: date,
    idempotencyKey: `diet:${userId}:${date}`,
  };
}

/**
 * Streak milestone bonus. Awarded only on the exact day a threshold is crossed,
 * keyed by the milestone itself — so a streak that breaks and is rebuilt to 7
 * cannot farm the 7-day bonus twice.
 */
export function computeStreakMilestoneAward(
  newStreak: number,
  userId: string,
  kind: 'workout' | 'zero_sugar' = 'workout',
): CoinAward | null {
  const reward = COIN_RULES.streakMilestones[newStreak];
  if (reward === undefined) return null;

  return {
    delta: reward,
    reason: `${newStreak}-day streak milestone`,
    sourceType: 'streak',
    sourceId: String(newStreak),
    idempotencyKey: `streak:${kind}:${userId}:${newStreak}`,
  };
}

export function computeChallengeAward(
  challengeId: string,
  coinReward: number,
  userId: string,
): CoinAward {
  return {
    delta: coinReward,
    reason: 'Challenge completed',
    sourceType: 'challenge',
    sourceId: challengeId,
    idempotencyKey: `challenge:${userId}:${challengeId}`,
  };
}

// -----------------------------------------------------------------------------
// Ledger application — cap, idempotency, honesty
// -----------------------------------------------------------------------------

export interface LedgerContext {
  /** Every row written for this user today. Used for the cap and duplicate check. */
  todayRows: LedgerRow[];
  /** Full balance, so a redemption cannot overdraw. */
  currentBalance: number;
}

export function earnedToday(rows: LedgerRow[]): number {
  return rows.filter((r) => r.delta > 0).reduce((sum, r) => sum + r.delta, 0);
}

/**
 * Decides what actually gets written to the ledger.
 *
 * The important property: this function never lies. If the cap swallows part of
 * an award, the caller receives `partially_applied` plus the exact shortfall, so
 * the UI can say "you hit today's cap" instead of showing a +20 animation for a
 * +0 write. Reward systems that quietly award nothing are how users stop trusting
 * the number on screen.
 */
export function applyAward(award: CoinAward, ctx: LedgerContext): AwardOutcome {
  if (award.delta === 0) {
    return {
      applied: null,
      requestedDelta: 0,
      cappedAmount: 0,
      status: 'nothing_to_award',
      message: '',
    };
  }

  // Idempotency: this exact event was already recorded.
  const duplicate = ctx.todayRows.some(
    (r) => r.idempotencyKey && r.idempotencyKey === award.idempotencyKey,
  );
  if (duplicate) {
    return {
      applied: null,
      requestedDelta: award.delta,
      cappedAmount: 0,
      status: 'duplicate',
      message: 'Already counted.',
    };
  }

  // Spending: never allow an overdraw.
  if (award.delta < 0) {
    if (ctx.currentBalance + award.delta < 0) {
      return {
        applied: null,
        requestedDelta: award.delta,
        cappedAmount: 0,
        status: 'nothing_to_award',
        message: `Not enough coins — you have ${ctx.currentBalance}, this needs ${Math.abs(award.delta)}.`,
      };
    }
    return {
      applied: award,
      requestedDelta: award.delta,
      cappedAmount: 0,
      status: 'applied',
      message: award.reason,
    };
  }

  // Earning: apply the daily cap.
  const already = earnedToday(ctx.todayRows);
  const headroom = Math.max(0, COIN_RULES.dailyEarnCap - already);

  if (headroom === 0) {
    return {
      applied: null,
      requestedDelta: award.delta,
      cappedAmount: award.delta,
      status: 'cap_reached',
      message: `You have hit today's ${COIN_RULES.dailyEarnCap}-coin limit. Your progress still counts — coins reset tomorrow.`,
    };
  }

  if (award.delta > headroom) {
    return {
      applied: { ...award, delta: headroom },
      requestedDelta: award.delta,
      cappedAmount: award.delta - headroom,
      status: 'partially_applied',
      message: `+${headroom} coins (today's limit reached).`,
    };
  }

  return {
    applied: award,
    requestedDelta: award.delta,
    cappedAmount: 0,
    status: 'applied',
    message: `+${award.delta} — ${award.reason}`,
  };
}

/** Applies several awards in order, threading the cap through correctly. */
export function applyAwards(awards: CoinAward[], ctx: LedgerContext): AwardOutcome[] {
  const rows = [...ctx.todayRows];
  let balance = ctx.currentBalance;
  const outcomes: AwardOutcome[] = [];

  for (const award of awards) {
    const outcome = applyAward(award, { todayRows: rows, currentBalance: balance });
    outcomes.push(outcome);
    if (outcome.applied) {
      rows.push({
        delta: outcome.applied.delta,
        reason: outcome.applied.reason,
        sourceType: outcome.applied.sourceType,
        idempotencyKey: outcome.applied.idempotencyKey,
        createdAt: 'pending',
      });
      balance += outcome.applied.delta;
    }
  }
  return outcomes;
}

// -----------------------------------------------------------------------------
// Balance & levels
// -----------------------------------------------------------------------------

export interface Balance {
  balance: number;
  earnedTotal: number;
  spentTotal: number;
  level: number;
  levelProgress: number;      // 0..1 toward the next level
  coinsToNextLevel: number;
  isMaxLevel: boolean;
}

/**
 * Level is derived from LIFETIME EARNINGS, not the current balance.
 *
 * This matters: if level tracked the balance, redeeming a reward would demote the
 * user and lock content they had already unlocked. Spending coins must never take
 * progress away.
 */
export function computeBalance(rows: LedgerRow[]): Balance {
  const earnedTotal = rows.filter((r) => r.delta > 0).reduce((s, r) => s + r.delta, 0);
  const spentTotal = rows.filter((r) => r.delta < 0).reduce((s, r) => s + Math.abs(r.delta), 0);
  const balance = earnedTotal - spentTotal;

  let level = 1;
  for (let i = 0; i < LEVEL_THRESHOLDS.length; i++) {
    if (earnedTotal >= LEVEL_THRESHOLDS[i]!) level = i + 1;
    else break;
  }

  const isMaxLevel = level >= LEVEL_THRESHOLDS.length;
  const currentFloor = LEVEL_THRESHOLDS[level - 1] ?? 0;
  const nextFloor = isMaxLevel ? currentFloor : LEVEL_THRESHOLDS[level]!;
  const span = nextFloor - currentFloor;

  return {
    balance,
    earnedTotal,
    spentTotal,
    level,
    levelProgress: isMaxLevel || span <= 0 ? 1 : Math.round(((earnedTotal - currentFloor) / span) * 1000) / 1000,
    coinsToNextLevel: isMaxLevel ? 0 : nextFloor - earnedTotal,
    isMaxLevel,
  };
}

// -----------------------------------------------------------------------------
// Unlocks
// -----------------------------------------------------------------------------

export interface Unlockable {
  id: string;
  kind: 'program' | 'masterclass' | 'avatar' | 'theme';
  title: string;
  requiredLevel: number;
  requiredCoins: number;
  /** Recovery/accessibility content must never appear here. Asserted below. */
  isSafetyContent?: boolean;
}

export interface UnlockState extends Unlockable {
  isUnlocked: boolean;
  blockedBy: 'level' | 'coins' | null;
}

/**
 * Cosmetic and advanced-content unlocks only.
 *
 * Guardrail: anything flagged as safety content is rejected outright rather than
 * gated. The database enforces the same rule (`safety_content_never_locked`), so a
 * misconfigured row cannot make a recovery routine unreachable for an injured user.
 */
export function evaluateUnlocks(items: Unlockable[], balance: Balance): UnlockState[] {
  return items
    .filter((item) => {
      if (item.isSafetyContent) {
        // Loud in dev, silently safe in prod: never gate safety content.
        if (process.env.NODE_ENV !== 'production') {
          throw new Error(
            `Unlockable "${item.title}" is flagged as safety content and must not be gated.`,
          );
        }
        return false;
      }
      return true;
    })
    .map((item) => {
      const levelOk = balance.level >= item.requiredLevel;
      const coinsOk = balance.earnedTotal >= item.requiredCoins;
      return {
        ...item,
        isUnlocked: levelOk && coinsOk,
        blockedBy: !levelOk ? 'level' : !coinsOk ? 'coins' : null,
      };
    });
}

// -----------------------------------------------------------------------------
// Redemption
// -----------------------------------------------------------------------------

/**
 * Spending coins on an admin-curated real-world reward.
 *
 * This is the ONLY place coins map to anything of real value, and it is one-way:
 * coins out, never money in. There is no inverse function.
 */
export function buildRedemption(
  catalogItemId: string,
  title: string,
  coinCost: number,
  userId: string,
  requestNonce: string,
): CoinAward {
  return {
    delta: -Math.abs(coinCost),
    reason: `Redeemed: ${title}`,
    sourceType: 'redemption',
    sourceId: catalogItemId,
    // The nonce comes from the client's redemption request, so a double-tap
    // cannot spend twice, but a genuine second redemption later still can.
    idempotencyKey: `redeem:${userId}:${catalogItemId}:${requestNonce}`,
  };
}
