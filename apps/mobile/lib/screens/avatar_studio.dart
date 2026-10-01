import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import 'rpm_avatar_creator.dart';
import 'rpm_avatar_viewer.dart';

/// Entry point for the Avatar Studio.
/// Routes to the 3D viewer if an avatar URL is already saved,
/// or to the creation landing page if not.
class AvatarStudioScreen extends StatefulWidget {
  const AvatarStudioScreen({super.key});
  @override
  State<AvatarStudioScreen> createState() => _AvatarStudioScreenState();
}

class _AvatarStudioScreenState extends State<AvatarStudioScreen> {
  String? _savedUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('rpm_avatar_url');
    if (!mounted) return;
    setState(() {
      _savedUrl = url;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: VColor.bg,
        body: Center(child: CircularProgressIndicator(color: VColor.accent)),
      );
    }

    // If avatar already created → go directly to 3D viewer
    if (_savedUrl != null && _savedUrl!.isNotEmpty) {
      return const RpmAvatarViewerScreen();
    }

    // First time — show landing page
    return _AvatarLandingPage(onCreated: _load);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LANDING PAGE — shown when no avatar exists yet
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarLandingPage extends StatelessWidget {
  final VoidCallback onCreated;
  const _AvatarLandingPage({required this.onCreated});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VColor.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  BackButton(color: VColor.text),
                  Expanded(
                    child: Text(
                      '3D Avatar Studio',
                      style: TextStyle(
                        color: VColor.text,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Icon(Icons.threed_rotation_rounded,
                      color: VColor.accent, size: 24),
                  SizedBox(width: 8),
                ],
              ),
            ),

            // ── Hero area ────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // 3D icon with glow
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: VColor.surfaceRaised,
                        border: Border.all(color: VColor.accent, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: VColor.accent.withValues(alpha: 0.25),
                            blurRadius: 40,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: VColor.accent,
                        size: 80,
                      ),
                    ),

                    const SizedBox(height: 32),

                    const Text(
                      'Create Your\nRealistic 3D Avatar',
                      style: TextStyle(
                        color: VColor.text,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Use Ready Player Me to build a photorealistic 3D avatar. '
                      'Take a selfie for face scan, customize clothes, hair, '
                      'and see yourself work out in 3D.',
                      style: TextStyle(
                        color: VColor.textMid,
                        fontSize: 14,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 40),

                    // ── Feature chips ────────────────────────────────────────
                    const Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        _FeatureChip(
                            icon: Icons.face_retouching_natural_rounded,
                            label: 'Face Scan'),
                        _FeatureChip(
                            icon: Icons.checkroom_rounded,
                            label: 'Outfits'),
                        _FeatureChip(
                            icon: Icons.sports_gymnastics_rounded,
                            label: 'Animations'),
                        _FeatureChip(
                            icon: Icons.accessibility_new_rounded,
                            label: '3D Body'),
                        _FeatureChip(
                            icon: Icons.color_lens_rounded,
                            label: 'Skin & Hair'),
                        _FeatureChip(
                            icon: Icons.save_rounded,
                            label: 'Saved Forever'),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // ── Note about internet ──────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: VColor.warnSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: VColor.warn.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.wifi_rounded,
                              color: VColor.warn, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Internet connection required to create your 3D avatar via Ready Player Me.',
                              style: TextStyle(
                                  color: VColor.warn,
                                  fontSize: 12,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Create button ────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: const Text(
                          'Create 3D Avatar with Selfie',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VColor.accent,
                          foregroundColor: VColor.textOnAccent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () async {
                          final result =
                              await Navigator.push<String>(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const RpmAvatarCreatorScreen()),
                          );
                          if (result != null) onCreated();
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Skip / customize later ───────────────────────────────
                    TextButton.icon(
                      icon: const Icon(Icons.skip_next_rounded,
                          size: 18, color: VColor.textMuted),
                      label: const Text(
                        'Skip selfie — customize in creator',
                        style:
                            TextStyle(color: VColor.textMuted, fontSize: 13),
                      ),
                      onPressed: () async {
                        final result = await Navigator.push<String>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RpmAvatarCreatorScreen()),
                        );
                        if (result != null) onCreated();
                      },
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: VColor.accentGlow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VColor.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: VColor.accent, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
                color: VColor.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
