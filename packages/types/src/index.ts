/**
 * @vyra/types
 * Shared constants, types and domain rules used by the API server.
 * Zero runtime dependencies — only TypeScript itself.
 */

// ─── Primitive branded aliases ────────────────────────────────────────────────
export type ISODate = string; // "YYYY-MM-DD"

// ─── Enumerated user-profile values ──────────────────────────────────────────
export const GENDERS = ['male', 'female', 'non-binary', 'prefer-not-to-say'] as const;
export type Gender = typeof GENDERS[number];

export const FITNESS_GOALS = [
  'lose_weight', 'gain_weight', 'build_muscle', 'improve_endurance',
  'stay_active', 'manage_stress', 'flexibility', 'maintain', 'general_wellness',
] as const;
export type FitnessGoal = typeof FITNESS_GOALS[number];

export const DIET_PREFERENCES = [
  'none', 'vegetarian', 'vegan', 'keto', 'paleo', 'gluten_free',
  'dairy_free', 'low_carb', 'intermittent_fasting',
  'veg_no_egg', 'veg_with_egg', 'non_veg',
] as const;
export type DietPreference = typeof DIET_PREFERENCES[number];

// ─── Schedule block types ─────────────────────────────────────────────────────
export const BLOCK_TYPES = [
  'sleep', 'class', 'work', 'commute', 'meal', 'prayer', 'custom', 'free',
] as const;
export type BlockType = typeof BLOCK_TYPES[number];

/** A free time window detected by the Chrono Engine. */
export interface FreeWindow {
  weekday:     number;  // 0=Mon … 6=Sun
  start:       string;  // "HH:mm"
  end:         string;  // "HH:mm"
  startMin:    number;  // minutes since midnight
  endMin:      number;
  durationMin: number;
  suitability: number;  // 0.0–1.0 score
}

// ─── Exercise library types ───────────────────────────────────────────────────
export type Difficulty = 'beginner' | 'intermediate' | 'advanced';
export type ExerciseCategory =
  | 'cardio' | 'strength' | 'flexibility' | 'balance'
  | 'yoga' | 'breathing' | 'meditation' | 'recovery'
  | 'hiit' | 'functional' | 'seated' | 'exercise' | 'special';
export type RecoveryArea =
  | 'lower_back' | 'shoulders' | 'shoulder' | 'hips'
  | 'knees' | 'knee' | 'neck' | 'hamstrings' | 'calves'
  | 'wrists' | 'wrist' | 'ankle' | 'general';

// ─── Recipe types ─────────────────────────────────────────────────────────────
export interface RecipeIngredient {
  name: string;
  quantity: string;
}

export interface Recipe {
  id?:           string;
  title:         string;
  ingredients:   RecipeIngredient[];
  steps:         string[];
  cookTimeMin:   number;
  dietPreference: DietPreference;
  containsEgg:   boolean;
  containsMeat:  boolean;
  isAiGenerated: boolean;
  regionTag?:    string;
  nutrition?: {
    calories?: number; proteinG?: number; carbsG?: number;
    fatG?: number;     fiberG?: number;   sugarG?: number;
  };
}

// ─── API error codes ──────────────────────────────────────────────────────────
// Uppercase codes as used by router.ts and server.ts
export type ApiErrorCode =
  | 'VALIDATION_FAILED' | 'UNAUTHENTICATED' | 'FORBIDDEN' | 'NOT_FOUND'
  | 'CONFLICT' | 'CONSENT_REQUIRED' | 'RATE_LIMITED' | 'UPSTREAM_UNAVAILABLE'
  | 'bad_request' | 'unauthorized' | 'server_error' | 'ai_unavailable'
  | 'diet_unsatisfiable' | 'invalid_input';

// ─── Gamification: Coins ──────────────────────────────────────────────────────
export interface CoinRules {
  workoutCompleted:  number;
  workoutPartial:    number;
  allMetricsLogged:  number;
  zeroSugarDay:      number;
  dietDayOnTarget:   number;
  dailyEarnCap:      number;
  streakMilestones:  Record<number, number>;
}

export const COIN_RULES: CoinRules = {
  workoutCompleted: 20, workoutPartial: 10, allMetricsLogged: 10,
  zeroSugarDay: 15,     dietDayOnTarget: 10, dailyEarnCap: 100,
  streakMilestones: { 7: 50, 14: 100, 21: 200, 30: 350, 60: 500, 90: 750 },
};

// ─── Gamification: Levels ────────────────────────────────────────────────────
export const LEVEL_THRESHOLDS: readonly number[] = [0, 100, 250, 500, 1000, 2000, 5000, 10000];

export function levelFromXp(xp: number): number {
  for (let i = LEVEL_THRESHOLDS.length - 1; i >= 0; i--) {
    if (xp >= LEVEL_THRESHOLDS[i]!) return i + 1;
  }
  return 1;
}

// ─── Gamification: Tiers ─────────────────────────────────────────────────────
export interface TierDef {
  tier:       string;  // used as tier.tier in server.ts
  name:       string;
  minPoints:  number;
  icon:       string;
}

export const TIER_THRESHOLDS: readonly TierDef[] = [
  { tier: 'bronze',   name: 'Bronze',   minPoints: 0,     icon: '🥉' },
  { tier: 'silver',   name: 'Silver',   minPoints: 500,   icon: '🥈' },
  { tier: 'gold',     name: 'Gold',     minPoints: 1500,  icon: '🥇' },
  { tier: 'platinum', name: 'Platinum', minPoints: 4000,  icon: '💎' },
  { tier: 'diamond',  name: 'Diamond',  minPoints: 10000, icon: '👑' },
];

// ─── Health metric ranges ─────────────────────────────────────────────────────
export interface MetricRange {
  min:        number;
  max:        number;
  normalLow:  number;
  normalHigh: number;
  unit:       string;
  label:      string;
}

export const METRIC_RANGE_BY_KEY: Record<string, MetricRange> = {
  waterMl:        { min: 0,  max: 6000,  normalLow: 1500, normalHigh: 4000, unit: 'ml',    label: 'Water intake' },
  steps:          { min: 0,  max: 80000, normalLow: 3000, normalHigh: 15000,unit: 'steps', label: 'Steps' },
  caloriesBurned: { min: 0,  max: 6000,  normalLow: 200,  normalHigh: 3500, unit: 'kcal',  label: 'Calories burned' },
  heartRateBpm:   { min: 30, max: 250,   normalLow: 60,   normalHigh: 100,  unit: 'bpm',   label: 'Heart rate' },
  bpSystolic:     { min: 60, max: 240,   normalLow: 90,   normalHigh: 130,  unit: 'mmHg',  label: 'Systolic BP' },
  bpDiastolic:    { min: 40, max: 160,   normalLow: 60,   normalHigh: 85,   unit: 'mmHg',  label: 'Diastolic BP' },
  spo2:           { min: 70, max: 100,   normalLow: 95,   normalHigh: 100,  unit: '%',     label: 'SpO₂' },
  glucoseMgDl:    { min: 30, max: 700,   normalLow: 70,   normalHigh: 140,  unit: 'mg/dL', label: 'Blood glucose' },
  weightKg:       { min: 20, max: 300,   normalLow: 40,   normalHigh: 120,  unit: 'kg',    label: 'Body weight' },
};

// ─── Sugar / diet rules ───────────────────────────────────────────────────────
export const SUGAR_GUIDELINE = {
  default_g:           25,
  male_g:              36,
  female_g:            25,
  zeroSugarThresholdG: 2,   // ≤2g is "zero sugar" for awarding coin
  idealLimitG:         25,
  upperLimitG:         50,
} as const;

export const SUGAR_NEUTRALIZER_SUGGESTIONS: readonly string[] = [
  'Drink a large glass of water immediately after',
  'Add 10 minutes of brisk walking to your plan',
  'Eat a handful of nuts or legumes with your next meal to blunt the glucose spike',
  'Wait 20 minutes before eating anything else',
  'Do 5 minutes of light stretching to activate muscles and improve uptake',
];

// ─── Disclaimers ─────────────────────────────────────────────────────────────
export const DISCLAIMERS = {
  labReport:
    'This analysis is for informational purposes only and does not constitute medical advice. ' +
    'Please consult a qualified healthcare professional before making any changes to diet, ' +
    'supplementation or lifestyle based on these results.',
  recipe:
    'This recipe suggestion is generated by AI and is for informational purposes only. ' +
    'Always consult a registered dietitian for personalised nutrition advice.',
  healthReport:
    'This health insight is for informational purposes only. ' +
    'VYRA does not diagnose, treat or prescribe. Consult your doctor before changing your diet or supplements.',
  aiChat:
    'VYRA AI is not a medical professional. For health concerns, please consult a qualified doctor.',
  aiNutrition:
    'Nutritional analysis is AI-generated and an approximate estimate. Actual values vary by preparation and portion. ' +
    'Always verify with a registered dietitian before making dietary changes.',
  general:
    'Information provided by VYRA is for general wellness purposes only and does not constitute medical advice. ' +
    'Consult a qualified healthcare professional for personal health decisions.',
  biometric:
    'Biometric readings shown here are for personal tracking only. ' +
    'VYRA is not a medical device. Consult your doctor about any readings that concern you.',
  sugar:
    'Sugar tracking is based on your logged intake. Values are estimates. ' +
    'Consult a registered dietitian for personalised dietary advice.',
} as const;
