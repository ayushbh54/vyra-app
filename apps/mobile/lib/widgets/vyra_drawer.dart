import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../screens/avatar_studio.dart';
import '../screens/beacon.dart';
import '../screens/blood_donation.dart';
import '../screens/emergency_contacts.dart';
import '../screens/health_report_ai.dart';
import '../screens/health_sync.dart';
import '../screens/leaderboard.dart';
import '../screens/messages_inbox.dart';
import '../screens/nearby_doctors.dart';
import '../screens/pose_tracker.dart';
import '../screens/profile.dart';
import '../screens/settings.dart';
import '../screens/smartwatch_diagnostic_screen.dart';
import '../screens/water_reminder.dart';
import '../theme.dart';
import '../theme_manager.dart';
import 'screen_scaffold.dart';

/// VYRA Slide-out Profile Navigation Drawer
///
/// Designed cleanly matching the reference layout:
/// - Organization banner (VYRA ATHLETE ECOSYSTEM · VYRA ATHLETE OS)
/// - Athlete Hero Card with Avatar ("AB"), Name, ID/Handle, and "Switch user" action
/// - Top Rank & Tier Badge Card ("🏆 Rank #4 • Diamond Tier • 2,450 Pts")
/// - Clean category tiles with colored badges (Profile, Leaderboard, Security, Notifications,
///   Health Sync, Emergency Contacts, Beacon SOS, Messages Inbox, Contact Us)
/// - Theme Mode Switcher (Classic Bright / Obsidian Dark)
/// - Pinned bottom coral "Log out of this account" button
/// - System version watermark
class VyraDrawer extends StatefulWidget {
  const VyraDrawer({super.key});

  @override
  State<VyraDrawer> createState() => _VyraDrawerState();
}

class _VyraDrawerState extends State<VyraDrawer> {
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final p = await context.read<VyraApi>().getProfile();
      if (mounted) setState(() => _profile = p);
    } catch (_) {
      // Graceful fallback
    }
  }

  void _showSwitchUserDialog() {
    final isDark = ThemeManager.instance.isDark;
    final bg = isDark ? const Color(0xFF171C25) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFDFE2F0) : const Color(0xFF0F172A);

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(VRadius.xl)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: VSpace.base, vertical: VSpace.lg),
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
                      child: const Icon(Icons.sync_alt_rounded, color: Color(0xFF0284C7), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Switch Profile / Persona',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: VSpace.base),
                Text(
                  'Switch to a different athlete profile or test schedule persona:',
                  style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                const SizedBox(height: VSpace.base),
                _personaOption(ctx, 'student', 'Ayush Bhadoria (Individual Athlete)', 'Morning prime · 17 min daily window', Icons.person_rounded),
                _personaOption(ctx, 'nurse', 'Hospital Nurse', 'Shift worker · 12 hr shifts', Icons.medical_services_rounded),
                _personaOption(ctx, 'homemaker', 'Homemaker', 'Split schedule · High daytime mobility', Icons.home_rounded),
                _personaOption(ctx, 'open', 'Remote Athlete', 'Flexible schedule · Full day', Icons.laptop_chromebook_rounded),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _personaOption(BuildContext ctx, String id, String title, String subtitle, IconData icon) {
    final isDark = ThemeManager.instance.isDark;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF0284C7)),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: isDark ? const Color(0xFFDFE2F0) : const Color(0xFF0F172A))),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
      trailing: Icon(Icons.chevron_right_rounded, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), size: 20),
      onTap: () async {
        Navigator.pop(ctx);
        Navigator.pop(context); // Close drawer
        try {
          await context.read<VyraApi>().startDemoSession(id);
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
          }
        } catch (_) {}
      },
    );
  }

  void _showContactUsSheet() {
    final isDark = ThemeManager.instance.isDark;
    final bg = isDark ? const Color(0xFF171C25) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFDFE2F0) : const Color(0xFF0F172A);

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(VRadius.xl)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(VSpace.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0x2422C55E),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.support_agent_rounded, color: Color(0xFF22C55E), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Contact & Support',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: VSpace.base),
                Text(
                  'Have questions, feedback, or need sports medicine assistance?',
                  style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                const SizedBox(height: VSpace.base),
                _contactTile(Icons.mail_outline_rounded, 'Email Support', 'support@vyra.fit', const Color(0xFF3B82F6)),
                _contactTile(Icons.sports_rounded, 'VYRA Athletics Team', 'athletes@vyra.fit', const Color(0xFFF59E0B)),
                _contactTile(Icons.phone_in_talk_outlined, 'Athlete Safety Helpline', '+91 (800) 897-VYRA', const Color(0xFFEF4444)),
                const SizedBox(height: VSpace.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _contactTile(IconData icon, String title, String subtitle, Color color) {
    final isDark = ThemeManager.instance.isDark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: isDark ? const Color(0xFFDFE2F0) : const Color(0xFF0F172A))),
              Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final isDark = ThemeManager.instance.isDark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.lg)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Log out of VYRA?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Your active training session, streaks, and encrypted sync data will remain secure on this device.',
          style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.pop(context); // Close drawer
      final api = context.read<VyraApi>();
      await api.logout();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final athleteName = _profile?.name.isNotEmpty == true ? _profile!.name.toUpperCase() : 'AYUSH BHADORIA';
    final athleteId = _profile?.displayHandle.isNotEmpty == true ? _profile!.displayHandle : '2413227194';

    final initials = athleteName.split(' ').where((s) => s.isNotEmpty).map((s) => s[0]).take(2).join();

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeManager.instance.themeModeNotifier,
      builder: (context, currentThemeMode, _) {
        final isDark = ThemeManager.instance.isDark;
        final drawerBg = isDark ? const Color(0xFF0F131D) : const Color(0xFFF8FAFC);
        final cardBg = isDark ? const Color(0xFF171C25) : Colors.white;
        final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
        final textPrimary = isDark ? const Color(0xFFDFE2F0) : const Color(0xFF0F172A);
        final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

        return Drawer(
          backgroundColor: drawerBg,
          elevation: 16,
          child: SafeArea(
            child: Column(
              children: [
                // Scrollable content area
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      // Header: VYRA AI FITNESS ECOSYSTEM
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0284C7), Color(0xFF00D2FF)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'VYRA AI FITNESS',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                  color: textPrimary,
                                ),
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'ATHLETE ECOSYSTEM · VYRA OS',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.4,
                                      color: isDark ? const Color(0xFF00D2FF) : const Color(0xFF0284C7),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Profile Hero Card (Avatar, Name, ID, Switch user pill)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Avatar squircle with initials
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  colors: isDark
                                      ? [const Color(0xFF0284C7), const Color(0xFF00D2FF)]
                                      : [const Color(0xFF1E40AF), const Color(0xFF0284C7)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  initials.isNotEmpty ? initials : 'AB',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Name & Handle/ID
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    athleteName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '@ayushbh • $athleteId',
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Switch user button
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _showSwitchUserDialog,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                    border: Border.all(color: cardBorder),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.sync_alt_rounded,
                                        size: 13,
                                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Switch',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // TOP RANK & BADGE CARD (User requested: "aurr top par rank vegera badge vegera show ho jahan ham 3 lines tap kre")
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [const Color(0xFF3B2A10), const Color(0xFF221A0F)]
                                : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.35 : 0.5),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Text('🏆', style: TextStyle(fontSize: 17)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Rank #4',
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w900,
                                              color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF8AD8FF).withValues(alpha: 0.25),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'Diamond Tier',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0284C7),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '2,450 Activity Pts · 82% to Master',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF78350F),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Progress bar to next rank
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: 0.82,
                                minHeight: 4,
                                backgroundColor: isDark ? const Color(0xFF422006) : const Color(0xFFFDE68A),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Navigation Tiles matching Screenshot 2 style
                      _DrawerMenuItem(
                        icon: Icons.person_rounded,
                        iconBgColor: const Color(0xFF3B82F6), // Blue
                        title: 'My profile',
                        onTap: () {
                          Navigator.pop(context);
                          pushScreen(context, 'My Profile', const ProfileScreen());
                        },
                      ),
                      _DrawerMenuItem(
                        icon: Icons.emoji_events_rounded,
                        iconBgColor: const Color(0xFFF59E0B), // Gold
                        title: 'Leaderboard & Rankings',
                        onTap: () {
                          Navigator.pop(context);
                          pushScreen(context, 'National Leaderboard', const LeaderboardScreen());
                        },
                      ),
                      _DrawerMenuItem(
                        icon: Icons.near_me_rounded,
                        iconBgColor: const Color(0xFF0284C7), // Sky Blue
                        title: 'Direct Messages & Athlete Chat',
                        onTap: () {
                          Navigator.pop(context);
                          pushScreen(context, 'Messages Inbox', const MessagesInboxScreen());
                        },
                      ),
                      _DrawerMenuItem(
                        icon: Icons.lock_rounded,
                        iconBgColor: const Color(0xFF6366F1), // Indigo
                        title: 'Change password / Security',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SettingsScreen()),
                          );
                        },
                      ),
                      _DrawerMenuItem(
                        icon: Icons.notifications_rounded,
                        iconBgColor: const Color(0xFF8B5CF6), // Purple
                        title: 'Notification settings',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const WaterReminderScreen()),
                          );
                        },
                      ),
                      _DrawerMenuItem(
                        icon: Icons.watch_rounded,
                        iconBgColor: const Color(0xFF10B981), // Emerald
                        title: 'Smartwatch Sync (HiWatch Pro)',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => HealthSyncScreen(api: context.read<VyraApi>()),
                            ),
                          );
                        },
                      ),
                      _DrawerMenuItem(
                        icon: Icons.biotech_rounded,
                        iconBgColor: const Color(0xFF00D2FF), // Cyan
                        title: 'Watch Protocol Prober (Tester Tool)',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SmartwatchDiagnosticScreen(),
                            ),
                          );
                        },
                      ),

                      // ── NATIONAL HEALTH & ATHLETIC INNOVATIONS ──
                      _DrawerMenuItem(
                        icon: Icons.face_retouching_natural_rounded,
                        iconBgColor: const Color(0xFF00D2FF), // Cyan
                        title: '3D Coach Avatar & Digital Twin Studio',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AvatarStudioScreen()),
                          );
                        },
                      ),
                      _DrawerMenuItem(
                        icon: Icons.bloodtype_rounded,
                        iconBgColor: const Color(0xFFDC2626), // Red
                        title: 'e-RaktKosh Blood Donation (API Setu)',
                        onTap: () {
                          Navigator.pop(context);
                          pushScreen(context, 'e-RaktKosh Blood Lifeline', const BloodDonationScreen());
                        },
                      ),
                      _DrawerMenuItem(
                        icon: Icons.camera_enhance_rounded,
                        iconBgColor: const Color(0xFF00D2FF), // Cyan
                        title: 'AI Camera Pose & Rep Tracker',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const PoseTrackerScreen()),
                          );
                        },
                      ),
                      _DrawerMenuItem(
                        icon: Icons.document_scanner_rounded,
                        iconBgColor: const Color(0xFF10B981), // Emerald
                        title: 'AI Report Analysis',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const HealthReportAiScreen()),
                          );
                        },
                      ),
                      _DrawerMenuItem(
                        icon: Icons.local_hospital_rounded,
                        iconBgColor: const Color(0xFF0284C7), // Blue
                        title: 'Nearby Rated Doctors (NHA)',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const NearbyDoctorsScreen()),
                          );
                        },
                      ),
                      _DrawerMenuItem(
                        icon: Icons.security_rounded,
                        iconBgColor: const Color(0xFFEF4444), // Red
                        title: 'Safety & Emergency Contacts',
                        onTap: () {
                          Navigator.pop(context);
                          pushScreen(context, 'Safety & Emergency Contacts', const EmergencyContactsScreen());
                        },
                      ),
                      _DrawerMenuItem(
                        icon: Icons.radar_rounded,
                        iconBgColor: const Color(0xFF06B6D4), // Cyan
                        title: 'Beacon SOS & Live Location',
                        onTap: () {
                          Navigator.pop(context);
                          pushScreen(context, 'Beacon SOS & Live Location', const BeaconScreen());
                        },
                      ),
                      _DrawerMenuItem(
                        icon: Icons.chat_bubble_rounded,
                        iconBgColor: const Color(0xFF22C55E), // Green
                        title: 'Contact us / Support',
                        onTap: () {
                          Navigator.pop(context);
                          _showContactUsSheet();
                        },
                      ),

                      const SizedBox(height: 6),
                      Divider(color: cardBorder, height: 16),
                      const SizedBox(height: 6),

                      // Theme Switcher Tile (Classic Bright / Obsidian Dark)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF171C25) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'App Theme',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                      color: textPrimary,
                                    ),
                                  ),
                                  Text(
                                    isDark ? 'Obsidian Dark' : 'Classic Bright',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark ? const Color(0xFF00D2FF) : const Color(0xFF0284C7),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: isDark,
                              activeTrackColor: const Color(0xFF00D2FF),
                              onChanged: (_) {
                                ThemeManager.instance.toggleTheme();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Pinned Bottom Section: Coral Logout & Version info
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  decoration: BoxDecoration(
                    color: drawerBg,
                    border: Border(top: BorderSide(color: cardBorder)),
                  ),
                  child: Column(
                    children: [
                      // Logout pill button matching screenshot 2
                      InkWell(
                        onTap: _confirmLogout,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                            border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Log out of this account',
                                style: TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'VYRA AI Fitness · Enterprise Edition · v2.4.0',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: textSecondary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DrawerMenuItem extends StatelessWidget {
  const _DrawerMenuItem({
    required this.icon,
    required this.iconBgColor,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBgColor;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeManager.instance.isDark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        dense: true,
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 17),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? const Color(0xFFDFE2F0) : const Color(0xFF0F172A),
            fontSize: 13.8,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: isDark ? const Color(0xFF859399) : const Color(0xFF94A3B8),
          size: 19,
        ),
        onTap: onTap,
      ),
    );
  }
}
