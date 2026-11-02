import 'package:flutter_test/flutter_test.dart';
import 'package:vyra/models/models.dart';

void main() {
  group('VYRA NeuroSync™ Biocognitive Engine Mobile Tests', () {
    test('NeuroSyncBrainData parses metabolic biomarkers, caloric metrics and weekly schedule', () {
      final json = {
        'modality': 'gym',
        'metabolicArchetype': 'glycemic_insulin_resistant',
        'metabolismSummary': 'Sub-optimal insulin sensitivity (Glucose ~135 mg/dL). High-volume compound contractions prioritized.',
        'caloricStatusSummary': 'Surplus (+350 kcal): Fueling muscle hypertrophy & glycogen replenishment.',
        'muscleRecoverySummary': 'Targeting neglected groups: chest, back. Resting recently trained: legs.',
        'clinicalSafetyNotes': [
          'Postprandial resistance movements accelerate GLUT-4 glucose uptake without insulin dependency.'
        ],
        'aiReasoning': 'Ranked barbell and dumbbell compound movements for glycemic disposal.',
        'metrics': {
          'bmrKcal': 1680,
          'tdeeKcal': 2350,
          'bmi': 22.4,
          'bmiCategory': 'normal',
          'targetCaloricBudget': 2700,
          'caloricDeltaKcal': 350,
          'caloricState': 'surplus',
        },
        'weeklyPeriodizedMatrix': [
          {
            'day': 'Monday',
            'dayShort': 'MON',
            'theme': 'Push Hypertrophy: Chest, Deltoids & Triceps',
            'targetMuscles': ['Chest', 'Anterior Deltoids', 'Triceps'],
            'intensity': 'High',
            'sampleExercises': ['Barbell Bench Press', 'Incline Dumbbell Press', 'Tricep Parallel Dips'],
            'dietaryStrategy': 'High Protein (2.0g/kg) + Glycogen Replenishment Complex Carbs (Oats, Brown Rice)',
            'metabolicFocus': 'Maximizes muscle protein synthesis and mechanical tension.',
          },
          {
            'day': 'Tuesday',
            'dayShort': 'TUE',
            'theme': 'Pull & Posterior Chain: Back, Lats & Biceps',
            'targetMuscles': ['Latissimus Dorsi', 'Rhomboids', 'Biceps'],
            'intensity': 'High',
            'sampleExercises': ['Barbell Deadlift', 'Pull-Up', 'Dumbbell Bent-Over Row'],
            'dietaryStrategy': 'Balanced Carb-Protein Split + Anti-Inflammatory Fats (Omega-3, Walnuts)',
            'metabolicFocus': 'Spinal erector and lat recruitment elevates post-exercise oxygen consumption (EPOC).',
          },
        ],
      };

      final brain = NeuroSyncBrainData.fromJson(json);

      expect(brain.modality, 'gym');
      expect(brain.metabolicArchetype, 'glycemic_insulin_resistant');
      expect(brain.metabolismSummary, contains('insulin sensitivity'));
      expect(brain.caloricStatusSummary, contains('Surplus (+350 kcal)'));
      expect(brain.muscleRecoverySummary, contains('Targeting neglected groups: chest, back'));
      expect(brain.clinicalSafetyNotes.length, 1);
      expect(brain.clinicalSafetyNotes.first, contains('GLUT-4'));
      expect(brain.metrics, isNotNull);
      expect(brain.metrics!.bmrKcal, 1680);
      expect(brain.metrics!.tdeeKcal, 2350);
      expect(brain.metrics!.bmi, 22.4);
      expect(brain.metrics!.caloricState, 'surplus');
      expect(brain.metrics!.caloricDeltaKcal, 350);

      expect(brain.weeklyPeriodizedMatrix.length, 2);
      expect(brain.weeklyPeriodizedMatrix[0].day, 'Monday');
      expect(brain.weeklyPeriodizedMatrix[0].dayShort, 'MON');
      expect(brain.weeklyPeriodizedMatrix[0].intensity, 'High');
      expect(brain.weeklyPeriodizedMatrix[0].sampleExercises, contains('Barbell Bench Press'));
      expect(brain.weeklyPeriodizedMatrix[0].dietaryStrategy, contains('High Protein'));
      expect(brain.weeklyPeriodizedMatrix[0].metabolicFocus, contains('muscle protein synthesis'));
    });

    test('TodayData parses embedded neuroSyncBrain seamlessly', () {
      final todayJson = {
        'date': '2026-11-02',
        'plan': {
          'planDate': '2026-11-02',
          'goalMin': 30,
          'capacityMin': 45,
          'achievedMin': 15.0,
          'entries': [
            {
              'exerciseSlug': 'barbell-bench-press',
              'name': 'Barbell Bench Press',
              'durationSec': 120,
              'isCompleted': false,
            }
          ],
        },
        'windows': [],
        'capacity': {'dailyGoalMin': 30, 'capacityMin': 45},
        'effort': {'achievedMin': 15.0, 'goalMin': 30, 'effortRatio': 0.5, 'met': false, 'label': 'partial'},
        'coins': {'balance': 450, 'earnedTotal': 600, 'spentTotal': 150, 'level': 2, 'levelProgress': 0.45, 'coinsToNextLevel': 100, 'isMaxLevel': false},
        'dietEnabled': true,
        'disclaimer': 'Safe training disclaimer',
        'neuroSyncBrain': {
          'modality': 'gym',
          'metabolicArchetype': 'balanced_athletic',
          'metabolismSummary': 'Balanced athletic metabolism.',
          'caloricStatusSummary': 'Balanced intake.',
          'muscleRecoverySummary': 'Optimal muscular balance.',
          'clinicalSafetyNotes': [],
          'aiReasoning': 'Preset compound pool.',
          'weeklyPeriodizedMatrix': [],
        },
      };

      final today = TodayData.fromJson(todayJson);
      expect(today.date, '2026-11-02');
      expect(today.plan.entries.length, 1);
      expect(today.plan.entries.first.exerciseSlug, 'barbell-bench-press');
      expect(today.neuroSyncBrain, isNotNull);
      expect(today.neuroSyncBrain!.modality, 'gym');
      expect(today.neuroSyncBrain!.metabolicArchetype, 'balanced_athletic');
    });
  });
}
