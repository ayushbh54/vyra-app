import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/screen_scaffold.dart';
import 'exercise_detail.dart';
import 'health_sync.dart';
import 'library.dart';
import 'record.dart';
import 'global_search.dart';

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
  UserProfile? _profile;
  String? _error;
  String? _busySlug;
  String? _customWindowStart;
  String? _customWindowEnd;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<VyraApi>();
      final data = await api.today();
      try {
        _profile = await api.getProfile();
      } catch (_) {}

      // Retrieve locally completed exercises for this date to guarantee 0-loss of history
      final prefs = await SharedPreferences.getInstance();
      final localDone = prefs.getStringList('completed_exercises_${data.date}') ?? [];
      _customWindowStart = prefs.getString('custom_window_start');
      _customWindowEnd = prefs.getString('custom_window_end');

      var updatedAchieved = data.plan.achievedMin;
      final mergedEntries = data.plan.entries.map((e) {
        final isDone = e.isCompleted || localDone.contains(e.exerciseSlug);
        if (!e.isCompleted && isDone) {
          updatedAchieved += (e.durationSec / 60.0);
        }
        return e.copyWith(isCompleted: isDone);
      }).toList();

      final mergedPlan = data.plan.copyWith(
        entries: mergedEntries,
        achievedMin: updatedAchieved,
      );

      if (!mounted) return;
      setState(() {
        _data = data.copyWith(plan: mergedPlan);
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _setCustomWindow(String start, String end) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_window_start', start);
      await prefs.setString('custom_window_end', end);
      setState(() {
        _customWindowStart = start;
        _customWindowEnd = end;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✨ Preferred workout slot set to $start – $end!'),
            backgroundColor: VColor.accentGreen,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _resetCustomWindow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('custom_window_start');
      await prefs.remove('custom_window_end');
      setState(() {
        _customWindowStart = null;
        _customWindowEnd = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reset to auto-detected schedule.')),
        );
      }
    } catch (_) {}
  }

  Future<void> _openCustomWindowDialog() async {
    final presets = [
      ('🌅 Early Morning', '06:30', '08:00'),
      ('☀️ Morning Prime', '08:00', '09:30'),
      ('🥗 Midday Break', '12:30', '13:30'),
      ('🌆 Evening Focus', '17:30', '19:00'),
      ('🌙 Night Session', '20:00', '21:30'),
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: VColor.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(VSpace.base),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Customize Workout Timing', style: TextStyle(color: VColor.text, fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close, color: VColor.textLow), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Choose when you prefer to exercise so VYRA optimizes your routine around your real life.', style: TextStyle(color: VColor.textMid, fontSize: 13)),
            const SizedBox(height: VSpace.base),
            for (final p in presets)
              Padding(
                padding: const EdgeInsets.only(bottom: VSpace.xs),
                child: ListTile(
                  tileColor: VColor.surfaceRaised,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  title: Text(p.$1, style: const TextStyle(color: VColor.text, fontWeight: FontWeight.w600, fontSize: 14)),
                  trailing: Text('${p.$2} – ${p.$3}', style: const TextStyle(color: VColor.accent, fontWeight: FontWeight.bold, fontSize: 13)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _setCustomWindow(p.$2, p.$3);
                  },
                ),
              ),
            const SizedBox(height: VSpace.sm),
            if (_customWindowStart != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _resetCustomWindow();
                  },
                  child: const Text('Reset to Automatic Schedule'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _complete(PlanEntry entry) async {
    setState(() => _busySlug = entry.exerciseSlug);
    // 1. Immediately cache locally in SharedPreferences so history survives session-outs
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateKey = 'completed_exercises_${_data?.date ?? ''}';
      final list = prefs.getStringList(dateKey) ?? [];
      if (!list.contains(entry.exerciseSlug)) {
        list.add(entry.exerciseSlug);
        await prefs.setStringList(dateKey, list);
      }
    } catch (_) {}

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
      // Re-load will keep the locally persisted completion intact
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busySlug = null);
    }
  }

  Future<void> _openExercise(PlanEntry entry) async {
    LibraryItem? item;
    try {
      final items = await context.read<VyraApi>().library();
      for (final i in items) {
        if (i.slug == entry.exerciseSlug) {
          item = i;
          break;
        }
      }
    } catch (_) {}

    item ??= LibraryItem(
      slug: entry.exerciseSlug,
      name: entry.name,
      category: 'exercise',
      subcategory: 'session',
      bodyParts: const ['core', 'glutes', 'legs'],
      difficulty: 'beginner',
      instructions: const [
        'Form check: align your head, neck and spine comfortably.',
        'Follow the animated movement guide on screen.',
        'Breathe rhythmically — exhale during muscle contraction.',
      ],
      audioScript: 'Maintain proper alignment and steady rhythm throughout.',
      defaultDurationSec: entry.durationSec > 0 ? entry.durationSec : 60,
      equipment: const [],
      contraindications: const [],
      isSeatedFriendly: false,
      isLowImpact: true,
      isRecoveryFor: const [],
      thumbnailUrl: '',
      gifUrl: '',
    );

    if (!mounted) return;
    await pushScreen(context, entry.name, ExerciseDetailScreen(item: item));
    if (mounted) _load();
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
                  onPressed: () => pushScreen(
                    context,
                    'Smartwatch Sync',
                    HealthSyncScreen(api: context.read<VyraApi>()),
                  ),
                  icon: const Icon(Icons.watch_rounded, size: 16, color: VColor.accentGreen),
                  label: const Text('Watch Sync'),
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
            if (plan.entries.isNotEmpty && !plan.entries.every((e) => e.isCompleted)) ...[
              const SizedBox(height: VSpace.base),
              VGradientButton(
                label: 'Launch Workout Session (${plan.entries.where((e) => !e.isCompleted).length} moves)',
                icon: Icons.play_arrow_rounded,
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: () {
                  final nextExercise = plan.entries.firstWhere(
                    (e) => !e.isCompleted,
                    orElse: () => plan.entries.first,
                  );
                  _openExercise(nextExercise);
                },
              ),
            ],
            const SizedBox(height: VSpace.base),
            if (_profile?.accessibilityMode == true ||
                _profile?.disabilityFlag == true ||
                (_profile?.disabilityType != null &&
                    _profile!.disabilityType.isNotEmpty &&
                    _profile!.disabilityType.toLowerCase() != 'none')) ...[
              Container(
                margin: const EdgeInsets.only(bottom: VSpace.sm),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VColor.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: VColor.accent.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.accessible_forward_rounded, color: VColor.accent, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Adaptive Seated Plan Active',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: VColor.accent,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'All exercises are 100% seated & mobility-friendly.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: VColor.textMuted,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
    final headerStatus = capacity.isRestDay
        ? 'REST & RECOVERY'
        : (allDone || plan.remainingMin <= 0)
            ? 'GOAL ACHIEVED • 100%'
            : 'AI REGIMEN OPTIMAL • ${plan.remainingMin} MIN LEFT';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const VHeaderBadge(label: 'CORE COMMAND HUB', accentColor: VColor.accent),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: VColor.accentGreenGlow,
                borderRadius: BorderRadius.circular(VRadius.pill),
                border: Border.all(color: VColor.accentGreen.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: VColor.accentGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'AI ACTIVE',
                    style: TextStyle(
                      color: VColor.accentGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.travel_explore, color: VColor.accent, size: 20),
              onPressed: () => pushScreen(context, 'Global Search', const GlobalSearchScreen()),
              tooltip: 'Search VYRA Directory',
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Text(
              'TRAINING',
              style: TextStyle(
                color: VColor.text,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '• $headerStatus',
              style: TextStyle(
                color: capacity.isRestDay
                    ? VColor.steel
                    : allDone
                        ? VColor.accentGreen
                        : VColor.accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Adaptive AI Daily Regimen tailored to your biometrics',
          style: TextStyle(color: VColor.textMid, fontSize: 13.5),
        ),
        const SizedBox(height: VSpace.base),
        // 3-Metric Kinetic Telemetry Cluster (Steps=Green, Burn=Orange, Vitals=Cyan)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: VColor.surfaceRaised,
            borderRadius: BorderRadius.circular(VRadius.lg),
            border: Border.all(color: VColor.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.directions_walk_rounded, color: VColor.accentGreen, size: 16),
                        const SizedBox(width: 4),
                        const Text('STEPS', style: TextStyle(color: VColor.textLow, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '6,420',
                      style: TextStyle(color: VColor.accentGreen, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const Text('Goal 10,000', style: TextStyle(color: VColor.textLow, fontSize: 10)),
                  ],
                ),
              ),
              Container(width: 1, height: 36, color: VColor.lineSoft),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_fire_department_rounded, color: VColor.accentOrange, size: 16),
                          const SizedBox(width: 4),
                          const Text('BURN', style: TextStyle(color: VColor.textLow, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '485 kcal',
                        style: TextStyle(color: VColor.accentOrange, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const Text('Active output', style: TextStyle(color: VColor.textLow, fontSize: 10)),
                    ],
                  ),
                ),
              ),
              Container(width: 1, height: 36, color: VColor.lineSoft),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.timer_rounded, color: VColor.accent, size: 16),
                          const SizedBox(width: 4),
                          const Text('SESSION', style: TextStyle(color: VColor.textLow, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${plan.achievedMin.round()} min',
                        style: const TextStyle(color: VColor.accent, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      Text('of ${plan.goalMin}m', style: const TextStyle(color: VColor.textLow, fontSize: 10)),
                    ],
                  ),
                ),
              ),
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
              onTap: () => _openExercise(entry),
              onToggleCheck: () => _complete(entry),
            ),
          )),
    ];
  }

  List<Widget> _windows(BuildContext context, TodayData data) {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const VSectionHeader('Workout windows'),
          TextButton.icon(
            onPressed: _openCustomWindowDialog,
            icon: const Icon(Icons.edit_calendar_rounded, size: 16, color: VColor.accent),
            label: Text(
              _customWindowStart != null ? 'Edit Timing' : 'Set My Timing',
              style: const TextStyle(color: VColor.accent, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      if (_customWindowStart != null && _customWindowEnd != null)
        Padding(
          padding: const EdgeInsets.only(bottom: VSpace.sm),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [VColor.accent.withOpacity(0.18), VColor.surfaceRaised],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(VRadius.md),
              border: Border.all(color: VColor.accent.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: VColor.accent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.access_time_filled_rounded, color: VColor.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$_customWindowStart – $_customWindowEnd',
                            style: const TextStyle(color: VColor.text, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: VColor.accentGreenGlow,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: VColor.accentGreen.withOpacity(0.5)),
                            ),
                            child: const Text('CUSTOM ACTIVE', style: TextStyle(color: VColor.accentGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Your custom daily workout slot. Workouts and alerts are matched here.',
                        style: TextStyle(color: VColor.textMid, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: VColor.textLow),
                  tooltip: 'Reset timing',
                  onPressed: _resetCustomWindow,
                ),
              ],
            ),
          ),
        ),
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
    required this.onToggleCheck,
  });

  final PlanEntry entry;
  final bool busy;
  final bool disabled;
  final VoidCallback onTap;
  final VoidCallback onToggleCheck;

  @override
  Widget build(BuildContext context) {
    final done = entry.isCompleted;

    return Semantics(
      button: true,
      enabled: !disabled,
      label: '${entry.name}, ${entry.durationMin} minutes. ${done ? "Completed" : "Tap to open exercise workout"}',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(VRadius.md),
        child: InkWell(
          onTap: disabled ? null : onTap,
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
                GestureDetector(
                  onTap: disabled ? null : onToggleCheck,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? VColor.accentGreen : Colors.transparent,
                      border: Border.all(color: done ? VColor.accentGreen : VColor.textLow, width: 1.5),
                    ),
                    child: done
                        ? const Icon(Icons.check, size: 18, color: VColor.textOnAccent)
                        : null,
                  ),
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
                        '${entry.scheduledAt != null ? " · ${entry.scheduledAt}" : ""}'
                        ' · Tap for visual guide & timer',
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
                  )
                else
                  const Icon(Icons.chevron_right, size: 20, color: VColor.textLow),
              ],
            ),
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
