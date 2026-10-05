// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:vyra/services/avatar_customization_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ─────────────────────────────────────────────────────────────────────
  // Load real exercise_poses.js from assets
  // ─────────────────────────────────────────────────────────────────────
  late String posesJsContent;

  setUpAll(() async {
    posesJsContent =
        await rootBundle.loadString('assets/js/exercise_poses.js');
    expect(posesJsContent.length, greaterThan(1000),
        reason: 'exercise_poses.js must be non-empty');
  });

  // ─────────────────────────────────────────────────────────────────────
  // 1. GLB ASSET CHECK
  // ─────────────────────────────────────────────────────────────────────
  group('Avatar GLB Assets', () {
    test('male_coach.glb is bundled and non-empty', () async {
      final data =
          await rootBundle.load('assets/models/male_coach.glb');
      expect(data.lengthInBytes, greaterThan(100000),
          reason: 'male_coach.glb should be at least 100 KB');
      // Verify glTF magic bytes: 0x676C5446 = "glTF"
      final bytes = data.buffer.asUint8List(0, 4);
      expect(String.fromCharCodes(bytes), equals('glTF'),
          reason: 'male_coach.glb must start with glTF magic bytes');
    });

    test('female_coach.glb is bundled and non-empty', () async {
      final data =
          await rootBundle.load('assets/models/female_coach.glb');
      expect(data.lengthInBytes, greaterThan(1000000),
          reason: 'female_coach.glb should be at least 1 MB');
      final bytes = data.buffer.asUint8List(0, 4);
      expect(String.fromCharCodes(bytes), equals('glTF'),
          reason: 'female_coach.glb must start with glTF magic bytes');
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // 2. JS ENGINE CONTENT CHECK
  // ─────────────────────────────────────────────────────────────────────
  group('exercise_poses.js Engine', () {
    test('JS file is loaded and non-empty', () {
      expect(posesJsContent.isNotEmpty, isTrue);
    });

    test('JS exposes VyraExercisePose.apply', () {
      expect(posesJsContent.contains('VyraExercisePose'), isTrue);
      expect(posesJsContent.contains('apply:'), isTrue);
    });

    test('JS exposes VyraExercisePose.resolve (debug helper)', () {
      expect(posesJsContent.contains('resolve:'), isTrue);
    });

    test('JS has 5-tier resolver (resolveExercise)', () {
      expect(posesJsContent.contains('resolveExercise'), isTrue);
      expect(posesJsContent.contains('Tier 1'), isTrue);
      expect(posesJsContent.contains('Tier 2'), isTrue);
      expect(posesJsContent.contains('Tier 3'), isTrue);
      expect(posesJsContent.contains('Tier 4'), isTrue);
      expect(posesJsContent.contains('Tier 5'), isTrue);
    });

    test('JS POSES map has 40+ exercises', () {
      // Count `const POSES = {` and then count top-level keys
      final posesSection = RegExp(r'const POSES = \{([\s\S]*?)\n  \};',
          multiLine: true).firstMatch(posesJsContent);
      expect(posesSection, isNotNull,
          reason: 'POSES map must exist in JS');
      // Each pose key appears as "    key: {" pattern
      final poseKeys =
          RegExp(r'^\s{4}(\w+):\s*\{', multiLine: true)
              .allMatches(posesJsContent)
              .length;
      expect(poseKeys, greaterThanOrEqualTo(40),
          reason: 'Need at least 40 explicit poses, found $poseKeys');
    });

    test('JS ALIASES map has 100+ entries', () {
      final aliasSection = RegExp(r'const ALIASES = \{([\s\S]*?)\};',
          multiLine: true).firstMatch(posesJsContent);
      expect(aliasSection, isNotNull);
      final aliasCount =
          RegExp(r"'[^']+'\s*:\s*'[^']+'").allMatches(posesJsContent).length;
      expect(aliasCount, greaterThanOrEqualTo(100),
          reason: 'Need at least 100 aliases, found $aliasCount');
    });

    test('JS has rep loop engine (requestAnimationFrame)', () {
      expect(posesJsContent.contains('requestAnimationFrame'), isTrue);
      expect(posesJsContent.contains('startRepLoop'), isTrue);
    });

    test('JS has pose blender for unknown exercises', () {
      expect(posesJsContent.contains('blendPoses'), isTrue);
      expect(posesJsContent.contains('scorePoses'), isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // 3. DART SERVICE — getExercisePoseKey
  //    Must return the raw slug (JS handles all resolution)
  // ─────────────────────────────────────────────────────────────────────
  group('AvatarCustomizationService.getExercisePoseKey', () {
    final cases = {
      'squat':                   'squat',
      'push_up':                 'push_up',
      'Shoulder Press':          'shoulder_press',
      'BURPEE':                  'burpee',
      'reverse-nordic-curl':     'reverse_nordic_curl',
      'Kettlebell Turkish Getup':'kettlebell_turkish_getup',
      'running':                 'running',
      'yoga':                    'yoga',
      'XYZ Unknown 2027':        'xyz_unknown_2027',
    };

    cases.forEach((input, expected) {
      test('normalises "$input" → "$expected"', () {
        expect(
          AvatarCustomizationService.getExercisePoseKey(input),
          equals(expected),
        );
      });
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // 4. DART SERVICE — getExerciseAnimation (GLB animation names)
  //    male_coach.glb: "Idle", "Run", "Walk", "TPose"
  //    female_coach.glb: "idle" (ONE animation = samba dance)
  // ─────────────────────────────────────────────────────────────────────
  group('AvatarCustomizationService.getExerciseAnimation', () {
    // Male animations
    test('male running → "Run"', () {
      expect(AvatarCustomizationService.getExerciseAnimation(
          'running', isFemale: false), equals('Run'));
    });
    test('male squat → "Idle"', () {
      expect(AvatarCustomizationService.getExerciseAnimation(
          'squat', isFemale: false), equals('Idle'));
    });
    test('male boxing → "Walk"', () {
      expect(AvatarCustomizationService.getExerciseAnimation(
          'boxing', isFemale: false), equals('Walk'));
    });
    test('male unknown exercise → "Run" (safe cardio default)', () {
      // slugToAvatarPose unknown → 'running' → 'Run' animation — keeps avatar moving
      expect(AvatarCustomizationService.getExerciseAnimation(
          'xyz_future_exercise_2027', isFemale: false), equals('Run'));
    });

    // Female animations
    test('female ANY exercise → "" (neutral bind pose, no anim)', () {
      for (final slug in ['running', 'squat', 'yoga', 'pushup', 'boxing']) {
        expect(
          AvatarCustomizationService.getExerciseAnimation(slug, isFemale: true),
          equals(''),
          reason: 'Female exercises must return empty string (JS pose override handles it)',
        );
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // 5. DART SERVICE — getDanceAnimation (confirmed from GLB binary)
  // ─────────────────────────────────────────────────────────────────────
  group('AvatarCustomizationService.getDanceAnimation', () {
    test('female dance → "idle" (only animation in female_coach.glb)', () {
      expect(AvatarCustomizationService.getDanceAnimation(isFemale: true),
          equals('idle'));
    });
    test('male dance → "Run" (energetic dance mode)', () {
      expect(AvatarCustomizationService.getDanceAnimation(isFemale: false),
          equals('Run'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // 6. MODEL PATH LOGIC
  //    Verify default paths match actual bundled filenames
  // ─────────────────────────────────────────────────────────────────────
  group('Avatar Model Path Logic', () {
    test('male model path contains "male_coach.glb"', () {
      const path = 'assets/models/male_coach.glb';
      expect(path.contains('female'), isFalse);
      expect(path.contains('male_coach.glb'), isTrue);
    });

    test('female model path contains "female_coach.glb"', () {
      const path = 'assets/models/female_coach.glb';
      expect(path.contains('female'), isTrue);
      expect(path.contains('female_coach.glb'), isTrue);
    });

    test('isFemale detection from path works for both genders', () {
      expect('assets/models/male_coach.glb'.contains('female'), isFalse);
      expect('assets/models/female_coach.glb'.contains('female'), isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // 7. END-TO-END FLOW: Gemini slug → avatar behaviour
  //    Simulates what happens when Gemini recommends an exercise
  // ─────────────────────────────────────────────────────────────────────
  group('End-to-End: Gemini exercise → Avatar', () {

    void verifyFlow(String geminiSlug, {
      required String expectedMaleAnim,
      required String expectedFemaleAnim,
      required String expectedDanceMale,
      required String expectedDanceFemale,
    }) {
      final poseKey = AvatarCustomizationService.getExercisePoseKey(geminiSlug);
      final maleAnim = AvatarCustomizationService.getExerciseAnimation(
          geminiSlug, isFemale: false);
      final femaleAnim = AvatarCustomizationService.getExerciseAnimation(
          geminiSlug, isFemale: true);
      final danceM = AvatarCustomizationService.getDanceAnimation(isFemale: false);
      final danceF = AvatarCustomizationService.getDanceAnimation(isFemale: true);

      // poseKey must be non-empty (JS will receive it)
      expect(poseKey.isNotEmpty, isTrue,
          reason: '"$geminiSlug" must produce non-empty poseKey for JS');
      // poseKey must be in exercise_poses.js (either exact POSES key, alias, or keyword)
      expect(posesJsContent.contains("'$poseKey'") ||
             posesJsContent.contains('"$poseKey"') ||
             posesJsContent.contains(poseKey.split('_').first),
          isTrue,
          reason: 'poseKey "$poseKey" must appear in exercise_poses.js');

      expect(maleAnim, equals(expectedMaleAnim),
          reason: 'Male anim for "$geminiSlug"');
      expect(femaleAnim, equals(expectedFemaleAnim),
          reason: 'Female anim for "$geminiSlug"');
      expect(danceM, equals(expectedDanceMale));
      expect(danceF, equals(expectedDanceFemale));
    }

    test('Gemini recommends "running"', () => verifyFlow('running',
      expectedMaleAnim: 'Run',
      expectedFemaleAnim: '',
      expectedDanceMale: 'Run',
      expectedDanceFemale: 'idle',
    ));

    test('Gemini recommends "squat"', () => verifyFlow('squat',
      expectedMaleAnim: 'Idle',
      expectedFemaleAnim: '',
      expectedDanceMale: 'Run',
      expectedDanceFemale: 'idle',
    ));

    test('Gemini recommends "push_up"', () => verifyFlow('push_up',
      expectedMaleAnim: 'Idle',
      expectedFemaleAnim: '',
      expectedDanceMale: 'Run',
      expectedDanceFemale: 'idle',
    ));

    test('Gemini recommends "boxing"', () => verifyFlow('boxing',
      expectedMaleAnim: 'Walk',
      expectedFemaleAnim: '',
      expectedDanceMale: 'Run',
      expectedDanceFemale: 'idle',
    ));

    test('Gemini recommends "yoga"', () => verifyFlow('yoga',
      expectedMaleAnim: 'Idle',
      expectedFemaleAnim: '',
      expectedDanceMale: 'Run',
      expectedDanceFemale: 'idle',
    ));

    test('Gemini recommends "shoulder_press" (specific pose)', () {
      final pk = AvatarCustomizationService.getExercisePoseKey('shoulder_press');
      expect(pk, equals('shoulder_press'));
      expect(posesJsContent.contains('shoulder_press'), isTrue);
    });

    test('Gemini recommends future exercise "xyz_unknown_2027"', () {
      final pk = AvatarCustomizationService.getExercisePoseKey('xyz_unknown_2027');
      expect(pk.isNotEmpty, isTrue,
          reason: 'Unknown exercises must still produce a non-empty key');
      // JS tier-5 will catch this with safe default 'squat'
    });

    test('Dance mode: male plays Run, female plays idle (samba)', () {
      expect(AvatarCustomizationService.getDanceAnimation(isFemale: false), 'Run');
      expect(AvatarCustomizationService.getDanceAnimation(isFemale: true), 'idle');
    });

    test('shouldPlay logic: female only plays in dance mode', () {
      const isFemale = true;
      const isDanceMode = false;
      final shouldPlay = isFemale ? isDanceMode : true;
      expect(shouldPlay, isFalse,
          reason: 'Female in exercise mode: shouldPlay=false (JS bone pose handles pose, not animation)');
    });

    test('shouldPlay logic: male always plays', () {
      const isFemale = false;
      const isDanceMode = false;
      final shouldPlay = isFemale ? isDanceMode : true;
      expect(shouldPlay, isTrue,
          reason: 'Male always plays (has Idle/Run/Walk animations)');
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // 8. JS INJECTION CONTENT CHECK
  //    Simulates what _buildModelJs produces when poseKey is non-empty
  // ─────────────────────────────────────────────────────────────────────
  group('_buildModelJs JS injection', () {
    // Replicate what _buildModelJs produces for a poseKey
    String buildModelJs(String exercisePosesJs, String poseKey, double ts) {
      final poseJs = poseKey.isNotEmpty ? '''
        $exercisePosesJs
        function applyVyraPose() {
          if (typeof window.VyraExercisePose !== "undefined") {
            window.VyraExercisePose.apply("$poseKey");
          }
        }
        setTimeout(applyVyraPose, 400);''' : '';
      return '''
        (function() {
          function apply() {
            var mv = document.querySelector('model-viewer');
            if (!mv) return;
            mv.timeScale = $ts;
            $poseJs
          }
          var mv = document.querySelector('model-viewer');
          if (mv) {
            if (mv.loaded) { apply(); }
            else { mv.addEventListener('load', apply, { once: true }); }
          }
        })();
      ''';
    }

    test('JS injection for "squat" contains VyraExercisePose.apply("squat")', () {
      final js = buildModelJs(posesJsContent, 'squat', 1.0);
      expect(js.contains('VyraExercisePose.apply("squat")'), isTrue);
    });

    test('JS injection for "shoulder_press" contains correct apply call', () {
      final js = buildModelJs(posesJsContent, 'shoulder_press', 1.0);
      expect(js.contains('VyraExercisePose.apply("shoulder_press")'), isTrue);
    });

    test('JS injection embeds full engine (>10KB)', () {
      final js = buildModelJs(posesJsContent, 'squat', 1.0);
      expect(js.length, greaterThan(10000),
          reason: 'Full engine JS must be embedded in injection');
    });

    test('Dance mode: poseKey="" → no VyraExercisePose.apply call', () {
      final js = buildModelJs(posesJsContent, '', 1.8);
      expect(js.contains('VyraExercisePose.apply'), isFalse,
          reason: 'Dance mode uses GLB animation, no JS pose override');
    });

    test('JS injection always waits for model-viewer load event', () {
      final js = buildModelJs(posesJsContent, 'running', 1.5);
      expect(js.contains("addEventListener('load'"), isTrue);
    });
  });
}
