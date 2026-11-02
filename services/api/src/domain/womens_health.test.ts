import { describe, it } from 'node:test';
import assert from 'node:assert';
import {
  FeminaCycleEngine,
  MaternalCareEngine,
  CycleEntry,
} from './womens_health';

describe('🌸 VYRA FeminaCycle™ Menstrual Health Engine', () => {
  it('correctly calculates cycle phases and predicts next period and ovulation', () => {
    // 28-day cycle with last period starting 10 days ago
    const today = new Date('2026-11-03');
    const lastStart = new Date(today);
    lastStart.setDate(today.getDate() - 10); // Day 11 of cycle

    const history: CycleEntry[] = [
      { startDate: lastStart.toISOString().split('T')[0], durationDays: 5, cycleLengthDays: 28 },
      { startDate: '2026-09-26', durationDays: 5, cycleLengthDays: 28 },
      { startDate: '2026-08-29', durationDays: 5, cycleLengthDays: 28 },
    ];

    const result = FeminaCycleEngine.analyzeCycle({
      cycleHistory: history,
      todayDateStr: '2026-11-03',
    });

    assert.strictEqual(result.currentCycleDay, 11);
    assert.strictEqual(result.currentPhase, 'follicular');
    assert.strictEqual(result.cycleRegularity, 'regular');
    assert.strictEqual(result.averageCycleLength, 28);
    assert.strictEqual(result.daysUntilNextPeriod, 18);
    assert(result.nextPeriodStartDate.length > 0);
    assert(result.ovulationDate.length > 0);
    assert(result.fertileWindowStart.length > 0);
    assert(result.fertileWindowEnd.length > 0);
  });

  it('identifies menstrual phase on days 1-5 and gives iron-rich dietary guidance', () => {
    // Day 2 of period
    const history: CycleEntry[] = [
      { startDate: '2026-11-02', durationDays: 5, cycleLengthDays: 28 },
    ];

    const result = FeminaCycleEngine.analyzeCycle({
      cycleHistory: history,
      todayDateStr: '2026-11-03',
    });

    assert.strictEqual(result.currentCycleDay, 2);
    assert.strictEqual(result.currentPhase, 'menstrual');
    assert.strictEqual(result.conceptionProbability, 'low');

    const carePlan = FeminaCycleEngine.getAdaptiveCarePlan({
      currentPhase: result.currentPhase,
      crampSeverity: 4,
      symptoms: ['cramps', 'backache', 'bloating'],
    });

    // Verify restorative asanas
    assert(carePlan.recommendedAsanas.some((a) => a.name === "Child's Pose"));
    assert(carePlan.recommendedAsanas.some((a) => a.name === 'Cat-Cow Pose'));
    assert(carePlan.recommendedAsanas.some((a) => a.name === 'Legs Up The Wall'));

    // Verify menstrual diet
    assert(carePlan.dietaryPlan.keyNutrients.includes('Iron'));
    assert(carePlan.dietaryPlan.keyNutrients.includes('Magnesium'));
    assert(carePlan.dietaryPlan.recommendedFoods.some((f) => f.includes('Gud (Jaggery)')));
    assert(carePlan.dietaryPlan.avoidFoods.some((f) => f.includes('Cold iced drinks')));
  });

  it('detects irregular long cycles (>35 days) and prescribes seed cycling and lifestyle restoration', () => {
    const history: CycleEntry[] = [
      { startDate: '2026-10-01', cycleLengthDays: 40 },
      { startDate: '2026-08-22', cycleLengthDays: 40 },
    ];

    const result = FeminaCycleEngine.analyzeCycle({
      cycleHistory: history,
      todayDateStr: '2026-11-03',
    });

    assert.strictEqual(result.cycleRegularity, 'irregular_long');
    assert(result.regularityInsight.includes('>35 din'));
    assert(result.naturalBalancingTips.some((t) => t.includes('Seed Cycling Phase 1')));
    assert(result.naturalBalancingTips.some((t) => t.includes('Cortisol Control')));
  });

  it('provides luteal phase PMS guidance with B6 and progesterone-supporting nutrition', () => {
    const carePlan = FeminaCycleEngine.getAdaptiveCarePlan({
      currentPhase: 'luteal',
      symptoms: ['bloating', 'mood_swings'],
    });

    assert(carePlan.dietaryPlan.keyNutrients.includes('Vitamin B6'));
    assert(carePlan.dietaryPlan.keyNutrients.includes('Potassium'));
    assert(carePlan.dietaryPlan.recommendedFoods.some((f) => f.includes('Banana (Kela)')));
    assert(carePlan.dietaryPlan.recommendedFoods.some((f) => f.includes('Dark Chocolate')));
    assert(carePlan.dietaryPlan.seedCyclingTip?.includes('Sesame (Til)'));
  });

  it('generates complete 24h chrono-routine, fruit therapy, sleep protocol & medication rules', () => {
    const carePlan = FeminaCycleEngine.getAdaptiveCarePlan({
      currentPhase: 'menstrual',
      crampSeverity: 4,
      symptoms: ['cramps', 'bloating', 'fatigue'],
    });

    // 24-hour Chrono-care routine steps
    assert.strictEqual(carePlan.chronoRoutine.length, 8);
    const wakeStep = carePlan.chronoRoutine.find((s) => s.periodOfDay === 'morning_wake');
    assert(wakeStep !== undefined);
    assert(wakeStep.title.includes('Ginger') || wakeStep.nutritionOrAction.toLowerCase().includes('ginger'));

    const bedStep = carePlan.chronoRoutine.find((s) => s.periodOfDay === 'bedtime');
    assert(bedStep !== undefined);
    assert(bedStep.title.includes('Haldi') || bedStep.nutritionOrAction.includes('Turmeric'));

    // Fruit therapy
    assert(carePlan.fruitTherapy.recommendedFruits.some((f) => f.name === 'Pomegranate'));
    assert(carePlan.fruitTherapy.avoidOrCautionFruits.some((f) => f.name.includes('Melon')));

    // Sleep Protocol
    assert(carePlan.sleepProtocol.targetSleepHours.includes('8.5'));
    assert(carePlan.sleepProtocol.optimalPosture.includes('Fetal'));

    // Home remedies
    assert(carePlan.homeRemedies.some((r) => r.title.includes('Ajwain')));
    assert(carePlan.homeRemedies.some((r) => r.title.includes('Castor Oil')));

    // Medication Schedule
    const iron = carePlan.medicationSchedule.find((m) => m.name.includes('Iron'));
    assert(iron !== undefined);
    assert(iron.interactionWarning.includes('block'));
  });
});

describe('🤰 VYRA MaternalCare™ 9-Month Pregnancy & Maternal Engine', () => {
  it('calculates gestational week and trimester accurately from LMP', () => {
    // 20 weeks ago (140 days)
    const lmp = '2026-06-16';
    const result = MaternalCareEngine.analyzePregnancy({
      lastMenstrualPeriod: lmp,
      todayDateStr: '2026-11-03',
    });

    assert.strictEqual(result.currentWeek, 21);
    assert.strictEqual(result.trimester, 'second');
    assert(result.trimesterDisplayName.includes('Second Trimester'));
    assert.strictEqual(result.fetalMilestone.week, 20);
    assert.strictEqual(result.fetalMilestone.fruitAnalogy, 'Banana (Kela)');
    assert(result.daysUntilDelivery > 0);
  });

  it('provides trimester 1 essential care (Folic acid, nausea, safe activities)', () => {
    // Week 8 of pregnancy
    const result = MaternalCareEngine.analyzePregnancy({
      lastMenstrualPeriod: '2026-09-08',
      todayDateStr: '2026-11-03',
    });

    assert.strictEqual(result.currentWeek, 9);
    assert.strictEqual(result.trimester, 'first');

    // Checklist includes Folic Acid
    const folic = result.dailyCareChecklist.find((i) => i.id === 'folic_acid_supplement');
    assert(folic !== undefined);
    assert(folic.positiveImpact.includes('neural tube defects'));
    assert(folic.skippedRisk.includes('Spina Bifida') || folic.skippedRisk.includes('anomalies'));

    // First trimester activities
    assert(result.prenatalSafeActivities.contraindicated.some((c) => c.includes('HIIT')));
    assert(result.prenatalSafeActivities.recommended.some((r) => r.includes('Pranayama')));
  });

  it('provides trimester 2 & 3 critical care: Iron + Calcium timing gap, kick counting & left-side sleep', () => {
    // Week 32 of pregnancy
    const result = MaternalCareEngine.analyzePregnancy({
      estimatedDueDate: '2026-12-29',
      todayDateStr: '2026-11-03',
    });

    assert.strictEqual(result.trimester, 'third');
    assert.strictEqual(result.currentWeek, 33);

    // Iron checklist explains why NOT to take with milk/calcium
    const iron = result.dailyCareChecklist.find((i) => i.id === 'elemental_iron_supplement');
    assert(iron !== undefined);
    assert(iron.timingTip?.includes('doodh (milk)'));

    // Kick counter checklist in 3rd trimester
    const kick = result.dailyCareChecklist.find((i) => i.id === 'kick_counter_audit');
    assert(kick !== undefined);
    assert(kick.details.includes('10 movements'));

    // Left side sleep rule
    const sleep = result.dailyCareChecklist.find((i) => i.id === 'side_sleeping_guideline');
    assert(sleep !== undefined);
    assert(sleep.positiveImpact.includes('Inferior Vena Cava'));
  });

  it('maps clinical sonography and screening roadmap by gestational age', () => {
    const result = MaternalCareEngine.analyzePregnancy({
      lastMenstrualPeriod: '2026-06-16',
      todayDateStr: '2026-11-03',
    });

    assert(result.upcomingClinicalScans.length > 0);
    assert(result.upcomingClinicalScans.some((s) => s.testName.includes('Targeted Anomaly Scan')));
    assert(result.upcomingClinicalScans.some((s) => s.testName.includes('Glucose Challenge')));
  });

  it('generates maternal 24h chrono-routine, fruit contraindications, sleep protocol & medication rules', () => {
    const result = MaternalCareEngine.analyzePregnancy({
      lastMenstrualPeriod: '2026-06-16', // Week 20
      todayDateStr: '2026-11-03',
    });

    // 24h Chrono routine
    assert.strictEqual(result.chronoRoutine.length, 8);
    const wakeStep = result.chronoRoutine.find((s) => s.periodOfDay === 'morning_wake');
    assert(wakeStep !== undefined);
    assert(wakeStep.nutritionOrAction.includes('crackers') || wakeStep.nutritionOrAction.includes('chana'));

    const afternoonStep = result.chronoRoutine.find((s) => s.periodOfDay === 'afternoon_rest');
    assert(afternoonStep !== undefined);
    assert(afternoonStep.guidance.includes('Inferior Vena Cava'));

    // Fruit safety & contraindications
    assert(result.fruitTherapy.recommendedFruits.some((f) => f.name === 'Pomegranate'));
    const greenPapaya = result.fruitTherapy.avoidOrCautionFruits.find((f) =>
      f.name.includes('Papaya')
    );
    assert(greenPapaya !== undefined);
    assert.strictEqual(greenPapaya.riskLevel, 'strict_avoid');
    assert(greenPapaya.scientificMechanism.includes('Papain'));

    // Sleep protocol
    assert(result.sleepProtocol.optimalPosture.includes('Left-Lateral'));
    assert(result.sleepProtocol.circadianTip.includes('Week 16'));

    // Home remedies
    assert(result.homeRemedies.some((r) => r.symptom.includes('Morning Sickness')));
    assert(result.homeRemedies.some((r) => r.symptom.includes('Leg Cramps')));

    // Medication Schedule
    const iron = result.medicationSchedule.find((m) => m.name.includes('Iron'));
    assert(iron !== undefined);
    assert(iron.interactionWarning.includes('NEVER take Calcium and Iron together') || iron.interactionWarning.includes('Dairy'));
  });
});
