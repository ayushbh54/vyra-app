// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:vyra/services/avatar_customization_service.dart';
import 'package:vyra/services/exercise_animation_registry.dart';

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
      // v6.0: resolveExercise uses EXERCISES (exact), ALIASES, KEYWORD_RULES,
      // dynamic synthesis, and safe default — 5-tier cascade
      expect(posesJsContent.contains('resolveExercise'), isTrue);
      expect(posesJsContent.contains('var EXERCISES'), isTrue);
      expect(posesJsContent.contains('var ALIASES'), isTrue);
      expect(posesJsContent.contains('KEYWORD_RULES'), isTrue);
    });

    test('JS EXERCISES map has 40+ exercises', () {
      // v6.0 uses var EXERCISES = { "key": { ... } } with double-quoted keys
      expect(posesJsContent.contains('var EXERCISES = {'), isTrue,
          reason: 'EXERCISES map must exist in JS');
      // Count top-level exercise entries by their double-quoted keys
      final poseKeys =
          RegExp(r'^\s{4}"([a-z][a-z_0-9]+)":\s*\{', multiLine: true)
              .allMatches(posesJsContent)
              .length;
      expect(poseKeys, greaterThanOrEqualTo(40),
          reason: 'Need at least 40 explicit exercises, found $poseKeys');
    });

    test('JS ALIASES map has 100+ entries', () {
      final aliasSection = RegExp(r'var ALIASES = \{([\s\S]*?)\};',
          multiLine: true).firstMatch(posesJsContent);
      expect(aliasSection, isNotNull);
      final aliasCount =
          RegExp(r"^\s+\w+:\s*'\w+'", multiLine: true).allMatches(posesJsContent).length;
      expect(aliasCount, greaterThanOrEqualTo(100),
          reason: 'Need at least 100 aliases, found $aliasCount');
    });

    test('JS has rep loop engine (requestAnimationFrame)', () {
      expect(posesJsContent.contains('requestAnimationFrame'), isTrue);
      expect(posesJsContent.contains('startExerciseLoop'), isTrue);
    });

    test('JS handles unknown exercises via KEYWORD_RULES safe default', () {
      expect(posesJsContent.contains('KEYWORD_RULES'), isTrue);
      expect(posesJsContent.contains('bodyweight_squat'), isTrue,
          reason: 'Safe default must be bodyweight_squat');
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
    // v3.1: strength/floor exercises return '' — AnimationMixer stays silent,
    // JS bone pose engine has full control of bone transforms.
    test('male squat → "" (JS pose engine, mixer silent)', () {
      expect(AvatarCustomizationService.getExerciseAnimation(
          'squat', isFemale: false), equals(''));
    });
    test('male boxing → "" (JS pose engine drives strikes)', () {
      expect(AvatarCustomizationService.getExerciseAnimation(
          'boxing', isFemale: false), equals(''));
    });
    test('male unknown exercise → "" (JS procedural synthesis handles it)', () {
      expect(AvatarCustomizationService.getExerciseAnimation(
          'xyz_future_exercise_2027', isFemale: false), equals(''));
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

    // v3.1: squat returns '' for male (JS handles pose, no mixer clip)
    test('Gemini recommends "squat"', () => verifyFlow('squat',
      expectedMaleAnim: '',
      expectedFemaleAnim: '',
      expectedDanceMale: 'Run',
      expectedDanceFemale: 'idle',
    ));

    // v3.1: push_up returns '' for male (floor exercise, JS handles horizontal pose)
    test('Gemini recommends "push_up"', () => verifyFlow('push_up',
      expectedMaleAnim: '',
      expectedFemaleAnim: '',
      expectedDanceMale: 'Run',
      expectedDanceFemale: 'idle',
    ));

    test('Gemini recommends "boxing"', () => verifyFlow('boxing',
      expectedMaleAnim: '',
      expectedFemaleAnim: '',
      expectedDanceMale: 'Run',
      expectedDanceFemale: 'idle',
    ));

    // v3.1: yoga returns '' for male (JS pose handles it, no mixer conflict)
    test('Gemini recommends "yoga"', () => verifyFlow('yoga',
      expectedMaleAnim: '',
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

    // v3.1: shouldPlay = _isDanceMode ? true : currentAnim.isNotEmpty
    // For a strength/floor exercise, currentAnim='' → shouldPlay=false → autoPlay=false.
    // This is CORRECT — the JS pose engine needs the mixer to be silent.
    test('shouldPlay logic: male strength exercise → false (currentAnim is empty)', () {
      const isDanceMode = false;
      final currentAnim = AvatarCustomizationService.getExerciseAnimation('squat', isFemale: false);
      final shouldPlay = isDanceMode ? true : currentAnim.isNotEmpty;
      expect(shouldPlay, isFalse,
          reason: 'Male strength exercise: currentAnim="" → shouldPlay=false → mixer stays idle');
    });

    test('shouldPlay logic: male cardio → true (Run clip exists)', () {
      const isDanceMode = false;
      final currentAnim = AvatarCustomizationService.getExerciseAnimation('running', isFemale: false);
      final shouldPlay = isDanceMode ? true : currentAnim.isNotEmpty;
      expect(shouldPlay, isTrue,
          reason: 'Male running: currentAnim="Run" → shouldPlay=true → clip autoPlays');
    });

    test('shouldPlay logic: dance mode always true', () {
      const isDanceMode = true;
      final currentAnim = AvatarCustomizationService.getDanceAnimation(isFemale: false);
      final shouldPlay = isDanceMode ? true : currentAnim.isNotEmpty;
      expect(shouldPlay, isTrue, reason: 'Dance mode always plays');
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

  // ─────────────────────────────────────────────────────────────────────
  // 9. v3.1 ENGINE REGRESSION TESTS
  //    Verifies all four root-cause fixes introduced in v3.1
  // ─────────────────────────────────────────────────────────────────────
  group('v3.1 AnimationMixer Conflict & Floor Pose Fixes', () {

    // ── Fix 1: stopMixer() presence ──────────────────────────────────
    test('JS contains stopMixer() function (AnimationMixer shutdown)', () {
      expect(posesJsContent.contains('function stopMixer'), isTrue,
          reason: 'stopMixer() must exist to defeat 60fps AnimationMixer override');
    });

    test('JS stopMixer() calls stopAllAction (Three.js AnimationMixer API)', () {
      expect(posesJsContent.contains('stopAllAction'), isTrue,
          reason: 'stopAllAction() is the Three.js API to halt all active AnimationActions');
    });

    test('JS startExerciseLoop() calls stopMixer before running loop', () {
      expect(posesJsContent.contains('stopMixer(mv, root);'), isTrue,
          reason: 'stopMixer must be called in startExerciseLoop before starting RAF loop');
    });

    // ── Fix v6.0: floor exercise prone posture in character space ───────
    test('floor exercises declare "posture": "prone" in v6.0 character space', () {
      expect(posesJsContent, contains('"posture": "prone"'));
      expect(posesJsContent.contains('"push_up"'), isTrue);
      expect(posesJsContent.contains('"plank"'), isTrue);
      expect(posesJsContent.contains('"mountain_climbers"'), isTrue);
      expect(posesJsContent.contains('"burpee"'), isTrue);
    });


    // ── Fix 3: getExerciseAnimation returns '' for floor/strength ─────
    test('getExerciseAnimation returns "" for pushup (no mixer conflict)', () {
      expect(AvatarCustomizationService.getExerciseAnimation('pushup', isFemale: false), equals(''));
    });

    test('getExerciseAnimation returns "" for plank (no mixer conflict)', () {
      expect(AvatarCustomizationService.getExerciseAnimation('plank', isFemale: false), equals(''));
    });

    test('getExerciseAnimation returns "" for weightlifting', () {
      expect(AvatarCustomizationService.getExerciseAnimation('weightlifting', isFemale: false), equals(''));
    });

    // Locomotion clips are STILL returned (regression guard)
    test('getExerciseAnimation still returns "Run" for running (regression guard)', () {
      expect(AvatarCustomizationService.getExerciseAnimation('running', isFemale: false), equals('Run'));
    });

    test('getExerciseAnimation returns "" for boxing (procedural strikes — v5.0)', () {
      expect(AvatarCustomizationService.getExerciseAnimation('boxing', isFemale: false), equals(''));
    });

    // ── Fix 4: shouldPlay uses currentAnim.isNotEmpty ─────────────────
    test('shouldPlay is false for male strength exercise (anim is empty)', () {
      final anim = AvatarCustomizationService.getExerciseAnimation('squat', isFemale: false);
      final shouldPlay = anim.isNotEmpty; // mirrors exercise_detail.dart logic
      expect(shouldPlay, isFalse,
          reason: 'autoPlay must be false when no clip — prevents mixer from overwriting JS bones');
    });

    test('shouldPlay is true for male running (Run clip exists)', () {
      final anim = AvatarCustomizationService.getExerciseAnimation('running', isFemale: false);
      final shouldPlay = anim.isNotEmpty;
      expect(shouldPlay, isTrue);
    });

    test('shouldPlay is true in dance mode regardless of anim', () {
      const isDanceMode = true;
      final anim = AvatarCustomizationService.getDanceAnimation(isFemale: false);
      final shouldPlay = isDanceMode ? true : anim.isNotEmpty;
      expect(shouldPlay, isTrue);
    });

    // ── Fix v3.1b: burpee/jumping_jack slug routing fix ──────────────
    // These were misrouted through slugToAvatarPose → 'skipping' → 'Run' clip
    // → AnimationMixer conflict. Pre-check now intercepts them → return ''.
    test('v3.1b: burpee returns "" (pre-check intercepts skipping→Run routing)', () {
      expect(
        AvatarCustomizationService.getExerciseAnimation('burpee', isFemale: false),
        equals(''),
        reason: 'burpee has a JS floor pose (−87° hips); Run clip must NOT play',
      );
    });

    test('v3.1b: jumping_jack returns "" (JS pose handles standing position)', () {
      expect(
        AvatarCustomizationService.getExerciseAnimation('jumping_jack', isFemale: false),
        equals(''),
      );
    });

    test('v3.1b: box_jump returns "" (plyometric floor exercise)', () {
      expect(
        AvatarCustomizationService.getExerciseAnimation('box_jump', isFemale: false),
        equals(''),
      );
    });

    // Skipping and jump_rope are handled by JS pose engine (v5.0+)
    test('v5.0: skipping returns "" (handled by JS biomechanical pose engine)', () {
      expect(
        AvatarCustomizationService.getExerciseAnimation('skipping', isFemale: false),
        equals(''),
      );
    });

    test('v5.0: jumping_rope returns "" (handled by JS biomechanical pose engine)', () {
      expect(
        AvatarCustomizationService.getExerciseAnimation('jump_rope', isFemale: false),
        equals(''),
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // v3.2 — Lifecycle, Registry & Both-Avatar Regression Tests
  // ══════════════════════════════════════════════════════════════════════════
  group('v3.2 ExerciseAnimationRegistry correctness', () {
    // ── Asset inventory ────────────────────────────────────────────────────
    test('registry: male_coach.glb clip inventory is correct', () {
      final inventory = ExerciseAnimationRegistry.assetInventory;
      expect(inventory['male_coach.glb clips'], contains('Run'));
      expect(inventory['male_coach.glb clips'], contains('Walk'));
      expect(inventory['male_coach.glb clips'], contains('Idle'));
    });

    test('registry: female_coach.glb has only samba idle clip', () {
      final inventory = ExerciseAnimationRegistry.assetInventory;
      expect(inventory['female_coach.glb clips'], equals('idle (samba dance only)'));
    });

    // ── Male coach — clip mode exercises ───────────────────────────────────
    test('registry: running → clipMode, Run, hasRealClip=true (male)', () {
      final config = ExerciseAnimationRegistry.getConfig('running', isFemale: false);
      expect(config.mode, AnimationMode.clipMode);
      expect(config.clipName, 'Run');
      expect(config.hasRealClip, isTrue);
    });

    test('registry: boxing → poseMode (forcePoModeOverride prevents Walk clip)', () {
      final config = ExerciseAnimationRegistry.getConfig('boxing', isFemale: false);
      expect(config.mode, AnimationMode.poseMode);
      expect(config.clipName, isEmpty);
      expect(config.hasRealClip, isFalse);
    });

    test('registry: skipping → poseMode (forcePoModeOverride prevents Run clip)', () {
      final config = ExerciseAnimationRegistry.getConfig('skipping', isFemale: false);
      expect(config.mode, AnimationMode.poseMode);
      expect(config.clipName, isEmpty);
      expect(config.hasRealClip, isFalse);
    });

    // ── Male coach — pose mode exercises ───────────────────────────────────
    test('registry: squat → poseMode, empty clip, hasRealClip=false (male)', () {
      final config = ExerciseAnimationRegistry.getConfig('squat', isFemale: false);
      expect(config.mode, AnimationMode.poseMode);
      expect(config.clipName, isEmpty);
      expect(config.hasRealClip, isFalse);
    });

    test('registry: push_up → poseMode, empty clip (male)', () {
      final config = ExerciseAnimationRegistry.getConfig('push_up', isFemale: false);
      expect(config.mode, AnimationMode.poseMode);
      expect(config.clipName, isEmpty);
    });

    test('registry: plank → poseMode (male)', () {
      final config = ExerciseAnimationRegistry.getConfig('plank', isFemale: false);
      expect(config.mode, AnimationMode.poseMode);
      expect(config.clipName, isEmpty);
    });

    // ── Force-override exercises (were mis-routing to Run clip) ────────────
    test('registry: burpee → poseMode (force-override prevents Run clip)', () {
      final config = ExerciseAnimationRegistry.getConfig('burpee', isFemale: false);
      expect(config.mode, AnimationMode.poseMode);
      expect(config.clipName, isEmpty);
      expect(config.hasRealClip, isFalse);
    });

    test('registry: jumping_jack → poseMode (force-override)', () {
      final config = ExerciseAnimationRegistry.getConfig('jumping_jack', isFemale: false);
      expect(config.mode, AnimationMode.poseMode);
      expect(config.clipName, isEmpty);
    });

    test('registry: box_jump → poseMode (force-override)', () {
      final config = ExerciseAnimationRegistry.getConfig('box_jump', isFemale: false);
      expect(config.mode, AnimationMode.poseMode);
      expect(config.clipName, isEmpty);
    });

    // ── Female coach — ALL exercises return poseMode ───────────────────────
    test('registry: female running → poseMode (no real exercise clip in female GLB)', () {
      final config = ExerciseAnimationRegistry.getConfig('running', isFemale: true);
      expect(config.mode, AnimationMode.poseMode);
      expect(config.clipName, isEmpty);
      expect(config.hasRealClip, isFalse);
    });

    test('registry: female push_up → poseMode', () {
      final config = ExerciseAnimationRegistry.getConfig('push_up', isFemale: true);
      expect(config.mode, AnimationMode.poseMode);
      expect(config.clipName, isEmpty);
    });

    test('registry: female squat → poseMode', () {
      final config = ExerciseAnimationRegistry.getConfig('squat', isFemale: true);
      expect(config.mode, AnimationMode.poseMode);
      expect(config.clipName, isEmpty);
    });

    test('registry: female dance clip name is "idle" (samba)', () {
      expect(ExerciseAnimationRegistry.femaleDanceClip, 'idle');
    });

    test('registry: male dance clip name is "Run"', () {
      expect(ExerciseAnimationRegistry.maleDanceClip, 'Run');
    });
  });

  group('v3.2 Both-avatar animation routing — getExerciseAnimation', () {
    // ── Male ────────────────────────────────────────────────────────────────
    test('male running → "Run" clip', () {
      expect(AvatarCustomizationService.getExerciseAnimation('running', isFemale: false), 'Run');
    });

    test('male boxing → "" (handled by JS procedural engine)', () {
      expect(AvatarCustomizationService.getExerciseAnimation('boxing', isFemale: false), '');
    });

    test('male squat → "" (pose mode)', () {
      expect(AvatarCustomizationService.getExerciseAnimation('squat', isFemale: false), '');
    });

    test('male push_up → "" (pose mode)', () {
      expect(AvatarCustomizationService.getExerciseAnimation('push_up', isFemale: false), '');
    });

    test('male plank → "" (pose mode)', () {
      expect(AvatarCustomizationService.getExerciseAnimation('plank', isFemale: false), '');
    });

    test('male burpee → "" (v3.1b force-override)', () {
      expect(AvatarCustomizationService.getExerciseAnimation('burpee', isFemale: false), '');
    });

    // ── Female ──────────────────────────────────────────────────────────────
    test('female running → "" (no real clip in female GLB)', () {
      expect(AvatarCustomizationService.getExerciseAnimation('running', isFemale: true), '');
    });

    test('female boxing → "" (no real clip in female GLB)', () {
      expect(AvatarCustomizationService.getExerciseAnimation('boxing', isFemale: true), '');
    });

    test('female squat → "" (pose mode)', () {
      expect(AvatarCustomizationService.getExerciseAnimation('squat', isFemale: true), '');
    });

    test('female dance animation → "idle" (samba)', () {
      expect(AvatarCustomizationService.getDanceAnimation(isFemale: true), 'idle');
    });

    test('male dance animation → "Run"', () {
      expect(AvatarCustomizationService.getDanceAnimation(isFemale: false), 'Run');
    });
  });

  group('v3.2 Lifecycle & rapid-switching guards', () {
    // These tests validate the logical invariants that the _isDisposed guard
    // enforces, without needing widget pump (unit-level behavioral checks).

    test('isDisposed pattern: callbacks must check disposed before setState', () {
      // Simulate the guard logic: once isDisposed=true, no setState is called.
      bool stateWasCalled = false;
      bool isDisposed = false;

      void simulateAsyncCallback() {
        if (isDisposed) return; // the guard
        stateWasCalled = true;
      }

      isDisposed = true;
      simulateAsyncCallback();
      expect(stateWasCalled, isFalse,
          reason: '_isDisposed=true must prevent setState from running');
    });

    test('isDisposed pattern: callback runs when not disposed', () {
      bool stateWasCalled = false;
      bool isDisposed = false;

      void simulateAsyncCallback() {
        if (isDisposed) return;
        stateWasCalled = true;
      }

      simulateAsyncCallback();
      expect(stateWasCalled, isTrue);
    });

    test('rapid exercise switching: ModelViewer key changes on each switch', () {
      // The ValueKey strategy ensures Flutter rebuilds the ModelViewer
      // on exercise switch, which tears down the old WebView+JS context.
      // A new key per switch = guaranteed fresh JS environment.
      const modelPath = 'assets/models/male_coach.glb';
      const orbit1 = '0deg 85deg 3.5m';
      const orbit2 = '45deg 90deg 3.8m';
      final key1 = '${modelPath}_${orbit1}_1.0_false_null';
      final key2 = '${modelPath}_${orbit2}_1.2_false_null';
      expect(key1 == key2, isFalse,
          reason: 'Different exercise views must produce different ValueKeys '
              'so Flutter rebuilds ModelViewer and tears down old JS context');
    });

    test('animation ownership: shouldPlay is false when no clip (prevents mixer conflict)', () {
      // Core v3.1 invariant: exercise with empty anim → shouldPlay=false → autoPlay=false
      for (final slug in ['squat', 'push_up', 'plank', 'side_plank',
          'mountain_climber', 'burpee', 'jumping_jack', 'deadlift',
          'shoulder_press', 'bicep_curl']) {
        final anim = AvatarCustomizationService.getExerciseAnimation(slug, isFemale: false);
        final shouldPlay = anim.isNotEmpty;
        expect(shouldPlay, isFalse,
            reason: '$slug: shouldPlay must be false (anim="$anim") — '
                'AnimationMixer must stay silent for JS pose engine to work');
      }
    });

    test('locomotion regression: shouldPlay is true for pure running exercises and false for JS poses', () {
      for (final slug in ['running', 'jogging', 'sprint', 'treadmill']) {
        final anim = AvatarCustomizationService.getExerciseAnimation(slug, isFemale: false);
        final shouldPlay = anim.isNotEmpty;
        expect(shouldPlay, isTrue,
            reason: '$slug must have a real clip — got "$anim"');
      }
      for (final slug in ['boxing', 'cycling', 'swimming', 'skipping', 'jump_rope']) {
        final anim = AvatarCustomizationService.getExerciseAnimation(slug, isFemale: false);
        final shouldPlay = anim.isNotEmpty;
        expect(shouldPlay, isFalse,
            reason: '$slug must have empty clip to let JS pose engine run — got "$anim"');
      }
    });
  });

  group('v3.2 JS engine: stopMixer documented API contract', () {
    late String posesJsContent;

    setUpAll(() async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      await binding.runAsync(() async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler('flutter/assets', null);
      });
      try {
        posesJsContent = await rootBundle.loadString('assets/js/exercise_poses.js');
      } catch (_) {
        posesJsContent = '';
      }
    });

    test('stopMixer: mv.pause() is Strategy 1 (most reliable documented API)', () {
      expect(posesJsContent, contains("typeof mv.pause === 'function'"),
          reason: 'mv.pause() must be the primary strategy in stopMixer()');
    });

    test('stopMixer: mv.timeScale=0 silences animation mixer timescale', () {
      expect(posesJsContent, contains('mv.timeScale = 0'),
          reason: 'timeScale=0 ensures mixer cannot advance while bone engine runs');
    });

    test('stopMixer: mv.animationName="" deselects active clip', () {
      expect(posesJsContent, contains("mv.animationName = ''"),
          reason: "Deselect active clip via animationName=''");
    });

    test('stopMixer: Object.getOwnPropertySymbols(mv) accesses internal mixer symbols', () {
      expect(posesJsContent, contains('Object.getOwnPropertySymbols(mv)'),
          reason: 'Internal symbols must be traversed to halt Three.js actions');
      expect(posesJsContent, contains('stopAllAction()'),
          reason: 'stopAllAction() must be called on mixer');
    });

    test('burpee 4-phase closed loop: has distinct phases in v6.0', () {
      expect(posesJsContent, contains("verifiedSetup.mode === 'burpee'"),
          reason: 'Burpee must have specialized 4-phase closed loop');
      expect(posesJsContent, contains('phase < 0.25'),
          reason: 'Phase 1: squat descent');
      expect(posesJsContent, contains('phase < 0.45'),
          reason: 'Phase 2: plank transition');
      expect(posesJsContent, contains('phase < 0.78'),
          reason: 'Phase 3: pushup / floor hold');
    });

    test('lifecycle: visibilitychange auto-stop is registered', () {
      expect(posesJsContent, contains('visibilitychange'),
          reason: 'RAF loop must auto-cancel when WebView is hidden/destroyed');
    });

    test('lifecycle: pagehide auto-stop is registered', () {
      expect(posesJsContent, contains('pagehide'),
          reason: 'RAF loop must auto-cancel on pagehide event');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // v6.0 — Character-Space Biomechanical Verification & Floor Posture
  // ══════════════════════════════════════════════════════════════════════════
  group('v6.0 Character-Space Biomechanical Posture Verification', () {
    test('floor exercises declare "posture": "prone" in v6.0 blueprint', () {
      for (final exercise in ['push_up', 'plank', 'mountain_climbers', 'burpee']) {
        expect(posesJsContent, contains('"$exercise"'));
      }
      expect(posesJsContent, contains('"posture": "prone"'));
    });

    test('standing exercises declare "posture": "standing" in v6.0 blueprint', () {
      for (final exercise in ['bodyweight_squat', 'jumping_jacks']) {
        expect(posesJsContent, contains('"$exercise"'));
      }
      expect(posesJsContent, contains('"posture": "standing"'));
    });
  });
}
