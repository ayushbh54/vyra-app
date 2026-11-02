/**
 * =============================================================================
 * VYRA NEUROSYNC™ ADAPTIVE BIOCOGNITIVE ENGINE (v7.0)
 * =============================================================================
 * World-class intelligent recommendation engine that dynamically synthesizes:
 *   1. Clinical & Metabolic Biomarkers (TSH, Glucose, HbA1c, Lipids, Uric Acid, Hb)
 *   2. BMR / TDEE & Real-Time Caloric Flux (Logged calories vs daily budget)
 *   3. Missed Workout Memory & 48h Muscle Group Recovery Matrix (Anti-Repetition)
 *   4. Training Modality Preference (Gym Iron vs Home Calisthenics vs Light Mobility vs Shred)
 *   5. Weekly Synchronized Workout & Periodized Nutrition Matrix (7-Day Mon–Sun)
 * =============================================================================
 */

import type { StoredUser, StoredPlan } from '../store';
import { EXERCISES, type SeedExercise } from '../content/exercises';
import type { PlaceableExercise } from './chrono';

export type TrainingModality = 'gym' | 'home' | 'light' | 'shred';

export type MetabolicArchetype =
  | 'sluggish_hypothyroid'       // TSH > 4.0 mIU/L
  | 'hyper_metabolic'            // TSH < 0.4 mIU/L
  | 'glycemic_insulin_resistant' // Glucose > 100 or HbA1c > 5.7%
  | 'hyperlipidemic'             // LDL > 130 or Triglycerides > 150
  | 'hyperuricemic'              // Uric Acid > 6.5
  | 'hypoxic_anemic'             // Hemoglobin < 12
  | 'balanced_athletic';

export interface BmrTdeeMetrics {
  bmrKcal: number;
  tdeeKcal: number;
  bmi: number;
  bmiCategory: 'underweight' | 'normal' | 'overweight' | 'obese';
  targetCaloricBudget: number;
  caloricDeltaKcal: number;
  caloricState: 'surplus' | 'deficit' | 'balanced';
}

export interface MuscleRecoveryStatus {
  recentMusclesTrained: string[];
  missedMuscles: string[];
  priorityFocusMuscles: string[];
  restedMuscles: string[];
}

export interface WeeklyDaySchedule {
  day: string;
  dayShort: string;
  theme: string;
  targetMuscles: string[];
  intensity: 'High' | 'Moderate' | 'Light' | 'Rest';
  sampleExercises: string[];
  dietaryStrategy: string;
  metabolicFocus: string;
}

export interface NeuroSyncBrainOutput {
  modality: TrainingModality;
  metabolicArchetype: MetabolicArchetype;
  metabolismSummary: string;
  caloricStatusSummary: string;
  muscleRecoverySummary: string;
  clinicalSafetyNotes: string[];
  aiReasoning: string;
  metrics: BmrTdeeMetrics;
  weeklyPeriodizedMatrix: WeeklyDaySchedule[];
  recommendedPool: PlaceableExercise[];
}

// -----------------------------------------------------------------------------
// 1. METABOLISM & BIOMARKER CLASSIFIER
// -----------------------------------------------------------------------------

export function evaluateMetabolicProfile(
  user: StoredUser,
  loggedCaloriesToday?: number,
): { archetype: MetabolicArchetype; summary: string; metrics: BmrTdeeMetrics; safetyNotes: string[] } {
  const heightM = (user.heightCm || 170) / 100;
  const weight = user.weightKg || 68;
  const bmi = Math.round((weight / (heightM * heightM)) * 10) / 10;

  let bmiCategory: BmrTdeeMetrics['bmiCategory'] = 'normal';
  if (bmi < 18.5) bmiCategory = 'underweight';
  else if (bmi >= 25 && bmi < 29.9) bmiCategory = 'overweight';
  else if (bmi >= 30) bmiCategory = 'obese';

  // Age calculation from DOB
  let age = 22;
  if (user.dob) {
    const birthYear = new Date(user.dob).getFullYear();
    const currentYear = new Date().getFullYear();
    if (!isNaN(birthYear) && birthYear > 1920) age = currentYear - birthYear;
  }

  // Mifflin-St Jeor BMR
  const isMale = (user.gender ?? 'male').toLowerCase() === 'male';
  const bmr = Math.round(
    10 * weight + 6.25 * (user.heightCm || 170) - 5 * age + (isMale ? 5 : -161)
  );

  // TDEE with moderate daily athletic factor (1.35)
  const tdee = Math.round(bmr * 1.35);

  // Caloric target based on fitness goal
  let targetCaloricBudget = tdee;
  if (user.fitnessGoal === 'lose_weight') {
    targetCaloricBudget = Math.round(tdee - 450); // Safe 450 kcal deficit
  } else if (user.fitnessGoal === 'gain_weight') {
    targetCaloricBudget = Math.round(tdee + 350); // Clean 350 kcal surplus
  }

  const logged = loggedCaloriesToday ?? targetCaloricBudget;
  const delta = logged - targetCaloricBudget;
  let caloricState: BmrTdeeMetrics['caloricState'] = 'balanced';
  if (delta > 200) caloricState = 'surplus';
  else if (delta < -250) caloricState = 'deficit';

  const markers = user.latestLabMarkers ?? {};
  const safetyNotes: string[] = [];
  let archetype: MetabolicArchetype = 'balanced_athletic';
  let summary = 'Optimal athletic baseline: balanced energy expenditure and glycogen turnover.';

  // Biomarker Classification
  const tsh = markers['tsh'];
  const glucose = markers['fasting_glucose'] ?? markers['glucose'] ?? markers['blood_sugar'];
  const hba1c = markers['hba1c'];
  const ldl = markers['ldl'];
  const trig = markers['triglycerides'];
  const uricAcid = markers['uric_acid'];
  const hb = markers['hemoglobin'];

  if (tsh !== undefined && tsh > 4.0) {
    archetype = 'sluggish_hypothyroid';
    summary = `Depressed metabolic rate (TSH ${tsh.toFixed(1)} mIU/L). Body exhibits increased water retention and slower basal expenditure; compound mechanical stimulation prescribed to upregulate resting metabolism.`;
    safetyNotes.push('Avoid extreme prolonged cardio that spikes systemic cortisol. Focus on compound progressive resistance.');
  } else if (tsh !== undefined && tsh < 0.4) {
    archetype = 'hyper_metabolic';
    summary = `Elevated basal turnover (TSH ${tsh.toFixed(2)} mIU/L). Body burns through glycogen and amino acids rapidly; volume clamped to prevent catabolic muscle breakdown.`;
    safetyNotes.push('Keep hydration above 3.2L and prioritize muscle-sparing high-protein meals.');
  } else if ((glucose !== undefined && glucose > 100) || (hba1c !== undefined && hba1c > 5.7)) {
    archetype = 'glycemic_insulin_resistant';
    const gVal = glucose ?? (hba1c ? hba1c * 20 : 110);
    summary = `Sub-optimal insulin sensitivity (Glucose ~${Math.round(gVal)} mg/dL). High-volume compound contractions prioritized across quads and glutes to function as glucose disposal sinks.`;
    safetyNotes.push('Postprandial resistance movements accelerate GLUT-4 glucose uptake without insulin dependency.');
  } else if ((ldl !== undefined && ldl > 130) || (trig !== undefined && trig > 150)) {
    archetype = 'hyperlipidemic';
    summary = `Elevated circulating lipids (LDL ${ldl ?? 140} mg/dL). Sustained mitochondrial fatty acid oxidation circuits prioritized.`;
    safetyNotes.push('Incorporate Zone 2 steady-state movement to upregulate beta-oxidation and HDL clearance.');
  } else if (uricAcid !== undefined && uricAcid > 6.5) {
    archetype = 'hyperuricemic';
    summary = `Elevated serum uric acid (${uricAcid.toFixed(1)} mg/dL). Joint-friendly, non-concussive loading prescribed with strict hydration guarding.`;
    safetyNotes.push('Zero plyometric foot pounding to protect joints; maintain minimum 3.5L daily hydration.');
  } else if (hb !== undefined && hb < 12.0) {
    archetype = 'hypoxic_anemic';
    summary = `Sub-clinical oxygen carrying capacity (Hemoglobin ${hb.toFixed(1)} g/dL). Strict aerobic ceiling enforced to prevent lactic acidosis and hypoxia.`;
    safetyNotes.push('Strictly clamp high-intensity anaerobic sprints. Limit sets to controlled tempo with generous rest.');
  }

  return {
    archetype,
    summary,
    metrics: {
      bmrKcal: bmr,
      tdeeKcal: tdee,
      bmi,
      bmiCategory,
      targetCaloricBudget,
      caloricDeltaKcal: delta,
      caloricState,
    },
    safetyNotes,
  };
}

// -----------------------------------------------------------------------------
// 2. MUSCLE RECOVERY & MISSED EXERCISE TRACKER
// -----------------------------------------------------------------------------

export function analyzeMuscleHistory(pastPlans: StoredPlan[]): MuscleRecoveryStatus {
  const recentMusclesTrained = new Set<string>();
  const missedMuscles = new Set<string>();

  // Look back at the most recent 1 to 3 days
  const sortedPlans = [...pastPlans].sort((a, b) => b.planDate.localeCompare(a.planDate));
  const yesterday = sortedPlans[0];
  const priorDays = sortedPlans.slice(1, 3);

  // Yesterday's completed exercises -> 48h active recovery
  if (yesterday) {
    for (const entry of yesterday.entries) {
      if (entry.isCompleted) {
        const ex = EXERCISES.find((e) => e.slug === entry.exerciseSlug);
        if (ex) {
          ex.bodyParts.forEach((bp) => recentMusclesTrained.add(bp.toLowerCase()));
          ex.muscles.forEach((m) => recentMusclesTrained.add(m.toLowerCase()));
        }
      } else {
        // Missed yesterday!
        const ex = EXERCISES.find((e) => e.slug === entry.exerciseSlug);
        if (ex) {
          ex.bodyParts.forEach((bp) => missedMuscles.add(bp.toLowerCase()));
        }
      }
    }
  }

  // Prior days' missed exercises
  for (const plan of priorDays) {
    for (const entry of plan.entries) {
      if (!entry.isCompleted) {
        const ex = EXERCISES.find((e) => e.slug === entry.exerciseSlug);
        if (ex) {
          ex.bodyParts.forEach((bp) => missedMuscles.add(bp.toLowerCase()));
        }
      }
    }
  }

  // Priority focus: Missed muscle groups that are NOT in active 48h recovery
  const priorityFocusMuscles = [...missedMuscles].filter((m) => !recentMusclesTrained.has(m));

  const allMajorGroups = ['chest', 'back', 'legs', 'shoulders', 'arms', 'core', 'glutes'];
  const restedMuscles = allMajorGroups.filter((g) => !recentMusclesTrained.has(g));

  return {
    recentMusclesTrained: [...recentMusclesTrained],
    missedMuscles: [...missedMuscles],
    priorityFocusMuscles: priorityFocusMuscles.length > 0 ? priorityFocusMuscles : restedMuscles,
    restedMuscles,
  };
}

// -----------------------------------------------------------------------------
// 3. 7-DAY SYNCHRONIZED WORKOUT & DIETARY PERIODIZATION MATRIX
// -----------------------------------------------------------------------------

export function buildWeeklyPeriodizedMatrix(
  goal: string,
  modality: TrainingModality,
  metabolicArchetype: MetabolicArchetype,
): WeeklyDaySchedule[] {
  const isGym = modality === 'gym';
  const isLight = modality === 'light';

  return [
    {
      day: 'Monday',
      dayShort: 'MON',
      theme: isLight ? 'Gentle Upper Mobility & Torso Alignment' : 'Push Hypertrophy: Chest, Deltoids & Triceps',
      targetMuscles: ['Chest', 'Anterior Deltoids', 'Triceps'],
      intensity: isLight ? 'Light' : 'High',
      sampleExercises: isGym
        ? ['Barbell Bench Press', 'Incline Dumbbell Press', 'Tricep Parallel Dips']
        : ['Push-Up', 'Wall Push-Up', 'Arm Circles'],
      dietaryStrategy: 'High Protein (2.0g/kg) + Glycogen Replenishment Complex Carbs (Oats, Brown Rice)',
      metabolicFocus: 'Anabolic Muscle Protein Synthesis peak following weekend rest.',
    },
    {
      day: 'Tuesday',
      dayShort: 'TUE',
      theme: isLight ? 'Spine Decompression & Breathing Flow' : 'Pull Strength: Latissimus, Rhomboids & Biceps',
      targetMuscles: ['Lats', 'Upper Back', 'Biceps'],
      intensity: isLight ? 'Light' : 'High',
      sampleExercises: isGym
        ? ['Barbell Deadlift', 'Dumbbell Bent-Over Row', 'Pull-Up', 'Dumbbell Hammer Curl']
        : ['Dead Bug', 'Bird Dog', 'Dumbbell Bicep Curl'],
      dietaryStrategy: 'Lean Protein (Paneer/Chicken/Dal) + Anti-Inflammatory Turmeric & Omega-3',
      metabolicFocus: 'Posterior chain recruitment; steady-state lipid & amino acid balance.',
    },
    {
      day: 'Wednesday',
      dayShort: 'WED',
      theme: isLight ? 'Knee & Hip Joint Lubrication' : 'Lower Body Power: Quads, Glutes & Hamstrings',
      targetMuscles: ['Quadriceps', 'Hamstrings', 'Glutes', 'Calves'],
      intensity: isLight ? 'Light' : 'High',
      sampleExercises: isGym
        ? ['Barbell Back Squat', 'Romanian Deadlift (RDL)', '45° Leg Press']
        : ['Bodyweight Squat', 'Reverse Lunge', 'Glute Bridge', 'Wall Sit'],
      dietaryStrategy: 'Peak Starch Carbs (Roti/Sweet Potato) for maximum leg glycogen saturation',
      metabolicFocus: 'Massive insulin-independent GLUT-4 glucose disposal into lower body muscle mass.',
    },
    {
      day: 'Thursday',
      dayShort: 'THU',
      theme: 'Active Recovery, Joint Decompression & Fascial Flow',
      targetMuscles: ['Full Body', 'Fascia', 'Rotator Cuff', 'Hips'],
      intensity: 'Light',
      sampleExercises: ['Cat-Cow', 'Child’s Pose', 'Downward Dog', 'Hip Flexor Stretch', 'Shoulder Pendulum'],
      dietaryStrategy: 'Moderate Caloric Balance, High Micronutrient Green Salads & 3.5L Electrolyte Hydration',
      metabolicFocus: 'Parasympathetic nervous system recovery, cortisol suppression, and cellular repair.',
    },
    {
      day: 'Friday',
      dayShort: 'FRI',
      theme: isLight ? 'Postural Core & Cervical Balance' : 'Upper Body Hypertrophy Surge & Shoulder Armor',
      targetMuscles: ['Shoulders', 'Upper Chest', 'Arms', 'Core'],
      intensity: isLight ? 'Moderate' : 'High',
      sampleExercises: isGym
        ? ['Overhead Barbell Press', 'Dumbbell Lateral Raise', 'Cable Face Pull', 'Hanging Leg Raise']
        : ['Seated Shoulder Press', 'Knee Push-Up', 'Plank', 'Russian Twists'],
      dietaryStrategy: 'Pre-Workout Banana/Curd + Sustained Protein Flux for structural hypertrophy',
      metabolicFocus: 'Upper body mechanical tension and micro-trauma adaptation before weekend.',
    },
    {
      day: 'Saturday',
      dayShort: 'SAT',
      theme: 'Metabolic Conditioning, Core Matrix & Cardio Surge',
      targetMuscles: ['Core', 'Obliques', 'Full Body Cardiovascular'],
      intensity: 'High',
      sampleExercises: isGym
        ? ['Kettlebell Swing', 'Mountain Climbers', 'Russian Twists', 'Burpees']
        : ['Tabata Squat Thrust', 'High Knees', 'Mountain Climbers', 'Plank'],
      dietaryStrategy: 'High Hydration + Clean Complex Carbs (Dal Khichdi, Sprouts) for mitochondrial burn',
      metabolicFocus: 'Maximum caloric expenditure, visceral fat mobilization, and VO2-max surge.',
    },
    {
      day: 'Sunday',
      dayShort: 'SUN',
      theme: 'Deep Rest, Breathwork & Mind-Body Reset',
      targetMuscles: ['Diaphragm', 'Nervous System', 'Pelvic Floor'],
      intensity: 'Rest',
      sampleExercises: ['Anulom Vilom', 'Box Breathing', 'Body Scan', 'Legs-Up-The-Wall'],
      dietaryStrategy: 'Digestive Reset: Probiotic Curd, High Fiber, Light Khichdi & Herbal Teas',
      metabolicFocus: 'Systemic detoxification, neuromuscular consolidation, and full energy store refill.',
    },
  ];
}

// -----------------------------------------------------------------------------
// 4. NEUROSYNC™ SMART EXERCISE POOL RANKER
// -----------------------------------------------------------------------------

export function synthesizeNeuroSyncPool(
  user: StoredUser,
  modality: TrainingModality,
  metabolic: { archetype: MetabolicArchetype; metrics: BmrTdeeMetrics },
  recovery: MuscleRecoveryStatus,
  date: string,
): { pool: PlaceableExercise[]; reasoning: string } {
  const isAdaptive = Boolean(
    user.accessibilityMode ||
    user.disabilityFlag ||
    (user.disabilityType && user.disabilityType.toLowerCase() !== 'none'),
  );

  let pool = isAdaptive
    ? EXERCISES.filter((e) => e.isSeatedFriendly)
    : [...EXERCISES];

  // 1. Modality Filter
  if (modality === 'gym') {
    // Boost gym barbell, dumbbell, cable equipment
    pool = pool.filter((e) => !e.isSeatedFriendly || e.equipment.some((eq) => ['barbell', 'dumbbells', 'cable_machine', 'bench', 'dip_bars', 'pull_up_bar'].includes(eq)));
    if (pool.length < 10) pool = [...EXERCISES];
  } else if (modality === 'light') {
    pool = pool.filter((e) => e.isLowImpact || e.intensity <= 2 || e.subcategory === 'mobility' || e.subcategory === 'yoga');
  } else if (modality === 'shred') {
    pool = pool.filter((e) => e.metValue >= 5.0 || e.subcategory === 'cardio' || e.subcategory === 'core');
  }

  // 2. Physical considerations & Injury screening
  const injuryText = [
    user.disabilityType ?? '',
    user.physicalConsiderationDetails ?? '',
    ...(user.medicalConditions ?? []),
  ].join(' ').toLowerCase();

  if (injuryText.trim().length > 0) {
    const hasKneeInjury = injuryText.includes('knee') || injuryText.includes('acl') || injuryText.includes('meniscus');
    const hasBackInjury = injuryText.includes('back') || injuryText.includes('spine') || injuryText.includes('lumbar') || injuryText.includes('disc');
    const hasShoulderInjury = injuryText.includes('shoulder') || injuryText.includes('rotator') || injuryText.includes('impingement');
    const hasWristInjury = injuryText.includes('wrist') || injuryText.includes('carpal');

    pool = pool.filter((e) => {
      const contra = e.contraindications.join(' ').toLowerCase();
      const name = e.name.toLowerCase();
      if (hasKneeInjury && (contra.includes('knee') || name.includes('squat') || name.includes('lunge') || name.includes('jump'))) return false;
      if (hasBackInjury && (contra.includes('back') || name.includes('deadlift') || name.includes('sit-up'))) return false;
      if (hasShoulderInjury && (contra.includes('shoulder') || name.includes('overhead') || name.includes('bench press'))) return false;
      if (hasWristInjury && name.includes('push-up') && !name.includes('forearm')) return false;
      return true;
    });
  }

  // 3. Dynamic Multi-Signal Scoring Engine
  const dateHash = Math.abs(
    (date + user.id + modality).split('').reduce((acc, c) => ((acc << 5) - acc) + c.charCodeAt(0), 0)
  );

  const scored = pool.map((e) => {
    let score = 50;
    const body = e.bodyParts.join(' ').toLowerCase();
    const muscles = e.muscles.join(' ').toLowerCase();
    const sub = e.subcategory.toLowerCase();

    // Modality alignment
    if (modality === 'gym') {
      const isIron = e.equipment.some((eq) => ['barbell', 'dumbbells', 'cable_machine', 'bench', 'squat_rack', 'leg_press_machine'].includes(eq));
      if (isIron) score += 60;
      if (e.intensity === 3) score += 25;
    } else if (modality === 'light') {
      if (e.isLowImpact) score += 40;
      if (e.intensity === 1) score += 30;
      if (e.intensity === 3) score -= 50;
    } else if (modality === 'shred') {
      if (sub === 'cardio' || sub === 'core') score += 45;
      score += Math.round(e.metValue * 6);
    }

    // Caloric Delta Integration
    if (metabolic.metrics.caloricState === 'surplus') {
      // Direct surplus into muscle protein synthesis & metabolic burn
      if (sub === 'chest' || sub === 'back' || sub === 'legs' || sub === 'arms') score += 35;
      if (e.intensity >= 2) score += 20;
    } else if (metabolic.metrics.caloricState === 'deficit') {
      // Preserve lean muscle while avoiding exhaustion
      if (e.isLowImpact || e.intensity === 2) score += 25;
      if (e.intensity === 3 && e.metValue > 8.0) score -= 30; // Avoid catabolic burnout
    }

    // Missed Muscle Catch-Up (+50 bonus)
    for (const missed of recovery.priorityFocusMuscles) {
      if (body.includes(missed) || muscles.includes(missed)) {
        score += 55;
        break;
      }
    }

    // Active 48h Muscle Recovery (-60 penalty so muscles rest!)
    for (const recent of recovery.recentMusclesTrained) {
      if (body.includes(recent) || muscles.includes(recent)) {
        score -= 60;
        break;
      }
    }

    // Metabolic Archetype adjustments
    if (metabolic.archetype === 'glycemic_insulin_resistant') {
      if (body.includes('legs') || body.includes('glutes') || body.includes('back')) score += 30; // Largest glycogen sinks
    } else if (metabolic.archetype === 'sluggish_hypothyroid') {
      if (e.intensity === 2 || (e.intensity === 3 && !sub.includes('cardio'))) score += 30; // Resistance uplifts thyroid
    } else if (metabolic.archetype === 'hypoxic_anemic') {
      if (e.intensity === 3) score -= 45; // Safety clamp
      if (e.isLowImpact) score += 25;
    }

    // Daily Jitter to guarantee variety
    const jitter = (dateHash ^ e.slug.length) % 17;
    return { exercise: e, finalScore: score + jitter };
  });

  scored.sort((a, b) => b.finalScore - a.finalScore);

  const placeable: PlaceableExercise[] = scored.map((s) => ({
    id: s.exercise.slug,
    name: s.exercise.name,
    durationSec: s.exercise.defaultDurationSec,
    intensity: s.exercise.intensity,
    isLowImpact: s.exercise.isLowImpact,
  }));

  // Build transparent Explainable AI reasoning
  const topNames = placeable.slice(0, 3).map((p) => p.name).join(', ');
  const missedNotice = recovery.priorityFocusMuscles.length > 0
    ? `Prioritized ${recovery.priorityFocusMuscles.slice(0, 2).join(' & ').toUpperCase()} (detected missed volume in previous days). `
    : '';
  const caloricNotice = metabolic.metrics.caloricState === 'surplus'
    ? `Caloric surplus of +${metabolic.metrics.caloricDeltaKcal} kcal detected: channeling nutrition into hypertrophy and metabolic core volume. `
    : metabolic.metrics.caloricState === 'deficit'
    ? `Caloric deficit of ${metabolic.metrics.caloricDeltaKcal} kcal detected: pacing volume to preserve lean mass without fatigue. `
    : '';

  const reasoning = `🧠 VYRA NeuroSync™ Decision: Generated ${modality.toUpperCase()} workout centered on ${topNames}. ${missedNotice}${caloricNotice}Grounded for BMI ${metabolic.metrics.bmi.toFixed(1)} (${metabolic.metrics.bmiCategory}) and ${metabolic.archetype.replace(/_/g, ' ')} profile.`;

  return {
    pool: placeable,
    reasoning,
  };
}
