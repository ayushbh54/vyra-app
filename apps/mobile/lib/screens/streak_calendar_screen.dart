import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';

enum HeatmapThemeMode { emerald, flame }

class StreakCalendarScreen extends StatefulWidget {
  final int? initialYear;
  final int? initialMonth;
  final StreakCalendarData? initialCalendarData;

  const StreakCalendarScreen({
    super.key,
    this.initialYear,
    this.initialMonth,
    this.initialCalendarData,
  });

  @override
  State<StreakCalendarScreen> createState() => _StreakCalendarScreenState();
}

class _StreakCalendarScreenState extends State<StreakCalendarScreen> {
  late int _selectedYear;
  late int _selectedMonth;
  HeatmapThemeMode _palette = HeatmapThemeMode.emerald;

  bool _isLoading = true;
  String? _error;
  StreakCalendarData? _calendarData;
  bool _isCheckingIn = false;

  final List<String> _weekdays = const ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = widget.initialYear ?? now.year;
    _selectedMonth = widget.initialMonth ?? now.month;
    if (widget.initialCalendarData != null) {
      _calendarData = widget.initialCalendarData;
      _isLoading = false;
    } else {
      _loadCalendar();
    }
  }

  Future<void> _loadCalendar() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = context.read<VyraApi>();
      final data = await api.getStreakCalendar(
        year: _selectedYear,
        month: _selectedMonth,
      );
      if (mounted) {
        setState(() {
          _calendarData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _previousMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedMonth == 1) {
        _selectedMonth = 12;
        _selectedYear -= 1;
      } else {
        _selectedMonth -= 1;
      }
    });
    _loadCalendar();
  }

  void _nextMonth() {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    // Do not navigate beyond next month if future
    if (_selectedYear == now.year && _selectedMonth >= now.month) {
      return;
    }
    setState(() {
      if (_selectedMonth == 12) {
        _selectedMonth = 1;
        _selectedYear += 1;
      } else {
        _selectedMonth += 1;
      }
    });
    _loadCalendar();
  }

  Future<void> _handleManualCheckin() async {
    HapticFeedback.mediumImpact();
    setState(() => _isCheckingIn = true);

    try {
      final api = context.read<VyraApi>();
      final res = await api.checkin();
      if (mounted) {
        final streak = res['currentStreak'] ?? (_calendarData?.currentStreak ?? 0) + 1;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1B2029),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Daily Check-in Recorded! Streak: $streak Days 🔥',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
        _loadCalendar();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Check-in failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingIn = false);
    }
  }

  Color _getCellColor(int level, bool isDark) {
    if (_palette == HeatmapThemeMode.emerald) {
      if (isDark) {
        switch (level) {
          case 1:
            return const Color(0xFF0E4429);
          case 2:
            return const Color(0xFF006D32);
          case 3:
            return const Color(0xFF26A641);
          case 4:
            return const Color(0xFF39D353);
          default:
            return const Color(0xFF161B22);
        }
      } else {
        switch (level) {
          case 1:
            return const Color(0xFF9BE9A8);
          case 2:
            return const Color(0xFF40C463);
          case 3:
            return const Color(0xFF30A14E);
          case 4:
            return const Color(0xFF216E39);
          default:
            return const Color(0xFFEBEDF0);
        }
      }
    } else {
      // Flame Fire Palette
      if (isDark) {
        switch (level) {
          case 1:
            return const Color(0xFF4A2500);
          case 2:
            return const Color(0xFF8B3A00);
          case 3:
            return const Color(0xFFD35400);
          case 4:
            return const Color(0xFFFF5722);
          default:
            return const Color(0xFF1C1917);
        }
      } else {
        switch (level) {
          case 1:
            return const Color(0xFFFFD1A9);
          case 2:
            return const Color(0xFFFF9E58);
          case 3:
            return const Color(0xFFFF6F00);
          case 4:
            return const Color(0xFFD84315);
          default:
            return const Color(0xFFF3ECE7);
        }
      }
    }
  }

  Color _getCellBorder(int level, bool isDark) {
    if (_palette == HeatmapThemeMode.emerald) {
      if (isDark) {
        switch (level) {
          case 1:
            return const Color(0xFF185A37);
          case 2:
            return const Color(0xFF00893F);
          case 3:
            return const Color(0xFF32C950);
          case 4:
            return const Color(0xFF6BFF88);
          default:
            return const Color(0xFF272F3D);
        }
      } else {
        switch (level) {
          case 1:
            return const Color(0xFF85D893);
          case 2:
            return const Color(0xFF33AA53);
          case 3:
            return const Color(0xFF24853F);
          case 4:
            return const Color(0xFF165229);
          default:
            return const Color(0xFFD0D7DE);
        }
      }
    } else {
      if (isDark) {
        switch (level) {
          case 1:
            return const Color(0xFF6E3600);
          case 2:
            return const Color(0xFFB54C00);
          case 3:
            return const Color(0xFFFF7043);
          case 4:
            return const Color(0xFFFF8A65);
          default:
            return const Color(0xFF2D2622);
        }
      } else {
        switch (level) {
          case 1:
            return const Color(0xFFFFB380);
          case 2:
            return const Color(0xFFFF802B);
          case 3:
            return const Color(0xFFE65100);
          case 4:
            return const Color(0xFFBF360C);
          default:
            return const Color(0xFFDDD2CB);
        }
      }
    }
  }

  void _inspectDay(StreakDayItem day) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DayActivityInspectorSheet(
        dayItem: day,
        onCheckinRequested: _handleManualCheckin,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final todayStr =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final hasCheckedInToday =
        _calendarData?.days.any((d) => d.date == todayStr && d.checkedIn) ?? false;

    // Universal Responsive Clamping
    final mq = MediaQuery.of(context);
    final clampedMq = mq.copyWith(
      textScaler: mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.2),
    );

    return MediaQuery(
      data: clampedMq,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F131D) : const Color(0xFFF6F8FA),
        appBar: AppBar(
          title: Text(
            'Streak & Activity Matrix',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          backgroundColor: isDark ? const Color(0xFF161B24) : Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            // Palette Selector (Emerald vs Flame)
            IconButton(
              tooltip: 'Toggle Theme Palette',
              icon: Icon(
                _palette == HeatmapThemeMode.emerald
                    ? Icons.local_fire_department_rounded
                    : Icons.eco_rounded,
                color: _palette == HeatmapThemeMode.emerald
                    ? Colors.orangeAccent
                    : const Color(0xFF39D353),
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _palette = _palette == HeatmapThemeMode.emerald
                      ? HeatmapThemeMode.flame
                      : HeatmapThemeMode.emerald;
                });
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: VColor.accentCyan),
                )
              : _error != null
                  ? SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.redAccent),
                              const SizedBox(height: 12),
                              Text(
                                'Failed to load streak matrix',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _loadCalendar,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: VColor.accentCyan,
                                  foregroundColor: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 1. Hero HUD (Streak & Consistency Metric Cards)
                              _buildHeroHUD(isDark),
                              const SizedBox(height: 16),

                              // 2. Today Check-in Fast Banner (if not checked in yet)
                              if (!hasCheckedInToday) ...[
                                _buildCheckinActionBanner(isDark),
                                const SizedBox(height: 16),
                              ],

                              // 3. Calendar Month Header & Matrix Card
                              _buildCalendarCard(isDark),
                              const SizedBox(height: 16),

                              // 4. Intensity Legend & Explanation
                              _buildLegendCard(isDark),
                              const SizedBox(height: 16),

                              // 5. Daily Consistency Tips
                              _buildConsistencyPhilosophyCard(isDark),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildHeroHUD(bool isDark) {
    final data = _calendarData;
    final currentStreak = data?.currentStreak ?? 0;
    final longestStreak = data?.longestStreak ?? 0;
    final activeDays = data?.totalActiveDaysInMonth ?? 0;
    final totalDays = data?.days.length ?? 30;
    final consistency = data?.monthlyConsistencyPct ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            title: 'Current Streak',
            value: '$currentStreak',
            unit: 'Days',
            icon: Icons.local_fire_department_rounded,
            iconColor: Colors.orangeAccent,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            title: 'Best Streak',
            value: '$longestStreak',
            unit: 'Days',
            icon: Icons.emoji_events_rounded,
            iconColor: const Color(0xFFFFD700),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            title: 'Active Days',
            value: '$activeDays/$totalDays',
            unit: 'Days',
            icon: Icons.calendar_month_rounded,
            iconColor: VColor.accentCyan,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            title: 'Consistency',
            value: '$consistency%',
            unit: 'Rate',
            icon: Icons.bolt_rounded,
            iconColor: const Color(0xFF39D353),
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B24) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF262C38) : const Color(0xFFE1E4E8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckinActionBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF2B1C00), const Color(0xFF1D1500)]
              : [const Color(0xFFFFF3E0), const Color(0xFFFFE0B2)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.orangeAccent.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keep Your Flame Alive!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Check in today to maintain your consecutive streak.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _isCheckingIn ? null : _handleManualCheckin,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: _isCheckingIn
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Text(
                    'Check In',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard(bool isDark) {
    final data = _calendarData;
    final monthName = data?.monthName ?? 'Month';
    final year = data?.year ?? _selectedYear;
    final days = data?.days ?? [];

    final now = DateTime.now();
    final isCurrentMonth = _selectedYear == now.year && _selectedMonth == now.month;

    // Calculate empty offset cells for the first day of the month
    final firstDayOfWeek = DateTime(year, _selectedMonth, 1).weekday % 7; // 0 = Sun

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B24) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF262C38) : const Color(0xFFE1E4E8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Month Navigation Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 28),
                onPressed: _previousMonth,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              Row(
                children: [
                  Text(
                    '$monthName $year',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (isCurrentMonth) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: VColor.accentCyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: VColor.accentCyan.withValues(alpha: 0.4)),
                      ),
                      child: const Text(
                        'CURRENT',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: VColor.accentCyan,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 28),
                onPressed: isCurrentMonth ? null : _nextMonth,
                color: isCurrentMonth
                    ? (isDark ? Colors.white24 : Colors.black26)
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Weekday Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _weekdays.map((w) {
              return Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // Calendar Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: firstDayOfWeek + days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              if (index < firstDayOfWeek) {
                // Empty placeholder cell before start of month
                return const SizedBox.shrink();
              }

              final dayIndex = index - firstDayOfWeek;
              final dayItem = days[dayIndex];
              final dayNum = dayIndex + 1;

              final todayStr =
                  '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
              final isToday = dayItem.date == todayStr;

              final bgColor = _getCellColor(dayItem.level, isDark);
              final borderColor = isToday
                  ? VColor.accentCyan
                  : _getCellBorder(dayItem.level, isDark);

              final textDark = dayItem.level >= 2 && _palette == HeatmapThemeMode.emerald && !isDark;
              final textWhite = isDark || dayItem.level >= 2;

              return InkWell(
                onTap: () => _inspectDay(dayItem),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: borderColor,
                      width: isToday ? 2.0 : 1.0,
                    ),
                    boxShadow: [
                      if (dayItem.level == 4)
                        BoxShadow(
                          color: (_palette == HeatmapThemeMode.emerald
                                  ? const Color(0xFF39D353)
                                  : Colors.orangeAccent)
                              .withValues(alpha: 0.35),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          '$dayNum',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                            color: textWhite
                                ? Colors.white
                                : (textDark ? Colors.white : Colors.black87),
                          ),
                        ),
                      ),
                      if (isToday)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: VColor.accentCyan,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLegendCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B24) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF262C38) : const Color(0xFFE1E4E8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Activity Intensity',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
          Row(
            children: [
              Text(
                'Less ',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
              ...List.generate(5, (lvl) {
                return Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: _getCellColor(lvl, isDark),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: _getCellBorder(lvl, isDark),
                      width: 0.8,
                    ),
                  ),
                );
              }),
              Text(
                ' More',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConsistencyPhilosophyCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B24) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF262C38) : const Color(0xFFE1E4E8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, size: 18, color: VColor.accentCyan),
              const SizedBox(width: 8),
              Text(
                'How Activity Levels Work',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildLevelDescription(
            level: 1,
            title: 'Check-in Logged',
            desc: 'Daily check-in, light hydration or < 15 min movement.',
            isDark: isDark,
          ),
          _buildLevelDescription(
            level: 2,
            title: 'Moderate Activation',
            desc: '15–30 min workout or 5,000+ daily steps recorded.',
            isDark: isDark,
          ),
          _buildLevelDescription(
            level: 3,
            title: 'Target Achieved',
            desc: '30+ min workout session completed with target met.',
            isDark: isDark,
          ),
          _buildLevelDescription(
            level: 4,
            title: 'Beast Mode 🔥',
            desc: 'High-intensity session: 40+ min and 300+ kcal burned.',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildLevelDescription({
    required int level,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 3, right: 8),
            decoration: BoxDecoration(
              color: _getCellColor(level, isDark),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: _getCellBorder(level, isDark)),
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// INTERACTIVE DAY ACTIVITY INSPECTOR MODAL SHEET
/// ============================================================================
class _DayActivityInspectorSheet extends StatefulWidget {
  final StreakDayItem dayItem;
  final VoidCallback onCheckinRequested;

  const _DayActivityInspectorSheet({
    required this.dayItem,
    required this.onCheckinRequested,
  });

  @override
  State<_DayActivityInspectorSheet> createState() => _DayActivityInspectorSheetState();
}

class _DayActivityInspectorSheetState extends State<_DayActivityInspectorSheet> {
  bool _isLoading = true;
  DayDetailedBreakdown? _details;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchFullDayDetails();
  }

  Future<void> _fetchFullDayDetails() async {
    try {
      final api = context.read<VyraApi>();
      final res = await api.getDaySummary(widget.dayItem.date);
      if (mounted) {
        setState(() {
          _details = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = widget.dayItem;
    final detail = _details;

    // Active App Usage formatted (e.g. "0h 42m")
    final appUsageStr = detail?.appUsageFormatted ?? item.appUsageFormatted;
    final caloriesBurned = detail?.caloriesBurned ?? item.caloriesBurned;
    final caloriesConsumed = detail?.caloriesConsumed ?? item.caloriesConsumed;
    final netCalories = detail?.netCalories ?? item.netCalories;
    final waterMl = detail?.waterMl ?? item.waterMl;
    final steps = detail?.steps ?? item.steps;
    final coins = detail?.coinsEarned ?? item.coinsEarned;
    final exercises = detail?.exercisesCompleted ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131722) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 16,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Scrollable Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    // Date Title & Level Badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                detail?.formattedDate ?? item.date,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (item.checkedIn)
                                    _buildBadge(
                                      label: 'Check-in Verified',
                                      color: const Color(0xFF39D353),
                                      icon: Icons.check_circle_rounded,
                                    )
                                  else
                                    _buildBadge(
                                      label: 'No Check-in',
                                      color: Colors.grey,
                                      icon: Icons.cancel_outlined,
                                    ),
                                  const SizedBox(width: 8),
                                  if (item.level == 4)
                                    _buildBadge(
                                      label: 'Beast Mode',
                                      color: Colors.orangeAccent,
                                      icon: Icons.local_fire_department,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 14, color: Colors.orangeAccent),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Offline log preview',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.orange[200] : Colors.orange[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Primary Forensic Grid: App Screen Time & Caloric Net
                    Row(
                      children: [
                        Expanded(
                          child: _buildInspectionCard(
                            title: 'Active App Screen Time',
                            value: appUsageStr,
                            subtitle: 'Genuine coaching & app use (idle excluded)',
                            icon: Icons.timer_rounded,
                            iconColor: VColor.accentCyan,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInspectionCard(
                            title: 'Workouts Burned',
                            value: '$caloriesBurned',
                            subtitle: 'Total burned: $caloriesBurned kcal',
                            icon: Icons.local_fire_department_rounded,
                            iconColor: Colors.orangeAccent,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Caloric Balance Tri-Split
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A202C) : const Color(0xFFF7FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildCalorieStat(
                            title: 'Burned',
                            value: '$caloriesBurned kcal',
                            color: Colors.orangeAccent,
                            isDark: isDark,
                          ),
                          Container(
                            height: 28,
                            width: 1,
                            color: isDark ? Colors.grey[800] : Colors.grey[300],
                          ),
                          _buildCalorieStat(
                            title: 'Intake (Food)',
                            value: '$caloriesConsumed kcal',
                            color: const Color(0xFF39D353),
                            isDark: isDark,
                          ),
                          Container(
                            height: 28,
                            width: 1,
                            color: isDark ? Colors.grey[800] : Colors.grey[300],
                          ),
                          _buildCalorieStat(
                            title: 'Net Caloric Balance',
                            value: '${netCalories >= 0 ? '+' : ''}$netCalories kcal',
                            color: netCalories >= 0 ? VColor.accentCyan : Colors.purpleAccent,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Secondary Vital Telemetry (Water, Steps, Coins)
                    Row(
                      children: [
                        Expanded(
                          child: _buildMiniStat(
                            icon: Icons.water_drop_rounded,
                            iconColor: Colors.blueAccent,
                            label: 'Hydration',
                            value: '$waterMl ml',
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMiniStat(
                            icon: Icons.directions_walk_rounded,
                            iconColor: const Color(0xFF39D353),
                            label: 'Steps Walked',
                            value: '$steps',
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMiniStat(
                            icon: Icons.monetization_on_rounded,
                            iconColor: const Color(0xFFFFD700),
                            label: 'Coins Earned',
                            value: '+$coins',
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Completed Exercises Section
                    Text(
                      'Completed Exercises (${exercises.length})',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2, color: VColor.accentCyan),
                        ),
                      )
                    else if (exercises.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF181D28) : const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF262C38) : const Color(0xFFE9ECEF),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.bed_rounded,
                                color: isDark ? Colors.grey[500] : Colors.grey[600], size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.checkedIn
                                    ? 'Active Rest Day. Check-in and daily movements logged cleanly.'
                                    : 'No training routines logged for this day.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...exercises.map((e) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF181D28) : const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF262C38) : const Color(0xFFE9ECEF),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF39D353).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_rounded,
                                    color: Color(0xFF39D353), size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${e.sets} sets × ${e.reps} reps • ${e.durationFormatted}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                    // AI Cognitive Summary Note
                    if (detail != null && detail.summaryNote.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: VColor.accentCyan.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: VColor.accentCyan.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.auto_awesome_rounded,
                                size: 18, color: VColor.accentCyan),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                detail.summaryNote,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadge({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectionCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181D28) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF262C38) : const Color(0xFFE9ECEF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalorieStat({
    required String title,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181D28) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF262C38) : const Color(0xFFE9ECEF),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
