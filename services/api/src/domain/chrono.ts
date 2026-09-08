/**
 * =============================================================================
 * VYRA CHRONO ENGINE
 * =============================================================================
 * The core of the product. Turns a user's declared timetable into:
 *
 *   1. Dead-Time Detection      real, usable movement windows in their day
 *   2. Adaptive Capacity Goal   a daily goal scaled to the time they actually have
 *   3. Effort Ratio             achievement measured against THEIR day, not a
 *                               fixed 10,000-step standard
 *
 * Why this is deterministic and not an LLM call:
 *   - It is interval arithmetic. An LLM would be slower, costlier, non-reproducible
 *     and occasionally wrong about a user's sleep window, which is unacceptable.
 *   - Every scheduling decision must be explainable to the user ("we picked 4:15pm
 *     because it is a 22-minute gap between your class and coaching"). Deterministic
 *     rules can produce that sentence; a black box cannot.
 *
 * This module is intentionally PURE: no database, no clock, no I/O. Everything it
 * needs is passed in. That is what makes it unit-testable and what lets the same
 * code run on-device for offline planning.
 * =============================================================================
 */

import type { BlockType, FitnessGoal, FreeWindow, ISODate } from '@vyra/types';

// -----------------------------------------------------------------------------
// Configuration — the single source of truth for scheduling behaviour
// -----------------------------------------------------------------------------
export interface ChronoConfig {
  /** Shortest gap worth offering a session in. Below this, changing clothes costs more than the workout. */
  minWindowMin: number;
  /** Breathing room kept on each side of a commitment, so we never make someone late. */
  bufferMin: number;
  /** Longest single micro-session. Beyond this it stops being "micro" and gets skipped. */
  maxMicroSessionMin: number;
  /**
   * Most movements in one session.
   *
   * Without this the filler is time-correct and useless: a 25-minute window once
   * produced a "session" of twenty-one different exercises, because each one fit
   * in the remaining seconds. A session is a handful of movements you repeat,
   * not a list you read.
   */
  maxExercisesPerSession: number;
  /** Never notify inside these declared block types. Not a user setting — a hard rule. */
  protectedBlockTypes: readonly BlockType[];
  /** Enforced even when the user declared no sleep block, so we cannot wake anyone. */
  quietHours: { start: string; end: string };
  /**
   * Suitability-weighted free minutes that constitute a "full" day of movement
   * opportunity. Both the denominator of capacityFactor and the cap on capacity.
   * 90, not 1440: having a free day does not mean 24 usable hours of exercise,
   * and beyond ~90 minutes of opportunity the constraint stops being time.
   */
  referenceCapacityMin: number;
  /** Floor on capacityFactor. Even the busiest user gets a real, non-trivial goal. */
  minCapacityFactor: number;
  /** No goal below this — a 3-minute goal is not a goal. */
  absoluteMinGoalMin: number;
  /** A window ending this close to sleep onset is penalised (late exercise disrupts sleep). */
  preSleepPenaltyWindowMin: number;
  preSleepPenaltyFactor: number;
  /** Missed work is spread across at most this many upcoming open days. */
  rebalanceSpreadDays: number;
  /** A rebalance never pushes any single day past this absolute load. */
  maxDailyLoadMin: number;
  /** ...nor past this multiple of that day's own original load. */
  maxDailyLoadMultiplier: number;
}

export const DEFAULT_CHRONO_CONFIG: ChronoConfig = {
  minWindowMin: 10,
  bufferMin: 5,
  maxMicroSessionMin: 25,
  maxExercisesPerSession: 6,
  protectedBlockTypes: ['sleep', 'class'],
  quietHours: { start: '22:30', end: '06:30' },
  referenceCapacityMin: 90,
  minCapacityFactor: 0.4,
  absoluteMinGoalMin: 10,
  preSleepPenaltyWindowMin: 60,
  preSleepPenaltyFactor: 0.5,
  rebalanceSpreadDays: 4,
  maxDailyLoadMin: 60,
  maxDailyLoadMultiplier: 1.5,
};

/**
 * Ideal daily movement target per goal, in minutes.
 * Anchored to WHO guidance: 150-300 min of moderate activity per week
 * (~22-43 min/day). We do not invent aggressive targets.
 */
export const IDEAL_TARGET_MIN: Partial<Record<FitnessGoal, number>> = {
  lose_weight: 40,
  gain_weight: 35,
  maintain: 30,
  general_wellness: 25,
};

// -----------------------------------------------------------------------------
// Time helpers — minutes-since-midnight is the internal representation.
// 'HH:mm' strings only exist at the boundary.
// -----------------------------------------------------------------------------
export const MINUTES_IN_DAY = 1440;

export function timeToMin(hhmm: string): number {
  const parts = hhmm.split(':');
  const h = Number(parts[0]);
  const m = Number(parts[1] ?? '0');
  if (!Number.isInteger(h) || !Number.isInteger(m) || h < 0 || h > 24 || m < 0 || m > 59) {
    throw new RangeError(`Invalid time '${hhmm}'`);
  }
  return h * 60 + m;
}

export function minToTime(min: number): string {
  const clamped = Math.max(0, Math.min(MINUTES_IN_DAY, Math.round(min)));
  const h = Math.floor(clamped / 60);
  const m = clamped % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}

function clamp(v: number, lo: number, hi: number): number {
  return Math.max(lo, Math.min(hi, v));
}

// -----------------------------------------------------------------------------
// Block normalisation
// -----------------------------------------------------------------------------
export interface EngineBlock {
  weekday: number;   // 0 = Monday .. 6 = Sunday
  startMin: number;
  endMin: number;
  blockType: BlockType;
  label?: string;
}

export interface RawBlock {
  weekday: number;
  blockStart: string;
  blockEnd: string;
  blockType: BlockType;
  label?: string;
}

/**
 * Converts client input into engine blocks, splitting anything that crosses
 * midnight into two same-shape blocks on consecutive weekdays.
 *
 * A sleep window of 23:00 -> 06:30 is the normal case, not an edge case:
 * it becomes (day d, 23:00-24:00) and (day d+1, 00:00-06:30). The database
 * CHECK (block_end > block_start) is satisfied because we split before insert.
 */
export function expandBlocks(raw: RawBlock[]): EngineBlock[] {
  const out: EngineBlock[] = [];
  for (const b of raw) {
    const startMin = timeToMin(b.blockStart);
    const endMin = timeToMin(b.blockEnd);
    if (endMin === startMin) continue;  // zero-length: ignore rather than throw

    if (endMin > startMin) {
      out.push({ weekday: b.weekday, startMin, endMin, blockType: b.blockType, label: b.label });
    } else {
      // Crosses midnight.
      out.push({ weekday: b.weekday, startMin, endMin: MINUTES_IN_DAY, blockType: b.blockType, label: b.label });
      out.push({ weekday: (b.weekday + 1) % 7, startMin: 0, endMin, blockType: b.blockType, label: b.label });
    }
  }
  return out;
}

/**
 * Merges overlapping and touching busy blocks for one weekday.
 * Two back-to-back classes with no gap must not produce a phantom 0-minute window.
 */
export function mergeBusyBlocks(blocks: EngineBlock[]): Array<{ startMin: number; endMin: number }> {
  const busy = blocks
    .filter((b) => b.blockType !== 'free')
    .map((b) => ({ startMin: b.startMin, endMin: b.endMin }))
    .sort((a, b) => a.startMin - b.startMin || a.endMin - b.endMin);

  const merged: Array<{ startMin: number; endMin: number }> = [];
  for (const b of busy) {
    const last = merged[merged.length - 1];
    if (last && b.startMin <= last.endMin) {
      last.endMin = Math.max(last.endMin, b.endMin);
    } else {
      merged.push({ ...b });
    }
  }
  return merged;
}

// -----------------------------------------------------------------------------
// Suitability scoring
// -----------------------------------------------------------------------------
/**
 * How good a given time of day is for movement, 0..1, keyed on the window midpoint.
 *
 * Rationale for the shape of this curve:
 *   - 06:30-09:00 and 17:00-20:00 score highest. Late afternoon is when core
 *     temperature and muscle performance peak; early morning has the strongest
 *     habit-adherence evidence.
 *   - 13:00-14:30 scores low: the post-prandial period is when vigorous movement
 *     is least comfortable.
 *   - After 21:30 scores very low: exercise close to bedtime disrupts sleep onset,
 *     and sleep is a health outcome we refuse to trade away for a streak.
 */
export function timeOfDayScore(midpointMin: number): number {
  const bands: Array<[number, number, number]> = [
    [timeToMin('05:00'), timeToMin('06:30'), 0.75],
    [timeToMin('06:30'), timeToMin('09:00'), 1.00],
    [timeToMin('09:00'), timeToMin('12:00'), 0.85],
    [timeToMin('12:00'), timeToMin('13:00'), 0.70],
    [timeToMin('13:00'), timeToMin('14:30'), 0.35],
    [timeToMin('14:30'), timeToMin('17:00'), 0.80],
    [timeToMin('17:00'), timeToMin('20:00'), 1.00],
    [timeToMin('20:00'), timeToMin('21:30'), 0.60],
    [timeToMin('21:30'), timeToMin('23:00'), 0.30],
  ];
  for (const band of bands) {
    if (midpointMin >= band[0] && midpointMin < band[1]) return band[2];
  }
  return 0.10;  // deep night
}

/**
 * Longer windows are worth slightly more, saturating at maxMicroSessionMin.
 * A 25-minute gap is far more useful than a 10-minute one; a 3-hour gap is not
 * meaningfully better than 25 minutes, because we are scheduling a micro-session.
 */
export function durationScore(durationMin: number, cfg: ChronoConfig): number {
  const usable = Math.min(durationMin, cfg.maxMicroSessionMin);
  const span = cfg.maxMicroSessionMin - cfg.minWindowMin;
  if (span <= 0) return 1;
  return clamp(0.6 + 0.4 * ((usable - cfg.minWindowMin) / span), 0.6, 1);
}

// -----------------------------------------------------------------------------
// 1. DEAD-TIME DETECTION
// -----------------------------------------------------------------------------
export interface DetectedWindow extends FreeWindow {
  startMin: number;
  endMin: number;
  /** Minutes we would actually schedule here (window minus buffers, capped). */
  usableMin: number;
  /** Human-readable justification, surfaced in the UI so nothing feels arbitrary. */
  rationale: string;
}

/**
 * Finds every usable movement window for one weekday.
 *
 * Algorithm:
 *   1. Merge all declared commitments into non-overlapping busy intervals.
 *   2. Take the complement — the gaps.
 *   3. Shrink each gap by a buffer on both sides so we never crowd a commitment.
 *   4. Drop anything shorter than minWindowMin, and anything inside quiet hours.
 *   5. Score what survives and sort best-first.
 */
export function detectFreeWindows(
  blocks: EngineBlock[],
  weekday: number,
  cfg: ChronoConfig = DEFAULT_CHRONO_CONFIG,
): DetectedWindow[] {
  const dayBlocks = blocks.filter((b) => b.weekday === weekday);
  const busy = mergeBusyBlocks(dayBlocks);

  // Quiet hours are treated as busy even if the user declared no sleep block,
  // so the engine can never propose a 3am session.
  const quietStart = timeToMin(cfg.quietHours.start);
  const quietEnd = timeToMin(cfg.quietHours.end);
  const quietIntervals =
    quietStart > quietEnd
      ? [{ startMin: quietStart, endMin: MINUTES_IN_DAY }, { startMin: 0, endMin: quietEnd }]
      : [{ startMin: quietStart, endMin: quietEnd }];

  const allBusy = mergeBusyBlocks(
    [...busy, ...quietIntervals].map((b) => ({
      weekday,
      startMin: b.startMin,
      endMin: b.endMin,
      blockType: 'work' as BlockType,
    })),
  );

  // Complement of the busy set.
  const gaps: Array<{ startMin: number; endMin: number }> = [];
  let cursor = 0;
  for (const b of allBusy) {
    if (b.startMin > cursor) gaps.push({ startMin: cursor, endMin: b.startMin });
    cursor = Math.max(cursor, b.endMin);
  }
  if (cursor < MINUTES_IN_DAY) gaps.push({ startMin: cursor, endMin: MINUTES_IN_DAY });

  // Sleep onset, used for the pre-sleep penalty.
  const sleepBlocks = dayBlocks.filter((b) => b.blockType === 'sleep' && b.startMin > timeToMin('12:00'));
  const sleepOnsetMin = sleepBlocks.length
    ? Math.min(...sleepBlocks.map((b) => b.startMin))
    : quietStart;

  const windows: DetectedWindow[] = [];
  for (const gap of gaps) {
    // Buffer only against a real commitment, not against the start/end of the day.
    const bufferedStart = gap.startMin === 0 ? gap.startMin : gap.startMin + cfg.bufferMin;
    const bufferedEnd = gap.endMin === MINUTES_IN_DAY ? gap.endMin : gap.endMin - cfg.bufferMin;
    const durationMin = bufferedEnd - bufferedStart;
    if (durationMin < cfg.minWindowMin) continue;

    const midpoint = bufferedStart + durationMin / 2;
    let score = timeOfDayScore(midpoint) * durationScore(durationMin, cfg);

    let penalised = false;
    if (bufferedEnd > sleepOnsetMin - cfg.preSleepPenaltyWindowMin && bufferedStart < sleepOnsetMin) {
      score *= cfg.preSleepPenaltyFactor;
      penalised = true;
    }

    const usableMin = Math.min(durationMin, cfg.maxMicroSessionMin);
    windows.push({
      weekday,
      start: minToTime(bufferedStart),
      end: minToTime(bufferedEnd),
      startMin: bufferedStart,
      endMin: bufferedEnd,
      durationMin,
      usableMin,
      suitability: Math.round(score * 1000) / 1000,
      rationale: buildRationale(durationMin, midpoint, penalised),
    });
  }

  return windows.sort((a, b) => b.suitability - a.suitability || b.durationMin - a.durationMin);
}

function buildRationale(durationMin: number, midpointMin: number, preSleepPenalised: boolean): string {
  const when = minToTime(midpointMin);
  if (preSleepPenalised) {
    return `${durationMin} free minutes around ${when}, but close to your bedtime — we kept this as a backup and will suggest something gentle.`;
  }
  const tod = timeOfDayScore(midpointMin);
  if (tod >= 1) return `${durationMin} free minutes around ${when} — one of the best times of day for your body to move.`;
  if (tod >= 0.8) return `${durationMin} free minutes around ${when} — a good, workable slot.`;
  if (tod >= 0.5) return `${durationMin} free minutes around ${when} — usable, though not your strongest slot.`;
  return `${durationMin} free minutes around ${when} — right after eating, so we will keep it light.`;
}

/** Convenience: windows for all seven weekdays. */
export function detectWeeklyWindows(
  blocks: EngineBlock[],
  cfg: ChronoConfig = DEFAULT_CHRONO_CONFIG,
): Record<number, DetectedWindow[]> {
  const out: Record<number, DetectedWindow[]> = {};
  for (let d = 0; d < 7; d++) out[d] = detectFreeWindows(blocks, d, cfg);
  return out;
}

// -----------------------------------------------------------------------------
// 2. ADAPTIVE CAPACITY GOAL
// -----------------------------------------------------------------------------
export interface CapacityAssessment {
  weekday: number;
  /** Realistically usable movement minutes available today. */
  capacityMin: number;
  /** capacityMin / referenceCapacityMin, floored so nobody gets a trivial goal. */
  capacityFactor: number;
  /** The unadjusted, goal-derived target. */
  idealTargetMin: number;
  /** What we actually ask of this user today. */
  dailyGoalMin: number;
  windowCount: number;
  /** Plain-language explanation shown in the app. Transparency is the point. */
  explanation: string;
}

/**
 * The fairness mechanism.
 *
 * A student with 30 usable minutes and a person with 4 free hours must not receive
 * the same goal. Absolute goals do exactly that, and it is why time-poor users
 * churn out of fitness apps. Here the goal is a function of the day the user
 * actually has.
 *
 * Capacity is computed as SUITABILITY-WEIGHTED total free minutes, capped at
 * referenceCapacityMin:
 *
 *   contribution(w) = w.durationMin x (0.5 + 0.5 x w.suitability)
 *   capacityMin     = min(sum of contributions, referenceCapacityMin)
 *
 * Two deliberate choices here, both learned the hard way:
 *
 *   - We do NOT cap each window at maxMicroSessionMin. An earlier version did,
 *     and it inverted the whole mechanism: a completely free user has ONE huge
 *     window (capped to 25) while a busy student has THREE fragments (25+25+20),
 *     so the free user appeared to have LESS capacity and received a SMALLER goal.
 *     Per-window caps belong to session placement, not to capacity measurement.
 *     (See the `chrono_capacity_ordering` test, which locks this in.)
 *
 *   - Free minutes are weighted by suitability, so a day whose only gap is 10pm
 *     yields less capacity than the same gap at 6pm. Time that exists but is a
 *     poor time to train is not fully counted.
 */
export function assessCapacity(
  windows: DetectedWindow[],
  fitnessGoal: FitnessGoal,
  cfg: ChronoConfig = DEFAULT_CHRONO_CONFIG,
): CapacityAssessment {
  const weightedMin = windows.reduce(
    (sum, w) => sum + w.durationMin * (0.5 + 0.5 * w.suitability),
    0,
  );
  const capacityMin = Math.round(Math.min(weightedMin, cfg.referenceCapacityMin));

  const rawFactor = capacityMin / cfg.referenceCapacityMin;
  const capacityFactor = Math.round(clamp(rawFactor, cfg.minCapacityFactor, 1) * 1000) / 1000;

  const idealTargetMin = IDEAL_TARGET_MIN[fitnessGoal] ?? 30;
  const dailyGoalMin = Math.max(cfg.absoluteMinGoalMin, Math.round(idealTargetMin * capacityFactor));

  const weekday = windows[0]?.weekday ?? 0;

  let explanation: string;
  if (capacityMin === 0) {
    explanation =
      'Your schedule leaves no usable gap today, so this is a rest day. That is a legitimate part of training, not a failure.';
  } else if (capacityFactor >= 1) {
    explanation = `You have about ${capacityMin} usable minutes today — a full day, so this is your full ${dailyGoalMin}-minute target.`;
  } else {
    explanation =
      `Your day only has about ${capacityMin} usable minutes, so today's goal is ${dailyGoalMin} minutes ` +
      `instead of ${idealTargetMin}. Scaled to your real schedule — hitting this counts every bit as much.`;
  }

  return {
    weekday,
    capacityMin,
    capacityFactor,
    idealTargetMin,
    dailyGoalMin: capacityMin === 0 ? 0 : dailyGoalMin,
    windowCount: windows.length,
    explanation,
  };
}

// -----------------------------------------------------------------------------
// 3. EFFORT RATIO — the ranking mechanism
// -----------------------------------------------------------------------------
export interface EffortResult {
  achievedMin: number;
  goalMin: number;
  /** achieved / goal, uncapped so genuine overachievement is still visible. */
  effortRatio: number;
  /** Ratio used for points, capped so one enormous day cannot dominate a season. */
  scoringRatio: number;
  met: boolean;
  label: 'rest_day' | 'missed' | 'partial' | 'met' | 'exceeded';
}

export const EFFORT_SCORING_CAP = 1.5;

/**
 * Measures a day against THIS user's goal, not against a global standard.
 *
 * This is what lets a student with 30 free minutes outrank a user with all day
 * free: the student who used 27 of 30 minutes scores 0.90, while the free user
 * who did 45 of 40 minutes scores 1.13 — but across a week, the student's
 * consistency multiplier compounds while the sporadic user's does not.
 */
export function computeEffort(achievedMin: number, goalMin: number): EffortResult {
  if (goalMin <= 0) {
    return {
      achievedMin,
      goalMin: 0,
      effortRatio: 0,
      scoringRatio: 0,
      met: true,
      label: 'rest_day',
    };
  }
  const effortRatio = Math.round((achievedMin / goalMin) * 1000) / 1000;
  const scoringRatio = Math.min(effortRatio, EFFORT_SCORING_CAP);

  let label: EffortResult['label'];
  if (achievedMin <= 0) label = 'missed';
  else if (effortRatio < 0.8) label = 'partial';
  else if (effortRatio < 1.05) label = 'met';
  else label = 'exceeded';

  return { achievedMin, goalMin, effortRatio, scoringRatio, met: effortRatio >= 0.8, label };
}

export const CONSISTENCY_WEIGHT = 0.5;

/**
 * Weekly activity points.
 *
 *   rawPoints   = sum of daily effort ratios (capped) x base points
 *   consistency = 1 + weight x activeDays / periodDays
 *   final       = rawPoints x consistency
 *
 * Seven 20-minute sessions beat one 140-minute session, because the former builds
 * a habit and the latter builds an anecdote.
 */
export function computeActivityPoints(
  dailyEfforts: EffortResult[],
  basePointsPerDay = 50,
  weight = CONSISTENCY_WEIGHT,
): { rawPoints: number; consistencyFactor: number; activityPoints: number; activeDays: number } {
  const scoringDays = dailyEfforts.filter((e) => e.label !== 'rest_day');
  const periodDays = Math.max(1, scoringDays.length);
  const activeDays = scoringDays.filter((e) => e.achievedMin > 0).length;

  const rawPoints = Math.round(
    scoringDays.reduce((sum, e) => sum + e.scoringRatio * basePointsPerDay, 0),
  );
  const consistencyFactor = Math.round((1 + weight * (activeDays / periodDays)) * 1000) / 1000;

  return {
    rawPoints,
    consistencyFactor,
    activityPoints: Math.round(rawPoints * consistencyFactor),
    activeDays,
  };
}

// -----------------------------------------------------------------------------
// 4. SESSION PLACEMENT
// -----------------------------------------------------------------------------
export interface PlaceableExercise {
  id: string;
  name: string;
  durationSec: number;
  /** Intensity 1-3. Post-meal and pre-sleep windows only receive intensity 1. */
  intensity: 1 | 2 | 3;
  isLowImpact: boolean;
}

export interface PlacedSession {
  window: DetectedWindow;
  exercises: PlaceableExercise[];
  /** How many times the exercise list is repeated to fill the window. */
  rounds: number;
  totalMin: number;
  /** Why these moves, in this window — shown to the user. */
  rationale: string;
}

/**
 * Fills the best windows with exercises until the daily goal is covered.
 *
 * Deliberately greedy and boring: highest-suitability window first, fill it,
 * move on. Predictability matters more than optimality here — a user needs to
 * trust that tomorrow looks like today.
 *
 * Safety rule: low-suitability windows (post-meal, pre-sleep) receive only
 * low-intensity, low-impact work. We never place burpees at 10pm.
 */
export function placeSessions(
  windows: DetectedWindow[],
  pool: PlaceableExercise[],
  goalMin: number,
  cfg: ChronoConfig = DEFAULT_CHRONO_CONFIG,
): PlacedSession[] {
  if (goalMin <= 0 || windows.length === 0 || pool.length === 0) return [];

  const sessions: PlacedSession[] = [];
  let remainingMin = goalMin;
  const used = new Set<string>();

  for (const window of windows) {
    if (remainingMin <= 0) break;

    const gentleOnly = window.suitability < 0.5;
    const candidates = pool.filter(
      (e) => !used.has(e.id) && (!gentleOnly || (e.intensity === 1 && e.isLowImpact)),
    );
    if (candidates.length === 0) continue;

    const budgetMin = Math.min(window.usableMin, remainingMin, cfg.maxMicroSessionMin);
    const chosen: PlaceableExercise[] = [];
    let filledSec = 0;

    for (const exercise of candidates) {
      if (chosen.length >= cfg.maxExercisesPerSession) break;
      const nextSec = filledSec + exercise.durationSec;
      if (nextSec / 60 > budgetMin) continue;
      chosen.push(exercise);
      used.add(exercise.id);
      filledSec = nextSec;
      if (filledSec / 60 >= budgetMin - 1) break;
    }

    // A short list of movements is meant to be repeated. Rounds are how a
    // six-exercise set fills a twenty-five minute window without becoming
    // twenty-one different exercises.
    const roundSec = filledSec;
    let rounds = 1;
    while (roundSec > 0 && ((rounds + 1) * roundSec) / 60 <= budgetMin) rounds++;
    filledSec = roundSec * rounds;

    if (chosen.length === 0) continue;

    const totalMin = Math.round((filledSec / 60) * 10) / 10;
    remainingMin = Math.round((remainingMin - totalMin) * 10) / 10;

    const roundText = rounds > 1 ? ` — ${chosen.length} moves, ${rounds} rounds` : '';
    sessions.push({
      window,
      exercises: chosen,
      rounds,
      totalMin,
      rationale: gentleOnly
        ? `${totalMin} gentle minutes at ${window.start}${roundText}. Kept light because of the time of day.`
        : `${totalMin} minutes in your ${window.durationMin}-minute gap at ${window.start}${roundText}.`,
    });
  }

  return sessions;
}

// -----------------------------------------------------------------------------
// 5. MISSED-WORKOUT REBALANCING
// -----------------------------------------------------------------------------
export interface RebalanceCandidateDay {
  date: ISODate;
  weekday: number;
  /** Minutes already planned for this day. */
  existingLoadMin: number;
  /** Capacity from the Chrono Engine for that weekday. */
  capacityMin: number;
}

export interface RebalanceItem {
  exerciseId: string;
  name: string;
  durationMin: number;
}

export interface RebalancePlan {
  missedDate: ISODate;
  assignments: Array<{
    date: ISODate;
    items: RebalanceItem[];
    previousLoadMin: number;
    newLoadMin: number;
  }>;
  /** Items that genuinely did not fit anywhere. We drop them honestly rather than cram. */
  dropped: RebalanceItem[];
  warnings: string[];
}

/**
 * Redistributes a missed day across the next few open days.
 *
 * Hard constraints, all of which exist to protect the user from the app:
 *   - never exceed maxDailyLoadMin on any day
 *   - never exceed maxDailyLoadMultiplier x that day's own original load
 *   - never exceed that day's Chrono capacity (the time genuinely does not exist)
 *   - spread across at most rebalanceSpreadDays days
 *
 * Anything that will not fit is DROPPED and reported, never crammed in. Piling a
 * missed day onto tomorrow is how injuries and quitting happen; the honest move is
 * to tell the user some of it is gone and that this is fine.
 *
 * Longest items are placed first (classic bin-packing first-fit-decreasing) because
 * a 15-minute block is much harder to place late than three 5-minute ones.
 */
export function rebalanceMissedWorkout(
  missedDate: ISODate,
  items: RebalanceItem[],
  candidateDays: RebalanceCandidateDay[],
  cfg: ChronoConfig = DEFAULT_CHRONO_CONFIG,
): RebalancePlan {
  const warnings: string[] = [];
  const days = candidateDays.slice(0, cfg.rebalanceSpreadDays).map((d) => ({
    ...d,
    addedMin: 0,
    items: [] as RebalanceItem[],
  }));

  if (days.length === 0) {
    return {
      missedDate,
      assignments: [],
      dropped: [...items],
      warnings: ['No open days available in the next few days, so nothing was rescheduled.'],
    };
  }

  const capacityFor = (d: (typeof days)[number]) => {
    const multiplierCap = d.existingLoadMin > 0
      ? d.existingLoadMin * cfg.maxDailyLoadMultiplier
      : cfg.maxDailyLoadMin;
    return Math.max(
      0,
      Math.min(cfg.maxDailyLoadMin, multiplierCap, d.capacityMin) - d.existingLoadMin - d.addedMin,
    );
  };

  const sorted = [...items].sort((a, b) => b.durationMin - a.durationMin);
  const dropped: RebalanceItem[] = [];

  for (const item of sorted) {
    // Place into the day with the most remaining headroom — keeps the load even.
    const target = days
      .filter((d) => capacityFor(d) >= item.durationMin)
      .sort((a, b) => capacityFor(b) - capacityFor(a))[0];

    if (!target) {
      dropped.push(item);
      continue;
    }
    target.items.push(item);
    target.addedMin += item.durationMin;
  }

  if (dropped.length > 0) {
    const droppedMin = dropped.reduce((s, i) => s + i.durationMin, 0);
    warnings.push(
      `${dropped.length} exercise${dropped.length > 1 ? 's' : ''} (${droppedMin} min) did not fit in your ` +
        `next few days, so we let them go rather than overload you. Missing some of a session is normal.`,
    );
  }

  const assignments = days
    .filter((d) => d.items.length > 0)
    .map((d) => ({
      date: d.date,
      items: d.items,
      previousLoadMin: d.existingLoadMin,
      newLoadMin: d.existingLoadMin + d.addedMin,
    }));

  if (assignments.length > 0) {
    warnings.push(
      `Spread across ${assignments.length} day${assignments.length > 1 ? 's' : ''}. ` +
        `No single day was increased by more than ${Math.round((cfg.maxDailyLoadMultiplier - 1) * 100)}%.`,
    );
  }

  return { missedDate, assignments, dropped, warnings };
}

// -----------------------------------------------------------------------------
// 6. NOTIFICATION SAFETY
// -----------------------------------------------------------------------------
/**
 * Structural guard: is it legal to notify this user at this moment?
 *
 * This is enforced in the scheduler, not offered as a user preference, because
 * "do not wake me at 2am" should not be something a user has to discover in
 * settings after being woken at 2am.
 */
export function isNotifiableAt(
  blocks: EngineBlock[],
  weekday: number,
  atMin: number,
  cfg: ChronoConfig = DEFAULT_CHRONO_CONFIG,
): { allowed: boolean; reason?: string } {
  const quietStart = timeToMin(cfg.quietHours.start);
  const quietEnd = timeToMin(cfg.quietHours.end);
  const inQuiet = quietStart > quietEnd
    ? atMin >= quietStart || atMin < quietEnd
    : atMin >= quietStart && atMin < quietEnd;
  if (inQuiet) return { allowed: false, reason: 'quiet_hours' };

  for (const b of blocks) {
    if (b.weekday !== weekday) continue;
    if (!cfg.protectedBlockTypes.includes(b.blockType)) continue;
    if (atMin >= b.startMin && atMin < b.endMin) {
      return { allowed: false, reason: `inside_${b.blockType}_block` };
    }
  }
  return { allowed: true };
}
