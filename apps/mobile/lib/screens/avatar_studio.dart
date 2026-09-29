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
  bool _isAutoTurntable = true;
  String _activeTab = 'outfits'; // 'outfits', 'shoes', 'caps', 'watches', 'accessories', 'face_tone'
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;
  bool _isAnalyzingPhoto = false;

  late AnimationController _idleAnimCtrl;

  @override
  void initState() {
    super.initState();
    _profile = AvatarCustomizationService.instance.profile;
    _idleAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..addListener(() {
        if (_isAutoTurntable) {
          setState(() {
            _rotationAngle += 0.008;
            if (_rotationAngle > math.pi * 2) {
              _rotationAngle -= math.pi * 2;
            }
          });
        }
      })
      ..repeat();
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
      setState(() => _isAnalyzingPhoto = true);
      final xfile = await _picker.pickImage(
        source: source,
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 88,
      );
      if (xfile != null) {
        final updated = await AvatarCustomizationService.instance.scanAndExtractFromPhoto(xfile.path);
        if (mounted) {
          setState(() {
            _profile = updated;
            _isAnalyzingPhoto = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF102A43),
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF34FF8C)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Matched tone to selfie! Tone: ${_profile.skinTone.toUpperCase()}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else {
        if (mounted) setState(() => _isAnalyzingPhoto = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to match selfie: $e')),
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
          GestureDetector(
            onTap: () {
              setState(() {
                _isAutoTurntable = !_isAutoTurntable;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _isAutoTurntable
                    ? const Color(0xFF00D2FF).withValues(alpha: 0.15)
                    : const Color(0xFF141C2B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isAutoTurntable ? const Color(0xFF00D2FF) : Colors.white24,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sync_rounded,
                    color: _isAutoTurntable ? const Color(0xFF00D2FF) : Colors.white54,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isAutoTurntable ? 'TURNTABLE' : 'MANUAL',
                    style: TextStyle(
                      color: _isAutoTurntable ? const Color(0xFF00D2FF) : Colors.white54,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── TOP 3D AVATAR VIEWPORT (Only 3D avatar in turntable motion, no photo clutter) ──
            Expanded(
              flex: 5,
              child: GestureDetector(
                onHorizontalDragStart: (_) {
                  setState(() => _isAutoTurntable = false);
                },
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _rotationAngle += details.primaryDelta! * 0.02;
                  });
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Studio Ambient Background with Subtle Podium Glow
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

                    // 3D Procedural Vector Stylized Avatar in smooth motion
                    RepaintBoundary(
                      child: CustomPaint(
                        size: const Size(double.infinity, double.infinity),
                        painter: _StudioAvatar3DPainter(
                          rotationAngle: _rotationAngle,
                          idleProgress: _idleAnimCtrl.value,
                          profile: _profile,
                        ),
                      ),
                    ),

                    // Quick Angle Preset Chips
                    Positioned(
                      top: 10,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildAnglePresetPill('Front', 0.0),
                          const SizedBox(width: 8),
                          _buildAnglePresetPill('Side', math.pi / 2),
                          const SizedBox(width: 8),
                          _buildAnglePresetPill('Back', math.pi),
                        ],
                      ),
                    ),

                    // Interactive touch drag prompt
                    Positioned(
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
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
                  ],
                ),
              ),
            ),

            // ── BOTTOM SNAPCHAT-STYLE CUSTOMIZATION CONTROLS PANEL ──
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
                    // Tab Bar: Outfits, Shoes, Caps, Watches, Accessories, Face & Tone
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          _buildTabButton('outfits', 'Outfits', Icons.checkroom_rounded),
                          _buildTabButton('shoes', 'Shoes', Icons.sports_kabaddi_rounded),
                          _buildTabButton('caps', 'Caps & Hats', Icons.sports_score_rounded),
                          _buildTabButton('watches', 'Watches', Icons.watch_rounded),
                          _buildTabButton('accessories', 'Accessories', Icons.headphones_rounded),
                          _buildTabButton('face_tone', 'Tone & Hair', Icons.face_retouching_natural_rounded),
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
                                  final messenger = ScaffoldMessenger.of(context);
                                  setState(() => _isSaving = true);
                                  await AvatarCustomizationService.instance.updateProfile(_profile);
                                  await Future.delayed(const Duration(milliseconds: 300));
                                  if (!mounted) return;
                                  setState(() => _isSaving = false);
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      backgroundColor: Color(0xFF00D2FF),
                                      content: Text(
                                        '3D Avatar Customized & Saved Successfully!',
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
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                                )
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

  Widget _buildAnglePresetPill(String label, double rad) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isAutoTurntable = false;
          _rotationAngle = rad;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700),
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
      case 'shoes':
        return _buildShoesSelector();
      case 'caps':
        return _buildCapsSelector();
      case 'watches':
        return _buildWatchesSelector();
      case 'accessories':
        return _buildAccessoriesSelector();
      case 'face_tone':
        return _buildFaceToneAndHair();
      default:
        return const SizedBox.shrink();
    }
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
        Row(
          children: [
            Expanded(
              child: _buildOutfitCard(
                'hoodie_white',
                'White Heather Hoodie',
                'Pro Hoodie, Orange Belt & Dark Chinos',
                const Color(0xFFFF9F4A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOutfitCard(
                'athletic_teal',
                'Electric Teal Gym Set',
                'Teal Performance Top + Tights',
                const Color(0xFF00D2FF),
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
                'Matte Carbon Stealth',
                'Carbon Fitted Compression Tracksuit',
                const Color(0xFF829AB1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOutfitCard(
                'sunset_orange',
                'Sunset High-Energy',
                'Coral Amber Performance Gear',
                const Color(0xFFFF6B6B),
              ),
            ),
          ],
        ),
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

  Widget _buildShoesSelector() {
    final shoes = [
      {'id': 'orange', 'name': 'Heat Orange', 'color': const Color(0xFFFF9F4A)},
      {'id': 'cyan', 'name': 'Cyber Cyan', 'color': const Color(0xFF00D2FF)},
      {'id': 'white', 'name': 'Pure White', 'color': Colors.white},
      {'id': 'stealth', 'name': 'Onyx Stealth', 'color': const Color(0xFF243B53)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Athletic Sneakers',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 14, height: 14, decoration: BoxDecoration(color: s['color'] as Color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(
                      s['name'] as String,
                      style: TextStyle(color: Colors.white, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, fontSize: 12),
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

  Widget _buildCapsSelector() {
    final caps = [
      {'id': 'none', 'name': 'No Headwear', 'icon': Icons.block_rounded},
      {'id': 'snapback_black', 'name': 'Athletic Cap', 'icon': Icons.sports_baseball_rounded},
      {'id': 'visor_neon', 'name': 'Neon Visor', 'icon': Icons.sports_tennis_rounded},
      {'id': 'beanie_gray', 'name': 'Urban Beanie', 'icon': Icons.ac_unit_rounded},
      {'id': 'backward_cap', 'name': 'Backward Cap', 'icon': Icons.skateboarding_rounded},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Caps & Headwear',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: caps.map((c) {
            final isSelected = _profile.capStyle == c['id'];
            return ChoiceChip(
              avatar: Icon(c['icon'] as IconData, size: 16, color: isSelected ? Colors.black : const Color(0xFF00D2FF)),
              label: Text(c['name'] as String),
              selected: isSelected,
              onSelected: (val) {
                if (val) _updateProfile(_profile.copyWith(capStyle: c['id'] as String));
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

  Widget _buildWatchesSelector() {
    final watches = [
      {'id': 'none', 'name': 'None', 'color': Colors.transparent},
      {'id': 'vyra_smartwatch_cyan', 'name': 'VYRA Cyber Watch', 'color': const Color(0xFF00D2FF)},
      {'id': 'sport_band_orange', 'name': 'Neon Sport Band', 'color': const Color(0xFFFF9F4A)},
      {'id': 'gold_chrono', 'name': 'Gold Chrono Pro', 'color': const Color(0xFFFFD700)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Smartwatches & Bands',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: watches.map((w) {
            final isSelected = _profile.watchStyle == w['id'];
            return ChoiceChip(
              label: Text(w['name'] as String),
              selected: isSelected,
              onSelected: (val) {
                if (val) _updateProfile(_profile.copyWith(watchStyle: w['id'] as String));
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

  Widget _buildAccessoriesSelector() {
    final items = [
      {'id': 'none', 'name': 'None', 'icon': Icons.block_rounded},
      {'id': 'headphones_silver', 'name': 'Pro Wireless Headphones', 'icon': Icons.headphones_rounded},
      {'id': 'sweatband_red', 'name': 'Athletic Head Sweatband', 'icon': Icons.sports_gymnastics_rounded},
      {'id': 'sunglasses_stealth', 'name': 'Stealth Sport Shades', 'icon': Icons.remove_red_eye_rounded},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Athletic Accessories',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items.map((item) {
            final isSelected = _profile.accessoryStyle == item['id'];
            return ChoiceChip(
              avatar: Icon(item['icon'] as IconData, size: 16, color: isSelected ? Colors.black : const Color(0xFF00D2FF)),
              label: Text(item['name'] as String),
              selected: isSelected,
              onSelected: (val) {
                if (val) _updateProfile(_profile.copyWith(accessoryStyle: item['id'] as String));
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

  Widget _buildFaceToneAndHair() {
    final tones = [
      {'id': 'fair', 'name': 'Fair Ivory', 'color': const Color(0xFFF7D5BA)},
      {'id': 'wheatish', 'name': 'Wheatish Natural', 'color': const Color(0xFFE4AE84)},
      {'id': 'tan', 'name': 'Warm Tan', 'color': const Color(0xFFC78A5B)},
      {'id': 'dusky', 'name': 'Dusky Deep', 'color': const Color(0xFF87522E)},
    ];

    final isMale = _profile.avatarGender == 'male';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selfie Scan Button to Auto-Resonate Tone & Hair
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF00D2FF).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF00D2FF).withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: Color(0xFF00D2FF), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'AI Selfie Tone Resonance',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Upload a selfie to instantly match skin tone, hair tint, and likeness.',
                style: TextStyle(color: Color(0xFF8896AB), fontSize: 11),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isAnalyzingPhoto ? null : () => _pickFacePhoto(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_rounded, size: 16),
                      label: const Text('Take Selfie'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF00D2FF),
                        side: const BorderSide(color: Color(0xFF00D2FF)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isAnalyzingPhoto ? null : () => _pickFacePhoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_rounded, size: 16),
                      label: const Text('From Gallery'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF34FF8C),
                        side: const BorderSide(color: Color(0xFF34FF8C)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Skin Tone Selector
        const Text(
          'Skin Tone Pigment',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: tones.map((t) {
            final isSelected = _profile.skinTone == t['id'];
            return GestureDetector(
              onTap: () => _updateProfile(_profile.copyWith(skinTone: t['id'] as String)),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
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
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 18),

        // Gender Toggle
        const Text(
          'Silhouette & Gender',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('Female Athlete ♀'),
                selected: !isMale,
                onSelected: (val) {
                  if (val) {
                    _updateProfile(_profile.copyWith(
                      avatarGender: 'female',
                      hairStyle: 'pixar_wavy',
                      outfitStyle: 'athletic_teal',
                    ));
                  }
                },
                selectedColor: const Color(0xFF00D2FF),
                backgroundColor: const Color(0xFF141C2B),
                labelStyle: TextStyle(
                  color: !isMale ? Colors.black : Colors.white,
                  fontWeight: !isMale ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ChoiceChip(
                label: const Text('Male Athlete ♂'),
                selected: isMale,
                onSelected: (val) {
                  if (val) {
                    _updateProfile(_profile.copyWith(
                      avatarGender: 'male',
                      hairStyle: 'crew_fade',
                      outfitStyle: 'hoodie_white',
                    ));
                  }
                },
                selectedColor: const Color(0xFF00D2FF),
                backgroundColor: const Color(0xFF141C2B),
                labelStyle: TextStyle(
                  color: isMale ? Colors.black : Colors.white,
                  fontWeight: isMale ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // Hair Styles
        Text(
          isMale ? 'Male Hair Cuts' : 'Female Hairstyles',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: (isMale
                  ? [
                      {'id': 'crew_fade', 'name': 'Athletic Fade'},
                      {'id': 'short_crop', 'name': 'Textured Crop'},
                      {'id': 'buzz_cut', 'name': 'Military Buzz'},
                    ]
                  : [
                      {'id': 'pixar_wavy', 'name': 'Wavy Curls'},
                      {'id': 'ponytail', 'name': 'Sporty Ponytail'},
                      {'id': 'high_bun', 'name': 'Topknot Bun'},
                    ])
              .map((h) {
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
                fontSize: 11,
              ),
            );
          }).toList(),
        ),
      ],
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
    final breathe = math.sin(idleProgress * math.pi * 2) * 2.5;

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
    final footL = Offset(cx - 24 * cosRot, size.height * 0.80);
    final footR = Offset(cx + 24 * cosRot, size.height * 0.80);

    final kneeL = Offset(cx - 20 * cosRot, cy + 85);
    final kneeR = Offset(cx + 20 * cosRot, cy + 85);

    final isMale = profile.avatarGender == 'male';

    final pelvis = Offset(cx, cy + 25 - (breathe * 0.2));

    final shoulderSpan = isMale ? 48.0 : 38.0;
    final shoulderL = Offset(cx - shoulderSpan * cosRot, cy - (isMale ? 47 : 45) - breathe);
    final shoulderR = Offset(cx + shoulderSpan * cosRot, cy - (isMale ? 47 : 45) - breathe);

    final elbowSpan = isMale ? 58.0 : 52.0;
    final elbowL = Offset(cx - elbowSpan * cosRot - (sinRot * 10), cy - 10 - breathe);
    final elbowR = Offset(cx + elbowSpan * cosRot + (sinRot * 10), cy - 10 - breathe);
    final handL = Offset(cx - (isMale ? 26 : 22) * cosRot, cy + 28 - breathe);
    final handR = Offset(cx + (isMale ? 26 : 22) * cosRot, cy + 28 - breathe);

    final neck = Offset(cx, cy - 65 - breathe);
    final head = Offset(cx, cy - 105 - breathe);

    // Outfit Colors
    Color topPrimary = const Color(0xFF00D2FF);
    Color topSecondary = const Color(0xFF142438);
    Color pantsColor = const Color(0xFF334E68);
    Color beltColor = const Color(0xFFFF9F4A);

    if (profile.outfitStyle == 'hoodie_white') {
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

    // 4. Draw Legs
    final legPaint = Paint()
      ..color = pantsColor
      ..strokeWidth = isMale ? 28 : 24
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(pelvis, kneeL, legPaint);
    canvas.drawLine(kneeL, footL, legPaint);
    canvas.drawLine(pelvis, kneeR, legPaint);
    canvas.drawLine(kneeR, footR, legPaint);

    // 5. Draw Sneakers
    Color shoeColor = const Color(0xFFFF9F4A);
    if (profile.shoeColor == 'cyan') shoeColor = const Color(0xFF00D2FF);
    if (profile.shoeColor == 'white') shoeColor = Colors.white;
    if (profile.shoeColor == 'stealth') shoeColor = const Color(0xFF1E2838);

    final shoePaint = Paint()..color = shoeColor..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: footL, width: isMale ? 32 : 28, height: isMale ? 18 : 16), const Radius.circular(8)),
      shoePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: footR, width: isMale ? 32 : 28, height: isMale ? 18 : 16), const Radius.circular(8)),
      shoePaint,
    );

    // 6. Draw Torso
    final waistWidth = (isMale ? 22.0 : 18.0) * cosRot;
    final torsoPath = Path()
      ..moveTo(shoulderL.dx, shoulderL.dy)
      ..lineTo(shoulderR.dx, shoulderR.dy)
      ..lineTo(pelvis.dx + waistWidth, pelvis.dy)
      ..lineTo(pelvis.dx - waistWidth, pelvis.dy)
      ..close();
    canvas.drawPath(torsoPath, Paint()..color = topPrimary..style = PaintingStyle.fill);

    // Waist Belt
    final beltRect = Rect.fromCenter(center: pelvis, width: (isMale ? 50 : 44) * cosRot.abs() + 10, height: 8);
    canvas.drawRRect(RRect.fromRectAndRadius(beltRect, const Radius.circular(4)), Paint()..color = beltColor);
    canvas.drawCircle(pelvis, 5, Paint()..color = const Color(0xFFDFE2F0));

    // 7. Draw Arms
    final armPaint = Paint()
      ..color = topSecondary
      ..strokeWidth = isMale ? 18 : 14
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(shoulderL, elbowL, armPaint);
    canvas.drawLine(elbowL, handL, armPaint);
    canvas.drawLine(shoulderR, elbowR, armPaint);
    canvas.drawLine(elbowR, handR, armPaint);

    // 7b. Draw Smartwatch if selected
    if (profile.watchStyle != 'none') {
      Color watchColor = const Color(0xFF00D2FF);
      if (profile.watchStyle == 'sport_band_orange') watchColor = const Color(0xFFFF9F4A);
      if (profile.watchStyle == 'gold_chrono') watchColor = const Color(0xFFFFD700);

      final wrist = Offset((elbowL.dx + handL.dx) / 2, (elbowL.dy + handL.dy) / 2);
      canvas.drawCircle(wrist, 6, Paint()..color = Colors.black);
      canvas.drawCircle(wrist, 4, Paint()..color = watchColor);
    }

    // 8. Draw Neck
    final skinColors = profile.skinGradientColors;
    canvas.drawRect(Rect.fromCenter(center: neck, width: 14, height: 18), Paint()..color = skinColors[1]);

    // 8b. Draw Headphones if selected
    if (profile.accessoryStyle == 'headphones_silver') {
      final headphonePaint = Paint()
        ..color = const Color(0xFFDFE2F0)
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke;
      canvas.drawArc(
        Rect.fromCenter(center: neck, width: 44, height: 26),
        0,
        math.pi,
        false,
        headphonePaint,
      );
      canvas.drawCircle(Offset(neck.dx - 20, neck.dy + 8), 7, Paint()..color = const Color(0xFF00D2FF));
      canvas.drawCircle(Offset(neck.dx + 20, neck.dy + 8), 7, Paint()..color = const Color(0xFF00D2FF));
    }

    // 9. Draw Head
    _drawPixarFace(canvas, head, cosRot, sinRot);
  }

  void _drawPodium(Canvas canvas, double cx, double cy) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 6), width: 260, height: 50),
      Paint()
        ..color = const Color(0xFF00D2FF).withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

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

    // Draw Hair
    if (!isMale) {
      canvas.drawCircle(Offset(head.dx - 26, head.dy - 10), 18, hairPaint);
      canvas.drawCircle(Offset(head.dx + 26, head.dy - 10), 18, hairPaint);
      canvas.drawCircle(Offset(head.dx - 28, head.dy + 12), 16, hairPaint);
      canvas.drawCircle(Offset(head.dx + 28, head.dy + 12), 16, hairPaint);

      final topHairPath = Path()
        ..moveTo(head.dx - 32, head.dy - 12)
        ..quadraticBezierTo(head.dx, head.dy - 48, head.dx + 32, head.dy - 12)
        ..quadraticBezierTo(head.dx, head.dy - 20, head.dx - 32, head.dy - 12)
        ..close();
      canvas.drawPath(topHairPath, hairPaint);
    } else {
      final maleTopHair = Path()
        ..moveTo(head.dx - 32, head.dy - 8)
        ..quadraticBezierTo(head.dx, head.dy - 44, head.dx + 32, head.dy - 8)
        ..quadraticBezierTo(head.dx, head.dy - 22, head.dx - 32, head.dy - 8)
        ..close();
      canvas.drawPath(maleTopHair, hairPaint);

      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(head.dx - 30, head.dy - 2), width: 6, height: 22), const Radius.circular(3)),
        hairPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(head.dx + 30, head.dy - 2), width: 6, height: 22), const Radius.circular(3)),
        hairPaint,
      );
    }

    // Caps / Headwear
    if (profile.capStyle != 'none') {
      Color capColor = const Color(0xFF1E2838);
      if (profile.capStyle == 'visor_neon') capColor = const Color(0xFF00D2FF);
      if (profile.capStyle == 'beanie_gray') capColor = const Color(0xFF829AB1);

      final capPath = Path()
        ..moveTo(head.dx - 34, head.dy - 14)
        ..quadraticBezierTo(head.dx, head.dy - 46, head.dx + 34, head.dy - 14)
        ..close();
      canvas.drawPath(capPath, Paint()..color = capColor);

      // Visor brim
      if (profile.capStyle == 'snapback_black' || profile.capStyle == 'visor_neon') {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(head.dx, head.dy - 14), width: 56, height: 10),
          Paint()..color = capColor,
        );
      }
    }

    // Sweatband accessory
    if (profile.accessoryStyle == 'sweatband_red') {
      canvas.drawRect(
        Rect.fromCenter(center: Offset(head.dx, head.dy - 18), width: 58, height: 8),
        Paint()..color = const Color(0xFFFF4136),
      );
    }

    // Eyes
    final eyeShiftX = 10 * cosRot;
    final eyeL = Offset(head.dx - 11 + (eyeShiftX * 0.4), head.dy - 4);
    final eyeR = Offset(head.dx + 11 + (eyeShiftX * 0.4), head.dy - 4);

    if (profile.accessoryStyle == 'sunglasses_stealth') {
      // Draw sunglasses
      final shadesPaint = Paint()..color = const Color(0xFF101622);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: eyeL, width: 22, height: 16), const Radius.circular(6)), shadesPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: eyeR, width: 22, height: 16), const Radius.circular(6)), shadesPaint);
      canvas.drawLine(eyeL, eyeR, Paint()..color = Colors.black..strokeWidth = 3);
    } else {
      // Eye whites
      canvas.drawOval(Rect.fromCenter(center: eyeL, width: 13, height: 16), Paint()..color = Colors.white);
      canvas.drawOval(Rect.fromCenter(center: eyeR, width: 13, height: 16), Paint()..color = Colors.white);

      // Irises
      canvas.drawCircle(eyeL, 5.5, Paint()..color = const Color(0xFF5C3317));
      canvas.drawCircle(eyeR, 5.5, Paint()..color = const Color(0xFF5C3317));

      // Pupils & catchlights
      canvas.drawCircle(eyeL, 3, Paint()..color = Colors.black);
      canvas.drawCircle(eyeR, 3, Paint()..color = Colors.black);
      canvas.drawCircle(Offset(eyeL.dx - 1.5, eyeL.dy - 1.5), 1.5, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(eyeR.dx - 1.5, eyeR.dy - 1.5), 1.5, Paint()..color = Colors.white);
    }

    // Eyebrows
    final browPaint = Paint()
      ..color = profile.hairColor
      ..strokeWidth = isMale ? 3.4 : 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(eyeL.dx - 6, eyeL.dy - 11), Offset(eyeL.dx + 6, eyeL.dy - 10), browPaint);
    canvas.drawLine(Offset(eyeR.dx - 6, eyeR.dy - 10), Offset(eyeR.dx + 6, eyeR.dy - 11), browPaint);

    // Stubble
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

    // Nose button
    canvas.drawCircle(Offset(head.dx + (eyeShiftX * 0.3), head.dy + 7), 2.2, Paint()..color = skinColors[2]);

    // Smile
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
