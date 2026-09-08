/**
 * =============================================================================
 * LAB REPORT ANALYSIS  ->  NUTRITION RESPONSE
 * =============================================================================
 * From the founder's handwritten notes:
 *   "also of reports — analyse cause any deficiency, then make accordingly diet"
 *
 * A user uploads a routine blood report. VYRA reads the markers, spots likely
 * nutritional gaps, and adjusts their diet plan toward foods that address them.
 *
 * -----------------------------------------------------------------------------
 * THIS IS THE MOST DANGEROUS FEATURE IN THE APP. Design accordingly.
 * -----------------------------------------------------------------------------
 * A wellness app that reads medical data can cause real harm in three ways, and
 * every rule below exists to close one of them:
 *
 *   1. MISSING SOMETHING SERIOUS. A report can contain a red flag that needs a
 *      doctor today, not a spinach recommendation. So any value in a critical
 *      band SUPPRESSES all dietary output and escalates. We would rather give a
 *      user nothing than give them a smoothie recipe instead of a referral.
 *
 *   2. GIVING ADVICE THAT IS HARMFUL FOR *THIS* USER. The clearest example:
 *      "eat more protein" is standard fitness advice and is genuinely dangerous
 *      for someone with impaired kidney function. So abnormal renal markers
 *      block protein-increasing advice outright (see CONTRAINDICATIONS).
 *
 *   3. IMPLYING DIAGNOSIS OR TREATMENT. We never name a disease, never suggest a
 *      supplement or a dose, and never imply food replaces medication. We say
 *      "these values are outside the usual range — here are foods rich in the
 *      relevant nutrient, and please discuss this with a doctor."
 *
 * Reference ranges vary by lab, age, sex, and population. They are guidance for
 * conversation, never a diagnosis. Every output carries that statement.
 *
 * Deterministic on purpose: extraction from an image may use a vision model, but
 * the interpretation is rule-based, auditable, and identical every time. Nobody
 * should receive health guidance from a black box that cannot be reviewed.
 * =============================================================================
 */

import type { DietPreference, Gender } from '@vyra/types';

// -----------------------------------------------------------------------------
// Markers
// -----------------------------------------------------------------------------

export type MarkerKey =
  | 'hemoglobin' | 'ferritin' | 'vitamin_d' | 'vitamin_b12' | 'calcium'
  | 'tsh' | 'hba1c' | 'fasting_glucose'
  | 'total_cholesterol' | 'ldl' | 'hdl' | 'triglycerides'
  | 'creatinine' | 'egfr' | 'alt' | 'uric_acid';

export type Band = 'critical_low' | 'low' | 'borderline_low' | 'normal' | 'borderline_high' | 'high' | 'critical_high';

export interface MarkerReading {
  key: MarkerKey;
  value: number;
  unit: string;
}

interface RangeSpec {
  key: MarkerKey;
  label: string;
  unit: string;
  /** Sex-specific normal band where it matters clinically. */
  normal: { low: number; high: number } | Record<'male' | 'female' | 'other', { low: number; high: number }>;
  /** Outside this, we stop advising and escalate. */
  critical?: { belowLow?: number; aboveHigh?: number };
  /** Plausibility bounds — outside this the reading is a parse error, not a result. */
  plausible: { min: number; max: number };
  /** Nutrient this marker points at, when it points at one at all. */
  nutrient?: NutrientKey;
  /** Some markers never generate diet advice — only a referral. */
  referralOnly?: boolean;
}

export type NutrientKey = 'iron' | 'vitamin_d' | 'vitamin_b12' | 'calcium' | 'fiber' | 'omega3' | 'protein';

// -----------------------------------------------------------------------------
// Reference ranges
// Adult ranges in common Indian lab units. Sources are conventional clinical
// reference intervals; individual labs differ, which is why the output always
// says "compare with the range printed on your own report".
// -----------------------------------------------------------------------------

export const MARKER_RANGES: Record<MarkerKey, RangeSpec> = {
  hemoglobin: {
    key: 'hemoglobin', label: 'Haemoglobin', unit: 'g/dL',
    normal: { male: { low: 13, high: 17 }, female: { low: 12, high: 15 }, other: { low: 12, high: 17 } },
    critical: { belowLow: 8 },
    plausible: { min: 2, max: 25 },
    nutrient: 'iron',
  },
  ferritin: {
    key: 'ferritin', label: 'Ferritin (iron stores)', unit: 'ng/mL',
    normal: { male: { low: 30, high: 300 }, female: { low: 15, high: 200 }, other: { low: 15, high: 300 } },
    plausible: { min: 0, max: 3000 },
    nutrient: 'iron',
  },
  vitamin_d: {
    key: 'vitamin_d', label: 'Vitamin D (25-OH)', unit: 'ng/mL',
    normal: { low: 30, high: 100 },
    critical: { belowLow: 10 },
    plausible: { min: 0, max: 200 },
    nutrient: 'vitamin_d',
  },
  vitamin_b12: {
    key: 'vitamin_b12', label: 'Vitamin B12', unit: 'pg/mL',
    normal: { low: 300, high: 900 },
    critical: { belowLow: 150 },
    plausible: { min: 0, max: 5000 },
    nutrient: 'vitamin_b12',
  },
  calcium: {
    key: 'calcium', label: 'Calcium', unit: 'mg/dL',
    normal: { low: 8.5, high: 10.5 },
    critical: { belowLow: 7, aboveHigh: 12 },
    plausible: { min: 3, max: 20 },
    nutrient: 'calcium',
  },
  tsh: {
    key: 'tsh', label: 'TSH (thyroid)', unit: 'mIU/L',
    normal: { low: 0.4, high: 4.0 },
    critical: { aboveHigh: 10 },
    plausible: { min: 0, max: 150 },
    referralOnly: true,
  },
  hba1c: {
    key: 'hba1c', label: 'HbA1c (3-month sugar average)', unit: '%',
    normal: { low: 4.0, high: 5.6 },
    critical: { aboveHigh: 9 },
    plausible: { min: 2, max: 20 },
    nutrient: 'fiber',
  },
  fasting_glucose: {
    key: 'fasting_glucose', label: 'Fasting Glucose', unit: 'mg/dL',
    normal: { low: 70, high: 99 },
    critical: { belowLow: 54, aboveHigh: 200 },
    plausible: { min: 20, max: 800 },
    nutrient: 'fiber',
  },
  total_cholesterol: {
    key: 'total_cholesterol', label: 'Total Cholesterol', unit: 'mg/dL',
    normal: { low: 0, high: 199 },
    plausible: { min: 50, max: 600 },
    nutrient: 'fiber',
  },
  ldl: {
    key: 'ldl', label: 'LDL Cholesterol', unit: 'mg/dL',
    normal: { low: 0, high: 99 },
    critical: { aboveHigh: 190 },
    plausible: { min: 10, max: 500 },
    nutrient: 'fiber',
  },
  hdl: {
    key: 'hdl', label: 'HDL Cholesterol', unit: 'mg/dL',
    normal: { male: { low: 40, high: 100 }, female: { low: 50, high: 100 }, other: { low: 40, high: 100 } },
    plausible: { min: 5, max: 150 },
    nutrient: 'omega3',
  },
  triglycerides: {
    key: 'triglycerides', label: 'Triglycerides', unit: 'mg/dL',
    normal: { low: 0, high: 149 },
    critical: { aboveHigh: 500 },
    plausible: { min: 10, max: 2000 },
    nutrient: 'omega3',
  },
  // ---- Renal & hepatic: referral only. These never produce diet advice. ----
  creatinine: {
    key: 'creatinine', label: 'Serum Creatinine', unit: 'mg/dL',
    normal: { male: { low: 0.7, high: 1.3 }, female: { low: 0.6, high: 1.1 }, other: { low: 0.6, high: 1.3 } },
    critical: { aboveHigh: 2 },
    plausible: { min: 0.1, max: 20 },
    referralOnly: true,
  },
  egfr: {
    key: 'egfr', label: 'eGFR (kidney function)', unit: 'mL/min/1.73m²',
    normal: { low: 90, high: 200 },
    critical: { belowLow: 45 },
    plausible: { min: 1, max: 200 },
    referralOnly: true,
  },
  alt: {
    key: 'alt', label: 'ALT (liver)', unit: 'U/L',
    normal: { low: 7, high: 55 },
    critical: { aboveHigh: 200 },
    plausible: { min: 1, max: 3000 },
    referralOnly: true,
  },
  uric_acid: {
    key: 'uric_acid', label: 'Uric Acid', unit: 'mg/dL',
    normal: { male: { low: 3.4, high: 7.0 }, female: { low: 2.4, high: 6.0 }, other: { low: 2.4, high: 7.0 } },
    plausible: { min: 0.5, max: 25 },
    referralOnly: true,
  },
};

// -----------------------------------------------------------------------------
// Nutrient -> Indian food sources
// Deliberately everyday, affordable, regionally familiar foods. Telling an Indian
// student to eat salmon and kale is useless advice, however nutritionally correct.
// -----------------------------------------------------------------------------

interface NutrientGuidance {
  nutrient: NutrientKey;
  label: string;
  /** Food suggestions per dietary preference. Never suggest off-diet foods. */
  foods: Partial<Record<DietPreference, string[]>>;
  /** A practical tip that improves absorption or effect. */
  tip: string;
  /** Set when food alone is usually not enough — pushes toward a doctor. */
  foodAloneOftenInsufficient?: boolean;
}

export const NUTRIENT_GUIDANCE: Record<NutrientKey, NutrientGuidance> = {
  iron: {
    nutrient: 'iron', label: 'Iron',
    foods: {
      veg_no_egg: ['Ragi (finger millet)', 'Palak and other dark greens', 'Rajma', 'Chana', 'Bajra', 'Sesame (til)', 'Dates', 'Jaggery (small amounts)'],
      veg_with_egg: ['Ragi', 'Palak', 'Rajma', 'Chana', 'Egg yolk', 'Bajra', 'Sesame (til)', 'Dates'],
      non_veg: ['Chicken liver', 'Red meat', 'Fish', 'Egg yolk', 'Ragi', 'Palak', 'Rajma', 'Chana'],
    },
    tip: 'Pair iron-rich food with vitamin C (lemon, amla, guava, tomato) — it can substantially improve absorption. Avoid tea or coffee within an hour of the meal, as tannins reduce it.',
  },
  vitamin_d: {
    nutrient: 'vitamin_d', label: 'Vitamin D',
    foods: {
      veg_no_egg: ['Fortified milk', 'Mushrooms (sun-exposed)', 'Fortified cereals'],
      veg_with_egg: ['Egg yolk', 'Fortified milk', 'Mushrooms', 'Fortified cereals'],
      non_veg: ['Fatty fish (rohu, sardine, mackerel)', 'Egg yolk', 'Fortified milk'],
    },
    tip: '15-20 minutes of morning sunlight on your arms and face is the most effective source. Food alone rarely corrects a real deficiency.',
    foodAloneOftenInsufficient: true,
  },
  vitamin_b12: {
    nutrient: 'vitamin_b12', label: 'Vitamin B12',
    foods: {
      veg_no_egg: ['Milk', 'Curd', 'Paneer', 'Fortified cereals', 'Nutritional yeast'],
      veg_with_egg: ['Eggs', 'Milk', 'Curd', 'Paneer', 'Fortified cereals'],
      non_veg: ['Fish', 'Chicken', 'Eggs', 'Milk', 'Curd', 'Liver'],
    },
    tip: 'B12 occurs almost entirely in animal foods, so a purely plant-based diet needs fortified foods. A deficiency usually needs medical treatment, not just diet.',
    foodAloneOftenInsufficient: true,
  },
  calcium: {
    nutrient: 'calcium', label: 'Calcium',
    foods: {
      veg_no_egg: ['Milk', 'Curd', 'Paneer', 'Ragi', 'Sesame (til)', 'Amaranth (rajgira)', 'Almonds'],
      veg_with_egg: ['Milk', 'Curd', 'Paneer', 'Ragi', 'Sesame (til)', 'Almonds'],
      non_veg: ['Milk', 'Curd', 'Paneer', 'Small fish with bones', 'Ragi', 'Sesame (til)'],
    },
    tip: 'Calcium needs vitamin D to be absorbed properly — the two are usually looked at together.',
  },
  fiber: {
    nutrient: 'fiber', label: 'Fibre & slow carbohydrates',
    foods: {
      veg_no_egg: ['Whole dals with skin', 'Oats', 'Bajra and jowar rotis', 'Vegetables at every meal', 'Whole fruit instead of juice', 'Chia and flax seeds'],
      veg_with_egg: ['Whole dals', 'Oats', 'Bajra and jowar rotis', 'Vegetables', 'Whole fruit', 'Chia and flax seeds'],
      non_veg: ['Whole dals', 'Oats', 'Millet rotis', 'Vegetables', 'Whole fruit', 'Chia and flax seeds'],
    },
    tip: 'Swapping refined grains (maida, white rice) for whole grains and adding vegetables slows sugar absorption. Increase fibre gradually and drink more water.',
  },
  omega3: {
    nutrient: 'omega3', label: 'Healthy fats (omega-3)',
    foods: {
      veg_no_egg: ['Flaxseed (alsi)', 'Chia seeds', 'Walnuts', 'Mustard oil', 'Soybean'],
      veg_with_egg: ['Flaxseed', 'Chia seeds', 'Walnuts', 'Omega-3 enriched eggs'],
      non_veg: ['Fatty fish (rohu, hilsa, mackerel, sardine)', 'Flaxseed', 'Walnuts'],
    },
    tip: 'Replacing fried snacks and vanaspati with nuts, seeds and cold-pressed oils tends to matter more than adding any single food.',
  },
  protein: {
    nutrient: 'protein', label: 'Protein',
    foods: {
      veg_no_egg: ['Dals and legumes', 'Paneer', 'Curd', 'Soya chunks', 'Peanuts', 'Milk'],
      veg_with_egg: ['Eggs', 'Dals', 'Paneer', 'Curd', 'Soya chunks', 'Milk'],
      non_veg: ['Chicken', 'Fish', 'Eggs', 'Dals', 'Paneer', 'Curd'],
    },
    tip: 'Spread protein across meals rather than eating it all at dinner.',
  },
};

/**
 * Advice that becomes unsafe in the presence of certain findings.
 *
 * The kidney rule is the important one. "Eat more protein" is the single most
 * common piece of fitness advice on earth, and for someone with reduced kidney
 * function it is exactly the wrong thing to say. A fitness app that reads lab
 * values and does not encode this should not be reading lab values.
 */
const CONTRAINDICATIONS: Array<{
  when: (findings: Finding[]) => boolean;
  blockNutrients: NutrientKey[];
  reason: string;
}> = [
  {
    when: (f) => f.some((x) => (x.key === 'creatinine' && x.band !== 'normal' && x.direction === 'high')
      || (x.key === 'egfr' && x.direction === 'low')),
    blockNutrients: ['protein'],
    reason:
      'Your kidney markers are outside the usual range. Increasing protein can be harmful when kidney function is reduced, so we have not suggested it. Please discuss your protein intake with a doctor before changing it.',
  },
  {
    when: (f) => f.some((x) => x.key === 'uric_acid' && x.direction === 'high'),
    blockNutrients: ['protein'],
    reason:
      'Your uric acid is above the usual range. Some high-protein foods can worsen this, so we have not suggested increasing protein. A doctor can advise what is right for you.',
  },
  {
    when: (f) => f.some((x) => x.key === 'calcium' && x.direction === 'high'),
    blockNutrients: ['calcium'],
    reason:
      'Your calcium is already above the usual range, so we have not suggested calcium-rich foods. Please have this checked.',
  },
];

// -----------------------------------------------------------------------------
// Analysis
// -----------------------------------------------------------------------------

export interface Finding {
  key: MarkerKey;
  label: string;
  value: number;
  unit: string;
  band: Band;
  direction: 'low' | 'high' | 'normal';
  normalRange: { low: number; high: number };
  isCritical: boolean;
  referralOnly: boolean;
  /** Neutral description. Never names a disease. */
  summary: string;
}

export interface DietAdjustment {
  nutrient: NutrientKey;
  label: string;
  becauseOf: string[];
  foods: string[] | undefined;
  tip: string;
  seeADoctor: boolean;
}

export interface LabAnalysisResult {
  /** True when nothing usable was extracted — we say so rather than inventing. */
  noReadableMarkers: boolean;
  findings: Finding[];
  /** Values outside plausible bounds — almost always an OCR error, never shown as a result. */
  rejectedReadings: Array<{ key: MarkerKey; value: number; reason: string }>;
  /**
   * When true, ALL dietary output is suppressed and the app shows a referral only.
   */
  urgentReferral: boolean;
  urgentReasons: string[];
  adjustments: DietAdjustment[];
  suppressedAdvice: string[];
  disclaimer: string;
  nextStep: string;
}

export const LAB_DISCLAIMER =
  'This is a general wellness reading of your report, not a medical diagnosis. Reference ranges differ between laboratories — always compare against the range printed on your own report, and discuss any result outside it with a qualified doctor. VYRA does not diagnose conditions, prescribe supplements, or replace medical treatment.';

function normalFor(spec: RangeSpec, gender: Gender): { low: number; high: number } {
  if ('low' in spec.normal) return spec.normal;
  const key = gender === 'male' ? 'male' : gender === 'female' ? 'female' : 'other';
  return spec.normal[key];
}

function classify(spec: RangeSpec, value: number, gender: Gender): { band: Band; direction: Finding['direction']; isCritical: boolean } {
  const range = normalFor(spec, gender);

  if (spec.critical?.belowLow !== undefined && value < spec.critical.belowLow) {
    return { band: 'critical_low', direction: 'low', isCritical: true };
  }
  if (spec.critical?.aboveHigh !== undefined && value > spec.critical.aboveHigh) {
    return { band: 'critical_high', direction: 'high', isCritical: true };
  }
  if (value < range.low) {
    // Within 10% of the boundary reads as borderline rather than a deficiency.
    const band: Band = value >= range.low * 0.9 ? 'borderline_low' : 'low';
    return { band, direction: 'low', isCritical: false };
  }
  if (value > range.high) {
    const band: Band = value <= range.high * 1.1 ? 'borderline_high' : 'high';
    return { band, direction: 'high', isCritical: false };
  }
  return { band: 'normal', direction: 'normal', isCritical: false };
}

function describe(spec: RangeSpec, value: number, band: Band, range: { low: number; high: number }): string {
  const r = `usual range ${range.low}-${range.high} ${spec.unit}`;
  switch (band) {
    case 'critical_low':
      return `${spec.label} is ${value} ${spec.unit}, well below the ${r}. This needs medical attention.`;
    case 'critical_high':
      return `${spec.label} is ${value} ${spec.unit}, well above the ${r}. This needs medical attention.`;
    case 'low':
      return `${spec.label} is ${value} ${spec.unit}, below the ${r}.`;
    case 'high':
      return `${spec.label} is ${value} ${spec.unit}, above the ${r}.`;
    case 'borderline_low':
      return `${spec.label} is ${value} ${spec.unit}, just below the ${r}.`;
    case 'borderline_high':
      return `${spec.label} is ${value} ${spec.unit}, just above the ${r}.`;
    default:
      return `${spec.label} is ${value} ${spec.unit}, within the ${r}.`;
  }
}

/**
 * The main entry point.
 *
 * Order of operations is deliberate:
 *   reject implausible -> classify -> check for critical -> (stop, or) build diet
 *
 * Critical findings short-circuit everything. A user whose haemoglobin is 6 must
 * see "please see a doctor", not a list of iron-rich foods with a doctor's note
 * appended somewhere below the fold.
 */
export function analyseLabReport(
  readings: MarkerReading[],
  user: { gender: Gender; dietPreference: DietPreference },
): LabAnalysisResult {
  const findings: Finding[] = [];
  const rejectedReadings: LabAnalysisResult['rejectedReadings'] = [];

  for (const reading of readings) {
    const spec = MARKER_RANGES[reading.key];
    if (!spec) continue;

    // An OCR misread ("13" scanned as "130") must never become a health finding.
    if (
      !Number.isFinite(reading.value) ||
      reading.value < spec.plausible.min ||
      reading.value > spec.plausible.max
    ) {
      rejectedReadings.push({
        key: reading.key,
        value: reading.value,
        reason: `Outside the plausible range for ${spec.label} — likely a scanning error. Please enter it manually.`,
      });
      continue;
    }

    const range = normalFor(spec, user.gender);
    const { band, direction, isCritical } = classify(spec, reading.value, user.gender);

    findings.push({
      key: reading.key,
      label: spec.label,
      value: reading.value,
      unit: spec.unit,
      band,
      direction,
      normalRange: range,
      isCritical,
      referralOnly: spec.referralOnly === true,
      summary: describe(spec, reading.value, band, range),
    });
  }

  if (findings.length === 0) {
    return {
      noReadableMarkers: true,
      findings: [],
      rejectedReadings,
      urgentReferral: false,
      urgentReasons: [],
      adjustments: [],
      suppressedAdvice: [],
      disclaimer: LAB_DISCLAIMER,
      nextStep:
        'We could not read any recognised values from this report. You can enter them manually, or try a clearer photo.',
    };
  }

  // ---- Critical short-circuit ----
  const critical = findings.filter((f) => f.isCritical);
  if (critical.length > 0) {
    return {
      noReadableMarkers: false,
      findings,
      rejectedReadings,
      urgentReferral: true,
      urgentReasons: critical.map((f) => f.summary),
      adjustments: [],          // deliberately empty
      suppressedAdvice: [
        'Dietary suggestions are not shown for results in this range. Food is not the right response to these values.',
      ],
      disclaimer: LAB_DISCLAIMER,
      nextStep:
        'Please share this report with a doctor soon. If you feel unwell — breathless, dizzy, chest pain, or very weak — seek care today.',
    };
  }

  // ---- Build dietary response ----
  const blocked = new Set<NutrientKey>();
  const suppressedAdvice: string[] = [];
  for (const rule of CONTRAINDICATIONS) {
    if (rule.when(findings)) {
      rule.blockNutrients.forEach((n) => blocked.add(n));
      suppressedAdvice.push(rule.reason);
    }
  }

  const byNutrient = new Map<NutrientKey, string[]>();
  let anyNeedsDoctor = false;

  for (const finding of findings) {
    if (finding.band === 'normal') continue;
    const spec = MARKER_RANGES[finding.key];

    if (spec.referralOnly) {
      anyNeedsDoctor = true;
      continue;   // referral markers never generate food advice
    }
    if (!spec.nutrient) continue;

    // Only a genuine shortfall triggers a nutrient push. For markers where being
    // HIGH is the problem (HbA1c, LDL, triglycerides), the fibre/omega-3 response
    // is the correct one; for haemoglobin and vitamins, it is the low side.
    const highIsTheProblem = ['hba1c', 'fasting_glucose', 'total_cholesterol', 'ldl', 'triglycerides'].includes(finding.key);
    const relevant = highIsTheProblem ? finding.direction === 'high' : finding.direction === 'low';
    if (!relevant) continue;

    if (blocked.has(spec.nutrient)) continue;

    const list = byNutrient.get(spec.nutrient) ?? [];
    list.push(finding.summary);
    byNutrient.set(spec.nutrient, list);
  }

  const adjustments: DietAdjustment[] = [...byNutrient.entries()].map(([nutrient, becauseOf]) => {
    const guidance = NUTRIENT_GUIDANCE[nutrient];
    return {
      nutrient,
      label: guidance.label,
      becauseOf,
      foods: guidance.foods[user.dietPreference],
      tip: guidance.tip,
      seeADoctor: guidance.foodAloneOftenInsufficient === true,
    };
  });

  const abnormal = findings.filter((f) => f.band !== 'normal');
  const nextStep =
    abnormal.length === 0
      ? 'Everything we could read is within the usual range. Keep going.'
      : anyNeedsDoctor || adjustments.some((a) => a.seeADoctor)
        ? 'Please show this report to a doctor. Food can support these values, but some of them usually need proper medical review.'
        : 'These foods have been woven into your meal plan. Recheck with your doctor at the interval they recommend.';

  return {
    noReadableMarkers: false,
    findings,
    rejectedReadings,
    urgentReferral: false,
    urgentReasons: [],
    adjustments,
    suppressedAdvice,
    disclaimer: LAB_DISCLAIMER,
    nextStep,
  };
}

/**
 * Converts the analysis into concrete meal-planner biases.
 *
 * Returned as preference weights rather than hard rules, so the planner still
 * balances calories and macros. A deficiency nudges the plan; it does not
 * hijack it into three meals of spinach.
 */
export function toPlannerHints(result: LabAnalysisResult): Array<{ tag: string; weight: number }> {
  if (result.urgentReferral) return [];
  return result.adjustments.map((a) => ({ tag: `nutrient:${a.nutrient}`, weight: 1.5 }));
}
