import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/screen_scaffold.dart';
import 'library.dart';
import 'record.dart';

/// TAB 1 — TRAINING HUB
///
/// The screen a user opens every day, so it answers one question immediately:
/// "what am I doing today, and how much is left?" Everything else sits below.
///
/// The Chrono Engine's reasoning is shown rather than hidden. When today's goal
/// is 12 minutes instead of 30, the app says why. A goal that changes without
/// explanation feels arbitrary; a goal that explains itself feels fair — and
/// fairness is the entire product.
class TrainingHubScreen extends StatefulWidget {
  const TrainingHubScreen({super.key});

  @override
  State<TrainingHubScreen> createState() => _TrainingHubScreenState();
}

class _TrainingHubScreenState extends State<TrainingHubScreen> {
  TodayData? _data;
  String? _error;
  String? _busySlug;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<VyraApi>().today();
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _complete(PlanEntry entry) async {
    setState(() => _busySlug = entry.exerciseSlug);
    try {
      final result = await context
          .read<VyraApi>()
          .completeExercise(entry.exerciseSlug, entry.durationSec);

      if (!mounted) return;

      // Show exactly what the coin engine did, cap included. We never animate a
      // reward that was not actually granted — that is how a number on screen
      // stops being trusted.
      final message = result.coinOutcomes
          .map((o) => o.message)
          .where((m) => m.isNotEmpty)
          .join('\n');

      if (message.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
        );
      }
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busySlug = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _data == null) {
      return _Shell(child: VErrorView(message: _error!, onRetry: _load));
    }
    if (_data == null) {
      return const _Shell(child: VLoading(label: 'Reading your day'));
    }

    final data = _data!;
    final plan = data.plan;
    final capacity = data.capacity;

    return RefreshIndicator(
      onRefresh: _load,
      color: VColor.accent,
      backgroundColor: VColor.surface,
      child: _Shell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context, plan, capacity),
            const SizedBox(height: VSpace.base),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => pushScreen(context, 'Record Activity', const RecordScreen()),
                  icon: const Icon(Icons.fiber_manual_record, size: 16, color: VColor.accent),
                  label: const Text('Record'),
                ),
              ),
              const SizedBox(width: VSpace.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => pushScreen(context, 'Exercise Library', const LibraryScreen()),
                  icon: const Icon(Icons.grid_view_rounded, size: 16, color: VColor.accent),
                  label: const Text('Library'),
                ),
              ),
            ]),
            const SizedBox(height: VSpace.base),
            _goalExplanation(context, capacity),
            const SizedBox(height: VSpace.base),
            if (capacity.isRestDay)
              const VEmptyState(
                title: 'Nothing scheduled today',
                body:
                    'Your calendar has no usable gap, so VYRA is not going to invent one. '
                    'Rest is part of training, not a failure. If your day opens up, edit your '
                    'schedule and we will find the time.',
              )
            else if (plan.entries.isEmpty)
              const VEmptyState(
                title: 'Your plan is being built',
                body:
                    'Add your timetable in Profile and VYRA will find the minutes hiding in your day.',
              )
            else
              ..._session(context, plan),
            const SizedBox(height: VSpace.base),
            if (data.windows.isNotEmpty) ..._windows(context, data),
            const SizedBox(height: VSpace.base),
            _progress(context, data),
            const SizedBox(height: VSpace.base),
            VDisclaimer(data.disclaimer),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _header(BuildContext context, WorkoutPlan plan, Capacity capacity) {
    final allDone = plan.entries.isNotEmpty && plan.completedCount >= plan.entries.length;
    final headerTitle = capacity.isRestDay
        ? 'Rest day'
        : (allDone || plan.remainingMin <= 0)
            ? 'Goal completed! 🎉'
            : '${plan.remainingMin} min to go';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const VLabel('Today'),
              const SizedBox(height: 4),
              Text(
                headerTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
        VRing(
          progress: plan.progress,
          size: 82,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${plan.completedCount}/${plan.entries.length}',
                style: const TextStyle(
                    color: VColor.text, fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const Text('done',
                  style: TextStyle(color: VColor.textLow, fontSize: 10, letterSpacing: 0.8)),
            ],
          ),
        ),
      ],
    );
  }

  /// The engine explaining itself. This is the product's core promise, visible.
  Widget _goalExplanation(BuildContext context, Capacity capacity) {
    return VCard(
      tone: capacity.isRestDay ? CardTone.normal : CardTone.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const VLabel('Your goal today'),
              const Spacer(),
              if (capacity.wasScaledDown) const VPill('Scaled to your day'),
            ],
          ),
          const SizedBox(height: VSpace.sm),
          Text(
            capacity.explanation,
            style: const TextStyle(color: VColor.text, fontSize: 13.5, height: 1.5),
          ),
          const SizedBox(height: VSpace.base),
          Row(
            children: [
              Expanded(
                child: VStat(
                    label: 'Free time found',
                    value: '${capacity.capacityMin}',
                    unit: 'min',
                    tint: VColor.accentGreen),
              ),
              Expanded(
                child: VStat(label: 'Windows', value: '${capacity.windowCount}', tint: VColor.accent),
              ),
              Expanded(
                child: VStat(
                  label: 'Standard goal',
                  value: '${capacity.idealTargetMin}',
                  unit: 'min',
                  tint: VColor.textLow,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _session(BuildContext context, WorkoutPlan plan) {
    final at = plan.entries.first.scheduledAt;
    return [
      VSectionHeader(at == null ? 'Session' : 'Session · $at'),
      ...plan.entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: VSpace.sm),
            child: _ExerciseRow(
              entry: entry,
              busy: _busySlug == entry.exerciseSlug,
              disabled: _busySlug != null,
              onTap: () => _complete(entry),
            ),
          )),
    ];
  }

  List<Widget> _windows(BuildContext context, TodayData data) {
    return [
      const VSectionHeader('Free windows we found'),
      ...data.windows.map((w) => Padding(
            padding: const EdgeInsets.only(bottom: VSpace.sm),
            child: VCard(
              tone: CardTone.raised,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${w.start} – ${w.end}',
                        style: const TextStyle(
                            color: VColor.text, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      VPill(
                        w.qualityLabel,
                        tone: w.suitability >= 0.8
                            ? CardTone.accent
                            : w.suitability >= 0.5
                                ? CardTone.raised
                                : CardTone.warn,
                      ),
                    ],
                  ),
                  const SizedBox(height: VSpace.sm),
                  Text(w.rationale, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          )),
    ];
  }

  Widget _progress(BuildContext context, TodayData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VSectionHeader('Progress'),
        VCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const VLabel('Effort today'),
                    Text(
                      '${data.effort.percent}%',
                      style: const TextStyle(
                          color: VColor.accentGreen, fontSize: 34, fontWeight: FontWeight.w700),
                    ),
                    const Text('of your own goal',
                        style: TextStyle(color: VColor.textLow, fontSize: 11)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VLabel('Level ${data.coins.level}'),
                    Text(
                      '${data.coins.balance}',
                      style: const TextStyle(
                          color: VColor.text, fontSize: 34, fontWeight: FontWeight.w700),
                    ),
                    const Text('coins earned',
                        style: TextStyle(color: VColor.textLow, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.entry,
    required this.busy,
    required this.disabled,
    required this.onTap,
  });

  final PlanEntry entry;
  final bool busy;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = entry.isCompleted;

    return Semantics(
      button: true,
      checked: done,
      label: '${entry.name}, ${entry.durationMin} minutes',
      child: InkWell(
        onTap: done || disabled ? null : onTap,
        borderRadius: BorderRadius.circular(VRadius.md),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(VSpace.base),
          decoration: BoxDecoration(
            color: done ? VColor.bgLift : VColor.surface,
            border: Border.all(color: done ? VColor.lineSoft : VColor.line),
            borderRadius: BorderRadius.circular(VRadius.md),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? VColor.accentGreen : Colors.transparent,
                  border: Border.all(color: done ? VColor.accentGreen : VColor.textLow, width: 1.5),
                ),
                child: done
                    ? const Icon(Icons.check, size: 16, color: VColor.textOnAccent)
                    : null,
              ),
              const SizedBox(width: VSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: TextStyle(
                        color: done ? VColor.textLow : VColor.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.durationMin} min'
                      '${entry.scheduledAt != null ? " · ${entry.scheduledAt}" : ""}',
                      style: const TextStyle(color: VColor.textLow, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: VColor.accent),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.base, VSpace.base, VSpace.xxxl),
          children: [child],
        ),
      );
}
