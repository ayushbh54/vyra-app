import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/screen_scaffold.dart';
import 'beacon.dart';
import 'edit_profile.dart';
import 'emergency_contacts.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserProfile? _profile;
  bool _loading = true;

  // Custom Workout Window
  String? _customWindowStart;
  String? _customWindowEnd;

  // Audio Coach Settings
  bool _audioCoachEnabled = true;

  // Timetable preferences
  int _preferredDurationMin = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<VyraApi>();
      _profile = await api.getProfile();
      final prefs = await SharedPreferences.getInstance();
      _customWindowStart = prefs.getString('custom_window_start');
      _customWindowEnd = prefs.getString('custom_window_end');
      _audioCoachEnabled = prefs.getBool('audio_coach_enabled') ?? true;
      _preferredDurationMin = prefs.getInt('preferred_duration_min') ?? 30;
      if (mounted) setState(() {});
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleAudioCoach(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('audio_coach_enabled', val);
    if (!mounted) return;
    setState(() => _audioCoachEnabled = val);
  }

  Future<void> _setPreferredDuration(int min) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('preferred_duration_min', min);
    if (!mounted) return;
    setState(() => _preferredDurationMin = min);
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('vyra_cached_feed_v1');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App cache cleared successfully.')),
      );
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VColor.surface,
        title: const Text('Log Out of VYRA?', style: TextStyle(color: VColor.text, fontWeight: FontWeight.bold)),
        content: const Text(
          'Your workout history, streaks and coins are safely backed up to your account.',
          style: TextStyle(color: VColor.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: VColor.textMid)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: VColor.warn),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final api = context.read<VyraApi>();
      await api.logout();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: VColor.bg, body: Center(child: VLoading()));

    return Scaffold(
      backgroundColor: VColor.bg,
      appBar: AppBar(
        backgroundColor: VColor.surface,
        leading: const BackButton(color: VColor.text),
        title: const Text('Settings', style: TextStyle(color: VColor.text, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: VColor.warn),
            tooltip: 'Log Out',
            onPressed: _logout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(VSpace.base),
        children: [
          // ── Account & Identity ──
          const VLabel('ACCOUNT & IDENTITY'),
          const SizedBox(height: VSpace.xs),
          VCard(
            tone: CardTone.raised,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline, color: VColor.accent),
                  title: Text(_profile?.name.isNotEmpty == true ? _profile!.name : 'Edit Athlete Profile',
                      style: const TextStyle(color: VColor.text, fontWeight: FontWeight.w600)),
                  subtitle: Text(_profile?.city.isNotEmpty == true ? '${_profile!.city} · ${_profile!.primarySport.toUpperCase()}' : 'Name, city, sport, weight',
                      style: const TextStyle(color: VColor.textMid, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: VColor.textLow),
                  onTap: () async {
                    await pushScreen(
                      context,
                      'Edit Profile',
                      EditProfileScreen(
                        initialName: _profile?.name ?? '',
                        initialCity: _profile?.city ?? '',
                        initialPrimarySport: _profile?.primarySport ?? 'run',
                        initialWeightKg: _profile?.weightKg ?? 60,
                        initialDisabilityFlag: _profile?.disabilityFlag ?? false,
                        initialDisabilityType: _profile?.disabilityType ?? 'none',
                        initialHasPhysicalConsideration: _profile?.hasPhysicalConsideration ?? false,
                        initialPhysicalConsiderationDetails: _profile?.physicalConsiderationDetails ?? '',
                        initialMedicalConditions: _profile?.medicalConditions ?? [],
                      ),
                    );
                    _load();
                  },
                ),
                const Divider(height: 1, color: VColor.line),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: VColor.warn),
                  title: const Text('Log Out', style: TextStyle(color: VColor.warn, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Sign out of your VYRA account', style: TextStyle(color: VColor.textMid, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: VColor.textLow),
                  onTap: _logout,
                ),
              ],
            ),
          ),
          const SizedBox(height: VSpace.base),

          // ── Workout & Timetable Preferences ──
          const VLabel('WORKOUT & TIMETABLE TIMING'),
          const SizedBox(height: VSpace.xs),
          VCard(
            tone: CardTone.raised,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Preferred Workout Window',
                        style: TextStyle(color: VColor.text, fontWeight: FontWeight.w600, fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: VColor.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _customWindowStart != null ? '$_customWindowStart – $_customWindowEnd' : 'Auto (Adaptive)',
                        style: const TextStyle(color: VColor.accent, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'VYRA automatically slots training into your schedule, or you can pick your exact preferred hours.',
                  style: TextStyle(color: VColor.textMid, fontSize: 12),
                ),
                const SizedBox(height: VSpace.sm),
                const Divider(color: VColor.line),
                const SizedBox(height: VSpace.xs),
                const Text('Target Session Duration',
                    style: TextStyle(color: VColor.text, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [15, 30, 45, 60].map((dur) {
                    final isSel = _preferredDurationMin == dur;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text('${dur}m'),
                          selected: isSel,
                          selectedColor: VColor.accent,
                          labelStyle: TextStyle(
                            color: isSel ? VColor.textOnAccent : VColor.text,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (_) => _setPreferredDuration(dur),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: VSpace.base),

          // ── Accessibility & Differently-Abled Athlete ──
          const VLabel('ACCESSIBILITY & ADAPTIVE TRAINING'),
          const SizedBox(height: VSpace.xs),
          VCard(
            tone: CardTone.raised,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.accessible_forward_rounded, color: VColor.accent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Adaptive & Seated Mode',
                              style: TextStyle(color: VColor.text, fontWeight: FontWeight.w600, fontSize: 14)),
                          Text(
                            _profile?.disabilityType != null && _profile!.disabilityType.isNotEmpty && _profile!.disabilityType != 'none'
                                ? 'Active: ${_profile!.disabilityType.toUpperCase()} (100% seated exercises)'
                                : 'Disabled · Generating standard full-body routines',
                            style: TextStyle(
                              color: _profile?.disabilityType != null && _profile!.disabilityType != 'none'
                                  ? VColor.accentGreen
                                  : VColor.textMid,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: VSpace.sm),
                OutlinedButton.icon(
                  onPressed: () async {
                    await pushScreen(
                      context,
                      'Edit Mobility & Health',
                      EditProfileScreen(
                        initialName: _profile?.name ?? '',
                        initialCity: _profile?.city ?? '',
                        initialPrimarySport: _profile?.primarySport ?? 'run',
                        initialWeightKg: _profile?.weightKg ?? 60,
                        initialDisabilityFlag: _profile?.disabilityFlag ?? false,
                        initialDisabilityType: _profile?.disabilityType ?? 'none',
                        initialHasPhysicalConsideration: _profile?.hasPhysicalConsideration ?? false,
                        initialPhysicalConsiderationDetails: _profile?.physicalConsiderationDetails ?? '',
                        initialMedicalConditions: _profile?.medicalConditions ?? [],
                      ),
                    );
                    _load();
                  },
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('Update Mobility & Conditions'),
                ),
              ],
            ),
          ),
          const SizedBox(height: VSpace.base),

          // ── Audio & Guidance ──
          const VLabel('AUDIO COACH & SPEECH'),
          const SizedBox(height: VSpace.xs),
          VCard(
            tone: CardTone.raised,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: VColor.accent,
                  title: const Text('Spoken Form Cues', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Speaks real-time tempo and form guidance via device speaker.',
                      style: TextStyle(color: VColor.textLow, fontSize: 12)),
                  value: _audioCoachEnabled,
                  onChanged: _toggleAudioCoach,
                ),
              ],
            ),
          ),
          const SizedBox(height: VSpace.base),

          // ── Safety & Beacon ──
          const VLabel('SAFETY & EMERGENCY'),
          const SizedBox(height: VSpace.xs),
          VCard(
            tone: CardTone.raised,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.podcasts_outlined, color: VColor.accent),
                  title: const Text('Live Beacon', style: TextStyle(color: VColor.text, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Auto-broadcast live GPS tracking to safety contacts',
                      style: TextStyle(color: VColor.textMid, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: VColor.textLow),
                  onTap: () => pushScreen(context, 'Beacon', const BeaconScreen()),
                ),
                const Divider(height: 1, color: VColor.line),
                ListTile(
                  leading: const Icon(Icons.emergency_outlined, color: VColor.warn),
                  title: const Text('Emergency Contacts & 112 SOS', style: TextStyle(color: VColor.text, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Direct 1-tap call & safety notification setup',
                      style: TextStyle(color: VColor.textMid, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: VColor.textLow),
                  onTap: () => pushScreen(context, 'Emergency Contacts', const EmergencyContactsScreen()),
                ),
              ],
            ),
          ),
          const SizedBox(height: VSpace.base),

          // ── App & Storage ──
          const VLabel('APP & STORAGE'),
          const SizedBox(height: VSpace.xs),
          VCard(
            tone: CardTone.raised,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cleaning_services_outlined, color: VColor.textMid),
                  title: const Text('Clear Offline Feed Cache', style: TextStyle(color: VColor.text, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Frees space without affecting your saved workout history',
                      style: TextStyle(color: VColor.textMid, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: VColor.textLow),
                  onTap: _clearCache,
                ),
                const Divider(height: 1, color: VColor.line),
                const ListTile(
                  leading: Icon(Icons.info_outline, color: VColor.textMid),
                  title: Text('App Version', style: TextStyle(color: VColor.text, fontWeight: FontWeight.w600)),
                  subtitle: Text('VYRA Release 1.0.0 (Chrono Engine v2)',
                      style: TextStyle(color: VColor.textMid, fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: VSpace.lg),

          // ── Log Out Button ──
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: VColor.warn,
                side: const BorderSide(color: VColor.warn),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.md)),
              ),
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded, color: VColor.warn),
              label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
          const SizedBox(height: VSpace.xxl),
        ],
      ),
    );
  }
}
