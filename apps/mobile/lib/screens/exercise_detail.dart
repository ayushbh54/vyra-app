import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

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
                                color: VColor.accent.withOpacity(0.35),
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
                            color: VColor.accent.withOpacity(0.15),
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

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
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

  String get _currentPhaseName {
    final v = _animCtrl.value;
    if (v < 0.40) {
      return 'Phase 1: Eccentric (Control Down)';
    } else if (v < 0.60) {
      return 'Phase 2: Isometric (Peak Hold & Squeeze)';
    } else {
      return 'Phase 3: Concentric (Drive Up)';
    }
  }

  String get _targetMuscle {
    if (widget.movement?.targetMuscle != null && widget.movement!.targetMuscle.isNotEmpty) {
      return widget.movement!.targetMuscle;
    }
    final s = widget.item.slug.toLowerCase();
    if (s.contains('bridge') || s.contains('glute')) return 'Glutes & Hamstrings';
    if (s.contains('squat')) return 'Quadriceps & Glutes';
    if (s.contains('pushup') || s.contains('press')) return 'Chest & Triceps';
    if (s.contains('plank') || s.contains('core')) return 'Transverse Abdominis';
    return widget.item.category.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: VColor.surfaceRaised,
        borderRadius: BorderRadius.circular(VRadius.lg),
        border: Border.all(color: VColor.accent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info bar
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
                      decoration: const BoxDecoration(color: VColor.accentGreen, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    const Text('VISUAL MOVEMENT GUIDE',
                        style: TextStyle(
                            color: VColor.accent, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  ],
                ),
                Row(
                  children: [
                    InkWell(
                      onTap: _cycleSpeed,
                      borderRadius: BorderRadius.circular(VRadius.sm),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: VColor.steel.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(VRadius.sm),
                        ),
                        child: Text('${_speedMultiplier}x',
                            style: const TextStyle(color: VColor.textMid, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: VSpace.xs),
                    IconButton(
                      icon: Icon(_isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline,
                          color: VColor.text, size: 22),
                      onPressed: _togglePlay,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Simulation Canvas
          SizedBox(
            height: 180,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _animCtrl,
              builder: (context, _) {
                return Stack(
                  children: [
                    CustomPaint(
                      size: const Size(double.infinity, 180),
                      painter: _BiomechanicalPainter(
                        animationProgress: _animCtrl.value,
                        exerciseSlug: widget.item.slug.toLowerCase(),
                      ),
                    ),
                    // Phase indicator overlay
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
                              color: VColor.bg.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(VRadius.sm),
                              border: Border.all(color: VColor.line),
                            ),
                            child: Text(
                              _currentPhaseName,
                              style: const TextStyle(color: VColor.text, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: VColor.accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(VRadius.sm),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.fitness_center_rounded, size: 12, color: VColor.accent),
                                const SizedBox(width: 4),
                                Text(
                                  _targetMuscle,
                                  style: const TextStyle(
                                      color: VColor.accent, fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: VSpace.xs),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BIOMECHANICAL PAINTER (Draws smooth kinematic avatar for exercises)
// ─────────────────────────────────────────────────────────────────────────────
class _BiomechanicalPainter extends CustomPainter {
  _BiomechanicalPainter({
    required this.animationProgress,
    required this.exerciseSlug,
  });

  final double animationProgress;
  final String exerciseSlug;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final groundY = size.height - 38;

    // Floor line
    final groundPaint = Paint()
      ..color = VColor.line.withOpacity(0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(20, groundY), Offset(size.width - 20, groundY), groundPaint);

    final bonePaint = Paint()
      ..color = VColor.text
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final jointPaint = Paint()
      ..color = VColor.accent
      ..style = PaintingStyle.fill;

    final muscleGlowPaint = Paint()
      ..color = VColor.accentGreen.withOpacity(0.6)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    // Sine curve cycle for smooth back-and-forth movement (0 -> 1 -> 0)
    final cycle = (math.sin(animationProgress * 2 * math.pi - math.pi / 2) + 1) / 2;

    if (exerciseSlug.contains('bridge') || exerciseSlug.contains('glute')) {
      // ── GLUTE BRIDGE KINEMATICS ──
      // Lying down horizontally, shoulders on ground, lifting pelvis up
      final shoulder = Offset(cx - 60, groundY - 14);
      final head = Offset(cx - 85, groundY - 18);
      final foot = Offset(cx + 60, groundY - 4);

      // Pelvis moves from ground up to straight aligned bridge
      final hipY = (groundY - 14) - (cycle * 52);
      final hip = Offset(cx - 10, hipY);

      // Knees bend at foot angle
      final kneeY = hipY - 12;
      final knee = Offset(cx + 35, kneeY);

      // Muscle glow at glutes / lower back during peak elevation
      if (cycle > 0.5) {
        canvas.drawCircle(hip, 18 * cycle, muscleGlowPaint);
      }

      // Head
      canvas.drawCircle(head, 11, jointPaint..color = VColor.text);
      // Torso (Shoulder -> Hip)
      canvas.drawLine(shoulder, hip, bonePaint);
      // Thigh (Hip -> Knee)
      canvas.drawLine(hip, knee, bonePaint);
      // Calf (Knee -> Foot)
      canvas.drawLine(knee, foot, bonePaint);
      // Arm resting on ground
      canvas.drawLine(shoulder, Offset(cx - 20, groundY - 4), bonePaint..strokeWidth = 3);

      // Joints
      canvas.drawCircle(shoulder, 5, jointPaint..color = VColor.accent);
      canvas.drawCircle(hip, 6, jointPaint..color = VColor.accentGreen);
      canvas.drawCircle(knee, 5, jointPaint..color = VColor.accent);
      canvas.drawCircle(foot, 4, jointPaint..color = VColor.accent);
    } else if (exerciseSlug.contains('squat')) {
      // ── SQUAT KINEMATICS ──
      // Standing upright, hips sink back and down, knees flex to 90 deg
      final footL = Offset(cx - 25, groundY - 4);
      final footR = Offset(cx + 25, groundY - 4);

      final squatDepth = cycle * 42; // depth drop
      final hip = Offset(cx - 8, groundY - 60 + squatDepth);
      final kneeL = Offset(cx - 30, groundY - 32 + (squatDepth * 0.4));
      final kneeR = Offset(cx + 20, groundY - 32 + (squatDepth * 0.4));

      final chest = Offset(cx + 2, hip.dy - 38);
      final head = Offset(cx + 4, chest.dy - 18);

      // Muscle glow on quads/glutes at bottom
      if (cycle > 0.5) {
        canvas.drawCircle(kneeL, 16 * cycle, muscleGlowPaint);
        canvas.drawCircle(hip, 16 * cycle, muscleGlowPaint);
      }

      // Head
      canvas.drawCircle(head, 11, jointPaint..color = VColor.text);
      // Spine
      canvas.drawLine(head, chest, bonePaint);
      canvas.drawLine(chest, hip, bonePaint);
      // Thighs
      canvas.drawLine(hip, kneeL, bonePaint);
      canvas.drawLine(hip, kneeR, bonePaint);
      // Shins
      canvas.drawLine(kneeL, footL, bonePaint);
      canvas.drawLine(kneeR, footR, bonePaint);
      // Arms out for balance
      canvas.drawLine(chest, Offset(cx + 34, chest.dy + 4), bonePaint..strokeWidth = 3);

      // Joints
      canvas.drawCircle(hip, 5, jointPaint..color = VColor.accentGreen);
      canvas.drawCircle(kneeL, 5, jointPaint..color = VColor.accent);
      canvas.drawCircle(kneeR, 5, jointPaint..color = VColor.accent);
    } else if (exerciseSlug.contains('pushup') || exerciseSlug.contains('press')) {
      // ── PUSH-UP KINEMATICS ──
      final foot = Offset(cx - 70, groundY - 6);
      final hand = Offset(cx + 40, groundY - 4);

      final drop = cycle * 32;
      final shoulder = Offset(cx + 40, (groundY - 50) + drop);
      final elbow = Offset(cx + 22, (groundY - 35) + (drop * 0.7));
      final hip = Offset(cx - 15, (groundY - 38) + (drop * 0.7));
      final head = Offset(cx + 62, shoulder.dy - 8);

      if (cycle > 0.5) {
        canvas.drawCircle(shoulder, 18 * cycle, muscleGlowPaint);
      }

      // Head
      canvas.drawCircle(head, 10, jointPaint..color = VColor.text);
      // Body plank line (Shoulder -> Hip -> Foot)
      canvas.drawLine(shoulder, hip, bonePaint);
      canvas.drawLine(hip, foot, bonePaint);
      // Arms (Shoulder -> Elbow -> Hand)
      canvas.drawLine(shoulder, elbow, bonePaint..strokeWidth = 4);
      canvas.drawLine(elbow, hand, bonePaint..strokeWidth = 4);

      // Joints
      canvas.drawCircle(shoulder, 5, jointPaint..color = VColor.accentGreen);
      canvas.drawCircle(elbow, 5, jointPaint..color = VColor.accent);
      canvas.drawCircle(hand, 4, jointPaint..color = VColor.accent);
      canvas.drawCircle(hip, 5, jointPaint..color = VColor.accent);
    } else {
      // ── GENERAL MOVEMENT / RHYTHMIC FIGURE ──
      final baseCenter = Offset(cx, groundY - 60);
      final bobY = math.sin(animationProgress * 2 * math.pi) * 8;
      final torsoTop = Offset(cx, baseCenter.dy - 30 + bobY);
      final head = Offset(cx, torsoTop.dy - 16);
      final hip = Offset(cx, baseCenter.dy + 15 + bobY);

      final armSweep = math.sin(animationProgress * 2 * math.pi) * 22;
      final legSweep = math.cos(animationProgress * 2 * math.pi) * 16;

      canvas.drawCircle(head, 12, jointPaint..color = VColor.text);
      canvas.drawLine(torsoTop, hip, bonePaint);

      // Arms
      canvas.drawLine(torsoTop, Offset(cx - 28, torsoTop.dy + 20 + armSweep), bonePaint);
      canvas.drawLine(torsoTop, Offset(cx + 28, torsoTop.dy + 20 - armSweep), bonePaint);

      // Legs
      canvas.drawLine(hip, Offset(cx - 20, groundY - 4 - legSweep.abs()), bonePaint);
      canvas.drawLine(hip, Offset(cx + 20, groundY - 4 - (16 - legSweep.abs())), bonePaint);

      canvas.drawCircle(torsoTop, 5, jointPaint..color = VColor.accentGreen);
      canvas.drawCircle(hip, 5, jointPaint..color = VColor.accent);
    }
  }

  @override
  bool shouldRepaint(covariant _BiomechanicalPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress || oldDelegate.exerciseSlug != exerciseSlug;
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
    super.dispose();
  }

  void _togglePlay() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_isPlaying) {
        _waveCtrl.stop();
        _autoStopTimer?.cancel();
        _isPlaying = false;
      } else {
        _waveCtrl.repeat(reverse: true);
        _isPlaying = true;
        // Auto stop after script duration
        _autoStopTimer?.cancel();
        _autoStopTimer = Timer(const Duration(seconds: 12), () {
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _waveCtrl.stop();
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
                    color: _isPlaying ? VColor.accent : VColor.steel.withOpacity(0.5),
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
              color: VColor.bg.withOpacity(0.5),
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
