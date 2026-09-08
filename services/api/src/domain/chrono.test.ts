/**
 * Chrono Engine tests.
 *
 * These are not decoration. The engine encodes VYRA's central product claim, so
 * each test locks in a behaviour we would be embarrassed to get wrong in a demo.
 *
 * Run: pnpm --filter @vyra/api test
 */
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

import {
  DEFAULT_CHRONO_CONFIG,
  assessCapacity,
  computeActivityPoints,
  computeEffort,
  detectFreeWindows,
  expandBlocks,
  isNotifiableAt,
  mergeBusyBlocks,
  minToTime,
  placeSessions,
  rebalanceMissedWorkout,
  timeOfDayScore,
  timeToMin,
  type EngineBlock,
  type PlaceableExercise,
  type RawBlock,
} from './chrono';

// ---------------------------------------------------------------------------
// Fixtures — three real Indian daily realities
// ---------------------------------------------------------------------------

/** A Class-12 student: school, commute, coaching, study. Genuinely time-poor. */
const CRUSHED_STUDENT: RawBlock[] = [
  { weekday: 0, blockStart: '22:30', blockEnd: '06:00', blockType: 'sleep' },
  { weekday: 0, blockStart: '06:30', blockEnd: '07:15', blockType: 'commute' },
  { weekday: 0, blockStart: '07:15', blockEnd: '14:30', blockType: 'class' },
  { weekday: 0, blockStart: '14:30', blockEnd: '15:30', blockType: 'commute' },
  { weekday: 0, blockStart: '16:00', blockEnd: '20:30', blockType: 'class', label: 'Coaching' },
  { weekday: 0, blockStart: '20:30', blockEnd: '22:15', blockType: 'work', label: 'Homework' },
];

/** A college student: classes, but real gaps. Moderately busy. */
const BUSY_STUDENT: RawBlock[] = [
  { weekday: 0, blockStart: '23:00', blockEnd: '07:00', blockType: 'sleep' },
  { weekday: 0, blockStart: '09:00', blockEnd: '13:00', blockType: 'class' },
  { weekday: 0, blockStart: '14:00', blockEnd: '17:00', blockType: 'class' },
];

/** Someone with an open day. */
const FREE_USER: RawBlock[] = [
  { weekday: 0, blockStart: '23:00', blockEnd: '07:00', blockType: 'sleep' },
];

/**
 * Sleep declared on the PREVIOUS day, which wraps into Monday morning.
 * Without this, Monday 00:00-07:00 is only covered by quiet hours (which end at
 * 06:30), leaving a real 06:30-07:00 gap. That is correct engine behaviour — the
 * user simply never told us they were asleep — so fixtures modelling a full day
 * must declare Sunday night too.
 */
const SUNDAY_NIGHT_SLEEP: RawBlock = {
  weekday: 6, blockStart: '22:30', blockEnd: '07:00', blockType: 'sleep',
};

/** A day with only one 12-minute gap — too short to be usable after buffers. */
const TIGHT_DAY: RawBlock[] = [
  SUNDAY_NIGHT_SLEEP,
  { weekday: 0, blockStart: '22:30', blockEnd: '07:00', blockType: 'sleep' },
  { weekday: 0, blockStart: '07:00', blockEnd: '12:00', blockType: 'class' },
  { weekday: 0, blockStart: '12:12', blockEnd: '22:30', blockType: 'work' },
];

/** A day whose only free time sits right before bedtime. */
const LATE_ONLY_DAY: RawBlock[] = [
  { weekday: 6, blockStart: '23:00', blockEnd: '07:00', blockType: 'sleep' },
  { weekday: 0, blockStart: '23:00', blockEnd: '07:00', blockType: 'sleep' },
  { weekday: 0, blockStart: '07:00', blockEnd: '21:40', blockType: 'work' },
];

const POOL: PlaceableExercise[] = [
  { id: 'e1', name: 'Jumping Jacks', durationSec: 300, intensity: 3, isLowImpact: false },
  { id: 'e2', name: 'Bodyweight Squats', durationSec: 300, intensity: 2, isLowImpact: false },
  { id: 'e3', name: 'Plank', durationSec: 180, intensity: 2, isLowImpact: true },
  { id: 'e4', name: 'Cat-Cow Stretch', durationSec: 240, intensity: 1, isLowImpact: true },
  { id: 'e5', name: 'Seated Neck Release', durationSec: 180, intensity: 1, isLowImpact: true },
  { id: 'e6', name: 'Burpees', durationSec: 420, intensity: 3, isLowImpact: false },
];

// ---------------------------------------------------------------------------
describe('time helpers', () => {
  it('converts both ways without drift', () => {
    assert.equal(timeToMin('00:00'), 0);
    assert.equal(timeToMin('06:30'), 390);
    assert.equal(timeToMin('24:00'), 1440);
    assert.equal(minToTime(390), '06:30');
    assert.equal(minToTime(1440), '24:00');
  });

  it('rejects malformed input rather than silently guessing', () => {
    assert.throws(() => timeToMin('25:00'), RangeError);
    assert.throws(() => timeToMin('ab:cd'), RangeError);
  });
});

// ---------------------------------------------------------------------------
describe('block expansion', () => {
  it('splits a midnight-crossing sleep block across two weekdays', () => {
    const blocks = expandBlocks([
      { weekday: 0, blockStart: '23:00', blockEnd: '06:30', blockType: 'sleep' },
    ]);
    assert.equal(blocks.length, 2);
    assert.deepEqual(
      blocks.map((b) => [b.weekday, b.startMin, b.endMin]),
      [
        [0, timeToMin('23:00'), 1440],
        [1, 0, timeToMin('06:30')],
      ],
    );
  });

  it('wraps Sunday sleep onto Monday', () => {
    const blocks = expandBlocks([
      { weekday: 6, blockStart: '23:30', blockEnd: '07:00', blockType: 'sleep' },
    ]);
    assert.equal(blocks[1]!.weekday, 0);
  });

  it('merges back-to-back classes so no phantom zero-length gap appears', () => {
    const merged = mergeBusyBlocks([
      { weekday: 0, startMin: 540, endMin: 600, blockType: 'class' },
      { weekday: 0, startMin: 600, endMin: 660, blockType: 'class' },
      { weekday: 0, startMin: 650, endMin: 700, blockType: 'work' },
    ]);
    assert.deepEqual(merged, [{ startMin: 540, endMin: 700 }]);
  });
});

// ---------------------------------------------------------------------------
describe('time-of-day suitability curve', () => {
  it('rates early evening and early morning highest', () => {
    assert.equal(timeOfDayScore(timeToMin('07:30')), 1);
    assert.equal(timeOfDayScore(timeToMin('18:00')), 1);
  });

  it('rates the post-lunch window low', () => {
    assert.ok(timeOfDayScore(timeToMin('13:30')) < 0.5);
  });

  it('rates late night near zero, because sleep is not negotiable', () => {
    assert.ok(timeOfDayScore(timeToMin('02:00')) <= 0.1);
    assert.ok(timeOfDayScore(timeToMin('22:00')) <= 0.3);
  });
});

// ---------------------------------------------------------------------------
describe('dead-time detection', () => {
  it('finds real gaps for a college student', () => {
    const windows = detectFreeWindows(expandBlocks(BUSY_STUDENT), 0);
    assert.ok(windows.length >= 2, 'expected at least two usable windows');

    // The 13:00-14:00 lunch gap should be found, buffered to 13:05-13:55.
    const lunchGap = windows.find((w) => w.start === '13:05');
    assert.ok(lunchGap, 'lunch gap not detected');
    assert.equal(lunchGap!.end, '13:55');
    assert.equal(lunchGap!.durationMin, 50);
  });

  it('never proposes a window inside quiet hours', () => {
    const windows = detectFreeWindows(expandBlocks(FREE_USER), 0);
    const quietStart = timeToMin(DEFAULT_CHRONO_CONFIG.quietHours.start);
    const quietEnd = timeToMin(DEFAULT_CHRONO_CONFIG.quietHours.end);
    for (const w of windows) {
      assert.ok(w.startMin >= quietEnd, `window ${w.start} starts before quiet hours end`);
      assert.ok(w.endMin <= quietStart, `window ${w.end} runs into quiet hours`);
    }
  });

  it('keeps a buffer so a user is never made late for class', () => {
    const windows = detectFreeWindows(expandBlocks(BUSY_STUDENT), 0);
    const beforeFirstClass = windows.find((w) => w.endMin <= timeToMin('09:00'));
    assert.ok(beforeFirstClass);
    assert.equal(beforeFirstClass!.endMin, timeToMin('09:00') - DEFAULT_CHRONO_CONFIG.bufferMin);
  });

  it('drops gaps too short to be worth changing clothes for', () => {
    const windows = detectFreeWindows(expandBlocks(TIGHT_DAY), 0);
    assert.equal(windows.length, 0);
  });

  it('treats an undeclared night as genuinely free time, not as sleep', () => {
    // Without SUNDAY_NIGHT_SLEEP, 06:30-07:00 on Monday is time the user never
    // accounted for. The engine must offer it rather than assume they are asleep —
    // guessing at unstated commitments is how a scheduler loses a user's trust.
    const withoutPriorNight = TIGHT_DAY.filter((b) => b.weekday !== 6);
    const windows = detectFreeWindows(expandBlocks(withoutPriorNight), 0);
    assert.equal(windows.length, 1);
    assert.equal(windows[0]!.start, '06:35');
  });

  it('penalises a window that runs up against bedtime', () => {
    const windows = detectFreeWindows(expandBlocks(LATE_ONLY_DAY), 0);
    assert.equal(windows.length, 1);
    assert.ok(
      windows[0]!.suitability <= 0.35,
      `pre-sleep window should be heavily penalised, got ${windows[0]!.suitability}`,
    );
    assert.match(windows[0]!.rationale, /bedtime/);
  });

  it('returns windows sorted best-first', () => {
    const windows = detectFreeWindows(expandBlocks(BUSY_STUDENT), 0);
    for (let i = 1; i < windows.length; i++) {
      assert.ok(windows[i - 1]!.suitability >= windows[i]!.suitability);
    }
  });

  it('explains every window in plain language', () => {
    for (const w of detectFreeWindows(expandBlocks(BUSY_STUDENT), 0)) {
      assert.ok(w.rationale.length > 20, 'every window must be explainable to the user');
    }
  });
});

// ---------------------------------------------------------------------------
describe('adaptive capacity goal', () => {
  it('gives a crushed student a smaller, achievable goal', () => {
    const w = detectFreeWindows(expandBlocks(CRUSHED_STUDENT), 0);
    const a = assessCapacity(w, 'maintain');
    assert.ok(a.dailyGoalMin > 0, 'a crushed day should still get a real goal');
    assert.ok(
      a.dailyGoalMin < a.idealTargetMin,
      `expected a scaled-down goal, got ${a.dailyGoalMin} vs ideal ${a.idealTargetMin}`,
    );
    assert.ok(a.capacityFactor >= DEFAULT_CHRONO_CONFIG.minCapacityFactor);
  });

  it('gives a free user the full target', () => {
    const w = detectFreeWindows(expandBlocks(FREE_USER), 0);
    const a = assessCapacity(w, 'maintain');
    assert.equal(a.capacityFactor, 1);
    assert.equal(a.dailyGoalMin, a.idealTargetMin);
  });

  /**
   * chrono_capacity_ordering — the regression test for the inversion bug.
   *
   * An earlier version capped each window's contribution at maxMicroSessionMin.
   * That made a free user (one huge window, capped to 25) appear to have LESS
   * capacity than a fragmented busy student (25 + 25 + 20 = 70), so the free user
   * received the SMALLER goal — exactly backwards. Capacity must be monotonic in
   * how much genuinely free, well-timed time a person has.
   */
  it('chrono_capacity_ordering: capacity rises with real free time', () => {
    const crushed = assessCapacity(detectFreeWindows(expandBlocks(CRUSHED_STUDENT), 0), 'maintain');
    const busy = assessCapacity(detectFreeWindows(expandBlocks(BUSY_STUDENT), 0), 'maintain');
    const free = assessCapacity(detectFreeWindows(expandBlocks(FREE_USER), 0), 'maintain');

    assert.ok(
      crushed.capacityMin < busy.capacityMin,
      `crushed (${crushed.capacityMin}) must be below busy (${busy.capacityMin})`,
    );
    assert.ok(
      busy.capacityMin <= free.capacityMin,
      `busy (${busy.capacityMin}) must not exceed free (${free.capacityMin})`,
    );
    assert.ok(crushed.dailyGoalMin <= busy.dailyGoalMin);
    assert.ok(busy.dailyGoalMin <= free.dailyGoalMin);
  });

  it('declares a rest day rather than inventing time that does not exist', () => {
    const noTime: RawBlock[] = [
      { weekday: 0, blockStart: '23:00', blockEnd: '06:00', blockType: 'sleep' },
      { weekday: 0, blockStart: '06:00', blockEnd: '23:00', blockType: 'work' },
    ];
    const a = assessCapacity(detectFreeWindows(expandBlocks(noTime), 0), 'lose_weight');
    assert.equal(a.capacityMin, 0);
    assert.equal(a.dailyGoalMin, 0);
    assert.match(a.explanation, /rest day/);
    assert.match(a.explanation, /not a failure/);
  });

  it('never sets a goal below the absolute floor', () => {
    const w = detectFreeWindows(expandBlocks(CRUSHED_STUDENT), 0);
    const a = assessCapacity(w, 'general_wellness');
    assert.ok(a.dailyGoalMin >= DEFAULT_CHRONO_CONFIG.absoluteMinGoalMin);
  });

  it('explains the scaling in words the user can read', () => {
    const a = assessCapacity(detectFreeWindows(expandBlocks(CRUSHED_STUDENT), 0), 'maintain');
    assert.match(a.explanation, /usable minutes/);
  });
});

// ---------------------------------------------------------------------------
describe('effort ratio', () => {
  it('scores against the user own goal, not a global standard', () => {
    const student = computeEffort(27, 30);   // time-poor, used almost all of it
    const freeUser = computeEffort(45, 40);  // more absolute minutes
    assert.equal(student.label, 'met');
    assert.equal(freeUser.label, 'exceeded');
    assert.ok(student.effortRatio > 0.85);
  });

  it('treats a rest day as met, never as a failure', () => {
    const r = computeEffort(0, 0);
    assert.equal(r.label, 'rest_day');
    assert.equal(r.met, true);
  });

  it('caps the scoring ratio so one heroic day cannot dominate a season', () => {
    const r = computeEffort(300, 20);
    assert.equal(r.effortRatio, 15);
    assert.equal(r.scoringRatio, 1.5);
  });

  it('labels a zero-minute day as missed', () => {
    assert.equal(computeEffort(0, 25).label, 'missed');
  });
});

// ---------------------------------------------------------------------------
describe('activity points', () => {
  /**
   * The behavioural claim, made testable: consistency must beat volume.
   * Both users below did 140 minutes in the week.
   */
  it('ranks a consistent user above a binge user with identical total minutes', () => {
    const consistent = computeActivityPoints(
      Array.from({ length: 7 }, () => computeEffort(20, 20)),
    );
    const binge = computeActivityPoints([
      computeEffort(140, 20),
      ...Array.from({ length: 6 }, () => computeEffort(0, 20)),
    ]);

    assert.ok(
      consistent.activityPoints > binge.activityPoints * 2,
      `consistent ${consistent.activityPoints} should far exceed binge ${binge.activityPoints}`,
    );
    assert.equal(consistent.activeDays, 7);
    assert.equal(binge.activeDays, 1);
  });

  it('does not punish a user for a legitimate rest day', () => {
    const withRest = computeActivityPoints([
      ...Array.from({ length: 6 }, () => computeEffort(20, 20)),
      computeEffort(0, 0), // rest day, excluded from the denominator
    ]);
    assert.equal(withRest.consistencyFactor, 1.5);
  });

  it('gives the maximum consistency factor only for a fully active period', () => {
    const partial = computeActivityPoints([
      computeEffort(20, 20),
      computeEffort(0, 20),
      computeEffort(20, 20),
      computeEffort(0, 20),
    ]);
    assert.equal(partial.consistencyFactor, 1.25);
  });
});

// ---------------------------------------------------------------------------
describe('session placement', () => {
  it('fills the best window first', () => {
    const windows = detectFreeWindows(expandBlocks(BUSY_STUDENT), 0);
    const sessions = placeSessions(windows, POOL, 30);
    assert.ok(sessions.length >= 1);
    assert.equal(sessions[0]!.window.start, windows[0]!.start);
  });

  it('never places high-intensity work in a poor window', () => {
    const windows = detectFreeWindows(expandBlocks(LATE_ONLY_DAY), 0);
    const sessions = placeSessions(windows, POOL, 20);
    for (const s of sessions) {
      for (const e of s.exercises) {
        assert.equal(e.intensity, 1, `${e.name} is too intense for a pre-sleep window`);
        assert.equal(e.isLowImpact, true);
      }
    }
  });

  it('never exceeds the window it was given', () => {
    const windows = detectFreeWindows(expandBlocks(BUSY_STUDENT), 0);
    for (const s of placeSessions(windows, POOL, 60)) {
      assert.ok(s.totalMin <= s.window.usableMin + 0.1, 'session overflows its window');
      assert.ok(s.totalMin <= DEFAULT_CHRONO_CONFIG.maxMicroSessionMin + 0.1);
    }
  });

  it('never repeats an exercise across a day', () => {
    const windows = detectFreeWindows(expandBlocks(FREE_USER), 0);
    const seen = new Set<string>();
    for (const s of placeSessions(windows, POOL, 60)) {
      for (const e of s.exercises) {
        assert.ok(!seen.has(e.id), `${e.name} scheduled twice`);
        seen.add(e.id);
      }
    }
  });

  it('returns nothing on a rest day', () => {
    assert.deepEqual(placeSessions(detectFreeWindows(expandBlocks(FREE_USER), 0), POOL, 0), []);
  });
});

// ---------------------------------------------------------------------------
describe('missed-workout rebalancing', () => {
  const items = [
    { exerciseId: 'a', name: 'Squats', durationMin: 10 },
    { exerciseId: 'b', name: 'Plank', durationMin: 5 },
    { exerciseId: 'c', name: 'Lunges', durationMin: 8 },
  ];
  const days = [
    { date: '2026-09-03', weekday: 3, existingLoadMin: 20, capacityMin: 60 },
    { date: '2026-09-04', weekday: 4, existingLoadMin: 20, capacityMin: 60 },
    { date: '2026-09-05', weekday: 5, existingLoadMin: 25, capacityMin: 60 },
  ];

  it('spreads work across several days instead of dumping it on tomorrow', () => {
    const plan = rebalanceMissedWorkout('2026-09-02', items, days);
    assert.ok(plan.assignments.length >= 2, 'should spread across multiple days');
    assert.equal(plan.dropped.length, 0);
  });

  it('never increases a day beyond the configured multiplier', () => {
    const plan = rebalanceMissedWorkout('2026-09-02', items, days);
    for (const a of plan.assignments) {
      assert.ok(
        a.newLoadMin <= a.previousLoadMin * DEFAULT_CHRONO_CONFIG.maxDailyLoadMultiplier + 0.001,
        `${a.date} went from ${a.previousLoadMin} to ${a.newLoadMin}`,
      );
      assert.ok(a.newLoadMin <= DEFAULT_CHRONO_CONFIG.maxDailyLoadMin);
    }
  });

  it('respects a day real capacity — it will not schedule time that does not exist', () => {
    const noRoom = [{ date: '2026-09-03', weekday: 3, existingLoadMin: 10, capacityMin: 12 }];
    const plan = rebalanceMissedWorkout('2026-09-02', items, noRoom);
    assert.equal(plan.assignments.length, 0);
    assert.equal(plan.dropped.length, 3);
  });

  it('drops honestly rather than cramming, and says so kindly', () => {
    const tight = [{ date: '2026-09-03', weekday: 3, existingLoadMin: 30, capacityMin: 45 }];
    const plan = rebalanceMissedWorkout('2026-09-02', items, tight);
    assert.ok(plan.dropped.length > 0);
    const msg = plan.warnings.join(' ');
    assert.match(msg, /did not fit/);
    assert.match(msg, /normal/);
  });

  it('places the longest items first so they are not stranded', () => {
    const plan = rebalanceMissedWorkout('2026-09-02', items, [
      { date: '2026-09-03', weekday: 3, existingLoadMin: 20, capacityMin: 60 },
    ]);
    const placed = plan.assignments.flatMap((a) => a.items.map((i) => i.durationMin));
    assert.ok(placed.includes(10), 'the longest item should be placed');
  });

  it('handles having no open days at all', () => {
    const plan = rebalanceMissedWorkout('2026-09-02', items, []);
    assert.equal(plan.dropped.length, 3);
    assert.match(plan.warnings[0]!, /No open days/);
  });
});

// ---------------------------------------------------------------------------
describe('notification safety', () => {
  const blocks: EngineBlock[] = expandBlocks(CRUSHED_STUDENT);

  it('refuses to notify during quiet hours', () => {
    const r = isNotifiableAt(blocks, 0, timeToMin('02:00'));
    assert.equal(r.allowed, false);
    assert.equal(r.reason, 'quiet_hours');
  });

  it('refuses to notify during a declared class', () => {
    const r = isNotifiableAt(blocks, 0, timeToMin('10:00'));
    assert.equal(r.allowed, false);
    assert.match(r.reason!, /class/);
  });

  it('allows notification in a genuine free window', () => {
    assert.equal(isNotifiableAt(blocks, 0, timeToMin('15:45')).allowed, true);
  });

  it('is a structural rule, not a user preference', () => {
    // Sanity: sleep and class are the protected set, and it is not empty.
    assert.ok(DEFAULT_CHRONO_CONFIG.protectedBlockTypes.includes('sleep'));
    assert.ok(DEFAULT_CHRONO_CONFIG.protectedBlockTypes.includes('class'));
  });
});
