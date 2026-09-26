import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/avatar_customization_service.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// 3D COACH AVATAR & DIGITAL TWIN STUDIO
/// ─────────────────────────────────────────────────────────────────────────────
class AvatarStudioScreen extends StatefulWidget {
  const AvatarStudioScreen({super.key});

  @override
  State<AvatarStudioScreen> createState() => _AvatarStudioScreenState();
}

class _AvatarStudioScreenState extends State<AvatarStudioScreen>
    with SingleTickerProviderStateMixin {
  late AvatarFaceProfile _profile;
  double _rotationAngle = 0.0;
  String _activeTab = 'outfits'; // 'outfits', 'hairstyles', 'colors', 'shoes', 'face'
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;

  late AnimationController _idleAnimCtrl;

  @override
  void initState() {
    super.initState();
    _profile = AvatarCustomizationService.instance.profile;
    _idleAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _idleAnimCtrl.dispose();
    super.dispose();
  }

  void _updateProfile(AvatarFaceProfile newProfile) {
    setState(() {
      _profile = newProfile;
    });
    AvatarCustomizationService.instance.updateProfile(newProfile);
  }

  Future<void> _pickFacePhoto(ImageSource source) async {
    try {
      final xfile = await _picker.pickImage(
        source: source,
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 88,
      );
      if (xfile != null) {
        final updated = _profile.copyWith(
          photoPath: xfile.path,
          usePhotoFace: true,
          useUserLikeness: true,
        );
        _updateProfile(updated);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF102A43),
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF34FF8C)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Face photo mapped to 3D Avatar successfully!',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick photo: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070B12),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '3D Coach Avatar Studio',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00D2FF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF00D2FF).withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sync_rounded, color: Color(0xFF00D2FF), size: 14),
                SizedBox(width: 4),
                Text(
                  '360°',
                  style: TextStyle(
                    color: Color(0xFF00D2FF),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── TOP 3D AVATAR VIEWPORT (Interactive 360° Studio Podium) ──
            Expanded(
              flex: 5,
              child: GestureDetector(
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _rotationAngle += details.primaryDelta! * 0.02;
                  });
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Studio Ambient Background
                    Container(
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(0, -0.2),
                          radius: 0.85,
                          colors: [
                            Color(0xFF132035),
                            Color(0xFF080D16),
                            Color(0xFF05080E),
                          ],
                        ),
                      ),
                    ),

                    // 3D Pixar Stylized Character Stage with Interactive 3D Perspective Rotation
                    AnimatedBuilder(
                      animation: _idleAnimCtrl,
                      builder: (context, _) {
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001) // 3D Perspective
                            ..rotateY(_rotationAngle),
                          child: Image.asset(
                            'assets/images/coach_avatar_studio.png',
                            fit: BoxFit.contain,
                            alignment: Alignment.topCenter,
                            errorBuilder: (_, __, ___) => RepaintBoundary(
                              child: CustomPaint(
                                size: const Size(double.infinity, double.infinity),
                                painter: _StudioAvatar3DPainter(
                                  rotationAngle: _rotationAngle,
                                  idleProgress: _idleAnimCtrl.value,
                                  profile: _profile,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // User's Real Face Photo Picture-in-Picture Badge (if uploaded)
                    if (_profile.photoPath != null && _profile.usePhotoFace)
                      Positioned(
                        top: 14,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B1320).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF00D2FF), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00D2FF).withValues(alpha: 0.25),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(_profile.photoPath!),
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'My Face',
                                style: TextStyle(
                                  color: Color(0xFF00D2FF),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // 360° Drag Hint Pill
                    Positioned(
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app_rounded, color: Color(0xFF00D2FF), size: 14),
                            SizedBox(width: 6),
                            Text(
                              'Drag anywhere to rotate 360°',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Camera / Selfie Quick Action
                    Positioned(
                      top: 14,
                      left: 16,
                      child: GestureDetector(
                        onTap: () => _showPhotoSourceDialog(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D2FF).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF00D2FF).withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.camera_alt_rounded, color: Color(0xFF00D2FF), size: 16),
                              SizedBox(width: 5),
                              Text(
                                'Set Face Photo',
                                style: TextStyle(color: Color(0xFF00D2FF), fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── BOTTOM CUSTOMIZATION CONTROLS PANEL ──
            Expanded(
              flex: 4,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF0C111C),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border(
                    top: BorderSide(color: Color(0xFF1E2838), width: 1.5),
                  ),
                ),
                child: Column(
                  children: [
                    // Tab Bar: Outfits, Hairstyles, Colors, Shoes, Face
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          _buildTabButton('outfits', 'Outfits', Icons.checkroom_rounded),
                          _buildTabButton('hairstyles', 'Hairstyles', Icons.face_retouching_natural_rounded),
                          _buildTabButton('colors', 'Colors', Icons.palette_rounded),
                          _buildTabButton('body', 'Body & Gender', Icons.wc_rounded),
                          _buildTabButton('shoes', 'Shoes', Icons.skateboarding_rounded),
                          _buildTabButton('face', 'Face Photo', Icons.camera_alt_rounded),
                        ],
                      ),
                    ),

                    const Divider(color: Color(0xFF182232), height: 1),

                    // Tab Body Controls
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _buildTabContent(),
                      ),
                    ),

                    // Bottom Save Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSaving
                              ? null
                              : () async {
                                  setState(() => _isSaving = true);
                                  await AvatarCustomizationService.instance.updateProfile(_profile);
                                  await Future.delayed(const Duration(milliseconds: 300));
                                  if (!mounted) return;
                                  setState(() => _isSaving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: const Color(0xFF00D2FF),
                                      content: const Text(
                                        '3D Avatar Profile Saved Successfully!',
                                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00D2FF),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                          ),
                          child: _isSaving
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                              : const Text(
                                  'Save Avatar Profile',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String tabId, String label, IconData icon) {
    final isActive = _activeTab == tabId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _activeTab = tabId),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF00D2FF).withValues(alpha: 0.15) : const Color(0xFF141C2B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? const Color(0xFF00D2FF) : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: isActive ? const Color(0xFF00D2FF) : const Color(0xFF8896AB)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : const Color(0xFF8896AB),
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_activeTab) {
      case 'outfits':
        return _buildOutfitsGrid();
      case 'hairstyles':
        return _buildHairstylesGrid();
      case 'colors':
        return _buildSkinToneSelector();
      case 'body':
        return _buildBodyGenderControls();
      case 'shoes':
        return _buildShoesSelector();
      case 'face':
        return _buildFaceModeControls();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBodyGenderControls() {
    final isMale = _profile.avatarGender == 'male';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Avatar Archetype & Gender',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  _updateProfile(_profile.copyWith(
                    avatarGender: 'female',
                    hairStyle: 'pixar_wavy',
                    outfitStyle: 'athletic_teal',
                  ));
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: !isMale ? const Color(0xFF00D2FF).withValues(alpha: 0.15) : const Color(0xFF141C2B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: !isMale ? const Color(0xFF00D2FF) : const Color(0xFF243B53),
                      width: !isMale ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.female_rounded, color: !isMale ? const Color(0xFF00D2FF) : const Color(0xFF8896AB), size: 34),
                      const SizedBox(height: 8),
                      Text(
                        'Female Athlete ♀',
                        style: TextStyle(
                          color: !isMale ? Colors.white : const Color(0xFF8896AB),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Pixar Stylized Silhouette',
                        style: TextStyle(color: Color(0xFF8896AB), fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  _updateProfile(_profile.copyWith(
                    avatarGender: 'male',
                    hairStyle: 'crew_fade',
                    outfitStyle: 'runner_stealth',
                  ));
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isMale ? const Color(0xFF00D2FF).withValues(alpha: 0.15) : const Color(0xFF141C2B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isMale ? const Color(0xFF00D2FF) : const Color(0xFF243B53),
                      width: isMale ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.male_rounded, color: isMale ? const Color(0xFF00D2FF) : const Color(0xFF8896AB), size: 34),
                      const SizedBox(height: 8),
                      Text(
                        'Male Athlete ♂',
                        style: TextStyle(
                          color: isMale ? Colors.white : const Color(0xFF8896AB),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Broad Athletic V-Taper',
                        style: TextStyle(color: Color(0xFF8896AB), fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOutfitsGrid() {
    final isMale = _profile.avatarGender == 'male';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isMale ? 'Male Athletic Outfits' : 'Female Athletic Outfits',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF00D2FF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isMale ? 'Male ♂' : 'Female ♀',
                style: const TextStyle(color: Color(0xFF00D2FF), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!isMale) ...[
          Row(
            children: [
              Expanded(
                child: _buildOutfitCard(
                  'athletic_teal',
                  'Athletic Gym Set',
                  'Teal Sports Top + Grey Tights',
                  const Color(0xFF00D2FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOutfitCard(
                  'hoodie_white',
                  'Classic Hoodie',
                  'White Hoodie, Orange Belt & Jeans',
                  const Color(0xFFFF9F4A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildOutfitCard(
                  'runner_stealth',
                  'Aero Stealth',
                  'Matte Black Pro Runner',
                  const Color(0xFF829AB1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOutfitCard(
                  'sunset_orange',
                  'Sunset Energy',
                  'Coral Top + Performance Shorts',
                  const Color(0xFFFF6B6B),
                ),
              ),
            ],
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: _buildOutfitCard(
                  'male_muscle_tank',
                  'Athletic Muscle Tank',
                  'Cyan Gym Tank + Heavy Joggers',
                  const Color(0xFF00D2FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOutfitCard(
                  'runner_stealth',
                  'Stealth Compression Tee',
                  'Matte Black Carbon Tee & Pants',
                  const Color(0xFF829AB1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildOutfitCard(
                  'hoodie_white',
                  'Sleeveless Gym Hoodie',
                  'White Heather Hoodie + Shorts',
                  const Color(0xFFFF9F4A),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOutfitCard(
                  'sunset_orange',
                  'Warmup Tracksuit',
                  'Amber & Navy Performance Set',
                  const Color(0xFFFF6B6B),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildOutfitCard(String id, String title, String subtitle, Color accentColor) {
    final isSelected = _profile.outfitStyle == id;
    return GestureDetector(
      onTap: () => _updateProfile(_profile.copyWith(outfitStyle: id)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.12) : const Color(0xFF141C2B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accentColor : const Color(0xFF243B53),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.sports_gymnastics_rounded, color: accentColor, size: 22),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Equipped', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: Color(0xFF8896AB), fontSize: 10), maxLines: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildHairstylesGrid() {
    final isMale = _profile.avatarGender == 'male';
    final hairstyles = isMale
        ? [
            {'id': 'crew_fade', 'name': 'Athletic Fade', 'desc': 'Sharp taper fade'},
            {'id': 'short_crop', 'name': 'Textured Crop', 'desc': 'Modern textured gym cut'},
            {'id': 'slick_back', 'name': 'Slick Back', 'desc': 'Clean classic pompadour'},
            {'id': 'buzz_cut', 'name': 'Military Buzz', 'desc': 'Ultra clean high buzz'},
          ]
        : [
            {'id': 'pixar_wavy', 'name': 'Wavy Brown (Reference)', 'desc': 'Flowing stylized waves'},
            {'id': 'ponytail', 'name': 'Sporty Ponytail', 'desc': 'High bounce active pony'},
            {'id': 'high_bun', 'name': 'Topknot Bun', 'desc': 'Athletic studio bun'},
            {'id': 'short_crop', 'name': 'Modern Bob', 'desc': 'Shoulder length active bob'},
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Hairstyle',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: hairstyles.map((h) {
            final isSelected = _profile.hairStyle == h['id'];
            return ChoiceChip(
              label: Text(h['name']!),
              selected: isSelected,
              onSelected: (val) {
                if (val) _updateProfile(_profile.copyWith(hairStyle: h['id']));
              },
              selectedColor: const Color(0xFF00D2FF),
              backgroundColor: const Color(0xFF141C2B),
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                fontSize: 12,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSkinToneSelector() {
    final tones = [
      {'id': 'fair', 'name': 'Fair Ivory', 'color': const Color(0xFFF7D5BA)},
      {'id': 'wheatish', 'name': 'Wheatish Natural', 'color': const Color(0xFFE4AE84)},
      {'id': 'tan', 'name': 'Warm Tan', 'color': const Color(0xFFC78A5B)},
      {'id': 'dusky', 'name': 'Dusky Deep', 'color': const Color(0xFF87522E)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Skin Tone Pigment',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: tones.map((t) {
            final isSelected = _profile.skinTone == t['id'];
            return GestureDetector(
              onTap: () => _updateProfile(_profile.copyWith(skinTone: t['id'] as String)),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: t['color'] as Color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? const Color(0xFF00D2FF) : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: const Color(0xFF00D2FF).withValues(alpha: 0.5), blurRadius: 10)]
                          : [],
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.black, size: 20) : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t['name'] as String,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF00D2FF) : const Color(0xFF8896AB),
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildShoesSelector() {
    final shoes = [
      {'id': 'orange', 'name': 'Retro Orange (Reference)', 'color': const Color(0xFFFF9F4A)},
      {'id': 'cyan', 'name': 'Electric Cyan', 'color': const Color(0xFF00D2FF)},
      {'id': 'white', 'name': 'Clean White', 'color': Colors.white},
      {'id': 'stealth', 'name': 'Stealth Shadow', 'color': const Color(0xFF243B53)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Athletic Sneakers',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: shoes.map((s) {
            final isSelected = _profile.shoeColor == s['id'];
            return GestureDetector(
              onTap: () => _updateProfile(_profile.copyWith(shoeColor: s['id'] as String)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? (s['color'] as Color).withValues(alpha: 0.2) : const Color(0xFF141C2B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? (s['color'] as Color) : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(width: 14, height: 14, decoration: BoxDecoration(color: s['color'] as Color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(
                      s['name'] as String,
                      style: TextStyle(color: Colors.white, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, fontSize: 11),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFaceModeControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Face Setup Mode',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Use My Real Face Photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: const Text('Display your real selfie on the 3D avatar head', style: TextStyle(color: Color(0xFF8896AB), fontSize: 12)),
          value: _profile.usePhotoFace,
          activeColor: const Color(0xFF00D2FF),
          onChanged: (val) => _updateProfile(_profile.copyWith(usePhotoFace: val)),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: () => _showPhotoSourceDialog(),
          icon: const Icon(Icons.camera_alt_rounded),
          label: Text(_profile.photoPath == null ? 'Take Selfie / Upload Face Photo' : 'Update Face Photo'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF14243B),
            foregroundColor: const Color(0xFF00D2FF),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF00D2FF))),
          ),
        ),
      ],
    );
  }

  void _showPhotoSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E1626),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Set Your Face on 3D Avatar',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Take a quick selfie or choose a photo from your gallery.',
                  style: TextStyle(color: Color(0xFF8896AB), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF00D2FF).withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF00D2FF)),
                  ),
                  title: const Text('Take Selfie (Camera)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickFacePhoto(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF34FF8C).withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.photo_library_rounded, color: Color(0xFF34FF8C)),
                  ),
                  title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickFacePhoto(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// PIXAR-STYLE 3D STYLIZED AVATAR CUSTOM PAINTER (Standing Studio Pose)
/// ─────────────────────────────────────────────────────────────────────────────
class _StudioAvatar3DPainter extends CustomPainter {
  _StudioAvatar3DPainter({
    required this.rotationAngle,
    required this.idleProgress,
    required this.profile,
  });

  final double rotationAngle;
  final double idleProgress;
  final AvatarFaceProfile profile;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.52;

    // 1. Draw Glowing Cybernetic Circular Studio Podium
    _drawPodium(canvas, cx, size.height * 0.82);

    // Idle breathing offset
    final breathe = math.sin(idleProgress * math.pi) * 3.0;

    // Orbit angle shift
    final cosRot = math.cos(rotationAngle);
    final sinRot = math.sin(rotationAngle);

    // 2. Contact Drop Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, size.height * 0.81), width: 140, height: 26),
      shadowPaint,
    );

    // 3. Body Landmarks in 3D Space
    // Feet
    final footL = Offset(cx - 24 * cosRot, size.height * 0.80);
    final footR = Offset(cx + 24 * cosRot, size.height * 0.80);

    // Knees
    final kneeL = Offset(cx - 20 * cosRot, cy + 85);
    final kneeR = Offset(cx + 20 * cosRot, cy + 85);

    final isMale = profile.avatarGender == 'male';

    // Hips / Pelvis
    final pelvis = Offset(cx, cy + 25 - (breathe * 0.2));

    // Shoulders (Male: broad 48px span, Female: 38px span)
    final shoulderSpan = isMale ? 48.0 : 38.0;
    final shoulderL = Offset(cx - shoulderSpan * cosRot, cy - (isMale ? 47 : 45) - breathe);
    final shoulderR = Offset(cx + shoulderSpan * cosRot, cy - (isMale ? 47 : 45) - breathe);

    // Elbows & Hands (Hands in pockets / on hips like reference image!)
    final elbowSpan = isMale ? 58.0 : 52.0;
    final elbowL = Offset(cx - elbowSpan * cosRot - (sinRot * 10), cy - 10 - breathe);
    final elbowR = Offset(cx + elbowSpan * cosRot + (sinRot * 10), cy - 10 - breathe);
    final handL = Offset(cx - (isMale ? 26 : 22) * cosRot, cy + 28 - breathe);
    final handR = Offset(cx + (isMale ? 26 : 22) * cosRot, cy + 28 - breathe);

    // Head & Neck
    final neck = Offset(cx, cy - 65 - breathe);
    final head = Offset(cx, cy - 105 - breathe);

    // Outfit Colors
    Color topPrimary = const Color(0xFF00D2FF);
    Color topSecondary = const Color(0xFF142438);
    Color pantsColor = const Color(0xFF334E68);
    Color beltColor = const Color(0xFFFF9F4A);

    if (profile.outfitStyle == 'hoodie_white') {
      // EXACT REFERENCE STYLE: White hoodie, orange belt, dark grey pants
      topPrimary = const Color(0xFFE8EEF5);
      topSecondary = const Color(0xFFCAD5E2);
      pantsColor = const Color(0xFF3E4C5E);
      beltColor = const Color(0xFFFF7A29);
    } else if (profile.outfitStyle == 'runner_stealth') {
      topPrimary = const Color(0xFF1E2838);
      topSecondary = const Color(0xFF0F172A);
      pantsColor = const Color(0xFF141C2B);
      beltColor = const Color(0xFF00D2FF);
    } else if (profile.outfitStyle == 'sunset_orange') {
      topPrimary = const Color(0xFFFF6B6B);
      topSecondary = const Color(0xFFFF9F4A);
      pantsColor = const Color(0xFF2B2D42);
      beltColor = const Color(0xFFFFE66D);
    }

    // 4. Draw Legs (Pants / Leggings)
    final legPaint = Paint()
      ..color = pantsColor
      ..strokeWidth = isMale ? 28 : 24
      ..strokeCap = StrokeCap.round;

    // Left Leg
    canvas.drawLine(pelvis, kneeL, legPaint);
    canvas.drawLine(kneeL, footL, legPaint);

    // Right Leg
    canvas.drawLine(pelvis, kneeR, legPaint);
    canvas.drawLine(kneeR, footR, legPaint);

    // 5. Draw Sneakers
    Color shoeColor = const Color(0xFFFF9F4A); // Orange like reference!
    if (profile.shoeColor == 'cyan') shoeColor = const Color(0xFF00D2FF);
    if (profile.shoeColor == 'white') shoeColor = Colors.white;
    if (profile.shoeColor == 'stealth') shoeColor = const Color(0xFF1E2838);

    final shoePaint = Paint()..color = shoeColor..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: footL, width: isMale ? 32 : 28, height: isMale ? 18 : 16), const Radius.circular(8)), shoePaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: footR, width: isMale ? 32 : 28, height: isMale ? 18 : 16), const Radius.circular(8)), shoePaint);

    // 6. Draw Torso (Top / Hoodie / Tank)
    final waistWidth = (isMale ? 22.0 : 18.0) * cosRot;
    final torsoPath = Path()
      ..moveTo(shoulderL.dx, shoulderL.dy)
      ..lineTo(shoulderR.dx, shoulderR.dy)
      ..lineTo(pelvis.dx + waistWidth, pelvis.dy)
      ..lineTo(pelvis.dx - waistWidth, pelvis.dy)
      ..close();
    canvas.drawPath(torsoPath, Paint()..color = topPrimary..style = PaintingStyle.fill);

    // Orange Waist Belt (like reference!)
    final beltRect = Rect.fromCenter(center: pelvis, width: (isMale ? 50 : 44) * cosRot.abs() + 10, height: 8);
    canvas.drawRRect(RRect.fromRectAndRadius(beltRect, const Radius.circular(4)), Paint()..color = beltColor);
    // Belt Buckle
    canvas.drawCircle(pelvis, 5, Paint()..color = const Color(0xFFDFE2F0));

    // 7. Draw Arms (Sleeves + Hands)
    final armPaint = Paint()
      ..color = topSecondary
      ..strokeWidth = isMale ? 18 : 14
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(shoulderL, elbowL, armPaint);
    canvas.drawLine(elbowL, handL, armPaint);

    canvas.drawLine(shoulderR, elbowR, armPaint);
    canvas.drawLine(elbowR, handR, armPaint);

    // 8. Draw Neck
    final skinColors = profile.skinGradientColors;
    canvas.drawRect(Rect.fromCenter(center: neck, width: 14, height: 18), Paint()..color = skinColors[1]);

    // 9. Draw Head (Pixar Stylized Face)
    _drawPixarFace(canvas, head, cosRot, sinRot);
  }

  void _drawPodium(Canvas canvas, double cx, double cy) {
    // Outer cybernetic ring
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 6), width: 260, height: 50),
      Paint()
        ..color = const Color(0xFF00D2FF).withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Glowing Neon Cyan Center Stage
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 220, height: 42),
      Paint()
        ..color = const Color(0xFF0E1A2B)
        ..style = PaintingStyle.fill,
    );

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 220, height: 42),
      Paint()
        ..color = const Color(0xFF00D2FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4),
    );

    // Inner bright ring
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - 2), width: 180, height: 34),
      Paint()
        ..color = const Color(0xFF34FF8C).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawPixarFace(Canvas canvas, Offset head, double cosRot, double sinRot) {
    const headRadius = 32.0;

    // Head base with skin tone gradient
    final skinColors = profile.skinGradientColors;
    final skinGrad = RadialGradient(
      center: Alignment(0.2 * cosRot, -0.3),
      radius: 0.85,
      colors: skinColors,
    );

    canvas.drawCircle(
      head,
      headRadius,
      Paint()
        ..shader = skinGrad.createShader(Rect.fromCircle(center: head, radius: headRadius))
        ..style = PaintingStyle.fill,
    );

    final isMale = profile.avatarGender == 'male';
    final hairPaint = Paint()..color = profile.hairColor..style = PaintingStyle.fill;

    if (!isMale) {
      // ── FEMALE HAIRSTYLE (Flowing rich waves like reference image!) ──
      // Left & Right flowing curls
      canvas.drawCircle(Offset(head.dx - 26, head.dy - 10), 18, hairPaint);
      canvas.drawCircle(Offset(head.dx + 26, head.dy - 10), 18, hairPaint);
      canvas.drawCircle(Offset(head.dx - 28, head.dy + 12), 16, hairPaint);
      canvas.drawCircle(Offset(head.dx + 28, head.dy + 12), 16, hairPaint);

      // Top hair volume
      final topHairPath = Path()
        ..moveTo(head.dx - 32, head.dy - 12)
        ..quadraticBezierTo(head.dx, head.dy - 48, head.dx + 32, head.dy - 12)
        ..quadraticBezierTo(head.dx, head.dy - 20, head.dx - 32, head.dy - 12)
        ..close();
      canvas.drawPath(topHairPath, hairPaint);
    } else {
      // ── MALE HAIRSTYLE (Athletic taper fade / textured modern crop) ──
      final maleTopHair = Path()
        ..moveTo(head.dx - 32, head.dy - 8)
        ..quadraticBezierTo(head.dx, head.dy - 44, head.dx + 32, head.dy - 8)
        ..quadraticBezierTo(head.dx, head.dy - 22, head.dx - 32, head.dy - 8)
        ..close();
      canvas.drawPath(maleTopHair, hairPaint);

      // Clean side tapers
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(head.dx - 30, head.dy - 2), width: 6, height: 22),
          const Radius.circular(3),
        ),
        hairPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(head.dx + 30, head.dy - 2), width: 6, height: 22),
          const Radius.circular(3),
        ),
        hairPaint,
      );
    }

    // Face features (Eyes, eyebrows, smile)
    final eyeShiftX = 10 * cosRot;
    final eyeL = Offset(head.dx - 11 + (eyeShiftX * 0.4), head.dy - 4);
    final eyeR = Offset(head.dx + 11 + (eyeShiftX * 0.4), head.dy - 4);

    // Eye whites
    canvas.drawOval(Rect.fromCenter(center: eyeL, width: 13, height: 16), Paint()..color = Colors.white);
    canvas.drawOval(Rect.fromCenter(center: eyeR, width: 13, height: 16), Paint()..color = Colors.white);

    // Big expressive brown irises
    canvas.drawCircle(eyeL, 5.5, Paint()..color = const Color(0xFF5C3317));
    canvas.drawCircle(eyeR, 5.5, Paint()..color = const Color(0xFF5C3317));

    // Pupils & catchlights
    canvas.drawCircle(eyeL, 3, Paint()..color = Colors.black);
    canvas.drawCircle(eyeR, 3, Paint()..color = Colors.black);
    canvas.drawCircle(Offset(eyeL.dx - 1.5, eyeL.dy - 1.5), 1.5, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(eyeR.dx - 1.5, eyeR.dy - 1.5), 1.5, Paint()..color = Colors.white);

    // Eyebrows (Masculine thicker, Female groomed)
    final browPaint = Paint()
      ..color = profile.hairColor
      ..strokeWidth = isMale ? 3.4 : 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(eyeL.dx - 6, eyeL.dy - 11), Offset(eyeL.dx + 6, eyeL.dy - 10), browPaint);
    canvas.drawLine(Offset(eyeR.dx - 6, eyeR.dy - 10), Offset(eyeR.dx + 6, eyeR.dy - 11), browPaint);

    // Stubble / Facial Hair if Male
    if (isMale && profile.facialHair != 'clean') {
      final stubblePaint = Paint()
        ..color = profile.hairColor.withValues(alpha: 0.45)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final stubblePath = Path()
        ..moveTo(head.dx - 18, head.dy + 12)
        ..quadraticBezierTo(head.dx, head.dy + 26, head.dx + 18, head.dy + 12);
      canvas.drawPath(stubblePath, stubblePaint);
    }

    // Cute nose button
    canvas.drawCircle(Offset(head.dx + (eyeShiftX * 0.3), head.dy + 7), 2.2, Paint()..color = skinColors[2]);

    // Friendly Pixar Smile
    final smilePath = Path()
      ..moveTo(head.dx - 8 + (eyeShiftX * 0.3), head.dy + 15)
      ..quadraticBezierTo(head.dx + (eyeShiftX * 0.3), head.dy + 22, head.dx + 10 + (eyeShiftX * 0.3), head.dy + 16);
    canvas.drawPath(
      smilePath,
      Paint()
        ..color = const Color(0xFF9E4747)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _StudioAvatar3DPainter oldDelegate) {
    return oldDelegate.rotationAngle != rotationAngle ||
        oldDelegate.idleProgress != idleProgress ||
        oldDelegate.profile != profile;
  }
}
