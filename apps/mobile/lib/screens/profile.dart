import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/screen_scaffold.dart';
import 'ai_chat.dart';
import 'beacon.dart';
import 'edit_profile.dart';
import 'emergency_contacts.dart';
import 'food.dart';
import 'health_sync.dart';
import 'lab_report.dart';
import 'leaderboard.dart';
import 'training_hub.dart';
import 'trophy_case.dart';

/// TAB 5 — PROFILE, HEALTH & PRIVACY
///
/// Three things live here: the seven health metrics, blood-report analysis, and
/// the privacy centre.
///
/// The report feature is the most dangerous in the app, so its UI follows the
/// engine's own rule: when a value is in a critical band, the dietary advice is
/// not merely de-emphasised — it is not rendered at all, and a referral takes
/// its place. Showing "eat more spinach" underneath "your haemoglobin is 6.2"
/// would be a design failure with real consequences.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _controllers = <String, TextEditingController>{
    'steps': TextEditingController(),
    'waterMl': TextEditingController(),
    'heartRateBpm': TextEditingController(),
    'weightKg': TextEditingController(),
  };

  static const _metricLabels = {
    'steps': ('Steps', 'e.g. 6400', ''),
    'waterMl': ('Water', 'e.g. 2000', 'ml'),
    'heartRateBpm': ('Resting heart rate', 'e.g. 68', 'bpm'),
    'weightKg': ('Weight', 'e.g. 62.5', 'kg'),
  };

  // Blood report
  final _hb = TextEditingController();
  final _vitD = TextEditingController();
  final _b12 = TextEditingController();

  LabAnalysis? _lab;
  bool _analysing = false;
  bool _savingMetrics = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _hb.dispose();
    _vitD.dispose();
    _b12.dispose();
    super.dispose();
  }

  Future<void> _saveMetrics() async {
    final values = <String, num>{};
    for (final entry in _controllers.entries) {
      final text = entry.value.text.trim();
      if (text.isEmpty) continue;
      final parsed = num.tryParse(text);
      if (parsed != null) values[entry.key] = parsed;
    }

    if (values.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least one reading first.')),
      );
      return;
    }

    setState(() => _savingMetrics = true);
    try {
      final message = await context.read<VyraApi>().logTracking(values);
      if (!mounted) return;
      for (final c in _controllers.values) {
        c.clear();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message ?? 'Saved.')),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _savingMetrics = false);
    }
  }

  Future<void> _analyse() async {
    final readings = <Map<String, dynamic>>[
      if (double.tryParse(_hb.text.trim()) != null)
        {'key': 'hemoglobin', 'value': double.parse(_hb.text.trim())},
      if (double.tryParse(_vitD.text.trim()) != null)
        {'key': 'vitamin_d', 'value': double.parse(_vitD.text.trim())},
      if (double.tryParse(_b12.text.trim()) != null)
        {'key': 'vitamin_b12', 'value': double.parse(_b12.text.trim())},
    ];

    if (readings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least one value from your report.')),
      );
      return;
    }

    setState(() => _analysing = true);
    try {
      final result = await context.read<VyraApi>().analyseLabReport(readings);
      if (mounted) setState(() => _lab = result);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _analysing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.base, VSpace.base, VSpace.xxxl),
        children: [
          Text('You', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: VSpace.lg),

          // ── Quick links — screens that no longer have a bottom-nav slot
          // now that Record/Maps/Groups match Strava's layout ─────────
          const VSectionHeader('More'),
          VCard(
            tone: CardTone.raised,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _QuickLink(
                  icon: Icons.watch_rounded,
                  label: 'Connect Smartwatch & Devices',
                  subtitle: 'Wear OS, Galaxy Watch, Apple Watch & BLE sensors',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HealthSyncScreen(api: context.read<VyraApi>()),
                    ),
                  ),
                ),
                const Divider(height: 1, color: VColor.line),
                _QuickLink(
                  icon: Icons.bolt_outlined,
                  label: 'Training Hub',
                  subtitle: 'Exercises, yoga, breathing, meditation',
                  onTap: () => pushScreen(context, 'Training Hub', const TrainingHubScreen()),
                ),
                const Divider(height: 1, color: VColor.line),
                _QuickLink(
                  icon: Icons.restaurant_outlined,
                  label: 'Food & Diet',
                  subtitle: 'Meal plan, macros, AI recipes',
                  onTap: () => pushScreen(context, 'Food & Diet', const FoodScreen()),
                ),
                const Divider(height: 1, color: VColor.line),
                _QuickLink(
                  icon: Icons.podcasts_outlined,
                  label: 'Beacon',
                  subtitle: 'Share live location with safety contacts',
                  onTap: () => pushScreen(context, 'Beacon', const BeaconScreen()),
                ),
                const Divider(height: 1, color: VColor.line),
                _QuickLink(
                  icon: Icons.auto_awesome_rounded,
                  label: 'AI Coach Chat',
                  subtitle: 'Ask Gemini about fitness, nutrition & recovery',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AiChatScreen())),
                ),
                const Divider(height: 1, color: VColor.line),
                _QuickLink(
                  icon: Icons.biotech_rounded,
                  label: 'Lab Report Scan',
                  subtitle: 'AI reads blood markers, suggests diet tips',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const LabReportScreen())),
                ),
                const Divider(height: 1, color: VColor.line),
                _QuickLink(
                  icon: Icons.emoji_events_rounded,
                  label: 'Leaderboard',
                  subtitle: 'Global & friends tier rankings',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
                ),
                const Divider(height: 1, color: VColor.line),
                _QuickLink(
                  icon: Icons.emergency_outlined,
                  label: 'Emergency Contacts',
                  subtitle: 'Up to 3 people, plus a one-tap 112 call',
                  onTap: () => pushScreen(
                      context, 'Emergency Contacts', const EmergencyContactsScreen()),
                ),
                const Divider(height: 1, color: VColor.line),
                _QuickLink(
                  icon: Icons.edit_outlined,
                  label: 'Edit Profile',
                  subtitle: 'Name, city, primary sport, weight',
                  onTap: () async {
                    try {
                      final me = await context.read<VyraApi>().me();
                      if (!context.mounted) return;
                      await pushScreen(
                        context,
                        'Edit Profile',
                        EditProfileScreen(
                          initialName: (me['name'] as String?) ?? '',
                          initialCity: (me['city'] as String?) ?? '',
                          initialPrimarySport: (me['primarySport'] as String?) ?? 'run',
                          initialWeightKg: (me['weightKg'] as num?)?.toDouble() ?? 60,
                        ),
                      );
                    } on ApiException catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(e.message)));
                      }
                    }
                  },
                ),
                const Divider(height: 1, color: VColor.line),
                _QuickLink(
                  icon: Icons.emoji_events_outlined,
                  label: 'Trophy Case',
                  subtitle: 'Activity milestones',
                  onTap: () => pushScreen(context, 'Trophy Case', const TrophyCaseScreen()),
                ),
              ],
            ),
          ),
          const SizedBox(height: VSpace.lg),

          // ── Health metrics ───────────────────────────────────────
          const VSectionHeader('Today\'s readings'),
          VCard(
            child: Column(
              children: [
                for (final key in _controllers.keys)
                  Padding(
                    padding: const EdgeInsets.only(bottom: VSpace.md),
                    child: Row(
                      children: [
                        Container(
                          width: 4, height: 34,
                          margin: const EdgeInsets.only(right: VSpace.md),
                          decoration: BoxDecoration(
                            color: VColor.metric(key),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            _metricLabels[key]!.$1,
                            style: const TextStyle(color: VColor.textMid, fontSize: 13.5),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _controllers[key],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.right,
                            style: const TextStyle(color: VColor.text, fontSize: 15),
                            decoration: InputDecoration(
                              hintText: _metricLabels[key]!.$2,
                              suffixText: _metricLabels[key]!.$3,
                              suffixStyle: const TextStyle(color: VColor.textLow, fontSize: 12),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: VSpace.xs),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _savingMetrics ? null : _saveMetrics,
                    child: const Text('Save readings'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: VSpace.md),
          const VDisclaimer(
            'These readings are for your own reference only. VYRA is not medical-grade '
            'equipment — do not use them to diagnose anything or to change medication.',
          ),

          const SizedBox(height: VSpace.xl),

          // ── Blood report ─────────────────────────────────────────
          const VSectionHeader('Blood report'),
          VCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter a few values from a recent report and VYRA will suggest foods that '
                  'support them, then weave those into your meal plan.',
                  style: TextStyle(color: VColor.textMid, fontSize: 13.5, height: 1.45),
                ),
                const SizedBox(height: VSpace.base),
                _labField('Haemoglobin', 'g/dL', _hb),
                _labField('Vitamin D (25-OH)', 'ng/mL', _vitD),
                _labField('Vitamin B12', 'pg/mL', _b12),
                const SizedBox(height: VSpace.sm),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _analysing ? null : _analyse,
                    child: _analysing
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: VColor.textOnAccent))
                        : const Text('Read my report'),
                  ),
                ),
              ],
            ),
          ),

          if (_lab != null) ...[
            const SizedBox(height: VSpace.md),
            _LabResultView(analysis: _lab!),
          ],

          const SizedBox(height: VSpace.xl),

          // ── Privacy ──────────────────────────────────────────────
          const VSectionHeader('Privacy'),
          VCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your health data is stored in India, encrypted, and belongs to you. You can '
                  'take a copy of everything or delete it permanently, at any time, without '
                  'asking anyone.',
                  style: TextStyle(color: VColor.textMid, fontSize: 13.5, height: 1.45),
                ),
                const SizedBox(height: VSpace.base),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await context.read<VyraApi>().exportMyData();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Your data export is ready.')),
                        );
                      } on ApiException catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(e.message)));
                      }
                    },
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Export everything about me'),
                  ),
                ),
                const SizedBox(height: VSpace.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmErase(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: VColor.crit,
                      side: const BorderSide(color: VColor.crit),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete my account and data'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _labField(String label, String unit, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: VSpace.md),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label, style: const TextStyle(color: VColor.textMid, fontSize: 13.5)),
          ),
          Expanded(
            flex: 2,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              style: const TextStyle(color: VColor.text, fontSize: 15),
              decoration: InputDecoration(
                suffixText: unit,
                suffixStyle: const TextStyle(color: VColor.textLow, fontSize: 11),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmErase(BuildContext context) async {
    // Deletion is irreversible, so it takes a deliberate second action. This is
    // the one place in the app where friction is the correct design.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VColor.surface,
        title: const Text('Delete everything?', style: TextStyle(color: VColor.text)),
        content: const Text(
          'This permanently deletes your account, your plans, your health readings and your '
          'coins. It cannot be undone.',
          style: TextStyle(color: VColor.textMid, height: 1.45),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep my account')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: VColor.crit)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await context.read<VyraApi>().eraseAccount();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your account and all associated data have been deleted.')),
      );
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

// -----------------------------------------------------------------------------

class _LabResultView extends StatelessWidget {
  const _LabResultView({required this.analysis});
  final LabAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    if (analysis.noReadableMarkers) {
      return VEmptyState(title: 'Nothing to read', body: analysis.nextStep);
    }

    // Critical path: referral only. The engine returns no dietary advice here,
    // and the UI must not invent any.
    if (analysis.urgentReferral) {
      return VCard(
        tone: CardTone.critical,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const VPill('Please see a doctor', tone: CardTone.critical),
            const SizedBox(height: VSpace.md),
            ...analysis.urgentReasons.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: VSpace.sm),
                  child: Text(r,
                      style: const TextStyle(color: VColor.text, fontSize: 14, height: 1.45)),
                )),
            const SizedBox(height: VSpace.sm),
            Text(analysis.nextStep,
                style: const TextStyle(color: VColor.text, fontSize: 14, height: 1.5)),
            const SizedBox(height: VSpace.base),
            VDisclaimer(analysis.disclaimer, severe: true),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const VLabel('What we read'),
              const SizedBox(height: VSpace.sm),
              ...analysis.findings.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: VSpace.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 7, height: 7,
                          margin: const EdgeInsets.only(top: 6, right: VSpace.sm),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: f.isNormal ? VColor.good : VColor.warn,
                          ),
                        ),
                        Expanded(
                          child: Text(f.summary,
                              style: const TextStyle(
                                  color: VColor.textMid, fontSize: 13.5, height: 1.45)),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),

        for (final adj in analysis.adjustments) ...[
          const SizedBox(height: VSpace.md),
          VCard(
            tone: CardTone.accent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: VLabel('More ${adj.label}')),
                    if (adj.seeADoctor) const VPill('Ask a doctor', tone: CardTone.warn),
                  ],
                ),
                const SizedBox(height: VSpace.sm),
                Wrap(
                  spacing: VSpace.sm,
                  runSpacing: VSpace.sm,
                  children: adj.foods
                      .map((f) => Chip(
                            label: Text(f),
                            labelStyle: const TextStyle(color: VColor.text, fontSize: 12.5),
                            backgroundColor: VColor.surfaceRaised,
                            side: const BorderSide(color: VColor.line),
                          ))
                      .toList(),
                ),
                const SizedBox(height: VSpace.md),
                Text(adj.tip,
                    style: const TextStyle(
                        color: VColor.textMid, fontSize: 13, height: 1.5)),
              ],
            ),
          ),
        ],

        // Advice we deliberately withheld, and why. Silence here would be worse
        // than the explanation.
        for (final s in analysis.suppressedAdvice) ...[
          const SizedBox(height: VSpace.md),
          VCard(
            tone: CardTone.warn,
            child: Text(s,
                style: const TextStyle(color: VColor.text, fontSize: 13.5, height: 1.5)),
          ),
        ],

        const SizedBox(height: VSpace.md),
        VCard(
          tone: CardTone.raised,
          child: Text(analysis.nextStep,
              style: const TextStyle(color: VColor.text, fontSize: 14, height: 1.5)),
        ),

        const SizedBox(height: VSpace.md),
        VDisclaimer(analysis.disclaimer),
      ],
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: VSpace.base, vertical: VSpace.md),
        child: Row(
          children: [
            Icon(icon, color: VColor.accent, size: 22),
            const SizedBox(width: VSpace.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(subtitle, style: const TextStyle(color: VColor.textLow, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: VColor.textLow),
          ],
        ),
      ),
    );
  }
}
