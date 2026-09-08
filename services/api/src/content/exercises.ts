/**
 * =============================================================================
 * VYRA CONTENT LIBRARY
 * =============================================================================
 * The seed set for the exercise, yoga, breathing and meditation library.
 *
 * Notes on how this is written:
 *   - Every item carries real coaching cues in `audioScript`. A library of names
 *     and durations is not a fitness product; the cue is the actual value.
 *   - `metValue` drives calorie estimates. Values follow the Compendium of
 *     Physical Activities. We never hardcode a calorie number, because burn
 *     depends on the person's mass.
 *   - `contraindications` are populated wherever a movement is genuinely risky
 *     for a common condition. An empty array means we checked and found none.
 *   - `isSeatedFriendly` items form the Accessibility Mode content set, and are
 *     always `unlockLevel: 0` — the database enforces this too.
 *   - `isRecoveryFor` items are matched by the recovery-routine builder.
 *
 * Media URLs point at the app's own CDN bucket. They are populated by the
 * content pipeline; the app renders a still frame and the text cues when a
 * clip is missing, so a gap in media never blocks a workout.
 * =============================================================================
 */

import type { Difficulty, ExerciseCategory, RecoveryArea } from '@vyra/types';

export interface SeedExercise {
  slug: string;
  name: string;
  category: ExerciseCategory;
  subcategory: string;
  bodyParts: string[];
  muscles: string[];
  difficulty: Difficulty;
  instructions: string[];
  audioScript: string;
  defaultDurationSec: number;
  defaultReps?: number;
  metValue: number;
  equipment: string[];
  contraindications: string[];
  isSeatedFriendly: boolean;
  isLowImpact: boolean;
  isRecoveryFor: RecoveryArea[];
  /** 1 = gentle, 2 = moderate, 3 = vigorous. Drives safe window placement. */
  intensity: 1 | 2 | 3;
}

const CDN = 'https://media.vyra.app/exercises';

export const mediaFor = (slug: string) => ({
  gifUrl: `${CDN}/${slug}.gif`,
  videoUrl: `${CDN}/${slug}.mp4`,
  thumbnailUrl: `${CDN}/${slug}.jpg`,
});

export const EXERCISES: SeedExercise[] = [
  // ─────────────────────────────────────────── STRENGTH · LOWER BODY
  {
    slug: 'bodyweight-squat',
    name: 'Bodyweight Squat',
    category: 'exercise', subcategory: 'legs',
    bodyParts: ['legs', 'glutes'], muscles: ['quadriceps', 'glutes', 'hamstrings'],
    difficulty: 'beginner',
    instructions: [
      'Stand with your feet a little wider than your hips, toes turned slightly out.',
      'Push your hips back as if sitting into a chair behind you.',
      'Lower until your thighs are roughly parallel to the floor, chest up.',
      'Drive through your heels to stand back up.',
    ],
    audioScript:
      'Feet a little wider than your hips. Hips back first, then bend the knees. Keep your chest lifted and your weight in your heels. Breathe in on the way down, out as you stand. Knees track over your toes — not falling inward.',
    defaultDurationSec: 45, defaultReps: 15, metValue: 5.0,
    equipment: [], contraindications: ['Acute knee pain', 'Recent knee or hip surgery'],
    isSeatedFriendly: false, isLowImpact: true, isRecoveryFor: [], intensity: 2,
  },
  {
    slug: 'reverse-lunge',
    name: 'Reverse Lunge',
    category: 'exercise', subcategory: 'legs',
    bodyParts: ['legs', 'glutes'], muscles: ['quadriceps', 'glutes', 'hamstrings'],
    difficulty: 'beginner',
    instructions: [
      'Stand tall with your hands on your hips.',
      'Step one foot back and lower until both knees are near ninety degrees.',
      'Keep your front knee above your ankle, not past your toes.',
      'Push through the front heel to return, then change sides.',
    ],
    audioScript:
      'Step back, not forward — it is kinder on the front knee. Lower straight down rather than leaning ahead. Front knee stays above the ankle. Push the floor away through the front heel.',
    defaultDurationSec: 60, defaultReps: 20, metValue: 5.0,
    equipment: [], contraindications: ['Acute knee pain', 'Balance disorders'],
    isSeatedFriendly: false, isLowImpact: true, isRecoveryFor: [], intensity: 2,
  },
  {
    slug: 'glute-bridge',
    name: 'Glute Bridge',
    category: 'exercise', subcategory: 'glutes',
    bodyParts: ['glutes', 'back'], muscles: ['glutes', 'hamstrings', 'core'],
    difficulty: 'beginner',
    instructions: [
      'Lie on your back with knees bent and feet flat, hip-width apart.',
      'Press your feet down and lift your hips until your body forms a straight line.',
      'Squeeze your glutes at the top for a moment.',
      'Lower slowly, one vertebra at a time.',
    ],
    audioScript:
      'Press through your heels and lift the hips. Squeeze the glutes at the top — this should be felt in the glutes, not the lower back. If your back is doing the work, lift a little less high.',
    defaultDurationSec: 45, defaultReps: 15, metValue: 3.5,
    equipment: [], contraindications: [],
    isSeatedFriendly: false, isLowImpact: true, isRecoveryFor: ['lower_back'], intensity: 1,
  },
  {
    slug: 'wall-sit',
    name: 'Wall Sit',
    category: 'exercise', subcategory: 'legs',
    bodyParts: ['legs'], muscles: ['quadriceps', 'glutes'],
    difficulty: 'beginner',
    instructions: [
      'Stand with your back flat against a wall.',
      'Walk your feet forward and slide down until your knees are at ninety degrees.',
      'Hold, keeping your back in contact with the wall.',
    ],
    audioScript:
      'Back flat to the wall, knees over ankles. Breathe steadily — do not hold your breath. Your legs will burn; that is the point. If your knees complain, come a little higher.',
    defaultDurationSec: 40, metValue: 4.0,
    equipment: ['wall'], contraindications: ['Acute knee pain'],
    isSeatedFriendly: false, isLowImpact: true, isRecoveryFor: [], intensity: 2,
  },
  {
    slug: 'calf-raise',
    name: 'Calf Raise',
    category: 'exercise', subcategory: 'legs',
    bodyParts: ['legs'], muscles: ['calves'],
    difficulty: 'beginner',
    instructions: [
      'Stand tall, feet hip-width apart, near a wall for balance.',
      'Rise onto the balls of your feet.',
      'Pause at the top, then lower slowly.',
    ],
    audioScript: 'Rise up slowly, pause, and lower even more slowly. The lowering half is where the work happens.',
    defaultDurationSec: 40, defaultReps: 20, metValue: 3.0,
    equipment: [], contraindications: [],
    isSeatedFriendly: false, isLowImpact: true, isRecoveryFor: ['ankle'], intensity: 1,
  },

  // ─────────────────────────────────────────── STRENGTH · UPPER BODY
  {
    slug: 'knee-push-up',
    name: 'Knee Push-Up',
    category: 'exercise', subcategory: 'chest',
    bodyParts: ['chest', 'arms'], muscles: ['pectorals', 'triceps', 'shoulders'],
    difficulty: 'beginner',
    instructions: [
      'Start on hands and knees, hands slightly wider than your shoulders.',
      'Walk your knees back so your body makes a straight line from head to knees.',
      'Lower your chest towards the floor, elbows at about forty-five degrees.',
      'Press back up.',
    ],
    audioScript:
      'Hands under and slightly wider than your shoulders. Keep a straight line from head to knees — no sagging at the hips. Elbows point back at an angle, not straight out to the sides.',
    defaultDurationSec: 45, defaultReps: 12, metValue: 3.8,
    equipment: [], contraindications: ['Wrist injury', 'Shoulder impingement'],
    isSeatedFriendly: false, isLowImpact: true, isRecoveryFor: [], intensity: 2,
  },
  {
    slug: 'push-up',
    name: 'Push-Up',
    category: 'exercise', subcategory: 'chest',
    bodyParts: ['chest', 'arms', 'core'], muscles: ['pectorals', 'triceps', 'core'],
    difficulty: 'intermediate',
    instructions: [
      'Start in a plank with hands slightly wider than your shoulders.',
      'Keep your body in one straight line from head to heels.',
      'Lower your chest towards the floor.',
      'Press back up without letting your hips drop.',
    ],
    audioScript:
      'Body in one line — squeeze your glutes to stop the hips sagging. Lower with control, press up strong. Quality over quantity: five good repetitions beat fifteen sloppy ones.',
    defaultDurationSec: 45, defaultReps: 12, metValue: 8.0,
    equipment: [], contraindications: ['Wrist injury', 'Shoulder impingement'],
    isSeatedFriendly: false, isLowImpact: true, isRecoveryFor: [], intensity: 3,
  },
  {
    slug: 'dumbbell-bicep-curl',
    name: 'Dumbbell Bicep Curl',
    category: 'exercise', subcategory: 'arms',
    bodyParts: ['arms'], muscles: ['biceps', 'forearms'],
    difficulty: 'beginner',
    instructions: [
      'Stand tall holding a dumbbell in each hand, arms hanging, palms facing forward.',
      'Keep your elbows pinned to your torso throughout the movement.',
      'Curl the weights up smoothly without swinging your body.',
      'Squeeze at the top, then lower with control back to a full hang.',
    ],
    audioScript:
      'Elbows tucked in, no swinging from the hips. Lift smooth, squeeze at the top, three-second lower on the way down. If your back is moving, the weight is too heavy.',
    defaultDurationSec: 40, defaultReps: 12, metValue: 3.5,
    equipment: ['dumbbells'], contraindications: ['Wrist injury', 'Elbow injury'],
    isSeatedFriendly: false, isLowImpact: true, isRecoveryFor: [], intensity: 2,
  },
  {
    slug: 'wall-push-up',
    name: 'Wall Push-Up',
    category: 'exercise', subcategory: 'chest',
    bodyParts: ['chest', 'arms'], muscles: ['pectorals', 'triceps'],
    difficulty: 'beginner',
    instructions: [
      'Stand an arm\'s length from a wall, palms flat at chest height.',
      'Bend your elbows to bring your chest towards the wall.',
      'Press back to the start.',
    ],
    audioScript:
      'Stand far enough back that your arms are straight to begin. Lean in slowly, press away with control. Step further back to make it harder.',
    defaultDurationSec: 40, defaultReps: 15, metValue: 2.8,
    equipment: ['wall'], contraindications: [],
    isSeatedFriendly: true, isLowImpact: true, isRecoveryFor: ['shoulder'], intensity: 1,
  },
  {
    slug: 'seated-shoulder-press',
    name: 'Seated Shoulder Press',
    category: 'exercise', subcategory: 'shoulders',
    bodyParts: ['shoulders', 'arms'], muscles: ['deltoids', 'triceps'],
    difficulty: 'beginner',
    instructions: [
      'Sit tall in a sturdy chair, feet flat on the floor.',
      'Bring your hands to shoulder height, palms facing forward.',
      'Press upward until your arms are almost straight.',
      'Lower with control.',
    ],
    audioScript:
      'Sit tall — imagine a string lifting the crown of your head. Press up, keeping your ribs down so your lower back does not arch. Lower slowly.',
    defaultDurationSec: 45, defaultReps: 15, metValue: 3.0,
    equipment: ['chair'], contraindications: ['Acute shoulder pain'],
    isSeatedFriendly: true, isLowImpact: true, isRecoveryFor: [], intensity: 1,
  },
  {
    slug: 'arm-circles',
    name: 'Arm Circles',
    category: 'exercise', subcategory: 'shoulders',
    bodyParts: ['shoulders'], muscles: ['deltoids'],
    difficulty: 'beginner',
    instructions: [
      'Stand or sit tall with your arms out to the sides.',
      'Make small circles forward, gradually widening them.',
      'Reverse the direction halfway through.',
    ],
    audioScript: 'Small circles first, letting the shoulders warm up. Widen gradually. Halfway through, reverse.',
    defaultDurationSec: 30, metValue: 2.5,
    equipment: [], contraindications: [],
    isSeatedFriendly: true, isLowImpact: true, isRecoveryFor: ['shoulder'], intensity: 1,
  },

  // ─────────────────────────────────────────── CORE
  {
    slug: 'plank',
    name: 'Plank Hold',
    category: 'exercise', subcategory: 'abs',
    bodyParts: ['core'], muscles: ['core', 'shoulders', 'glutes'],
    difficulty: 'beginner',
    instructions: [
      'Rest on your forearms and toes, elbows under your shoulders.',
      'Hold your body in a straight line from head to heels.',
      'Brace your stomach and squeeze your glutes.',
    ],
    audioScript:
      'Elbows directly under the shoulders. Straight line from head to heels — hips neither sagging nor piked up. Breathe normally; do not hold your breath. Stop when your form breaks, not when it hurts.',
    defaultDurationSec: 30, metValue: 3.5,
    equipment: [], contraindications: ['Lower back pain', 'Shoulder injury'],
    isSeatedFriendly: false, isLowImpact: true, isRecoveryFor: [], intensity: 2,
  },
  {
    slug: 'dead-bug',
    name: 'Dead Bug',
    category: 'exercise', subcategory: 'abs',
    bodyParts: ['core'], muscles: ['core', 'hip flexors'],
    difficulty: 'beginner',
    instructions: [
      'Lie on your back, arms straight up, knees bent at ninety degrees above your hips.',
      'Slowly lower one arm overhead and the opposite leg towards the floor.',
      'Keep your lower back pressed into the floor throughout.',
      'Return and change sides.',
    ],
    audioScript:
      'Press your lower back gently into the floor and keep it there — that contact is the whole exercise. Move slowly. If your back lifts, do not reach as far.',
    defaultDurationSec: 45, metValue: 3.0,
    equipment: [], contraindications: [],
    isSeatedFriendly: false, isLowImpact: true, isRecoveryFor: ['lower_back'], intensity: 1,
  },
  {
    slug: 'bird-dog',
    name: 'Bird Dog',
    category: 'exercise', subcategory: 'back',
    bodyParts: ['core', 'back'], muscles: ['core', 'erector spinae', 'glutes'],
    difficulty: 'beginner',
    instructions: [
      'Start on hands and knees, wrists under shoulders, knees under hips.',
      'Extend one arm forward and the opposite leg back.',
      'Hold briefly, keeping your hips level.',
      'Return and change sides.',
    ],
    audioScript:
      'Reach long rather than high. Keep your hips square to the floor — imagine balancing a glass of water on your lower back. Slow and steady.',
    defaultDurationSec: 45, metValue: 3.0,
    equipment: [], contraindications: [],
    isSeatedFriendly: false, isLowImpact: true, isRecoveryFor: ['lower_back'], intensity: 1,
  },
  {
    slug: 'seated-torso-twist',
    name: 'Seated Torso Twist',
    category: 'exercise', subcategory: 'abs',
    bodyParts: ['core'], muscles: ['obliques'],
    difficulty: 'beginner',
    instructions: [
      'Sit tall with your feet flat on the floor.',
      'Place your hands lightly on your shoulders.',
      'Turn your upper body to one side, then the other.',
    ],
    audioScript: 'Turn from the ribs, not the neck. Keep your hips facing forward. Move at a steady, unhurried pace.',
    defaultDurationSec: 40, metValue: 2.5,
    equipment: ['chair'], contraindications: [],
    isSeatedFriendly: true, isLowImpact: true, isRecoveryFor: [], intensity: 1,
  },

  // ─────────────────────────────────────────── CARDIO
  {
    slug: 'jumping-jacks',
    name: 'Jumping Jacks',
    category: 'exercise', subcategory: 'cardio',
    bodyParts: ['full body'], muscles: ['calves', 'shoulders', 'core'],
    difficulty: 'beginner',
    instructions: [
      'Stand with your feet together, arms by your sides.',
      'Jump your feet wide while raising your arms overhead.',
      'Jump back to the start.',
    ],
    audioScript:
      'Land softly through the balls of your feet, knees slightly bent. Keep a rhythm you can hold for the whole set. If jumping is uncomfortable, step one foot out at a time instead.',
    defaultDurationSec: 45, metValue: 8.0,
    equipment: [], contraindications: ['Knee or ankle injury', 'Pregnancy (later stages)'],
    isSeatedFriendly: false, isLowImpact: false, isRecoveryFor: [], intensity: 3,
  },
  {
    slug: 'march-in-place',
    name: 'March in Place',
    category: 'exercise', subcategory: 'cardio',
    bodyParts: ['full body'], muscles: ['hip flexors', 'calves'],
    difficulty: 'beginner',
    instructions: [
      'Stand tall and lift one knee to hip height.',
      'Lower and repeat with the other leg.',
      'Swing your arms naturally.',
    ],
    audioScript: 'Lift the knees to a comfortable height and let the arms swing. This is the low-impact alternative whenever jumping does not suit you.',
    defaultDurationSec: 60, metValue: 3.5,
    equipment: [], contraindications: [],
    isSeatedFriendly: false, isLowImpact: true, isRecoveryFor: ['knee'], intensity: 1,
  },
  {
    slug: 'seated-march',
    name: 'Seated March',
    category: 'exercise', subcategory: 'cardio',
    bodyParts: ['legs', 'core'], muscles: ['hip flexors', 'core'],
    difficulty: 'beginner',
    instructions: [
      'Sit tall towards the front of a sturdy chair.',
      'Lift one knee, lower it, then lift the other.',
      'Add arm swings once the rhythm is steady.',
    ],
    audioScript: 'Sit tall, away from the backrest. Lift one knee at a time at a steady pace. Add the arms when you feel ready — this raises your heart rate without standing.',
    defaultDurationSec: 60, metValue: 2.8,
    equipment: ['chair'], contraindications: [],
    isSeatedFriendly: true, isLowImpact: true, isRecoveryFor: ['knee', 'ankle'], intensity: 1,
  },
  {
    slug: 'high-knees',
    name: 'High Knees',
    category: 'exercise', subcategory: 'cardio',
    bodyParts: ['legs', 'core'], muscles: ['hip flexors', 'quadriceps', 'calves'],
    difficulty: 'intermediate',
    instructions: [
      'Run on the spot, driving your knees towards hip height.',
      'Stay on the balls of your feet.',
      'Pump your arms in rhythm.',
    ],
    audioScript: 'Quick feet, knees driving up. Stay light — think quiet landings. Hold the pace you can keep for the whole interval.',
    defaultDurationSec: 30, metValue: 8.0,
    equipment: [], contraindications: ['Knee or ankle injury'],
    isSeatedFriendly: false, isLowImpact: false, isRecoveryFor: [], intensity: 3,
  },
  {
    slug: 'burpee',
    name: 'Burpee',
    category: 'exercise', subcategory: 'cardio',
    bodyParts: ['full body'], muscles: ['quadriceps', 'chest', 'core', 'shoulders'],
    difficulty: 'advanced',
    instructions: [
      'From standing, squat and place your hands on the floor.',
      'Jump or step your feet back into a plank.',
      'Return your feet to your hands.',
      'Stand and jump.',
    ],
    audioScript:
      'Pace yourself — burpees punish anyone who starts too fast. Step back instead of jumping if you need to; it is still a burpee.',
    defaultDurationSec: 40, metValue: 8.0,
    equipment: [], contraindications: ['Knee, wrist or back injury', 'High blood pressure'],
    isSeatedFriendly: false, isLowImpact: false, isRecoveryFor: [], intensity: 3,
  },
  {
    slug: 'mountain-climbers',
    name: 'Mountain Climbers',
    category: 'exercise', subcategory: 'cardio',
    bodyParts: ['core', 'legs'], muscles: ['core', 'hip flexors', 'shoulders'],
    difficulty: 'intermediate',
    instructions: [
      'Start in a plank with your hands under your shoulders.',
      'Drive one knee towards your chest.',
      'Switch legs quickly, keeping your hips low.',
    ],
    audioScript: 'Hips stay low and level — do not let them bounce up. Drive the knees in, keep the shoulders over the wrists.',
    defaultDurationSec: 30, metValue: 8.0,
    equipment: [], contraindications: ['Wrist injury', 'Lower back pain'],
    isSeatedFriendly: false, isLowImpact: false, isRecoveryFor: [], intensity: 3,
  },

  // ─────────────────────────────────────────── SPECIAL FORMATS
  {
    slug: 'tabata-squat-thrust',
    name: 'Tabata: Squat Thrusts',
    category: 'special', subcategory: 'tabata',
    bodyParts: ['full body'], muscles: ['quadriceps', 'core', 'shoulders'],
    difficulty: 'advanced',
    instructions: [
      'Twenty seconds of maximum effort squat thrusts.',
      'Ten seconds of rest.',
      'Repeat for eight rounds — four minutes in total.',
    ],
    audioScript:
      'Twenty seconds on, ten seconds off, eight rounds. Go hard in the work interval and truly rest in the ten seconds. Stop if your form falls apart.',
    defaultDurationSec: 240, metValue: 10.0,
    equipment: [], contraindications: ['Heart conditions', 'High blood pressure', 'Joint injury'],
    isSeatedFriendly: false, isLowImpact: false, isRecoveryFor: [], intensity: 3,
  },
  {
    slug: 'hiit-interval-beginner',
    name: 'HIIT: Beginner Intervals',
    category: 'special', subcategory: 'hiit',
    bodyParts: ['full body'], muscles: ['full body'],
    difficulty: 'intermediate',
    instructions: [
      'Thirty seconds of work at a hard but controlled effort.',
      'Thirty seconds of walking or marching to recover.',
      'Repeat for eight rounds.',
    ],
    audioScript:
      'Hard effort, then a real recovery — the recovery is what makes the next interval work. If you cannot speak a short sentence during the rest, ease off next round.',
    defaultDurationSec: 480, metValue: 9.0,
    equipment: [], contraindications: ['Heart conditions', 'Uncontrolled blood pressure'],
    isSeatedFriendly: false, isLowImpact: false, isRecoveryFor: [], intensity: 3,
  },
  {
    slug: 'zumba-basic-flow',
    name: 'Zumba: Basic Dance Flow',
    category: 'special', subcategory: 'zumba',
    bodyParts: ['full body'], muscles: ['legs', 'core'],
    difficulty: 'beginner',
    instructions: [
      'Follow the four-count step pattern to the beat.',
      'Add hip movement once the footwork feels natural.',
      'Keep moving between sequences.',
    ],
    audioScript: 'Footwork first, styling later. If you lose the step, keep moving and rejoin on the next count — nobody is watching.',
    defaultDurationSec: 300, metValue: 6.5,
    equipment: [], contraindications: [],
    isSeatedFriendly: false, isLowImpact: false, isRecoveryFor: [], intensity: 2,
  },
  {
    slug: 'tai-chi-opening-form',
    name: 'Tai Chi: Opening Form',
    category: 'special', subcategory: 'tai_chi',
    bodyParts: ['full body'], muscles: ['legs', 'core'],
    difficulty: 'beginner',
    instructions: [
      'Stand with your feet shoulder-width apart, knees soft.',
      'Raise your arms slowly to shoulder height as you breathe in.',
      'Lower them just as slowly as you breathe out.',
      'Let the movement and the breath match.',
    ],
    audioScript:
      'Move slower than feels natural. Let the breath lead and the arms follow. Knees stay soft, shoulders stay down. There is no rush here.',
    defaultDurationSec: 300, metValue: 3.0,
    equipment: [], contraindications: [],
    isSeatedFriendly: false, isLowImpact: true, isRecoveryFor: ['lower_back', 'knee'], intensity: 1,
  },

  // ─────────────────────────────────────────── YOGA · BODY
  {
    slug: 'cat-cow',
    name: 'Cat-Cow Flow',
    category: 'yoga', subcategory: 'body_yoga',
    bodyParts: ['back', 'core'], muscles: ['spine', 'core'],
    difficulty: 'beginner',
    instructions: [
      'Start on hands and knees.',
      'Breathe in as you drop your belly and lift your chest and tailbone.',
      'Breathe out as you round your spine and tuck your chin.',
      'Move with your breath.',
    ],
    audioScript:
      'Inhale, let the belly soften and the chest lift. Exhale, round the back and tuck the chin. Let the breath set the pace, not the other way round.',
    defaultDurationSec: 60, metValue: 2.5,
    equipment: ['mat'], contraindications: ['Wrist injury'],
    isSeatedFriendly: false, isLowImpact: true, isRecoveryFor: ['lower_back', 'neck'], intensity: 1,
  },
  {
    slug: 'child-pose',
    name: "Child's Pose (Balasana)",
    category: 'yoga', subcategory: 'body_yoga',
    bodyParts: ['back', 'hips'], muscles: ['lower back', 'hips'],
    difficulty: 'beginner',
    instructions: [
      'Kneel and sit back towards your heels.',
      'Fold forward and rest your forehead on the floor.',
      'Reach your arms forward or rest them by your sides.',
    ],
    audioScript: 'Let your forehead rest and your shoulders soften. Breathe into your back ribs. Stay as long as it feels good.',
    defaultDurationSec: 60, metValue: 2.0,
    equipment: ['mat'], contraindications: ['Knee injury', 'Late pregnancy'],
    isSeatedFriendly: false, isLowImpact: true, isRecoveryFor: ['lower_back'], intensity: 1,
  },
  {
    slug: 'downward-dog',
    name: 'Downward-Facing Dog (Adho Mukha Svanasana)',
    category: 'yoga', subcategory: 'body_yoga',
    bodyParts: ['full body'], muscles: ['hamstrings', 'shoulders', 'calves'],
    difficulty: 'beginner',
    instructions: [
      'From hands and knees, tuck your toes and lift your hips up and back.',
      'Keep a soft bend in your knees.',
      'Press the floor away through your hands.',
    ],
    audioScript:
      'Bend the knees as much as you need — a long spine matters far more than straight legs. Press the floor away, let the head hang softly.',
    defaultDurationSec: 45, metValue: 2.8,
    equipment: ['mat'], contraindications: ['Wrist injury', 'High blood pressure', 'Glaucoma'],
    isSeatedFriendly: false, isLowImpact: true, isRecoveryFor: [], intensity: 2,
  },
  {
    slug: 'seated-forward-fold',
    name: 'Seated Forward Fold (Paschimottanasana)',
    category: 'yoga', subcategory: 'body_yoga',
    bodyParts: ['back', 'legs'], muscles: ['hamstrings', 'lower back'],
    difficulty: 'beginner',
    instructions: [
      'Sit with your legs extended in front of you.',
      'Lengthen your spine, then fold forward from the hips.',
      'Rest your hands wherever they reach.',
    ],
    audioScript: 'Fold from the hips, not by rounding the back. Bend your knees if you need to. This is not a competition with your toes.',
    defaultDurationSec: 60, metValue: 2.3,
    equipment: ['mat'], contraindications: ['Herniated disc', 'Sciatica'],
    isSeatedFriendly: false, isLowImpact: true, isRecoveryFor: [], intensity: 1,
  },
  {
    slug: 'tree-pose',
    name: 'Tree Pose (Vrikshasana)',
    category: 'yoga', subcategory: 'body_yoga',
    bodyParts: ['legs', 'core'], muscles: ['calves', 'core', 'glutes'],
    difficulty: 'beginner',
    instructions: [
      'Stand tall and shift your weight onto one foot.',
      'Place the other foot on your ankle, calf, or inner thigh — never on the knee.',
      'Bring your hands together at your chest.',
      'Fix your gaze on one still point.',
    ],
    audioScript:
      'Foot on the ankle, the calf, or the inner thigh — never against the knee itself. Find one still point to look at; the gaze steadies the balance. Wobbling is part of it.',
    defaultDurationSec: 60, metValue: 2.5,
    equipment: [], contraindications: ['Vertigo', 'Severe balance impairment'],
    isSeatedFriendly: false, isLowImpact: true, isRecoveryFor: [], intensity: 1,
  },
  {
    slug: 'supine-twist',
    name: 'Supine Spinal Twist',
    category: 'yoga', subcategory: 'body_yoga',
    bodyParts: ['back', 'core'], muscles: ['spine', 'obliques'],
    difficulty: 'beginner',
    instructions: [
      'Lie on your back and hug both knees in.',
      'Let your knees fall to one side, arms out wide.',
      'Turn your head the other way and breathe.',
      'Change sides.',
    ],
    audioScript: 'Let gravity do the work — this is a release, not a stretch you force. Keep both shoulders heavy on the floor.',
    defaultDurationSec: 60, metValue: 2.0,
    equipment: ['mat'], contraindications: ['Recent spinal surgery'],
    isSeatedFriendly: false, isLowImpact: true, isRecoveryFor: ['lower_back'], intensity: 1,
  },

  // ─────────────────────────────────────────── YOGA · FACE
  {
    slug: 'lions-breath',
    name: "Lion's Pose (Simhasana)",
    category: 'yoga', subcategory: 'face_yoga',
    bodyParts: ['face', 'neck'], muscles: ['facial muscles', 'jaw'],
    difficulty: 'beginner',
    instructions: [
      'Sit comfortably and take a deep breath in through your nose.',
      'Open your mouth wide, stick your tongue out and down.',
      'Breathe out forcefully with a "haa" sound.',
      'Repeat a few times.',
    ],
    audioScript:
      'Big breath in through the nose. Open the mouth wide, tongue out and down, eyes up, and breathe out with a strong "haa". It will feel silly — that is part of why it releases jaw tension.',
    defaultDurationSec: 45, metValue: 2.0,
    equipment: [], contraindications: ['Jaw disorders such as TMJ'],
    isSeatedFriendly: true, isLowImpact: true, isRecoveryFor: [], intensity: 1,
  },
  {
    slug: 'cheek-lift',
    name: 'Cheek Lift',
    category: 'yoga', subcategory: 'face_yoga',
    bodyParts: ['face'], muscles: ['cheek muscles'],
    difficulty: 'beginner',
    instructions: [
      'Smile widely without showing your teeth.',
      'Place your fingertips lightly on the tops of your cheeks.',
      'Lift the cheek muscles up, hold, and release.',
    ],
    audioScript: 'Smile wide, feel the cheeks lift under your fingers, hold for a count of five, and release. Keep the forehead relaxed.',
    defaultDurationSec: 40, metValue: 2.0,
    equipment: [], contraindications: [],
    isSeatedFriendly: true, isLowImpact: true, isRecoveryFor: [], intensity: 1,
  },
  {
    slug: 'jaw-release',
    name: 'Jaw Release',
    category: 'yoga', subcategory: 'face_yoga',
    bodyParts: ['face', 'neck'], muscles: ['jaw', 'neck'],
    difficulty: 'beginner',
    instructions: [
      'Sit tall and let your jaw hang loose.',
      'Move your lower jaw gently side to side.',
      'Massage the hinge of the jaw with your fingertips.',
    ],
    audioScript: 'Let the jaw hang heavy. Small, gentle movements — never force it. If it clicks painfully, stop and see a dentist.',
    defaultDurationSec: 40, metValue: 2.0,
    equipment: [], contraindications: ['TMJ disorders'],
    isSeatedFriendly: true, isLowImpact: true, isRecoveryFor: ['neck'], intensity: 1,
  },

  // ─────────────────────────────────────────── YOGA · HAIR / SCALP
  {
    slug: 'scalp-massage',
    name: 'Scalp Circulation Massage',
    category: 'yoga', subcategory: 'hair_yoga',
    bodyParts: ['head'], muscles: ['scalp'],
    difficulty: 'beginner',
    instructions: [
      'Sit comfortably and place your fingertips on your scalp.',
      'Move the scalp itself in small circles rather than sliding over the hair.',
      'Work from the front hairline to the back of the head.',
    ],
    audioScript:
      'Move the scalp under your fingers rather than rubbing the hair. Firm but comfortable pressure. Work slowly across the whole head.',
    defaultDurationSec: 120, metValue: 1.8,
    equipment: [], contraindications: ['Scalp infections or wounds'],
    isSeatedFriendly: true, isLowImpact: true, isRecoveryFor: [], intensity: 1,
  },
  {
    slug: 'legs-up-wall',
    name: 'Legs Up the Wall (Viparita Karani)',
    category: 'yoga', subcategory: 'hair_yoga',
    bodyParts: ['legs', 'head'], muscles: ['hamstrings'],
    difficulty: 'beginner',
    instructions: [
      'Sit sideways next to a wall, then swing your legs up as you lie back.',
      'Rest your arms by your sides.',
      'Stay and breathe slowly.',
    ],
    audioScript:
      'Hips close to the wall, legs resting up it. Arms soft by your sides. A gentle inversion — come out slowly, and skip it entirely if you have high blood pressure or a neck problem.',
    defaultDurationSec: 180, metValue: 1.5,
    equipment: ['wall'], contraindications: ['High blood pressure', 'Glaucoma', 'Neck injury'],
    isSeatedFriendly: false, isLowImpact: true, isRecoveryFor: ['lower_back'], intensity: 1,
  },

  // ─────────────────────────────────────────── BREATHING
  {
    slug: 'box-breathing',
    name: 'Box Breathing (4-4-4-4)',
    category: 'breathing', subcategory: 'box_breathing',
    bodyParts: ['lungs'], muscles: ['diaphragm'],
    difficulty: 'beginner',
    instructions: [
      'Breathe in through your nose for four counts.',
      'Hold for four counts.',
      'Breathe out for four counts.',
      'Hold empty for four counts. Repeat.',
    ],
    audioScript:
      'In for four. Hold for four. Out for four. Hold for four. If holding feels uncomfortable, shorten the count — the rhythm matters more than the number.',
    defaultDurationSec: 300, metValue: 1.3,
    equipment: [], contraindications: ['Severe respiratory conditions'],
    isSeatedFriendly: true, isLowImpact: true, isRecoveryFor: [], intensity: 1,
  },
  {
    slug: 'four-seven-eight',
    name: '4-7-8 Breathing',
    category: 'breathing', subcategory: 'relaxation',
    bodyParts: ['lungs'], muscles: ['diaphragm'],
    difficulty: 'beginner',
    instructions: [
      'Breathe in quietly through your nose for four counts.',
      'Hold for seven counts.',
      'Breathe out through your mouth for eight counts.',
      'Repeat four times.',
    ],
    audioScript:
      'In through the nose for four. Hold for seven. Long breath out through the mouth for eight. The long exhale is what settles the nervous system. Four rounds is plenty to begin.',
    defaultDurationSec: 240, metValue: 1.3,
    equipment: [], contraindications: ['Severe respiratory conditions'],
    isSeatedFriendly: true, isLowImpact: true, isRecoveryFor: [], intensity: 1,
  },
  {
    slug: 'anulom-vilom',
    name: 'Alternate Nostril Breathing (Anulom Vilom)',
    category: 'breathing', subcategory: 'pranayama',
    bodyParts: ['lungs'], muscles: ['diaphragm'],
    difficulty: 'beginner',
    instructions: [
      'Sit comfortably with a straight spine.',
      'Close your right nostril with your thumb and breathe in through the left.',
      'Close the left and breathe out through the right.',
      'Breathe in through the right, then out through the left. That is one round.',
    ],
    audioScript:
      'Right nostril closed, breathe in through the left. Switch, breathe out through the right. In through the right, switch, out through the left. Keep the breath smooth and unforced.',
    defaultDurationSec: 300, metValue: 1.3,
    equipment: [], contraindications: ['Blocked nose', 'Recent nasal surgery'],
    isSeatedFriendly: true, isLowImpact: true, isRecoveryFor: [], intensity: 1,
  },

  // ─────────────────────────────────────────── MEDITATION
  {
    slug: 'body-scan',
    name: 'Body Scan',
    category: 'meditation', subcategory: 'mindfulness',
    bodyParts: ['mind'], muscles: [],
    difficulty: 'beginner',
    instructions: [
      'Lie down or sit comfortably and close your eyes.',
      'Bring attention to your feet, then move slowly upward.',
      'Notice sensation without trying to change it.',
    ],
    audioScript:
      'Start at your feet. Notice whatever is there — warmth, pressure, nothing at all. Move slowly up through the legs, the hips, the back. You are not trying to relax; you are only noticing. When your mind wanders, that is normal — return to where you were.',
    defaultDurationSec: 600, metValue: 1.0,
    equipment: [], contraindications: [],
    isSeatedFriendly: true, isLowImpact: true, isRecoveryFor: [], intensity: 1,
  },
  {
    slug: 'breath-awareness',
    name: 'Breath Awareness',
    category: 'meditation', subcategory: 'mindfulness',
    bodyParts: ['mind'], muscles: [],
    difficulty: 'beginner',
    instructions: [
      'Sit comfortably with your eyes closed or softly lowered.',
      'Rest your attention on the feeling of breathing.',
      'When your mind wanders, gently return to the breath.',
    ],
    audioScript:
      'Let the breath be exactly as it is. Notice where you feel it most — the nose, the chest, the belly. Your mind will wander. Noticing that you wandered is the practice, not a failure at it.',
    defaultDurationSec: 300, metValue: 1.0,
    equipment: [], contraindications: [],
    isSeatedFriendly: true, isLowImpact: true, isRecoveryFor: [], intensity: 1,
  },
  {
    slug: 'sleep-prep',
    name: 'Sleep Preparation',
    category: 'meditation', subcategory: 'sleep',
    bodyParts: ['mind'], muscles: [],
    difficulty: 'beginner',
    instructions: [
      'Lie down in bed and let your body settle.',
      'Release tension from your jaw, shoulders and hands.',
      'Let your breath slow naturally.',
    ],
    audioScript:
      'Let the bed hold your weight. Soften the jaw. Let the shoulders drop away from the ears. Unclench the hands. There is nothing to do now and nowhere to be.',
    defaultDurationSec: 600, metValue: 1.0,
    equipment: [], contraindications: [],
    isSeatedFriendly: true, isLowImpact: true, isRecoveryFor: [], intensity: 1,
  },

  // ─────────────────────────────────────────── RECOVERY-SPECIFIC
  {
    slug: 'neck-release',
    name: 'Seated Neck Release',
    category: 'exercise', subcategory: 'mobility',
    bodyParts: ['neck'], muscles: ['neck', 'trapezius'],
    difficulty: 'beginner',
    instructions: [
      'Sit tall with your shoulders relaxed.',
      'Let your right ear drop towards your right shoulder.',
      'Hold, breathing softly, then change sides.',
    ],
    audioScript:
      'Let the head drop with gravity — do not pull it. Keep the opposite shoulder down. If you feel anything sharp, come out immediately.',
    defaultDurationSec: 45, metValue: 1.8,
    equipment: [], contraindications: ['Cervical spine injury'],
    isSeatedFriendly: true, isLowImpact: true, isRecoveryFor: ['neck', 'shoulder'], intensity: 1,
  },
  {
    slug: 'wrist-mobility',
    name: 'Wrist Mobility Series',
    category: 'exercise', subcategory: 'mobility',
    bodyParts: ['wrist', 'arms'], muscles: ['forearms'],
    difficulty: 'beginner',
    instructions: [
      'Extend one arm forward, palm down.',
      'Gently draw the fingers back with your other hand.',
      'Turn the palm up and repeat.',
      'Finish with slow wrist circles.',
    ],
    audioScript: 'Gentle pressure only — a stretch, never a strain. Especially useful if you type or write for long stretches.',
    defaultDurationSec: 60, metValue: 1.8,
    equipment: [], contraindications: ['Acute wrist injury'],
    isSeatedFriendly: true, isLowImpact: true, isRecoveryFor: ['wrist'], intensity: 1,
  },
  {
    slug: 'ankle-circles',
    name: 'Ankle Circles',
    category: 'exercise', subcategory: 'mobility',
    bodyParts: ['ankle', 'legs'], muscles: ['ankle stabilisers'],
    difficulty: 'beginner',
    instructions: [
      'Sit and lift one foot off the floor.',
      'Draw slow circles with your toes in one direction.',
      'Reverse, then change feet.',
    ],
    audioScript: 'Slow, controlled circles — as large as comfort allows. Reverse halfway. Good for stiff ankles and long hours sitting.',
    defaultDurationSec: 45, metValue: 1.5,
    equipment: ['chair'], contraindications: [],
    isSeatedFriendly: true, isLowImpact: true, isRecoveryFor: ['ankle'], intensity: 1,
  },
  {
    slug: 'hip-flexor-stretch',
    name: 'Kneeling Hip Flexor Stretch',
    category: 'exercise', subcategory: 'mobility',
    bodyParts: ['hips', 'legs'], muscles: ['hip flexors', 'quadriceps'],
    difficulty: 'beginner',
    instructions: [
      'Kneel on one knee with the other foot flat in front.',
      'Tuck your tailbone under and shift gently forward.',
      'Hold, then change sides.',
    ],
    audioScript:
      'Tuck the tailbone first — that small movement is what makes the stretch work. Shift forward only slightly. Long hours sitting shorten these muscles.',
    defaultDurationSec: 60, metValue: 2.0,
    equipment: ['mat'], contraindications: ['Knee injury'],
    isSeatedFriendly: false, isLowImpact: true, isRecoveryFor: ['lower_back', 'knee'], intensity: 1,
  },
  {
    slug: 'shoulder-pendulum',
    name: 'Shoulder Pendulum',
    category: 'exercise', subcategory: 'mobility',
    bodyParts: ['shoulders'], muscles: ['rotator cuff'],
    difficulty: 'beginner',
    instructions: [
      'Lean forward with one hand supported on a chair.',
      'Let the other arm hang loose.',
      'Swing it gently in small circles.',
    ],
    audioScript:
      'Let the arm hang completely loose and let momentum move it — the shoulder muscles should not be working. A common early rehabilitation movement, but check with a physiotherapist if you are recovering from an injury.',
    defaultDurationSec: 60, metValue: 1.8,
    equipment: ['chair'], contraindications: ['Recent shoulder surgery without clearance'],
    isSeatedFriendly: false, isLowImpact: true, isRecoveryFor: ['shoulder'], intensity: 1,
  },
];

// -----------------------------------------------------------------------------
// Integrity checks — run at import so a bad seed fails loudly at boot
// -----------------------------------------------------------------------------

const slugs = new Set<string>();
for (const e of EXERCISES) {
  if (slugs.has(e.slug)) throw new Error(`Duplicate exercise slug: ${e.slug}`);
  slugs.add(e.slug);

  if (e.audioScript.length < 40) {
    throw new Error(`${e.slug}: audio script is too short to be real coaching`);
  }
  if (e.instructions.length < 2) {
    throw new Error(`${e.slug}: needs at least two instruction steps`);
  }
  // The database enforces this too; failing here means we catch it before deploy.
  if ((e.isRecoveryFor.length > 0 || e.isSeatedFriendly) && e.intensity === 3) {
    throw new Error(`${e.slug}: recovery/accessible content must not be high intensity`);
  }
}

export const LIBRARY_STATS = {
  total: EXERCISES.length,
  byCategory: EXERCISES.reduce<Record<string, number>>((acc, e) => {
    acc[e.category] = (acc[e.category] ?? 0) + 1;
    return acc;
  }, {}),
  seatedFriendly: EXERCISES.filter((e) => e.isSeatedFriendly).length,
  recovery: EXERCISES.filter((e) => e.isRecoveryFor.length > 0).length,
};
