import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  evaluateMetabolicProfile,
  analyzeMuscleHistory,
  buildWeeklyPeriodizedMatrix,
  synthesizeNeuroSyncPool,
} from './neurosync';
import type { StoredUser, StoredPlan } from '../store';

const mockUser: StoredUser = {
  id: 'usr_test_neurosync',
  displayHandle: 'athletetest',
  name: 'Athlete Test',
  gender: 'male',
  dob: '2000-01-01',
  heightCm: 175,
  weightKg: 70,
  disabilityFlag: false,
  accessibilityMode: false,
  fitnessGoal: 'gain_weight',
  dietToggle: true,
  dietPreference: 'vegetarian',
  primarySport: 'gym',
  dmPrivacy: 'following',
  accountStatus: 'active',
  onboardingStep: 4,
  createdAt: new Date().toISOString(),
};

describe('VYRA NeuroSync™ Adaptive Biocognitive Engine', () => {
  describe('evaluateMetabolicProfile', () => {
    it('calculates Mifflin-St Jeor BMR and TDEE correctly', () => {
      const { metrics, archetype } = evaluateMetabolicProfile(mockUser, 2500);
      assert.ok(metrics.bmrKcal > 1500 && metrics.bmrKcal < 1800);
      assert.ok(metrics.tdeeKcal > metrics.bmrKcal);
      assert.equal(archetype, 'balanced_athletic');
    });

    it('identifies sluggish hypothyroid archetype when TSH > 4.0', () => {
      const hypoUser: StoredUser = {
        ...mockUser,
        latestLabMarkers: { tsh: 5.8 },
      };
      const { archetype, summary, safetyNotes } = evaluateMetabolicProfile(hypoUser);
      assert.equal(archetype, 'sluggish_hypothyroid');
      assert.ok(summary.includes('TSH 5.8'));
      assert.ok(safetyNotes.length > 0);
    });

    it('identifies glycemic insulin resistant archetype when glucose > 100', () => {
      const diabeticUser: StoredUser = {
        ...mockUser,
        latestLabMarkers: { fasting_glucose: 135 },
      };
      const { archetype, summary, safetyNotes } = evaluateMetabolicProfile(diabeticUser);
      assert.equal(archetype, 'glycemic_insulin_resistant');
      assert.ok(summary.includes('insulin sensitivity'));
      assert.ok(safetyNotes.length > 0);
    });

    it('calculates caloric surplus and deficit accurately based on food diary', () => {
      const surplus = evaluateMetabolicProfile(mockUser, 3200);
      assert.equal(surplus.metrics.caloricState, 'surplus');
      assert.ok(surplus.metrics.caloricDeltaKcal > 0);

      const deficit = evaluateMetabolicProfile(mockUser, 1200);
      assert.equal(deficit.metrics.caloricState, 'deficit');
      assert.ok(deficit.metrics.caloricDeltaKcal < 0);
    });
  });

  describe('analyzeMuscleHistory', () => {
    it('detects 48h active recovery muscles and neglected muscle groups', () => {
      const pastPlans: StoredPlan[] = [
        {
          userId: mockUser.id,
          planDate: '2026-11-01',
          goalMin: 30,
          capacityMin: 45,
          achievedMin: 30,
          entries: [
            {
              exerciseSlug: 'barbell-bench-press',
              name: 'Barbell Bench Press',
              durationSec: 600,
              isCompleted: true,
            },
          ],
        },
      ];

      const recovery = analyzeMuscleHistory(pastPlans);
      assert.ok(recovery.recentMusclesTrained.includes('chest'));
      assert.ok(recovery.priorityFocusMuscles.length > 0);
    });
  });

  describe('buildWeeklyPeriodizedMatrix', () => {
    it('produces a full 7-day periodized schedule with synchronized nutrition', () => {
      const schedule = buildWeeklyPeriodizedMatrix('gain_weight', 'gym', 'balanced_athletic');
      assert.equal(schedule.length, 7);
      assert.equal(schedule[0].day, 'Monday');
      assert.equal(schedule[6].day, 'Sunday');
      assert.ok(schedule[0].dietaryStrategy.length > 10);
      assert.ok(schedule[0].metabolicFocus.length > 10);
    });
  });

  describe('synthesizeNeuroSyncPool', () => {
    it('synthesizes heavy gym compound movements when modality is gym', () => {
      const metabolic = evaluateMetabolicProfile(mockUser, 2400);
      const recovery = analyzeMuscleHistory([]);
      const result = synthesizeNeuroSyncPool(mockUser, 'gym', metabolic, recovery, '2026-11-02');

      assert.ok(result.pool.length >= 10);
      const slugs = result.pool.map((e) => e.id);
      assert.ok(
        slugs.includes('barbell-bench-press') ||
        slugs.includes('barbell-back-squat') ||
        slugs.includes('barbell-deadlift') ||
        slugs.includes('overhead-barbell-press')
      );
    });

    it('filters out spinal compression exercises when back injury is flagged', () => {
      const injuredUser: StoredUser = {
        ...mockUser,
        disabilityType: 'Lumbar disc herniation lower back pain',
      };
      const metabolic = evaluateMetabolicProfile(injuredUser);
      const recovery = analyzeMuscleHistory([]);
      const result = synthesizeNeuroSyncPool(injuredUser, 'gym', metabolic, recovery, '2026-11-02');

      const slugs = result.pool.map((e) => e.id);
      assert.equal(slugs.includes('barbell-deadlift'), false);
    });
  });
});
