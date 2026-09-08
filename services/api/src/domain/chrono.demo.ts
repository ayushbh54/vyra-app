/**
 * Chrono Engine demo — run this live in front of judges.
 *
 *   pnpm --filter @vyra/api demo:chrono
 *
 * It takes three real Indian daily schedules and shows, with actual numbers,
 * why VYRA's goal-setting and ranking are fairer than an absolute target.
 */
import {
  assessCapacity,
  computeActivityPoints,
  computeEffort,
  detectFreeWindows,
  expandBlocks,
  placeSessions,
  type PlaceableExercise,
  type RawBlock,
} from './chrono';

const POOL: PlaceableExercise[] = [
  { id: 'jj', name: 'Jumping Jacks', durationSec: 300, intensity: 3, isLowImpact: false },
  { id: 'sq', name: 'Bodyweight Squats', durationSec: 300, intensity: 2, isLowImpact: false },
  { id: 'pl', name: 'Plank Hold', durationSec: 180, intensity: 2, isLowImpact: true },
  { id: 'lu', name: 'Reverse Lunges', durationSec: 300, intensity: 2, isLowImpact: false },
  { id: 'cc', name: 'Cat-Cow Flow', durationSec: 240, intensity: 1, isLowImpact: true },
  { id: 'nr', name: 'Seated Neck Release', durationSec: 180, intensity: 1, isLowImpact: true },
  { id: 'bb', name: 'Box Breathing', durationSec: 300, intensity: 1, isLowImpact: true },
];

const PERSONAS: Array<{ name: string; blocks: RawBlock[] }> = [
  {
    name: 'Aarav — Class 12, school + coaching',
    blocks: [
      { weekday: 6, blockStart: '22:45', blockEnd: '06:00', blockType: 'sleep' },
      { weekday: 0, blockStart: '22:45', blockEnd: '06:00', blockType: 'sleep' },
      { weekday: 0, blockStart: '06:30', blockEnd: '07:15', blockType: 'commute' },
      { weekday: 0, blockStart: '07:15', blockEnd: '14:30', blockType: 'class', label: 'School' },
      { weekday: 0, blockStart: '14:30', blockEnd: '15:30', blockType: 'commute' },
      { weekday: 0, blockStart: '16:00', blockEnd: '20:30', blockType: 'class', label: 'Coaching' },
      { weekday: 0, blockStart: '20:30', blockEnd: '22:15', blockType: 'work', label: 'Homework' },
    ],
  },
  {
    name: 'Priya — hospital nurse, 12-hour shift',
    blocks: [
      { weekday: 6, blockStart: '23:30', blockEnd: '06:30', blockType: 'sleep' },
      { weekday: 0, blockStart: '23:30', blockEnd: '06:30', blockType: 'sleep' },
      { weekday: 0, blockStart: '07:15', blockEnd: '08:00', blockType: 'commute' },
      { weekday: 0, blockStart: '08:00', blockEnd: '20:00', blockType: 'work', label: 'Shift' },
      { weekday: 0, blockStart: '20:00', blockEnd: '20:45', blockType: 'commute' },
    ],
  },
  {
    name: 'Sunita — homemaker, fragmented day',
    blocks: [
      { weekday: 6, blockStart: '22:30', blockEnd: '05:30', blockType: 'sleep' },
      { weekday: 0, blockStart: '22:30', blockEnd: '05:30', blockType: 'sleep' },
      { weekday: 0, blockStart: '06:30', blockEnd: '09:00', blockType: 'work', label: 'Morning household' },
      { weekday: 0, blockStart: '12:00', blockEnd: '14:00', blockType: 'work', label: 'Lunch & chores' },
      { weekday: 0, blockStart: '17:00', blockEnd: '20:30', blockType: 'work', label: 'Evening household' },
    ],
  },
  {
    name: 'Rohit — works from home, flexible day',
    blocks: [
      { weekday: 6, blockStart: '23:30', blockEnd: '07:30', blockType: 'sleep' },
      { weekday: 0, blockStart: '23:30', blockEnd: '07:30', blockType: 'sleep' },
      { weekday: 0, blockStart: '10:00', blockEnd: '13:00', blockType: 'work' },
    ],
  },
];

function bar(value: number, max: number, width = 24): string {
  const filled = Math.round((value / max) * width);
  return '█'.repeat(Math.max(0, filled)) + '·'.repeat(Math.max(0, width - filled));
}

console.log('\n═══ VYRA CHRONO ENGINE ═══\n');

for (const persona of PERSONAS) {
  const blocks = expandBlocks(persona.blocks);
  const windows = detectFreeWindows(blocks, 0);
  const capacity = assessCapacity(windows, 'maintain');
  const sessions = placeSessions(windows, POOL, capacity.dailyGoalMin);

  console.log(`\n${persona.name}`);
  console.log('─'.repeat(64));
  console.log(`  Windows found : ${windows.length}`);
  for (const w of windows.slice(0, 4)) {
    console.log(`    ${w.start}-${w.end}  ${String(w.durationMin).padStart(3)}min  suitability ${w.suitability.toFixed(2)}`);
  }
  console.log(`  Capacity      : ${capacity.capacityMin} min  ${bar(capacity.capacityMin, 90)}`);
  console.log(`  Today's goal  : ${capacity.dailyGoalMin} min  (ideal ${capacity.idealTargetMin}, factor ${capacity.capacityFactor})`);
  console.log(`  Plan          : ${sessions.length} session(s)`);
  for (const s of sessions) {
    console.log(`    ${s.window.start}  ${s.totalMin}min — ${s.exercises.map((e) => e.name).join(', ')}`);
  }
  console.log(`  App says      : "${capacity.explanation}"`);
}

// ---------------------------------------------------------------------------
console.log('\n\n═══ THE FAIRNESS CLAIM, IN NUMBERS ═══\n');

const aarav = assessCapacity(detectFreeWindows(expandBlocks(PERSONAS[0]!.blocks), 0), 'maintain');
const rohit = assessCapacity(detectFreeWindows(expandBlocks(PERSONAS[3]!.blocks), 0), 'maintain');

// Aarav uses almost all the time he has. Rohit does more minutes, but a small
// fraction of a wide-open day, and only sporadically.
const aaravWeek = Array.from({ length: 7 }, () => computeEffort(Math.round(aarav.dailyGoalMin * 0.9), aarav.dailyGoalMin));
const rohitWeek = [
  computeEffort(45, rohit.dailyGoalMin),
  computeEffort(50, rohit.dailyGoalMin),
  ...Array.from({ length: 5 }, () => computeEffort(0, rohit.dailyGoalMin)),
];

const aaravPts = computeActivityPoints(aaravWeek);
const rohitPts = computeActivityPoints(rohitWeek);

const aaravMin = aaravWeek.reduce((s, e) => s + e.achievedMin, 0);
const rohitMin = rohitWeek.reduce((s, e) => s + e.achievedMin, 0);

const row = (a: string, b: string, c: string) =>
  `  ${a.padEnd(34)}${b.padStart(12)}${c.padStart(14)}`;

console.log(row('', 'Aarav', 'Rohit'));
console.log('  ' + '─'.repeat(58));
console.log(row('Free time available/day', `${aarav.capacityMin} min`, `${rohit.capacityMin} min`));
console.log(row('Their goal', `${aarav.dailyGoalMin} min`, `${rohit.dailyGoalMin} min`));
console.log(row('Total minutes done this week', `${aaravMin} min`, `${rohitMin} min`));
console.log(row('Days active', `${aaravPts.activeDays}/7`, `${rohitPts.activeDays}/7`));
console.log(row('Consistency multiplier', `x${aaravPts.consistencyFactor}`, `x${rohitPts.consistencyFactor}`));
console.log('  ' + '─'.repeat(58));
console.log(row('VYRA activity points', `${aaravPts.activityPoints}`, `${rohitPts.activityPoints}`));
console.log('  ' + '─'.repeat(58));

const winner = aaravPts.activityPoints > rohitPts.activityPoints ? 'Aarav' : 'Rohit';
console.log(`\n  A raw-volume leaderboard would rank Rohit (${rohitMin} min) above Aarav (${aaravMin} min).`);
console.log(`  VYRA ranks ${winner} higher — he used ${Math.round((aaravMin / (aarav.capacityMin * 7)) * 100)}% of the time he had,`);
console.log(`  every single day, while Rohit used ${Math.round((rohitMin / (rohit.capacityMin * 7)) * 100)}% of his, twice.\n`);
