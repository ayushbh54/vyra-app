import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../services/tts_service.dart';
import 'package:image_picker/image_picker.dart';
import '../services/avatar_customization_service.dart';
import 'avatar_studio.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// EXERCISE DETAIL — Interactive animated movement guide, biomechanical cues,
/// spoken-audio cadence coach, countdown timer, and completion logger.
class ExerciseDetailScreen extends StatefulWidget {
  const ExerciseDetailScreen({required this.item, super.key});

  final LibraryItem item;

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  Timer? _ticker;
  late int _remainingSec = widget.item.defaultDurationSec;
  bool _running = false;
  bool _completing = false;
  MovementDefinition? _movement;

  @override
  void initState() {
    super.initState();
    _checkMovement();
    // Auto-sync avatar pose to this exercise — driven by Gemini workout plan slug
    _syncAvatarPose();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Automatically transitions the avatar to the pose matching this exercise.
  /// Uses AvatarCustomizationService.slugToAvatarPose() to map the exercise slug.
  void _syncAvatarPose() {
    final slug = widget.item.slug;
    // Fire-and-forget: don't await, no blocking UI
    AvatarCustomizationService.instance.setActiveExercisePose(slug);
  }

  Future<void> _checkMovement() async {
    try {
      final def = await context.read<VyraApi>().movementFor(widget.item.slug);
      if (mounted) setState(() => _movement = def);
    } on ApiException {
      // Exercise does not have a 3D movement definition
    }
  }

  void _toggleTimer() {
    if (_running) {
      _ticker?.cancel();
      setState(() => _running = false);
      return;
    }
    setState(() => _running = true);
    HapticFeedback.lightImpact();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSec <= 1) {
        t.cancel();
        HapticFeedback.mediumImpact();
        setState(() {
          _remainingSec = 0;
          _running = false;
        });
        return;
      }
      setState(() => _remainingSec--);
    });
  }

  void _resetTimer() {
    _ticker?.cancel();
    HapticFeedback.selectionClick();
    setState(() {
      _running = false;
      _remainingSec = widget.item.defaultDurationSec;
    });
  }

  Future<void> _markComplete() async {
    setState(() => _completing = true);
    try {
      final actual = widget.item.defaultDurationSec - _remainingSec;
      final result = await context.read<VyraApi>().completeExercise(
            widget.item.slug,
            actual > 0 ? actual : widget.item.defaultDurationSec,
          );
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      final message = result.coinOutcomes.map((o) => o.message).where((m) => m.isNotEmpty).join('\n');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message.isEmpty ? 'Great job! Exercise logged.' : message),
          backgroundColor: VColor.accentGreen,
        ),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  String get _timeLabel {
    final m = _remainingSec ~/ 60;
    final s = _remainingSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      backgroundColor: VColor.bg,
      appBar: AppBar(
        backgroundColor: VColor.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: VColor.text, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(item.name, style: const TextStyle(color: VColor.text, fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.xs, VSpace.base, VSpace.xxxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(spacing: VSpace.xs, runSpacing: VSpace.xs, children: [
              VPill(item.subcategory),
              VPill(item.difficulty),
              if (item.isSeatedFriendly) const VPill('Seated-friendly'),
              if (_movement != null) const VPill('3D coaching', tone: CardTone.accent),
            ]),
            const SizedBox(height: VSpace.md),

            // ── Animated Visual Movement Guide ──────────────────────────────
            _ExerciseVisualGuide(item: item, movement: _movement),
            const SizedBox(height: VSpace.lg),

            // ── Timer Card ──────────────────────────────────────────────────
            VCard(
              tone: CardTone.raised,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const VLabel('Interval Timer'),
                      Text(
                        _running ? 'Active set' : 'Paused',
                        style: TextStyle(
                          color: _running ? VColor.accentGreen : VColor.textMid,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: VSpace.sm),
                  Text(_timeLabel,
                      style: const TextStyle(color: VColor.text, fontSize: 52, fontWeight: FontWeight.w800, letterSpacing: -1)),
                  const SizedBox(height: VSpace.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: _resetTimer,
                        icon: const Icon(Icons.replay_rounded, color: VColor.textMid, size: 26),
                        tooltip: 'Reset timer',
                      ),
                      const SizedBox(width: VSpace.lg),
                      GestureDetector(
                        onTap: _toggleTimer,
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: VColor.accent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: VColor.accent.withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: VColor.textOnAccent,
                            size: 32,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: VSpace.base),

            // ── Audio Spoken Cue Coach ──────────────────────────────────────
            if (item.audioScript.isNotEmpty) ...[
              _AudioCoachPlayer(script: item.audioScript),
              const SizedBox(height: VSpace.base),
            ],

            // ── Biomechanics & Movement Phases ──────────────────────────────
            if (_movement != null) ...[
              VCard(
                tone: CardTone.accent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.view_in_ar_rounded, color: VColor.accent, size: 22),
                        const SizedBox(width: VSpace.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('3D Biomechanics & Form Coach',
                                  style: TextStyle(fontWeight: FontWeight.w700, color: VColor.text)),
                              Text('Target: ${_movement!.targetMuscle} • Tempo: ${_movement!.tempo}',
                                  style: const TextStyle(
                                      color: VColor.accentGreen, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: VColor.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(VRadius.sm),
                          ),
                          child: Text('${_movement!.phases.length} Phases',
                              style: const TextStyle(color: VColor.accent, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: VSpace.base),
                    const Text('Movement Phases & Joint Cues:',
                        style: TextStyle(color: VColor.textMid, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: VSpace.xs),
                    for (final phase in _movement!.phases) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: VColor.surfaceRaised,
                                shape: BoxShape.circle,
                                border: Border.all(color: VColor.accent, width: 1.5),
                              ),
                              child: Text('${_movement!.phases.indexOf(phase) + 1}',
                                  style: const TextStyle(color: VColor.accent, fontSize: 10, fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: VSpace.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(phase.label,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600, color: VColor.text, fontSize: 13)),
                                      const SizedBox(width: 6),
                                      Text('(${phase.durationSec}s)',
                                          style: const TextStyle(color: VColor.textLow, fontSize: 11)),
                                    ],
                                  ),
                                  Text(phase.cue,
                                      style: const TextStyle(color: VColor.textMid, fontSize: 12, height: 1.3)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_movement!.correctMechanics.isNotEmpty) ...[
                      const SizedBox(height: VSpace.sm),
                      const Divider(color: VColor.line, height: 16),
                      const Text('Correct Form Mechanics:',
                          style: TextStyle(color: VColor.accentGreen, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      for (final mech in _movement!.correctMechanics)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle_outline_rounded, size: 14, color: VColor.accentGreen),
                              const SizedBox(width: 6),
                              Expanded(
                                  child: Text(mech, style: const TextStyle(color: VColor.textMid, fontSize: 11))),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: VSpace.base),
            ],

            const VLabel('Step-by-step instructions'),
            const SizedBox(height: VSpace.sm),
            for (final step in item.instructions)
              Padding(
                padding: const EdgeInsets.only(bottom: VSpace.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Icon(Icons.circle, size: 6, color: VColor.accent),
                    ),
                    const SizedBox(width: VSpace.sm),
                    Expanded(child: Text(step, style: const TextStyle(color: VColor.text, height: 1.4))),
                  ],
                ),
              ),
            const SizedBox(height: VSpace.base),

            if (item.contraindications.isNotEmpty)
              VDisclaimer('Skip or modify if you have: ${item.contraindications.join(", ")}. '
                  'This is general guidance, not medical advice.'),

            const SizedBox(height: VSpace.xl),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: _completing ? null : _markComplete,
                style: FilledButton.styleFrom(
                  backgroundColor: VColor.accent,
                  foregroundColor: VColor.textOnAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.pill)),
                ),
                child: _completing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: VColor.textOnAccent))
                    : const Text('Mark complete', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANIMATED VISUAL MOVEMENT GUIDE (Custom Biomechanical Simulation Canvas)
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// 3D CYBER-ATHLETE AVATAR & 180° HORIZONTAL PERSPECTIVE VIEWPORT
// ─────────────────────────────────────────────────────────────────────────────
enum ExercisePerspective { side, front, diag, orbit }


class _ExerciseVisualGuide extends StatefulWidget {
  const _ExerciseVisualGuide({required this.item, this.movement});

  final LibraryItem item;
  final MovementDefinition? movement;

  @override
  State<_ExerciseVisualGuide> createState() => _ExerciseVisualGuideState();
}

class _ExerciseVisualGuideState extends State<_ExerciseVisualGuide> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  bool _isPlaying = true;
  double _speedMultiplier = 1.0;
  String _orbitAngleString = '0deg 85deg 3.5m';
  String _activeAngleLabel = 'Front View';
  final _picker = ImagePicker();
  String _coachModelPath = 'assets/models/male_coach.glb';
  String _coachName = 'Remy';
  Color? _coachOutfitColor;
  Color? _coachAuraColor;

  bool _isDanceMode = false;

  /// Returns the best camera angle for demonstrating this exercise
  String _getExerciseCameraOrbit(String slug) {
    final s = slug.toLowerCase();
    if (s.contains('plank') || s.contains('push') || s.contains('cobra') || s.contains('child')) {
      return '20deg 110deg 3.5m'; // Looking down slightly - shows horizontal exercises
    }
    if (s.contains('squat') || s.contains('lunge') || s.contains('wall')) {
      return '45deg 90deg 3.8m'; // 45° side angle - shows leg exercises
    }
    if (s.contains('yoga') || s.contains('stretch') || s.contains('warrior')) {
      return '-30deg 80deg 3.5m'; // Slight right angle for yoga poses
    }
    if (s.contains('run') || s.contains('skip') || s.contains('jump')) {
      return '30deg 82deg 3.0m'; // Dynamic forward-angled view
    }
    if (s.contains('box') || s.contains('punch')) {
      return '-45deg 85deg 3.0m'; // Side view for boxing
    }
    if (s.contains('row') || s.contains('pull') || s.contains('deadlift')) {
      return '90deg 85deg 3.5m'; // Side view for back exercises
    }
    if (s.contains('overhead') || s.contains('shoulder') || s.contains('press')) {
      return '0deg 75deg 3.2m'; // Front view for overhead
    }
    return '0deg 85deg 3.5m'; // Default front view
  }

  /// Returns the action label for the current exercise (not dance)
  String get _exerciseActionLabel {
    if (_isDanceMode) return '🛑 Stop Dance';
    final slug = widget.item.slug.toLowerCase();
    final isFemale = _coachModelPath.contains('female');
    final anim = AvatarCustomizationService.getExerciseAnimation(slug, isFemale: isFemale);
    switch (anim) {
      case 'Run':  return '🏃 Running';
      case 'Walk': return '🚶 Walking';
      default:     return '🧘 Exercise';
    }
  }

  @override
  void initState() {
    super.initState();
    _orbitAngleString = _getExerciseCameraOrbit(widget.item.slug);
    _activeAngleLabel = 'Exercise View';
    _isDanceMode = false;

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();

    // Initialize local face personalization service (0 KB network overhead)
    AvatarCustomizationService.instance.init();
    AvatarCustomizationService.instance.addListener(_onAvatarProfileChanged);

    // Load active 3D coach model and customized styling
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      final savedModel = prefs.getString('selected_coach_model');
      final savedName = prefs.getString('selected_coach_name');
      final savedGender = prefs.getString('selected_coach_gender') ??
          prefs.getString('user_gender')?.toLowerCase();
      final isFemale = savedGender == 'female' ||
          (savedModel?.contains('female') ?? false);
      final savedOutfitColorInt = prefs.getInt('coach_outfit_color');
      final savedAuraColorInt = prefs.getInt('coach_aura_color');

      setState(() {
        _coachModelPath = savedModel ??
            (isFemale
                ? 'assets/models/female_coach.glb'
                : 'assets/models/male_coach.glb');
        _coachName = savedName ?? (isFemale ? 'Megan' : 'Remy');
        if (savedOutfitColorInt != null) _coachOutfitColor = Color(savedOutfitColorInt);
        if (savedAuraColorInt != null) _coachAuraColor = Color(savedAuraColorInt);
        
        // Set speed based on exercise intensity
        if (!_isDanceMode) {
          final pose = AvatarCustomizationService.slugToAvatarPose(widget.item.slug.toLowerCase());
          _speedMultiplier = AvatarCustomizationService.poseToTimeScale(pose).clamp(0.3, 2.0);
        }
      });
      // Set avatar pose to match exercise
      AvatarCustomizationService.instance
          .setActiveExercisePose(widget.item.slug.toLowerCase());
    });
  }

  void _onAvatarProfileChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AvatarCustomizationService.instance.removeListener(_onAvatarProfileChanged);
    _animCtrl.dispose();
    super.dispose();
  }

  void _togglePlay() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_isPlaying) {
        _animCtrl.stop();
        _isPlaying = false;
      } else {
        _animCtrl.repeat();
        _isPlaying = true;
      }
    });
  }

  void _cycleSpeed() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_speedMultiplier == 1.0) {
        _speedMultiplier = 0.75; // Slow motion for form learning
      } else if (_speedMultiplier == 0.75) {
        _speedMultiplier = 1.25;
      } else if (_speedMultiplier == 1.25) {
        _speedMultiplier = 1.5;
      } else {
        _speedMultiplier = 1.0;
      }
      _animCtrl.duration = Duration(milliseconds: (3600 / _speedMultiplier).round());
      if (_isPlaying) {
        _animCtrl.repeat();
      }
    });
  }

  void _setPresetAngle(String orbitString, String label) {
    HapticFeedback.selectionClick();
    setState(() {
      _orbitAngleString = orbitString;
      _activeAngleLabel = label;
    });
  }

  String _buildModelJs({required double timeScale, Color? outfit}) {
    String topRgba = '';
    if (outfit != null) {
      final r = (outfit.r).toStringAsFixed(2);
      final g = (outfit.g).toStringAsFixed(2);
      final b = (outfit.b).toStringAsFixed(2);
      topRgba = '[$r, $g, $b, 1.0]';
    }
    return '''
    (function() {
      function apply() {
        var mv = document.querySelector('model-viewer');
        if (!mv) return;
        mv.timeScale = $timeScale;
        mv.environmentImage = 'neutral';
        if (mv.model && mv.model.materials) {
          try {
            for (var i = 0; i < mv.model.materials.length; i++) {
              var mat = mv.model.materials[i];
              if (!mat || !mat.name) continue;
              if (mat.name === 'Alpha_Joints_MAT' || mat.name === 'Alpha_Body_MAT' || 
                  mat.name === 'mixamorig:Hips' || mat.name.toLowerCase().includes('skin') ||
                  mat.name.toLowerCase().includes('body')) {
                try { mat.pbrMetallicRoughness['metallicFactor'] = 0.0; } catch(e) {}
                try { mat.pbrMetallicRoughness['roughnessFactor'] = 0.85; } catch(e) {}
              }
              if (mat.name === 'Topmat' || mat.name === 'Ch21_body' || mat.name === 'Alpha_Surface_MAT') {
                ${topRgba.isNotEmpty ? "try { mat.pbrMetallicRoughness.setBaseColorFactor($topRgba); } catch(e) {}" : ""}
              }
            }
          } catch(e) {}
        }
      }
      var mv = document.querySelector('model-viewer');
      if (mv) {
        if (mv.loaded) {
          apply();
        } else {
          mv.addEventListener('load', apply, { once: true });
        }
      }
    })();
    ''';
  }

  /// 📸 Scan/Upload User Photo to match Avatar face (On-Device, 0 KB Network, Zero Heat)
  Future<void> _pickPhotoAndMatchFace() async {
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
        maxWidth: 720,
      );
      if (xfile == null) return;
      HapticFeedback.mediumImpact();
      await AvatarCustomizationService.instance.scanAndExtractFromPhoto(xfile.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.face_retouching_natural_rounded, color: VColor.accentGreen),
                SizedBox(width: 8),
                Text('3D Avatar face personalized from your photo! (0 KB Data)'),
              ],
            ),
            backgroundColor: VColor.surfaceHigh,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {}
  }

  void _openFaceCustomizerSheet() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AvatarStudioScreen()),
    );
  }

  /// Returns a live coaching cue based on exercise type and animation progress
  String get _currentExerciseCue {
    final slug = widget.item.slug.toLowerCase();
    final pose = AvatarCustomizationService.slugToAvatarPose(slug);
    final v = _animCtrl.value;
    
    if (_isDanceMode) return '💃 Dance Mode — Feel the rhythm!';
    
    switch (pose) {
      case 'yoga':
        if (v < 0.33) return '🧘 Breathe in — expand';
        if (v < 0.66) return '🧘 Hold — feel the stretch';
        return '🧘 Breathe out — release';
      case 'running':
        if (v < 0.5) return '🏃 Drive forward — pump arms';
        return '🏃 Stay tall — breathe steady';
      case 'squat':
        if (v < 0.4) return '⬇️ Lower slowly — chest up';
        if (v < 0.6) return '💥 Hold at bottom';
        return '⬆️ Drive up through heels';
      case 'pushup':
        if (v < 0.4) return '⬇️ Lower with control';
        if (v < 0.6) return '💪 Hold — core tight';
        return '⬆️ Push the floor away';
      case 'plank':
        return '🔥 Hold — brace core, breathe';
      case 'boxing':
        if (v < 0.5) return '🥊 Extend — snap the punch';
        return '🛡️ Guard up — reset';
      case 'cycling':
        if (v < 0.5) return '🚴 Power stroke — push down';
        return '🚴 Recovery stroke — pull up';
      case 'skipping':
        return '⚡ Stay light — wrists drive';
      case 'swimming':
        if (v < 0.5) return '🏊 Pull through — rotate hips';
        return '🏊 Reach forward — glide';
      case 'weightlifting':
        if (v < 0.4) return '⬇️ Eccentric — control down';
        if (v < 0.6) return '💥 Isometric — peak squeeze';
        return '⬆️ Concentric — drive up';
      default:
        if (v < 0.40) return 'Phase 1: Control — eccentric';
        if (v < 0.60) return 'Phase 2: Hold — peak squeeze';
        return 'Phase 3: Drive — concentric';
    }
  }

  String get _targetMuscle {
    if (widget.movement?.targetMuscle != null && widget.movement!.targetMuscle.isNotEmpty) {
      return widget.movement!.targetMuscle;
    }
    final s = widget.item.slug.toLowerCase().replaceAll('_', '-');
    if (s.contains('shoulder') || s.contains('overhead') || (s.contains('seated') && s.contains('press'))) {
      return 'Shoulders & Triceps';
    }
    if (s.contains('bridge') || s.contains('glute')) return 'Glutes & Hamstrings';
    if (s.contains('wall-sit')) return 'Quadriceps & Glutes';
    if (s.contains('squat') || s.contains('lunge')) return 'Quadriceps & Hamstrings';
    if (s.contains('push-up') || s.contains('pushup') || s.contains('chest')) return 'Chest & Triceps';
    if (s.contains('plank') || s.contains('core') || s.contains('abs') || s.contains('crunch')) return 'Core & Abs';
    if (s.contains('bicep') || s.contains('curl')) return 'Biceps';
    if (s.contains('tricep') || s.contains('dip')) return 'Triceps';
    if (s.contains('pull') || s.contains('row') || s.contains('lat')) return 'Back & Lats';
    if (s.contains('calf') || s.contains('raise')) return 'Calves';
    if (s.contains('yoga') || s.contains('stretch') || s.contains('dog') || s.contains('cobra')) return 'Full Body Mobility';
    return widget.item.category.toUpperCase();
  }

  void _toggleDance() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isDanceMode = !_isDanceMode;
      if (_isDanceMode) {
        _speedMultiplier = 1.8;
      } else {
        final pose = AvatarCustomizationService.slugToAvatarPose(
            widget.item.slug.toLowerCase());
        _speedMultiplier = AvatarCustomizationService.poseToTimeScale(pose);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final faceProfile = AvatarCustomizationService.instance.profile;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: VColor.surfaceRaised,
        borderRadius: BorderRadius.circular(VRadius.lg),
        border: Border.all(color: VColor.accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info bar & Face Customizer CTA
          Padding(
            padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.sm + 4, VSpace.base, VSpace.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: VColor.accentGreen,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: VColor.accentGreen, blurRadius: 6),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '3D COACH AVATAR • 180° VIEWPORT',
                      style: TextStyle(
                        color: VColor.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Face Likeness Customizer Pill (Tap -> Studio, Long Press -> Fast Selfie)
                    InkWell(
                      onTap: _openFaceCustomizerSheet,
                      onLongPress: _pickPhotoAndMatchFace,
                      borderRadius: BorderRadius.circular(VRadius.sm),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: faceProfile.useUserLikeness
                              ? VColor.accentGreen.withValues(alpha: 0.15)
                              : VColor.steel.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(VRadius.sm),
                          border: Border.all(
                            color: faceProfile.useUserLikeness
                                ? VColor.accentGreen.withValues(alpha: 0.5)
                                : VColor.line,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              faceProfile.useUserLikeness
                                  ? Icons.face_retouching_natural_rounded
                                  : Icons.person_rounded,
                              size: 13,
                              color: faceProfile.useUserLikeness ? VColor.accentGreen : VColor.textMid,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              faceProfile.useUserLikeness ? 'My Face' : '3D Avatar',
                              style: TextStyle(
                                color: faceProfile.useUserLikeness ? VColor.accentGreen : VColor.textMid,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: VSpace.xs),
                    InkWell(
                      onTap: _cycleSpeed,
                      borderRadius: BorderRadius.circular(VRadius.sm),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: VColor.steel.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(VRadius.sm),
                        ),
                        child: Text(
                          '${_speedMultiplier}x',
                          style: const TextStyle(color: VColor.textMid, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: VSpace.xs),
                    IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline,
                        color: VColor.text,
                        size: 22,
                      ),
                      onPressed: _togglePlay,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── 180° Horizontal Perspective Viewport Selector ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: VSpace.base, vertical: 4),
            child: Container(
              height: 34,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: VColor.surface,
                borderRadius: BorderRadius.circular(VRadius.pill),
                border: Border.all(color: VColor.line),
              ),
              child: Row(
                children: [
                  _buildAnglePill(
                    label: 'Front View',
                    icon: Icons.accessibility_new_rounded,
                    isSelected: _activeAngleLabel == 'Front View',
                    onTap: () => _setPresetAngle('0deg 85deg 3.5m', 'Front View'),
                  ),
                  _buildAnglePill(
                    label: 'Side View',
                    icon: Icons.view_sidebar_rounded,
                    isSelected: _activeAngleLabel == 'Side View',
                    onTap: () => _setPresetAngle('90deg 85deg 3.5m', 'Side View'),
                  ),
                  _buildAnglePill(
                    label: '45° Angle',
                    icon: Icons.view_in_ar_rounded,
                    isSelected: _activeAngleLabel == '45° Angle',
                    onTap: () => _setPresetAngle('45deg 85deg 3.5m', '45° Angle'),
                  ),
                  _buildAnglePill(
                    label: 'Left Side',
                    icon: Icons.view_sidebar_outlined,
                    isSelected: _activeAngleLabel == 'Left Side',
                    onTap: () => _setPresetAngle('-90deg 85deg 3.5m', 'Left Side'),
                  ),
                ],
              ),
            ),
          ),

          // ── 💃 Dance / Exercise Mode Toggle ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(VSpace.base, 6, VSpace.base, 4),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _toggleDance,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _isDanceMode
                            ? const Color(0xFFE91E63).withValues(alpha: 0.18)
                            : VColor.accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(VRadius.pill),
                        border: Border.all(
                          color: _isDanceMode
                              ? const Color(0xFFE91E63).withValues(alpha: 0.7)
                              : VColor.accent.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isDanceMode ? Icons.stop_rounded : Icons.music_note_rounded,
                            size: 16,
                            color: _isDanceMode ? const Color(0xFFE91E63) : VColor.accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _exerciseActionLabel,
                            style: TextStyle(
                              color: _isDanceMode ? const Color(0xFFE91E63) : VColor.accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: VColor.surface,
                    borderRadius: BorderRadius.circular(VRadius.pill),
                    border: Border.all(color: VColor.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _coachModelPath.contains('female') ? Icons.female_rounded : Icons.male_rounded,
                        size: 14,
                        color: VColor.accentCyan,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _coachName,
                        style: const TextStyle(color: VColor.textMid, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── 3D Coach Avatar Viewport (360° Touch Orbit + Perspective Presets) ──
          SizedBox(
            height: 220,
            width: double.infinity,
            child: Stack(
              children: [
                // ── Ambient Aura Glow ──
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.1),
                        radius: 0.9,
                        colors: [
                          (_coachAuraColor ?? const Color(0xFF00E5FF)).withValues(alpha: 0.18),
                          const Color(0xFF0D0D12),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Realistic 3D Human Coach ──
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Builder(builder: (context) {
                    final isFemale = _coachModelPath.contains('female');
                    final exerciseAnim = AvatarCustomizationService.getExerciseAnimation(
                      widget.item.slug, isFemale: isFemale);
                    final danceAnim = AvatarCustomizationService.getDanceAnimation(
                      isFemale: isFemale);
                    final currentAnim = _isDanceMode ? danceAnim : exerciseAnim;
                    // Male: always autoPlay (Soldier has real exercise anims).
                    // Female: only play in dance mode (idle = samba dance).
                    final shouldPlay = isFemale ? _isDanceMode : true;
                    final ts = _isDanceMode ? 1.8 : _speedMultiplier;
                    return ModelViewer(
                      key: ValueKey(
                          '${_coachModelPath}_${_orbitAngleString}_${_speedMultiplier}_${_isDanceMode}_${_coachOutfitColor?.toARGB32()}'),
                      src: _coachModelPath,
                      alt: '3D Coach $_coachName',
                      ar: false,
                      autoRotate: false,
                      cameraControls: true,
                      autoPlay: shouldPlay,
                      shadowIntensity: 1.0,
                      shadowSoftness: 0.8,
                      exposure: 1.4,
                      environmentImage: 'neutral',
                      backgroundColor: const Color(0xFF0D0D12),
                      cameraOrbit: _orbitAngleString,
                      animationName: currentAnim,
                      loading: Loading.eager,
                      relatedJs: _buildModelJs(
                        timeScale: shouldPlay ? ts : 0.0,
                        outfit: _coachOutfitColor,
                      ),
                    );
                  }),
                ),

                // ── Top HUD: Drag hint & Coach name ──
                Positioned(
                  top: 8,
                  right: VSpace.base,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: VColor.bg.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(VRadius.pill),
                      border: Border.all(
                          color: VColor.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.touch_app_rounded,
                            size: 12, color: VColor.accentCyan),
                        const SizedBox(width: 4),
                        Text(
                          '3D Coach $_coachName • $_activeAngleLabel',
                          style: const TextStyle(
                            color: VColor.accentCyan,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                  // ── Bottom HUD: Phase indicator & Target Muscle badge ──
                  Positioned(
                    bottom: 8,
                    left: VSpace.base,
                    right: VSpace.base,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: VColor.bg.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(VRadius.sm),
                            border: Border.all(color: VColor.line),
                          ),
                          child: Text(
                            _currentExerciseCue,
                            style: const TextStyle(
                              color: VColor.text,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: VColor.accent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(VRadius.sm),
                            border: Border.all(
                                color: VColor.accent.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.bolt_rounded,
                                  size: 13, color: VColor.accentGreen),
                              const SizedBox(width: 4),
                              Text(
                                _targetMuscle,
                                style: const TextStyle(
                                  color: VColor.accentGreen,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: VSpace.xs),
        ],
      ),
    );
  }

  Widget _buildAnglePill({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(VRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? VColor.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(VRadius.pill),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? VColor.textOnAccent : VColor.textMid,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? VColor.textOnAccent : VColor.textMid,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AVATAR FACE CUSTOMIZER MODAL SHEET (On-Device Likeness, Zero Network Data)
// ─────────────────────────────────────────────────────────────────────────────
class _AvatarFaceCustomizerSheet extends StatefulWidget {
  const _AvatarFaceCustomizerSheet({required this.onPickPhoto});
  final VoidCallback onPickPhoto;

  @override
  State<_AvatarFaceCustomizerSheet> createState() => _AvatarFaceCustomizerSheetState();
}

class _AvatarFaceCustomizerSheetState extends State<_AvatarFaceCustomizerSheet> {
  late AvatarFaceProfile _current;

  @override
  void initState() {
    super.initState();
    _current = AvatarCustomizationService.instance.profile;
  }

  void _update(AvatarFaceProfile p) {
    setState(() => _current = p);
    AvatarCustomizationService.instance.updateProfile(p);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.base, VSpace.base, VSpace.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.face_retouching_natural_rounded, color: VColor.accentCyan, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '3D Avatar Face Likeness',
                      style: TextStyle(color: VColor.text, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: VColor.accentGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(VRadius.sm),
                    border: Border.all(color: VColor.accentGreen.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    '⚡ 0 KB Data • 0% Heat',
                    style: TextStyle(color: VColor.accentGreen, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: VSpace.xs),
            const Text(
              'Apni photo se 3D Avatar ka face match karein. Purely on-device processed — phone heat aur extra data use nahi hota.',
              style: TextStyle(color: VColor.textMid, fontSize: 12),
            ),
            const SizedBox(height: VSpace.base),

            // 1-Tap Photo Scan Button
            InkWell(
              onTap: widget.onPickPhoto,
              borderRadius: BorderRadius.circular(VRadius.md),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      VColor.accent.withValues(alpha: 0.25),
                      VColor.accentGreen.withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(VRadius.md),
                  border: Border.all(color: VColor.accent.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: VColor.accent, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt_rounded, color: VColor.textOnAccent, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('📸 Scan Face from Selfie / Photo',
                              style: TextStyle(color: VColor.text, fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 2),
                          Text('Auto-detects skin tone, haircut & beard profile',
                              style: TextStyle(color: VColor.textMid, fontSize: 11)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: VColor.accent),
                  ],
                ),
              ),
            ),
            const SizedBox(height: VSpace.base),

            // Mode Selector: My Likeness vs Cyber Coach
            Row(
              children: [
                Expanded(
                  child: _buildChoiceChip(
                    label: '👤 My Face Likeness',
                    selected: _current.useUserLikeness,
                    onTap: () => _update(_current.copyWith(useUserLikeness: true)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildChoiceChip(
                    label: '🤖 Cybernetic Coach',
                    selected: !_current.useUserLikeness,
                    onTap: () => _update(_current.copyWith(useUserLikeness: false)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: VSpace.base),

            // Skin Tone Palette
            const Text('Skin Tone Complexion:', style: TextStyle(color: VColor.textLow, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildSkinToneChip('wheatish', 'Wheatish (Warm Indian)', const Color(0xFFC78A5B)),
                const SizedBox(width: 6),
                _buildSkinToneChip('fair', 'Fair', const Color(0xFFE8B89C)),
                const SizedBox(width: 6),
                _buildSkinToneChip('tan', 'Tan', const Color(0xFFB87848)),
                const SizedBox(width: 6),
                _buildSkinToneChip('dusky', 'Bronze', const Color(0xFF834E2A)),
              ],
            ),
            const SizedBox(height: VSpace.sm),

            // Hair Style
            const Text('Hair Style:', style: TextStyle(color: VColor.textLow, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildHairChip('crew_fade', 'Athletic Fade'),
                  const SizedBox(width: 6),
                  _buildHairChip('short_crop', 'Short Crop'),
                  const SizedBox(width: 6),
                  _buildHairChip('curls_bun', 'Topknot Curls'),
                  const SizedBox(width: 6),
                  _buildHairChip('bald_helmet', 'Cyber Helmet'),
                ],
              ),
            ),
            const SizedBox(height: VSpace.sm),

            // Facial Hair
            const Text('Facial Hair:', style: TextStyle(color: VColor.textLow, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildBeardChip('neat_beard', 'Neat Beard'),
                const SizedBox(width: 6),
                _buildBeardChip('stubble', 'Light Stubble'),
                const SizedBox(width: 6),
                _buildBeardChip('clean', 'Clean Shaven'),
              ],
            ),
            const SizedBox(height: VSpace.base),

            // Close CTA
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: VColor.accent,
                  foregroundColor: VColor.textOnAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.pill)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Apply to 3D Avatar (Instant)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceChip({required String label, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(VRadius.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? VColor.accent.withValues(alpha: 0.2) : VColor.surfaceHigh,
          borderRadius: BorderRadius.circular(VRadius.sm),
          border: Border.all(color: selected ? VColor.accent : VColor.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? VColor.accent : VColor.textMid,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildSkinToneChip(String toneKey, String label, Color previewColor) {
    final isSelected = _current.skinTone == toneKey;
    return Expanded(
      child: InkWell(
        onTap: () => _update(_current.copyWith(skinTone: toneKey, useUserLikeness: true)),
        borderRadius: BorderRadius.circular(VRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? previewColor.withValues(alpha: 0.3) : VColor.surfaceHigh,
            borderRadius: BorderRadius.circular(VRadius.sm),
            border: Border.all(color: isSelected ? previewColor : VColor.line),
          ),
          child: Column(
            children: [
              Container(width: 14, height: 14, decoration: BoxDecoration(color: previewColor, shape: BoxShape.circle)),
              const SizedBox(height: 3),
              Text(
                toneKey.toUpperCase(),
                style: TextStyle(
                  color: isSelected ? VColor.text : VColor.textMid,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHairChip(String key, String label) {
    final isSelected = _current.hairStyle == key;
    return InkWell(
      onTap: () => _update(_current.copyWith(hairStyle: key, useUserLikeness: true)),
      borderRadius: BorderRadius.circular(VRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? VColor.accentGreen.withValues(alpha: 0.2) : VColor.surfaceHigh,
          borderRadius: BorderRadius.circular(VRadius.pill),
          border: Border.all(color: isSelected ? VColor.accentGreen : VColor.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? VColor.accentGreen : VColor.textMid,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildBeardChip(String key, String label) {
    final isSelected = _current.facialHair == key;
    return Expanded(
      child: InkWell(
        onTap: () => _update(_current.copyWith(facialHair: key, useUserLikeness: true)),
        borderRadius: BorderRadius.circular(VRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? VColor.accentCyan.withValues(alpha: 0.2) : VColor.surfaceHigh,
            borderRadius: BorderRadius.circular(VRadius.pill),
            border: Border.all(color: isSelected ? VColor.accentCyan : VColor.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? VColor.accentCyan : VColor.textMid,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// AUDIO COACH PLAYER (Spoken guidance with animated sound wave bars)
// ─────────────────────────────────────────────────────────────────────────────
class _AudioCoachPlayer extends StatefulWidget {
  const _AudioCoachPlayer({required this.script});

  final String script;

  @override
  State<_AudioCoachPlayer> createState() => _AudioCoachPlayerState();
}

class _AudioCoachPlayerState extends State<_AudioCoachPlayer> with SingleTickerProviderStateMixin {
  late AnimationController _waveCtrl;
  bool _isPlaying = false;
  Timer? _autoStopTimer;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    _autoStopTimer?.cancel();
    TtsService.stop();
    super.dispose();
  }

  void _togglePlay() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_isPlaying) {
        _waveCtrl.stop();
        _autoStopTimer?.cancel();
        TtsService.stop();
        _isPlaying = false;
      } else {
        _waveCtrl.repeat(reverse: true);
        _isPlaying = true;
        // Real-time audio voice guidance through device speaker
        TtsService.speak(widget.script);
        _autoStopTimer?.cancel();
        final words = widget.script.split(RegExp(r'\s+')).length;
        final estSeconds = (words / 2.0).clamp(10, 60).toInt();
        _autoStopTimer = Timer(Duration(seconds: estSeconds), () {
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _waveCtrl.stop();
              TtsService.stop();
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return VCard(
      tone: _isPlaying ? CardTone.accent : CardTone.raised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _isPlaying ? VColor.accent : VColor.steel.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.volume_up_rounded : Icons.play_arrow_rounded,
                    color: _isPlaying ? VColor.textOnAccent : VColor.text,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: VSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isPlaying ? 'Audio Coach: Guiding form…' : 'Spoken Form Coaching',
                      style: TextStyle(
                        color: _isPlaying ? VColor.accent : VColor.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      _isPlaying ? 'Tap to pause cue' : 'Tap to listen to real-time cue',
                      style: const TextStyle(color: VColor.textMid, fontSize: 11),
                    ),
                  ],
                ),
              ),
              // Animated sound wave bars
              if (_isPlaying)
                AnimatedBuilder(
                  animation: _waveCtrl,
                  builder: (context, _) {
                    return Row(
                      children: List.generate(4, (i) {
                        final h = 6.0 + (14.0 * math.sin((_waveCtrl.value * math.pi) + (i * 0.8)).abs());
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: 3.5,
                          height: h,
                          decoration: BoxDecoration(
                            color: VColor.accentGreen,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: VSpace.sm),
          Container(
            padding: const EdgeInsets.all(VSpace.sm),
            decoration: BoxDecoration(
              color: VColor.bg.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(VRadius.sm),
            ),
            child: Text(
              '"${widget.script}"',
              style: const TextStyle(
                color: VColor.textMid,
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
