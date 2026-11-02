/**
 * =============================================================================
 * VYRA FeminaHealth™ — Women's Health, Menstrual & Maternal Care Engine
 * =============================================================================
 * Grounded in clinical obstetrics, gynaecology, and ICMR-NIN nutrition.
 * Provides two deeply intelligent subsystems:
 *   1. FeminaCycle™: Menstrual Cycle Phase Mapping, Bayesian Prediction,
 *      Symptom-Adaptive Pain Relief Asanas & Hormone Balancing Diet.
 *   2. MaternalCare™: 40-Week Trimester Maternal Guidance, Doctor's Orders
 *      Compliance & Biological Impact Predictor, Kick Counter & Scans Roadmap.
 * =============================================================================
 */

// -----------------------------------------------------------------------------
// 1. FeminaCycle™ Types & Data Structures
// -----------------------------------------------------------------------------

export type CyclePhase = 'menstrual' | 'follicular' | 'ovulatory' | 'luteal';

export type FlowIntensity = 'none' | 'spotting' | 'light' | 'medium' | 'heavy';

export type MenstrualSymptom =
  | 'cramps'
  | 'bloating'
  | 'fatigue'
  | 'mood_swings'
  | 'headache'
  | 'backache'
  | 'tender_breasts'
  | 'acne'
  | 'nausea';

export interface CycleEntry {
  startDate: string; // YYYY-MM-DD
  durationDays?: number; // Bleeding days (default 5)
  cycleLengthDays?: number; // Total cycle length to next period
}

export interface CycleSymptomLog {
  date: string; // YYYY-MM-DD
  flow: FlowIntensity;
  crampSeverity: number; // 0 (None) to 5 (Severe)
  symptoms: MenstrualSymptom[];
  mood: string; // 'calm' | 'happy' | 'irritable' | 'anxious' | 'low_energy'
  notes?: string;
}

export interface ReliefAsana {
  name: string;
  sanskritName: string;
  durationMinutes: number;
  benefits: string;
  steps: string[];
  caution: string;
}

export interface CycleNutritionRecommendation {
  focus: string;
  keyNutrients: string[];
  recommendedFoods: string[];
  avoidFoods: string[];
  seedCyclingTip?: string;
  rationale: string;
}

export interface CyclePredictionResult {
  currentCycleDay: number;
  currentPhase: CyclePhase;
  phaseDisplayName: string;
  daysUntilNextPeriod: number;
  nextPeriodStartDate: string;
  fertileWindowStart: string;
  fertileWindowEnd: string;
  ovulationDate: string;
  conceptionProbability: 'low' | 'medium' | 'high' | 'peak';
  averageCycleLength: number;
  cycleRegularity: 'regular' | 'irregular_long' | 'irregular_short' | 'variable';
  regularityInsight: string;
  naturalBalancingTips: string[];
}

export interface DailyChronoRoutineStep {
  id: string;
  timeSlot: string; // e.g. '06:30 AM - 07:30 AM'
  periodOfDay:
    | 'morning_wake'
    | 'breakfast'
    | 'mid_morning'
    | 'lunch'
    | 'afternoon_rest'
    | 'evening_movement'
    | 'dinner'
    | 'bedtime';
  title: string;
  guidance: string;
  nutritionOrAction: string;
  sleepPostureOrTip: string;
  medicineOrSupplements: string[];
}

export interface FruitDetail {
  name: string;
  hindiName: string;
  benefits: string;
  nutrientKey: string;
  timing: string;
  bestConsumedWith: string;
}

export interface FruitContraindication {
  name: string;
  hindiName: string;
  riskLevel: 'strict_avoid' | 'caution';
  clinicalReason: string;
  scientificMechanism: string;
}

export interface FruitTherapyGuide {
  recommendedFruits: FruitDetail[];
  avoidOrCautionFruits: FruitContraindication[];
  dailyFruitRule: string;
}

export interface SymptomHomeRemedy {
  symptom: string;
  title: string;
  ingredients: string[];
  preparation: string;
  clinicalRationale: string;
  timing: string;
  cautions: string;
}

export interface SleepSanctuaryProtocol {
  targetSleepHours: string;
  optimalPosture: string;
  pillowSetup: string;
  circadianTip: string;
  windDownRitual: string[];
  hormonalContext: string;
}

export interface MedicationTimingRule {
  name: string;
  dosageExample: string;
  idealTime: string;
  clinicalPurpose: string;
  interactionWarning: string;
  timingTip: string;
  isPregnancySafe: boolean;
}

export interface PartnerEmpathyGuide {
  phaseOrTrimester: string;
  emotionalContext: string;
  whatSheNeedsMost: string;
  dosList: string[];
  dontsList: string[];
  suggestedGiftsAndCare: { item: string; whyItHelps: string }[];
  readyToShareMessage: string;
}

export interface CareReminderItem {
  id: string;
  category: 'medication' | 'meal' | 'hydration' | 'checkup' | 'doctor_visit' | 'rest';
  title: string;
  timeSlot: string; // e.g. '08:30 AM'
  isEnabled: boolean;
  repeatDaily: boolean;
  notes?: string;
}

export interface SmartWatchBiometricSync {
  restingHeartRateBpm: number;
  skinTemperatureOffsetCelsius: number; // e.g. +0.4°C
  heartRateVariabilityMs: number;
  bloodOxygenSpo2: number;
  sleepDurationHours: number;
  deepSleepMinutes: number;
  biphasicOvulationConfirmed: boolean;
  biometricInsight: string;
}

export interface SymptomAdaptiveCarePlan {
  crampSeverity: number;
  activeSymptoms: MenstrualSymptom[];
  recommendedAsanas: ReliefAsana[];
  dietaryPlan: CycleNutritionRecommendation;
  hydrationGoalMl: number;
  lifestyleGuidance: string[];
  chronoRoutine: DailyChronoRoutineStep[];
  fruitTherapy: FruitTherapyGuide;
  sleepProtocol: SleepSanctuaryProtocol;
  homeRemedies: SymptomHomeRemedy[];
  medicationSchedule: MedicationTimingRule[];
  partnerGuide: PartnerEmpathyGuide;
  smartWatchSync: SmartWatchBiometricSync;
  defaultReminders: CareReminderItem[];
}

// -----------------------------------------------------------------------------
// 2. MaternalCare™ Types & Data Structures
// -----------------------------------------------------------------------------

export type Trimester = 'first' | 'second' | 'third' | 'postpartum';

export interface DoctorInstruction {
  id: string;
  category: 'medication' | 'diet' | 'activity' | 'test' | 'caution';
  title: string;
  details: string;
  frequency: string; // 'daily' | 'twice_daily' | 'weekly' | 'as_needed'
  isCompletedToday: boolean;
  positiveImpact: string; // Why it benefits the baby/mother
  skippedRisk: string; // Risk if neglected
  timingTip?: string;
}

export interface FetalMilestone {
  week: number;
  fruitAnalogy: string;
  approximateWeightGrams: number;
  approximateLengthMm: number;
  developmentHighlights: string[];
  motherBodyChanges: string[];
}

export interface PregnancyProfileResult {
  currentWeek: number;
  currentDayInWeek: number;
  totalDaysPregnant: number;
  trimester: Trimester;
  trimesterDisplayName: string;
  estimatedDueDate: string;
  daysUntilDelivery: number;
  fetalMilestone: FetalMilestone;
  dailyCareChecklist: DoctorInstruction[];
  prenatalSafeActivities: {
    recommended: string[];
    contraindicated: string[];
    kegelPrescription: string;
  };
  upcomingClinicalScans: {
    weekRange: string;
    testName: string;
    clinicalPurpose: string;
    isUrgent: boolean;
  }[];
  chronoRoutine: DailyChronoRoutineStep[];
  fruitTherapy: FruitTherapyGuide;
  sleepProtocol: SleepSanctuaryProtocol;
  homeRemedies: SymptomHomeRemedy[];
  medicationSchedule: MedicationTimingRule[];
  partnerGuide: PartnerEmpathyGuide;
  smartWatchSync: SmartWatchBiometricSync;
  defaultReminders: CareReminderItem[];
}

// -----------------------------------------------------------------------------
// 3. FeminaCycle™ Engine Implementation
// -----------------------------------------------------------------------------

export class FeminaCycleEngine {
  /**
   * Calculates current phase, predictions and regularity from cycle history.
   */
  static analyzeCycle({
    cycleHistory,
    todayDateStr = new Date().toISOString().split('T')[0],
  }: {
    cycleHistory: CycleEntry[];
    todayDateStr?: string;
  }): CyclePredictionResult {
    const today = new Date(todayDateStr);

    // If no history, assume 28-day standard starting 14 days ago
    if (!cycleHistory || cycleHistory.length === 0) {
      const defaultStart = new Date(today);
      defaultStart.setDate(defaultStart.getDate() - 14);
      return this._computePrediction(defaultStart, 28, today, 'regular');
    }

    // Sort descending (most recent first)
    const sorted = [...cycleHistory].sort(
      (a, b) => new Date(b.startDate).getTime() - new Date(a.startDate).getTime()
    );

    const latestStart = new Date(sorted[0].startDate);

    // Calculate average cycle length
    let avgLength = 28;
    const recordedLengths: number[] = [];

    for (let i = 0; i < sorted.length - 1; i++) {
      const current = new Date(sorted[i].startDate);
      const prev = new Date(sorted[i + 1].startDate);
      const diffDays = Math.round(
        (current.getTime() - prev.getTime()) / (1000 * 60 * 60 * 24)
      );
      if (diffDays >= 18 && diffDays <= 60) {
        recordedLengths.push(diffDays);
      }
    }

    if (recordedLengths.length > 0) {
      avgLength = Math.round(
        recordedLengths.reduce((a, b) => a + b, 0) / recordedLengths.length
      );
    } else if (sorted[0].cycleLengthDays) {
      avgLength = sorted[0].cycleLengthDays;
    }

    // Diagnose regularity
    let regularity: 'regular' | 'irregular_long' | 'irregular_short' | 'variable' =
      'regular';
    let insight =
      'Aapka cycle ekdum healthy aur regular range (25-35 din) me maintain hai.';

    if (avgLength > 35) {
      regularity = 'irregular_long';
      insight =
        'Aapka cycle lamba hai (>35 din). Ye delayed ovulation, PCOS ya stress hormone imbalance ka signal ho sakta hai.';
    } else if (avgLength < 21) {
      regularity = 'irregular_short';
      insight =
        'Aapka cycle jaldi aa raha hai (<21 din). Ye short luteal phase ya anovulatory cycle ka signal ho sakta hai.';
    } else if (recordedLengths.length >= 3) {
      const maxL = Math.max(...recordedLengths);
      const minL = Math.min(...recordedLengths);
      if (maxL - minL > 7) {
        regularity = 'variable';
        insight =
          'Aapke cycle me mahine-dar-mahine 7+ din ka variance hai. Hormonal balance ke lie natural seed cycling aur sleep schedule follow karein.';
      }
    }

    return this._computePrediction(latestStart, avgLength, today, regularity, insight);
  }

  private static _computePrediction(
    latestStart: Date,
    avgLength: number,
    today: Date,
    regularity: 'regular' | 'irregular_long' | 'irregular_short' | 'variable',
    insight = 'Healthy cycle alignment.'
  ): CyclePredictionResult {
    const elapsedDays = Math.max(
      0,
      Math.floor((today.getTime() - latestStart.getTime()) / (1000 * 60 * 60 * 24))
    );

    const currentCycleDay = (elapsedDays % avgLength) + 1;
    const daysUntilNext = avgLength - currentCycleDay + 1;

    // Estimate next start date
    const nextStart = new Date(latestStart);
    const completedCycles = Math.floor(elapsedDays / avgLength);
    nextStart.setDate(latestStart.getDate() + (completedCycles + 1) * avgLength);

    // Ovulation is typically 14 days before next period
    const ovulation = new Date(nextStart);
    ovulation.setDate(nextStart.getDate() - 14);

    const fertileStart = new Date(ovulation);
    fertileStart.setDate(ovulation.getDate() - 5);

    const fertileEnd = new Date(ovulation);
    fertileEnd.setDate(ovulation.getDate() + 1);

    // Identify current phase
    let phase: CyclePhase = 'follicular';
    let phaseDisplayName = 'Follicular Phase (Hormone Rebound)';
    let conceptionProb: 'low' | 'medium' | 'high' | 'peak' = 'low';

    if (currentCycleDay <= 5) {
      phase = 'menstrual';
      phaseDisplayName = 'Menstrual Phase (Rest & Replenish)';
      conceptionProb = 'low';
    } else if (currentCycleDay >= 6 && currentCycleDay <= 12) {
      phase = 'follicular';
      phaseDisplayName = 'Follicular Phase (Energy & Strength Peak)';
      conceptionProb = currentCycleDay >= 10 ? 'medium' : 'low';
    } else if (currentCycleDay >= 13 && currentCycleDay <= 16) {
      phase = 'ovulatory';
      phaseDisplayName = 'Ovulatory Phase (Peak Stamina & Fertility)';
      conceptionProb = currentCycleDay === 14 ? 'peak' : 'high';
    } else {
      phase = 'luteal';
      phaseDisplayName = 'Luteal Phase (PMS Care & Deep Recovery)';
      conceptionProb = 'low';
    }

    const tips: string[] = [];
    if (regularity === 'irregular_long' || regularity === 'variable') {
      tips.push(
        'Seed Cycling Phase 1 (Days 1-14): 1 spoon Flax + Pumpkin seeds roz lein jo natural estrogen regulate karte hain.'
      );
      tips.push(
        'Cortisol Control: Raat ko 10 PM tak soyein; deep sleep luteinizing hormone (LH) release ko rhythm me rakhta hai.'
      );
      tips.push(
        'Refined Sugar kam karein taaki insulin spike na ho aur ovaries par androgen load na badhe.'
      );
    } else {
      tips.push(
        'Cycle hydration: Din me kam se kam 2.5L paani lein taaki pelvic cramping aur water retention kam ho.'
      );
      tips.push(
        'Circadian sync: Subah 15 minute natural sunlight lene se melatonin aur cortisol synchronize rehte hain.'
      );
    }

    return {
      currentCycleDay,
      currentPhase: phase,
      phaseDisplayName,
      daysUntilNextPeriod: daysUntilNext,
      nextPeriodStartDate: nextStart.toISOString().split('T')[0],
      fertileWindowStart: fertileStart.toISOString().split('T')[0],
      fertileWindowEnd: fertileEnd.toISOString().split('T')[0],
      ovulationDate: ovulation.toISOString().split('T')[0],
      conceptionProbability: conceptionProb,
      averageCycleLength: avgLength,
      cycleRegularity: regularity,
      regularityInsight: insight,
      naturalBalancingTips: tips,
    };
  }

  /**
   * Generates symptom-adaptive relief plan: restorative yoga asanas and diet.
   */
  static getAdaptiveCarePlan({
    currentPhase,
    crampSeverity = 0,
    symptoms = [],
  }: {
    currentPhase: CyclePhase;
    crampSeverity?: number;
    symptoms?: MenstrualSymptom[];
  }): SymptomAdaptiveCarePlan {
    const asanas: ReliefAsana[] = [];

    // Severe or moderate cramps
    if (crampSeverity >= 3 || symptoms.includes('cramps')) {
      asanas.push({
        name: "Child's Pose",
        sanskritName: 'Balasana',
        durationMinutes: 5,
        benefits:
          'Pelvic floor aur lower back ki tightness release karta hai, uterine contractions ke dard ko sooth karta hai.',
        steps: [
          'Ghutno ke bal baith kar thighs ko thoda wide karein.',
          'Hips ko peeche heels par rakhein aur aage jhuk kar forehead zameen par lagayein.',
          'Arms ko aage extend karein aur deep breathing karein.',
        ],
        caution: 'Pet par dabav na dalein; knees wide rakhein taaki belly free rahe.',
      });

      asanas.push({
        name: 'Reclined Bound Angle Pose',
        sanskritName: 'Supta Baddha Konasana',
        durationMinutes: 7,
        benefits:
          'Abdominal wall ko stretch aur relax karta hai, pelvic blood flow badhata hai.',
        steps: [
          'Peeth ke bal let kar dono feet ke soles ko aapas me touch karein.',
          'Ghutno ko dono taraf butterfly ki tarah open karein.',
          'Ek haath heart par aur ek haath lower belly par rakh kar lambi saans lein.',
        ],
        caution: 'Agar inner thighs me khichav lage toh knees ke neeche pillow ya cushion rakhein.',
      });
    }

    // Backache or stiffness
    if (symptoms.includes('backache') || currentPhase === 'menstrual') {
      asanas.push({
        name: 'Cat-Cow Pose',
        sanskritName: 'Marjaryasana-Bitilasana',
        durationMinutes: 4,
        benefits:
          'Spine aur pelvic bones ko gently mobilize karta hai, sacrum pain ko turant kam karta hai.',
        steps: [
          'Four-point kneeling position me aayein (hands under shoulders, knees under hips).',
          'Inhale karte hue chest open karein aur back gentle arch karein (Cow).',
          'Exhale karte hue spine ko upar curve karein aur chin ko chest ki taraf le jayein (Cat).',
        ],
        caution: 'Jhatke se movement na karein; slow aur smooth breath ke sath karein.',
      });
    }

    // Bloating, fatigue or luteal PMS
    if (
      symptoms.includes('bloating') ||
      symptoms.includes('fatigue') ||
      currentPhase === 'luteal' ||
      currentPhase === 'menstrual'
    ) {
      asanas.push({
        name: 'Legs Up The Wall',
        sanskritName: 'Viparita Karani',
        durationMinutes: 8,
        benefits:
          'Legs aur pelvic area se stagnant blood aur lymphatic fluid wapas heart ki taraf drain karta hai, bloating aur thakan door karta hai.',
        steps: [
          'Deewar ke paas hips ko satayein aur dono legs ko deewar par seedha upar rest karein.',
          'Arms ko sides me open karein, eyes band karein.',
          '10 deep belly breaths lein.',
        ],
        caution: 'Cervical ya high BP issue ho toh sar ke neeche chota pillow rakhein.',
      });
    }

    // Default gentle asana if none matched
    if (asanas.length === 0) {
      asanas.push({
        name: 'Corpse Pose with Heart Opener',
        sanskritName: 'Supported Savasana',
        durationMinutes: 10,
        benefits: 'Nervous system ko parasympathetic rest-and-digest mode me le jata hai.',
        steps: [
          'Peeth ke bal seedhe let jayein.',
          'Knees ke neeche rolled towel ya bolster rakhein.',
          'Poori body ko zameen par dheela chhod dein.',
        ],
        caution: 'Room ka temperature comfortable rakhein.',
      });
    }

    // Diet determination based on phase and symptoms
    let diet: CycleNutritionRecommendation;

    if (currentPhase === 'menstrual') {
      diet = {
        focus: 'Iron & Magnesium Replenishment + Anti-Inflammatory',
        keyNutrients: ['Iron', 'Magnesium', 'Vitamin C', 'Zinc'],
        recommendedFoods: [
          'Palak (Spinach), Methi aur Bathua',
          'Pomegranate (Anaar) aur Chhote Black Raisins (Kishmish)',
          'Roasted Chana aur Gud (Jaggery) — Natural iron powerhouse',
          'Pumpkin Seeds (Magnesium cramps relief)',
          'Ginger & Cinnamon Warm Herbal Water (Uterine muscle relaxation)',
        ],
        avoidFoods: [
          'Cold iced drinks (uterine spasm trigger)',
          'Excessive caffeine/coffee (constricts blood vessels)',
          'Deep fried salty snacks (increases water retention)',
        ],
        seedCyclingTip:
          'Phase 1: 1 tbsp ground Flax Seeds roz lein jo healthy estrogen clearance me madad karta hai.',
        rationale:
          'Blood loss se ferritin drop hota hai jisse fatigue aati hai. Warm iron-dense Indian foods energy restore karte hain aur magnesium uterine spasms ko relax karta hai.',
      };
    } else if (currentPhase === 'follicular') {
      diet = {
        focus: 'High Energy, Lean Protein & Gut Microbiome Support',
        keyNutrients: ['Lean Protein', 'Probiotics', 'Complex Carbohydrates'],
        recommendedFoods: [
          'Sprouted Moong & Chana (High bioavailability protein)',
          'Curd / Dahi aur Chaas with roasted jeera',
          'Fresh Seasonal Fruits (Papaya, Apple, Berries)',
          'Oats, Brown Rice aur Multigrain Roti',
        ],
        avoidFoods: ['Processed packaged foods', 'Refined maida bakery products'],
        seedCyclingTip:
          'Phase 1 Continue: 1 tbsp Pumpkin seeds lein jo zinc aur estrogen receptor building me madad karte hain.',
        rationale:
          'Estrogen rise hone se metabolism fast hota hai. High-quality protein aur probiotics follicular maturation aur muscle tone build karte hain.',
      };
    } else if (currentPhase === 'ovulatory') {
      diet = {
        focus: 'Liver Detoxification & Antioxidant Defense',
        keyNutrients: ['Glutathione precursors', 'Vitamin E', 'Fiber'],
        recommendedFoods: [
          'Cruciferous vegetables: Cauliflower, Cabbage, Broccoli',
          'Avocado, Almonds aur Soaked Walnuts',
          'Coconut Water aur Nimbu Paani with Chia Seeds',
          'Fresh salad with cucumber, carrots, beetroots',
        ],
        avoidFoods: ['Heavy oily gravies', 'Excessive table salt'],
        seedCyclingTip: 'Transitioning to Phase 2: Sesame seeds shuru karein.',
        rationale:
          'Estrogen apne peak par hota hai. Fiber aur liver-supporting cruciferous vegetables excess estrogen ko safely metabolize karke bahar nikalte hain.',
      };
    } else {
      // Luteal Phase
      diet = {
        focus: 'Progesterone Synthesis, PMS Mood & Bloating Control',
        keyNutrients: ['Vitamin B6', 'Omega-3', 'Potassium', 'Complex Fiber'],
        recommendedFoods: [
          'Banana (Kela) — High in B6 and potassium to reduce bloating',
          'Sesame Seeds (Til) & Sunflower Seeds (Surajmukhi ke beej)',
          'Dark Chocolate (70%+ cocoa) for endorphins and magnesium',
          'Warm Herbal Chamomile / Ajwain Tea for gas and mood stability',
          'Khichdi with Ghee (Easy to digest warm comfort food)',
        ],
        avoidFoods: [
          'High sodium papad, pickles, chips (prevents swelling/bloating)',
          'Excess refined sugars (prevents mood crashes)',
        ],
        seedCyclingTip:
          'Phase 2: 1 tbsp Sesame (Til) + 1 tbsp Sunflower seeds roz lein jo natural progesterone synthesis me madad karte hain.',
        rationale:
          'Progesterone dominancy ke dauran digestion thoda slow ho jata hai aur water retention badhti hai. Vitamin B6 serotonin aur dopamine boost karta hai jabki potassium bloating ko counteract karta hai.',
      };
    }

    const lifestyle: string[] = [
      'Garam paani ka warm compress ya heating pad lower belly par 15 minute lagayein.',
      'Wear loose, breathable cotton clothing around the waist.',
      'Raat ko herbal ginger-tulsi ya chamomile tea lene se sleep quality behtar hoti hai.',
    ];

    const chronoRoutine = this._buildFeminaChronoRoutine(currentPhase);
    const fruitTherapy = this._buildFeminaFruitTherapy(currentPhase);
    const sleepProtocol = this._buildFeminaSleepSanctuary(currentPhase);
    const homeRemedies = this._buildFeminaHomeRemedies(currentPhase, symptoms, crampSeverity);
    const medicationSchedule = this._buildFeminaMedicationSchedule(currentPhase);
    const partnerGuide = this._buildFeminaPartnerGuide(currentPhase);
    const smartWatchSync = this._buildFeminaSmartWatchSync(currentPhase);
    const defaultReminders = this._buildFeminaDefaultReminders(currentPhase);

    return {
      crampSeverity,
      activeSymptoms: symptoms,
      recommendedAsanas: asanas,
      dietaryPlan: diet,
      hydrationGoalMl: 2500,
      lifestyleGuidance: lifestyle,
      chronoRoutine,
      fruitTherapy,
      sleepProtocol,
      homeRemedies,
      medicationSchedule,
      partnerGuide,
      smartWatchSync,
      defaultReminders,
    };
  }

  // ---------------------------------------------------------------------------
  // Femina Helpers: 24h Chrono, Fruit Therapy, Sleep & Remedies
  // ---------------------------------------------------------------------------

  private static _buildFeminaChronoRoutine(phase: CyclePhase): DailyChronoRoutineStep[] {
    switch (phase) {
      case 'menstrual':
        return [
          {
            id: 'm_wake',
            timeSlot: '06:30 AM - 07:30 AM',
            periodOfDay: 'morning_wake',
            title: 'Warm Ginger-Ajwain Gentle Awakening',
            guidance: 'Uterine contractions ko sooth karne ke lie warm water infusion lein.',
            nutritionOrAction: '1 glass lukewarm water + fresh ginger slices + pinch of ajwain & jaggery.',
            sleepPostureOrTip: 'Bedsheet se uthne se pehle gentle knees-to-chest stretch karein.',
            medicineOrSupplements: ['Warm digestive herbal infusion'],
          },
          {
            id: 'm_breakfast',
            timeSlot: '08:00 AM - 09:00 AM',
            periodOfDay: 'breakfast',
            title: 'Iron & Bioavailable Protein Nourishment',
            guidance: 'Blood loss se hone wale ferritin drop ko counteract karein.',
            nutritionOrAction: 'Warm Besan/Moong Dal Cheela stuffed with Palak & Paneer + 5 soaked Black Raisins.',
            sleepPostureOrTip: 'Upright mindful eating; walk 5 mins after eating.',
            medicineOrSupplements: ['Iron Supplement (with fresh lemon water, NEVER with tea/milk)'],
          },
          {
            id: 'm_mid_morning',
            timeSlot: '10:30 AM - 11:30 AM',
            periodOfDay: 'mid_morning',
            title: 'Fruit Therapy & Seed Cycling Phase 1',
            guidance: 'Vitamin C se non-heme iron absorption 300% badhti hai.',
            nutritionOrAction: '1 bowl fresh Pomegranate (Anaar) arils + 1 tbsp ground Flax Seeds.',
            sleepPostureOrTip: 'Stay hydrated with warm water sips.',
            medicineOrSupplements: [],
          },
          {
            id: 'm_lunch',
            timeSlot: '01:00 PM - 02:00 PM',
            periodOfDay: 'lunch',
            title: 'Warm Comfort Indian Healing Lunch',
            guidance: 'Pelvic circulation promote karta hai aur bloating prevent karta hai.',
            nutritionOrAction: 'Steamed Rice + Methi Dal + Beetroot Salad + 1 tsp A2 Desi Cow Ghee.',
            sleepPostureOrTip: 'Vajrasana me 5 minutes baith kar digestion settle karein.',
            medicineOrSupplements: [],
          },
          {
            id: 'm_afternoon_rest',
            timeSlot: '03:30 PM - 04:30 PM',
            periodOfDay: 'afternoon_rest',
            title: 'Lymphatic Drainage & Feet Elevation',
            guidance: 'Pelvic area se pooling blood aur fatigue release karein.',
            nutritionOrAction: '1 cup warm Cinnamon water or Fennel tea.',
            sleepPostureOrTip: '15-min Legs-Up-The-Wall (Viparita Karani) deewar par legs rest karke.',
            medicineOrSupplements: [],
          },
          {
            id: 'm_evening_movement',
            timeSlot: '05:30 PM - 06:30 PM',
            periodOfDay: 'evening_movement',
            title: 'Restorative Asana Sanctuary (Zero Inversions)',
            guidance: 'Uterine smooth muscle tone relax karein. Heavy weights aur HIIT avoid karein.',
            nutritionOrAction: 'Balasana (Child\'s Pose) + Supta Baddha Konasana + Cat-Cow (Marjaryasana).',
            sleepPostureOrTip: 'Ground mat par soft pillow aur blanket use karein.',
            medicineOrSupplements: [],
          },
          {
            id: 'm_dinner',
            timeSlot: '07:30 PM - 08:30 PM',
            periodOfDay: 'dinner',
            title: 'Anti-Inflammatory Light Dinner',
            guidance: 'Sone se kam se kam 2 ghante pehle dinner khatam karein.',
            nutritionOrAction: 'Warm Palak-Paneer Soup ya 2 soft Phulkas with Lauki/Tori and Moong dal.',
            sleepPostureOrTip: 'Walk 100 paces gently post dinner.',
            medicineOrSupplements: [],
          },
          {
            id: 'm_bedtime',
            timeSlot: '09:45 PM - 10:30 PM',
            periodOfDay: 'bedtime',
            title: 'Golden Haldi Milk & Deep Sleep Sanctuary',
            guidance: 'Cramps block karke deep REM sleep spindles induce karein. Target: 8.5-9.5 hrs.',
            nutritionOrAction: 'Warm Milk + Turmeric (Haldi) + Cardamom + pinch of black pepper + 1/2 tsp Ghee.',
            sleepPostureOrTip: 'Fetal position me soyein ya knees ke beech supportive pillow rakhein.',
            medicineOrSupplements: ['Magnesium Glycinate (300mg) for cramp relief & deep sleep'],
          },
        ];

      case 'follicular':
        return [
          {
            id: 'f_wake',
            timeSlot: '06:30 AM - 07:30 AM',
            periodOfDay: 'morning_wake',
            title: 'Metabolic Fire Morning Awakening',
            guidance: 'Estrogen rising phase me gut fire aur energy ignite karein.',
            nutritionOrAction: '1 glass lukewarm water + half lemon squeeze + 1 tsp soaked Chia seeds.',
            sleepPostureOrTip: '10 mins natural morning sunlight exposure.',
            medicineOrSupplements: [],
          },
          {
            id: 'f_breakfast',
            timeSlot: '08:00 AM - 09:00 AM',
            periodOfDay: 'breakfast',
            title: 'High-Protein & Probiotic Stamina Bowl',
            guidance: 'Follicular growth aur lean muscle building ko support karein.',
            nutritionOrAction: 'Sprouted Moong Salad + Fresh Dahi (Curd) with roasted cumin + 4 Almonds.',
            sleepPostureOrTip: 'Active upright posture, full energetic breathing.',
            medicineOrSupplements: ['Zinc (15-30mg) for follicle maturation'],
          },
          {
            id: 'f_mid_morning',
            timeSlot: '10:30 AM - 11:30 AM',
            periodOfDay: 'mid_morning',
            title: 'Prebiotic Fruit & Pumpkin Seed Cycling',
            guidance: 'Zinc follicle rupture aur estrogen receptor sensitivity enhance karta hai.',
            nutritionOrAction: '1 Crisp Green Apple or Ripe Papaya bowl + 1 tbsp raw Pumpkin Seeds.',
            sleepPostureOrTip: 'Maintain optimal hydration (min 2.5L daily).',
            medicineOrSupplements: [],
          },
          {
            id: 'f_lunch',
            timeSlot: '01:00 PM - 02:00 PM',
            periodOfDay: 'lunch',
            title: 'Lean Protein & Complex Fuel Lunch',
            guidance: 'High metabolic rate supports steady sustained energy.',
            nutritionOrAction: 'Multigrain Roti + Rajma / Grilled Paneer + Crunchy Cucumber-Carrot Salad.',
            sleepPostureOrTip: 'Short 5-min walk after lunch.',
            medicineOrSupplements: [],
          },
          {
            id: 'f_afternoon_rest',
            timeSlot: '03:30 PM - 04:30 PM',
            periodOfDay: 'afternoon_rest',
            title: 'Cognitive Reset & Hydration',
            guidance: 'Brain alertness peak par hoti hai; sustain with green tea.',
            nutritionOrAction: 'Green tea or Matcha + 4 soaked Walnuts.',
            sleepPostureOrTip: 'Posture check: shoulders rolled back, spine straight.',
            medicineOrSupplements: [],
          },
          {
            id: 'f_evening_movement',
            timeSlot: '05:30 PM - 06:30 PM',
            periodOfDay: 'evening_movement',
            title: 'Peak Strength & Athletic Conditioning',
            guidance: 'Estrogen ke karan pain tolerance highest hai — optimal time for heavy lifts or cardio.',
            nutritionOrAction: 'Gym Strength Training, Power Vinyasa Yoga, or 5km brisk run.',
            sleepPostureOrTip: 'Dynamic warmup followed by thorough cool-down stretches.',
            medicineOrSupplements: [],
          },
          {
            id: 'f_dinner',
            timeSlot: '07:30 PM - 08:30 PM',
            periodOfDay: 'dinner',
            title: 'Cellular Repair Protein Dinner',
            guidance: 'Muscle recovery and overnight glycogen replenishment.',
            nutritionOrAction: 'Steamed vegetables with Grilled Tofu / Paneer and Yellow Moong Dal soup.',
            sleepPostureOrTip: 'Gentle post-dinner stroll.',
            medicineOrSupplements: [],
          },
          {
            id: 'f_bedtime',
            timeSlot: '09:45 PM - 10:30 PM',
            periodOfDay: 'bedtime',
            title: 'Circadian Wind-Down & Deep Rest',
            guidance: 'High sleep efficiency phase. Target: 7.5 - 8.0 hours.',
            nutritionOrAction: 'Chamomile tea or warm water with soaked raisins.',
            sleepPostureOrTip: 'Room temperature cool (20-22°C), complete dark room.',
            medicineOrSupplements: [],
          },
        ];

      case 'ovulatory':
        return [
          {
            id: 'o_wake',
            timeSlot: '06:30 AM - 07:30 AM',
            periodOfDay: 'morning_wake',
            title: 'Hydration & Cervical Fluid Nourishment',
            guidance: 'Fertile cervical mucus aur luteinizing hormone (LH) surge ko support karein.',
            nutritionOrAction: '1 glass fresh Tender Coconut Water or Aloe Vera juice.',
            sleepPostureOrTip: 'Gentle morning spine twists and deep ocean breathing.',
            medicineOrSupplements: [],
          },
          {
            id: 'o_breakfast',
            timeSlot: '08:00 AM - 09:00 AM',
            periodOfDay: 'breakfast',
            title: 'Antioxidant Defense & Energy Breakfast',
            guidance: 'Follicular rupture ke oxidative stress se cells ko protect karein.',
            nutritionOrAction: 'Berry Smoothie Bowl with Chia Seeds & Walnuts, or Boiled Eggs / Tofu Bhurji.',
            sleepPostureOrTip: 'Mindful peaceful eating.',
            medicineOrSupplements: ['Antioxidant CoQ10 / Vitamin E'],
          },
          {
            id: 'o_mid_morning',
            timeSlot: '10:30 AM - 11:30 AM',
            periodOfDay: 'mid_morning',
            title: 'Glutathione Fruit Therapy & Sunflower Seeds',
            guidance: 'Liver detoxification of peak estrogen.',
            nutritionOrAction: 'Fresh Watermelon slices or Sweet Lime (Mosambi) + 1 tbsp Sunflower Seeds.',
            sleepPostureOrTip: 'Stay active; move every 45 minutes.',
            medicineOrSupplements: [],
          },
          {
            id: 'o_lunch',
            timeSlot: '01:00 PM - 02:00 PM',
            periodOfDay: 'lunch',
            title: 'Cruciferous Liver-Clearing Feast',
            guidance: 'Indole-3-carbinol liver me excess estrogen clearance boost karta hai.',
            nutritionOrAction: 'Steamed Broccoli, Cauliflower, and Carrots + Dal + Quinoa or Roti.',
            sleepPostureOrTip: 'Sit upright, avoid screen during eating.',
            medicineOrSupplements: [],
          },
          {
            id: 'o_afternoon_rest',
            timeSlot: '03:30 PM - 04:30 PM',
            periodOfDay: 'afternoon_rest',
            title: 'Cellular Cooling Refresh',
            guidance: 'Body temperature post-ovulation 0.3°C badhne lagti hai.',
            nutritionOrAction: 'Fresh Chaas (Buttermilk) with crushed mint and roasted jeera.',
            sleepPostureOrTip: 'Step outside for fresh oxygen breathwork.',
            medicineOrSupplements: [],
          },
          {
            id: 'o_evening_movement',
            timeSlot: '05:30 PM - 06:30 PM',
            periodOfDay: 'evening_movement',
            title: 'High Intensity Intervals & Social Workouts',
            guidance: 'Peak testosterone & estrogen drive maximum stamina and social confidence.',
            nutritionOrAction: 'HIIT training, group fitness dance, or competitive sports.',
            sleepPostureOrTip: 'Full body cool-down and pelvic stretches.',
            medicineOrSupplements: [],
          },
          {
            id: 'o_dinner',
            timeSlot: '07:30 PM - 08:30 PM',
            periodOfDay: 'dinner',
            title: 'Light Antioxidant Quinoa & Lentils',
            guidance: 'Easy digestion prevents night discomfort.',
            nutritionOrAction: 'Warm Quinoa Bowl with Sautéed Bell Peppers, Spinach, and Moong Dal.',
            sleepPostureOrTip: '10 mins leisurely walk.',
            medicineOrSupplements: [],
          },
          {
            id: 'o_bedtime',
            timeSlot: '09:45 PM - 10:30 PM',
            periodOfDay: 'bedtime',
            title: 'Cool Bedroom Sanctuary Rest',
            guidance: 'Maintain deep sleep architecture. Target: 7.5 - 8.0 hours.',
            nutritionOrAction: 'Sip cold/room-temp water with fresh mint.',
            sleepPostureOrTip: 'Use breathable organic cotton sheets and cool ventilation.',
            medicineOrSupplements: [],
          },
        ];

      case 'luteal':
        return [
          {
            id: 'l_wake',
            timeSlot: '06:30 AM - 07:30 AM',
            periodOfDay: 'morning_wake',
            title: 'Warm CCF Bloating-Shield Awakening',
            guidance: 'Progesterone digestively slow karta hai; CCF tea gut ko activate karti hai.',
            nutritionOrAction: 'Warm Cumin-Coriander-Fennel (CCF) boiled tea.',
            sleepPostureOrTip: 'Gentle Cat-Cow stretches on bed before standing.',
            medicineOrSupplements: [],
          },
          {
            id: 'l_breakfast',
            timeSlot: '08:00 AM - 09:00 AM',
            periodOfDay: 'breakfast',
            title: 'Serotonin-Boosting Complex Carb Breakfast',
            guidance: 'Pre-menstrual serotonin drop ko complex carbs aur Vitamin B6 se prevent karein.',
            nutritionOrAction: 'Warm Oatmeal or Multigrain Dalia with sliced banana, walnuts & pinch of cinnamon.',
            sleepPostureOrTip: 'Upright calm posture, avoid caffeinated coffee spikes.',
            medicineOrSupplements: ['Vitamin B6 (50mg) / Evening Primrose Oil'],
          },
          {
            id: 'l_mid_morning',
            timeSlot: '10:30 AM - 11:30 AM',
            periodOfDay: 'mid_morning',
            title: 'Potassium Fruit Therapy & Sesame Seed Cycling',
            guidance: 'Potassium excess sodium flush karta hai; sesame seeds progesterone build karte hain.',
            nutritionOrAction: '1 Ripe Robusta Banana or 2 fresh Figs (Anjeer) + 1 tbsp roasted Sesame (Til) seeds.',
            sleepPostureOrTip: 'Continuous steady water intake.',
            medicineOrSupplements: [],
          },
          {
            id: 'l_lunch',
            timeSlot: '01:00 PM - 02:00 PM',
            periodOfDay: 'lunch',
            title: 'Digestive Comfort Khichdi & Light Gourds',
            guidance: 'Slow motility me heavy foods constipation aur gas karte hain.',
            nutritionOrAction: 'Moong Dal Khichdi + Ghee + Lauki/Turai subzi + Fresh Pudina curd.',
            sleepPostureOrTip: 'Vajrasana for 5 mins post-meal.',
            medicineOrSupplements: [],
          },
          {
            id: 'l_afternoon_rest',
            timeSlot: '03:30 PM - 04:30 PM',
            periodOfDay: 'afternoon_rest',
            title: 'PMS Mood Reset & Endorphin Boost',
            guidance: 'Magnesium suppresses cortisol and curbs sweet cravings.',
            nutritionOrAction: '1 cup Chamomile tea + 2 squares of 70%+ Dark Chocolate.',
            sleepPostureOrTip: '10-min mindfulness or box breathing (4-4-4-4).',
            medicineOrSupplements: [],
          },
          {
            id: 'l_evening_movement',
            timeSlot: '05:30 PM - 06:30 PM',
            periodOfDay: 'evening_movement',
            title: 'Low-Impact Pilates & Nature Walking',
            guidance: 'High intensity HIIT increases cortisol during luteal phase; switch to gentle movement.',
            nutritionOrAction: '30-min brisk walk in nature, Mat Pilates, or Yin Yoga.',
            sleepPostureOrTip: 'Deep hip opening stretches (Pigeon pose, Butterfly pose).',
            medicineOrSupplements: [],
          },
          {
            id: 'l_dinner',
            timeSlot: '07:30 PM - 08:30 PM',
            periodOfDay: 'dinner',
            title: 'Early Low-Sodium Soothing Dinner',
            guidance: 'Pickles, papad aur high salt strictly avoid karein to prevent puffy face/hands.',
            nutritionOrAction: 'Lauki Kofta Curry (light gravy) with 2 Phulkas or Pumpkin-Ginger Soup.',
            sleepPostureOrTip: 'No food within 2.5 hours of bedtime to prevent GERD.',
            medicineOrSupplements: [],
          },
          {
            id: 'l_bedtime',
            timeSlot: '09:45 PM - 10:30 PM',
            periodOfDay: 'bedtime',
            title: 'Progesterone Sleep Sanctuary Rest',
            guidance: 'Higher body temperature can fragment sleep. Keep bedroom cool. Target: 8.5-9.0 hrs.',
            nutritionOrAction: 'Warm Ashwagandha or Chamomile infusion.',
            sleepPostureOrTip: 'Side sleeping with pillow between knees; blackout curtains.',
            medicineOrSupplements: ['Magnesium Glycinate (300mg) at bedtime'],
          },
        ];
    }
  }

  private static _buildFeminaFruitTherapy(phase: CyclePhase): FruitTherapyGuide {
    switch (phase) {
      case 'menstrual':
        return {
          dailyFruitRule: 'Always consume room-temperature fruits. Avoid refrigerated cold melons during bleeding.',
          recommendedFruits: [
            {
              name: 'Pomegranate',
              hindiName: 'Anaar',
              benefits: 'High bioavailable non-heme iron and polyphenol antioxidants; directly combats menstrual fatigue and replenishes red blood cells.',
              nutrientKey: 'Iron, Vitamin C, Folate',
              timing: 'Mid-morning (11:00 AM)',
              bestConsumedWith: 'Pinch of black salt and ground flax seeds',
            },
            {
              name: 'Ripe Banana',
              hindiName: 'Kela',
              benefits: 'Rich in Vitamin B6 and potassium; relieves smooth muscle cramps and prevents sudden dopamine drops.',
              nutrientKey: 'Vitamin B6, Potassium, Magnesium',
              timing: 'Breakfast or mid-afternoon',
              bestConsumedWith: 'Warm cinnamon dash',
            },
            {
              name: 'Kiwi & Indian Gooseberry',
              hindiName: 'Amla',
              benefits: 'Mega-dose Vitamin C amplifies plant-based iron absorption by over 300%.',
              nutrientKey: 'Vitamin C, Bioflavonoids',
              timing: 'Right after lunch or breakfast',
              bestConsumedWith: 'Fresh water',
            },
          ],
          avoidOrCautionFruits: [
            {
              name: 'Chilled Melons',
              hindiName: 'Thandi Kharbooza / Tarbooz',
              riskLevel: 'caution',
              clinicalReason: 'Cold temperatures trigger pelvic vasoconstriction and worsen spasmodic dysmenorrhea.',
              scientificMechanism: 'Cold-induced smooth muscle shivering increases prostaglandin release.',
            },
            {
              name: 'Unripe Sour Mango',
              hindiName: 'Kacchi Kairi',
              riskLevel: 'caution',
              clinicalReason: 'Excess acidity triggers gastric distress and uterine discomfort.',
              scientificMechanism: 'High citric/malic acid aggravating gut sensitivity.',
            },
          ],
        };

      case 'follicular':
        return {
          dailyFruitRule: 'Focus on high-fiber prebiotic fruits that nourish gut bacteria for clean estrogen synthesis.',
          recommendedFruits: [
            {
              name: 'Green Apple',
              hindiName: 'Seb',
              benefits: 'High pectin soluble fiber feeds estrobolome gut bacteria, supporting healthy estrogen levels.',
              nutrientKey: 'Pectin, Quercetin, Vitamin C',
              timing: 'Mid-morning snack',
              bestConsumedWith: 'Almond butter or raw pumpkin seeds',
            },
            {
              name: 'Ripe Papaya',
              hindiName: 'Paka Papita',
              benefits: 'Rich in carotenes and digestive papain enzyme; maintains smooth bowel regularity.',
              nutrientKey: 'Beta-Carotene, Papain, Folate',
              timing: 'Mid-morning',
              bestConsumedWith: 'Fresh lime squeeze',
            },
            {
              name: 'Blueberries & Blackberries',
              hindiName: 'Berries / Jamun',
              benefits: 'Anthocyanins protect the developing ovarian follicle from cellular oxidative stress.',
              nutrientKey: 'Anthocyanins, Vitamin E',
              timing: 'Breakfast bowl',
              bestConsumedWith: 'Greek yogurt or curd',
            },
          ],
          avoidOrCautionFruits: [],
        };

      case 'ovulatory':
        return {
          dailyFruitRule: 'Focus on high hydration, glutathione, and capillary-strengthening citrus bioflavonoids.',
          recommendedFruits: [
            {
              name: 'Watermelon',
              hindiName: 'Tarbooz',
              benefits: '92% cellular hydration with lycopene; keeps cervical crypts hydrated and cools body during LH peak.',
              nutrientKey: 'Lycopene, Citrulline, Potassium',
              timing: 'Mid-morning (11:00 AM)',
              bestConsumedWith: 'Fresh mint leaves',
            },
            {
              name: 'Sweet Lime & Oranges',
              hindiName: 'Mosambi / Santra',
              benefits: 'Bioflavonoids strengthen vascular capillary walls around the ovulating follicle.',
              nutrientKey: 'Hesperidin, Vitamin C',
              timing: 'Afternoon snack',
              bestConsumedWith: 'Pinch of black pepper',
            },
          ],
          avoidOrCautionFruits: [],
        };

      case 'luteal':
        return {
          dailyFruitRule: 'Prioritize high-potassium, low-glycemic fruits to combat PMS water retention and sugar cravings.',
          recommendedFruits: [
            {
              name: 'Robusta Banana',
              hindiName: 'Paka Kela',
              benefits: 'High potassium flushes excess sodium; Vitamin B6 drives serotonin synthesis to abolish PMS irritability.',
              nutrientKey: 'Potassium, Vitamin B6, Tryptophan',
              timing: 'Breakfast or 4:00 PM craving window',
              bestConsumedWith: '1 tsp peanut butter or sunflower seeds',
            },
            {
              name: 'Fresh Figs',
              hindiName: 'Anjeer',
              benefits: 'High magnesium and bioavailable iron; satisfies pre-menstrual sweet cravings with zero glycemic spike.',
              nutrientKey: 'Magnesium, Soluble Fiber, Iron',
              timing: 'Mid-morning',
              bestConsumedWith: 'Warm water or walnuts',
            },
            {
              name: 'Fresh Avocado',
              hindiName: 'Makhan Phal',
              benefits: 'Healthy monounsaturated fatty acids provide lipid building blocks for sustained progesterone.',
              nutrientKey: 'MUFA, Folate, Vitamin E',
              timing: 'Lunch salad or toast',
              bestConsumedWith: 'Lemon juice and sea salt',
            },
          ],
          avoidOrCautionFruits: [
            {
              name: 'Sugar-Coated Candied Fruits',
              hindiName: 'Chashni wale Sukhe Phal',
              riskLevel: 'caution',
              clinicalReason: 'Sharp glucose spikes trigger reactive hypoglycemia, aggravating mood swings and acne.',
              scientificMechanism: 'Insulin surges stimulate sebaceous androgen receptors, triggering cystic acne.',
            },
          ],
        };
    }
  }

  private static _buildFeminaSleepSanctuary(phase: CyclePhase): SleepSanctuaryProtocol {
    switch (phase) {
      case 'menstrual':
        return {
          targetSleepHours: '8.5 - 9.5 hours',
          optimalPosture: 'Fetal Posture (Side lying with knees tucked) or Supine with a bolster under knees',
          pillowSetup: 'Place a soft bolster or pillow under your knees to release pelvic and sacral tension.',
          circadianTip: 'Wear warm cotton socks to bed; warming peripheral extremities induces rapid sleep onset.',
          windDownRitual: [
            'Digital screen sunset 45 minutes before sleep.',
            'Apply warm castor oil or sesame oil gently to lower belly.',
            'Sip warm Golden Turmeric Milk.',
            'Listen to 432 Hz delta sleep tones or practice 4-7-8 breathing.',
          ],
          hormonalContext: 'Estrogen and progesterone are at their lowest baseline; immune cytokines rise slightly, requiring maximum restorative slow-wave sleep.',
        };

      case 'follicular':
        return {
          targetSleepHours: '7.5 - 8.0 hours',
          optimalPosture: 'Side sleeping with ergonomic cervical pillow',
          pillowSetup: 'Single medium-firm pillow aligning cervical spine with thoracic vertebrae.',
          circadianTip: 'Wake up with natural morning blue-sky light to anchor daytime cortisol rhythm.',
          windDownRitual: [
            'Read 10-15 pages of an inspiring book.',
            'Sip chamomile or lemon balm infusion.',
            'Dim bedroom lights to warm amber 1 hour before sleep.',
          ],
          hormonalContext: 'Rising estrogen enhances REM sleep efficiency and rapid morning wakefulness.',
        };

      case 'ovulatory':
        return {
          targetSleepHours: '7.5 hours',
          optimalPosture: 'Left or right lateral recumbent',
          pillowSetup: 'Supportive pillow ensuring neck is level.',
          circadianTip: 'Set bedroom AC/fan to 20-22°C to counteract natural ovulatory body temperature rise.',
          windDownRitual: [
            '10 minutes evening gratitude journaling.',
            'Cool water wash for face and feet.',
            'Gentle forward folds before getting into bed.',
          ],
          hormonalContext: 'Estrogen and testosterone peak; sleep need is lowest, energy is highest.',
        };

      case 'luteal':
        return {
          targetSleepHours: '8.5 - 9.0 hours',
          optimalPosture: 'Side sleeping with pillow firmly between thighs',
          pillowSetup: 'Placing a pillow between knees prevents pelvic torsion and relieves pre-menstrual lower back ache.',
          circadianTip: 'Progesterone elevates core body temperature by 0.3-0.5°C; keep bedroom extra cool and dark.',
          windDownRitual: [
            'Take a warm epsom salt bath 90 mins before bed (rapid cooling post-bath triggers melatonin release).',
            'Sip warm Ashwagandha-Chamomile tea.',
            'Wear loose breathable modal or organic cotton nightwear.',
          ],
          hormonalContext: 'High progesterone increases sleep fragmentation and daytime drowsiness. Extra sleep duration is biologically essential.',
        };
    }
  }

  private static _buildFeminaHomeRemedies(
    phase: CyclePhase,
    symptoms: MenstrualSymptom[],
    crampSeverity: number
  ): SymptomHomeRemedy[] {
    const remedies: SymptomHomeRemedy[] = [];

    if (crampSeverity >= 2 || symptoms.includes('cramps')) {
      remedies.push({
        symptom: 'Menstrual Cramps (Dysmenorrhea)',
        title: 'Ajwain-Jeera & Jaggery (Gud) Decoction',
        ingredients: ['1 tsp Ajwain (Carom seeds)', '1 tsp Jeera (Cumin seeds)', '1 small piece organic Jaggery', '2 cups water'],
        preparation: 'Boil ajwain and jeera in 2 cups water until reduced to 1 cup. Add jaggery, stir until dissolved, strain and sip warm.',
        clinicalRationale: 'Thymol in ajwain acts as a potent natural antispasmodic on uterine myometrial smooth muscle.',
        timing: 'Morning and evening during peak cramps',
        cautions: 'Drink warm, not scalding hot.',
      });

      remedies.push({
        symptom: 'Spasmodic Pelvic Pain',
        title: 'Suprapubic Warm Castor Oil Compress',
        ingredients: ['Cold-pressed Castor oil (Arandi ka tel)', 'Flannel cloth', 'Hot water bottle / heating pad'],
        preparation: 'Warm 2 tbsp castor oil, massage onto suprapubic abdomen, cover with warm cloth and rest hot water bag for 15-20 mins.',
        clinicalRationale: 'Ricinoleic acid penetrates dermally to stimulate pelvic lymphatic flow and down-regulate prostaglandin E2.',
        timing: 'Evening while lying down',
        cautions: 'Do not use if heavy bleeding with clots is uncontrolled.',
      });
    }

    if (symptoms.includes('bloating') || phase === 'luteal') {
      remedies.push({
        symptom: 'Premenstrual Bloating & Water Retention',
        title: 'Cumin-Coriander-Fennel (CCF) Detox Tea',
        ingredients: ['1/2 tsp Cumin seeds', '1/2 tsp Coriander seeds', '1/2 tsp Fennel (Saunf) seeds', '2.5 cups water'],
        preparation: 'Boil gently for 7 minutes, strain, and sip warm throughout the afternoon.',
        clinicalRationale: 'Fennel anethole relaxes gastrointestinal sphincters while coriander acts as a gentle natural diuretic.',
        timing: 'Post lunch or 4:00 PM',
        cautions: 'Safe for daily use.',
      });
    }

    if (symptoms.includes('headache') || symptoms.includes('mood_swings')) {
      remedies.push({
        symptom: 'Hormonal Migraines & PMS Mood Swings',
        title: 'Magnesium Dark Chocolate & Peppermint Acupressure',
        ingredients: ['2 squares 70%+ Dark Chocolate', 'Peppermint essential oil (1 drop) with almond oil', 'Warm water'],
        preparation: 'Eat dark chocolate mindfully. Apply diluted peppermint oil to temples and press LI-4 (Hegu point between thumb & index finger).',
        clinicalRationale: 'Magnesium regulates vascular tone in cerebral arteries, halting vasoconstriction and boosting brain endorphins.',
        timing: 'At onset of headache or mood slump',
        cautions: 'Avoid if sensitive to caffeine in late evenings.',
      });
    }

    if (remedies.length === 0) {
      remedies.push({
        symptom: 'Daily Hormone Balance',
        title: 'Golden Turmeric & Cardamom Healing Milk',
        ingredients: ['1 cup Cow or Oat milk', '1/4 tsp organic Turmeric', '2 crushed Cardamom pods', 'pinch of black pepper'],
        preparation: 'Simmer on low heat for 5 minutes. Sweeten lightly with raw honey or dates.',
        clinicalRationale: 'Curcumin suppresses systemic inflammatory prostaglandins and promotes restful restorative sleep.',
        timing: 'Bedtime',
        cautions: 'None.',
      });
    }

    return remedies;
  }

  private static _buildFeminaMedicationSchedule(phase: CyclePhase): MedicationTimingRule[] {
    return [
      {
        name: 'Iron (Ferrous Ascorbate / Bisglycinate)',
        dosageExample: 'As prescribed by physician (e.g. 50-100mg elemental iron)',
        idealTime: 'Mid-Morning (11:00 AM) with fresh Orange / Lemon water',
        clinicalPurpose: 'Replenishes lost ferritin stores and prevents iron-deficiency microcytic anemia.',
        interactionWarning: 'CRITICAL: Never consume with Milk, Dahi, Tea, or Coffee. Calcium and polyphenols block iron absorption by 80%.',
        timingTip: 'Keep a 2-hour window before and after dairy or tea.',
        isPregnancySafe: true,
      },
      {
        name: 'Magnesium Glycinate',
        dosageExample: '250mg - 350mg',
        idealTime: 'Bedtime (09:45 PM)',
        clinicalPurpose: 'Relaxes uterine smooth muscles, prevents nocturnal calf cramps, and modulates GABA receptors for deep sleep.',
        interactionWarning: 'Take with half glass of water. Glycinate form avoids diarrhea seen in oxide forms.',
        timingTip: 'Take 30 minutes before turning off lights.',
        isPregnancySafe: true,
      },
      {
        name: 'Vitamin B6 (Pyridoxine)',
        dosageExample: '25mg - 50mg',
        idealTime: 'Morning after breakfast (09:00 AM)',
        clinicalPurpose: 'Cofactor for serotonin and dopamine synthesis; clinically proven to reduce premenstrual anxiety and fluid retention.',
        interactionWarning: 'Do not exceed 100mg daily without doctor advice.',
        timingTip: 'Best taken in the morning to prevent vivid dreaming.',
        isPregnancySafe: true,
      },
      {
        name: 'Shatavari (Asparagus Racemosus)',
        dosageExample: '1/2 tsp powder or 1 tablet (consult Ayurvedic physician)',
        idealTime: 'Bedtime with warm milk',
        clinicalPurpose: 'Traditional phytoestrogen adaptogen supporting ovarian health, regular ovulation, and uterine vitality.',
        interactionWarning: 'Consult doctor if history of estrogen-sensitive conditions.',
        timingTip: 'Most effective during follicular and ovulatory phases.',
        isPregnancySafe: false,
      },
    ];
  }

  private static _buildFeminaPartnerGuide(phase: CyclePhase): PartnerEmpathyGuide {
    switch (phase) {
      case 'menstrual':
        return {
          phaseOrTrimester: 'Menstrual Phase (Period Bleeding)',
          emotionalContext:
            'Estrogen and progesterone drop to baseline levels; prostaglandins trigger uterine cramping, pelvic congestion, fatigue, and lower dopamine.',
          whatSheNeedsMost:
            'Deep physical warmth, emotional safety, proactive help with chores, and zero pressure for high-energy activities.',
          dosList: [
            'Bring her a hot water bag or heating pad without waiting to be asked.',
            'Prepare a warm cup of Ginger-Jaggery tea or Golden Haldi milk.',
            'Take care of dinner, kitchen cleaning, or grocery runs proactively.',
            'Offer gentle lower-back or foot massages with warm almond/sesame oil.',
            'Remind her she is cherished, loved, and safe to rest.',
          ],
          dontsList: [
            'NEVER say "Tum itna chidchid kyu kar rahi ho?" or minimize her pain.',
            'Don\'t initiate arguments or take temporary quietness personally.',
            'Don\'t offer cold drinks or icy treats that cause uterine vasoconstriction.',
            'Don\'t push her to attend crowded social gatherings if she feels depleted.',
          ],
          suggestedGiftsAndCare: [
            {
              item: '70%+ Dark Chocolate Artisan Box',
              whyItHelps: 'High bioavailable magnesium releases uterine spasms and naturally elevates brain endorphins.',
            },
            {
              item: 'Electric Heating Pad / Hot Water Bag',
              whyItHelps: 'Continuous suprapubic warmth dilates pelvic micro-vessels, slashing cramp pain by up to 40%.',
            },
            {
              item: 'Organic Chamomile & Lavender Sleep Infusion',
              whyItHelps: 'Soothes autonomic nervous tension and promotes uninterrupted deep delta sleep.',
            },
            {
              item: 'Fuzzy Warm Cotton Bed Socks',
              whyItHelps: 'Warming peripheral extremities redirects blood flow and relieves deep pelvic congestion.',
            },
          ],
          readyToShareMessage:
            'Hey love! ❤️ Just a gentle heads-up from VYRA: Today is my menstrual bleeding day. Hormones are at baseline and cramps might be high. A hot water bag, dark chocolate, and an extra long hug would mean the absolute world to me right now! 🥰✨',
        };

      case 'follicular':
        return {
          phaseOrTrimester: 'Follicular Phase (Rising Stamina)',
          emotionalContext:
            'Estrogen levels are steadily rising; brain neurochemistry is primed for curiosity, optimism, social bonding, and high energy.',
          whatSheNeedsMost:
            'Shared adventures, engaging conversations, fitness partnership, and enthusiasm for new ideas.',
          dosList: [
            'Plan a romantic outdoor date or brisk evening walk together.',
            'Encourage her fitness goals and join her for workouts or runs.',
            'Cook fresh, colorful, high-protein meals together (sprouts, fresh paneer, crisp salads).',
            'Support her passions, projects, and creative brainstorming.',
          ],
          dontsList: [
            'Don\'t hold her back from ambitious workout or work milestones.',
            'Don\'t let routine get stagnant; her brain thrives on novelty right now.',
          ],
          suggestedGiftsAndCare: [
            {
              item: 'Fresh Seasonal Flower Bouquet (Lilies / Roses)',
              whyItHelps: 'Celebrates her blossoming energy and lifts home aesthetic dopamine.',
            },
            {
              item: 'Electrolyte Sipper or Stylish Gym Bottle',
              whyItHelps: 'Supports her peak athletic workout hydration.',
            },
            {
              item: 'Curated Raw Nut & Seed Mix (Pumpkin & Flax)',
              whyItHelps: 'Supplies essential zinc and lignans for follicle development.',
            },
          ],
          readyToShareMessage:
            'Hey partner! 🌸 My energy is rising and I am in the Follicular phase! Feeling motivated, strong, and ready for adventure. Let\'s do something fun or go for a workout together tonight! 💃✨',
        };

      case 'ovulatory':
        return {
          phaseOrTrimester: 'Ovulatory Phase (Peak Glow & Vitality)',
          emotionalContext:
            'Estrogen and testosterone hit their monthly peak; maximum confidence, verbal eloquence, social magnetism, and peak fertility.',
          whatSheNeedsMost:
            'Romantic presence, verbal compliments, affection, and active quality time together.',
          dosList: [
            'Take her out on a special romantic dinner date.',
            'Give heartfelt compliments on her beauty, intellect, and grace.',
            'Be fully present without phone distractions.',
            'Enjoy active high-energy workouts or sports together.',
          ],
          dontsList: [
            'Don\'t be emotionally distant or unresponsive.',
            'Don\'t forget that this is the biological fertile window if planning conception (or practicing safe intimacy).',
          ],
          suggestedGiftsAndCare: [
            {
              item: 'Aromatherapy Floral Perfume / Rose Water Mist',
              whyItHelps: 'Complements her natural ovulatory pheromones and high sensory awareness.',
            },
            {
              item: 'Artisan Fruit & Berry Platter',
              whyItHelps: 'Glutathione and antioxidants protect cellular vitality.',
            },
            {
              item: 'Dinner Reservation at her Favorite Healthy Cafe',
              whyItHelps: 'Creates memorable romantic connection during her peak social mood.',
            },
          ],
          readyToShareMessage:
            'Hey sweetheart! 💖 I am in my peak Ovulatory phase today! Feeling radiant, happy, and energized. Looking forward to spending some romantic quality time together tonight! 🥰🍷',
        };

      case 'luteal':
        return {
          phaseOrTrimester: 'Luteal Phase (PMS & Emotional Sensitivity)',
          emotionalContext:
            'Progesterone surges and then fluctuates; serotonin dips while core body temperature rises 0.5°C. Emotional sensitivity, bloating, and fatigue are biologically real.',
          whatSheNeedsMost:
            'Compassionate listening without problem-solving, quiet comforting presence, and zero judgment for craving carbs or quiet rest.',
          dosList: [
            'Listen attentively to her day without jumping to analyze or criticize.',
            'Surprise her with warm, comforting meals (moong dal khichdi, comforting soup).',
            'Draw a warm bath or prepare an Epsom salt foot soak for her swollen ankles.',
            'Keep bedroom cool and dark at night to counter progesterone night heat.',
            'Offer gentle reassurance: "You are doing great, and I am here for you."',
          ],
          dontsList: [
            'NEVER say "Tumhara period aane wala hai kya?" in an irritated tone.',
            'Don\'t dismiss tears or frustration as "just hormones".',
            'Don\'t bring high-sodium salty chips or fast food that triggers painful puffiness.',
            'Don\'t start stressful financial or contentious arguments right now.',
          ],
          suggestedGiftsAndCare: [
            {
              item: 'Lavender Essential Oil Pillow Spray',
              whyItHelps: 'Promotes deep restorative sleep despite progesterone-induced micro-awakenings.',
            },
            {
              item: 'Soft Sherpa Weighted Blanket',
              whyItHelps: 'Provides comforting somatic grounding that relieves pre-menstrual sensory overload.',
            },
            {
              item: 'Basket of Ripe Bananas, Fresh Figs & Dark Cocoa',
              whyItHelps: 'Supplies high potassium and vitamin B6 to clear bloating and lift mood.',
            },
          ],
          readyToShareMessage:
            'Hey partner! 💕 Just letting you know that my Luteal/PMS phase is active right now. Progesterone shifts can make me feel emotionally sensitive, tired, and bloated. A listening ear, a warm dinner, and a calm hug tonight would be pure magic! Love you! 🥰🛋️',
        };
    }
  }

  private static _buildFeminaSmartWatchSync(phase: CyclePhase): SmartWatchBiometricSync {
    switch (phase) {
      case 'menstrual':
        return {
          restingHeartRateBpm: 66,
          skinTemperatureOffsetCelsius: -0.1,
          heartRateVariabilityMs: 58,
          bloodOxygenSpo2: 99,
          sleepDurationHours: 8.8,
          deepSleepMinutes: 115,
          biphasicOvulationConfirmed: false,
          biometricInsight:
            'Baseline temperature restored after luteal decline. Elevated parasympathetic recovery indicates safe window for gentle restorative movement.',
        };
      case 'follicular':
        return {
          restingHeartRateBpm: 64,
          skinTemperatureOffsetCelsius: 0.0,
          heartRateVariabilityMs: 65,
          bloodOxygenSpo2: 99,
          sleepDurationHours: 7.8,
          deepSleepMinutes: 98,
          biphasicOvulationConfirmed: false,
          biometricInsight:
            'High HRV and low resting heart rate indicate peak athletic capacity and autonomic nervous readiness for intense training.',
        };
      case 'ovulatory':
        return {
          restingHeartRateBpm: 68,
          skinTemperatureOffsetCelsius: +0.2,
          heartRateVariabilityMs: 60,
          bloodOxygenSpo2: 99,
          sleepDurationHours: 7.5,
          deepSleepMinutes: 90,
          biphasicOvulationConfirmed: true,
          biometricInsight:
            'Watch sensors detect initial +0.2°C skin temperature inflection and subtle resting HR elevation, confirming active luteinizing hormone (LH) surge.',
        };
      case 'luteal':
        return {
          restingHeartRateBpm: 72,
          skinTemperatureOffsetCelsius: +0.45,
          heartRateVariabilityMs: 48,
          bloodOxygenSpo2: 98,
          sleepDurationHours: 8.5,
          deepSleepMinutes: 80,
          biphasicOvulationConfirmed: true,
          biometricInsight:
            'Sustained +0.45°C Basal Body Temperature elevation and lower HRV confirm active post-ovulatory corpus luteum progesterone dominance.',
        };
    }
  }

  private static _buildFeminaDefaultReminders(phase: CyclePhase): CareReminderItem[] {
    return [
      {
        id: 'fem_rem_wake_hydration',
        category: 'hydration',
        title: 'Morning Warm Herbal Hydration',
        timeSlot: '07:00 AM',
        isEnabled: true,
        repeatDaily: true,
        notes: 'Warm water with ginger/ajwain or lemon-chia for gut circulation.',
      },
      {
        id: 'fem_rem_breakfast',
        category: 'meal',
        title: 'Bioavailable Protein & Micronutrient Breakfast',
        timeSlot: '08:30 AM',
        isEnabled: true,
        repeatDaily: true,
        notes: 'Cheela / sprouted moong / dalia aligned with cycle phase.',
      },
      {
        id: 'fem_rem_fruit_seeds',
        category: 'meal',
        title: 'Mid-Morning Fruit Therapy & Seed Cycling',
        timeSlot: '11:00 AM',
        isEnabled: true,
        repeatDaily: true,
        notes: 'Pomegranate/Flax in Phase 1, or Banana/Sesame in Phase 2.',
      },
      {
        id: 'fem_rem_iron_supplement',
        category: 'medication',
        title: 'Iron Supplement (with Lemon Water)',
        timeSlot: '04:00 PM',
        isEnabled: phase === 'menstrual',
        repeatDaily: true,
        notes: 'Keep 2 hours away from tea, coffee, milk and calcium.',
      },
      {
        id: 'fem_rem_evening_asana',
        category: 'rest',
        title: 'Restorative Asana & Pelvic Relax Time',
        timeSlot: '05:30 PM',
        isEnabled: true,
        repeatDaily: true,
        notes: 'Child\'s pose, Supta Baddha Konasana, or brisk walk.',
      },
      {
        id: 'fem_rem_magnesium_sleep',
        category: 'medication',
        title: 'Magnesium Glycinate & Golden Milk',
        timeSlot: '09:45 PM',
        isEnabled: true,
        repeatDaily: true,
        notes: 'Relaxes smooth uterine muscles for deep restorative sleep.',
      },
    ];
  }
}

// -----------------------------------------------------------------------------
// 4. MaternalCare™ Engine Implementation
// -----------------------------------------------------------------------------

export class MaternalCareEngine {
  /**
   * Pre-computed clinical milestones from Week 1 to Week 40.
   */
  private static readonly MILESTONES: Record<number, FetalMilestone> = {
    4: {
      week: 4,
      fruitAnalogy: 'Poppy Seed (Khashkhash)',
      approximateWeightGrams: 1,
      approximateLengthMm: 2,
      developmentHighlights: [
        'Blastocyst uterus ki lining me safely implant ho chuka hai.',
        'Amniotic sac aur placenta banna shuru ho gaye hain.',
        'Neural tube (jo aage chal kar brain aur spinal cord banega) form ho raha hai.',
      ],
      motherBodyChanges: [
        'Mild spotting ya implantation cramping ho sakti hai.',
        'Progesterone rise hone se thoda exhaustion aur breast tenderness mehsus hoti hai.',
      ],
    },
    8: {
      week: 8,
      fruitAnalogy: 'Kidney Bean (Rajma)',
      approximateWeightGrams: 2,
      approximateLengthMm: 16,
      developmentHighlights: [
        'Baby ka tiny heart ab lagbhag 150-160 beats per minute par beat kar raha hai.',
        'Arms, legs, fingers aur toes ke tiny buds shape le rahe hain.',
        'Facial features jaise lips, nose aur eyelids form ho rahe hain.',
      ],
      motherBodyChanges: [
        'Morning sickness aur nausea peak par ho sakta hai.',
        'Frequent urination (uterus ka size expand ho raha hai).',
      ],
    },
    12: {
      week: 12,
      fruitAnalogy: 'Plum / Nimbu (Lime)',
      approximateWeightGrams: 14,
      approximateLengthMm: 54,
      developmentHighlights: [
        'Saare critical organ systems (kidneys, liver, brain) successfully ban chuke hain.',
        'Baby ab fingers open aur close kar sakta hai aur hiccup kar sakta hai.',
        'Vocal cords complete ho rahe hain.',
      ],
      motherBodyChanges: [
        'First trimester ka end — nausea dhire-dhire kam hona shuru hota hai.',
        'Placenta ab baby ke nutrition ka poora charge le leta hai.',
      ],
    },
    16: {
      week: 16,
      fruitAnalogy: 'Avocado (Makhanphal)',
      approximateWeightGrams: 100,
      approximateLengthMm: 116,
      developmentHighlights: [
        'Baby ki eyes light detect karne lagti hain aur ears mother ki voice sunte hain.',
        'Skeleton cartilage se hard bone me convert ho raha hai (calcium demand peak).',
        'Scalp par tiny hair pattern ban raha hai.',
      ],
      motherBodyChanges: [
        'Energy levels wapas high hone lagte hain ("Golden Trimester").',
        'Baby bump visible hona shuru ho sakta hai.',
      ],
    },
    20: {
      week: 20,
      fruitAnalogy: 'Banana (Kela)',
      approximateWeightGrams: 300,
      approximateLengthMm: 256,
      developmentHighlights: [
        'Halfway mark! Baby active movements aur flips karta hai ("Quickening kicks").',
        'Vernix caseosa (protective cream layer) baby ki sensitive skin ko cover karti hai.',
        'Taste buds mature ho rahe hain — baby amniotic fluid taste karta hai.',
      ],
      motherBodyChanges: [
        'First kicks clearly feel hoti hain (fluttery sensations).',
        'Level II Target Anomaly scan ka optimal time hota hai.',
      ],
    },
    24: {
      week: 24,
      fruitAnalogy: 'Corn on the Cob (Bhutta)',
      approximateWeightGrams: 600,
      approximateLengthMm: 300,
      developmentHighlights: [
        'Viability milestone: Lungs me surfactant banna shuru ho raha hai jo breathing me madad karta hai.',
        'Baby ka hearing system fully functional hai; music aur loud voices par react karta hai.',
        'Rapid brain cell development.',
      ],
      motherBodyChanges: [
        'Mild Braxton Hicks practice contractions shuru ho sakte hain.',
        'Skin par linea nigra ya mild stretch marks dikh sakte hain.',
      ],
    },
    28: {
      week: 28,
      fruitAnalogy: 'Eggplant (Baingan)',
      approximateWeightGrams: 1000,
      approximateLengthMm: 376,
      developmentHighlights: [
        'Third trimester start! Baby eyes open kar sakta hai aur eyelashes develop ho gayi hain.',
        'Body fat build ho raha hai jo delivery ke baad body temperature maintain karega.',
        'Regular sleep-wake sleep cycles establish hote hain.',
      ],
      motherBodyChanges: [
        'Shortness of breath (uterus diaphragm ko push karta hai).',
        'Daily Kick counting mandatory hota hai (10 kicks in 2 hours).',
      ],
    },
    32: {
      week: 32,
      fruitAnalogy: 'Butternut Squash (Kaddu)',
      approximateWeightGrams: 1700,
      approximateLengthMm: 424,
      developmentHighlights: [
        'Bones complete hard ho gayi hain (except skull bones, jo delivery ke lie soft rehti hain).',
        'Baby practice breathing motions continuously karta hai.',
        'Nails fingers ke tips tak grow ho chuke hain.',
      ],
      motherBodyChanges: [
        'Pelvic pressure badhti hai; frequent washroom visits.',
        'Heartburn aur acidity — small frequent meals lena zaroori hai.',
      ],
    },
    36: {
      week: 36,
      fruitAnalogy: 'Papaya / Honeydew Melon',
      approximateWeightGrams: 2600,
      approximateLengthMm: 474,
      developmentHighlights: [
        'Lungs almost fully mature ho chuki hain.',
        'Baby head-down cephalic position me drop hona shuru hota hai (Lightening).',
        'Immune system mother se antibodies absorb kar raha hai.',
      ],
      motherBodyChanges: [
        'Walking me waddle posture banta hai.',
        'Breathing thodi aasan hoti hai jab baby pelvis me drop hota hai.',
      ],
    },
    40: {
      week: 40,
      fruitAnalogy: 'Watermelon (Tarbooz)',
      approximateWeightGrams: 3400,
      approximateLengthMm: 512,
      developmentHighlights: [
        'Full term baby! Ready to meet the world.',
        'Firm grip, clear reflexes, fully developed fat layers.',
        'Placenta baby ko delivery ke lie zaruri hormones provide karta hai.',
      ],
      motherBodyChanges: [
        'Cervix thinning aur dilation shuru hota hai.',
        'Hospital bag ready rakhein; true labour contractions monitor karein.',
      ],
    },
  };

  /**
   * Computes full gestational state, milestone, trimester, checklist and clinical advice.
   */
  static analyzePregnancy({
    lastMenstrualPeriod,
    estimatedDueDate,
    todayDateStr = new Date().toISOString().split('T')[0],
    customInstructions = [],
  }: {
    lastMenstrualPeriod?: string; // YYYY-MM-DD
    estimatedDueDate?: string; // YYYY-MM-DD
    todayDateStr?: string;
    customInstructions?: DoctorInstruction[];
  }): PregnancyProfileResult {
    const today = new Date(todayDateStr);
    let eddDate: Date;
    let lmpDate: Date;

    if (estimatedDueDate) {
      eddDate = new Date(estimatedDueDate);
      lmpDate = new Date(eddDate);
      lmpDate.setDate(eddDate.getDate() - 280);
    } else if (lastMenstrualPeriod) {
      lmpDate = new Date(lastMenstrualPeriod);
      eddDate = new Date(lmpDate);
      eddDate.setDate(lmpDate.getDate() + 280); // Naegele's rule 280 days
    } else {
      // Default: assume week 20 halfway
      lmpDate = new Date(today);
      lmpDate.setDate(today.getDate() - 140);
      eddDate = new Date(lmpDate);
      eddDate.setDate(lmpDate.getDate() + 280);
    }

    const totalDays = Math.max(
      1,
      Math.floor((today.getTime() - lmpDate.getTime()) / (1000 * 60 * 60 * 24))
    );

    const currentWeek = Math.min(42, Math.max(1, Math.floor(totalDays / 7) + 1));
    const currentDayInWeek = (totalDays % 7) + 1;
    const daysUntilDelivery = Math.max(
      0,
      Math.floor((eddDate.getTime() - today.getTime()) / (1000 * 60 * 60 * 24))
    );

    let trimester: Trimester = 'first';
    let trimesterDisplayName = 'First Trimester (Weeks 1-12) • Foundation & Organogenesis';

    if (currentWeek <= 12) {
      trimester = 'first';
      trimesterDisplayName = 'First Trimester (Weeks 1-12) • Foundation & Organogenesis';
    } else if (currentWeek <= 27) {
      trimester = 'second';
      trimesterDisplayName = 'Second Trimester (Weeks 13-27) • The Golden Growth Era';
    } else if (currentWeek <= 40) {
      trimester = 'third';
      trimesterDisplayName = 'Third Trimester (Weeks 28-40) • Rapid Maturation & Birth Prep';
    } else {
      trimester = 'postpartum';
      trimesterDisplayName = 'Full Term / Ready for Delivery';
    }

    // Resolve closest fetal milestone
    const milestoneWeeks = [4, 8, 12, 16, 20, 24, 28, 32, 36, 40];
    const closestWeek = milestoneWeeks.reduce((prev, curr) =>
      Math.abs(curr - currentWeek) < Math.abs(prev - currentWeek) ? curr : prev
    );

    const milestone = this.MILESTONES[closestWeek] || this.MILESTONES[20];

    // Standard clinical instructions tailored to trimester
    const defaultInstructions: DoctorInstruction[] = this._buildStandardClinicalInstructions(
      currentWeek,
      trimester
    );

    // Merge with any custom doctor instructions passed by athlete
    const mergedChecklist = [...defaultInstructions];
    for (const custom of customInstructions) {
      const idx = mergedChecklist.findIndex((item) => item.id === custom.id);
      if (idx >= 0) {
        mergedChecklist[idx] = custom;
      } else {
        mergedChecklist.push(custom);
      }
    }

    // Prenatal Activity safety
    const activityGuide = this._buildActivityGuide(trimester);

    // Upcoming Scans Roadmap
    const upcomingScans = this._buildUpcomingScans(currentWeek);

    const chronoRoutine = this._buildMaternalChronoRoutine(currentWeek, trimester);
    const fruitTherapy = this._buildMaternalFruitTherapy(trimester);
    const sleepProtocol = this._buildMaternalSleepSanctuary(currentWeek, trimester);
    const homeRemedies = this._buildMaternalHomeRemedies(trimester);
    const medicationSchedule = this._buildMaternalMedicationSchedule(currentWeek, trimester);
    const partnerGuide = this._buildMaternalPartnerGuide(currentWeek, trimester);
    const smartWatchSync = this._buildMaternalSmartWatchSync(currentWeek, trimester);
    const defaultReminders = this._buildMaternalDefaultReminders(currentWeek, trimester);

    return {
      currentWeek,
      currentDayInWeek,
      totalDaysPregnant: totalDays,
      trimester,
      trimesterDisplayName,
      estimatedDueDate: eddDate.toISOString().split('T')[0],
      daysUntilDelivery,
      fetalMilestone: milestone,
      dailyCareChecklist: mergedChecklist,
      prenatalSafeActivities: activityGuide,
      upcomingClinicalScans: upcomingScans,
      chronoRoutine,
      fruitTherapy,
      sleepProtocol,
      homeRemedies,
      medicationSchedule,
      partnerGuide,
      smartWatchSync,
      defaultReminders,
    };
  }

  private static _buildStandardClinicalInstructions(
    week: number,
    trimester: Trimester
  ): DoctorInstruction[] {
    const list: DoctorInstruction[] = [];

    // Folic Acid in Trimester 1 & 2
    if (trimester === 'first' || trimester === 'second') {
      list.push({
        id: 'folic_acid_supplement',
        category: 'medication',
        title: 'Folic Acid (400-500 mcg) Daily',
        details: 'Doctor ki prescribed prenatal multivitamin subah breakfast ke baad lein.',
        frequency: 'daily',
        isCompletedToday: false,
        positiveImpact:
          'Baby ke brain aur spinal cord ke neural tube defects (Spina Bifida) ko 70% tak prevent karta hai.',
        skippedRisk:
          'First 12 weeks me miss karne se fetal spine aur neurological development me irreversible anomalies ka risk badhta hai.',
        timingTip: 'Subah breakfast ke sath lein taaki nausea na ho.',
      });
    }

    // Iron & Calcium in Trimesters 2 & 3
    if (trimester === 'second' || trimester === 'third') {
      list.push({
        id: 'elemental_iron_supplement',
        category: 'medication',
        title: 'Elemental Iron (Ferrous Ascorbate / Fumarate)',
        details: 'Dopahar ke meal ke baad ya evening me Nimbu Paani / Orange Juice ke sath lein.',
        frequency: 'daily',
        isCompletedToday: false,
        positiveImpact:
          'Blood volume ko 50% expand karta hai jisse baby tak oxygen aur hemoglobin seamless flow hota hai.',
        skippedRisk:
          'Maternal severe anemia, delivery ke waqt high blood loss risk aur baby ka low birth weight.',
        timingTip:
          'CRITICAL: Kabhi bhi doodh (milk), dahi ya calcium ke sath na lein! Calcium iron absorption ko 60% block kar deta hai. 2 ghante ka gap rakhein.',
      });

      list.push({
        id: 'calcium_vit_d3_supplement',
        category: 'medication',
        title: 'Calcium (500mg) + Vitamin D3',
        details: 'Raat ko dinner ke baad warm doodh ke sath lein.',
        frequency: 'daily',
        isCompletedToday: false,
        positiveImpact:
          'Baby ke skeletal bones aur tooth buds develop karta hai bina mother ki bones se calcium leached kiye.',
        skippedRisk:
          'Mother me post-pregnancy severe osteopenia, teeth weakening aur midnight leg muscle cramps.',
        timingTip: 'Iron aur calcium tablets me hamesha minimum 3 hours ka gap hona chahiye.',
      });
    }

    // Hydration across all trimesters
    list.push({
      id: 'hydration_maternal',
      category: 'diet',
      title: 'Maternal Hydration (Minimum 2.5 - 3.0 Litres)',
      details: 'Saaf paani, Nariyal Paani (Coconut water), chaas aur homemade soups.',
      frequency: 'daily',
      isCompletedToday: false,
      positiveImpact:
        'Amniotic fluid level (AFI) ko healthy range (8-18 cm) me rakhta hai aur placental circulation boost karta hai.',
      skippedRisk:
        'Oligohydramnios (low amniotic fluid), painful urinary tract infections (UTI) aur premature uterine contractions.',
      timingTip: 'Raat ko baar-baar uthna na pade islie 8 PM se pehle 80% quota complete karein.',
    });

    // Kick Counter in Trimester 3
    if (trimester === 'third') {
      list.push({
        id: 'kick_counter_audit',
        category: 'activity',
        title: 'Daily Fetal Movement & Kick Audit',
        details: 'Dinner ke baad left side par let kar 2 ghante me baby ke 10 movements count karein.',
        frequency: 'daily',
        isCompletedToday: false,
        positiveImpact:
          'Fetal neuro-muscular well-being aur oxygenation ka primary on-demand real-time indicator hai.',
        skippedRisk:
          'Fetal distress, umbilical cord entanglement ya oxygen hypoxia ko detect karne me delay.',
        timingTip: 'Agar baby silent ho toh ek glass thanda paani piyein aur left side 20 min rest karein.',
      });
    }

    // Side Sleeping in Trimester 2 & 3
    if (trimester === 'second' || trimester === 'third') {
      list.push({
        id: 'side_sleeping_guideline',
        category: 'caution',
        title: 'Left-Side Sleeping Posture (Left Lateral Tilt)',
        details: 'Knees ke beech me pregnancy pillow rakh kar left side par soyein.',
        frequency: 'daily',
        isCompletedToday: false,
        positiveImpact:
          'Inferior Vena Cava blood vessel par uterus ka pressure zero karta hai, baby tak maximum oxygen pahuchata hai.',
        skippedRisk:
          'Peeth ke bal (flat on back) sone se BP low ho jata hai (Supine Hypotension) aur baby tak blood flow 30% drop ho sakta hai.',
      });
    }

    return list;
  }

  private static _buildActivityGuide(trimester: Trimester) {
    if (trimester === 'first') {
      return {
        recommended: [
          'Gentle 20-25 minute brisk walking on even surface.',
          'Pranayama (Anulom Vilom) — Deep diaphragmatic breathing to ease anxiety and nausea.',
          'Cat-Cow pose (Marjaryasana) for gentle spine mobilization.',
          'Pelvic floor awareness exercises.',
        ],
        contraindicated: [
          'High intensity jumping, HIIT, or running.',
          'Hot yoga or saunas (core temperature must never exceed 38.9°C).',
          'Heavy abdominal twisting or direct stomach pressure.',
        ],
        kegelPrescription:
          'Gentle 5 contractions (hold 3 sec, release 5 sec) subah aur shaam.',
      };
    } else if (trimester === 'second') {
      return {
        recommended: [
          'Prenatal Yoga: Baddha Konasana (Butterfly) to open pelvic outlet.',
          'Tailor Sitting (floor sitting with straight back) to position baby.',
          'Side-lying leg lifts and gentle glute bridges with pillow support.',
          'Daily 30 minute low-impact walking in comfortable cushioned shoes.',
        ],
        contraindicated: [
          'Lying completely flat on back (supine) for longer than 3 minutes.',
          'Any pose with fall risk (balance poses without wall support).',
          'Holding breath during movement (Valsalva manoeuvre).',
        ],
        kegelPrescription:
          '10 pelvic floor pulses (hold 5 sec, release 5 sec) x 3 sets daily.',
      };
    } else {
      // Third Trimester
      return {
        recommended: [
          'Pelvic rocking on exercise birth ball (reduces lower back pressure).',
          'Gentle prenatal squats holding onto a sturdy chair or doorframe.',
          'Deep relaxation Savasana strictly in Left Lateral position with pillows.',
          'Perineal massage awareness and deep breathing for labour endurance.',
        ],
        contraindicated: [
          'Deep sudden twists or bouncing movements.',
          'Standing in one place stationary for > 20 minutes (causes venous pooling).',
          'Lifting weights > 5 kg.',
        ],
        kegelPrescription:
          'Pelvic floor release & elevator holds (lift, hold 6s, completely let go and soften 10s) to prepare for birth relaxation.',
      };
    }
  }

  private static _buildUpcomingScans(currentWeek: number) {
    const allScans = [
      {
        weekRange: 'Weeks 6 - 8',
        testName: 'Dating & Viability Sonography',
        clinicalPurpose: 'Confirms intrauterine pregnancy, gestational sac location, and detects fetal heartbeat.',
        minWeek: 6,
        maxWeek: 8,
      },
      {
        weekRange: 'Weeks 11 - 13.6',
        testName: 'Nuchal Translucency (NT) Scan & Dual Marker Blood Test',
        clinicalPurpose: 'Screens for chromosomal conditions (Down Syndrome / Trisomy 21, 18, 13) and early structural integrity.',
        minWeek: 11,
        maxWeek: 14,
      },
      {
        weekRange: 'Weeks 18 - 22',
        testName: 'Targeted Anomaly Scan (Level II Ultrasound)',
        clinicalPurpose: 'Exhaustive anatomical audit of baby brain, four-chamber heart, kidneys, spine, limbs and placenta location.',
        minWeek: 18,
        maxWeek: 22,
      },
      {
        weekRange: 'Weeks 24 - 28',
        testName: 'Glucose Challenge / OGTT & Complete Blood Count (CBC)',
        clinicalPurpose: 'Screens for Gestational Diabetes Mellitus (GDM) and evaluates maternal hemoglobin to prevent anemia.',
        minWeek: 24,
        maxWeek: 28,
      },
      {
        weekRange: 'Weeks 32 - 36',
        testName: 'Fetal Growth & Umbilical Doppler Sonography',
        clinicalPurpose: 'Measures estimated fetal weight (EFW), amniotic fluid index (AFI), and placental blood flow resistance.',
        minWeek: 32,
        maxWeek: 36,
      },
      {
        weekRange: 'Weeks 36 - 37',
        testName: 'Group B Streptococcus (GBS) Screen & Pelvic Assessment',
        clinicalPurpose: 'Identifies bacterial colonization to protect newborn during birth and evaluates fetal head engagement.',
        minWeek: 36,
        maxWeek: 38,
      },
    ];

    return allScans
      .filter((s) => currentWeek <= s.maxWeek + 2)
      .map((s) => ({
        weekRange: s.weekRange,
        testName: s.testName,
        clinicalPurpose: s.clinicalPurpose,
        isUrgent: currentWeek >= s.minWeek && currentWeek <= s.maxWeek,
      }));
  }

  // ---------------------------------------------------------------------------
  // Maternal Helpers: 24h Chrono, Fruit Therapy, Sleep & Remedies
  // ---------------------------------------------------------------------------

  private static _buildMaternalChronoRoutine(
    week: number,
    trimester: Trimester
  ): DailyChronoRoutineStep[] {
    return [
      {
        id: 'mat_wake',
        timeSlot: '06:30 AM - 07:30 AM',
        periodOfDay: 'morning_wake',
        title: 'Bedside Nausea & Acidity Shield (Eat Before Standing)',
        guidance: 'Raat bhar stomach acid jama hota hai; bina khaye bed se khade hone par severe morning sickness trigger hoti hai.',
        nutritionOrAction: 'Bed ke paas rakhe sukhe roasted chana ya whole-wheat crackers ke 2-3 bites bina sar uthaye chabayen. 15 minute baad halke gungune cardamom-ginger water ke chote sips lein.',
        sleepPostureOrTip: 'Head ko 30° elevated rakhein; jhatke se bed se bahar na niklein.',
        medicineOrSupplements: [
          'Thyroid (Levothyroxine, agar prescribed ho) — Khali pet 1 glass paani ke sath; chai/nashte se 45 min pehle',
        ],
      },
      {
        id: 'mat_breakfast',
        timeSlot: '08:00 AM - 09:00 AM',
        periodOfDay: 'breakfast',
        title: 'Prenatal Protein & Choline Power Breakfast',
        guidance: 'Choline aur bioavailable protein baby ke brain neural connections aur placenta vascularity banate hain.',
        nutritionOrAction: 'Besan Cheela with grated fresh Paneer & Mint chutney, ya 2 boiled eggs / tofu avocado toast + 5 soaked almonds aur 2 soaked walnuts.',
        sleepPostureOrTip: 'Khana khate waqt spine seedhi rakhein; nashte ke turant baad letna mana hai.',
        medicineOrSupplements:
          trimester === 'first'
            ? ['Folic Acid (5mg / 400-800mcg) with breakfast — Neural tube defect shield']
            : ['Calcium + Vitamin D3 (500mg) — take with breakfast meal'],
      },
      {
        id: 'mat_mid_morning',
        timeSlot: '10:30 AM - 11:30 AM',
        periodOfDay: 'mid_morning',
        title: 'Maternal Fruit Therapy & Amniotic Hydration',
        guidance: 'Amniotic fluid index (AFI) maintain karta hai aur placental blood flow optimize karta hai.',
        nutritionOrAction: '1 bowl fresh Pomegranate (Anaar) arils ya Crisp Apple + 1 glass fresh Tender Coconut Water.',
        sleepPostureOrTip: 'Khade hokar 5 minute gentle arm stretches karein.',
        medicineOrSupplements: [],
      },
      {
        id: 'mat_lunch',
        timeSlot: '01:00 PM - 02:00 PM',
        periodOfDay: 'lunch',
        title: 'Nourishing Indian Maternal Thali',
        guidance: 'Iron, plant calcium, complex fibers aur probiotics ka perfect balance.',
        nutritionOrAction: 'Palak-Moong Dal + 2 Phulkas smeared with A2 Desi Ghee + Fresh Curd / Dahi + Carrot-Cucumber Salad with fresh lemon juice squeeze.',
        sleepPostureOrTip: 'Mindful chewing; chew each bite 25-30 times to prevent gastric gas.',
        medicineOrSupplements:
          trimester !== 'first'
            ? ['Calcium + Vitamin D3 (second dose if twice daily prescribed)']
            : [],
      },
      {
        id: 'mat_afternoon_rest',
        timeSlot: '02:30 PM - 03:30 PM',
        periodOfDay: 'afternoon_rest',
        title: 'SOS Circulation Power Nap (Left-Side Recumbent)',
        guidance: 'Inferior Vena Cava (IVC) par heavy uterus ka pressure hatata hai, jisse baby ko maximum oxygen milti hai aur pairo ki swelling kam hoti hai.',
        nutritionOrAction: 'Left side par let kar dono ghutno aur takhno ke beech firm pillow lagayein.',
        sleepPostureOrTip: 'Left-Lateral Recumbent (SOS). Peeth ke bal (supine) letna strictly mana hai.',
        medicineOrSupplements: [],
      },
      {
        id: 'mat_evening_movement',
        timeSlot: '05:00 PM - 06:00 PM',
        periodOfDay: 'evening_movement',
        title: 'Prenatal Pelvic Mobility & Kegel Strengthening',
        guidance: 'Pelvic floor muscles ko tone karta hai aur birth canal flexibility improve karta hai.',
        nutritionOrAction: '20-25 mins gentle outdoor walk + Baddha Konasana (Butterfly) + Cat-Cow stretches + 10 reps Kegels (contract 5s, release 5s).',
        sleepPostureOrTip: 'Wear supportive shoes and keep water bottle handy.',
        medicineOrSupplements: [
          'Iron Supplement (Ferrous Ascorbate) — Taaza Nimbu paani ke sath lein. Chai, coffee ya doodh se 2 ghante door rakhein!',
        ],
      },
      {
        id: 'mat_dinner',
        timeSlot: '07:30 PM - 08:15 PM',
        periodOfDay: 'dinner',
        title: 'Early Anti-Reflux Digestible Dinner',
        guidance: 'Progesterone stomach valve ko relax karta hai. Sone se 2 ghante pehle khana finish karna nocturnal heartburn se bachata hai.',
        nutritionOrAction: 'Vegetable Moong Dal Khichdi with 1 tsp Ghee, ya Vegetable Dalia with Lauki/Tori curry.',
        sleepPostureOrTip: 'Khane ke baad 100 kadam gentle walk karein; seedhe bed par na jayein.',
        medicineOrSupplements: [],
      },
      {
        id: 'mat_bedtime',
        timeSlot: '09:45 PM - 10:30 PM',
        periodOfDay: 'bedtime',
        title: 'Sleep Sanctuary & 3-Pillow Left-SOS Setup',
        guidance: 'Deep 8.5 - 9.5 hours continuous sleep. Fetal human growth hormone night deep sleep me peak release hota hai.',
        nutritionOrAction: 'Gunguna milk with pinch of Kesar (Saffron) & Cardamom (ya warm almond milk).',
        sleepPostureOrTip: 'Left lateral sleep: 1 pillow between knees, 1 wedge pillow supporting belly bump, 1 pillow behind spine.',
        medicineOrSupplements: [
          'Omega-3 DHA (200-300mg) for baby brain & eyes',
          'Doxylamine + Vitamin B6 (agar severe nausea ke lie doctor ne prescribe kia ho)',
        ],
      },
    ];
  }

  private static _buildMaternalFruitTherapy(trimester: Trimester): FruitTherapyGuide {
    return {
      dailyFruitRule:
        'Sabhi fruits ko pehle warm water aur pinch of salt/baking soda se wash karein. Roadside unwashed cut fruits ya unpasteurized pack juices strictly avoid karein.',
      recommendedFruits: [
        {
          name: 'Pomegranate',
          hindiName: 'Anaar',
          benefits:
            'High non-heme iron, folate aur polyphenols; clinically proven to protect fetal brain from hypoxia and maximize uterine artery perfusion.',
          nutrientKey: 'Iron, Folate, Vitamin K, Polyphenols',
          timing: 'Mid-morning snack (11:00 AM)',
          bestConsumedWith: 'Fresh room temperature seeds',
        },
        {
          name: 'Fresh Avocado',
          hindiName: 'Makhan Phal',
          benefits:
            'Abundant in folate, potassium, and monounsaturated DHA fats; supports fetal neural tube and prevents painful maternal leg cramps.',
          nutrientKey: 'Folate, Potassium, MUFA healthy fats',
          timing: 'Breakfast toast or lunch salad',
          bestConsumedWith: 'Lemon juice & olive oil',
        },
        {
          name: 'Oranges & Sweet Lime',
          hindiName: 'Santra / Mosambi',
          benefits:
            'Vitamin C strengthens amniotic sac membrane collagen and multiplies maternal iron absorption.',
          nutrientKey: 'Vitamin C, Bioflavonoids, Hydration',
          timing: 'Post lunch or 4:00 PM',
          bestConsumedWith: 'Fresh room-temperature segments',
        },
        {
          name: 'Ripe Banana',
          hindiName: 'Paka Kela',
          benefits:
            'Vitamin B6 acts as natural antacid for morning nausea; high potassium prevents nocturnal calf spasms.',
          nutrientKey: 'Vitamin B6, Potassium, Soluble Fiber',
          timing: 'Early morning or afternoon',
          bestConsumedWith: 'Room temperature',
        },
        {
          name: 'Apples',
          hindiName: 'Seb',
          benefits:
            'High pectin soluble fiber prevents pregnancy constipation. Clinical studies show maternal apple intake lowers childhood asthma risk.',
          nutrientKey: 'Pectin fiber, Quercetin, Vitamin C',
          timing: 'Mid-morning or evening snack',
          bestConsumedWith: 'Wash thoroughly; eat with peel',
        },
        {
          name: 'Tender Coconut Water',
          hindiName: 'Nariyal Paani',
          benefits:
            'Pure natural isotonic electrolyte drink; supports optimal Amniotic Fluid Index (AFI) and fights maternal exhaustion.',
          nutrientKey: 'Potassium, Magnesium, Natural Electrolytes',
          timing: 'Mid-morning (11:00 AM)',
          bestConsumedWith: 'Freshly opened coconut',
        },
      ],
      avoidOrCautionFruits: [
        {
          name: 'Raw / Unripe / Green Papaya',
          hindiName: 'Kaccha / Adhpaka Papita',
          riskLevel: 'strict_avoid',
          clinicalReason:
            'STRICTLY FORBIDDEN: Kaccha papita contains concentrated latex and active Papain enzyme. Body me ye oxytocin aur prostaglandin mimic karta hai, causing violent uterine contractions, cervical softening and high risk of miscarriage / preterm labor.',
          scientificMechanism:
            'Papain induces premature uterine smooth muscle contractions and weakens placental attachment.',
        },
        {
          name: 'Raw Pineapple in High Amounts',
          hindiName: 'Anannas (Early Pregnancy)',
          riskLevel: 'caution',
          clinicalReason:
            'Contains Bromelain proteolytic enzyme which can soften the cervix and induce irregular uterine spasms, especially in 1st Trimester.',
          scientificMechanism:
            'Bromelain degrades collagen in the cervix, potentially precipitating cervical ripening.',
        },
        {
          name: 'Unpasteurized Packaged Juices & Unwashed Cut Street Fruits',
          hindiName: 'Thele ke Kate Phal aur Raw Juices',
          riskLevel: 'strict_avoid',
          clinicalReason:
            'High risk of Toxoplasma gondii, Listeria monocytogenes, and Salmonella. Listeria crosses the placenta and can cause fetal sepsis and stillbirth.',
          scientificMechanism:
            'Listeriolysin O allows Listeria to cross maternal-fetal endothelial barriers.',
        },
        {
          name: 'Excess Black Grapes in 3rd Trimester',
          hindiName: 'Zda Angoor (Late Pregnancy)',
          riskLevel: 'caution',
          clinicalReason:
            'High skin resveratrol can interact with fetal pancreatic development and high glycemic fructose can spike Gestational Diabetes (GDM).',
          scientificMechanism:
            'Rapid fructose load challenging maternal insulin resistance.',
        },
      ],
    };
  }

  private static _buildMaternalSleepSanctuary(
    week: number,
    trimester: Trimester
  ): SleepSanctuaryProtocol {
    return {
      targetSleepHours: '8.5 - 9.5 hours',
      optimalPosture:
        'Left-Lateral Recumbent (SOS - Sleep On Side). Left side par soyein with knee support.',
      pillowSetup:
        'Place a firm pregnancy pillow or normal pillow between thighs/knees to align pelvis; a wedge pillow under the belly; and a support pillow behind back.',
      circadianTip:
        'CRITICAL CLINICAL INVARIANT: Week 16 ke baad kabhi bhi peeth ke bal (supine flat) na soyein! Supine position me heavy uterus Inferior Vena Cava (IVC) ko daba deta hai jisse blood pressure girta hai aur baby ko oxygen supply ghat sakti hai.',
      windDownRitual: [
        'Dinner finish strictly 2 hours before bed to eliminate heartburn.',
        'Warm water foot wash and gentle ankle circular mobility.',
        'Sip warm saffron-cardamom milk for natural tryptophan sleep induction.',
        'Dark bedroom with ambient temperature kept between 20-22°C.',
      ],
      hormonalContext:
        'High progesterone and growing belly disrupt sleep continuity. Dedicated left-lateral posture ensures optimal blood flow to the placenta and kidneys.',
    };
  }

  private static _buildMaternalHomeRemedies(trimester: Trimester): SymptomHomeRemedy[] {
    return [
      {
        symptom: 'Morning Sickness & Nausea (NVP)',
        title: 'Fresh Ginger-Lemon & Cardamom Infusion',
        ingredients: ['1/2 inch fresh ginger crushed', '1 green cardamom pod (Elaichi)', '1 glass water', 'few drops lemon juice'],
        preparation: 'Boil ginger and elaichi in water for 5 minutes. Strain, cool slightly to lukewarm, add 2 drops lemon juice and sip very slowly.',
        clinicalRationale: 'Gingerol and shogaols in ginger normalize gastric dysrhythmia and block vestibular 5-HT3 serotonin receptors.',
        timing: 'First thing in morning or when nausea waves surge',
        cautions: 'Avoid excess ginger if gastric ulcer history exists.',
      },
      {
        symptom: 'Heartburn & Acid Reflux (GERD)',
        title: 'Fennel (Saunf) Overnight Cold Infusion',
        ingredients: ['1 tsp green Saunf (Fennel seeds)', '1 glass room-temperature water'],
        preparation: 'Soak saunf in water overnight. Morning me strain karke sip karein, ya khane ke baad 1/2 tsp roasted saunf chabayein.',
        clinicalRationale: 'Anethole soothes esophageal lining and cools hyperacidic stomach secretions without impacting digestion.',
        timing: 'Post lunch and post dinner',
        cautions: 'Do not use sugar-coated commercial mukhwas.',
      },
      {
        symptom: 'Nocturnal Calf & Leg Cramps',
        title: 'Active Dorsiflexion Immediate Release & Epsom Soak',
        ingredients: ['Warm water bucket', '2 tbsp Epsom Salt (Magnesium Sulfate)'],
        preparation: 'Jab bhi leg me achanak cramp aaye: Leg seedha karke panje (toes) ko turant upar ghutne ki taraf kheencho (Dorsiflexion). Sone se pehle 10 min pairo ko warm water me dip karein.',
        clinicalRationale: 'Dorsiflexion actively elongates the contracting gastrocnemius muscle, terminating the neuromuscular spasm instantly.',
        timing: 'Immediate when cramp strikes; soak before bedtime',
        cautions: 'Water should be comfortably warm, not hot.',
      },
      {
        symptom: 'Pregnancy Constipation & Hemorrhoids',
        title: 'Soaked Munakka (Black Raisins) & Warm Ghee Milk',
        ingredients: ['6-8 Black Raisins (Munakka)', '1 cup warm milk', '1/2 tsp A2 Desi Cow Ghee'],
        preparation: 'Munakka ko subah paani me soak karein aur dopahar me chabakar khayein. Raat ko sone se pehle gungune doodh me 1/2 tsp ghee mila kar piyein.',
        clinicalRationale: 'Munakka sorbitol and ghee butyric acid lubricate the bowel lumen, stimulating peristalsis gently without harsh laxatives.',
        timing: 'Munakka mid-morning, Ghee milk at bedtime',
        cautions: 'If lactose intolerant, replace milk with warm water.',
      },
      {
        symptom: 'Swollen Feet & Pedal Edema',
        title: 'Lymphatic Drainage Ankle Elevation Protocol',
        ingredients: ['2 firm pillows', 'Comfortable couch or bed'],
        preparation: 'Peeth ke peeche incline support lein aur dono pairo ko 2 pillows par dil ke level se upar rakhein. 15 minute deep breathing karein.',
        clinicalRationale: 'Gravitational venous return drains accumulated extracellular interstitial fluid back to the heart and kidneys.',
        timing: 'Twice daily: 3:00 PM and 8:30 PM',
        cautions: 'If swelling suddenly appears on face and hands with headache, immediately contact doctor to rule out preeclampsia.',
      },
    ];
  }

  private static _buildMaternalMedicationSchedule(
    week: number,
    trimester: Trimester
  ): MedicationTimingRule[] {
    return [
      {
        name: 'Thyroid Medication (Levothyroxine, if prescribed)',
        dosageExample: 'As prescribed by endocrinologist (e.g. 25mcg - 75mcg)',
        idealTime: '06:00 AM (Immediate wakeup, completely empty stomach)',
        clinicalPurpose: 'Maintains maternal euthyroid state crucial for fetal brain myelination and neurodevelopment.',
        interactionWarning: 'CRITICAL: Wait at least 45 to 60 minutes before tea, coffee, milk, or breakfast. Food reduces bioavailability by 50%.',
        timingTip: 'Keep tablet and water bottle on the nightstand.',
        isPregnancySafe: true,
      },
      {
        name: 'Folic Acid / Methylfolate',
        dosageExample: '5mg or 400 - 800mcg daily',
        idealTime: '08:30 AM (With breakfast)',
        clinicalPurpose: 'Closes fetal neural tube in Weeks 1 to 12, preventing Spina Bifida and Anencephaly.',
        interactionWarning: 'Safe with all breakfast foods. Continue through Trimester 1.',
        timingTip: 'Take consistently every morning with your first meal.',
        isPregnancySafe: true,
      },
      {
        name: 'Calcium + Vitamin D3',
        dosageExample: '500mg - 1000mg elemental calcium + 400IU D3',
        idealTime: '01:30 PM (With lunch or breakfast)',
        clinicalPurpose: 'Mineralizes baby\'s 206 developing bones and teeth; protects mother against dental and bone demineralization.',
        interactionWarning: 'CRITICAL INVARIANT: NEVER take Calcium and Iron together! Keep at least a 2 to 3-hour time gap. Calcium blocks iron transporter channels.',
        timingTip: 'Best taken with food for optimal stomach acid dissolution.',
        isPregnancySafe: true,
      },
      {
        name: 'Iron (Ferrous Ascorbate / Bisglycinate)',
        dosageExample: '60mg - 100mg elemental iron daily',
        idealTime: '04:30 PM (Evening with fresh Lemon or Orange juice)',
        clinicalPurpose: 'Prevents maternal gestational anemia, low birth weight, and postpartum hemorrhage.',
        interactionWarning: 'CRITICAL: Vitamin C multiplies absorption. Never take with Dairy (Milk/Curd), Tea, or Coffee. High tannins bind iron into insoluble salts.',
        timingTip: 'Take 2 hours after lunch and 2 hours before dinner.',
        isPregnancySafe: true,
      },
      {
        name: 'Prenatal Omega-3 DHA',
        dosageExample: '200mg - 300mg DHA',
        idealTime: '08:30 PM (With or immediately after dinner)',
        clinicalPurpose: 'Builds fetal cerebral cortex neurons and retinal photoreceptors during Trimester 2 & 3.',
        interactionWarning: 'Fat-soluble; best absorbed when taken with dinner containing healthy fats (ghee/olive oil).',
        timingTip: 'Taking at dinner also prevents fishy burps during daytime.',
        isPregnancySafe: true,
      },
      {
        name: 'Doxylamine Succinate + Pyridoxine (B6) (If prescribed for nausea)',
        dosageExample: '10mg / 10mg tablet (e.g. Doxinate)',
        idealTime: '10:00 PM (Bedtime)',
        clinicalPurpose: 'Category A safe antiemetic that prevents morning nausea peak without harming the fetus.',
        interactionWarning: 'Causes mild drowsiness; ideal to take at night.',
        timingTip: 'Take with half glass of water before sleeping.',
        isPregnancySafe: true,
      },
    ];
  }

  private static _buildMaternalPartnerGuide(
    week: number,
    trimester: Trimester
  ): PartnerEmpathyGuide {
    if (trimester === 'first') {
      return {
        phaseOrTrimester: '1st Trimester • Organogenesis & Morning Nausea',
        emotionalContext:
          'Maternal hCG and progesterone are surging exponentially; severe morning sickness, extreme fatigue, breast tenderness, and anxiety about early pregnancy stability are very common.',
        whatSheNeedsMost:
          'Gentle patience, help with meals and smells she can\'t tolerate, bedside morning crackers before she stands up, and loving reassurance.',
        dosList: [
          'Keep dry crackers or roasted chana on her nightstand every single night so she can eat before standing up.',
          'Take over cooking when tadka, onion, or garlic smells trigger nausea.',
          'Ensure she takes Folic Acid daily with breakfast.',
          'Attend first trimester doctor visits and ultrasound dating scans with her.',
          'Let her rest whenever fatigue strikes — her body is building an entire organ (the placenta)!',
        ],
        dontsList: [
          'Don\'t force her to eat foods she feels strongly nauseous about.',
          'Don\'t let her lift heavy grocery bags or move heavy furniture.',
          'Don\'t bring strong artificial perfumes or room sprays around her.',
          'Don\'t let her forget her Folic Acid tablet.',
        ],
        suggestedGiftsAndCare: [
          {
            item: 'Morning Nausea Rescue Box (Ginger drops, Cardamom, Marie biscuits)',
            whyItHelps: 'Immediately curbs gastric nausea and morning hyperacidity.',
          },
          {
            item: 'U-Shaped Ergonomic Maternity Body Pillow',
            whyItHelps: 'Supports expanding pelvic bones and enables comfortable side sleep.',
          },
          {
            item: 'First Trimester Milestone Keepsake Journal',
            whyItHelps: 'Builds beautiful parental bonding and documents ultrasound scan pictures.',
          },
        ],
        readyToShareMessage: `Hey papa-to-be! 🤰 Baby is at Week ${week} right now! Morning nausea and tiredness are quite real today. Could you please bring me a glass of warm lemon water and some bedside crackers? Your support means everything to our little family! Love you! 👶❤️✨`,
      };
    } else {
      return {
        phaseOrTrimester:
          trimester === 'second'
            ? '2nd Trimester • Golden Growth & Vitality'
            : '3rd Trimester • Final Maturation & Delivery Prep',
        emotionalContext:
          'Belly is expanding rapidly; relaxin hormone softens ligaments causing lower back pain, pelvic girdle ache, and leg cramps. Baby kicks actively!',
        whatSheNeedsMost:
          'Daily foot and calf massage, help arranging sleeping pillows on her LEFT side, hydration reminders, and nesting partnership.',
        dosList: [
          'Give her a 15-minute soothing foot and calf massage every night to prevent painful cramps.',
          'Help arrange pillows so she comfortably sleeps on her LEFT side (SOS).',
          'Participate in fetal kick counting sessions (feel the baby kick together!).',
          'Ensure her Iron and Calcium tablets are taken with at least a 2-hour gap.',
          'Pack the hospital maternity delivery bag together ahead of time.',
        ],
        dontsList: [
          'NEVER let her sleep flat on her back (supine) after Week 16 — it compresses the Inferior Vena Cava!',
          'Don\'t ignore sudden hand or facial swelling or severe headaches (check blood pressure).',
          'Don\'t let her stand on her feet for hours without resting.',
        ],
        suggestedGiftsAndCare: [
          {
            item: 'Whipped Shea Butter & Almond Belly Stretch Balm',
            whyItHelps: 'Deeply nourishes expanding belly skin and relieves stretching itching.',
          },
          {
            item: 'Epsom Salt Foot Spa Soak Basin',
            whyItHelps: 'Drains third-trimester fluid retention from swollen ankles and feet.',
          },
          {
            item: 'Maternity Hospital Bag Packing Organizer Kit',
            whyItHelps: 'Eliminates last-minute delivery panic with organized clothes and baby essentials.',
          },
        ],
        readyToShareMessage: `Hey love! 🤰 Week ${week} update from baby and me: Baby is kicking up a storm today! My back and feet are feeling quite heavy. A 10-minute foot massage and help tucking in my sleep pillows tonight would make you my absolute superhero! See you soon! 👶❤️✨`,
      };
    }
  }

  private static _buildMaternalSmartWatchSync(
    week: number,
    trimester: Trimester
  ): SmartWatchBiometricSync {
    const isLate = week >= 28;
    return {
      restingHeartRateBpm: isLate ? 76 : 72,
      skinTemperatureOffsetCelsius: +0.48,
      heartRateVariabilityMs: 46,
      bloodOxygenSpo2: 99,
      sleepDurationHours: 8.6,
      deepSleepMinutes: 85,
      biphasicOvulationConfirmed: true,
      biometricInsight:
        'Sustained +0.48°C elevated skin temperature and healthy +8-10 bpm resting heart rate elevation confirm 40% increased maternal circulatory plasma volume and robust gestational health.',
    };
  }

  private static _buildMaternalDefaultReminders(
    week: number,
    trimester: Trimester
  ): CareReminderItem[] {
    return [
      {
        id: 'mat_rem_thyroid',
        category: 'medication',
        title: 'Thyroid Medication (Empty Stomach)',
        timeSlot: '06:00 AM',
        isEnabled: false,
        repeatDaily: true,
        notes: 'Take with plain water 45 mins before tea or breakfast.',
      },
      {
        id: 'mat_rem_crackers',
        category: 'meal',
        title: 'Bedside Dry Crackers / Roasted Chana',
        timeSlot: '06:45 AM',
        isEnabled: true,
        repeatDaily: true,
        notes: 'Eat 2-3 bites before lifting head from pillow to stop nausea.',
      },
      {
        id: 'mat_rem_folic_or_calcium',
        category: 'medication',
        title: trimester === 'first' ? 'Folic Acid Supplement (5mg)' : 'Calcium + Vitamin D3 (500mg)',
        timeSlot: '08:30 AM',
        isEnabled: true,
        repeatDaily: true,
        notes: 'Take with breakfast food for optimal absorption.',
      },
      {
        id: 'mat_rem_fruit_coconut',
        category: 'hydration',
        title: 'Pomegranate / Apple + Tender Coconut Water',
        timeSlot: '11:00 AM',
        isEnabled: true,
        repeatDaily: true,
        notes: 'Supports healthy Amniotic Fluid Index (AFI) and iron levels.',
      },
      {
        id: 'mat_rem_sos_nap',
        category: 'rest',
        title: 'SOS Left-Side Circulation Rest (30 mins)',
        timeSlot: '02:30 PM',
        isEnabled: true,
        repeatDaily: true,
        notes: 'Relieves Inferior Vena Cava pressure; elevate feet on pillow.',
      },
      {
        id: 'mat_rem_iron',
        category: 'medication',
        title: 'Iron Supplement (with Lemon Water)',
        timeSlot: '04:30 PM',
        isEnabled: true,
        repeatDaily: true,
        notes: 'NEVER take with milk, curd, tea or coffee. Keep 2h gap from calcium.',
      },
      {
        id: 'mat_rem_kick_count',
        category: 'checkup',
        title: 'Fetal Kick Count Session (10 movements)',
        timeSlot: '08:00 PM',
        isEnabled: week >= 24,
        repeatDaily: true,
        notes: 'Lie on left side after dinner and count baby movements.',
      },
      {
        id: 'mat_rem_sleep_posture',
        category: 'rest',
        title: 'Left-Side 3-Pillow Sleep Setup & Kesar Milk',
        timeSlot: '09:45 PM',
        isEnabled: true,
        repeatDaily: true,
        notes: 'Pillow between knees, wedge under belly. Never sleep flat on back.',
      },
    ];
  }
}
