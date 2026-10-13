// ignore_for_file: avoid_classes_with_only_static_members

/// VYRA Exercise Animation Registry — Single source of truth for 3D avatar animation.
///
/// Documents exactly which exercise clips are available in each GLB asset,
/// and which exercises use the JS procedural pose engine instead.
///
/// ## GLB Asset Inventory (verified from binary JSON chunk, October 2026)
///
/// ### male_coach.glb (2.1 MB, 68 bones, Mixamo rig)
/// Animation clips:
///   - "Idle"   — default standing idle (do NOT use for exercises — causes mixer conflict)
///   - "Run"    — running/jogging locomotion cycle
///   - "TPose"  — T-pose (calibration only, never use for exercises)
///   - "Walk"   — walking locomotion cycle
///
/// ### female_coach.glb (55.0 MB, 72 bones, Mixamo rig)
/// Animation clips:
///   - "idle"   — samba dance (this is the ONLY animation; used for dance mode)
///
/// ## Animation Modes
///
/// CLIP_MODE: A real GLB animation clip plays via AnimationMixer.
///   → autoPlay=true, animationName=[clip], JS pose engine NOT called.
///
/// POSE_MODE: JS procedural engine (exercise_poses.js) drives all bones at 60fps.
///   → autoPlay=false, animationName='', AnimationMixer MUST be paused.
///
/// DANCE_MODE: Same as CLIP_MODE but triggered by user tapping Dance button.
///
/// ## Missing Assets (required for production exercise accuracy)
/// The following exercises currently use POSE_MODE with Euler approximations.
/// They would require real animation clips baked in Blender/Mixamo to achieve
/// biomechanically accurate movement with correct floor contact:
///
///   squat, push_up, plank, side_plank, mountain_climber,
///   burpee (multi-phase procedural is implemented but not IK-accurate),
///   jumping_jack, deadlift, shoulder_press, bicep_curl, pull_up,
///   yoga poses, pilates, all stretching exercises.
///
/// To add a real clip: export from Mixamo → embed in GLB → add entry to
/// [realClipExercises] → update [getAnimationMode] → remove from [procedurePoseExercises].

library exercise_animation_registry;

/// What animation strategy an exercise uses.
enum AnimationMode {
  /// A real GLB animation clip plays via AnimationMixer.
  clipMode,

  /// JS procedural pose engine (exercise_poses.js) drives bones.
  poseMode,

  /// Dance mode — clip plays regardless of exercise.
  danceMode,
}

/// Describes the animation configuration for a single exercise.
class ExerciseAnimConfig {
  const ExerciseAnimConfig({
    required this.mode,
    required this.clipName,
    required this.hasRealClip,
    required this.poseNote,
  });

  /// Which animation mode is used.
  final AnimationMode mode;

  /// The GLB clip name to pass to ModelViewer (empty string for pose mode).
  final String clipName;

  /// Whether this uses a genuine exercise-specific animation clip.
  /// false = Euler-rotation approximation only.
  final bool hasRealClip;

  /// Human-readable note about the pose implementation.
  final String poseNote;
}

class ExerciseAnimationRegistry {
  ExerciseAnimationRegistry._();

  // ── Real GLB clips — male coach only ────────────────────────────────────

  /// Exercises with a real Run locomotion clip (pure running/jogging only).
  static const Set<String> runClipExercises = {
    'running', 'run', 'jogging', 'jog', 'sprinting', 'sprint', 'treadmill', 'marathon',
  };

  /// Exercises with the Walk clip (pure walking/hiking only).
  static const Set<String> walkClipExercises = {
    'walking', 'walk', 'brisk_walk', 'treadmill_walk', 'hiking', 'hike',
  };

  /// Exercises that previously routed to skipping — now handled by JS v5.0 pose engine
  static const Set<String> skippingClipExercises = {};

  // ── Exercises explicitly intercepted before slugToAvatarPose ───────────

  /// These slugs would mis-route via substring matching,
  /// and have dedicated JS v5.0 biomechanical poses.
  static const Set<String> forcePoModeOverrides = {
    'burpee', 'box_jump', 'jumping_jack', 'jump_squat', 'tuck_jump',
    'crunch', 'march_in_place', 'seated_march', 'high_knees',
    'boxing', 'cycling', 'swimming', 'skipping', 'football', 'cricket',
  };

  // ── Pose-mode exercises (JS procedural, no real clip) ──────────────────

  /// All remaining exercises use JS procedural poses.
  /// This list is informational only — it is not exhaustive. Any slug not
  /// matched by [runClipExercises], [walkClipExercises], or
  /// [skippingClipExercises] falls through to pose mode.
  static const Set<String> procedurePoseExercises = {
    'squat', 'bodyweight_squat', 'goblet_squat', 'wall_sit', 'lunge', 'reverse_lunge',
    'push_up', 'knee_push_up', 'wall_push_up', 'plank', 'side_plank', 'forearm_plank',
    'mountain_climber', 'mountain_climbers', 'burpee', 'burpees', 'jumping_jack', 'jumping_jacks', 'box_jump',
    'deadlift', 'shoulder_press', 'seated_shoulder_press', 'seated_overhead_press',
    'bench_press', 'dumbbell_bench_press', 'overhead_press',
    'bicep_curl', 'dumbbell_bicep_curl', 'tricep_extension', 'tricep_dips', 'pull_up', 'chin_up', 'dip',
    'lat_pulldown', 'cable_row', 'bent_over_row', 'lateral_raise', 'arm_circles',
    'leg_press', 'leg_extension', 'leg_curl', 'calf_raise',
    'glute_bridge', 'hip_thrust', 'fire_hydrant',
    'russian_twist', 'seated_torso_twist', 'leg_raise', 'ab_wheel', 'crunch', 'sit_up',
    'dead_bug', 'bird_dog', 'core_activation',
    'yoga', 'downward_dog', 'warrior_pose', 'cobra_pose', 'child_pose', 'cat_cow',
    'seated_forward_fold', 'tree_pose', 'supine_twist', 'legs_up_wall',
    'lions_breath', 'cheek_lift', 'jaw_release', 'scalp_massage',
    'box_breathing', 'four_seven_eight', 'anulom_vilom', 'body_scan', 'breath_awareness', 'sleep_prep',
    'neck_release', 'wrist_mobility', 'ankle_circles', 'hip_flexor_stretch', 'shoulder_pendulum',
    'tai_chi_opening_form', 'zumba_basic_flow', 'tabata_squat_thrust', 'hiit_interval_beginner',
    'pilates', 'stretching', 'meditation',
    'high_knees', 'march_in_place', 'seated_march', 'butt_kicks', 'step_up',
  };

  // ── Female coach note ────────────────────────────────────────────────────

  /// For female coach, ALL exercises return '' (no clip) because
  /// female_coach.glb contains only one animation: 'idle' (samba dance),
  /// which is reserved exclusively for dance mode.
  static const String femaleExerciseClip = '';
  static const String femaleDanceClip = 'idle';
  static const String maleDanceClip = 'Run';

  /// Returns the full animation configuration for a given exercise slug.
  static ExerciseAnimConfig getConfig(String slug, {required bool isFemale}) {
    if (isFemale) {
      return const ExerciseAnimConfig(
        mode: AnimationMode.poseMode,
        clipName: '',
        hasRealClip: false,
        poseNote: 'Female coach: driven by JS v5.0 2-phase biomechanical pose engine.',
      );
    }

    final s = slug.toLowerCase().replaceAll(RegExp(r'[\s\-]+'), '_').trim();
    final tokens = s.split('_').where((t) => t.isNotEmpty).toSet();

    if (forcePoModeOverrides.any((k) => s.contains(k))) {
      return ExerciseAnimConfig(
        mode: AnimationMode.poseMode,
        clipName: '',
        hasRealClip: false,
        poseNote: '$slug: dedicated JS v5.0 biomechanical 2-keyframe pose.',
      );
    }

    if (runClipExercises.contains(s) ||
        (tokens.intersection(runClipExercises).isNotEmpty && !s.contains('crunch') && !s.contains('trunk'))) {
      return const ExerciseAnimConfig(
        mode: AnimationMode.clipMode,
        clipName: 'Run',
        hasRealClip: true,
        poseNote: 'Real Run locomotion clip from male_coach.glb.',
      );
    }

    if (walkClipExercises.contains(s) ||
        (tokens.intersection(walkClipExercises).isNotEmpty &&
         !s.contains('lunge') &&
         !s.contains('walkout') &&
         !s.contains('wall_walk'))) {
      return const ExerciseAnimConfig(
        mode: AnimationMode.clipMode,
        clipName: 'Walk',
        hasRealClip: true,
        poseNote: 'Real Walk locomotion clip from male_coach.glb.',
      );
    }

    return ExerciseAnimConfig(
      mode: AnimationMode.poseMode,
      clipName: '',
      hasRealClip: false,
      poseNote: '$slug: JS v5.0 2-phase biomechanical pose engine.',
    );
  }

  /// Returns a complete inventory of what is and is not available.
  static Map<String, String> get assetInventory => const {
    'male_coach.glb clips': 'Idle, Run, TPose, Walk',
    'female_coach.glb clips': 'idle (samba dance only)',
    'exercises with real clips': 'running, jogging, sprinting, football, '
        'cricket, boxing, cycling, swimming, skipping, jump_rope',
    'exercises with JS pose only': 'squat, push_up, plank, side_plank, '
        'mountain_climber, burpee (multi-phase), jumping_jack, deadlift, '
        'shoulder_press, bicep_curl, pull_up, yoga, pilates, and 40+ others',
    'missing assets for accuracy': 'Blender/Mixamo FBX → GLB exports needed '
        'for all strength and floor exercises',
  };
}
