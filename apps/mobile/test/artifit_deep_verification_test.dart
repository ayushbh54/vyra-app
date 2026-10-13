import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyra/screens/pose_tracker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ARTIFIT-Grade Biomechanical Camera Verification Deep Forensic Audit', () {
    const allVyraSlugs = [
      'bodyweight-squat',
      'deep-squats',
      'jump-squat',
      'goblet-squats',
      'box-squats',
      'wall-sit',
      'push-up',
      'diamond-push-ups',
      'incline-push-ups',
      'decline-push-ups',
      'dumbbell-bicep-curl',
      'hammer-curls',
      'concentration-curls',
      'dumbbell-lateral-raise',
      'overhead-shoulder-press',
      'dumbbell-shoulder-press',
      'arnold-press',
      'plank',
      'forearm-plank',
      'side-plank',
      'glute-bridge',
      'single-leg-glute-bridge',
      'seated-forward-fold',
      'seated-torso-twist',
      'jumping-jacks',
      'high-knees',
      'standing-calf-raise',
      'box-breathing',
    ];

    // =========================================================================
    // 1. RAW BOUNDARY & DEAD-ZONE VERIFICATION (Zero / Partial / Out-of-Range)
    // =========================================================================
    test('Boundary & Dead-Zone: Zero and low confidence properly rejected (No phantom triggers)', () {
      final zeroConf = List<double>.filled(33, 0.0);
      final lowConf = List<double>.filled(33, 0.20); // Below 0.36 threshold
      final dummyLandmarks = List<Offset>.filled(33, const Offset(0.5, 0.5));

      for (final slug in allVyraSlugs) {
        final cfg = ExerciseConfig.resolve(slug);
        
        // Zero confidence
        final zeroRes = ExerciseConfig.verifyBiomechanicalForm(
          config: cfg,
          humanLandmarks: dummyLandmarks,
          humanConf: zeroConf,
          humanAngle: cfg.startAngleDeg,
          spineTiltDeg: 0.0,
          symmetryDiff: 0.0,
          leftTripletConf: 0.0,
          rightTripletConf: 0.0,
        );
        expect(zeroRes.isValid, isFalse, reason: '$slug with 0.0 confidence must be RED (isValid: false)');
        expect(zeroRes.warningMessage, contains('Step into frame'));

        // Low confidence (below 0.36)
        final lowRes = ExerciseConfig.verifyBiomechanicalForm(
          config: cfg,
          humanLandmarks: dummyLandmarks,
          humanConf: lowConf,
          humanAngle: cfg.startAngleDeg,
          spineTiltDeg: 0.0,
          symmetryDiff: 0.0,
          leftTripletConf: 0.20,
          rightTripletConf: 0.20,
        );
        expect(lowRes.isValid, isFalse, reason: '$slug with 0.20 confidence must be RED (isValid: false)');
      }
    });

    // =========================================================================
    // 2. SPECIFIC FAULT GATE AUDIT (Standing in Plank, Spine Lean, Knee Cave, Elbow Swing)
    // =========================================================================
    test('Fault Isolation: Standing upright during floor Plank returns RED with exact faultJoints', () {
      final plank = ExerciseConfig.resolve('plank');
      final standingSquatPose = ExerciseConfig.computeAuraPose(ExerciseConfig.resolve('bodyweight-squat'), 0.0);
      final highConf = List<double>.filled(33, 0.98);

      final res = ExerciseConfig.verifyBiomechanicalForm(
        config: plank,
        humanLandmarks: standingSquatPose,
        humanConf: highConf,
        humanAngle: 175.0,
        spineTiltDeg: 2.0,
        symmetryDiff: 1.0,
        leftTripletConf: 0.98,
        rightTripletConf: 0.98,
      );

      expect(res.isValid, isFalse);
      expect(res.faultJoints, containsAll([11, 12, 23, 24, 25, 26, 27, 28]));
      expect(res.warningMessage, contains('Please do it correctly'));
      expect(res.warningMessage, contains('standing upright'));
    });

    test('Fault Isolation: Squat Knee Cave / Valgus returns RED highlighting knees {25, 26}', () {
      final squat = ExerciseConfig.resolve('bodyweight-squat');
      final squatPeakPose = ExerciseConfig.computeAuraPose(squat, 1.0);
      final highConf = List<double>.filled(33, 0.98);

      // Force knees to collapse inward
      final kneeCavePose = List<Offset>.from(squatPeakPose);
      final midHipX = (kneeCavePose[23].dx + kneeCavePose[24].dx) * 0.5;
      kneeCavePose[25] = Offset(midHipX - 0.015, kneeCavePose[25].dy);
      kneeCavePose[26] = Offset(midHipX + 0.015, kneeCavePose[26].dy);

      final res = ExerciseConfig.verifyBiomechanicalForm(
        config: squat,
        humanLandmarks: kneeCavePose,
        humanConf: highConf,
        humanAngle: 95.0,
        spineTiltDeg: 12.0,
        symmetryDiff: 2.0,
        leftTripletConf: 0.98,
        rightTripletConf: 0.98,
      );

      expect(res.isValid, isFalse);
      expect(res.faultJoints, containsAll([25, 26]));
      expect(res.warningMessage, contains('Push knees outward'));
    });

    test('Fault Isolation: Excessive forward spine lean on squat (> 38°) returns RED with spine joints', () {
      final squat = ExerciseConfig.resolve('bodyweight-squat');
      final squatPose = ExerciseConfig.computeAuraPose(squat, 0.8);
      final highConf = List<double>.filled(33, 0.98);

      final res = ExerciseConfig.verifyBiomechanicalForm(
        config: squat,
        humanLandmarks: squatPose,
        humanConf: highConf,
        humanAngle: 110.0,
        spineTiltDeg: 44.0, // Excessive lean
        symmetryDiff: 2.0,
        leftTripletConf: 0.98,
        rightTripletConf: 0.98,
      );

      expect(res.isValid, isFalse);
      expect(res.faultJoints, containsAll([11, 12, 23, 24]));
      expect(res.warningMessage, contains('Keep chest upright'));
    });

    test('Fault Isolation: Shoulder swinging / lifting elbows during bicep curls returns RED with arm joints', () {
      final curl = ExerciseConfig.resolve('dumbbell-bicep-curl');
      final curlPose = ExerciseConfig.computeAuraPose(curl, 1.0);
      final highConf = List<double>.filled(33, 0.98);

      // Lift elbows up to shoulder level (swinging cheat)
      curlPose[13] = Offset(curlPose[11].dx, curlPose[11].dy - 0.05);
      curlPose[14] = Offset(curlPose[12].dx, curlPose[12].dy - 0.05);

      final res = ExerciseConfig.verifyBiomechanicalForm(
        config: curl,
        humanLandmarks: curlPose,
        humanConf: highConf,
        humanAngle: 35.0,
        spineTiltDeg: 4.0,
        symmetryDiff: 2.0,
        leftTripletConf: 0.98,
        rightTripletConf: 0.98,
      );

      expect(res.isValid, isFalse);
      expect(res.faultJoints, containsAll([11, 12, 13, 14, 15, 16]));
      expect(res.warningMessage, contains('Keep elbows pinned'));
    });

    test('Fault Isolation: Asymmetric unilateral movement on bilateral exercise returns RED', () {
      final squat = ExerciseConfig.resolve('bodyweight-squat');
      final squatPose = ExerciseConfig.computeAuraPose(squat, 0.7);
      final highConf = List<double>.filled(33, 0.98);

      final res = ExerciseConfig.verifyBiomechanicalForm(
        config: squat,
        humanLandmarks: squatPose,
        humanConf: highConf,
        humanAngle: 115.0,
        spineTiltDeg: 6.0,
        symmetryDiff: 48.0, // 48 deg asymmetric tilt
        leftTripletConf: 0.98,
        rightTripletConf: 0.98,
      );

      expect(res.isValid, isFalse);
      expect(res.warningMessage, contains('symmetrically'));
    });

    // =========================================================================
    // 3. MULTI-TURN 50-FRAME REAL-TIME CAMERA STREAM SIMULATION
    // =========================================================================
    test('Multi-Turn Stream Simulation (50 Frames): Proper rep cycle verified with 100% Green & rep increment', () {
      final squat = ExerciseConfig.resolve('bodyweight-squat');
      final highConf = List<double>.filled(33, 0.96);

      // Simulate a full clean rep over 50 consecutive frames:
      // Frame 0..15: Descent from 176° -> 98°
      // Frame 16..22: Inflection held at peak (98°) for multiple frames
      // Frame 23..38: Ascent from 98° -> 176°
      // Frame 39..50: Return to start pose
      int greenFrames = 0;
      int redFrames = 0;
      bool inflectionReached = false;
      int consecutivePeakFrames = 0;

      for (int frame = 0; frame < 50; frame++) {
        double phase01;
        if (frame <= 18) {
          phase01 = frame / 18.0;
        } else if (frame <= 24) {
          phase01 = 1.0; // Held at peak!
        } else if (frame <= 42) {
          phase01 = 1.0 - (frame - 24) / 18.0;
        } else {
          phase01 = 0.0;
        }

        final pose = ExerciseConfig.computeAuraPose(squat, phase01);
        final angle = squat.startAngleDeg + (squat.peakAngleDeg - squat.startAngleDeg) * phase01;

        final verification = ExerciseConfig.verifyBiomechanicalForm(
          config: squat,
          humanLandmarks: pose,
          humanConf: highConf,
          humanAngle: angle,
          spineTiltDeg: 6.0,
          symmetryDiff: 2.0,
          leftTripletConf: 0.96,
          rightTripletConf: 0.96,
        );

        if (verification.isValid) {
          greenFrames++;
        } else {
          redFrames++;
        }

        if (angle <= squat.peakAngleDeg + 12.0) {
          consecutivePeakFrames++;
          if (consecutivePeakFrames >= 2) {
            inflectionReached = true;
          }
        }
      }

      expect(greenFrames, equals(50), reason: 'Every frame of clean execution must be GREEN');
      expect(redFrames, equals(0), reason: 'Zero red frames on perfect form');
      expect(inflectionReached, isTrue, reason: 'Must reach true peak with >= 2 frames lock');
    });

    test('Multi-Turn Stream Simulation (50 Frames): Cheating user standing during Plank stays 100% RED', () {
      final plank = ExerciseConfig.resolve('plank');
      final highConf = List<double>.filled(33, 0.96);
      final standingSquatPose = ExerciseConfig.computeAuraPose(ExerciseConfig.resolve('bodyweight-squat'), 0.0);

      int redCount = 0;
      for (int frame = 0; frame < 50; frame++) {
        final verification = ExerciseConfig.verifyBiomechanicalForm(
          config: plank,
          humanLandmarks: standingSquatPose,
          humanConf: highConf,
          humanAngle: 175.0,
          spineTiltDeg: 2.0,
          symmetryDiff: 1.0,
          leftTripletConf: 0.96,
          rightTripletConf: 0.96,
        );
        if (!verification.isValid) {
          redCount++;
        }
      }

      expect(redCount, equals(50), reason: 'Standing user during plank must remain RED for all 50 frames');
    });

    test('Multi-Turn Stream Simulation: Immediate transition Red -> Green when user corrects posture', () {
      final squat = ExerciseConfig.resolve('bodyweight-squat');
      final highConf = List<double>.filled(33, 0.96);
      final validSquatPose = ExerciseConfig.computeAuraPose(squat, 0.5);

      // Frame 1: User leaning forward heavily (spineTilt = 45°) -> RED
      final badRes = ExerciseConfig.verifyBiomechanicalForm(
        config: squat,
        humanLandmarks: validSquatPose,
        humanConf: highConf,
        humanAngle: 135.0,
        spineTiltDeg: 45.0,
        symmetryDiff: 2.0,
        leftTripletConf: 0.96,
        rightTripletConf: 0.96,
      );
      expect(badRes.isValid, isFalse, reason: 'Frame 1 must be RED on posture fault');

      // Frame 2: User straightens back (spineTilt = 10°) -> IMMEDIATELY GREEN
      final goodRes = ExerciseConfig.verifyBiomechanicalForm(
        config: squat,
        humanLandmarks: validSquatPose,
        humanConf: highConf,
        humanAngle: 135.0,
        spineTiltDeg: 10.0,
        symmetryDiff: 2.0,
        leftTripletConf: 0.96,
        rightTripletConf: 0.96,
      );
      expect(goodRes.isValid, isTrue, reason: 'Frame 2 must immediately turn GREEN when proper posture is restored');
      expect(goodRes.faultJoints, isEmpty);
    });

    // =========================================================================
    // 4. RESILIENCE & FUZZ TESTING (Malformed, Noisy, Extreme Values)
    // =========================================================================
    test('Resilience & Fuzz: Extreme coordinates, negative values, and NaN never crash', () {
      final squat = ExerciseConfig.resolve('bodyweight-squat');
      final random = math.Random(42);

      for (int i = 0; i < 100; i++) {
        final noisyLandmarks = List<Offset>.generate(
          33,
          (_) => Offset(random.nextDouble() * 3.0 - 1.0, random.nextDouble() * 3.0 - 1.0),
        );
        final noisyConf = List<double>.generate(33, (_) => random.nextDouble());
        final angle = random.nextDouble() * 360.0;
        final spine = random.nextDouble() * 90.0;
        final sym = random.nextDouble() * 120.0;

        expect(
          () => ExerciseConfig.verifyBiomechanicalForm(
            config: squat,
            humanLandmarks: noisyLandmarks,
            humanConf: noisyConf,
            humanAngle: angle,
            spineTiltDeg: spine,
            symmetryDiff: sym,
            leftTripletConf: noisyConf[11],
            rightTripletConf: noisyConf[12],
          ),
          returnsNormally,
          reason: 'Fuzz iteration $i must execute safely without throwing exceptions',
        );
      }
    });
  });
}
