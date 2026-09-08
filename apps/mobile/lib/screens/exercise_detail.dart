import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// EXERCISE DETAIL — instructions, a spoken-cue script, a countdown timer,
/// and the same "mark complete" flow the Training Hub uses (so a workout
/// item and this stand-alone library view stay perfectly consistent about
/// what counts as done).
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
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSec <= 1) {
        t.cancel();
        setState(() { _remainingSec = 0; _running = false; });
        return;
      }
      setState(() => _remainingSec--);
    });
  }

  void _resetTimer() {
    _ticker?.cancel();
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
            widget.item.slug, actual > 0 ? actual : widget.item.defaultDurationSec,
          );
      if (!mounted) return;
      final message = result.coinOutcomes.map((o) => o.message).where((m) => m.isNotEmpty).join('\n');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message.isEmpty ? 'Nice work — logged.' : message)),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.base, VSpace.base, VSpace.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: VSpace.xs, runSpacing: VSpace.xs, children: [
            VPill(item.subcategory),
            VPill(item.difficulty),
            if (item.isSeatedFriendly) const VPill('Seated-friendly'),
            if (_movement != null) VPill('3D coaching', tone: CardTone.accent),
          ]),
          const SizedBox(height: VSpace.lg),

          // Timer
          Center(
            child: Column(
              children: [
                Text(_timeLabel, style: const TextStyle(
                    color: VColor.text, fontSize: 56, fontWeight: FontWeight.w800)),
                const SizedBox(height: VSpace.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _resetTimer,
                      icon: const Icon(Icons.replay, color: VColor.textMid),
                    ),
                    const SizedBox(width: VSpace.base),
                    GestureDetector(
                      onTap: _toggleTimer,
                      child: Container(
                        width: 64, height: 64,
                        decoration: const BoxDecoration(color: VColor.accent, shape: BoxShape.circle),
                        child: Icon(_running ? Icons.pause : Icons.play_arrow,
                            color: VColor.textOnAccent, size: 32),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: VSpace.xl),

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
                                style: const TextStyle(color: VColor.accentGreen, fontSize: 12, fontWeight: FontWeight.w600)),
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
                            width: 20, height: 20,
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
                                        style: const TextStyle(fontWeight: FontWeight.w600, color: VColor.text, fontSize: 13)),
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
                            Expanded(child: Text(mech, style: const TextStyle(color: VColor.textMid, fontSize: 11))),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: VSpace.base),
          ],

          const VLabel('Coach cues'),
          const SizedBox(height: VSpace.sm),
          for (final step in item.instructions) Padding(
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

          if (item.audioScript.isNotEmpty) ...[
            const VLabel('Spoken cue'),
            const SizedBox(height: VSpace.sm),
            VCard(
              tone: CardTone.raised,
              child: Row(children: [
                const Icon(Icons.volume_up_outlined, color: VColor.textMid, size: 18),
                const SizedBox(width: VSpace.sm),
                Expanded(child: Text(item.audioScript,
                    style: const TextStyle(color: VColor.textMid, fontSize: 13, fontStyle: FontStyle.italic))),
              ]),
            ),
            const SizedBox(height: VSpace.base),
          ],

          if (item.contraindications.isNotEmpty)
            VDisclaimer('Skip or modify if you have: ${item.contraindications.join(", ")}. '
                'This is general guidance, not medical advice.'),

          const SizedBox(height: VSpace.xl),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _completing ? null : _markComplete,
              style: FilledButton.styleFrom(
                backgroundColor: VColor.accent,
                foregroundColor: VColor.textOnAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.pill)),
              ),
              child: _completing
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: VColor.textOnAccent))
                  : const Text('Mark complete', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
