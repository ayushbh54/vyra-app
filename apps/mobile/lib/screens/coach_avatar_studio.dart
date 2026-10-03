import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/avatar_customization_service.dart';
import '../services/body_scan_service.dart';
import '../services/tts_service.dart';
import '../theme.dart';
import '../widgets/avatar_viewer_widget.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// COACH AVATAR STUDIO SCREEN
/// Offline-first 3D Coach selection and deep personalization using pre-rigged
/// Adobe Mixamo humanoid models (.glb) with AI Body Posture Scan integration.
/// ─────────────────────────────────────────────────────────────────────────────
class CoachAvatarStudioScreen extends StatefulWidget {
  const CoachAvatarStudioScreen({super.key});

  @override
  State<CoachAvatarStudioScreen> createState() => _CoachAvatarStudioScreenState();
}

class _CoachAvatarStudioScreenState extends State<CoachAvatarStudioScreen> {
  // ── Default: Remy (male) & Megan (female) — Adobe Mixamo realistic humans ──
  static const String _defaultMaleName   = 'Remy';
  static const String _defaultFemaleName = 'Megan';

  String _selectedGender = 'male';
  String _activeAnim = 'Idle';
  bool _isSpeaking = false;
  bool _isSelectedSaved = false;
  bool _isLoading = true;

  // Personalization settings — defaults to Remy until user renames
  String _coachName = _defaultMaleName;

  String _selectedPhysique = 'Athletic';
  String _selectedAuraName = 'Cyan Electric';
  Color _selectedAuraColor = const Color(0xFF00E5FF);

  String _selectedOutfitName = 'Signature Cyan';
  Color _selectedOutfitColor = const Color(0xFF00E5FF);

  BodyScanResult? _bodyScanResult;

  // 4-Angle Photos for AI Posture Scan
  final Map<String, File?> _bodyPhotos = {
    'front': null,
    'back': null,
    'left': null,
    'right': null,
  };
  bool _isScanning = false;

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
    final savedName = prefs.getString('selected_coach_name');
    final savedPhysique = prefs.getString('coach_physique') ?? 'Athletic';
    final savedAura = prefs.getString('coach_aura') ?? 'Cyan Electric';
    final savedAuraColorInt = prefs.getInt('coach_aura_color');
    final savedOutfit = prefs.getString('coach_outfit_name') ?? 'Signature Cyan';
    final savedOutfitColorInt = prefs.getInt('coach_outfit_color');

    final savedScan = await BodyScanService.instance.loadSaved();

    if (mounted) {
      setState(() {
        _selectedGender = savedGender == 'female' ? 'female' : 'male';
        // Female GLB: 'SambaDance' or 'TPose' — use TPose as neutral default
        // Male GLB: 'idle' or 'Take 001' — use idle (breathing) as default
        _activeAnim = _selectedGender == 'female' ? '' : 'Idle';
        // Default: Remy (male) or Megan (female) until user personalizes
        _coachName = savedName ??
            (_selectedGender == 'female' ? _defaultFemaleName : _defaultMaleName);
        _selectedPhysique = savedPhysique;
        _selectedAuraName = savedAura;
        if (savedAuraColorInt != null) _selectedAuraColor = Color(savedAuraColorInt);
        _selectedOutfitName = savedOutfit;
        if (savedOutfitColorInt != null) _selectedOutfitColor = Color(savedOutfitColorInt);
        _bodyScanResult = savedScan;
      });
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _selectCoach() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();

    final isMale = _selectedGender == 'male';
    final coachModel = isMale ? _maleModelAsset : _femaleModelAsset;

    await prefs.setString('selected_coach_gender', _selectedGender);
    // Cross-save gender to all keys so any screen can detect it
    await prefs.setString('user_gender', _selectedGender);
    await prefs.setString('avatar_gender', _selectedGender);
    
    await prefs.setString('selected_coach_name', _coachName);
    await prefs.setString('selected_coach_model', coachModel);
    await prefs.setString('coach_physique', _selectedPhysique);
    await prefs.setString('coach_aura', _selectedAuraName);
    await prefs.setInt('coach_aura_color', _selectedAuraColor.toARGB32());
    await prefs.setString('coach_outfit_name', _selectedOutfitName);
    await prefs.setInt('coach_outfit_color', _selectedOutfitColor.toARGB32());
    await prefs.setString('rpm_avatar_url', coachModel); // Universal fallback

    // Update Avatar Customization Service
    final currentProfile = AvatarCustomizationService.instance.profile;
    await AvatarCustomizationService.instance.updateProfile(
      currentProfile.copyWith(
        avatarGender: _selectedGender,
        userName: _coachName,
        bodyType: _selectedPhysique.toLowerCase(),
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
                '3D Coach $_coachName ($selectedPhysiqueLabel) applied across your app!',
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

  String get selectedPhysiqueLabel {
    if (_bodyScanResult != null) {
      return _bodyScanResult!.bodyTypeLabel;
    }
    return _selectedPhysique;
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
        ? "Hey! I'm $_coachName, your strength and conditioning coach. Let's conquer your training goals today."
        : "Hello! I'm $_coachName, your fitness and wellness coach. Together we'll unlock your peak physical form.";

    // Trigger walk animation while speaking
    setState(() => _activeAnim = 'Walk');


    await TtsService.speak(speechText);

    if (mounted) {
      setState(() {
        _isSpeaking = false;
        if (isMale) _activeAnim = 'Idle';
      });
    }
  }

  void _showEditNameDialog() {
    final controller = TextEditingController(text: _coachName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VColor.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Personalize Coach Name',
          style: TextStyle(color: VColor.text, fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: VColor.text),
          decoration: InputDecoration(
            hintText: 'Enter name (e.g. Alex, Aryan, Maya)',
            hintStyle: const TextStyle(color: VColor.textMuted),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: VColor.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: VColor.accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: VColor.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                setState(() {
                  _coachName = val;
                  _isSelectedSaved = false;
                });
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: VColor.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save Name', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showBodyScanSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: VColor.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: VColor.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.camera_alt_rounded, color: VColor.accentGreen, size: 22),
                    SizedBox(width: 8),
                    Text(
                      '4-Angle AI Posture Scan',
                      style: TextStyle(
                        color: VColor.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Upload photos from all 4 angles. Google MLKit analyzes your body proportions to auto-tune your 3D coach model.',
                  style: TextStyle(color: VColor.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 18),
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.15,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _photoSlot('front', '🫅', 'Front View', setSheetState),
                    _photoSlot('back', '🔙', 'Back View', setSheetState),
                    _photoSlot('left', '👈', 'Left Side', setSheetState),
                    _photoSlot('right', '👉', 'Right Side', setSheetState),
                  ],
                ),
                const SizedBox(height: 18),
                if (_bodyScanResult != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: VColor.accentGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: VColor.accentGreen.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: VColor.accentGreen, size: 20),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Detected: ${_bodyScanResult!.bodyTypeLabel}',
                              style: const TextStyle(
                                color: VColor.text,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Confidence: ${(_bodyScanResult!.confidence * 100).toInt()}% • Proportions matched',
                              style: const TextStyle(
                                color: VColor.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _bodyPhotos.values.any((f) => f != null) && !_isScanning
                        ? () async {
                            setSheetState(() => _isScanning = true);
                            await _scanAllPhotos(setSheetState);
                            setSheetState(() => _isScanning = false);
                          }
                        : null,
                    icon: _isScanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(_isScanning
                        ? 'Analyzing Biometrics…'
                        : 'Calibrate 3D Coach to My Body'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VColor.accent,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: VColor.surface,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _scanAllPhotos(StateSetter setSheetState) async {
    BodyScanResult? best;
    for (final file in _bodyPhotos.values) {
      if (file == null) continue;
      final res = await BodyScanService.instance.analyzeImage(file);
      if (res != null && (best == null || res.confidence > best.confidence)) {
        best = res;
      }
    }

    if (best != null && mounted) {
      setState(() {
        _bodyScanResult = best;
        _selectedPhysique = best!.bodyTypeLabel;
        _isSelectedSaved = false;
      });
      setSheetState(() {});
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ 3D Coach calibrated to ${best.bodyTypeLabel}!'),
          backgroundColor: const Color(0xFF1E2620),
        ),
      );
    }
  }

  Widget _photoSlot(
    String key,
    String emoji,
    String label,
    StateSetter setSheetState,
  ) {
    final file = _bodyPhotos[key];
    return GestureDetector(
      onTap: () async {
        final picker = ImagePicker();
        final xfile = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
        );
        if (xfile != null) {
          setSheetState(() => _bodyPhotos[key] = File(xfile.path));
          setState(() {});
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: file != null ? VColor.accent.withValues(alpha: 0.1) : VColor.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: file != null ? VColor.accent : VColor.line,
            width: file != null ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: file != null ? VColor.accent : VColor.text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              file != null ? '✓ Loaded' : 'Tap to add',
              style: TextStyle(
                color: file != null ? VColor.accentGreen : VColor.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    TtsService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: VColor.bg,
        body: Center(child: CircularProgressIndicator(color: VColor.accent)),
      );
    }

    final isMale = _selectedGender == 'male';
    final coachTitle = isMale ? 'Strength & Conditioning' : 'Agility & Mindset';
    final modelPath = isMale ? _maleModelAsset : _femaleModelAsset;

    final availableAnims = isMale
        ? [
            // Soldier GLB animations (capital letters: 'Idle', 'Run', 'Walk', 'TPose')
            {'label': 'Idle Stance', 'anim': 'Idle', 'icon': Icons.accessibility_new_rounded},
            {'label': 'Running', 'anim': 'Run', 'icon': Icons.directions_run_rounded},
            {'label': 'Walking', 'anim': 'Walk', 'icon': Icons.directions_walk_rounded},
            {'label': 'T-Pose', 'anim': 'TPose', 'icon': Icons.accessibility_rounded},
          ]
        : [
            // Megan GLB: 'idle' = samba dance animation
            {'label': 'Workout Dance', 'anim': 'idle', 'icon': Icons.sports_gymnastics_rounded},
            {'label': 'Neutral Pose', 'anim': '', 'icon': Icons.accessibility_rounded},
          ];

    final physiqueOptions = [
      'Athletic',
      'Muscular (V-Taper)',
      'Lean Runner',
      'Powerlifter',
    ];

    final auraColors = [
      {'name': 'Cyan Electric', 'color': const Color(0xFF00E5FF)},
      {'name': 'Matrix Green', 'color': const Color(0xFF00E676)},
      {'name': 'Crimson Fury', 'color': const Color(0xFFFF1744)},
      {'name': 'Solar Sunset', 'color': const Color(0xFFFF9100)},
    ];

    final outfitPresets = [
      {'name': 'Signature Cyan', 'color': const Color(0xFF00E5FF)},
      {'name': 'Stealth Black', 'color': const Color(0xFF212529)},
      {'name': 'Crimson Blaze', 'color': const Color(0xFFFF1744)},
      {'name': 'Matrix Green', 'color': const Color(0xFF00E676)},
      {'name': 'Solar Gold', 'color': const Color(0xFFFF9100)},
      {'name': 'Clean White', 'color': const Color(0xFFF8F9FA)},
    ];

    return Scaffold(
      backgroundColor: VColor.bg,
      appBar: AppBar(
        backgroundColor: VColor.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: VColor.text, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.view_in_ar_rounded, color: VColor.accent, size: 20),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                '3D Coach Studio',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: VColor.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // 4-Side Posture Scan Button
          IconButton(
            onPressed: _showBodyScanSheet,
            icon: const Icon(Icons.camera_alt_rounded, color: VColor.accentGreen),
            tooltip: '4-Angle AI Posture Scan',
          ),
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
                        label: 'Male Coach',
                        icon: Icons.male_rounded,
                        isSelected: isMale,
                      ),
                    ),
                    Expanded(
                      child: _buildGenderTab(
                        gender: 'female',
                        label: 'Female Coach',
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
              height: 340,
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
                  coachName: _coachName,
                  coachTitle: coachTitle,
                  outfitColor: _selectedOutfitColor,
                  auraColor: _selectedAuraColor,
                  height: 340,
                  cameraOrbit: '0deg 75deg 3.2m',
                  autoPlay: isMale || (_activeAnim.isNotEmpty && _activeAnim == 'idle'),
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

            // ── Personalization & Biometrics Suite ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: VColor.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: VColor.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune_rounded, color: VColor.accent, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'AVATAR PERSONALIZATION',
                        style: TextStyle(
                          color: VColor.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _showEditNameDialog,
                        icon: const Icon(Icons.edit_rounded, size: 14, color: VColor.accent),
                        label: const Text('Edit Name', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: VColor.accent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Physique Selector
                  const Text(
                    'BODY PHYSIQUE PRESET',
                    style: TextStyle(
                      color: VColor.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: physiqueOptions.map((opt) {
                        final isSel = _selectedPhysique == opt;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(opt),
                            selected: isSel,
                            labelStyle: TextStyle(
                              color: isSel ? Colors.black : VColor.text,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                            selectedColor: VColor.accent,
                            backgroundColor: VColor.bg,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(VRadius.sm),
                            ),
                            onSelected: (_) {
                              setState(() {
                                _selectedPhysique = opt;
                                _isSelectedSaved = false;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 4-Angle Posture Scan Banner
                  InkWell(
                    onTap: _showBodyScanSheet,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: VColor.accentGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: VColor.accentGreen.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.camera_enhance_rounded,
                              color: VColor.accentGreen, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _bodyScanResult != null
                                      ? 'Scanned: ${_bodyScanResult!.bodyTypeLabel} ✓'
                                      : '📸 4-Angle AI Posture Scan',
                                  style: const TextStyle(
                                    color: VColor.text,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Text(
                                  'Calibrate model to your exact human proportions',
                                  style: TextStyle(
                                    color: VColor.textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: VColor.accentGreen, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Outfit / Gear Apparel (Kapde Style) ──
                  const Text(
                    'OUTFIT & GEAR APPAREL',
                    style: TextStyle(
                      color: VColor.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: outfitPresets.map((outfit) {
                        final isSel = _selectedOutfitName == outfit['name'];
                        final color = outfit['color'] as Color;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white70),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(outfit['name'] as String),
                              ],
                            ),
                            selected: isSel,
                            labelStyle: TextStyle(
                              color: isSel ? Colors.black : VColor.text,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                            selectedColor: VColor.accent,
                            backgroundColor: VColor.bg,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(VRadius.sm),
                            ),
                            onSelected: (_) {
                              setState(() {
                                _selectedOutfitName = outfit['name'] as String;
                                _selectedOutfitColor = color;
                                _isSelectedSaved = false;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Aura Energy Color
                  const Text(
                    'ENERGY AURA THEME',
                    style: TextStyle(
                      color: VColor.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: auraColors.map((aura) {
                      final isSel = _selectedAuraName == aura['name'];
                      final color = aura['color'] as Color;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedAuraName = aura['name'] as String;
                            _isSelectedSaved = false;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                            border: Border.all(
                              color: isSel ? Colors.white : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: [
                              if (isSel)
                                BoxShadow(
                                  color: color.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            // ── Coach Profile Details Card ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
                              'Coach $_coachName',
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
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
                      ? 'Coach $_coachName Active ✓'
                      : 'Select Coach $_coachName as Active 3D Mentor',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isSelectedSaved ? VColor.accentGreen : VColor.accent,
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
          _activeAnim = gender == 'female' ? '' : 'Idle';
          _coachName = gender == 'female' ? 'Sara' : 'Alex';
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
