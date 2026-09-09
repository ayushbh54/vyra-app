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
    final s = widget.item.slug.toLowerCase().replaceAll('_', '-');
    if (s.contains('shoulder') || s.contains('overhead') || (s.contains('seated') && s.contains('press'))) {
      return 'Shoulders & Triceps';
    }
    if (s.contains('bridge') || s.contains('glute')) return 'Glutes & Hamstrings';
    if (s.contains('wall-sit')) return 'Quadriceps & Glutes';
    if (s.contains('squat') || s.contains('lunge')) return 'Quadriceps & Hamstrings';
    if (s.contains('push-up') || s.contains('pushup') || s.contains('chest')) return 'Chest & Triceps';
    if (s.contains('plank') || s.contains('core') || s.contains('abs')) return 'Core & Abs';
    if (s.contains('bicep') || s.contains('curl')) return 'Biceps';
    if (s.contains('calf') || s.contains('raise')) return 'Calves';
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

    // Normalized slug for exact category matching
    final s = exerciseSlug.toLowerCase().replaceAll('_', '-');

    if (s.contains('bridge') || s.contains('glute')) {
      // ── 1. GLUTE BRIDGE KINEMATICS ──
      // Lying horizontally, feet flat on floor, lifting hips/pelvis up to bridge
      final shoulder = Offset(cx - 60, groundY - 14);
      final head = Offset(cx - 85, groundY - 18);
      final foot = Offset(cx + 60, groundY - 4);

      final hipY = (groundY - 14) - (cycle * 52);
      final hip = Offset(cx - 10, hipY);
      final knee = Offset(cx + 35, hipY - 12);

      if (cycle > 0.4) {
        canvas.drawCircle(hip, 18 * cycle, muscleGlowPaint);
      }

      canvas.drawCircle(head, 11, jointPaint..color = VColor.text);
      canvas.drawLine(shoulder, hip, bonePaint);
      canvas.drawLine(hip, knee, bonePaint);
      canvas.drawLine(knee, foot, bonePaint);
      canvas.drawLine(shoulder, Offset(cx - 20, groundY - 4), bonePaint..strokeWidth = 3);

      canvas.drawCircle(shoulder, 5, jointPaint..color = VColor.accent);
      canvas.drawCircle(hip, 6, jointPaint..color = VColor.accentGreen);
      canvas.drawCircle(knee, 5, jointPaint..color = VColor.accent);
      canvas.drawCircle(foot, 4, jointPaint..color = VColor.accent);
    } else if (s.contains('bicep') || s.contains('curl')) {
      // ── 2. DUMBBELL BICEP CURL KINEMATICS ──
      // Standing upright holding dumbbells, curling from waist to shoulders
      final head = Offset(cx, groundY - 135);
      final chest = Offset(cx, groundY - 110);
      final hip = Offset(cx, groundY - 65);
      final footL = Offset(cx - 18, groundY - 4);
      final footR = Offset(cx + 18, groundY - 4);

      // Legs
      canvas.drawLine(hip, footL, bonePaint);
      canvas.drawLine(hip, footR, bonePaint);
      // Spine
      canvas.drawCircle(head, 12, jointPaint..color = VColor.text);
      canvas.drawLine(head, chest, bonePaint);
      canvas.drawLine(chest, hip, bonePaint..strokeWidth = 6);

      // Arms: Shoulder -> Elbow (fixed at ribs) -> Forearm curling up
      final shoulderL = Offset(chest.dx - 22, chest.dy + 4);
      final shoulderR = Offset(chest.dx + 22, chest.dy + 4);
      final elbowL = Offset(shoulderL.dx - 4, chest.dy + 38);
      final elbowR = Offset(shoulderR.dx + 4, chest.dy + 38);

      // Hand moves along circular arc from bottom (hanging) to top (shoulder height)
      final curlAngle = (1.0 - cycle) * 1.5; // 0 = curled at shoulder, 1.5 rad = hanging down
      final handXL = elbowL.dx - (math.sin(curlAngle) * 28);
      final handYL = elbowL.dy + (math.cos(curlAngle) * 32);
      final handXR = elbowR.dx + (math.sin(curlAngle) * 28);
      final handYR = elbowR.dy + (math.cos(curlAngle) * 32);

      final handL = Offset(handXL, handYL);
      final handR = Offset(handXR, handYR);

      // Biceps muscle glow when curling
      if (cycle > 0.3) {
        canvas.drawCircle(Offset(elbowL.dx - 2, elbowL.dy - 14), 14 * cycle, muscleGlowPaint);
        canvas.drawCircle(Offset(elbowR.dx + 2, elbowR.dy - 14), 14 * cycle, muscleGlowPaint);
      }

      // Draw upper arms
      canvas.drawLine(shoulderL, elbowL, bonePaint..strokeWidth = 5);
      canvas.drawLine(shoulderR, elbowR, bonePaint..strokeWidth = 5);
      // Draw forearms
      canvas.drawLine(elbowL, handL, bonePaint..strokeWidth = 4);
      canvas.drawLine(elbowR, handR, bonePaint..strokeWidth = 4);

      // Draw Dumbbells in hands
      final dumbbellPaint = Paint()
        ..color = VColor.accentCyan
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      // Left dumbbell
      canvas.drawLine(Offset(handL.dx - 9, handL.dy), Offset(handL.dx + 9, handL.dy), dumbbellPaint);
      canvas.drawLine(Offset(handL.dx - 9, handL.dy - 6), Offset(handL.dx - 9, handL.dy + 6), dumbbellPaint..strokeWidth = 5);
      canvas.drawLine(Offset(handL.dx + 9, handL.dy - 6), Offset(handL.dx + 9, handL.dy + 6), dumbbellPaint..strokeWidth = 5);
      // Right dumbbell
      canvas.drawLine(Offset(handR.dx - 9, handR.dy), Offset(handR.dx + 9, handR.dy), dumbbellPaint..strokeWidth = 4);
      canvas.drawLine(Offset(handR.dx - 9, handR.dy - 6), Offset(handR.dx - 9, handR.dy + 6), dumbbellPaint..strokeWidth = 5);
      canvas.drawLine(Offset(handR.dx + 9, handR.dy - 6), Offset(handR.dx + 9, handR.dy + 6), dumbbellPaint..strokeWidth = 5);

      // Joints
      canvas.drawCircle(shoulderL, 5, jointPaint..color = VColor.accent);
      canvas.drawCircle(shoulderR, 5, jointPaint..color = VColor.accent);
      canvas.drawCircle(elbowL, 4, jointPaint..color = VColor.accentGreen);
      canvas.drawCircle(elbowR, 4, jointPaint..color = VColor.accentGreen);
      canvas.drawCircle(handL, 4, jointPaint..color = VColor.accentCyan);
      canvas.drawCircle(handR, 4, jointPaint..color = VColor.accentCyan);
    } else if (s.contains('wall-sit') || (s.contains('wall') && s.contains('sit'))) {
      // ── 3. WALL SIT KINEMATICS (Isometric Hold Against Wall) ──
      final wallX = cx - 35;
      final wallPaint = Paint()
        ..color = VColor.accent.withOpacity(0.4)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.square;
      // Vertical Wall
      canvas.drawLine(Offset(wallX, groundY - 140), Offset(wallX, groundY), wallPaint);

      // Back flat against wall
      final hip = Offset(wallX + 8, groundY - 50);
      final torsoTop = Offset(wallX + 8, groundY - 105);
      final head = Offset(wallX + 8, torsoTop.dy - 16);

      // Thighs horizontal at 90 degrees
      final knee = Offset(wallX + 50, hip.dy);
      // Shins vertical down to feet on floor
      final foot = Offset(knee.dx, groundY - 4);

      // Pulse muscle glow on quadriceps
      final pulse = 0.5 + (0.5 * cycle);
      canvas.drawCircle(Offset((hip.dx + knee.dx) / 2, hip.dy), 16 * pulse, muscleGlowPaint);

      // Head & Torso against wall
      canvas.drawCircle(head, 12, jointPaint..color = VColor.text);
      canvas.drawLine(torsoTop, hip, bonePaint..strokeWidth = 6);
      // Legs (Thigh -> Shin)
      canvas.drawLine(hip, knee, bonePaint..strokeWidth = 6);
      canvas.drawLine(knee, foot, bonePaint..strokeWidth = 5);
      // Arms resting forward on knees
      canvas.drawLine(torsoTop, Offset(knee.dx - 10, knee.dy - 8), bonePaint..strokeWidth = 4);

      canvas.drawCircle(torsoTop, 5, jointPaint..color = VColor.accent);
      canvas.drawCircle(hip, 5, jointPaint..color = VColor.accentGreen);
      canvas.drawCircle(knee, 6, jointPaint..color = VColor.accentGreen);
      canvas.drawCircle(foot, 4, jointPaint..color = VColor.accent);
    } else if (s.contains('wall-push')) {
      // ── 4. WALL PUSH-UP KINEMATICS ──
      final wallX = cx + 55;
      final wallPaint = Paint()
        ..color = VColor.accent.withOpacity(0.4)
        ..strokeWidth = 5;
      canvas.drawLine(Offset(wallX, groundY - 140), Offset(wallX, groundY), wallPaint);

      // Feet anchored on floor
      final foot = Offset(cx - 50, groundY - 4);
      // Body leans into wall as cycle goes 0 -> 1 -> 0
      final lean = cycle * 24;
      final hand = Offset(wallX - 3, groundY - 80);
      final shoulder = Offset(cx + 20 + lean, groundY - 80);
      final elbow = Offset(cx + 8 + (lean * 0.4), groundY - 60);
      final hip = Offset(cx - 15 + (lean * 0.7), groundY - 45);
      final head = Offset(shoulder.dx + 16, shoulder.dy - 12);

      if (cycle > 0.4) {
        canvas.drawCircle(shoulder, 18 * cycle, muscleGlowPaint);
      }

      // Head & Plank
      canvas.drawCircle(head, 11, jointPaint..color = VColor.text);
      canvas.drawLine(shoulder, hip, bonePaint..strokeWidth = 5);
      canvas.drawLine(hip, foot, bonePaint..strokeWidth = 5);
      // Arms (Shoulder -> Elbow -> Hand on wall)
      canvas.drawLine(shoulder, elbow, bonePaint..strokeWidth = 4);
      canvas.drawLine(elbow, hand, bonePaint..strokeWidth = 4);

      canvas.drawCircle(shoulder, 5, jointPaint..color = VColor.accentGreen);
      canvas.drawCircle(elbow, 5, jointPaint..color = VColor.accent);
      canvas.drawCircle(hand, 5, jointPaint..color = VColor.accentCyan);
      canvas.drawCircle(hip, 5, jointPaint..color = VColor.accent);
    } else if (s.contains('calf') || s.contains('raise')) {
      // ── 5. CALF RAISE KINEMATICS ──
      // Standing upright, rising onto balls of feet with ankle extension
      final lift = cycle * 28; // body rises by 28px
      final footX = cx;
      final ankleY = groundY - 8 - lift;
      final knee = Offset(footX, groundY - 55 - lift);
      final hip = Offset(footX, groundY - 95 - lift);
      final torsoTop = Offset(footX, groundY - 135 - lift);
      final head = Offset(footX, torsoTop.dy - 16);

      // Calves glow during lift
      if (cycle > 0.3) {
        canvas.drawCircle(Offset(footX, groundY - 32 - lift), 16 * cycle, muscleGlowPaint);
      }

      // Head & Torso
      canvas.drawCircle(head, 12, jointPaint..color = VColor.text);
      canvas.drawLine(head, torsoTop, bonePaint);
      canvas.drawLine(torsoTop, hip, bonePaint..strokeWidth = 6);
      // Legs
      canvas.drawLine(hip, knee, bonePaint);
      canvas.drawLine(knee, Offset(footX, ankleY), bonePaint);
      // Foot (toes touching ground, heel elevated)
      canvas.drawLine(Offset(footX, ankleY), Offset(footX + 16, groundY - 4), bonePaint..strokeWidth = 4);
      // Arms on hips
      canvas.drawLine(torsoTop, Offset(footX - 18, hip.dy + 8), bonePaint..strokeWidth = 3);
      canvas.drawLine(torsoTop, Offset(footX + 18, hip.dy + 8), bonePaint..strokeWidth = 3);

      canvas.drawCircle(hip, 5, jointPaint..color = VColor.accent);
      canvas.drawCircle(knee, 5, jointPaint..color = VColor.accent);
      canvas.drawCircle(Offset(footX, ankleY), 5, jointPaint..color = VColor.accentGreen);
    } else if (s.contains('knee-push')) {
      // ── 6. KNEE PUSH-UP KINEMATICS ──
      final knee = Offset(cx - 55, groundY - 6);
      final foot = Offset(cx - 78, groundY - 24); // feet curled up off floor
      final hand = Offset(cx + 40, groundY - 4);

      final drop = cycle * 30;
      final shoulder = Offset(cx + 35, (groundY - 48) + drop);
      final elbow = Offset(cx + 18, (groundY - 32) + (drop * 0.7));
      final hip = Offset(cx - 10, (groundY - 32) + (drop * 0.7));
      final head = Offset(cx + 56, shoulder.dy - 8);

      if (cycle > 0.5) {
        canvas.drawCircle(shoulder, 18 * cycle, muscleGlowPaint);
      }

      canvas.drawCircle(head, 10, jointPaint..color = VColor.text);
      canvas.drawLine(shoulder, hip, bonePaint);
      canvas.drawLine(hip, knee, bonePaint);
      canvas.drawLine(knee, foot, bonePaint..strokeWidth = 3); // feet raised
      canvas.drawLine(shoulder, elbow, bonePaint..strokeWidth = 4);
      canvas.drawLine(elbow, hand, bonePaint..strokeWidth = 4);

      canvas.drawCircle(shoulder, 5, jointPaint..color = VColor.accentGreen);
      canvas.drawCircle(elbow, 5, jointPaint..color = VColor.accent);
      canvas.drawCircle(hand, 4, jointPaint..color = VColor.accent);
      canvas.drawCircle(knee, 5, jointPaint..color = VColor.accent);
    } else if (s.contains('push-up') || s.contains('pushup') || s.contains('chest-press')) {
      // ── 7. STANDARD PUSH-UP KINEMATICS ──
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

      canvas.drawCircle(head, 10, jointPaint..color = VColor.text);
      canvas.drawLine(shoulder, hip, bonePaint);
      canvas.drawLine(hip, foot, bonePaint);
      canvas.drawLine(shoulder, elbow, bonePaint..strokeWidth = 4);
      canvas.drawLine(elbow, hand, bonePaint..strokeWidth = 4);

      canvas.drawCircle(shoulder, 5, jointPaint..color = VColor.accentGreen);
      canvas.drawCircle(elbow, 5, jointPaint..color = VColor.accent);
      canvas.drawCircle(hand, 4, jointPaint..color = VColor.accent);
      canvas.drawCircle(hip, 5, jointPaint..color = VColor.accent);
    } else if (s.contains('shoulder') || (s.contains('seated') && s.contains('press')) || s.contains('overhead')) {
      // ── 8. SEATED SHOULDER PRESS KINEMATICS (Upright Chair / Wheelchair) ──
      final chairX = cx - 10;
      final seatY = groundY - 45;
      final chairBackX = chairX - 22;

      final chairPaint = Paint()
        ..color = VColor.accent.withOpacity(0.35)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(chairBackX, seatY - 55), Offset(chairBackX, seatY), chairPaint);
      canvas.drawLine(Offset(chairBackX - 4, seatY), Offset(chairX + 26, seatY), chairPaint);
      canvas.drawLine(Offset(chairBackX, seatY), Offset(chairBackX, groundY), chairPaint..strokeWidth = 3);
      canvas.drawLine(Offset(chairX + 22, seatY), Offset(chairX + 22, groundY), chairPaint..strokeWidth = 3);

      final hip = Offset(chairX - 8, seatY - 6);
      final knee = Offset(chairX + 30, seatY);
      final foot = Offset(chairX + 32, groundY - 4);

      final torsoTop = Offset(chairX - 5, seatY - 58);
      final head = Offset(chairX - 4, torsoTop.dy - 18);
      final shoulderL = Offset(torsoTop.dx - 14, torsoTop.dy + 4);
      final shoulderR = Offset(torsoTop.dx + 14, torsoTop.dy + 4);

      final pressHeight = cycle * 44;
      final handYL = (torsoTop.dy - 8) - pressHeight;
      final handYR = (torsoTop.dy - 8) - pressHeight;
      final handXL = shoulderL.dx - 8 + (cycle * 4);
      final handXR = shoulderR.dx + 8 - (cycle * 4);

      final elbowYL = (torsoTop.dy + 14) - (cycle * 24);
      final elbowYR = (torsoTop.dy + 14) - (cycle * 24);
      final elbowXL = shoulderL.dx - 18 + (cycle * 6);
      final elbowXR = shoulderR.dx + 18 - (cycle * 6);

      final handL = Offset(handXL, handYL);
      final handR = Offset(handXR, handYR);
      final elbowL = Offset(elbowXL, elbowYL);
      final elbowR = Offset(elbowXR, elbowYR);

      if (cycle > 0.4) {
        canvas.drawCircle(shoulderL, 16 * cycle, muscleGlowPaint);
        canvas.drawCircle(shoulderR, 16 * cycle, muscleGlowPaint);
      }

      canvas.drawCircle(head, 12, jointPaint..color = VColor.text);
      canvas.drawLine(head, torsoTop, bonePaint);
      canvas.drawLine(torsoTop, hip, bonePaint..strokeWidth = 6);
      canvas.drawLine(hip, knee, bonePaint);
      canvas.drawLine(knee, foot, bonePaint);

      canvas.drawLine(shoulderL, elbowL, bonePaint..strokeWidth = 4);
      canvas.drawLine(elbowL, handL, bonePaint..strokeWidth = 4);
      canvas.drawLine(shoulderR, elbowR, bonePaint..strokeWidth = 4);
      canvas.drawLine(elbowR, handR, bonePaint..strokeWidth = 4);

      final dumbbellPaint = Paint()
        ..color = VColor.accentCyan
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(handL.dx - 10, handL.dy), Offset(handL.dx + 10, handL.dy), dumbbellPaint);
      canvas.drawLine(Offset(handL.dx - 10, handL.dy - 5), Offset(handL.dx - 10, handL.dy + 5), dumbbellPaint..strokeWidth = 5);
      canvas.drawLine(Offset(handL.dx + 10, handL.dy - 5), Offset(handL.dx + 10, handL.dy + 5), dumbbellPaint..strokeWidth = 5);

      canvas.drawLine(Offset(handR.dx - 10, handR.dy), Offset(handR.dx + 10, handR.dy), dumbbellPaint..strokeWidth = 4);
      canvas.drawLine(Offset(handR.dx - 10, handR.dy - 5), Offset(handR.dx - 10, handR.dy + 5), dumbbellPaint..strokeWidth = 5);
      canvas.drawLine(Offset(handR.dx + 10, handR.dy - 5), Offset(handR.dx + 10, handR.dy + 5), dumbbellPaint..strokeWidth = 5);

      canvas.drawCircle(shoulderL, 5, jointPaint..color = VColor.accentGreen);
      canvas.drawCircle(shoulderR, 5, jointPaint..color = VColor.accentGreen);
      canvas.drawCircle(elbowL, 4, jointPaint..color = VColor.accent);
      canvas.drawCircle(elbowR, 4, jointPaint..color = VColor.accent);
      canvas.drawCircle(handL, 4, jointPaint..color = VColor.accentCyan);
      canvas.drawCircle(handR, 4, jointPaint..color = VColor.accentCyan);
    } else if (s.contains('squat') || s.contains('lunge')) {
      // ── 9. SQUAT KINEMATICS ──
      final footL = Offset(cx - 25, groundY - 4);
      final footR = Offset(cx + 25, groundY - 4);

      final squatDepth = cycle * 42;
      final hip = Offset(cx - 8, groundY - 60 + squatDepth);
      final kneeL = Offset(cx - 30, groundY - 32 + (squatDepth * 0.4));
      final kneeR = Offset(cx + 20, groundY - 32 + (squatDepth * 0.4));

      final chest = Offset(cx + 2, hip.dy - 38);
      final head = Offset(cx + 4, chest.dy - 18);

      if (cycle > 0.5) {
        canvas.drawCircle(kneeL, 16 * cycle, muscleGlowPaint);
        canvas.drawCircle(hip, 16 * cycle, muscleGlowPaint);
      }

      canvas.drawCircle(head, 11, jointPaint..color = VColor.text);
      canvas.drawLine(head, chest, bonePaint);
      canvas.drawLine(chest, hip, bonePaint);
      canvas.drawLine(hip, kneeL, bonePaint);
      canvas.drawLine(hip, kneeR, bonePaint);
      canvas.drawLine(kneeL, footL, bonePaint);
      canvas.drawLine(kneeR, footR, bonePaint);
      canvas.drawLine(chest, Offset(cx + 34, chest.dy + 4), bonePaint..strokeWidth = 3);

      canvas.drawCircle(hip, 5, jointPaint..color = VColor.accentGreen);
      canvas.drawCircle(kneeL, 5, jointPaint..color = VColor.accent);
      canvas.drawCircle(kneeR, 5, jointPaint..color = VColor.accent);
    } else {
      // ── 10. CARDIO / RHYTHMIC FIGURE ──
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
