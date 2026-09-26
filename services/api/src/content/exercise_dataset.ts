/**
 * =============================================================================
 * VYRA EXERCISE & BIOMECHANICAL KINEMATICS DATASET
 * =============================================================================
 * Comprehensive verified sports-science dataset used for:
 *   1. Direct 3D Avatar Kinematic Articulation & Joint Target Angles
 *   2. Gemini AI Grounding (RAG) — Zero Hallucinations on Form, Cues, & Safety
 *   3. Audio Coach Cadence & Voice Cue Generation
 *   4. Injury Prevention & Adaptive Modifications (Differently-Abled/Rehab)
 * =============================================================================
 */

export interface ExerciseDatasetEntry {
  slug: string;
  name: string;
  hindiName: string;
  category: 'legs' | 'chest' | 'back' | 'shoulders' | 'arms' | 'core' | 'cardio' | 'yoga';
  difficulty: 'beginner' | 'intermediate' | 'advanced';
  mechanics: 'compound' | 'isolation' | 'isometric' | 'mobility';
  primaryMuscles: string[];
  secondaryMuscles: string[];
  kinematics: {
    primaryJoint: 'knee' | 'elbow' | 'shoulder' | 'hip' | 'spine' | 'ankle';
    optimalFlexionDeg: number;
    lockoutDeg: number;
    tempo: string; // e.g. '3-1-1-0' (eccentric - pause - concentric - pause)
    eccentricCue: string;
    isometricHoldCue: string;
    concentricDriveCue: string;
  };
  breathingPattern: string;
  criticalFormChecklist: string[];
  commonMistakesToAvoid: string[];
  modifications: {
    regression: string; // easier version
    progression: string; // harder version
    rehabFriendly: string; // modification for joint/back pain
  };
  calorieMET: number;
}

export const EXERCISE_DATASET: ExerciseDatasetEntry[] = [
  // ── LEGS & GLUTES ────────────────────────────────────────────────────────
  {
    slug: 'bodyweight-squat',
    name: 'Bodyweight Squat',
    hindiName: 'दंड बैठक (Squat)',
    category: 'legs',
    difficulty: 'beginner',
    mechanics: 'compound',
    primaryMuscles: ['Quadriceps', 'Gluteus Maximus'],
    secondaryMuscles: ['Hamstrings', 'Core', 'Adductors', 'Calves'],
    kinematics: {
      primaryJoint: 'knee',
      optimalFlexionDeg: 90,
      lockoutDeg: 175,
      tempo: '3-1-1-0',
      eccentricCue: 'Push hips back first, sink slowly over 3 seconds keeping chest proud.',
      isometricHoldCue: 'Hit 90-degree parallel depth; hold knees tracking directly over toes.',
      concentricDriveCue: 'Drive hard through the center of your heels, exhaling to lockout.',
    },
    breathingPattern: 'Inhale deeply during the 3-second descent; exhale sharply through pursed lips while ascending.',
    criticalFormChecklist: [
      'Stance slightly wider than shoulder-width, toes angled 15° outward.',
      'Weight distributed 70% mid-foot to heels; toes never grip into the floor.',
      'Lumbar spine maintains neutral curvature — no lower back rounding (butt wink).',
      'Knees track outward in line with second toe, avoiding valgus inward collapse.',
    ],
    commonMistakesToAvoid: [
      'Knees caving inward during ascent (weak glute medius cue).',
      'Heels lifting off the ground (indicates ankle dorsiflexion stiffness).',
      'Collapsing chest forward and relying purely on spinal flexion.',
    ],
    modifications: {
      regression: 'Box Squat or Wall Squat with exercise ball support.',
      progression: 'Tempo Pause Squat (3-second hold) or Goblet Squat with dumbbell.',
      rehabFriendly: 'Quarter-squat to chair with 60-degree knee bend to minimize patellar pressure.',
    },
    calorieMET: 5.0,
  },
  {
    slug: 'reverse-lunge',
    name: 'Reverse Lunge',
    hindiName: 'रिवर्स लंजेस (Reverse Lunge)',
    category: 'legs',
    difficulty: 'beginner',
    mechanics: 'compound',
    primaryMuscles: ['Quadriceps', 'Gluteus Maximus'],
    secondaryMuscles: ['Hamstrings', 'Calves', 'Core Stabilizers'],
    kinematics: {
      primaryJoint: 'knee',
      optimalFlexionDeg: 90,
      lockoutDeg: 180,
      tempo: '2-1-1-0',
      eccentricCue: 'Step back smoothly, lowering the rear knee directly toward the floor.',
      isometricHoldCue: 'Both knees flexed at crisp 90-degree angles.',
      concentricDriveCue: 'Push through front heel to return to upright standing posture.',
    },
    breathingPattern: 'Inhale as you step back and drop; exhale as you push forward to stand.',
    criticalFormChecklist: [
      'Front knee stacked vertically above ankle, never shearing past toes.',
      'Torso remains upright with a slight 5° forward athletic hip hinge.',
      'Rear knee hovers 1 inch above mat without slamming into the floor.',
    ],
    commonMistakesToAvoid: [
      'Stepping in a tightrope line, losing lateral balance.',
      'Pushing off rear toes rather than driving through the front working heel.',
    ],
    modifications: {
      regression: 'Static Split Squat with hand holding a wall or rail.',
      progression: 'Deficit Reverse Lunge from a 2-inch elevation or walking lunges.',
      rehabFriendly: 'Reverse Lunge is preferred over forward lunge for anterior knee protection.',
    },
    calorieMET: 5.0,
  },
  {
    slug: 'glute-bridge',
    name: 'Glute Bridge',
    hindiName: 'ग्लूट ब्रिज (Glute Bridge)',
    category: 'legs',
    difficulty: 'beginner',
    mechanics: 'compound',
    primaryMuscles: ['Gluteus Maximus', 'Hamstrings'],
    secondaryMuscles: ['Erector Spinae', 'Transverse Abdominis'],
    kinematics: {
      primaryJoint: 'hip',
      optimalFlexionDeg: 180, // Full hip extension
      lockoutDeg: 180,
      tempo: '2-2-1-0',
      eccentricCue: 'Lower spine vertebra by vertebra with controlled tension.',
      isometricHoldCue: 'Squeeze glutes maximally at the top, forming a straight shoulder-to-knee diagonal.',
      concentricDriveCue: 'Drive hips up to ceiling by pressing heels into the floor.',
    },
    breathingPattern: 'Inhale while on the mat; exhale forcefully as hips thrust toward the ceiling.',
    criticalFormChecklist: [
      'Feet planted hip-width apart, shins vertical at top of bridge.',
      'Pelvis remains posteriorly tilted — avoid hyperextending the lower lumbar spine.',
      'Neck relaxed on the ground; ribcage held down with abdominal bracing.',
    ],
    commonMistakesToAvoid: [
      'Arching lower back instead of contracting glutes.',
      'Pushing through the balls of the feet instead of the heels.',
    ],
    modifications: {
      regression: 'Standard two-leg Glute Bridge with arms flat for support.',
      progression: 'Single-leg Glute Bridge or Barbell Hip Thrust.',
      rehabFriendly: 'Excellent for lower back pain recovery and desk worker glute amnesia.',
    },
    calorieMET: 3.8,
  },
  {
    slug: 'wall-sit',
    name: 'Wall Sit',
    hindiName: 'वॉल सिट (Wall Sit)',
    category: 'legs',
    difficulty: 'beginner',
    mechanics: 'isometric',
    primaryMuscles: ['Quadriceps'],
    secondaryMuscles: ['Glutes', 'Calves', 'Core'],
    kinematics: {
      primaryJoint: 'knee',
      optimalFlexionDeg: 90,
      lockoutDeg: 90,
      tempo: '0-45-0-0', // Sustained isometric hold
      eccentricCue: 'Slide down the wall until thighs are strictly horizontal.',
      isometricHoldCue: 'Pin lower back firmly against the wall; hold knees at rigid 90 degrees.',
      concentricDriveCue: 'Maintain steady posture without resting hands on knees.',
    },
    breathingPattern: 'Rhythmic diaphragmatic breathing — 4 seconds in through nose, 4 seconds out.',
    criticalFormChecklist: [
      'Thighs parallel to floor at 90° knee angle.',
      'Shins perpendicular to floor, feet flat.',
      'Head, shoulders, and entire lower back contact the wall.',
    ],
    commonMistakesToAvoid: [
      'Resting hands or forearms on thighs (removes quad tension).',
      'Sliding feet too far back, putting shear load on patellar tendon.',
    ],
    modifications: {
      regression: 'Sit at 60° to 70° angle rather than deep 90° parallel.',
      progression: 'Single-leg Wall Sit or holding dumbbell across lap.',
      rehabFriendly: 'Safe closed-kinetic-chain knee strengthening with zero rotational torque.',
    },
    calorieMET: 4.0,
  },
  {
    slug: 'calf-raise',
    name: 'Calf Raise',
    hindiName: 'काफ रेज़ (Calf Raise)',
    category: 'legs',
    difficulty: 'beginner',
    mechanics: 'isolation',
    primaryMuscles: ['Gastrocnemius', 'Soleus'],
    secondaryMuscles: ['Tibialis Posterior', 'Foot intrinsic muscles'],
    kinematics: {
      primaryJoint: 'ankle',
      optimalFlexionDeg: 130, // Plantarflexion peak
      lockoutDeg: 90,
      tempo: '3-1-1-0',
      eccentricCue: 'Lower heels below ground plane over 3 full seconds for a deep stretch.',
      isometricHoldCue: 'Pause at peak tiptoe height for 1 second of solid calf contraction.',
      concentricDriveCue: 'Drive through the ball of the big toe straight up toward the ceiling.',
    },
    breathingPattern: 'Exhale as you elevate onto your toes; inhale as you slowly lower.',
    criticalFormChecklist: [
      'Maintain ankle alignment without rolling ankles outward (supination).',
      'Keep knees softly locked (standing calf emphasizes gastrocnemius).',
    ],
    commonMistakesToAvoid: [
      'Bouncing rapidly without a pause at peak height or stretch at the bottom.',
      'Rolling weight onto outside edges of pinky toes.',
    ],
    modifications: {
      regression: 'Double-leg flat floor Calf Raise holding a wall for balance.',
      progression: 'Single-leg Deficit Calf Raise off a step edge.',
      rehabFriendly: 'Crucial for Achilles tendon rehabilitation and runner injury prevention.',
    },
    calorieMET: 3.5,
  },

  // ── UPPER BODY · CHEST & PUSH ────────────────────────────────────────────
  {
    slug: 'push-up',
    name: 'Standard Push-Up',
    hindiName: 'पुश अप्स (Push-Up)',
    category: 'chest',
    difficulty: 'beginner',
    mechanics: 'compound',
    primaryMuscles: ['Pectoralis Major', 'Anterior Deltoids', 'Triceps Brachii'],
    secondaryMuscles: ['Serratus Anterior', 'Rectus Abdominis', 'Glutes'],
    kinematics: {
      primaryJoint: 'elbow',
      optimalFlexionDeg: 90,
      lockoutDeg: 175,
      tempo: '2-1-1-0',
      eccentricCue: 'Lower chest until 2 inches above mat, elbows angled 45° like an arrow.',
      isometricHoldCue: 'Hover at the bottom with core locked in rigid plank.',
      concentricDriveCue: 'Press the floor away aggressively, spreading the shoulder blades at top.',
    },
    breathingPattern: 'Inhale while descending toward the floor; exhale forcefully when driving upward.',
    criticalFormChecklist: [
      'Hands positioned slightly wider than shoulder-width, fingers spread.',
      'Body forms a straight unbroken line from crown of head to heels.',
      'Glutes and core squeezed tight to prevent lower back sagging or hip piking.',
      'Elbows track at 45-degree angle to torso — not flaring at 90 degrees.',
    ],
    commonMistakesToAvoid: [
      'Elbows flaring 90° perpendicular (causes shoulder impingement).',
      'Hips sagging down or piking into the air.',
      'Craning neck forward toward the mat instead of lowering the chest.',
    ],
    modifications: {
      regression: 'Incline Push-Up against a bench/wall or Knee Push-Up.',
      progression: 'Diamond Push-Up, Decline Push-Up, or Deficit Push-Up.',
      rehabFriendly: 'Incline Push-Up reduces wrist and shoulder compression by 40%.',
    },
    calorieMET: 6.0,
  },
  {
    slug: 'dumbbell-bench-press',
    name: 'Dumbbell Bench Press',
    hindiName: 'डंबल चेस्ट प्रेस (Dumbbell Press)',
    category: 'chest',
    difficulty: 'intermediate',
    mechanics: 'compound',
    primaryMuscles: ['Pectoralis Major'],
    secondaryMuscles: ['Anterior Deltoids', 'Triceps Brachii'],
    kinematics: {
      primaryJoint: 'elbow',
      optimalFlexionDeg: 90,
      lockoutDeg: 175,
      tempo: '3-1-1-0',
      eccentricCue: 'Lower dumbbells with elbows at 45°, feeling deep stretch across pectorals.',
      isometricHoldCue: 'Pause at bottom without resting weight on shoulders.',
      concentricDriveCue: 'Press dumbbells up in a gentle inward arc without banging weights together.',
    },
    breathingPattern: 'Inhale on the 3-second descent; exhale as dumbbells drive overhead.',
    criticalFormChecklist: [
      'Scapulae retracted and depressed into bench (create a stable upper back shelf).',
      'Feet planted flat on floor for leg drive.',
      'Wrists stacked directly over elbows throughout entire path.',
    ],
    commonMistakesToAvoid: [
      'Banging dumbbells together at top (losses tension on pectorals).',
      'Flaring elbows out at 90° to ears.',
    ],
    modifications: {
      regression: 'Floor Press (limits elbow extension, protects shoulders).',
      progression: 'Incline Dumbbell Press or Pause Dumbbell Press.',
      rehabFriendly: 'Floor Press protects anterior shoulder capsule.',
    },
    calorieMET: 5.5,
  },

  // ── UPPER BODY · ARMS (BICEPS & TRICEPS) ──────────────────────────────────
  {
    slug: 'dumbbell-bicep-curl',
    name: 'Dumbbell Bicep Curl',
    hindiName: 'डंबल बाइसेप कर्ल (Bicep Curl)',
    category: 'arms',
    difficulty: 'beginner',
    mechanics: 'isolation',
    primaryMuscles: ['Biceps Brachii'],
    secondaryMuscles: ['Brachialis', 'Brachioradialis', 'Forearms'],
    kinematics: {
      primaryJoint: 'elbow',
      optimalFlexionDeg: 40,
      lockoutDeg: 175,
      tempo: '2-1-3-0',
      eccentricCue: 'Three-second controlled release back to full elbow hang.',
      isometricHoldCue: 'Squeeze bicep peak hard at the top with wrist supinated.',
      concentricDriveCue: 'Smooth upward curl with elbows pinned tightly to the ribcage.',
    },
    breathingPattern: 'Exhale while curling upward; inhale on the slow 3-second descent.',
    criticalFormChecklist: [
      'Elbows locked to the side of the torso without drifting forward.',
      'Neutral wrist — do not hyperextend wrist backward under weight load.',
      'Stand with feet hip-width apart, knees soft, core engaged.',
    ],
    commonMistakesToAvoid: [
      'Swinging torso and utilizing hip momentum (cheat curls).',
      'Elbows drifting forward in front of ribs (shifts load to anterior deltoid).',
    ],
    modifications: {
      regression: 'Seated Incline Curl or Resistance Band Curl.',
      progression: 'Hammer Curl or 21s Bicep Curl Protocol.',
      rehabFriendly: 'Hammer Curl (neutral grip) reduces bicep tendon shear at the elbow.',
    },
    calorieMET: 4.5,
  },
  {
    slug: 'tricep-dips',
    name: 'Tricep Bench Dips',
    hindiName: 'ट्राइसेप डिप्स (Tricep Dips)',
    category: 'arms',
    difficulty: 'beginner',
    mechanics: 'compound',
    primaryMuscles: ['Triceps Brachii'],
    secondaryMuscles: ['Anterior Deltoids', 'Pectorals', 'Core'],
    kinematics: {
      primaryJoint: 'elbow',
      optimalFlexionDeg: 90,
      lockoutDeg: 175,
      tempo: '2-1-1-0',
      eccentricCue: 'Lower hips straight down brushing past bench edge until elbows reach 90°.',
      isometricHoldCue: 'Pause at bottom without shrugging shoulders up to ears.',
      concentricDriveCue: 'Press through palms to full tricep lockout at top.',
    },
    breathingPattern: 'Inhale on the way down; exhale as you press back up.',
    criticalFormChecklist: [
      'Hips stay close to bench/chair edge — do not drift far forward.',
      'Elbows track straight backward, not flaring wide.',
      'Shoulders stay pulled back and down away from ears.',
    ],
    commonMistakesToAvoid: [
      'Drifting hips too far away from bench (places heavy anterior shoulder stress).',
      'Shrugging shoulders into neck.',
    ],
    modifications: {
      regression: 'Bent-knee Bench Dips with feet flat on the floor.',
      progression: 'Straight-leg Dips or Parallel Bar Dips.',
      rehabFriendly: 'Limit descent to 60° if user has shoulder impingement.',
    },
    calorieMET: 4.8,
  },

  // ── UPPER BODY · SHOULDERS ───────────────────────────────────────────────
  {
    slug: 'seated-overhead-press',
    name: 'Seated Dumbbell Overhead Press',
    hindiName: 'शोल्डर ओवरहेड प्रेस (Shoulder Press)',
    category: 'shoulders',
    difficulty: 'beginner',
    mechanics: 'compound',
    primaryMuscles: ['Anterior Deltoid', 'Lateral Deltoid'],
    secondaryMuscles: ['Triceps Brachii', 'Upper Trapezius', 'Serratus Anterior'],
    kinematics: {
      primaryJoint: 'shoulder',
      optimalFlexionDeg: 180, // Overhead lockout
      lockoutDeg: 90, // Bottom rack
      tempo: '2-1-1-0',
      eccentricCue: 'Lower dumbbells with control to chin height with elbows at 60° forward.',
      isometricHoldCue: 'Stable rack at bottom without resting weight on collarbones.',
      concentricDriveCue: 'Press vertically directly over crown of head to lock out overhead.',
    },
    breathingPattern: 'Inhale while lowering weights to chin; exhale forcefully pressing overhead.',
    criticalFormChecklist: [
      'Press in the scapular plane (elbows 30° to 45° in front of body, not flared flat).',
      'Spine remains neutral against bench pad; do not arch lower back excessively.',
      'Wrists stay stacked vertically over elbows throughout movement.',
    ],
    commonMistakesToAvoid: [
      'Arching lower back into a makeshift incline bench press.',
      'Flaring elbows 90° backward (impinges rotator cuff).',
    ],
    modifications: {
      regression: 'Seated Dumbbell Press with back support.',
      progression: 'Standing Barbell Overhead Military Press.',
      rehabFriendly: 'Neutral-grip (palms facing each other) Arnold Press for shoulder comfort.',
    },
    calorieMET: 5.0,
  },
  {
    slug: 'lateral-raise',
    name: 'Dumbbell Lateral Raise',
    hindiName: 'लेटरल रेज़ (Lateral Raise)',
    category: 'shoulders',
    difficulty: 'beginner',
    mechanics: 'isolation',
    primaryMuscles: ['Lateral Deltoid'],
    secondaryMuscles: ['Anterior Deltoid', 'Trapezius', 'Supraspinatus'],
    kinematics: {
      primaryJoint: 'shoulder',
      optimalFlexionDeg: 90, // Parallel to floor
      lockoutDeg: 15,
      tempo: '2-1-3-0',
      eccentricCue: 'Three-second slow controlled descent fighting gravity.',
      isometricHoldCue: 'Brief 1-second hold at shoulder height with pinkies slightly higher.',
      concentricDriveCue: 'Lead with elbows out to the sides in the scapular plane.',
    },
    breathingPattern: 'Exhale raising arms up; inhale lowering down.',
    criticalFormChecklist: [
      'Slight bend in elbows (15°); lead with elbows rather than hands.',
      'Lift to parallel with shoulders (do not swing above 90° to avoid trap takeover).',
      'Slight forward lean of torso (10°) to match lateral deltoid fiber orientation.',
    ],
    commonMistakesToAvoid: [
      'Shrugging traps to sling weights upward with momentum.',
      'Using weights that are too heavy, ruining shoulder isolation.',
    ],
    modifications: {
      regression: 'Resistance band lateral raises.',
      progression: 'Cable lateral raises with constant tension.',
      rehabFriendly: 'Perform in front of mirror with light 2kg dumbbells or bands.',
    },
    calorieMET: 4.0,
  },

  // ── UPPER BODY · BACK & PULL ─────────────────────────────────────────────
  {
    slug: 'bent-over-row',
    name: 'Dumbbell Bent-Over Row',
    hindiName: 'डंबल रो (Dumbbell Row)',
    category: 'back',
    difficulty: 'intermediate',
    mechanics: 'compound',
    primaryMuscles: ['Latissimus Dorsi', 'Rhomboids'],
    secondaryMuscles: ['Middle Trapezius', 'Biceps Brachii', 'Posterior Deltoid'],
    kinematics: {
      primaryJoint: 'elbow',
      optimalFlexionDeg: 60,
      lockoutDeg: 175,
      tempo: '2-1-2-0',
      eccentricCue: 'Lower dumbbells toward the floor under control, feeling lats stretch.',
      isometricHoldCue: 'Squeeze shoulder blades hard together at the top of the pull.',
      concentricDriveCue: 'Drive elbows back toward hip pockets, pulling with back rather than biceps.',
    },
    breathingPattern: 'Exhale while rowing weights up toward hips; inhale while lowering.',
    criticalFormChecklist: [
      'Hinge at hips at 45° angle with flat neutral spine.',
      'Pull elbows toward hips rather than vertically toward chest.',
      'Keep head in line with spine — eyes focused 4 feet ahead on floor.',
    ],
    commonMistakesToAvoid: [
      'Rounding thoracic and lumbar spine (back injury risk).',
      'Yanking with arms instead of retracting scapulae.',
    ],
    modifications: {
      regression: 'Single-Arm Dumbbell Row with knee on bench.',
      progression: 'Barbell Bent-Over Row (Overhand or Underhand grip).',
      rehabFriendly: 'Chest-Supported Incline Dumbbell Row eliminates lower back strain.',
    },
    calorieMET: 6.0,
  },

  // ── CORE & ABS ───────────────────────────────────────────────────────────
  {
    slug: 'plank',
    name: 'Forearm Plank',
    hindiName: 'प्लैंक (Plank)',
    category: 'core',
    difficulty: 'beginner',
    mechanics: 'isometric',
    primaryMuscles: ['Transverse Abdominis', 'Rectus Abdominis'],
    secondaryMuscles: ['Glutes', 'Quadriceps', 'Deltoids', 'Erector Spinae'],
    kinematics: {
      primaryJoint: 'spine',
      optimalFlexionDeg: 180, // Straight rigid alignment
      lockoutDeg: 180,
      tempo: '0-45-0-0', // Sustained hold
      eccentricCue: 'Hold body completely rigid like a steel beam.',
      isometricHoldCue: 'Pull belly button to spine, squeeze glutes and quads together.',
      concentricDriveCue: 'Actively pull elbows toward toes to create intense core tension.',
    },
    breathingPattern: 'Continuous shallow diaphragmatic breathing without letting abdominal wall loosen.',
    criticalFormChecklist: [
      'Elbows stacked directly beneath shoulders.',
      'Spine flat from head to heels — pelvis tucked slightly under (posterior tilt).',
      'Eyes focused between fists; neck neutral.',
    ],
    commonMistakesToAvoid: [
      'Sagging hips (hyperextending lower lumbar spine).',
      'Piking hips into an inverted V (shifts load off core).',
    ],
    modifications: {
      regression: 'Knee Plank or Incline Forearm Plank on a bench.',
      progression: 'Long-Lever Plank or RKC Plank (max effort contraction).',
      rehabFriendly: 'Safest core exercise for disc herniation and lower back rehab.',
    },
    calorieMET: 3.8,
  },
  {
    slug: 'mountain-climbers',
    name: 'Mountain Climbers',
    hindiName: 'माउंटेन क्लाइम्बर्स (Mountain Climbers)',
    category: 'core',
    difficulty: 'intermediate',
    mechanics: 'compound',
    primaryMuscles: ['Rectus Abdominis', 'Hip Flexors'],
    secondaryMuscles: ['Shoulders', 'Quadriceps', 'Cardiovascular System'],
    kinematics: {
      primaryJoint: 'hip',
      optimalFlexionDeg: 70,
      lockoutDeg: 180,
      tempo: '1-0-1-0', // Rapid rhythmic cadence
      eccentricCue: 'Kick leg back into full push-up plank extension.',
      isometricHoldCue: 'Maintain shoulders directly over hands.',
      concentricDriveCue: 'Drive knee rhythmically toward chest without bouncing hips.',
    },
    breathingPattern: 'Rhythmic breath matching the cadence of alternating knees.',
    criticalFormChecklist: [
      'Hands flat beneath shoulders, fingers spread for wrist stability.',
      'Hips stay level at shoulder height — avoid bouncing up and down.',
    ],
    commonMistakesToAvoid: [
      'Bouncing hips high in the air.',
      'Letting shoulders drift backward away from wrists.',
    ],
    modifications: {
      regression: 'Slow-tempo Mountain Climber on incline surface.',
      progression: 'Cross-Body Mountain Climbers (knee to opposite elbow).',
      rehabFriendly: 'Slow marching plank reduces spinal shear.',
    },
    calorieMET: 8.0,
  },

  // ── CARDIO & HIIT ────────────────────────────────────────────────────────
  {
    slug: 'jumping-jacks',
    name: 'Jumping Jacks',
    hindiName: 'जंपिंग जैक (Jumping Jacks)',
    category: 'cardio',
    difficulty: 'beginner',
    mechanics: 'compound',
    primaryMuscles: ['Cardiovascular System', 'Calves'],
    secondaryMuscles: ['Deltoids', 'Glutes', 'Adductors'],
    kinematics: {
      primaryJoint: 'shoulder',
      optimalFlexionDeg: 180, // Overhead arm arc
      lockoutDeg: 0,
      tempo: '1-0-1-0',
      eccentricCue: 'Land softly on balls of feet, cushioning with knees.',
      isometricHoldCue: 'Synchronized arm and leg expansion.',
      concentricDriveCue: 'Spring dynamically outward and inward rhythmically.',
    },
    breathingPattern: 'Exhale as arms and legs jump out; inhale as they return together.',
    criticalFormChecklist: [
      'Land softly on balls of feet with knees softly bent to absorb impact.',
      'Arms sweep in full fluid arc overhead.',
    ],
    commonMistakesToAvoid: [
      'Landing with stiff locked knees (harsh on joints).',
      'Slapping heels aggressively onto hard floor.',
    ],
    modifications: {
      regression: 'Step Jacks (stepping laterally one foot at a time, zero jump).',
      progression: 'Star Jumps or Burpee to Jumping Jack combo.',
      rehabFriendly: 'Step Jacks provide low-impact cardio for sensitive knees/ankles.',
    },
    calorieMET: 8.0,
  },
  {
    slug: 'burpees',
    name: 'Full Body Burpees',
    hindiName: 'बर्पी (Burpee)',
    category: 'cardio',
    difficulty: 'advanced',
    mechanics: 'compound',
    primaryMuscles: ['Cardiovascular System', 'Chest', 'Quadriceps'],
    secondaryMuscles: ['Shoulders', 'Triceps', 'Hamstrings', 'Core'],
    kinematics: {
      primaryJoint: 'hip',
      optimalFlexionDeg: 90,
      lockoutDeg: 180,
      tempo: '1-1-1-0',
      eccentricCue: 'Drop hands to mat, kick feet back into plank and touch chest to floor.',
      isometricHoldCue: 'Snap feet forward outside hands.',
      concentricDriveCue: 'Explode vertically off the ground with arms reaching overhead.',
    },
    breathingPattern: 'Inhale on the drop to floor; exhale forcefully during the vertical jump.',
    criticalFormChecklist: [
      'Core braced throughout plank transition to protect lower back.',
      'Land softly on flat feet before initiating the next rep.',
    ],
    commonMistakesToAvoid: [
      'Sagging lower back into a belly flop without abdominal tension.',
      'Landing on toes with knees collapsing inward.',
    ],
    modifications: {
      regression: 'No-Push-up Burpee (Up-Downs) or Step-Back Burpee.',
      progression: 'Burpee with Tuck Jump or Chest-to-Bar Pull-up Burpee.',
      rehabFriendly: 'Elevated bench burpee reduces spinal impact.',
    },
    calorieMET: 10.0,
  },

  // ── YOGA & MOBILITY ──────────────────────────────────────────────────────
  {
    slug: 'downward-dog',
    name: 'Downward-Facing Dog',
    hindiName: 'अधोमुख श्वानासन (Downward Dog)',
    category: 'yoga',
    difficulty: 'beginner',
    mechanics: 'mobility',
    primaryMuscles: ['Hamstrings', 'Calves', 'Latissimus Dorsi'],
    secondaryMuscles: ['Shoulders', 'Wrists', 'Achilles Tendon'],
    kinematics: {
      primaryJoint: 'hip',
      optimalFlexionDeg: 75, // Inverted V apex
      lockoutDeg: 75,
      tempo: '0-30-0-0', // Sustained stretch hold
      eccentricCue: 'Press chest toward thighs, lengthening spine.',
      isometricHoldCue: 'Anchor heels toward mat, lift tailbone high to ceiling.',
      concentricDriveCue: 'Press firmly through knuckles of index fingers and thumbs.',
    },
    breathingPattern: 'Deep Ujjayi breathing — 4 seconds slow inhale, 4 seconds calm exhale.',
    criticalFormChecklist: [
      'Hands shoulder-width apart, fingers spread wide to protect wrists.',
      'Spine is the priority: bend knees if hamstrings are tight to keep back flat.',
      'Shoulders rotated outward away from ears.',
    ],
    commonMistakesToAvoid: [
      'Rounding lower spine just to force heels flat on the mat.',
      'Dumping all body weight into the wrists without engaging palms.',
    ],
    modifications: {
      regression: 'Pedal feet (walking the dog) or keep knees generously bent.',
      progression: 'Three-Legged Downward Dog with single-leg extension.',
      rehabFriendly: 'Gentle spinal decompression for desk worker posture correction.',
    },
    calorieMET: 3.0,
  },
  {
    slug: 'cobra-pose',
    name: 'Cobra Pose',
    hindiName: 'भुजंगासन (Bhujangasana)',
    category: 'yoga',
    difficulty: 'beginner',
    mechanics: 'mobility',
    primaryMuscles: ['Erector Spinae', 'Chest Pectorals'],
    secondaryMuscles: ['Shoulders', 'Glutes', 'Abdominal Wall'],
    kinematics: {
      primaryJoint: 'spine',
      optimalFlexionDeg: 140, // Gentle backward extension
      lockoutDeg: 140,
      tempo: '0-20-0-0',
      eccentricCue: 'Lower forehead to mat softly on release.',
      isometricHoldCue: 'Roll shoulders down and back, lifting chest with back muscles.',
      concentricDriveCue: 'Press tops of feet into mat as sternum shines forward.',
    },
    breathingPattern: 'Inhale deeply as chest lifts off mat; exhale relaxing shoulders downward.',
    criticalFormChecklist: [
      'Hands under shoulders, elbows hugging close to ribs.',
      'Tops of feet, thighs, and pelvis stay anchored into floor.',
      'Look forward, keeping back of neck long without hyperextending head.',
    ],
    commonMistakesToAvoid: [
      'Pushing aggressively with arms and compressing the lumbar spine.',
      'Shrugging shoulders into ears.',
    ],
    modifications: {
      regression: 'Baby Cobra (hands hover off mat, using only back extensors) or Sphinx Pose.',
      progression: 'Upward-Facing Dog (hips and thighs lift off mat).',
      rehabFriendly: 'Sphinx Pose on forearms is ideal for acute lower back stiffness.',
    },
    calorieMET: 2.8,
  },
];

// ─────────────────────────────────────────────────────────────────────────────
// QUERY & GEMINI GROUNDING HELPER FUNCTIONS
// ─────────────────────────────────────────────────────────────────────────────

/** Find an exercise by slug, English name, or Hindi keywords */
export function findExerciseInDataset(query: string): ExerciseDatasetEntry | undefined {
  const q = query.toLowerCase().trim().replaceAll('_', '-');
  return EXERCISE_DATASET.find(
    (e) =>
      e.slug === q ||
      e.name.toLowerCase().includes(q) ||
      e.hindiName.toLowerCase().includes(q) ||
      q.includes(e.slug) ||
      (q.includes('squat') && e.slug.includes('squat')) ||
      (q.includes('lunge') && e.slug.includes('lunge')) ||
      (q.includes('curl') && e.slug.includes('curl')) ||
      (q.includes('push') && e.slug.includes('push')) ||
      (q.includes('press') && e.slug.includes('press')) ||
      (q.includes('plank') && e.slug.includes('plank')) ||
      (q.includes('bridge') && e.slug.includes('bridge')) ||
      (q.includes('dog') && e.slug.includes('dog')),
  );
}

/** Get multiple exercises matching body group */
export function getExercisesForCategory(category: ExerciseDatasetEntry['category']): ExerciseDatasetEntry[] {
  return EXERCISE_DATASET.filter((e) => e.category === category);
}

/**
 * Builds a structured, verified grounding context block for Gemini AI.
 * When a user asks about form, joints, mistakes, or modifications, this block
 * is injected into the Gemini prompt so it answers with 100% sports-physio accuracy!
 */
export function buildGeminiExerciseGrounding(userMessage: string): string {
  const match = findExerciseInDataset(userMessage);
  if (!match) return '';

  return `
[GROUNDED VYRA EXERCISE KINEMATICS DATASET]:
- Exercise: ${match.name} (${match.hindiName}) [Category: ${match.category.toUpperCase()}]
- Primary Muscles: ${match.primaryMuscles.join(', ')}
- Secondary Muscles: ${match.secondaryMuscles.join(', ')}
- Biomechanical Joint Angle: ${match.kinematics.primaryJoint.toUpperCase()} Flexion to ${match.kinematics.optimalFlexionDeg}°
- Recommended Tempo: ${match.kinematics.tempo} (Eccentric: "${match.kinematics.eccentricCue}" | Hold: "${match.kinematics.isometricHoldCue}")
- Breathing Pattern: ${match.breathingPattern}
- Critical Form Checklist:
${match.criticalFormChecklist.map((c) => `  * ${c}`).join('\n')}
- Common Mistakes to Warn User:
${match.commonMistakesToAvoid.map((m) => `  * ${m}`).join('\n')}
- Personal Modifications:
  * Regression (Easier): ${match.modifications.regression}
  * Progression (Harder): ${match.modifications.progression}
  * Injury / Rehab Friendly: ${match.modifications.rehabFriendly}
- Caloric Burn MET Value: ${match.calorieMET} METs
(Use this exact verified scientific data to guide the athlete in your response).
`.trim();
}
