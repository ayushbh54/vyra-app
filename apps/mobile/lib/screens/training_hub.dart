import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../services/language_service.dart';
import '../theme.dart';
import '../theme_manager.dart';
import '../widgets/common.dart';
import '../widgets/daily_slogan_banner.dart';
import '../widgets/notifications_sheet.dart';
import '../widgets/screen_scaffold.dart';
import 'barcode_scan.dart';
import 'blood_donation.dart';
import 'challenges_hub.dart';
import 'exercise_detail.dart';
import 'face_hair_yoga.dart';
import 'food_scan.dart';
import 'health_report_ai.dart';
import 'health_sync.dart';
import 'library.dart';
import 'messages_inbox.dart';
import 'nearby_doctors.dart';
import 'pose_tracker.dart';
import 'record.dart';
import 'water_reminder.dart';

/// TAB 1 — TRAINING HUB
///
/// Redesigned with the clean, airy, modern, soft layout matching the reference UI:
/// - Top Bar:
///   - Left: 3-horizontal bars menu button opening the Side Drawer
///   - User greeting: Blue squircle avatar "AB", "Good morning, AYUSH ⌄", athlete tier badge pill
///   - Right: Notification Bell button with unread orange dot (opens Notifications sheet)
///   - Permanent Instagram-style Message (DM) button with unread badge (opens Messages Inbox)
/// - 3-Column Metric Highlights Card (87% Goal Pace | 2,450 Activity Pts | 18 Days Streak)
/// - Today's Routine Hero & Up-Next cards (time chip, coach, 1-tap start)
/// - Services Quick Access Grid (8 soft pastel rounded squircle icons)
/// - Recent Activity Log Cards
/// - Chrono AI Engine schedule windows & adaptive accessibility support
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

      // Show motivational slogan banner
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final lang = LanguageService.instance.locale.languageCode;
        DailySloganBanner.show(
          context: context,
          sloganContext: 'home',
          streakDays: 7,
          language: lang == 'hi' ? 'hi' : 'en',
        );
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
            backgroundColor: const Color(0xFF10B981),
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
    final isDark = ThemeManager.instance.isDark;
    final presets = [
      ('🌅 Early Morning', '06:30', '08:00'),
      ('☀️ Morning Prime', '08:30', '09:15'),
      ('🥗 Midday Break', '12:30', '13:30'),
      ('🌆 Evening Focus', '17:30', '19:00'),
      ('🌙 Night Session', '20:00', '21:30'),
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF171C25) : Colors.white,
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
                Text(
                  'Customize Workout Timing',
                  style: TextStyle(
                    color: isDark ? const Color(0xFFDFE2F0) : const Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: isDark ? const Color(0xFF859399) : const Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Choose when you prefer to exercise so VYRA optimizes your routine around your schedule.',
              style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: VSpace.base),
            for (final p in presets)
              Padding(
                padding: const EdgeInsets.only(bottom: VSpace.xs),
                child: ListTile(
                  tileColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  title: Text(p.$1, style: TextStyle(color: isDark ? const Color(0xFFDFE2F0) : const Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 14)),
                  trailing: Text('${p.$2} – ${p.$3}', style: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold, fontSize: 13)),
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

  void _showPersonaSwitcher(BuildContext context) {
    final isDark = ThemeManager.instance.isDark;
    final bg = isDark ? const Color(0xFF171C25) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFDFE2F0) : const Color(0xFF0F172A);

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.bolt_rounded, color: Color(0xFF0284C7), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chrono Engine Live Simulation',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            'Watch goals & workouts adapt live to real daily schedules:',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _personaOptionTile(ctx, 'student', 'Ayush Bhadoria (Student)', 'School, coaching · 17 usable minutes', Icons.school_rounded),
                _personaOptionTile(ctx, 'nurse', 'Hospital Nurse', '12-hr shift · Scaled-down 15 min mobility recovery', Icons.medical_services_rounded),
                _personaOptionTile(ctx, 'homemaker', 'Active Homemaker', 'Split day · 20 min daytime frequency', Icons.home_rounded),
                _personaOptionTile(ctx, 'open', 'Remote Worker', 'Open calendar · 45 min peak metabolic burn', Icons.laptop_chromebook_rounded),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _personaOptionTile(BuildContext ctx, String id, String title, String subtitle, IconData icon) {
    final isDark = ThemeManager.instance.isDark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF0284C7).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF0284C7)),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            color: isDark ? const Color(0xFFDFE2F0) : const Color(0xFF0F172A),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11.5,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_rounded, size: 18, color: Color(0xFF0284C7)),
        onTap: () async {
          Navigator.pop(ctx);
          try {
            await context.read<VyraApi>().startDemoSession(id);
            if (mounted) {
              await _load();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✨ Switched to $title! Goal & routine adapted.'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              }
            }
          } catch (_) {}
        },
      ),
    );
  }

  Future<void> _complete(PlanEntry entry) async {
    setState(() => _busySlug = entry.exerciseSlug);
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateKey = 'completed_exercises_${_data?.date ?? ''}';
      final list = prefs.getStringList(dateKey) ?? [];
      if (!list.contains(entry.exerciseSlug)) {
        list.add(entry.exerciseSlug);
        await prefs.setStringList(dateKey, list);
      }
    } catch (_) {}

    if (!mounted) return;
    try {
      final result = await context
          .read<VyraApi>()
          .completeExercise(entry.exerciseSlug, entry.durationSec);

      if (!mounted) return;
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
      await _load();
      if (!mounted) return;
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
    final isDark = ThemeManager.instance.isDark;
    final pageBg = isDark ? const Color(0xFF0F131D) : const Color(0xFFF4F7FB);

    if (_error != null && _data == null) {
      return Container(
        color: pageBg,
        child: SafeArea(
          child: Center(child: VErrorView(message: _error!, onRetry: _load)),
        ),
      );
    }
    if (_data == null) {
      return Container(
        color: pageBg,
        child: const SafeArea(
          child: Center(child: VLoading(label: 'Reading your day')),
        ),
      );
    }

    final data = _data!;
    final plan = data.plan;

    return Container(
      color: pageBg,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: const Color(0xFF0284C7),
          backgroundColor: isDark ? const Color(0xFF171C25) : Colors.white,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // 1. Top Header Bar matching Screenshot 1
              _buildTopHeaderBar(context),
              const SizedBox(height: 16),

              // 2. 3-Column Metric Highlights Card
              _build3ColumnMetricCard(context, plan),
              const SizedBox(height: 20),

              // 3. Today's Routine Section with Hero & Up-Next Cards
              _buildTodaysRoutineSection(context, data),
              const SizedBox(height: 24),

              // 4. Services Quick Access Grid (8 soft squircle pastel icons)
              _buildServicesGrid(context),
              const SizedBox(height: 24),

              // 5. Adaptive Accessibility Notice (if active)
              if (_profile?.accessibilityMode == true ||
                  _profile?.disabilityFlag == true ||
                  (_profile?.disabilityType != null &&
                      _profile!.disabilityType.isNotEmpty &&
                      _profile!.disabilityType.toLowerCase() != 'none'))
                _buildAdaptiveNotice(context),

              // 6. Detailed Exercise Schedule List
              if (plan.entries.isNotEmpty) ...[
                _buildScheduleList(context, plan),
                const SizedBox(height: 20),
              ],

              // 7. Recent Activity Section
              _buildRecentActivitySection(context),
              const SizedBox(height: 20),

              // 8. Chrono AI Schedule Window Info
              _buildChronoWindowBanner(context, data),
              const SizedBox(height: 16),

              // 9. Medical & Safety Disclaimer
              VDisclaimer(data.disclaimer),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. TOP HEADER BAR
  // ---------------------------------------------------------------------------
  Widget _buildTopHeaderBar(BuildContext context) {
    final isDark = ThemeManager.instance.isDark;
    final textPrimary = isDark ? const Color(0xFFDFE2F0) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF171C25) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final athleteName = _profile?.name.isNotEmpty == true ? _profile!.name : 'AYUSH';
    final firstName = athleteName.split(' ').first.toUpperCase();
    final initials = athleteName.split(' ').where((s) => s.isNotEmpty).map((s) => s[0]).take(2).join();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 3-horizontal bars menu icon button (Hamburger)
        Builder(
          builder: (bCtx) => InkWell(
            onTap: () => Scaffold.of(bCtx).openDrawer(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 42,
              height: 42,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.menu_rounded,
                color: textPrimary,
                size: 22,
              ),
            ),
          ),
        ),

        // Squircle Avatar "AB" matching Screenshot 1
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF0284C7), const Color(0xFF00D2FF)]
                  : [const Color(0xFF1E40AF), const Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E40AF).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              initials.isNotEmpty ? initials : 'AB',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Greeting & Name & Status Dropdown
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Good morning,',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              InkWell(
                onTap: () => _showPersonaSwitcher(context),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      firstName,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: textSecondary,
                      size: 19,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              // Pill badge matching screenshot chip style (taps to switch Chrono persona live)
              InkWell(
                onTap: () => _showPersonaSwitcher(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded, size: 12, color: Color(0xFF0284C7)),
                      const SizedBox(width: 3),
                      Text(
                        'Endurance Athlete • Level 4',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 13, color: textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Right side: Bell icon button + Instagram-style Message DM button
        // 1. Notification Bell
        InkWell(
          onTap: () => NotificationsSheet.show(context),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF171C25) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.notifications_none_rounded,
                  color: textPrimary,
                  size: 21,
                ),
                // Orange notification dot
                Positioned(
                  top: 9,
                  right: 9,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF97316),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // 2. Instagram-style Direct Message (DM) button
        InkWell(
          onTap: () => pushScreen(context, 'Direct Messages', const MessagesInboxScreen()),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF171C25) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.near_me_outlined,
                  color: textPrimary,
                  size: 20,
                ),
                // Cyan unread badge with count
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '3',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2. 3-COLUMN METRIC HIGHLIGHTS CARD
  // ---------------------------------------------------------------------------
  Widget _build3ColumnMetricCard(BuildContext context, WorkoutPlan plan) {
    final isDark = ThemeManager.instance.isDark;
    final cardBg = isDark ? const Color(0xFF171C25) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final dividerColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final labelColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final pacePercent = plan.goalMin > 0
        ? ((plan.achievedMin / plan.goalMin) * 100).clamp(0, 100).round()
        : 87;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.035),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Column 1: Goal Pace
            Expanded(
              child: Column(
                children: [
                  Text(
                    '$pacePercent%',
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0284C7), // Blue
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Goal Pace',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                ],
              ),
            ),
            VerticalDivider(color: dividerColor, thickness: 1, indent: 4, endIndent: 4),
            // Column 2: Activity Pts
            Expanded(
              child: Column(
                children: [
                  const Text(
                    '2,450',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFD97706), // Amber
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Activity Pts',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                ],
              ),
            ),
            VerticalDivider(color: dividerColor, thickness: 1, indent: 4, endIndent: 4),
            // Column 3: Streak
            Expanded(
              child: Column(
                children: [
                  const Text(
                    '18 Days',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF059669), // Green
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Streak',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. TODAY'S ROUTINE SECTION (Hero Card + Up Next Micro Cards)
  // ---------------------------------------------------------------------------
  Widget _buildTodaysRoutineSection(BuildContext context, TodayData data) {
    final isDark = ThemeManager.instance.isDark;
    final textPrimary = isDark ? const Color(0xFFDFE2F0) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final plan = data.plan;
    final nextExercise = plan.entries.firstWhere(
      (e) => !e.isCompleted,
      orElse: () => plan.entries.isNotEmpty
          ? plan.entries.first
          : const PlanEntry(
              exerciseSlug: 'core-activation',
              name: 'CORE & METABOLIC ACTIVATION',
              durationSec: 1800,
              isCompleted: false,
              scheduledAt: '08:30 AM',
            ),
    );

    final windowStr = _customWindowStart != null
        ? '$_customWindowStart – $_customWindowEnd'
        : (data.windows.isNotEmpty ? '${data.windows.first.start} – ${data.windows.first.end}' : '08:30 AM – 09:15 AM');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Today's Routine",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            InkWell(
              onTap: () => pushScreen(context, 'Exercise Library', const LibraryScreen()),
              child: const Row(
                children: [
                  Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF0284C7)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Big Hero Card matching Screenshot 1 style
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E293B), const Color(0xFF172033)]
                  : [const Color(0xFFE0F2FE), const Color(0xFFF0FDF4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFBAE6FD),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Timing pill badge + customize icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.3)
                          : const Color(0xFF0F172A).withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_filled_rounded, size: 13, color: Color(0xFF0284C7)),
                        const SizedBox(width: 5),
                        Text(
                          windowStr,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: _openCustomWindowDialog,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.edit_calendar_rounded, size: 16, color: textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Title
              Text(
                nextExercise.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),

              // Coach and metadata row
              Row(
                children: [
                  Icon(Icons.person_outline_rounded, size: 16, color: textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Coach Alex Vance',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.info_outline_rounded, size: 15, color: textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${nextExercise.durationMin} min · 420 kcal',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Start button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => _openExercise(nextExercise),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text(
                    'Start Workout',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Up Next & Then Micro Cards Row matching Screenshot 1
        Row(
          children: [
            Expanded(
              child: _buildUpNextMicroCard(
                tag: 'UP NEXT · 09:15 AM',
                title: 'HIIT & Cardio Surge',
                subtitle: '⏱ 30 min · High Burn',
                cardBorder: cardBorder,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildUpNextMicroCard(
                tag: 'THEN · 05:30 PM',
                title: 'Mobility & Flow',
                subtitle: '🧘 20 min · Recovery',
                cardBorder: cardBorder,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUpNextMicroCard({
    required String tag,
    required String title,
    required String subtitle,
    required Color cardBorder,
    required bool isDark,
  }) {
    final cardBg = isDark ? const Color(0xFF171C25) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFDFE2F0) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tag,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFFD97706), // Amber
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. SERVICES QUICK ACCESS GRID (8 Pastel Squircle Icons)
  // ---------------------------------------------------------------------------
  Widget _buildServicesGrid(BuildContext context) {
    final isDark = ThemeManager.instance.isDark;
    final textPrimary = isDark ? const Color(0xFFDFE2F0) : const Color(0xFF0F172A);

    final services = [
      (
        'Pose Tracker',
        Icons.camera_enhance_rounded,
        const Color(0xFFCFFAFE), // Cyan bg
        const Color(0xFF0891B2), // Cyan icon
        () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PoseTrackerScreen()),
            ),
      ),
      (
        'Blood Bank',
        Icons.bloodtype_rounded,
        const Color(0xFFFFE4E6), // Rose bg
        const Color(0xFFDC2626), // Red icon
        () => pushScreen(context, 'e-RaktKosh Blood Lifeline', const BloodDonationScreen()),
      ),
      (
        'Lab Report AI',
        Icons.biotech_rounded,
        const Color(0xFFD1FAE5), // Mint bg
        const Color(0xFF059669), // Emerald icon
        () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HealthReportAiScreen()),
            ),
      ),
      (
        'Top Doctors',
        Icons.local_hospital_rounded,
        const Color(0xFFFEF3C7), // Amber bg
        const Color(0xFFD97706), // Amber icon
        () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NearbyDoctorsScreen()),
            ),
      ),
      (
        'Record Activity',
        Icons.radio_button_checked_rounded,
        const Color(0xFFFEF3C7), // Amber bg
        const Color(0xFFD97706), // Amber icon
        () => pushScreen(context, 'Record Activity', const RecordScreen()),
      ),
      (
        'AI Food Scan',
        Icons.document_scanner_rounded,
        const Color(0xFFD1FAE5), // Mint bg
        const Color(0xFF059669), // Emerald icon
        () => pushScreen(context, 'AI Food Scan', const FoodScanScreen()),
      ),
      (
        'Hydration',
        Icons.water_drop_rounded,
        const Color(0xFFE0F2FE), // Sky bg
        const Color(0xFF0284C7), // Sky icon
        () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WaterReminderScreen()),
            ),
      ),
      (
        'Library',
        Icons.fitness_center_rounded,
        const Color(0xFFEDE9FE), // Lavender bg
        const Color(0xFF7C3AED), // Purple icon
        () => pushScreen(context, 'Exercise Library', const LibraryScreen()),
      ),
      (
        'Smartwatch',
        Icons.watch_rounded,
        const Color(0xFFFFE4E6), // Rose bg
        const Color(0xFFE11D48), // Rose icon
        () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => HealthSyncScreen(api: context.read<VyraApi>())),
            ),
      ),
      (
        'Challenges',
        Icons.emoji_events_rounded,
        const Color(0xFFE0E7FF), // Indigo bg
        const Color(0xFF4F46E5), // Indigo icon
        () => pushScreen(context, 'Challenges Hub', const ChallengesHubScreen()),
      ),
      (
        'Barcode Scan',
        Icons.qr_code_scanner_rounded,
        const Color(0xFFCFFAFE), // Cyan bg
        const Color(0xFF0891B2), // Cyan icon
        () => pushScreen(context, 'Barcode Scanner', const BarcodeScanScreen()),
      ),
      (
        'Face Yoga',
        Icons.self_improvement_rounded,
        const Color(0xFFFFEDD5), // Peach bg
        const Color(0xFFEA580C), // Orange icon
        () => pushScreen(context, 'Face & Scalp Yoga', const FaceHairYogaScreen()),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Services',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const Text(
              'All',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0284C7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Grid of 8 soft pastel squircle icons
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: services.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 14,
            crossAxisSpacing: 10,
            childAspectRatio: 0.82,
          ),
          itemBuilder: (context, index) {
            final item = services[index];
            return InkWell(
              onTap: item.$5,
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: isDark ? item.$3.withValues(alpha: 0.16) : item.$3,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark ? item.$4.withValues(alpha: 0.3) : item.$4.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Icon(item.$2, size: 24, color: item.$4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.$1,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 5. ADAPTIVE ACCESSIBILITY NOTICE
  // ---------------------------------------------------------------------------
  Widget _buildAdaptiveNotice(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0284C7).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.accessible_forward_rounded, color: Color(0xFF0284C7), size: 26),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Adaptive Seated Protocol Active',
                  style: TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                SizedBox(height: 2),
                Text(
                  'All exercises are calibrated for zero weight-bearing & wheelchair compatibility.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. DETAILED EXERCISE SCHEDULE LIST
  // ---------------------------------------------------------------------------
  Widget _buildScheduleList(BuildContext context, WorkoutPlan plan) {
    final isDark = ThemeManager.instance.isDark;
    final textPrimary = isDark ? const Color(0xFFDFE2F0) : const Color(0xFF0F172A);
    final cardBg = isDark ? const Color(0xFF171C25) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Today's Exercises",
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: textPrimary),
            ),
            Text(
              '${plan.completedCount}/${plan.entries.length} Completed',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final entry in plan.entries)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardBorder),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              leading: InkWell(
                onTap: () => _complete(entry),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: entry.isCompleted
                        ? const Color(0xFF10B981)
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: entry.isCompleted ? const Color(0xFF10B981) : cardBorder,
                    ),
                  ),
                  child: entry.isCompleted
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : (_busySlug == entry.exerciseSlug
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)),
                            )
                          : null),
                ),
              ),
              title: Text(
                entry.name,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: entry.isCompleted ? const Color(0xFF94A3B8) : textPrimary,
                  decoration: entry.isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: Text(
                '${entry.durationMin} min${entry.scheduledAt != null ? " · ${entry.scheduledAt}" : ""} · Tap to view form guide',
                style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
              onTap: () => _openExercise(entry),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 7. RECENT ACTIVITY SECTION
  // ---------------------------------------------------------------------------
  Widget _buildRecentActivitySection(BuildContext context) {
    final isDark = ThemeManager.instance.isDark;
    final textPrimary = isDark ? const Color(0xFFDFE2F0) : const Color(0xFF0F172A);
    final cardBg = isDark ? const Color(0xFF171C25) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary),
            ),
            InkWell(
              onTap: () => pushScreen(context, 'Record Activity', const RecordScreen()),
              child: const Text(
                'View all',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Recent Activity 1: Outdoor Run
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.directions_run_rounded, color: Color(0xFF0284C7), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Outdoor 5.2 km Run',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Morning Session · 28:40 min · 385 kcal',
                      style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '+120 Pts',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                ),
              ),
            ],
          ),
        ),

        // Recent Activity 2: Core Conditioning
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.fitness_center_rounded, color: Color(0xFF059669), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Core & Isometric Conditioning',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Yesterday · 20:00 min · Form Score 98%',
                      style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '+80 Pts',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFFD97706)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 8. CHRONO WINDOW BANNER
  // ---------------------------------------------------------------------------
  Widget _buildChronoWindowBanner(BuildContext context, TodayData data) {
    final isDark = ThemeManager.instance.isDark;
    return InkWell(
      onTap: _openCustomWindowDialog,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF171C25) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF0284C7), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chrono AI Daily Intelligence',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFFDFE2F0) : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.capacity.explanation,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF0284C7)),
          ],
        ),
      ),
    );
  }
}
