/**
 * Lab report analysis tests.
 *
 * This is the feature most capable of harming a user, so these tests are written
 * as safety assertions first and functionality second.
 */
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

import { analyseLabReport, toPlannerHints, type MarkerReading } from './labReport';

const FEMALE_VEG = { gender: 'female' as const, dietPreference: 'veg_no_egg' as const };
const MALE_NONVEG = { gender: 'male' as const, dietPreference: 'non_veg' as const };

const r = (key: MarkerReading['key'], value: number, unit = ''): MarkerReading => ({ key, value, unit });

// ---------------------------------------------------------------------------
describe('safety — critical values short-circuit everything', () => {
  it('suppresses ALL diet advice when a value is critical', () => {
    const out = analyseLabReport([r('hemoglobin', 6.2)], FEMALE_VEG);
    assert.equal(out.urgentReferral, true);
    assert.equal(out.adjustments.length, 0, 'must not suggest food for a critical value');
    assert.match(out.nextStep, /doctor/i);
  });

  it('tells the user what to watch for, not just "see a doctor"', () => {
    const out = analyseLabReport([r('hemoglobin', 6.2)], FEMALE_VEG);
    assert.match(out.nextStep, /breathless|dizzy|weak/i);
  });

  it('treats dangerously high sugar as critical', () => {
    const out = analyseLabReport([r('fasting_glucose', 260)], MALE_NONVEG);
    assert.equal(out.urgentReferral, true);
    assert.equal(out.adjustments.length, 0);
  });

  it('returns no planner hints during an urgent referral', () => {
    const out = analyseLabReport([r('hba1c', 11)], MALE_NONVEG);
    assert.deepEqual(toPlannerHints(out), []);
  });

  it('does not escalate a mildly abnormal value', () => {
    const out = analyseLabReport([r('hemoglobin', 11.2)], FEMALE_VEG);
    assert.equal(out.urgentReferral, false);
    assert.ok(out.adjustments.length > 0);
  });
});

// ---------------------------------------------------------------------------
describe('safety — contraindications', () => {
  /**
   * The most important test in this file.
   * "Eat more protein" is standard fitness advice and is dangerous for someone
   * with reduced kidney function.
   */
  it('never suggests more protein when kidney markers are abnormal', () => {
    const out = analyseLabReport(
      [r('creatinine', 1.8), r('hemoglobin', 11)],
      MALE_NONVEG,
    );
    assert.equal(out.adjustments.some((a) => a.nutrient === 'protein'), false);
    assert.ok(out.suppressedAdvice.some((s) => /kidney/i.test(s)));
    assert.ok(out.suppressedAdvice.some((s) => /doctor/i.test(s)));
  });

  it('blocks protein advice on low eGFR too', () => {
    const out = analyseLabReport([r('egfr', 55)], MALE_NONVEG);
    assert.equal(out.adjustments.some((a) => a.nutrient === 'protein'), false);
  });

  it('blocks protein advice when uric acid is high', () => {
    const out = analyseLabReport([r('uric_acid', 9)], MALE_NONVEG);
    assert.ok(out.suppressedAdvice.some((s) => /uric acid/i.test(s)));
  });

  it('does not push calcium at someone whose calcium is already high', () => {
    const out = analyseLabReport([r('calcium', 11.2)], FEMALE_VEG);
    assert.equal(out.adjustments.some((a) => a.nutrient === 'calcium'), false);
  });

  it('explains every suppression instead of silently omitting it', () => {
    const out = analyseLabReport([r('creatinine', 1.9)], MALE_NONVEG);
    for (const s of out.suppressedAdvice) assert.ok(s.length > 30);
  });
});

// ---------------------------------------------------------------------------
describe('safety — bad input', () => {
  it('rejects an OCR misread rather than treating it as a finding', () => {
    // 130 g/dL haemoglobin is impossible — almost certainly "13.0" misread.
    const out = analyseLabReport([r('hemoglobin', 130)], FEMALE_VEG);
    assert.equal(out.findings.length, 0);
    assert.equal(out.rejectedReadings.length, 1);
    assert.match(out.rejectedReadings[0]!.reason, /scanning error/i);
  });

  it('says so honestly when nothing could be read', () => {
    const out = analyseLabReport([], FEMALE_VEG);
    assert.equal(out.noReadableMarkers, true);
    assert.match(out.nextStep, /could not read/i);
    assert.equal(out.adjustments.length, 0);
  });

  it('handles NaN without crashing or inventing a result', () => {
    const out = analyseLabReport([r('vitamin_d', Number.NaN)], FEMALE_VEG);
    assert.equal(out.findings.length, 0);
    assert.equal(out.rejectedReadings.length, 1);
  });
});

// ---------------------------------------------------------------------------
describe('safety — language', () => {
  it('never names a disease', () => {
    const out = analyseLabReport(
      [r('hemoglobin', 9), r('hba1c', 6.2), r('tsh', 6.5), r('vitamin_d', 12)],
      FEMALE_VEG,
    );
    const allText = [
      ...out.findings.map((f) => f.summary),
      ...out.adjustments.flatMap((a) => [a.label, a.tip, ...a.becauseOf]),
      out.nextStep,
      out.disclaimer,
    ].join(' ').toLowerCase();

    for (const word of ['anaemia', 'anemia', 'diabetes', 'diabetic', 'hypothyroid', 'thyroid disease', 'disease']) {
      assert.ok(!allText.includes(word), `output should not name a condition: found "${word}"`);
    }
  });

  it('never suggests a supplement or a dose', () => {
    const out = analyseLabReport([r('vitamin_b12', 180), r('vitamin_d', 15)], FEMALE_VEG);

    // Scan only the ADVICE-bearing fields. The disclaimer is excluded on purpose:
    // it contains the word "supplements" precisely because it promises we do not
    // prescribe them, and a test that punished that sentence would push us to
    // delete the very line that protects the user.
    const adviceText = [
      ...out.findings.map((f) => f.summary),
      ...out.adjustments.flatMap((a) => [a.label, a.tip, ...(a.foods ?? []), ...a.becauseOf]),
      ...out.suppressedAdvice,
      out.nextStep,
    ].join(' ').toLowerCase();

    for (const word of ['tablet', 'capsule', 'supplement', 'dose', 'iu daily', 'injection', 'mg of']) {
      assert.ok(!adviceText.includes(word), `must not recommend: ${word}`);
    }
  });

  it('states in the disclaimer that it does not prescribe', () => {
    const out = analyseLabReport([r('vitamin_d', 15)], FEMALE_VEG);
    assert.match(out.disclaimer, /does not diagnose/i);
    assert.match(out.disclaimer, /prescribe supplements/i);
  });

  it('always attaches the disclaimer', () => {
    const out = analyseLabReport([r('hemoglobin', 13)], MALE_NONVEG);
    assert.match(out.disclaimer, /not a medical diagnosis/i);
    assert.match(out.disclaimer, /differ between laboratories/i);
  });
});

// ---------------------------------------------------------------------------
describe('sex-specific reference ranges', () => {
  it('uses the female haemoglobin range', () => {
    // 12.5 is normal for a woman, low for a man.
    const female = analyseLabReport([r('hemoglobin', 12.5)], FEMALE_VEG);
    const male = analyseLabReport([r('hemoglobin', 12.5)], MALE_NONVEG);
    assert.equal(female.findings[0]!.band, 'normal');
    assert.notEqual(male.findings[0]!.band, 'normal');
  });

  it('uses the sex-specific HDL threshold', () => {
    const female = analyseLabReport([r('hdl', 45)], FEMALE_VEG);
    const male = analyseLabReport([r('hdl', 45)], MALE_NONVEG);
    assert.equal(female.findings[0]!.direction, 'low');
    assert.equal(male.findings[0]!.direction, 'normal');
  });
});

// ---------------------------------------------------------------------------
describe('dietary response', () => {
  it('recommends iron foods for low haemoglobin', () => {
    const out = analyseLabReport([r('hemoglobin', 10.5)], FEMALE_VEG);
    const iron = out.adjustments.find((a) => a.nutrient === 'iron');
    assert.ok(iron, 'expected an iron adjustment');
    assert.match(iron!.tip, /vitamin c/i);
  });

  /**
   * A deficiency response that ignores the user's diet is worse than useless.
   */
  it('respects the user dietary preference in every suggestion', () => {
    const veg = analyseLabReport([r('hemoglobin', 10.5), r('vitamin_b12', 210)], FEMALE_VEG);
    const allFoods = veg.adjustments.flatMap((a) => a.foods).join(' ').toLowerCase();
    for (const word of ['chicken', 'liver', 'fish', 'meat', 'egg']) {
      assert.ok(!allFoods.includes(word), `veg_no_egg user must not be shown: ${word}`);
    }
  });

  it('offers non-vegetarian sources to a non-vegetarian user', () => {
    const out = analyseLabReport([r('hemoglobin', 11)], MALE_NONVEG);
    const foods = out.adjustments.flatMap((a) => a.foods).join(' ').toLowerCase();
    assert.ok(foods.includes('liver') || foods.includes('fish') || foods.includes('meat'));
  });

  it('suggests everyday Indian foods, not imported ones', () => {
    const out = analyseLabReport([r('hemoglobin', 10.5)], FEMALE_VEG);
    const foods = out.adjustments.flatMap((a) => a.foods).join(' ').toLowerCase();
    assert.ok(/ragi|palak|rajma|chana|bajra/.test(foods), 'expected familiar Indian staples');
  });

  it('responds to a HIGH marker where high is the problem', () => {
    const out = analyseLabReport([r('hba1c', 6.1), r('ldl', 145)], MALE_NONVEG);
    const fiber = out.adjustments.find((a) => a.nutrient === 'fiber');
    assert.ok(fiber, 'raised HbA1c and LDL should push fibre and slow carbs');
  });

  it('flags when food alone is usually not enough', () => {
    const out = analyseLabReport([r('vitamin_d', 14), r('vitamin_b12', 180)], FEMALE_VEG);
    assert.ok(out.adjustments.every((a) => a.seeADoctor === true));
    assert.match(out.nextStep, /doctor/i);
  });

  it('says nothing needs changing when everything is normal', () => {
    const out = analyseLabReport(
      [r('hemoglobin', 14), r('vitamin_d', 45), r('hba1c', 5.1)],
      MALE_NONVEG,
    );
    assert.equal(out.adjustments.length, 0);
    assert.match(out.nextStep, /within the usual range/i);
  });

  it('does not treat a borderline value as a deficiency worth acting on', () => {
    // 11.5 for a woman is just under 12 — borderline, not a shortfall.
    const out = analyseLabReport([r('hemoglobin', 11.5)], FEMALE_VEG);
    assert.equal(out.findings[0]!.band, 'borderline_low');
  });

  it('produces planner hints that nudge rather than hijack the meal plan', () => {
    const out = analyseLabReport([r('hemoglobin', 10.5)], FEMALE_VEG);
    const hints = toPlannerHints(out);
    assert.deepEqual(hints, [{ tag: 'nutrient:iron', weight: 1.5 }]);
  });
});

// ---------------------------------------------------------------------------
describe('referral-only markers', () => {
  it('never generates food advice from a thyroid result', () => {
    const out = analyseLabReport([r('tsh', 6.8)], FEMALE_VEG);
    assert.equal(out.adjustments.length, 0);
    assert.match(out.nextStep, /doctor/i);
  });

  it('never generates food advice from a liver result', () => {
    const out = analyseLabReport([r('alt', 90)], MALE_NONVEG);
    assert.equal(out.adjustments.length, 0);
  });

  it('still reports the finding so the user can see it', () => {
    const out = analyseLabReport([r('tsh', 6.8)], FEMALE_VEG);
    assert.equal(out.findings.length, 1);
    assert.match(out.findings[0]!.summary, /above/i);
  });
});
