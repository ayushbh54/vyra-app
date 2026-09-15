import 'package:flutter/material.dart';
import '../theme_manager.dart';

/// VYRA Notifications & System Activity Log Bottom Sheet
///
/// Triggered by tapping the Bell icon on the Home Page header.
/// Displays real-time Chrono schedule triggers, hydration reminders,
/// leaderboard rank updates, and device sync notifications.
class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NotificationsSheet(),
    );
  }

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  final List<Map<String, dynamic>> _notifications = [
    {
      'id': 'notif-1',
      'title': 'Chrono Engine Optimized Slot',
      'message': 'Found your peak 45-min metabolic window today between 08:30 AM – 09:15 AM.',
      'time': '10m ago',
      'icon': Icons.bolt_rounded,
      'color': const Color(0xFF0284C7), // Blue
      'unread': true,
    },
    {
      'id': 'notif-2',
      'title': 'Hydration Check-in',
      'message': 'Log 250ml water to stay on track toward your 3,200ml daily target.',
      'time': '35m ago',
      'icon': Icons.water_drop_rounded,
      'color': const Color(0xFF06B6D4), // Cyan
      'unread': true,
    },
    {
      'id': 'notif-3',
      'title': 'Leaderboard Milestone',
      'message': 'You reached Rank #4 in the National Diamond Tier with 2,450 Activity Pts!',
      'time': '2h ago',
      'icon': Icons.emoji_events_rounded,
      'color': const Color(0xFFF59E0B), // Gold
      'unread': false,
    },
    {
      'id': 'notif-4',
      'title': 'AI Food Scan Verified',
      'message': 'Mediterranean Protein Bowl (620 kcal, 42g protein) analyzed & logged.',
      'time': '4h ago',
      'icon': Icons.document_scanner_rounded,
      'color': const Color(0xFF10B981), // Green
      'unread': false,
    },
    {
      'id': 'notif-5',
      'title': 'Smartwatch Sync Complete',
      'message': 'Health Connect synced 6,420 steps and 78 bpm resting heart rate baseline.',
      'time': 'Today',
      'icon': Icons.watch_rounded,
      'color': const Color(0xFF8B5CF6), // Purple
      'unread': false,
    },
  ];

  void _markAllRead() {
    setState(() {
      for (final n in _notifications) {
        n['unread'] = false;
      }
    });
  }

  void _dismiss(int index) {
    setState(() {
      _notifications.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeManager.instance.isDark;
    final bg = isDark ? const Color(0xFF171C25) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFDFE2F0) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final border = isDark ? const Color(0x3C859399) : const Color(0xFFE2E8F0);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: border, width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 14),

            // Sheet Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.notifications_rounded, color: Color(0xFF0284C7), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notifications & System Log',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Real-time alerts from Chrono AI & Health Sync',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _markAllRead,
                    child: const Text(
                      'Mark read',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(color: border, height: 1),

            // Notifications List
            Expanded(
              child: _notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 48, color: textSecondary),
                          const SizedBox(height: 12),
                          Text(
                            'All caught up!',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No new system notifications at this time.',
                            style: TextStyle(color: textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, __) => Divider(color: border.withValues(alpha: 0.6), height: 1),
                      itemBuilder: (context, index) {
                        final item = _notifications[index];
                        final isUnread = item['unread'] as bool;
                        final color = item['color'] as Color;

                        return Dismissible(
                          key: ValueKey(item['id']),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) => _dismiss(index),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: const Color(0xFFEF4444),
                            child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            decoration: BoxDecoration(
                              color: isUnread
                                  ? (isDark
                                      ? const Color(0xFF0284C7).withValues(alpha: 0.08)
                                      : const Color(0xFFE0F2FE).withValues(alpha: 0.4))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(item['icon'] as IconData, size: 19, color: color),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item['title'] as String,
                                              style: TextStyle(
                                                color: textPrimary,
                                                fontSize: 13.5,
                                                fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            item['time'] as String,
                                            style: TextStyle(
                                              color: textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item['message'] as String,
                                        style: TextStyle(
                                          color: textSecondary,
                                          fontSize: 12.5,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isUnread) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF97316),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
