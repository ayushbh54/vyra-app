import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/avatar_customization_service.dart';
import '../services/tts_service.dart';
import '../theme.dart';
import '../widgets/avatar_viewer_widget.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// COACH AVATAR STUDIO SCREEN
/// Offline-first 3D Coach selection and customization using pre-rigged
/// Adobe Mixamo humanoid models (.glb).
/// ─────────────────────────────────────────────────────────────────────────────
class CoachAvatarStudioScreen extends StatefulWidget {
  const CoachAvatarStudioScreen({super.key});

  @override
  State<CoachAvatarStudioScreen> createState() => _CoachAvatarStudioScreenState();
}

class _CoachAvatarStudioScreenState extends State<CoachAvatarStudioScreen> {
  // Selected coach: 'male' (Alex) or 'female' (Sara)
  String _selectedGender = 'male';
  String _activeAnim = 'Idle';
  bool _isSpeaking = false;
  bool _isSelectedSaved = false;

  // Local asset paths
  static const String _maleModelAsset = 'assets/models/male_coach.glb';
  static const String _femaleModelAsset = 'assets/models/female_coach.glb';

  @override
  void initState() {
    super.initState();
    _loadSavedCoach();
  }

  Future<void> _loadSavedCoach() async {
    final prefs = await SharedPreferences.getInstance();
    final savedGender = prefs.getString('selected_coach_gender') ??
        prefs.getString('user_gender')?.toLowerCase() ??
        'male';

    if (mounted) {
      setState(() {
        _selectedGender = savedGender == 'female' ? 'female' : 'male';
        _activeAnim = _selectedGender == 'female' ? 'SambaDance' : 'Idle';
      });
    }
  }

  Future<void> _selectCoach() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();

    final isMale = _selectedGender == 'male';
    final coachName = isMale ? 'Alex' : 'Sara';
    final coachModel = isMale ? _maleModelAsset : _femaleModelAsset;

    await prefs.setString('selected_coach_gender', _selectedGender);
    await prefs.setString('selected_coach_name', coachName);
    await prefs.setString('selected_coach_model', coachModel);
    await prefs.setString('rpm_avatar_url', coachModel); // Backwards compatibility

    // Notify Avatar Customization Service
    final currentProfile = AvatarCustomizationService.instance.profile;
    await AvatarCustomizationService.instance.updateProfile(
      currentProfile.copyWith(
        avatarGender: _selectedGender,
        userName: coachName,
      ),
    );

    if (!mounted) return;
    setState(() => _isSelectedSaved = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: VColor.accentGreen),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '3D Coach $coachName selected as your athletic mentor!',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E2620),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _testVoice() async {
    HapticFeedback.selectionClick();
    if (_isSpeaking) {
      await TtsService.stop();
      if (mounted) setState(() => _isSpeaking = false);
      return;
    }

    setState(() => _isSpeaking = true);

    final isMale = _selectedGender == 'male';
    final speechText = isMale
        ? "Welcome athlete! I'm Alex, your VYRA strength and conditioning coach. Let's conquer your training goals today."
        : "Hello athlete! I'm Sara, your mobility and athletic performance coach. Together we'll unlock your peak physical potential.";

    // Trigger walk/dance animation while speaking
    if (isMale) {
      setState(() => _activeAnim = 'Walk');
    }

    await TtsService.speak(speechText);

    if (mounted) {
      setState(() {
        _isSpeaking = false;
        if (isMale) _activeAnim = 'Idle';
      });
    }
  }

  @override
  void dispose() {
    TtsService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMale = _selectedGender == 'male';
    final coachName = isMale ? 'Alex' : 'Sara';
    final coachTitle = isMale ? 'Strength & Conditioning' : 'Agility & Mindset';
    final modelPath = isMale ? _maleModelAsset : _femaleModelAsset;

    final availableAnims = isMale
        ? [
            {'label': 'Idle Pose', 'anim': 'Idle', 'icon': Icons.accessibility_new_rounded},
            {'label': 'Running', 'anim': 'Run', 'icon': Icons.directions_run_rounded},
            {'label': 'Walking', 'anim': 'Walk', 'icon': Icons.directions_walk_rounded},
          ]
        : [
            {'label': 'Workout Dance', 'anim': 'SambaDance', 'icon': Icons.sports_gymnastics_rounded},
            {'label': 'T-Pose Form', 'anim': 'TPose', 'icon': Icons.accessibility_rounded},
          ];

    return Scaffold(
      backgroundColor: VColor.bg,
      appBar: AppBar(
        backgroundColor: VColor.surface,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.view_in_ar_rounded, color: VColor.accent, size: 20),
            SizedBox(width: 8),
            Text(
              '3D Coach Studio',
              style: TextStyle(
                color: VColor.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: VColor.accentGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(VRadius.pill),
              border: Border.all(color: VColor.accentGreen.withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off_rounded, size: 12, color: VColor.accentGreen),
                SizedBox(width: 5),
                Text(
                  '100% Offline 3D',
                  style: TextStyle(
                    color: VColor.accentGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Gender Switcher Bar ──
            Container(
              padding: const EdgeInsets.all(12),
              color: VColor.surface,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: VColor.bg,
                  borderRadius: BorderRadius.circular(VRadius.pill),
                  border: Border.all(color: VColor.line),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildGenderTab(
                        gender: 'male',
                        label: 'Alex (Male Coach)',
                        icon: Icons.male_rounded,
                        isSelected: isMale,
                      ),
                    ),
                    Expanded(
                      child: _buildGenderTab(
                        gender: 'female',
                        label: 'Sara (Female Coach)',
                        icon: Icons.female_rounded,
                        isSelected: !isMale,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── 3D Viewport ──
            Container(
              height: 380,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: VColor.line),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AvatarViewerWidget(
                  modelPath: modelPath,
                  animationName: _activeAnim,
                  coachName: coachName,
                  coachTitle: coachTitle,
                  height: 380,
                ),
              ),
            ),

            // ── Animation Mode Chips ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Text(
                    'ANIMATIONS:',
                    style: TextStyle(
                      color: VColor.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: availableAnims.map((item) {
                          final animKey = item['anim'] as String;
                          final isSelected = _activeAnim == animKey;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    item['icon'] as IconData,
                                    size: 14,
                                    color: isSelected ? Colors.black : VColor.accent,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    item['label'] as String,
                                    style: TextStyle(
                                      color: isSelected ? Colors.black : VColor.text,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              selected: isSelected,
                              backgroundColor: VColor.surface,
                              selectedColor: VColor.accent,
                              checkmarkColor: Colors.black,
                              side: BorderSide(
                                color: isSelected ? VColor.accent : VColor.line,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(VRadius.pill),
                              ),
                              onSelected: (_) {
                                HapticFeedback.selectionClick();
                                setState(() => _activeAnim = animKey);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Coach Profile Details Card ──
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: VColor.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: VColor.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isMale
                              ? const Color(0xFF1B2A40)
                              : const Color(0xFF3B1E38),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isMale ? VColor.accentCyan : Colors.purpleAccent,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          isMale ? Icons.fitness_center_rounded : Icons.spa_rounded,
                          color: isMale ? VColor.accentCyan : Colors.purpleAccent,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Coach $coachName',
                              style: const TextStyle(
                                color: VColor.text,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              coachTitle,
                              style: TextStyle(
                                color: isMale ? VColor.accentCyan : Colors.purpleAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Voice Test Button
                      IconButton.filledTonal(
                        onPressed: _testVoice,
                        icon: Icon(
                          _isSpeaking
                              ? Icons.volume_up_rounded
                              : Icons.record_voice_over_rounded,
                          size: 20,
                          color: VColor.accent,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: VColor.accent.withValues(alpha: 0.15),
                        ),
                        tooltip: 'Test Coach Voice',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: VColor.line, height: 1),
                  const SizedBox(height: 14),

                  // Specialties & Coaching Philosophy
                  const Text(
                    'COACHING SPECIALTIES',
                    style: TextStyle(
                      color: VColor.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (isMale
                            ? [
                                'Strength Training',
                                'Tactical HIIT',
                                'Form Discipline',
                                'Cardio Conditioning',
                              ]
                            : [
                                'Dynamic Mobility',
                                'Core Stability',
                                'Recovery & Flexibility',
                                'Nutrition Mindset',
                              ])
                        .map(
                          (spec) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: VColor.bg,
                              borderRadius: BorderRadius.circular(VRadius.sm),
                              border: Border.all(color: VColor.line),
                            ),
                            child: Text(
                              spec,
                              style: const TextStyle(
                                color: VColor.text,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 14),

                  // Voice & Demeanor
                  Row(
                    children: [
                      const Icon(Icons.mic_none_rounded,
                          size: 14, color: VColor.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        isMale
                            ? 'Tone: Direct, motivational, high-energy'
                            : 'Tone: Precision-focused, encouraging, calm',
                        style: const TextStyle(
                          color: VColor.textMuted,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Primary Action: Select Coach ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              child: ElevatedButton.icon(
                onPressed: _selectCoach,
                icon: Icon(
                  _isSelectedSaved
                      ? Icons.check_circle_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 20,
                ),
                label: Text(
                  _isSelectedSaved
                      ? 'Coach $coachName Active ✓'
                      : 'Select Coach $coachName as Active 3D Mentor',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSelectedSaved ? VColor.accentGreen : VColor.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderTab({
    required String gender,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedGender = gender;
          _activeAnim = gender == 'female' ? 'SambaDance' : 'Idle';
          _isSelectedSaved = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? VColor.surfaceRaised : Colors.transparent,
          borderRadius: BorderRadius.circular(VRadius.pill),
          border: isSelected
              ? Border.all(color: VColor.accent.withValues(alpha: 0.5))
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? VColor.accent : VColor.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? VColor.text : VColor.textMuted,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
