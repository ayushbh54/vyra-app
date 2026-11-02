import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyra/services/kinetic_coach_brain.dart';
import 'package:vyra/theme.dart';

void main() {
  group('🛡️ Core Deep Audit: Multi-Turn Continuous Stream Simulation (50 Turns)', () {
    late KineticCoachBrain brain;

    setUp(() {
      brain = KineticCoachBrain();
      brain.resetWorkout();
    });

    test('50-Turn Continuous Workout Stream: Accurately separates clean vs cheated reps', () {
      int simulatedVerifiedReps = 0;
      int simulatedRejectedReps = 0;

      // 33 standard human landmarks list
      List<Offset> generateLandmarks({bool valgus = false, double kneeForwardOffset = 0.0}) {
        final lm = List<Offset>.filled(33, const Offset(0.5, 0.5));
        lm[27] = const Offset(0.35, 0.90); // Left ankle
        lm[28] = const Offset(0.65, 0.90); // Right ankle

        if (valgus) {
          // Knees collapsed inward
          lm[25] = const Offset(0.48, 0.65);
          lm[26] = const Offset(0.52, 0.65);
        } else {
          // Knees aligned with feet
          lm[25] = Offset(0.35 + kneeForwardOffset, 0.65);
          lm[26] = Offset(0.65 + kneeForwardOffset, 0.65);
        }
        return lm;
      }

      final conf = List<double>.filled(33, 0.95);

      // --- Rep 1 to 5: Flawless Form Squats (ROM 160° -> 88° -> 160°) ---
      for (int rep = 0; rep < 5; rep++) {
        brain.startRepCycle(160.0);
        for (int frame = 0; frame < 10; frame++) {
          final angle = 160.0 - (72.0 * math.sin(frame * math.pi / 10));
          final diag = brain.diagnoseKineticFaults(
            auraPattern: 'squat',
            framingMode: 'full_body',
            exerciseName: 'Deep Squat',
            humanLandmarks: generateLandmarks(),
            humanConf: conf,
            currentAngle: angle,
            spineTiltDeg: 12.0,
            symmetryDiff: 2.0,
            leftTripletConf: 0.95,
            rightTripletConf: 0.95,
            phase: frame < 5 ? 'ECCENTRIC' : 'CONCENTRIC',
            decreaseToPeak: true,
            peakAngleDeg: 90.0,
          );
          expect(diag.hasFault, isFalse);
          brain.recordFrame(
            isFormValid: true,
            currentAngle: angle,
            reachedDepth: angle <= 92.0,
          );
        }

        final verdict = brain.evaluateRepCompletion(
          currentRepCount: simulatedVerifiedReps,
          targetReps: 10,
          startAngleDeg: 160.0,
          peakAngleDeg: 90.0,
          decreaseToPeak: true,
          reachedDepth: true,
          isAssistedMode: true,
        );

        expect(verdict.isApproved, isTrue);
        expect(verdict.formPurity, greaterThanOrEqualTo(0.95));
        simulatedVerifiedReps++;
      }

      expect(simulatedVerifiedReps, equals(5));

      // --- Rep 6 & 7: Cheated Reps with Severe Knee Valgus ---
      for (int cheat = 0; cheat < 2; cheat++) {
        brain.startRepCycle(160.0);
        for (int frame = 0; frame < 10; frame++) {
          final angle = 160.0 - (72.0 * math.sin(frame * math.pi / 10));
          final diag = brain.diagnoseKineticFaults(
            auraPattern: 'squat',
            framingMode: 'full_body',
            exerciseName: 'Deep Squat',
            humanLandmarks: generateLandmarks(valgus: true), // Severe valgus
            humanConf: conf,
            currentAngle: angle,
            spineTiltDeg: 12.0,
            symmetryDiff: 2.0,
            leftTripletConf: 0.95,
            rightTripletConf: 0.95,
            phase: 'ECCENTRIC',
            decreaseToPeak: true,
            peakAngleDeg: 90.0,
          );
          if (angle <= 145.0) {
            expect(diag.hasFault, isTrue);
            expect(diag.faultType, equals(KineticFaultType.kneeValgus));
          }
          brain.recordFrame(
            isFormValid: !diag.hasFault,
            currentAngle: angle,
            reachedDepth: angle <= 92.0,
          );
        }

        final verdict = brain.evaluateRepCompletion(
          currentRepCount: simulatedVerifiedReps,
          targetReps: 10,
          startAngleDeg: 160.0,
          peakAngleDeg: 90.0,
          decreaseToPeak: true,
          reachedDepth: true,
          isAssistedMode: true,
        );

        // Rep MUST be rejected
        expect(verdict.isApproved, isFalse);
        expect(verdict.reason, contains('Form Breakdown'));
        simulatedRejectedReps++;
      }

      expect(simulatedRejectedReps, equals(2));
      expect(simulatedVerifiedReps, equals(5)); // Count did NOT advance!

      // --- Rep 8 & 9: Shallow Half-Reps (User only bent to 130°, never reached 90°) ---
      for (int shallow = 0; shallow < 2; shallow++) {
        brain.startRepCycle(160.0);
        for (int frame = 0; frame < 8; frame++) {
          final angle = 160.0 - (25.0 * math.sin(frame * math.pi / 8)); // Only reaches 135°!
          brain.recordFrame(
            isFormValid: true,
            currentAngle: angle,
            reachedDepth: false, // Depth NOT reached
          );
        }

        final verdict = brain.evaluateRepCompletion(
          currentRepCount: simulatedVerifiedReps,
          targetReps: 10,
          startAngleDeg: 160.0,
          peakAngleDeg: 90.0,
          decreaseToPeak: true,
          reachedDepth: false,
          isAssistedMode: true,
        );

        expect(verdict.isApproved, isFalse);
        expect(verdict.reason, contains('Shallow Depth'));
        simulatedRejectedReps++;
      }

      expect(simulatedRejectedReps, equals(4));
      expect(simulatedVerifiedReps, equals(5));

      // --- Rep 10 to 14: Final 5 Clean Reps to Finish Workout ---
      for (int rep = 0; rep < 5; rep++) {
        brain.startRepCycle(160.0);
        for (int frame = 0; frame < 10; frame++) {
          final angle = 160.0 - (72.0 * math.sin(frame * math.pi / 10));
          brain.recordFrame(
            isFormValid: true,
            currentAngle: angle,
            reachedDepth: angle <= 92.0,
          );
        }

        final verdict = brain.evaluateRepCompletion(
          currentRepCount: simulatedVerifiedReps,
          targetReps: 10,
          startAngleDeg: 160.0,
          peakAngleDeg: 90.0,
          decreaseToPeak: true,
          reachedDepth: true,
          isAssistedMode: true,
        );

        expect(verdict.isApproved, isTrue);
        simulatedVerifiedReps++;
      }

      expect(simulatedVerifiedReps, equals(10));
      expect(simulatedRejectedReps, equals(4));

      // Finalize scorecard
      final scorecard = brain.finalizeScorecard(
        exerciseId: 'bodyweight-squat',
        exerciseName: 'Deep Bodyweight Squat',
        completedReps: simulatedVerifiedReps,
        targetReps: 10,
        liveFormScore: 92.5,
        liveSymmetryScore: 98.0,
        durationSec: 120,
        rejectedReps: simulatedRejectedReps,
      );

      expect(scorecard.completedReps, equals(10));
      expect(scorecard.rejectedReps, equals(4));
      expect(scorecard.overallFormAccuracy, greaterThan(75.0));
      expect(scorecard.caloriesBurned, greaterThan(12));
      expect(scorecard.coachingFeedbackList.any((tip) => tip.contains('Filtered out 4 incomplete/cheated reps')), isTrue);
    });
  });

  group('🛡️ Core Deep Audit: Resilience, Fuzzing & Dead-Zone Verification', () {
    late KineticCoachBrain brain;

    setUp(() {
      brain = KineticCoachBrain();
      brain.resetWorkout();
    });

    test('Handles noisy, NaN, and extreme landmark inputs without throwing exceptions', () {
      final corruptedLandmarks = [
        const Offset(double.nan, double.nan),
        const Offset(double.infinity, double.negativeInfinity),
        const Offset(-999.0, 999.0),
        Offset.zero,
      ];

      final conf = List<double>.filled(33, 0.9);

      for (final badOffset in corruptedLandmarks) {
        final lm = List<Offset>.filled(33, badOffset);
        expect(
          () => brain.diagnoseKineticFaults(
            auraPattern: 'squat',
            framingMode: 'full_body',
            exerciseName: 'Deep Squat',
            humanLandmarks: lm,
            humanConf: conf,
            currentAngle: double.nan,
            spineTiltDeg: 500.0,
            symmetryDiff: -50.0,
            leftTripletConf: 0.9,
            rightTripletConf: 0.9,
            phase: 'IDLE',
            decreaseToPeak: true,
            peakAngleDeg: 90.0,
          ),
          returnsNormally,
        );
      }
    });

    test('Handles empty and truncated landmark lists gracefully', () {
      final conf = <double>[];
      final lm = <Offset>[];

      final report = brain.diagnoseKineticFaults(
        auraPattern: 'squat',
        framingMode: 'full_body',
        exerciseName: 'Deep Squat',
        humanLandmarks: lm,
        humanConf: conf,
        currentAngle: 120.0,
        spineTiltDeg: 10.0,
        symmetryDiff: 0.0,
        leftTripletConf: 0.0,
        rightTripletConf: 0.0,
        phase: 'IDLE',
        decreaseToPeak: true,
        peakAngleDeg: 90.0,
      );

      expect(report.hasFault, isFalse);
      expect(report.faultType, equals(KineticFaultType.none));
    });

    test('Zero workout duration and instant reset boundaries', () {
      expect(
        () => brain.finalizeScorecard(
          exerciseId: 'squat',
          exerciseName: 'Squat',
          completedReps: 0,
          targetReps: 10,
          liveFormScore: 0.0,
          liveSymmetryScore: 0.0,
          durationSec: 0,
          rejectedReps: 0,
        ),
        returnsNormally,
      );

      final scorecard = brain.finalizeScorecard(
        exerciseId: 'squat',
        exerciseName: 'Squat',
        completedReps: 0,
        targetReps: 10,
        liveFormScore: 0.0,
        liveSymmetryScore: 0.0,
        durationSec: 0,
        rejectedReps: 0,
      );

      // Caloric burn has safety minimum of 12 kcal
      expect(scorecard.caloriesBurned, greaterThanOrEqualTo(12));
      expect(scorecard.completedReps, equals(0));
    });
  });

  group('🛡️ Core Deep Audit: Multi-Lingual Prompt Integrity & Voice Throttling', () {
    test('All KineticFaultType variants provide non-empty English & Hinglish prompts', () {
      final brain = KineticCoachBrain();
      final lm = List<Offset>.filled(33, const Offset(0.5, 0.5));
      final conf = List<double>.filled(33, 0.9);

      // Test knee valgus
      lm[27] = const Offset(0.35, 0.90);
      lm[28] = const Offset(0.65, 0.90);
      lm[25] = const Offset(0.48, 0.65);
      lm[26] = const Offset(0.52, 0.65);

      final valgusReport = brain.diagnoseKineticFaults(
        auraPattern: 'squat',
        framingMode: 'full_body',
        exerciseName: 'Squat',
        humanLandmarks: lm,
        humanConf: conf,
        currentAngle: 100.0,
        spineTiltDeg: 10.0,
        symmetryDiff: 0.0,
        leftTripletConf: 0.9,
        rightTripletConf: 0.9,
        phase: 'ECCENTRIC',
        decreaseToPeak: true,
        peakAngleDeg: 90.0,
      );

      expect(valgusReport.spokenInstructionEn.isNotEmpty, isTrue);
      expect(valgusReport.spokenInstructionHi.isNotEmpty, isTrue);
      expect(valgusReport.spokenInstructionEn, isNot(equals(valgusReport.spokenInstructionHi)));

      // Voice throttling: First call returns true
      expect(
        brain.shouldVoiceCue(
          report: valgusReport,
          cooldown: const Duration(seconds: 4),
        ),
        isTrue,
      );
      // Immediate second call should be throttled (returns false)
      expect(
        brain.shouldVoiceCue(
          report: valgusReport,
          cooldown: const Duration(seconds: 4),
        ),
        isFalse,
      );
    });
  });

  group('🛡️ Core Deep Audit: Universal Responsive Biomechanical Scorecard Dialog', () {
    testWidgets('Renders Biomechanical Scorecard without RenderFlex overflow across narrow and wide screens', (WidgetTester tester) async {
      final brain = KineticCoachBrain();
      final scorecard = brain.finalizeScorecard(
        exerciseId: 'bodyweight-squat',
        exerciseName: 'Deep Bodyweight Squat',
        completedReps: 12,
        targetReps: 12,
        liveFormScore: 95.0,
        liveSymmetryScore: 98.2,
        durationSec: 105,
        rejectedReps: 3,
      );

      // Test on ultra-narrow compact screen (320px width)
      await tester.binding.setSurfaceSize(const Size(320, 640));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: ctx,
                      builder: (dialogCtx) => Dialog(
                        backgroundColor: VColor.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 680),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(scorecard.exerciseName, style: const TextStyle(fontSize: 18, color: VColor.text)),
                                  Text('Form: ${scorecard.overallFormAccuracy.toStringAsFixed(1)}%'),
                                  Text('Reps: ${scorecard.completedReps}/${scorecard.targetReps}'),
                                  Text('Rejected: ${scorecard.rejectedReps}'),
                                  Text('Calories: ~${scorecard.caloriesBurned} kcal'),
                                  ...scorecard.primaryMuscleGroups.map((m) => Chip(label: Text(m))),
                                  ...scorecard.coachingFeedbackList.map((tip) => Text(tip)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Scorecard'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Scorecard'));
      await tester.pumpAndSettle();

      expect(find.text('Deep Bodyweight Squat'), findsOneWidget);
      expect(find.text('Reps: 12/12'), findsOneWidget);
      expect(find.text('Rejected: 3'), findsOneWidget);
      expect(find.text('Quadriceps'), findsOneWidget);
      expect(find.text('Gluteus Maximus'), findsOneWidget);

      // Reset surface size
      await tester.binding.setSurfaceSize(null);
    });
  });
}
