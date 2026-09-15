import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../screens/beacon.dart';
import '../screens/emergency_contacts.dart';
import '../screens/health_sync.dart';
import '../screens/profile.dart';
import '../screens/settings.dart';
import '../screens/water_reminder.dart';
import '../theme.dart';
import '../theme_manager.dart';
import 'screen_scaffold.dart';

/// VYRA Slide-out Profile Navigation Drawer
///
/// Designed to match the user's institutional athlete portal screenshot:
/// - Organization banner (AKGEC / VYRA Ecosystem)
/// - Athlete Hero Card with Avatar, Name, Student ID/Handle, and "Switch user" action
/// - Clean category tiles with colored badges (Profile, Security, Notifications, Health Sync,
///   Emergency Contacts, Beacon SOS, Contact Us, Live Theme Mode Switcher)
/// - Bottom pinned coral "Log out of this account" button
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
      // Graceful fallback to default athlete info
    }
  }

  void _showSwitchUserDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: VColor.surfaceRaised,
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
                        color: VColor.accentGlow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.sync_alt_rounded, color: VColor.accent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Switch Profile / Persona',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: VColor.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: VSpace.base),
                const Text(
                  'Switch to a different athlete profile or test schedule persona:',
                  style: TextStyle(fontSize: 13, color: VColor.textMid),
                ),
                const SizedBox(height: VSpace.base),
                _personaOption(ctx, 'student', 'Ayush Bhadoria (Student)', 'AKGEC · 17 min daily window', Icons.school_rounded),
                _personaOption(ctx, 'nurse', 'Hospital Nurse', 'Shift worker · 12 hr shifts', Icons.medical_services_rounded),
                _personaOption(ctx, 'homemaker', 'Homemaker', 'Split schedule · High activity', Icons.home_rounded),
                _personaOption(ctx, 'open', 'Remote Athlete', 'Flexible schedule · Full day', Icons.laptop_chromebook_rounded),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _personaOption(BuildContext ctx, String id, String title, String subtitle, IconData icon) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: VColor.surface,
          border: Border.all(color: VColor.line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: VColor.accent),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: VColor.text)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: VColor.textLow)),
      trailing: const Icon(Icons.chevron_right_rounded, color: VColor.textLow, size: 20),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: VColor.surfaceRaised,
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
                    const Text(
                      'Contact & Support',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: VColor.text),
                    ),
                  ],
                ),
                const SizedBox(height: VSpace.base),
                const Text(
                  'Have questions, feedback, or need sports medicine assistance?',
                  style: TextStyle(fontSize: 13, color: VColor.textMid),
                ),
                const SizedBox(height: VSpace.base),
                _contactTile(Icons.mail_outline_rounded, 'Email Support', 'support@vyra.fit', const Color(0xFF3B82F6)),
                _contactTile(Icons.school_outlined, 'AKGEC Sports Department', 'sports@akgec.ac.in', const Color(0xFFF59E0B)),
                _contactTile(Icons.phone_in_talk_outlined, 'Safety & Helpline', '+91 (120) 276-2841', const Color(0xFFEF4444)),
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
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: VColor.text)),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: VColor.textMid)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VColor.surfaceRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.lg)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Log out of VYRA?', style: TextStyle(color: VColor.text, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Your active training session, streaks, and encrypted sync data will remain secure on this device.',
          style: TextStyle(color: VColor.textMid, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: VColor.textMid)),
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
        final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFEDF2F7);
        final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

        return Drawer(
          backgroundColor: isDark ? const Color(0xFF0F131D) : const Color(0xFFF8FAFC),
          elevation: 16,
          child: SafeArea(
            child: Column(
              children: [
                // Scrollable content area
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      // Organization / Institution header
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AJAY KUMAR GARG ENGINEERING COLLEGE',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: VColor.accentGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'VYRA ATHLETE ECOSYSTEM',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: isDark ? const Color(0xFF00D2FF) : const Color(0xFF0284C7),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Hero Card (Avatar, Name, ID, Switch user pill)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Avatar with initials
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: isDark
                                      ? [const Color(0xFF0284C7), const Color(0xFF00D2FF)]
                                      : [const Color(0xFF0369A1), const Color(0xFF0284C7)],
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
                                      color: isDark ? const Color(0xFFDFE2F0) : const Color(0xFF0F172A),
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    athleteId,
                                    style: TextStyle(
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      fontSize: 12,
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
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
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
                                        'Switch user',
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
                      const SizedBox(height: 18),

                      // Navigation Tiles
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
                        icon: Icons.lock_rounded,
                        iconBgColor: const Color(0xFFF59E0B), // Amber
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
                        title: 'Health Platform Sync',
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
                        title: 'Contact us',
                        onTap: () {
                          Navigator.pop(context);
                          _showContactUsSheet();
                        },
                      ),

                      const SizedBox(height: 6),
                      Divider(color: isDark ? const Color(0x3C859399) : const Color(0xFFE2E8F0), height: 16),
                      const SizedBox(height: 6),

                      // Theme Switcher Tile (Classic Bright / Obsidian Dark)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF171C25) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0x3C859399) : const Color(0xFFCBD5E1)),
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
                                      color: isDark ? const Color(0xFFDFE2F0) : const Color(0xFF0F172A),
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
                    color: isDark ? const Color(0xFF0F131D) : const Color(0xFFF8FAFC),
                    border: Border(top: BorderSide(color: isDark ? const Color(0x3C859399) : const Color(0xFFE2E8F0))),
                  ),
                  child: Column(
                    children: [
                      // Logout pill button matching screenshot
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
                        'EduMarshal · VYRA OS · v2.20260000907',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
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
