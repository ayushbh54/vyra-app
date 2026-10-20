import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyra/services/avatar_customization_service.dart';
import 'package:vyra/services/exercise_animation_registry.dart';
import 'package:vyra/screens/pose_tracker.dart';

double _angle2d(Offset a, Offset b, Offset c) {
  final bax = a.dx - b.dx;
  final bay = a.dy - b.dy;
  final bcx = c.dx - b.dx;
  final bcy = c.dy - b.dy;
  final dot = bax * bcx + bay * bcy;
  final magA = math.sqrt(bax * bax + bay * bay);
  final magB = math.sqrt(bcx * bcx + bcy * bcy);
  if (magA < 1e-6 || magB < 1e-6) return 180.0;
  final cosVal = (dot / (magA * magB)).clamp(-1.0, 1.0);
  return math.acos(cosVal) * 180.0 / math.pi;
}

double _activeAuraAngle(ExerciseConfig cfg, List<Offset> aura) {
  final l = _angle2d(
    aura[cfg.leftTriplet[0].index],
    aura[cfg.leftTriplet[1].index],
    aura[cfg.leftTriplet[2].index],
  );
  final r = _angle2d(
    aura[cfg.rightTriplet[0].index],
    aura[cfg.rightTriplet[1].index],
    aura[cfg.rightTriplet[2].index],
  );
  return cfg.decreaseToPeak ? math.min(l, r) : math.max(l, r);
}

void main() {
  const allVyraSlugs = <String>[
    // Face & Jaw (Mobile + Backend)
    'cheek-lift',
    'jaw-release',
    'brow-smoother',
    'neck-firming-lift',
    'eye-circle-relax',
    'scalp-massage',
    'lions-breath',
    // Desk & Chair
    'seated-spinal-twist',
    'chair-dips',
    'seated-leg-extension',
    'desk-shoulder-rolls',
    'seated-calf-raises',
    'wrist-finger-stretch',
    'seated-neck-glide',
    'chair-squats',
    'seated-shoulder-press',
    'seated-overhead-press',
    // Cardio & Fat Burn (Mobile + Backend Gemini Pool)
    'high-knees',
    'mountain-climbers',
    'skater-hops',
    'butt-kicks',
    'fast-feet-shuffle',
    'step-jacks',
    'burpee',
    'burpees',
    'jumping-jacks',
    'march-in-place',
    'seated-march',
    'tabata-squat-thrust',
    'hiit-interval-beginner',
    'zumba-basic-flow',
    // Strength & Conditioning
    'push-up',
    'knee-push-up',
    'incline-push-up',
    'wall-push-up',
    'diamond-push-up',
    'pike-push-up',
    'bodyweight-squat',
    'sumo-squat',
    'split-squat',
    'wall-sit',
    'reverse-lunge',
    'walking-lunge',
    'step-up',
    'glute-bridge',
    'single-leg-glute-bridge',
    'calf-raise',
    'resistance-band-row',
    'bent-over-row',
    'arm-circles',
    'overhead-reach',
    'dumbbell-goblet-squat',
    'dumbbell-romanian-deadlift',
    'dumbbell-bench-press',
    'dumbbell-one-arm-row',
    'dumbbell-overhead-press',
    'dumbbell-bicep-curl',
    'lateral-raise',
    'bicep-curl',
    'tricep-dip',
    'tricep-dips',
    // Core & Posture
    'plank',
    'forearm-plank',
    'side-plank',
    'dead-bug',
    'bird-dog',
    'seated-knee-lift',
    'standing-oblique-crunch',
    'cat-cow',
    'pelvic-tilt',
    'seated-torso-twist',
    // Yoga, Mobility & Recovery
    'sun-salutation-flow',
    'downward-dog',
    'child-pose',
    'childs-pose',
    'seated-forward-fold',
    'tree-pose',
    'tai-chi-opening-form',
    'warrior-ii',
    'chair-pose',
    'cobra-pose',
    'cobra-stretch',
    'bridge-pose',
    'supine-twist',
    'legs-up-wall',
    'neck-release',
    'shoulder-pendulum',
    'thoracic-open-book',
    'hip-flexor-stretch',
    'hamstring-hinge-stretch',
    'ankle-circles',
    'wrist-mobility',
    // Breathwork & Mindfulness (Mobile + Backend Gemini Pool)
    'box-breathing',
    'four-seven-eight',
    'four-seven-eight-breath',
    'anulom-vilom',
    'body-scan',
    'breath-awareness',
    'sleep-prep',
    'diaphragmatic-breathing',
    'coherent-breathing',
    'physiological-sigh',
    'alternate-nostril-breath',
    'ujjayi-breath',
    'pursed-lip-breathing',
    'humming-bee-breath',
    'morning-energizing-breath',
  ];

  group('Name-Wise 3D Exercise Animation & Pose Resolution Tests', () {
    test('All 98+ VYRA & Gemini exercise slugs resolve to valid non-empty pose keys', () {
      for (final slug in allVyraSlugs) {
        final poseKey = AvatarCustomizationService.getExercisePoseKey(slug);
        expect(poseKey.isNotEmpty, isTrue, reason: 'Slug $slug returned empty poseKey');
      }
    });

    test('No substring collision on crunch, box-breathing, or box-squat', () {
      expect(
        AvatarCustomizationService.getExerciseAnimation('standing-oblique-crunch', isFemale: false),
        equals(''),
      );
      expect(
        AvatarCustomizationService.slugToAvatarPose('standing-oblique-crunch'),
        isNot(equals('running')),
      );
      expect(
        AvatarCustomizationService.slugToAvatarPose('box-breathing'),
        equals('yoga'),
      );
      expect(
        AvatarCustomizationService.getExercisePoseKey('box-breathing'),
        equals('box_breathing'),
      );
      expect(AvatarCustomizationService.getExerciseAnimation('run', isFemale: false), equals('Run'));
      expect(AvatarCustomizationService.getExerciseAnimation('walk', isFemale: false), equals('Walk'));
      expect(AvatarCustomizationService.getExerciseAnimation('push-up', isFemale: false), equals(''));
      expect(AvatarCustomizationService.getExerciseAnimation('bodyweight-squat', isFemale: false), equals(''));
      expect(AvatarCustomizationService.getExerciseAnimation('jumping-jacks', isFemale: false), equals(''));
    });

    test('ExerciseAnimationRegistry stays in sync with AvatarCustomizationService', () {
      for (final slug in allVyraSlugs) {
        final cfg = ExerciseAnimationRegistry.getConfig(slug, isFemale: false);
        expect(cfg.mode, equals(AnimationMode.poseMode),
            reason: 'Slug $slug should use poseMode so exercise_poses.js v5.0 drives bones');
        expect(cfg.poseNote.isNotEmpty, isTrue);
      }
    });
  });

  group('AI Selfie Camera Pose Tracker ExerciseConfig & Gemini System Verification Tests', () {
    test('All 98+ Backend, Gemini AI & Mobile exercise slugs resolve to accurate biomechanical tracking configs', () {
      for (final slug in allVyraSlugs) {
        final cfg = ExerciseConfig.resolve(slug, customTitle: slug);
        expect(cfg.id.isNotEmpty, isTrue);
        expect(cfg.defaultReps > 0, isTrue, reason: 'Slug $slug has invalid defaultReps');
        expect(cfg.cueDown.isNotEmpty, isTrue, reason: 'Slug $slug has empty cueDown');
        expect(cfg.cueUp.isNotEmpty, isTrue, reason: 'Slug $slug has empty cueUp');
        expect(cfg.auraPattern.isNotEmpty, isTrue, reason: 'Slug $slug has empty auraPattern');
      }
    });

    test('Gemini AI dynamic exercise titles & specialized workouts map to exact biomechanical archetypes without collisions', () {
      // Squat & Lunge
      expect(ExerciseConfig.resolve('bodyweight-squat').auraPattern, equals('squat'));
      expect(ExerciseConfig.resolve('tabata-squat-thrust').auraPattern, equals('squat'));
      expect(ExerciseConfig.resolve('reverse-lunge').auraPattern, equals('lunge'));
      expect(ExerciseConfig.resolve('hip-flexor-stretch').auraPattern, equals('lunge'));

      // Posterior Hinge vs Glute Bridge
      expect(ExerciseConfig.resolve('seated-forward-fold').auraPattern, equals('hinge_fold'));
      expect(ExerciseConfig.resolve('dumbbell-romanian-deadlift').auraPattern, equals('hinge_fold'));
      expect(ExerciseConfig.resolve('hamstring-hinge-stretch').auraPattern, equals('hinge_fold'));
      expect(ExerciseConfig.resolve('glute-bridge').auraPattern, equals('bridge'));
      expect(ExerciseConfig.resolve('cat-cow').auraPattern, equals('bridge'));
      expect(ExerciseConfig.resolve('cobra-pose').auraPattern, equals('bridge'));

      // Core Twist, Dead-Bug & Bird-Dog (Must NOT fall back to squat!)
      expect(ExerciseConfig.resolve('seated-torso-twist').auraPattern, equals('torso_twist'));
      expect(ExerciseConfig.resolve('dead-bug').auraPattern, equals('torso_twist'));
      expect(ExerciseConfig.resolve('bird-dog').auraPattern, equals('torso_twist'));
      expect(ExerciseConfig.resolve('standing-oblique-crunch').auraPattern, equals('torso_twist'));
      expect(ExerciseConfig.resolve('thoracic-open-book').auraPattern, equals('torso_twist'));

      // Breathwork & Mindfulness (Must use upper_body breath_hold, NOT wall-sit knee bend!)
      for (final breathSlug in [
        'box-breathing',
        'four-seven-eight',
        'anulom-vilom',
        'lions-breath',
        'body-scan',
        'breath-awareness',
        'sleep-prep',
      ]) {
        final cfg = ExerciseConfig.resolve(breathSlug);
        expect(cfg.isHold, isTrue, reason: '$breathSlug should be a hold');
        expect(cfg.framingMode, equals('upper_body'), reason: '$breathSlug should use upper_body framing');
        expect(cfg.auraPattern, equals('breath_hold'), reason: '$breathSlug should use breath_hold aura');
      }

      // Dynamic Gemini AI custom slugs resolved via customTitle
      final geminiCustom1 = ExerciseConfig.resolve('gemini-rx-01', customTitle: 'Explosive Reverse Lunge');
      expect(geminiCustom1.auraPattern, equals('lunge'));
      final geminiCustom2 = ExerciseConfig.resolve('gemini-rx-02', customTitle: 'Evening Anulom Vilom Pranayama');
      expect(geminiCustom2.auraPattern, equals('breath_hold'));
      final geminiCustom3 = ExerciseConfig.resolve('gemini-rx-03', customTitle: 'Seated Thoracic Twist');
      expect(geminiCustom3.auraPattern, equals('torso_twist'));
    });

    test('Every single one of the 98+ exercises physically reaches startAngleDeg and peakAngleDeg in its AR Moving Aura and counts 5/5 reps or holds', () {
      const double tol = 3.5;

      for (final slug in allVyraSlugs) {
        final cfg = ExerciseConfig.resolve(slug, customTitle: slug);
        final auraStart = ExerciseConfig.computeAuraPose(cfg, 0.0, anchorX: 0.50, anchorY: 0.44, scale: 1.0, motionCycle: 0.5);
        final auraPeak = ExerciseConfig.computeAuraPose(cfg, 1.0, anchorX: 0.50, anchorY: 0.44, scale: 1.0, motionCycle: 0.5);

        final startMeasured = _activeAuraAngle(cfg, auraStart);
        final peakMeasured = _activeAuraAngle(cfg, auraPeak);

        if (cfg.isHold) {
          final inHoldZone = cfg.decreaseToPeak
              ? peakMeasured <= cfg.peakAngleDeg + 16.0
              : peakMeasured >= cfg.peakAngleDeg - 16.0;
          expect(
            inHoldZone,
            isTrue,
            reason: 'Hold exercise $slug (${cfg.auraPattern}) peakMeasured=$peakMeasured not in hold zone around ${cfg.peakAngleDeg}',
          );
        } else {
          // Verify start pose satisfies startAngleDeg and peak pose satisfies peakAngleDeg
          if (cfg.decreaseToPeak) {
            expect(
              startMeasured,
              greaterThanOrEqualTo(cfg.startAngleDeg - tol),
              reason: '$slug (${cfg.auraPattern}) start angle $startMeasured < ${cfg.startAngleDeg - tol}',
            );
            expect(
              peakMeasured,
              lessThanOrEqualTo(cfg.peakAngleDeg + tol),
              reason: '$slug (${cfg.auraPattern}) peak angle $peakMeasured > ${cfg.peakAngleDeg + tol}',
            );
          } else {
            expect(
              startMeasured,
              lessThanOrEqualTo(cfg.startAngleDeg + tol),
              reason: '$slug (${cfg.auraPattern}) start angle $startMeasured > ${cfg.startAngleDeg + tol}',
            );
            expect(
              peakMeasured,
              greaterThanOrEqualTo(cfg.peakAngleDeg - tol),
              reason: '$slug (${cfg.auraPattern}) peak angle $peakMeasured < ${cfg.peakAngleDeg - tol}',
            );
          }

          // Simulate 5 complete human-follows-Aura cycles (0.0 -> 1.0 -> 0.0) through the state machine
          int repsCounted = 0;
          bool reachedInflection = false;
          for (int rep = 0; rep < 5; rep++) {
            for (final phase in [0.0, 0.25, 0.5, 0.75, 1.0, 0.75, 0.5, 0.25, 0.0]) {
              final aura = ExerciseConfig.computeAuraPose(
                cfg,
                phase,
                motionCycle: rep.isEven ? 0.5 : -0.5,
              );
              final angle = _activeAuraAngle(cfg, aura);
              if (cfg.decreaseToPeak) {
                if (angle <= cfg.peakAngleDeg + tol) {
                  reachedInflection = true;
                } else if (angle >= cfg.startAngleDeg - tol && reachedInflection) {
                  reachedInflection = false;
                  repsCounted++;
                }
              } else {
                if (angle >= cfg.peakAngleDeg - tol) {
                  reachedInflection = true;
                } else if (angle <= cfg.startAngleDeg + tol && reachedInflection) {
                  reachedInflection = false;
                  repsCounted++;
                }
              }
            }
          }
          expect(
            repsCounted,
            equals(5),
            reason: 'Exercise $slug (${cfg.auraPattern}) counted $repsCounted/5 reps when following AR Aura',
          );
        }
      }
    });

    test('Mid-Torso 1:1 Aura Anchor locks shoulders and hips directly onto human body coordinates', () {
      final squat = ExerciseConfig.resolve('bodyweight-squat');
      final aura = ExerciseConfig.computeAuraPose(squat, 0.0, anchorX: 0.50, anchorY: 0.44, scale: 1.0);
      final midShoulder = (aura[11] + aura[12]) * 0.5;
      final midHip = (aura[23] + aura[24]) * 0.5;
      final midTorso = (midShoulder + midHip) * 0.5;

      expect((midTorso.dx - 0.50).abs(), lessThan(0.005));
      expect((midTorso.dy - 0.45).abs(), lessThan(0.015));
      expect((midShoulder.dy - 0.34).abs(), lessThan(0.01));
      expect((midHip.dy - 0.56).abs(), lessThan(0.01));
    });

    test('Human-to-Aura Matching: Synchronized human scores >= 95% while Stationary human at peak drops < 55% (Zero Phantom Reps)', () {
      final highConf = List<double>.filled(33, 0.95);

      for (final slug in allVyraSlugs) {
        final cfg = ExerciseConfig.resolve(slug, customTitle: slug);

        // 1. Synchronized Human moving WITH the Aura across phases 0.0 -> 0.5 -> 1.0
        for (final phase in [0.0, 0.50, 1.0]) {
          final auraPose = ExerciseConfig.computeAuraPose(cfg, phase);
          final targetAngle = cfg.startAngleDeg + (cfg.peakAngleDeg - cfg.startAngleDeg) * phase;
          final syncScore = ExerciseConfig.computeAuraMatch(
            config: cfg,
            humanLandmarks: auraPose,
            humanConf: highConf,
            auraLandmarks: auraPose,
            humanAngle: targetAngle,
            auraTargetAngle: targetAngle,
          );
          expect(
            syncScore,
            greaterThanOrEqualTo(95.0),
            reason: 'Synchronized human on $slug at phase $phase should score >= 95%, got $syncScore',
          );
        }

        // 2. Stationary Human standing still at start pose (phase 0.0) while Aura reaches peak (phase 1.0)
        if (!cfg.isHold) {
          final humanStandingStill = ExerciseConfig.computeAuraPose(cfg, 0.0);
          final auraAtPeak = ExerciseConfig.computeAuraPose(cfg, 1.0);
          final stationaryScoreAtPeak = ExerciseConfig.computeAuraMatch(
            config: cfg,
            humanLandmarks: humanStandingStill,
            humanConf: highConf,
            auraLandmarks: auraAtPeak,
            humanAngle: cfg.startAngleDeg,
            auraTargetAngle: cfg.peakAngleDeg,
          );
          expect(
            stationaryScoreAtPeak,
            lessThan(55.0),
            reason: 'Stationary human on $slug when Aura is at peak must score < 55% to prevent phantom reps, got $stationaryScoreAtPeak',
          );
        }
      }
    });

    testWidgets('PoseTrackerScreen renders AR Moving Aura HUD, 5-Zone Lock Bar, and verifies multi-turn Aura reps', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PoseTrackerScreen(
            exerciseName: 'bodyweight-squat',
            initialExerciseSlug: 'bodyweight-squat',
            initialExerciseName: 'Bodyweight Squat',
            targetReps: 5,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('HEAD'), findsOneWidget);
      expect(find.text('SHLDR'), findsOneWidget);
      expect(find.text('ARMS'), findsOneWidget);
      expect(find.text('CORE'), findsOneWidget);
      expect(find.text('LEGS'), findsOneWidget);
      expect(find.text('AURA SYNC'), findsOneWidget);
      expect(find.text('Start AR Tracking'), findsOneWidget);

      await tester.tap(find.text('AR Live'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Assisted'), findsOneWidget);

      await tester.tap(find.text('Start AR Tracking'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Pause'), findsOneWidget);

      for (int i = 0; i < 95; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('0'), findsNothing);
    });

    test('4-Stage Closed-Loop Avatar Engine v6.0 & Persistent Setup Cache + Unique Bundle ID verification', () {
      final jsFile = File('assets/js/exercise_poses.js');
      expect(jsFile.existsSync(), isTrue);
      final jsContent = jsFile.readAsStringSync();

      // Verify v6.0 4-Stage Closed-Loop Architecture components
      expect(jsContent, contains("var ENGINE_VERSION = '6.0.0';"));
      expect(jsContent, contains("var CACHE_PREFIX = 'vyra_verified_setup_v6_';"));
      expect(jsContent, contains('var GLB_BIND_META = {'));
      expect(jsContent, contains('function loadVerifiedSetupFromCache(rigId, poseName)'));
      expect(jsContent, contains('function saveVerifiedSetupToCache(rigId, poseName, setupObj)'));
      expect(jsContent, contains('function evaluateBlueprintPoseFK(rigMeta, charPoseMap)'));
      expect(jsContent, contains('function buildAndVerifySetup(rigId, poseName, spec)'));
      expect(jsContent, contains('function qSlerp(qa, qb, t)'));
      expect(jsContent, contains('function mirrorCharacterPose(poseMap)'));
      expect(jsContent, contains('function evaluateVerifiedFrame(verifiedSetup, rigOrder, elapsedSec)'));
      expect(jsContent, contains('simulateStream: function (slug, rigId, framesCount, durationSec)'));

      // Verify Unique App Bundle Identifier (com.ayush.vyra.fitness) & Version (2.0.0+6)
      final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
      expect(pbxproj, contains('PRODUCT_BUNDLE_IDENTIFIER = com.ayush.vyra.fitness;'));
      expect(pbxproj.contains('PRODUCT_BUNDLE_IDENTIFIER = com.ayush.vyra;'), isFalse);

      final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(infoPlist, contains('<string>VYRA Fitness</string>'));

      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('version: 2.0.0+8'));
    });

    test('ARTIFIT 5-Gate Biomechanical Form Verification: Valid form = Green (isValid: true), Wrong form = Red (isValid: false) with exact faultJoints & warning', () {
      final highConf = List<double>.filled(33, 0.95);

      // 1. Valid form across all exercises -> Green AR points (isValid: true)
      for (final slug in allVyraSlugs) {
        final cfg = ExerciseConfig.resolve(slug, customTitle: slug);
        final validPhases = cfg.isHold ? const [1.0] : const [0.0, 0.5, 1.0];
        for (final phase in validPhases) {
          final validPose = ExerciseConfig.computeAuraPose(cfg, phase);
          final angle = cfg.startAngleDeg + (cfg.peakAngleDeg - cfg.startAngleDeg) * phase;
          final res = ExerciseConfig.verifyBiomechanicalForm(
            config: cfg,
            humanLandmarks: validPose,
            humanConf: highConf,
            humanAngle: angle,
            spineTiltDeg: 5.0,
            symmetryDiff: 2.0,
            leftTripletConf: 0.95,
            rightTripletConf: 0.95,
          );
          expect(
            res.isValid,
            isTrue,
            reason: 'Valid posture for $slug at phase $phase must be Green (isValid: true), got warning: ${res.warningMessage}',
          );
          expect(res.faultJoints, isEmpty);
        }
      }

      // 2. Wrong Form: Standing upright during Floor Plank -> Red AR points (isValid: false)
      final plankCfg = ExerciseConfig.resolve('plank', customTitle: 'Plank');
      final standingPose = ExerciseConfig.computeAuraPose(
        ExerciseConfig.resolve('bodyweight-squat'),
        0.0,
      );
      final standingInPlankRes = ExerciseConfig.verifyBiomechanicalForm(
        config: plankCfg,
        humanLandmarks: standingPose,
        humanConf: highConf,
        humanAngle: 175.0,
        spineTiltDeg: 4.0,
        symmetryDiff: 2.0,
        leftTripletConf: 0.95,
        rightTripletConf: 0.95,
      );
      expect(standingInPlankRes.isValid, isFalse);
      expect(standingInPlankRes.warningMessage, contains('Please do it correctly'));
      expect(standingInPlankRes.faultJoints, containsAll([11, 12, 23, 24]));

      // 3. Wrong Form: Excessive Spine Tilt during Squat -> Red AR points (isValid: false)
      final squatCfg = ExerciseConfig.resolve('bodyweight-squat', customTitle: 'Bodyweight Squat');
      final validSquatPeak = ExerciseConfig.computeAuraPose(squatCfg, 1.0);
      final leaningSquatRes = ExerciseConfig.verifyBiomechanicalForm(
        config: squatCfg,
        humanLandmarks: validSquatPeak,
        humanConf: highConf,
        humanAngle: 90.0,
        spineTiltDeg: 48.0, // Excessive lean > 38 deg
        symmetryDiff: 2.0,
        leftTripletConf: 0.95,
        rightTripletConf: 0.95,
      );
      expect(leaningSquatRes.isValid, isFalse);
      expect(leaningSquatRes.warningMessage, contains('Please do it correctly'));
      expect(leaningSquatRes.faultJoints, containsAll([11, 12, 23, 24]));

      // 4. Wrong Form: Squat Knee Cave / Valgus -> Red AR points on knees {25, 26}
      final kneeCavePose = List<Offset>.from(validSquatPeak);
      final midHipX = (kneeCavePose[23].dx + kneeCavePose[24].dx) * 0.5;
      kneeCavePose[25] = Offset(midHipX - 0.01, kneeCavePose[25].dy);
      kneeCavePose[26] = Offset(midHipX + 0.01, kneeCavePose[26].dy);
      final kneeCaveRes = ExerciseConfig.verifyBiomechanicalForm(
        config: squatCfg,
        humanLandmarks: kneeCavePose,
        humanConf: highConf,
        humanAngle: 90.0,
        spineTiltDeg: 8.0,
        symmetryDiff: 2.0,
        leftTripletConf: 0.95,
        rightTripletConf: 0.95,
      );
      expect(kneeCaveRes.isValid, isFalse);
      expect(kneeCaveRes.faultJoints, containsAll([25, 26]));

      // 5. Wrong Form: Swinging elbows above shoulders during Bicep Curl -> Red AR points
      final curlCfg = ExerciseConfig.resolve('bicep-curl', customTitle: 'Bicep Curl');
      final badCurlPose = ExerciseConfig.computeAuraPose(curlCfg, 1.0);
      badCurlPose[13] = Offset(badCurlPose[11].dx, badCurlPose[11].dy - 0.12); // Left elbow lifted above shoulder
      final badCurlRes = ExerciseConfig.verifyBiomechanicalForm(
        config: curlCfg,
        humanLandmarks: badCurlPose,
        humanConf: highConf,
        humanAngle: 55.0,
        spineTiltDeg: 5.0,
        symmetryDiff: 2.0,
        leftTripletConf: 0.95,
        rightTripletConf: 0.95,
      );
      expect(badCurlRes.isValid, isFalse);
      expect(badCurlRes.faultJoints, containsAll([11, 12, 13, 14]));

      // 6. Wrong Form: Uneven Bilateral Movement (Moving only left arm on Push-up/Curl) -> Red AR points
      final validCurlPose = ExerciseConfig.computeAuraPose(curlCfg, 1.0);
      final unevenRes = ExerciseConfig.verifyBiomechanicalForm(
        config: curlCfg,
        humanLandmarks: validCurlPose,
        humanConf: highConf,
        humanAngle: 55.0,
        spineTiltDeg: 5.0,
        symmetryDiff: 105.0, // Right arm not curling at all!
        leftTripletConf: 0.95,
        rightTripletConf: 0.95,
      );
      expect(unevenRes.isValid, isFalse);
      expect(unevenRes.warningMessage, contains('symmetrically'));

      // 7. Recovery to Valid Range -> Immediately returns to Green (isValid: true)
      final recoveredRes = ExerciseConfig.verifyBiomechanicalForm(
        config: curlCfg,
        humanLandmarks: validCurlPose,
        humanConf: highConf,
        humanAngle: 55.0,
        spineTiltDeg: 5.0,
        symmetryDiff: 2.0,
        leftTripletConf: 0.95,
        rightTripletConf: 0.95,
      );
      expect(recoveredRes.isValid, isTrue);
      expect(recoveredRes.faultJoints, isEmpty);
    });
  });
}


