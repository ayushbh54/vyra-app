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
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
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

class _Vector3D {
  const _Vector3D(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;

  _Vector3D rotateY(double rad) {
    final cosA = math.cos(rad);
    final sinA = math.sin(rad);
    return _Vector3D(
      x * cosA + z * sinA,
      y,
      -x * sinA + z * cosA,
    );
  }

  Offset project(double cx, double groundY, {double fov = 440.0}) {
    final scale = fov / (fov - z);
    return Offset(cx + x * scale, groundY + y * scale);
  }

  double scaleFactor({double fov = 440.0}) {
    return (fov / (fov - z)).clamp(0.60, 1.60);
  }
}

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
  double _orbitAngle = 0.0; // In radians: -pi/2 (-90°) to +pi/2 (+90°)
  bool _isAutoOrbit = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final s = widget.item.slug.toLowerCase().replaceAll('_', '-');
    if (s.contains('bicep') || s.contains('shoulder') || s.contains('press') || s.contains('curl')) {
      _orbitAngle = 0.0; // Front view by default for upper body frontal movements
    } else {
      _orbitAngle = math.pi / 4; // 45° diagonal by default for full 3D body depth
    }

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();

    // Initialize local face personalization service (0 KB network overhead)
    AvatarCustomizationService.instance.init();
    AvatarCustomizationService.instance.addListener(_onAvatarProfileChanged);
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
      } else {
        _speedMultiplier = 1.0;
      }
      _animCtrl.duration = Duration(milliseconds: (3600 / _speedMultiplier).round());
      if (_isPlaying) {
        _animCtrl.repeat();
      }
    });
  }

  void _setPresetAngle(double angle) {
    HapticFeedback.selectionClick();
    setState(() {
      _isAutoOrbit = false;
      _orbitAngle = angle;
    });
  }

  void _toggleAutoOrbit() {
    HapticFeedback.selectionClick();
    setState(() {
      _isAutoOrbit = !_isAutoOrbit;
    });
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

  String get _currentPhaseName {
    final v = _animCtrl.value;
    if (v < 0.40) {
      return 'Phase 1: Eccentric (Control Down)';
    } else if (v < 0.60) {
      return 'Phase 2: Isometric (Peak Squeeze)';
    } else {
      return 'Phase 3: Concentric (Drive Up)';
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
                    label: '0° Front',
                    icon: Icons.accessibility_new_rounded,
                    isSelected: !_isAutoOrbit && (_orbitAngle.abs() < 0.15),
                    onTap: () => _setPresetAngle(0.0),
                  ),
                  _buildAnglePill(
                    label: '45° Diag',
                    icon: Icons.view_in_ar_rounded,
                    isSelected: !_isAutoOrbit && ((_orbitAngle - math.pi / 4).abs() < 0.15),
                    onTap: () => _setPresetAngle(math.pi / 4),
                  ),
                  _buildAnglePill(
                    label: '90° Side',
                    icon: Icons.view_sidebar_rounded,
                    isSelected: !_isAutoOrbit && ((_orbitAngle - math.pi / 2).abs() < 0.15),
                    onTap: () => _setPresetAngle(math.pi / 2),
                  ),
                  _buildAnglePill(
                    label: '🔄 180° Orbit',
                    icon: Icons.sync_rounded,
                    isSelected: _isAutoOrbit,
                    onTap: _toggleAutoOrbit,
                  ),
                ],
              ),
            ),
          ),

          // ── 3D Robot Simulation Canvas (Touch Drag & Battery Shield Enabled) ──
          SizedBox(
            height: 250,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _animCtrl,
              builder: (context, _) {
                // Compute current active orbit angle
                final activeOrbit = _isAutoOrbit
                    ? math.sin(_animCtrl.value * 2 * math.pi) * (math.pi / 2.1)
                    : _orbitAngle;

                final currentDeg = (activeOrbit * 180 / math.pi).round();

                return GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _isAutoOrbit = false;
                      _orbitAngle = (_orbitAngle + details.primaryDelta! * 0.016)
                          .clamp(-math.pi / 2, math.pi / 2);
                    });
                  },
                  child: Stack(
                    children: [
                      RepaintBoundary(
                        child: CustomPaint(
                          size: const Size(double.infinity, 250),
                          painter: _Biomechanical3DAvatarPainter(
                            animationProgress: _animCtrl.value,
                            exerciseSlug: widget.item.slug.toLowerCase(),
                            orbitAngle: activeOrbit,
                            faceProfile: faceProfile,
                          ),
                        ),
                      ),

                      // Top HUD: Interactive Drag Rotation Hint & Angle Degree
                      Positioned(
                        top: 8,
                        right: VSpace.base,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: VColor.bg.withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(VRadius.pill),
                            border: Border.all(color: VColor.accent.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.touch_app_rounded, size: 12, color: VColor.accentCyan),
                              const SizedBox(width: 4),
                              Text(
                                'Drag to rotate • $currentDeg°',
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

                      // Bottom HUD: Phase indicator & Target Muscle badge
                      Positioned(
                        bottom: 8,
                        left: VSpace.base,
                        right: VSpace.base,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: VColor.bg.withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(VRadius.sm),
                                border: Border.all(color: VColor.line),
                              ),
                              child: Text(
                                _currentPhaseName,
                                style: const TextStyle(
                                  color: VColor.text,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: VColor.accent.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(VRadius.sm),
                                border: Border.all(color: VColor.accent.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.bolt_rounded, size: 13, color: VColor.accentGreen),
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
                );
              },
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
// 3D BIOMECHANICAL ROBOT AVATAR PAINTER (Universal Moves & Thermal Shield)
// ─────────────────────────────────────────────────────────────────────────────
class _Biomechanical3DAvatarPainter extends CustomPainter {
  _Biomechanical3DAvatarPainter({
    required this.animationProgress,
    required this.exerciseSlug,
    required this.orbitAngle,
    required this.faceProfile,
  });

  final double animationProgress;
  final String exerciseSlug;
  final double orbitAngle;
  final AvatarFaceProfile faceProfile;

  // ── Pre-allocated Static Paint Objects (Prevents GC Churn & Thermal Spikes) ──
  static final Paint _gridPaint = Paint()
    ..color = VColor.accentCyan.withValues(alpha: 0.12)
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke;

  static final Paint _horizonLinePaint = Paint()
    ..color = VColor.line.withValues(alpha: 0.65)
    ..strokeWidth = 1.5;

  static final Paint _radialRayPaint = Paint()
    ..color = VColor.accent.withValues(alpha: 0.08)
    ..strokeWidth = 1.0;

  static final Paint _shadowPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.65)
    ..style = PaintingStyle.fill
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

  static final Paint _wallLinePaint = Paint()
    ..color = VColor.accentCyan.withValues(alpha: 0.18)
    ..strokeWidth = 2.0;

  static final Paint _muscleGlowPaint = Paint()
    ..color = const Color(0xFF34FF8C).withValues(alpha: 0.55)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 10
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

  static final Paint _conduitPaint = Paint()
    ..strokeCap = StrokeCap.round;

  static final Paint _servoHousingPaint = Paint()
    ..color = const Color(0xFF1E2838)
    ..style = PaintingStyle.fill;

  static final Paint _servoRimPaint = Paint()
    ..color = const Color(0xFF8BA7C4)
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;

  static final Paint _servoLedPaint = Paint()
    ..style = PaintingStyle.fill;

  static final Paint _torsoOutlinePaint = Paint()
    ..color = const Color(0xFF7F9CB8).withValues(alpha: 0.6)
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke;

  static final Paint _arcReactorGlowPaint = Paint()
    ..color = const Color(0xFF00D2FF).withValues(alpha: 0.35)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

  static final Paint _arcReactorRingPaint = Paint()
    ..color = const Color(0xFF00D2FF)
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;

  static final Paint _arcReactorCorePaint = Paint()
    ..color = const Color(0xFFDFE2F0);

  static final Paint _barbellBarPaint = Paint()
    ..color = const Color(0xFFDFE2F0)
    ..strokeWidth = 3.2
    ..strokeCap = StrokeCap.round;

  static final Paint _weightPlatePaint = Paint()
    ..color = const Color(0xFF141A24)
    ..style = PaintingStyle.fill;

  static final Paint _weightPlateRim = Paint()
    ..color = const Color(0xFF00D2FF)
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;

  static final Paint _hudArcPaint = Paint()
    ..color = const Color(0xFF34FF8C)
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;

  static final Paint _hudBgPaint = Paint()
    ..color = const Color(0xCC0F131D);

  static final Paint _hudBorderPaint = Paint()
    ..color = const Color(0x6034FF8C)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final groundY = size.height - 34;

    // 1. Draw 3D Perspective Ground Grid & Horizon
    _drawPerspectiveFloorGrid(canvas, size, cx, groundY, orbitAngle);

    // Sine curve cycle for smooth back-and-forth movement (0 -> 1 -> 0)
    final cycle = (math.sin(animationProgress * 2 * math.pi - math.pi / 2) + 1) / 2;
    final s = exerciseSlug.toLowerCase().replaceAll('_', '-');

    // 2. Compute 3D Anatomical Keypoints based on Universal Move Engine
    final pose = _computeUniversalExercise3DPose(s, cycle, animationProgress);

    // 3. Project 3D Model Coordinates onto 2D Screen with Depth
    final pHead = pose.head.rotateY(orbitAngle).project(cx, groundY);
    final pNeck = pose.neck.rotateY(orbitAngle).project(cx, groundY);
    final pChest = pose.chest.rotateY(orbitAngle).project(cx, groundY);
    final pPelvis = pose.pelvis.rotateY(orbitAngle).project(cx, groundY);

    final rotSL = pose.shoulderL.rotateY(orbitAngle);
    final rotSR = pose.shoulderR.rotateY(orbitAngle);
    final rotEL = pose.elbowL.rotateY(orbitAngle);
    final rotER = pose.elbowR.rotateY(orbitAngle);
    final rotHL = pose.handL.rotateY(orbitAngle);
    final rotHR = pose.handR.rotateY(orbitAngle);

    final pSL = rotSL.project(cx, groundY);
    final pSR = rotSR.project(cx, groundY);
    final pEL = rotEL.project(cx, groundY);
    final pER = rotER.project(cx, groundY);
    final pHL = rotHL.project(cx, groundY);
    final pHR = rotHR.project(cx, groundY);

    final rotHipL = pose.hipL.rotateY(orbitAngle);
    final rotHipR = pose.hipR.rotateY(orbitAngle);
    final rotKL = pose.kneeL.rotateY(orbitAngle);
    final rotKR = pose.kneeR.rotateY(orbitAngle);
    final rotFL = pose.footL.rotateY(orbitAngle);
    final rotFR = pose.footR.rotateY(orbitAngle);

    final pHipL = rotHipL.project(cx, groundY);
    final pHipR = rotHipR.project(cx, groundY);
    final pKL = rotKL.project(cx, groundY);
    final pKR = rotKR.project(cx, groundY);
    final pFL = rotFL.project(cx, groundY);
    final pFR = rotFR.project(cx, groundY);

    // 4. Ground Contact Dynamic Shadow Ellipse
    _drawGroundContactShadow(canvas, pFL, pFR, cx, groundY, pose.elevation, cycle);

    // 5. Wall Grid if Wall Sit or Wall Push
    if (pose.isWallExercise) {
      _drawHolographicWall(canvas, cx, groundY, orbitAngle);
    }

    // 6. Depth-Sorted Rendering (Painter's Algorithm for Perfect 3D Depth)
    final depthL = (rotSL.z + rotEL.z + rotHL.z + rotHipL.z + rotKL.z + rotFL.z) / 6.0;
    final depthR = (rotSR.z + rotER.z + rotHR.z + rotHipR.z + rotKR.z + rotFR.z) / 6.0;

    if (depthL < depthR) {
      // Left side is in background -> Draw Left first, then Torso/Head, then Right in foreground
      _drawLeftLeg(canvas, pHipL, pKL, pFL, pose.quadFlexed, rotKL.z);
      _drawLeftArm(canvas, pSL, pEL, pHL, pose.armFlexed, rotEL.z, pose.holdsWeights, orbitAngle, cycle);

      _drawTorsoAndHead(canvas, pHead, pNeck, pChest, pPelvis, pSL, pSR, pHipL, pHipR, orbitAngle, pose.coreFlexed);

      _drawRightLeg(canvas, pHipR, pKR, pFR, pose.quadFlexed, rotKR.z);
      _drawRightArm(canvas, pSR, pER, pHR, pose.armFlexed, rotER.z, pose.holdsWeights, orbitAngle, cycle);
    } else {
      // Right side is in background -> Draw Right first, then Torso/Head, then Left in foreground
      _drawRightLeg(canvas, pHipR, pKR, pFR, pose.quadFlexed, rotKR.z);
      _drawRightArm(canvas, pSR, pER, pHR, pose.armFlexed, rotER.z, pose.holdsWeights, orbitAngle, cycle);

      _drawTorsoAndHead(canvas, pHead, pNeck, pChest, pPelvis, pSL, pSR, pHipL, pHipR, orbitAngle, pose.coreFlexed);

      _drawLeftLeg(canvas, pHipL, pKL, pFL, pose.quadFlexed, rotKL.z);
      _drawLeftArm(canvas, pSL, pEL, pHL, pose.armFlexed, rotEL.z, pose.holdsWeights, orbitAngle, cycle);
    }

    // 7. Draw Kinetic Angle HUD Overlay
    if (pose.hudJoint != null && pose.hudP1 != null && pose.hudP2 != null) {
      final pJ = pose.hudJoint!.rotateY(orbitAngle).project(cx, groundY);
      final p1 = pose.hudP1!.rotateY(orbitAngle).project(cx, groundY);
      final p2 = pose.hudP2!.rotateY(orbitAngle).project(cx, groundY);
      _drawKineticAngleHUD(canvas, pJ, p1, p2, pose.hudAngleDeg, pose.hudLabel);
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // UNIVERSAL 3D KINEMATIC POSE CALCULATOR (All Moves Supported)
  // ───────────────────────────────────────────────────────────────────────────
  _Exercise3DPose _computeUniversalExercise3DPose(String s, double cycle, double animProgress) {
    // ── 1. SQUATS & VARIATIONS (Bodyweight, Barbell, Sumo, Goblet, Jump Squat) ──
    if (s.contains('squat') || s.contains('sumo') || s.contains('goblet')) {
      final squatDepth = cycle * 44.0;
      final hipZ = -28.0 * cycle;
      final kneeZ = 20.0 * cycle;
      final chestLeanZ = -12.0 * cycle;
      final armCounterZ = 34.0 * cycle;
      final kneeFlex = cycle > 0.45;
      final angleDeg = 175.0 - (cycle * 85.0);

      return _Exercise3DPose(
        head: _Vector3D(0, -145 + squatDepth * 0.9, chestLeanZ - 4),
        neck: _Vector3D(0, -130 + squatDepth * 0.9, chestLeanZ - 2),
        chest: _Vector3D(0, -108 + squatDepth * 0.95, chestLeanZ),
        pelvis: _Vector3D(0, -68 + squatDepth, hipZ),
        shoulderL: _Vector3D(-24, -112 + squatDepth * 0.95, chestLeanZ),
        shoulderR: _Vector3D(24, -112 + squatDepth * 0.95, chestLeanZ),
        elbowL: _Vector3D(-22, -92 + squatDepth * 0.8, armCounterZ * 0.6),
        elbowR: _Vector3D(22, -92 + squatDepth * 0.8, armCounterZ * 0.6),
        handL: _Vector3D(-16, -88 + squatDepth * 0.7, armCounterZ),
        handR: _Vector3D(16, -88 + squatDepth * 0.7, armCounterZ),
        hipL: _Vector3D(-18, -66 + squatDepth, hipZ),
        hipR: _Vector3D(18, -66 + squatDepth, hipZ),
        kneeL: _Vector3D(-20, -36 + squatDepth * 0.35, kneeZ),
        kneeR: _Vector3D(20, -36 + squatDepth * 0.35, kneeZ),
        footL: const _Vector3D(-22, -4, 0),
        footR: const _Vector3D(22, -4, 0),
        quadFlexed: kneeFlex,
        armFlexed: false,
        coreFlexed: true,
        elevation: 0.0,
        holdsWeights: s.contains('goblet') || s.contains('barbell'),
        hudJoint: _Vector3D(20, -36 + squatDepth * 0.35, kneeZ),
        hudP1: _Vector3D(18, -66 + squatDepth, hipZ),
        hudP2: const _Vector3D(22, -4, 0),
        hudAngleDeg: angleDeg,
        hudLabel: cycle > 0.8 ? '90° PARALLEL' : '${angleDeg.round()}° SQUAT',
      );
    }

    // ── 2. LUNGES (Reverse, Forward, Walking, Bulgarian Split Squat) ──
    if (s.contains('lunge') || s.contains('split-squat') || s.contains('step-up')) {
      final lungeDepth = cycle * 38.0;
      final backLegZ = -38.0 * cycle;
      final frontLegZ = 24.0 * cycle;
      final isLow = cycle > 0.45;

      return _Exercise3DPose(
        head: _Vector3D(0, -145 + lungeDepth * 0.85, 0),
        neck: _Vector3D(0, -130 + lungeDepth * 0.85, 0),
        chest: _Vector3D(0, -108 + lungeDepth * 0.85, 0),
        pelvis: _Vector3D(0, -68 + lungeDepth, 0),
        shoulderL: _Vector3D(-24, -112 + lungeDepth * 0.85, 0),
        shoulderR: _Vector3D(24, -112 + lungeDepth * 0.85, 0),
        elbowL: _Vector3D(-24, -82 + lungeDepth * 0.85, 0),
        elbowR: _Vector3D(24, -82 + lungeDepth * 0.85, 0),
        handL: _Vector3D(-22, -54 + lungeDepth * 0.85, 0),
        handR: _Vector3D(22, -54 + lungeDepth * 0.85, 0),
        hipL: _Vector3D(-16, -66 + lungeDepth, 0),
        hipR: _Vector3D(16, -66 + lungeDepth, 0),
        kneeL: _Vector3D(-18, -36 + lungeDepth * 0.4, frontLegZ),
        kneeR: _Vector3D(18, -36 + lungeDepth * 0.85, backLegZ),
        footL: _Vector3D(-18, -4, frontLegZ * 0.7),
        footR: _Vector3D(18, -4, backLegZ * 1.1),
        quadFlexed: isLow,
        armFlexed: false,
        coreFlexed: true,
        elevation: 0.0,
        holdsWeights: false,
        hudJoint: _Vector3D(-18, -36 + lungeDepth * 0.4, frontLegZ),
        hudP1: _Vector3D(-16, -66 + lungeDepth, 0),
        hudP2: _Vector3D(-18, -4, frontLegZ * 0.7),
        hudAngleDeg: 180.0 - (cycle * 90.0),
        hudLabel: isLow ? '90° FRONT KNEE' : 'LUNGE DEPTH',
      );
    }

    // ── 3. BICEP CURLS (Dumbbell, Hammer, Concentration, Preacher) ──
    if (s.contains('bicep') || s.contains('curl') || s.contains('hammer')) {
      final handZ = 6.0 + (math.sin(cycle * math.pi * 0.9) * 26.0);
      final handY = -48.0 - (cycle * 48.0);
      final isPeak = cycle > 0.45;
      final angleDeg = 160.0 - (cycle * 115.0);

      return _Exercise3DPose(
        head: const _Vector3D(0, -145, 0),
        neck: const _Vector3D(0, -130, 0),
        chest: const _Vector3D(0, -108, 0),
        pelvis: const _Vector3D(0, -68, 0),
        shoulderL: const _Vector3D(-24, -112, 0),
        shoulderR: const _Vector3D(24, -112, 0),
        elbowL: const _Vector3D(-26, -76, 2),
        elbowR: const _Vector3D(26, -76, 2),
        handL: _Vector3D(-24, handY, handZ),
        handR: _Vector3D(24, handY, handZ),
        hipL: const _Vector3D(-16, -66, 0),
        hipR: const _Vector3D(16, -66, 0),
        kneeL: const _Vector3D(-16, -35, 0),
        kneeR: const _Vector3D(16, -35, 0),
        footL: const _Vector3D(-16, -4, 0),
        footR: const _Vector3D(16, -4, 0),
        quadFlexed: false,
        armFlexed: isPeak,
        coreFlexed: true,
        elevation: 0.0,
        holdsWeights: true,
        hudJoint: const _Vector3D(26, -76, 2),
        hudP1: const _Vector3D(24, -112, 0),
        hudP2: _Vector3D(24, handY, handZ),
        hudAngleDeg: angleDeg,
        hudLabel: isPeak ? '45° PEAK SQUEEZE' : '${angleDeg.round()}° CURL',
      );
    }

    // ── 4. PUSH-UPS & CHEST PRESS (Plank Pushup, Bench Press, Diamond, Incline) ──
    if (s.contains('push-up') || s.contains('pushup') || s.contains('chest') || s.contains('bench-press') || s.contains('fly')) {
      final dip = cycle * 28.0;
      final chestY = -42.0 + dip;
      final elbowY = -34.0 + (dip * 0.7);
      final isBottom = cycle > 0.45;
      final angleDeg = 165.0 - (cycle * 75.0);

      return _Exercise3DPose(
        head: _Vector3D(0, chestY - 14, 52),
        neck: _Vector3D(0, chestY - 4, 42),
        chest: _Vector3D(0, chestY, 30),
        pelvis: _Vector3D(0, chestY + 6, -18),
        shoulderL: _Vector3D(-26, chestY - 2, 30),
        shoulderR: _Vector3D(26, chestY - 2, 30),
        elbowL: _Vector3D(-34, elbowY, 20),
        elbowR: _Vector3D(34, elbowY, 20),
        handL: const _Vector3D(-28, -6, 26),
        handR: const _Vector3D(28, -6, 26),
        hipL: _Vector3D(-14, chestY + 8, -20),
        hipR: _Vector3D(14, chestY + 8, -20),
        kneeL: _Vector3D(-12, chestY + 12, -60),
        kneeR: _Vector3D(12, chestY + 12, -60),
        footL: const _Vector3D(-10, -6, -98),
        footR: const _Vector3D(10, -6, -98),
        quadFlexed: false,
        armFlexed: isBottom,
        coreFlexed: true,
        elevation: 0.0,
        holdsWeights: false,
        hudJoint: _Vector3D(34, elbowY, 20),
        hudP1: _Vector3D(26, chestY - 2, 30),
        hudP2: const _Vector3D(28, -6, 26),
        hudAngleDeg: angleDeg,
        hudLabel: isBottom ? '90° CHEST DIP' : '${angleDeg.round()}° PRESS',
      );
    }

    // ── 5. WALL SIT & STATIC LEG HOLDS ──
    if (s.contains('wall-sit') || (s.contains('wall') && s.contains('sit'))) {
      return _Exercise3DPose(
        head: const _Vector3D(0, -112, -22),
        neck: const _Vector3D(0, -98, -22),
        chest: const _Vector3D(0, -82, -22),
        pelvis: const _Vector3D(0, -44, -22),
        shoulderL: const _Vector3D(-22, -84, -20),
        shoulderR: const _Vector3D(22, -84, -20),
        elbowL: const _Vector3D(-24, -62, -10),
        elbowR: const _Vector3D(24, -62, -10),
        handL: const _Vector3D(-18, -44, 4),
        handR: const _Vector3D(18, -44, 4),
        hipL: const _Vector3D(-16, -42, -20),
        hipR: const _Vector3D(16, -42, -20),
        kneeL: const _Vector3D(-18, -42, 16),
        kneeR: const _Vector3D(18, -42, 16),
        footL: const _Vector3D(-18, -4, 16),
        footR: const _Vector3D(18, -4, 16),
        quadFlexed: true,
        armFlexed: false,
        coreFlexed: true,
        elevation: 0.0,
        holdsWeights: false,
        isWallExercise: true,
        hudJoint: const _Vector3D(18, -42, 16),
        hudP1: const _Vector3D(16, -42, -20),
        hudP2: const _Vector3D(18, -4, 16),
        hudAngleDeg: 90.0,
        hudLabel: '90° ISOMETRIC HOLD',
      );
    }

    // ── 6. GLUTE BRIDGE & HIP THRUST ──
    if (s.contains('bridge') || s.contains('glute') || s.contains('hip-thrust')) {
      final lift = cycle * 44.0;
      final pelvisY = -12.0 - lift;
      final isHigh = cycle > 0.45;

      return _Exercise3DPose(
        head: const _Vector3D(0, -10, -56),
        neck: const _Vector3D(0, -10, -44),
        chest: const _Vector3D(0, -14, -28),
        pelvis: _Vector3D(0, pelvisY, 8),
        shoulderL: const _Vector3D(-24, -10, -32),
        shoulderR: const _Vector3D(24, -10, -32),
        elbowL: const _Vector3D(-28, -8, -14),
        elbowR: const _Vector3D(28, -8, -14),
        handL: const _Vector3D(-24, -4, 4),
        handR: const _Vector3D(24, -4, 4),
        hipL: _Vector3D(-16, pelvisY, 8),
        hipR: _Vector3D(16, pelvisY, 8),
        kneeL: _Vector3D(-18, pelvisY - 6, 32),
        kneeR: _Vector3D(18, pelvisY - 6, 32),
        footL: const _Vector3D(-18, -4, 34),
        footR: const _Vector3D(18, -4, 34),
        quadFlexed: isHigh,
        armFlexed: false,
        coreFlexed: true,
        elevation: 0.0,
        holdsWeights: false,
        hudJoint: _Vector3D(0, pelvisY, 8),
        hudP1: const _Vector3D(0, -14, -28),
        hudP2: _Vector3D(18, pelvisY - 6, 32),
        hudAngleDeg: 180.0 - (cycle * 25.0),
        hudLabel: isHigh ? 'PEAK GLUTE LOCKOUT' : 'HIP THRUST',
      );
    }

    // ── 7. OVERHEAD PRESS & SHOULDERS (Military, Arnold, Lateral Raise) ──
    if (s.contains('shoulder') || s.contains('overhead') || s.contains('military') || s.contains('lateral-raise')) {
      final pressY = -106.0 - (cycle * 62.0);
      final handX = 26.0 - (cycle * 8.0);
      final isLockout = cycle > 0.45;
      final angleDeg = 90.0 + (cycle * 85.0);

      return _Exercise3DPose(
        head: const _Vector3D(0, -145, 0),
        neck: const _Vector3D(0, -130, 0),
        chest: const _Vector3D(0, -108, 0),
        pelvis: const _Vector3D(0, -68, 0),
        shoulderL: const _Vector3D(-24, -112, 0),
        shoulderR: const _Vector3D(24, -112, 0),
        elbowL: _Vector3D(-handX - 4, pressY + 28, 2),
        elbowR: _Vector3D(handX + 4, pressY + 28, 2),
        handL: _Vector3D(-handX, pressY, 2),
        handR: _Vector3D(handX, pressY, 2),
        hipL: const _Vector3D(-16, -66, 0),
        hipR: const _Vector3D(16, -66, 0),
        kneeL: const _Vector3D(-16, -35, 0),
        kneeR: const _Vector3D(16, -35, 0),
        footL: const _Vector3D(-16, -4, 0),
        footR: const _Vector3D(16, -4, 0),
        quadFlexed: false,
        armFlexed: isLockout,
        coreFlexed: true,
        elevation: 0.0,
        holdsWeights: true,
        hudJoint: _Vector3D(handX + 4, pressY + 28, 2),
        hudP1: const _Vector3D(24, -112, 0),
        hudP2: _Vector3D(handX, pressY, 2),
        hudAngleDeg: angleDeg,
        hudLabel: isLockout ? '180° LOCKOUT' : '${angleDeg.round()}° PRESS',
      );
    }

    // ── 8. TRICEPS (Dips, Kickbacks, Extensions) ──
    if (s.contains('tricep') || s.contains('dip')) {
      final dipDepth = cycle * 24.0;
      final armAngle = 90.0 + (cycle * 60.0);

      return _Exercise3DPose(
        head: _Vector3D(0, -115 + dipDepth, -10),
        neck: _Vector3D(0, -100 + dipDepth, -10),
        chest: _Vector3D(0, -84 + dipDepth, -10),
        pelvis: _Vector3D(0, -48 + dipDepth, -10),
        shoulderL: _Vector3D(-22, -86 + dipDepth, -8),
        shoulderR: _Vector3D(22, -86 + dipDepth, -8),
        elbowL: _Vector3D(-26, -64 + (dipDepth * 0.4), -24),
        elbowR: _Vector3D(26, -64 + (dipDepth * 0.4), -24),
        handL: const _Vector3D(-24, -44, -10),
        handR: const _Vector3D(24, -44, -10),
        hipL: _Vector3D(-16, -46 + dipDepth, 4),
        hipR: _Vector3D(16, -46 + dipDepth, 4),
        kneeL: _Vector3D(-18, -44, 28),
        kneeR: _Vector3D(18, -44, 28),
        footL: const _Vector3D(-18, -4, 28),
        footR: const _Vector3D(18, -4, 28),
        quadFlexed: false,
        armFlexed: cycle > 0.45,
        coreFlexed: true,
        elevation: 0.0,
        holdsWeights: false,
        hudJoint: _Vector3D(26, -64 + (dipDepth * 0.4), -24),
        hudP1: _Vector3D(22, -86 + dipDepth, -8),
        hudP2: const _Vector3D(24, -44, -10),
        hudAngleDeg: armAngle,
        hudLabel: 'TRICEP EXTENSION',
      );
    }

    // ── 9. BACK & PULLS (Pull-ups, Lat Pulldowns, Rows, Deadlifts) ──
    if (s.contains('pull') || s.contains('row') || s.contains('lat') || s.contains('deadlift')) {
      final pullY = s.contains('deadlift') ? (cycle * 50.0) : -(cycle * 38.0);
      final isBackFiring = cycle > 0.45;

      return _Exercise3DPose(
        head: _Vector3D(0, -145 + pullY * 0.5, 0),
        neck: _Vector3D(0, -130 + pullY * 0.5, 0),
        chest: _Vector3D(0, -108 + pullY * 0.6, 0),
        pelvis: _Vector3D(0, -68 + pullY * 0.7, 0),
        shoulderL: _Vector3D(-26, -114 + pullY * 0.6, 0),
        shoulderR: _Vector3D(26, -114 + pullY * 0.6, 0),
        elbowL: _Vector3D(-30, -96 + pullY, -14 * cycle),
        elbowR: _Vector3D(30, -96 + pullY, -14 * cycle),
        handL: _Vector3D(-24, -80 + pullY * 1.2, 4),
        handR: _Vector3D(24, -80 + pullY * 1.2, 4),
        hipL: _Vector3D(-16, -66 + pullY * 0.7, 0),
        hipR: _Vector3D(16, -66 + pullY * 0.7, 0),
        kneeL: const _Vector3D(-16, -35, 0),
        kneeR: const _Vector3D(16, -35, 0),
        footL: const _Vector3D(-18, -4, 0),
        footR: const _Vector3D(18, -4, 0),
        quadFlexed: false,
        armFlexed: isBackFiring,
        coreFlexed: true,
        elevation: 0.0,
        holdsWeights: true,
        hudJoint: _Vector3D(30, -96 + pullY, -14 * cycle),
        hudP1: _Vector3D(26, -114 + pullY * 0.6, 0),
        hudP2: _Vector3D(24, -80 + pullY * 1.2, 4),
        hudAngleDeg: 120.0 - (cycle * 50.0),
        hudLabel: isBackFiring ? 'LAT ENGAGEMENT' : 'BACK DRIVE',
      );
    }

    // ── 10. CALF RAISE (Plantarflexion on Toes) ──
    if (s.contains('calf') || s.contains('raise') || s.contains('tiptoe')) {
      final lift = cycle * 20.0;
      final isPeak = cycle > 0.45;

      return _Exercise3DPose(
        head: _Vector3D(0, -145 - lift, 0),
        neck: _Vector3D(0, -130 - lift, 0),
        chest: _Vector3D(0, -108 - lift, 0),
        pelvis: _Vector3D(0, -68 - lift, 0),
        shoulderL: _Vector3D(-24, -112 - lift, 0),
        shoulderR: _Vector3D(24, -112 - lift, 0),
        elbowL: _Vector3D(-26, -82 - lift, 0),
        elbowR: _Vector3D(26, -82 - lift, 0),
        handL: _Vector3D(-24, -54 - lift, 0),
        handR: _Vector3D(24, -54 - lift, 0),
        hipL: _Vector3D(-16, -66 - lift, 0),
        hipR: _Vector3D(16, -66 - lift, 0),
        kneeL: _Vector3D(-16, -35 - lift, 0),
        kneeR: _Vector3D(16, -35 - lift, 0),
        footL: _Vector3D(-16, -4 - lift * 0.7, 0),
        footR: _Vector3D(16, -4 - lift * 0.7, 0),
        quadFlexed: isPeak,
        armFlexed: false,
        coreFlexed: true,
        elevation: lift,
        holdsWeights: false,
        hudJoint: _Vector3D(16, -4 - lift * 0.7, 0),
        hudP1: _Vector3D(16, -35 - lift, 0),
        hudP2: const _Vector3D(16, -4, 12),
        hudAngleDeg: 120.0 + (cycle * 35.0),
        hudLabel: isPeak ? 'PEAK PLANTARFLEX' : 'CALF DRIVE',
      );
    }

    // ── 11. CORE & PLANKS & CRUNCHES (Plank, Side Plank, Mountain Climber, Deadbug) ──
    if (s.contains('plank') || s.contains('core') || s.contains('abs') || s.contains('crunch') || s.contains('sit-up') || s.contains('mountain')) {
      final isMoving = s.contains('mountain') || s.contains('crunch');
      final kneeDrive = isMoving ? (math.sin(animProgress * 4 * math.pi) * 32.0).abs() : 0.0;

      return _Exercise3DPose(
        head: const _Vector3D(0, -38, 48),
        neck: const _Vector3D(0, -32, 38),
        chest: const _Vector3D(0, -30, 26),
        pelvis: const _Vector3D(0, -32, -18),
        shoulderL: const _Vector3D(-24, -32, 26),
        shoulderR: const _Vector3D(24, -32, 26),
        elbowL: const _Vector3D(-24, -8, 26),
        elbowR: const _Vector3D(24, -8, 26),
        handL: const _Vector3D(-16, -6, 40),
        handR: const _Vector3D(16, -6, 40),
        hipL: const _Vector3D(-14, -32, -20),
        hipR: const _Vector3D(14, -32, -20),
        kneeL: _Vector3D(-14, -28, -60 + kneeDrive),
        kneeR: const _Vector3D(14, -28, -60),
        footL: const _Vector3D(-12, -6, -96),
        footR: const _Vector3D(12, -6, -96),
        quadFlexed: false,
        armFlexed: false,
        coreFlexed: true,
        elevation: 0.0,
        holdsWeights: false,
        hudJoint: const _Vector3D(0, -32, -18),
        hudP1: const _Vector3D(0, -30, 26),
        hudP2: const _Vector3D(14, -28, -60),
        hudAngleDeg: 180.0,
        hudLabel: 'CORE STABILITY 180°',
      );
    }

    // ── 12. YOGA & MOBILITY (Downward Dog, Cobra, Warrior, Tree, Childs Pose) ──
    if (s.contains('yoga') || s.contains('dog') || s.contains('cobra') || s.contains('warrior') || s.contains('tree') || s.contains('child') || s.contains('stretch')) {
      if (s.contains('dog') || s.contains('downward')) {
        // Downward Dog: Inverted V-Shape
        return _Exercise3DPose(
          head: const _Vector3D(0, -42, 10),
          neck: const _Vector3D(0, -50, 6),
          chest: const _Vector3D(0, -62, -2),
          pelvis: const _Vector3D(0, -84, -28), // High apex
          shoulderL: const _Vector3D(-20, -58, 2),
          shoulderR: const _Vector3D(20, -58, 2),
          elbowL: const _Vector3D(-24, -34, 20),
          elbowR: const _Vector3D(24, -34, 20),
          handL: const _Vector3D(-22, -6, 38),
          handR: const _Vector3D(22, -6, 38),
          hipL: const _Vector3D(-14, -82, -28),
          hipR: const _Vector3D(14, -82, -28),
          kneeL: const _Vector3D(-14, -46, -48),
          kneeR: const _Vector3D(14, -46, -48),
          footL: const _Vector3D(-14, -6, -68),
          footR: const _Vector3D(14, -6, -68),
          quadFlexed: false,
          armFlexed: true,
          coreFlexed: true,
          elevation: 0.0,
          holdsWeights: false,
          hudJoint: const _Vector3D(0, -84, -28),
          hudP1: const _Vector3D(0, -62, -2),
          hudP2: const _Vector3D(-14, -46, -48),
          hudAngleDeg: 75.0,
          hudLabel: 'INVERTED V-POSE',
        );
      } else if (s.contains('cobra')) {
        // Cobra Pose: Chest arched upward, hands pressing
        return _Exercise3DPose(
          head: const _Vector3D(0, -78, 14),
          neck: const _Vector3D(0, -66, 12),
          chest: const _Vector3D(0, -52, 10),
          pelvis: const _Vector3D(0, -10, -18),
          shoulderL: const _Vector3D(-22, -54, 10),
          shoulderR: const _Vector3D(22, -54, 10),
          elbowL: const _Vector3D(-26, -30, 10),
          elbowR: const _Vector3D(26, -30, 10),
          handL: const _Vector3D(-24, -6, 16),
          handR: const _Vector3D(24, -6, 16),
          hipL: const _Vector3D(-14, -10, -20),
          hipR: const _Vector3D(14, -10, -20),
          kneeL: const _Vector3D(-12, -8, -50),
          kneeR: const _Vector3D(12, -8, -50),
          footL: const _Vector3D(-10, -6, -80),
          footR: const _Vector3D(10, -6, -80),
          quadFlexed: false,
          armFlexed: true,
          coreFlexed: true,
          elevation: 0.0,
          holdsWeights: false,
          hudJoint: const _Vector3D(0, -52, 10),
          hudP1: const _Vector3D(0, -78, 14),
          hudP2: const _Vector3D(0, -10, -18),
          hudAngleDeg: 140.0,
          hudLabel: 'SPINAL EXTENSION',
        );
      }
    }

    // ── 13. CARDIO / HIIT / JUMPING JACKS / RUNNING STRIDE (Dynamic Default) ──
    final bounce = (math.sin(animProgress * 4 * math.pi) * 8.0).abs();
    final spread = cycle * 24.0;
    final armLift = cycle * 68.0;

    return _Exercise3DPose(
      head: _Vector3D(0, -145 - bounce, 0),
      neck: _Vector3D(0, -130 - bounce, 0),
      chest: _Vector3D(0, -108 - bounce, 0),
      pelvis: _Vector3D(0, -68 - bounce, 0),
      shoulderL: _Vector3D(-24, -112 - bounce, 0),
      shoulderR: _Vector3D(24, -112 - bounce, 0),
      elbowL: _Vector3D(-28 - (spread * 0.6), -86 - bounce - (armLift * 0.6), 0),
      elbowR: _Vector3D(28 + (spread * 0.6), -86 - bounce - (armLift * 0.6), 0),
      handL: _Vector3D(-24 - spread, -62 - bounce - armLift, 0),
      handR: _Vector3D(24 + spread, -62 - bounce - armLift, 0),
      hipL: _Vector3D(-16, -66 - bounce, 0),
      hipR: _Vector3D(16, -66 - bounce, 0),
      kneeL: _Vector3D(-18 - (spread * 0.5), -35 - bounce, 0),
      kneeR: _Vector3D(18 + (spread * 0.5), -35 - bounce, 0),
      footL: _Vector3D(-18 - spread, -4 - bounce, 0),
      footR: _Vector3D(18 + spread, -4 - bounce, 0),
      quadFlexed: cycle > 0.4,
      armFlexed: cycle > 0.4,
      coreFlexed: true,
      elevation: bounce,
      holdsWeights: false,
      hudJoint: null,
      hudP1: null,
      hudP2: null,
      hudAngleDeg: 0,
      hudLabel: '',
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 3D RENDERING SUBROUTINES (CYBERNETIC ANATOMY & PHOTO LIKENESS SHADING)
  // ───────────────────────────────────────────────────────────────────────────

  void _drawPerspectiveFloorGrid(Canvas canvas, Size size, double cx, double groundY, double orbitAngle) {
    for (int i = 1; i <= 3; i++) {
      final rx = 65.0 * i;
      final ry = rx * 0.28;
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, groundY), width: rx * 2, height: ry * 2), _gridPaint);
    }
    canvas.drawLine(Offset(24, groundY), Offset(size.width - 24, groundY), _horizonLinePaint);

    for (double deg = -60; deg <= 60; deg += 30) {
      final rad = deg * math.pi / 180;
      final xEnd = cx + math.tan(rad) * 180;
      canvas.drawLine(Offset(cx, groundY), Offset(xEnd.clamp(24.0, size.width - 24.0), groundY + 22), _radialRayPaint);
    }
  }

  void _drawGroundContactShadow(Canvas canvas, Offset fl, Offset fr, double cx, double groundY, double elevation, double cycle) {
    final shadowCx = (fl.dx + fr.dx) / 2;
    final shadowWidth = math.max(68.0 - (elevation * 1.2), 34.0);
    final shadowHeight = shadowWidth * 0.25;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(shadowCx, groundY + 2), width: shadowWidth, height: shadowHeight),
      _shadowPaint,
    );
  }

  void _drawHolographicWall(Canvas canvas, double cx, double groundY, double orbitAngle) {
    final wallX = cx - 38 + (math.sin(orbitAngle) * 35);
    for (double y = groundY - 140; y <= groundY; y += 22) {
      canvas.drawLine(Offset(wallX - 35, y), Offset(wallX + 35, y), _wallLinePaint);
    }
    canvas.drawLine(Offset(wallX - 35, groundY - 140), Offset(wallX - 35, groundY), _wallLinePaint);
    canvas.drawLine(Offset(wallX + 35, groundY - 140), Offset(wallX + 35, groundY), _wallLinePaint);
  }

  void _drawVolumetricLimb(
    Canvas canvas,
    Offset p1,
    Offset p2,
    double r1,
    double r2, {
    required bool isFlexed,
    required double depth,
  }) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 1.0) return;

    final nx = -dy / dist;
    final ny = dx / dist;

    final path = Path()
      ..moveTo(p1.dx + nx * r1, p1.dy + ny * r1)
      ..lineTo(p2.dx + nx * r2, p2.dy + ny * r2)
      ..arcToPoint(Offset(p2.dx - nx * r2, p2.dy - ny * r2), radius: Radius.circular(r2))
      ..lineTo(p1.dx - nx * r1, p1.dy - ny * r1)
      ..arcToPoint(Offset(p1.dx + nx * r1, p1.dy + ny * r1), radius: Radius.circular(r1))
      ..close();

    // Muscle Contraction Aura
    if (isFlexed) {
      canvas.drawPath(path, _muscleGlowPaint);
    }

    final gradient = LinearGradient(
      begin: Alignment(nx, ny),
      end: Alignment(-nx, -ny),
      colors: const [
        Color(0xFF161E2C),
        Color(0xFF7F9CB8),
        Color(0xFF222C3D),
        Color(0xFF0F141F),
      ],
      stops: const [0.0, 0.35, 0.70, 1.0],
    );

    final limbPaint = Paint()
      ..shader = gradient.createShader(Rect.fromPoints(p1, p2))
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, limbPaint);

    // Glowing Conduit
    _conduitPaint
      ..color = isFlexed ? const Color(0xFF34FF8C) : const Color(0x7000D2FF)
      ..strokeWidth = isFlexed ? 2.8 : 1.8;
    canvas.drawLine(p1, p2, _conduitPaint);

    _draw3DServoJoint(canvas, p1, r1 * 0.95, isFlexed);
    _draw3DServoJoint(canvas, p2, r2 * 0.95, isFlexed);
  }

  void _draw3DServoJoint(Canvas canvas, Offset center, double radius, bool isFlexed) {
    canvas.drawCircle(center, radius, _servoHousingPaint);
    canvas.drawCircle(center, radius, _servoRimPaint);
    _servoLedPaint.color = isFlexed ? const Color(0xFF34FF8C) : const Color(0xFF00D2FF);
    canvas.drawCircle(center, radius * 0.42, _servoLedPaint);
  }

  void _drawLeftArm(Canvas canvas, Offset s, Offset e, Offset h, bool flexed, double depth, bool holdsWeights, double orbitAngle, double cycle) {
    _drawVolumetricLimb(canvas, s, e, 6.5, 5.0, isFlexed: flexed, depth: depth);
    _drawVolumetricLimb(canvas, e, h, 5.0, 4.0, isFlexed: flexed, depth: depth);
    _drawHandAndWeight(canvas, h, holdsWeights, orbitAngle, cycle);
  }

  void _drawRightArm(Canvas canvas, Offset s, Offset e, Offset h, bool flexed, double depth, bool holdsWeights, double orbitAngle, double cycle) {
    _drawVolumetricLimb(canvas, s, e, 6.5, 5.0, isFlexed: flexed, depth: depth);
    _drawVolumetricLimb(canvas, e, h, 5.0, 4.0, isFlexed: flexed, depth: depth);
    _drawHandAndWeight(canvas, h, holdsWeights, orbitAngle, cycle);
  }

  void _drawLeftLeg(Canvas canvas, Offset hip, Offset knee, Offset foot, bool flexed, double depth) {
    _drawVolumetricLimb(canvas, hip, knee, 9.0, 6.8, isFlexed: flexed, depth: depth);
    _drawVolumetricLimb(canvas, knee, foot, 6.8, 5.2, isFlexed: flexed, depth: depth);
    _drawAthleticBoot(canvas, foot, flexed);
  }

  void _drawRightLeg(Canvas canvas, Offset hip, Offset knee, Offset foot, bool flexed, double depth) {
    _drawVolumetricLimb(canvas, hip, knee, 9.0, 6.8, isFlexed: flexed, depth: depth);
    _drawVolumetricLimb(canvas, knee, foot, 6.8, 5.2, isFlexed: flexed, depth: depth);
    _drawAthleticBoot(canvas, foot, flexed);
  }

  void _drawAthleticBoot(Canvas canvas, Offset foot, bool flexed) {
    final bootPath = Path()
      ..moveTo(foot.dx - 6, foot.dy - 3)
      ..lineTo(foot.dx + 12, foot.dy - 3)
      ..lineTo(foot.dx + 14, foot.dy + 3)
      ..lineTo(foot.dx - 8, foot.dy + 3)
      ..close();

    canvas.drawPath(bootPath, Paint()..color = const Color(0xFF1B2332)..style = PaintingStyle.fill);

    final treadPaint = Paint()
      ..color = flexed ? const Color(0xFF34FF8C) : const Color(0xFF00D2FF)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(foot.dx - 8, foot.dy + 3), Offset(foot.dx + 14, foot.dy + 3), treadPaint);
  }

  void _drawHandAndWeight(Canvas canvas, Offset hand, bool holdsWeights, double orbitAngle, double cycle) {
    canvas.drawCircle(hand, 4.5, Paint()..color = const Color(0xFF243044));
    canvas.drawCircle(hand, 4.5, Paint()..color = const Color(0xFF8BA7C4)..style = PaintingStyle.stroke..strokeWidth = 1.2);

    if (holdsWeights) {
      canvas.drawLine(Offset(hand.dx - 12, hand.dy), Offset(hand.dx + 12, hand.dy), _barbellBarPaint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(hand.dx - 11, hand.dy), width: 5, height: 16), const Radius.circular(2)),
        _weightPlatePaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(hand.dx - 11, hand.dy), width: 5, height: 16), const Radius.circular(2)),
        _weightPlateRim,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(hand.dx + 11, hand.dy), width: 5, height: 16), const Radius.circular(2)),
        _weightPlatePaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(hand.dx + 11, hand.dy), width: 5, height: 16), const Radius.circular(2)),
        _weightPlateRim,
      );
    }
  }

  void _drawTorsoAndHead(
    Canvas canvas,
    Offset head,
    Offset neck,
    Offset chest,
    Offset pelvis,
    Offset sL,
    Offset sR,
    Offset hipL,
    Offset hipR,
    double orbitAngle,
    bool coreFlexed,
  ) {
    final torsoPath = Path()
      ..moveTo(sL.dx, sL.dy)
      ..lineTo(sR.dx, sR.dy)
      ..lineTo(hipR.dx, hipR.dy)
      ..lineTo(hipL.dx, hipL.dy)
      ..close();

    final torsoGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: const [
        Color(0xFF1C2638),
        Color(0xFF4A6882),
        Color(0xFF18202E),
        Color(0xFF0D121B),
      ],
      stops: const [0.0, 0.30, 0.75, 1.0],
    );

    canvas.drawPath(
      torsoPath,
      Paint()
        ..shader = torsoGradient.createShader(Rect.fromPoints(sL, hipR))
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(torsoPath, _torsoOutlinePaint);

    // Arc Reactor Core at Sternum
    final corePos = Offset(chest.dx, chest.dy + 8);
    canvas.drawCircle(corePos, 12, _arcReactorGlowPaint);
    canvas.drawCircle(corePos, 7.5, _arcReactorRingPaint);
    canvas.drawCircle(corePos, 4.0, _arcReactorCorePaint);

    // 6-Pack Abs Plates
    final absPaint = Paint()
      ..color = coreFlexed ? const Color(0xFF34FF8C).withValues(alpha: 0.45) : const Color(0x3000D2FF)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final spineY1 = chest.dy + 20;
    final spineY2 = pelvis.dy - 6;
    final midX = (chest.dx + pelvis.dx) / 2;

    canvas.drawLine(Offset(midX, spineY1), Offset(midX, spineY2), absPaint);
    for (double f = 0.25; f <= 0.85; f += 0.30) {
      final y = spineY1 + (spineY2 - spineY1) * f;
      final halfW = 10.0 * (1.0 - (f * 0.25));
      canvas.drawLine(Offset(midX - halfW, y), Offset(midX + halfW, y), absPaint);
    }

    if (orbitAngle.abs() > 0.45) {
      final spinePaint = Paint()
        ..color = const Color(0xFF8BA7C4).withValues(alpha: 0.4)
        ..strokeWidth = 2.0;
      final spineShift = math.sin(orbitAngle) * -8;
      canvas.drawLine(Offset(chest.dx + spineShift, chest.dy), Offset(pelvis.dx + spineShift, pelvis.dy), spinePaint);
    }

    final neckPaint = Paint()
      ..color = const Color(0xFF222C3E)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromCenter(center: neck, width: 8, height: 12), neckPaint);

    // ── Head & User Likeness Facial Customization ──
    _drawPersonalizedCyberHead(canvas, head, neck, orbitAngle);
  }

  /// Draw Head with User Likeness (Skin tone, Haircut, Beard & Visor matching user's photo)
  void _drawPersonalizedCyberHead(Canvas canvas, Offset head, Offset neck, double orbitAngle) {
    const headRadius = 14.5;
    final visorColor = faceProfile.visorColor;

    // 1. Natural Human Skin Gradient (from faceProfile)
    final skinColors = faceProfile.skinGradientColors;
    final skinGradient = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      radius: 0.9,
      colors: skinColors,
    );

    canvas.drawCircle(
      head,
      headRadius,
      Paint()
        ..shader = skinGradient.createShader(Rect.fromCircle(center: head, radius: headRadius))
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      head,
      headRadius,
      Paint()
        ..color = skinColors[1].withValues(alpha: 0.7)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke,
    );

    // 2. User Haircut Silhouette (Wavy Pixar curls / Fade / Crop / Topknot)
    final hairPaint = Paint()..color = faceProfile.hairColor..style = PaintingStyle.fill;
    if (faceProfile.hairStyle == 'pixar_wavy') {
      // Flowing stylized waves like reference character
      canvas.drawCircle(Offset(head.dx - headRadius - 2, head.dy - 3), 7.5, hairPaint);
      canvas.drawCircle(Offset(head.dx + headRadius + 2, head.dy - 3), 7.5, hairPaint);
      canvas.drawCircle(Offset(head.dx - headRadius - 1, head.dy + 8), 6.5, hairPaint);
      canvas.drawCircle(Offset(head.dx + headRadius + 1, head.dy + 8), 6.5, hairPaint);

      final topHair = Path()
        ..moveTo(head.dx - headRadius - 2, head.dy - 2)
        ..quadraticBezierTo(head.dx, head.dy - headRadius - 10, head.dx + headRadius + 2, head.dy - 2)
        ..quadraticBezierTo(head.dx, head.dy - headRadius + 2, head.dx - headRadius - 2, head.dy - 2)
        ..close();
      canvas.drawPath(topHair, hairPaint);
    } else if (faceProfile.hairStyle != 'bald_helmet') {
      final hairPath = Path()
        ..moveTo(head.dx - headRadius + 1, head.dy)
        ..quadraticBezierTo(head.dx - headRadius, head.dy - headRadius - 2, head.dx, head.dy - headRadius - 2.5)
        ..quadraticBezierTo(head.dx + headRadius, head.dy - headRadius - 2, head.dx + headRadius - 1, head.dy)
        ..quadraticBezierTo(head.dx, head.dy - headRadius + 4, head.dx - headRadius + 1, head.dy)
        ..close();
      canvas.drawPath(hairPath, hairPaint);

      if (faceProfile.hairStyle == 'curls_bun') {
        canvas.drawCircle(Offset(head.dx, head.dy - headRadius - 4), 4.5, hairPaint);
      }
    }

    // 3. Expressive Pixar Eyes & Smile (when user likeness is active)
    final eyeShiftX = math.sin(orbitAngle) * 5.0;
    if (faceProfile.useUserLikeness) {
      final eyeL = Offset(head.dx - 4.5 + (eyeShiftX * 0.4), head.dy - 1.5);
      final eyeR = Offset(head.dx + 4.5 + (eyeShiftX * 0.4), head.dy - 1.5);

      // Eye whites & pupils
      canvas.drawOval(Rect.fromCenter(center: eyeL, width: 5.5, height: 7), Paint()..color = Colors.white);
      canvas.drawOval(Rect.fromCenter(center: eyeR, width: 5.5, height: 7), Paint()..color = Colors.white);

      canvas.drawCircle(eyeL, 2.4, Paint()..color = const Color(0xFF5C3317));
      canvas.drawCircle(eyeR, 2.4, Paint()..color = const Color(0xFF5C3317));
      canvas.drawCircle(Offset(eyeL.dx - 0.7, eyeL.dy - 0.7), 0.8, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(eyeR.dx - 0.7, eyeR.dy - 0.7), 0.8, Paint()..color = Colors.white);

      // Friendly smile
      final smile = Path()
        ..moveTo(head.dx - 3.5 + (eyeShiftX * 0.3), head.dy + 6.5)
        ..quadraticBezierTo(head.dx + (eyeShiftX * 0.3), head.dy + 9.5, head.dx + 4.5 + (eyeShiftX * 0.3), head.dy + 7);
      canvas.drawPath(
        smile,
        Paint()
          ..color = const Color(0xFF9E4747)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );

      // Male facial hair / stubble if configured
      if (faceProfile.avatarGender == 'male' && faceProfile.facialHair != 'clean') {
        final stubble = Path()
          ..moveTo(head.dx - 8 + (eyeShiftX * 0.3), head.dy + 7)
          ..quadraticBezierTo(head.dx + (eyeShiftX * 0.3), head.dy + 13, head.dx + 8 + (eyeShiftX * 0.3), head.dy + 7);
        canvas.drawPath(
          stubble,
          Paint()
            ..color = faceProfile.hairColor.withValues(alpha: 0.45)
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
      }
    } else {
      // 4. 3D Perspective Curved Visor (Shifts with Orbit Angle)
      final visorShiftX = math.sin(orbitAngle) * 7.5;
      final visorCenter = Offset(head.dx + visorShiftX, head.dy - 1.5);
      final visorWidth = math.max(16.0 - (orbitAngle.abs() * 5.0), 9.0);
      final visorColor = faceProfile.visorColor;

      final visorBg = RRect.fromRectAndRadius(
        Rect.fromCenter(center: visorCenter, width: visorWidth, height: 6.5),
        const Radius.circular(3),
      );
      canvas.drawRRect(visorBg, Paint()..color = const Color(0xFF0A0F16));

      final scanlinePaint = Paint()
        ..color = visorColor
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(visorCenter.dx - (visorWidth * 0.42), visorCenter.dy),
        Offset(visorCenter.dx + (visorWidth * 0.42), visorCenter.dy),
        scanlinePaint,
      );

      canvas.drawCircle(
        visorCenter,
        5.0,
        Paint()
          ..color = visorColor.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }

    // Ear Pods / Anchors
    final earL = Offset(head.dx - headRadius + 1, head.dy);
    final earR = Offset(head.dx + headRadius - 1, head.dy);
    canvas.drawCircle(earL, 2.5, Paint()..color = visorColor);
    canvas.drawCircle(earR, 2.5, Paint()..color = visorColor);
  }

  void _drawKineticAngleHUD(Canvas canvas, Offset joint, Offset p1, Offset p2, double angleDeg, String label) {
    if (angleDeg <= 0) return;
    const arcRadius = 18.0;

    final ray1 = p1 - joint;
    final ray2 = p2 - joint;
    final startAngle = math.atan2(ray1.dy, ray1.dx);
    final sweepAngle = math.atan2(ray2.dy, ray2.dx) - startAngle;

    canvas.drawArc(
      Rect.fromCircle(center: joint, radius: arcRadius),
      startAngle,
      sweepAngle.clamp(-math.pi, math.pi),
      false,
      _hudArcPaint,
    );

    final textSpan = TextSpan(
      text: label,
      style: const TextStyle(
        color: Color(0xFF34FF8C),
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    );
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
    final badgeCenter = Offset(joint.dx + 24, joint.dy - 12);

    final bgRect = Rect.fromCenter(center: badgeCenter, width: tp.width + 10, height: 16);
    canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(4)), _hudBgPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(4)), _hudBorderPaint);
    tp.paint(canvas, Offset(badgeCenter.dx - tp.width / 2, badgeCenter.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _Biomechanical3DAvatarPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.exerciseSlug != exerciseSlug ||
        oldDelegate.orbitAngle != orbitAngle ||
        oldDelegate.faceProfile != faceProfile;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA CLASS FOR 3D EXERCISE POSE
// ─────────────────────────────────────────────────────────────────────────────
class _Exercise3DPose {
  _Exercise3DPose({
    required this.head,
    required this.neck,
    required this.chest,
    required this.pelvis,
    required this.shoulderL,
    required this.shoulderR,
    required this.elbowL,
    required this.elbowR,
    required this.handL,
    required this.handR,
    required this.hipL,
    required this.hipR,
    required this.kneeL,
    required this.kneeR,
    required this.footL,
    required this.footR,
    required this.quadFlexed,
    required this.armFlexed,
    required this.coreFlexed,
    required this.elevation,
    required this.holdsWeights,
    this.isWallExercise = false,
    this.hudJoint,
    this.hudP1,
    this.hudP2,
    this.hudAngleDeg = 0,
    this.hudLabel = '',
  });

  final _Vector3D head;
  final _Vector3D neck;
  final _Vector3D chest;
  final _Vector3D pelvis;
  final _Vector3D shoulderL;
  final _Vector3D shoulderR;
  final _Vector3D elbowL;
  final _Vector3D elbowR;
  final _Vector3D handL;
  final _Vector3D handR;
  final _Vector3D hipL;
  final _Vector3D hipR;
  final _Vector3D kneeL;
  final _Vector3D kneeR;
  final _Vector3D footL;
  final _Vector3D footR;

  final bool quadFlexed;
  final bool armFlexed;
  final bool coreFlexed;
  final double elevation;
  final bool holdsWeights;
  final bool isWallExercise;

  final _Vector3D? hudJoint;
  final _Vector3D? hudP1;
  final _Vector3D? hudP2;
  final double hudAngleDeg;
  final String hudLabel;
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
