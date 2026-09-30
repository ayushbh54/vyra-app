import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/avatar_customization_service.dart';
import '../theme.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// FREE FIRE-STYLE AVATAR STUDIO — PREMIUM ATHLETIC CHARACTER SYSTEM
///
/// CustomPainter-driven full-body avatar with:
///   • 5 sport poses: Running, Boxing, Yoga, Cycling, Weightlifting
///   • 3 body types: Athletic, Muscular, Lean
///   • 6 hair styles, 8 skin tones, outfit color pickers
///   • Accessory toggles: Headband, Wristband, Sunglasses
///   • Idle breathing + pose transition animations
/// ─────────────────────────────────────────────────────────────────────────────
class AvatarStudioScreen extends StatefulWidget {
  const AvatarStudioScreen({super.key});

  @override
  State<AvatarStudioScreen> createState() => _AvatarStudioScreenState();
}

class _AvatarStudioScreenState extends State<AvatarStudioScreen>
    with TickerProviderStateMixin {
  late AvatarFaceProfile _profile;
  double _rotationAngle = 0.0;
  bool _isAutoTurntable = true;
  String _activeTab = 'body';
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;
  bool _isAnalyzingPhoto = false;

  // ── Primary / Secondary outfit color pickers ──
  Color _outfitPrimary = VColor.accent;
  Color _outfitSecondary = const Color(0xFF142438);

  // ── Animations ──
  late AnimationController _idleAnimCtrl;
  late AnimationController _poseTransitionCtrl;
  late Animation<double> _poseTransition;
  String _previousPose = 'running';

  @override
  void initState() {
    super.initState();
    _profile = AvatarCustomizationService.instance.profile;
    _previousPose = _profile.sportPose;
    _syncOutfitColors(_profile.outfitStyle);

    _idleAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..addListener(() {
        if (mounted && _isAutoTurntable) {
          setState(() {
            _rotationAngle += 0.008;
            if (_rotationAngle > math.pi * 2) {
              _rotationAngle -= math.pi * 2;
            }
          });
        }
      })
      ..repeat();

    _poseTransitionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _poseTransition = CurvedAnimation(
      parent: _poseTransitionCtrl,
      curve: Curves.easeOutBack,
    );
    _poseTransitionCtrl.value = 1.0;
  }

  @override
  void dispose() {
    _idleAnimCtrl.dispose();
    _poseTransitionCtrl.dispose();
    super.dispose();
  }

  void _syncOutfitColors(String style) {
    switch (style) {
      case 'hoodie_white':
        _outfitPrimary = const Color(0xFFE8EEF5);
        _outfitSecondary = const Color(0xFFCAD5E2);
        break;
      case 'runner_stealth':
        _outfitPrimary = const Color(0xFF1E2838);
        _outfitSecondary = const Color(0xFF0F172A);
        break;
      case 'sunset_orange':
        _outfitPrimary = const Color(0xFFFF6B6B);
        _outfitSecondary = const Color(0xFFFF9F4A);
        break;
      case 'athletic_teal':
      default:
        _outfitPrimary = VColor.accent;
        _outfitSecondary = const Color(0xFF142438);
    }
  }

  void _updateProfile(AvatarFaceProfile newProfile) {
    final oldPose = _profile.sportPose;
    setState(() {
      _profile = newProfile;
    });
    AvatarCustomizationService.instance.updateProfile(newProfile);

    // Trigger pose transition animation when sport changes
    if (oldPose != newProfile.sportPose) {
      _previousPose = oldPose;
      _poseTransitionCtrl.forward(from: 0.0);
    }
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
        final updated = await AvatarCustomizationService.instance
            .scanAndExtractFromPhoto(xfile.path);
        if (!mounted) return;
        setState(() {
          _profile = updated;
          _isAnalyzingPhoto = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: VColor.surface,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: VColor.accentGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Matched tone to selfie! Tone: ${_profile.skinTone.toUpperCase()}',
                    style: const TextStyle(
                        color: VColor.text, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        if (!mounted) return;
        setState(() => _isAnalyzingPhoto = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAnalyzingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to match selfie: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VColor.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ──
            _buildTopBar(),

            // ── Avatar Viewport ──
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
                    // Studio ambient background
                    Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.3),
                          radius: 0.9,
                          colors: const [
                            VColor.surface,
                            VColor.bg,
                            VColor.bgLift,
                          ],
                        ),
                      ),
                    ),

                    // Animated grid lines for cyberpunk feel
                    CustomPaint(
                      size: const Size(double.infinity, double.infinity),
                      painter: _CyberGridPainter(
                        progress: _idleAnimCtrl.value,
                      ),
                    ),

                    // The Avatar
                    AnimatedBuilder(
                      animation: _poseTransition,
                      builder: (context, child) {
                        return RepaintBoundary(
                          child: CustomPaint(
                            size:
                                const Size(double.infinity, double.infinity),
                            painter: _FreeFireAvatarPainter(
                              rotationAngle: _rotationAngle,
                              idleProgress: _idleAnimCtrl.value,
                              profile: _profile,
                              poseTransition: _poseTransition.value,
                              previousPose: _previousPose,
                              outfitPrimary: _outfitPrimary,
                              outfitSecondary: _outfitSecondary,
                            ),
                          ),
                        );
                      },
                    ),

                    // Sport badge
                    Positioned(
                      top: 12,
                      left: 16,
                      child: _buildSportBadge(),
                    ),

                    // Angle presets
                    Positioned(
                      top: 12,
                      right: 16,
                      child: Column(
                        children: [
                          _buildAnglePresetPill('F', 0.0),
                          const SizedBox(height: 6),
                          _buildAnglePresetPill('S', math.pi / 2),
                          const SizedBox(height: 6),
                          _buildAnglePresetPill('B', math.pi),
                        ],
                      ),
                    ),

                    // Drag hint
                    Positioned(
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.swipe_rounded,
                                color: VColor.accent, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'Swipe to rotate • Tap angles to snap',
                              style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Customization Panel ──
            Expanded(
              flex: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: VColor.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  border: const Border(
                    top: BorderSide(color: VColor.line, width: 1.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: VColor.accent.withValues(alpha: 0.06),
                      blurRadius: 30,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Tab bar
                    _buildTabBar(),
                    Container(height: 1, color: VColor.lineSoft),

                    // Tab content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _buildTabContent(),
                      ),
                    ),

                    // Save button
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────── TOP BAR ───────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: VColor.surfaceRaised,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: VColor.line),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: VColor.text, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AVATAR STUDIO',
                  style: TextStyle(
                    color: VColor.accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 2.0,
                  ),
                ),
                Text(
                  'Customize your athlete identity',
                  style: TextStyle(color: VColor.textLow, fontSize: 11),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() => _isAutoTurntable = !_isAutoTurntable);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isAutoTurntable
                    ? VColor.accent.withValues(alpha: 0.15)
                    : VColor.surfaceRaised,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isAutoTurntable ? VColor.accent : VColor.line,
                ),
              ),
              child: Icon(
                _isAutoTurntable
                    ? Icons.threed_rotation
                    : Icons.pan_tool_rounded,
                color:
                    _isAutoTurntable ? VColor.accent : VColor.textLow,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────── SPORT BADGE ───────────────
  Widget _buildSportBadge() {
    final sportData = _getSportData(_profile.sportPose);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            sportData['color'] as Color,
            (sportData['color'] as Color).withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (sportData['color'] as Color).withValues(alpha: 0.4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(sportData['icon'] as IconData, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            (sportData['name'] as String).toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getSportData(String sport) {
    switch (sport) {
      case 'boxing':
        return {
          'name': 'Boxing',
          'icon': Icons.sports_mma_rounded,
          'color': const Color(0xFFFF4136)
        };
      case 'yoga':
        return {
          'name': 'Yoga',
          'icon': Icons.self_improvement_rounded,
          'color': const Color(0xFF9B59B6)
        };
      case 'cycling':
        return {
          'name': 'Cycling',
          'icon': Icons.directions_bike_rounded,
          'color': VColor.accentGreen
        };
      case 'weightlifting':
        return {
          'name': 'Weights',
          'icon': Icons.fitness_center_rounded,
          'color': VColor.accentOrange
        };
      case 'running':
      default:
        return {
          'name': 'Running',
          'icon': Icons.directions_run_rounded,
          'color': VColor.accent
        };
    }
  }

  // ─────────────── ANGLE PRESETS ───────────────
  Widget _buildAnglePresetPill(String label, double rad) {
    final isActive = (_rotationAngle - rad).abs() < 0.2;
    return GestureDetector(
      onTap: () {
        setState(() {
          _isAutoTurntable = false;
          _rotationAngle = rad;
        });
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isActive
              ? VColor.accent.withValues(alpha: 0.25)
              : Colors.black.withValues(alpha: 0.6),
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? VColor.accent : Colors.white24,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? VColor.accent : Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────── TAB BAR ───────────────
  Widget _buildTabBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _buildTabButton('body', 'Body', Icons.accessibility_new_rounded),
          _buildTabButton('outfit', 'Outfit', Icons.checkroom_rounded),
          _buildTabButton('hair', 'Hair', Icons.content_cut_rounded),
          _buildTabButton('skin', 'Skin', Icons.palette_rounded),
          _buildTabButton('accessories', 'Gear', Icons.diamond_rounded),
        ],
      ),
    );
  }

  Widget _buildTabButton(String tabId, String label, IconData icon) {
    final isActive = _activeTab == tabId;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = tabId),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(
                    colors: [VColor.accent, VColor.accentDeep],
                  )
                : null,
            color: isActive ? null : VColor.surfaceRaised,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? Colors.transparent : VColor.line,
              width: 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                        color: VColor.accent.withValues(alpha: 0.3),
                        blurRadius: 8)
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 14,
                  color: isActive ? Colors.white : VColor.textLow),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : VColor.textLow,
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

  // ─────────────── TAB CONTENT ───────────────
  Widget _buildTabContent() {
    switch (_activeTab) {
      case 'body':
        return _buildBodyTab();
      case 'outfit':
        return _buildOutfitTab();
      case 'hair':
        return _buildHairTab();
      case 'skin':
        return _buildSkinTab();
      case 'accessories':
        return _buildAccessoriesTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // ─────────────── BODY TAB ───────────────
  Widget _buildBodyTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sport Pose — now 5 options
        _buildSectionTitle('SPORT POSE', Icons.sports_score_rounded),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildSportCard('running', 'Runner',
                Icons.directions_run_rounded, VColor.accent),
            const SizedBox(width: 6),
            _buildSportCard('boxing', 'Boxing',
                Icons.sports_mma_rounded, const Color(0xFFFF4136)),
            const SizedBox(width: 6),
            _buildSportCard('yoga', 'Yoga',
                Icons.self_improvement_rounded, const Color(0xFF9B59B6)),
            const SizedBox(width: 6),
            _buildSportCard('cycling', 'Cycling',
                Icons.directions_bike_rounded, VColor.accentGreen),
            const SizedBox(width: 6),
            _buildSportCard('weightlifting', 'Weights',
                Icons.fitness_center_rounded, VColor.accentOrange),
          ],
        ),

        const SizedBox(height: 20),

        // Body Type — 3 options
        _buildSectionTitle('BODY TYPE', Icons.fitness_center_rounded),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildBodyTypeCard('athletic', 'Athletic', 'Balanced & fit'),
            const SizedBox(width: 10),
            _buildBodyTypeCard('muscular', 'Muscular', 'Broad & strong'),
            const SizedBox(width: 10),
            _buildBodyTypeCard('lean', 'Lean', 'Slim & agile'),
          ],
        ),

        const SizedBox(height: 20),

        // Gender
        _buildSectionTitle('AVATAR IDENTITY', Icons.person_rounded),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child:
                  _buildGenderCard('female', 'Female', Icons.female_rounded),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildGenderCard('male', 'Male', Icons.male_rounded),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSportCard(
      String id, String label, IconData icon, Color color) {
    final isSelected = _profile.sportPose == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => _updateProfile(_profile.copyWith(sportPose: id)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color.withValues(alpha: 0.3),
                      color.withValues(alpha: 0.08)
                    ],
                  )
                : null,
            color: isSelected ? null : VColor.surfaceRaised,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : VColor.line,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: color.withValues(alpha: 0.3), blurRadius: 10)
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected ? color : VColor.textLow, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? VColor.text : VColor.textLow,
                  fontWeight: FontWeight.w700,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBodyTypeCard(String id, String title, String subtitle) {
    final isSelected = _profile.bodyType == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => _updateProfile(_profile.copyWith(bodyType: id)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? VColor.accent.withValues(alpha: 0.12)
                : VColor.surfaceRaised,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? VColor.accent : VColor.line,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? VColor.accent.withValues(alpha: 0.2)
                      : VColor.surfaceHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  id == 'muscular'
                      ? Icons.fitness_center_rounded
                      : id == 'lean'
                          ? Icons.air_rounded
                          : Icons.accessibility_new_rounded,
                  color: isSelected ? VColor.accent : VColor.textLow,
                  size: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? VColor.text : VColor.textLow,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style:
                    const TextStyle(color: VColor.textLow, fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenderCard(String id, String label, IconData icon) {
    final isSelected = _profile.avatarGender == id;
    return GestureDetector(
      onTap: () {
        _updateProfile(_profile.copyWith(
          avatarGender: id,
          hairStyle: id == 'male' ? 'short_crop' : 'long_tied',
        ));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [VColor.accent, VColor.accentDeep],
                )
              : null,
          color: isSelected ? null : VColor.surfaceRaised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.transparent : VColor.line,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isSelected ? Colors.white : VColor.textLow,
                size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : VColor.textLow,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────── OUTFIT TAB ───────────────
  Widget _buildOutfitTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('OUTFIT STYLE', Icons.checkroom_rounded),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildOutfitCard(
                'athletic_teal',
                'Pro Teal',
                'Performance gear',
                VColor.accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildOutfitCard(
                'hoodie_white',
                'Arctic White',
                'Heather hoodie',
                const Color(0xFFE8EEF5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildOutfitCard(
                'runner_stealth',
                'Stealth Carbon',
                'Compression fit',
                const Color(0xFF829AB1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildOutfitCard(
                'sunset_orange',
                'Sunset Fire',
                'High-energy gear',
                const Color(0xFFFF6B6B),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Primary color picker
        _buildSectionTitle('PRIMARY COLOR', Icons.color_lens_rounded),
        const SizedBox(height: 10),
        _buildOutfitColorPicker(isPrimary: true),

        const SizedBox(height: 16),

        // Secondary color picker
        _buildSectionTitle('SECONDARY COLOR', Icons.format_paint_rounded),
        const SizedBox(height: 10),
        _buildOutfitColorPicker(isPrimary: false),

        const SizedBox(height: 20),

        _buildSectionTitle('SHOE COLOR', Icons.snowshoeing_rounded),
        const SizedBox(height: 10),
        _buildColorRow(
          items: [
            {
              'id': 'orange',
              'name': 'Heat',
              'color': VColor.accentOrangeSoft
            },
            {'id': 'cyan', 'name': 'Cyber', 'color': VColor.accent},
            {'id': 'white', 'name': 'Pure', 'color': Colors.white},
            {
              'id': 'stealth',
              'name': 'Onyx',
              'color': VColor.surfaceHigh
            },
          ],
          selectedId: _profile.shoeColor,
          onSelect: (id) =>
              _updateProfile(_profile.copyWith(shoeColor: id)),
        ),
      ],
    );
  }

  Widget _buildOutfitColorPicker({required bool isPrimary}) {
    final colors = <Color>[
      VColor.accent,
      VColor.accentGreen,
      VColor.accentOrange,
      const Color(0xFFFF4136),
      const Color(0xFF9B59B6),
      const Color(0xFFE8EEF5),
      const Color(0xFF142438),
      const Color(0xFF1E2838),
    ];
    final current = isPrimary ? _outfitPrimary : _outfitSecondary;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: colors.map((c) {
        final isSelected = (current.toARGB32() - c.toARGB32()).abs() < 5;
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isPrimary) {
                _outfitPrimary = c;
              } else {
                _outfitSecondary = c;
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? VColor.accent : VColor.line,
                width: isSelected ? 3 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color: VColor.accent.withValues(alpha: 0.5),
                          blurRadius: 8)
                    ]
                  : null,
            ),
            child: isSelected
                ? Icon(Icons.check,
                    color: c.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                    size: 18)
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOutfitCard(
      String id, String title, String subtitle, Color accentColor) {
    final isSelected = _profile.outfitStyle == id;
    return GestureDetector(
      onTap: () {
        _syncOutfitColors(id);
        _updateProfile(_profile.copyWith(outfitStyle: id));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accentColor.withValues(alpha: 0.2),
                    accentColor.withValues(alpha: 0.05)
                  ],
                )
              : null,
          color: isSelected ? null : VColor.surfaceRaised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accentColor : VColor.line,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: accentColor.withValues(alpha: 0.25),
                      blurRadius: 10)
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.checkroom_rounded,
                  color: accentColor, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: VColor.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: VColor.textLow, fontSize: 10)),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.check, color: Colors.white, size: 12),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────── HAIR TAB ───────────────
  Widget _buildHairTab() {
    final hairStyles = [
      {'id': 'short_crop', 'name': 'Short Crop', 'icon': Icons.face_rounded},
      {'id': 'buzz_cut', 'name': 'Buzz Cut', 'icon': Icons.circle},
      {'id': 'long_tied', 'name': 'Long Tied', 'icon': Icons.face_3_rounded},
      {
        'id': 'mohawk',
        'name': 'Mohawk',
        'icon': Icons.trending_up_rounded
      },
      {'id': 'braided', 'name': 'Braided', 'icon': Icons.waves_rounded},
      {
        'id': 'bald',
        'name': 'Bald',
        'icon': Icons.panorama_fish_eye_rounded
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('HAIRSTYLE', Icons.content_cut_rounded),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.3,
          children: hairStyles.map((h) {
            final isSelected = _profile.hairStyle == h['id'];
            return GestureDetector(
              onTap: () => _updateProfile(
                  _profile.copyWith(hairStyle: h['id'] as String)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            VColor.accent.withValues(alpha: 0.2),
                            VColor.accent.withValues(alpha: 0.05),
                          ],
                        )
                      : null,
                  color: isSelected ? null : VColor.surfaceRaised,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? VColor.accent : VColor.line,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      h['icon'] as IconData,
                      color: isSelected ? VColor.accent : VColor.textLow,
                      size: 22,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      h['name'] as String,
                      style: TextStyle(
                        color:
                            isSelected ? VColor.text : VColor.textLow,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        // Hair Color
        _buildSectionTitle('HAIR COLOR', Icons.color_lens_rounded),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildHairColorDot(const Color(0xFF151515), 'Jet Black'),
            _buildHairColorDot(const Color(0xFF3E2312), 'Chestnut'),
            _buildHairColorDot(const Color(0xFF8B4513), 'Auburn'),
            _buildHairColorDot(const Color(0xFFDAA520), 'Golden'),
            _buildHairColorDot(const Color(0xFFC0392B), 'Flame Red'),
            _buildHairColorDot(const Color(0xFF7F8C8D), 'Silver'),
          ],
        ),
      ],
    );
  }

  Widget _buildHairColorDot(Color color, String name) {
    final isSelected =
        (_profile.hairColor.toARGB32() - color.toARGB32()).abs() < 5;
    return GestureDetector(
      onTap: () => _updateProfile(_profile.copyWith(hairColor: color)),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? VColor.accent : Colors.transparent,
                width: 3,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color: VColor.accent.withValues(alpha: 0.5),
                          blurRadius: 8)
                    ]
                  : null,
            ),
            child: isSelected
                ? Icon(Icons.check,
                    color: color.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                    size: 18)
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: TextStyle(
              color: isSelected ? VColor.accent : VColor.textLow,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────── SKIN TAB ───────────────
  Widget _buildSkinTab() {
    // 8 diverse tones
    final tones = [
      {
        'id': 'porcelain',
        'name': 'Porcelain',
        'color': const Color(0xFFFFE4D0)
      },
      {
        'id': 'fair',
        'name': 'Fair Ivory',
        'color': const Color(0xFFF7D5BA)
      },
      {
        'id': 'light',
        'name': 'Light Sand',
        'color': const Color(0xFFEFC4A1)
      },
      {
        'id': 'wheatish',
        'name': 'Wheatish',
        'color': const Color(0xFFE4AE84)
      },
      {
        'id': 'tan',
        'name': 'Warm Tan',
        'color': const Color(0xFFC78A5B)
      },
      {
        'id': 'brown',
        'name': 'Rich Brown',
        'color': const Color(0xFFA06A3E)
      },
      {
        'id': 'dusky',
        'name': 'Deep Dusky',
        'color': const Color(0xFF87522E)
      },
      {
        'id': 'ebony',
        'name': 'Ebony',
        'color': const Color(0xFF5C3A1E)
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI Selfie Scanner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                VColor.accent.withValues(alpha: 0.12),
                VColor.accentGreen.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: VColor.accent.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      color: VColor.accent, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'AI Tone Match',
                    style: TextStyle(
                        color: VColor.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Upload a selfie to instantly match your skin tone',
                style: TextStyle(color: VColor.textLow, fontSize: 10),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildMiniButton(
                      'Selfie',
                      Icons.camera_alt_rounded,
                      VColor.accent,
                      _isAnalyzingPhoto
                          ? null
                          : () => _pickFacePhoto(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniButton(
                      'Gallery',
                      Icons.photo_library_rounded,
                      VColor.accentGreen,
                      _isAnalyzingPhoto
                          ? null
                          : () => _pickFacePhoto(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        _buildSectionTitle('SKIN TONE', Icons.palette_rounded),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.85,
          children: tones.map((t) {
            final isSelected = _profile.skinTone == t['id'];
            return GestureDetector(
              onTap: () => _updateProfile(
                  _profile.copyWith(skinTone: t['id'] as String)),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: t['color'] as Color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? VColor.accent
                            : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                  color:
                                      VColor.accent.withValues(alpha: 0.5),
                                  blurRadius: 10)
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 20)
                        : null,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    t['name'] as String,
                    style: TextStyle(
                      color:
                          isSelected ? VColor.accent : VColor.textLow,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─────────────── ACCESSORIES TAB ───────────────
  Widget _buildAccessoriesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('HEADWEAR', Icons.sports_baseball_rounded),
        const SizedBox(height: 10),
        _buildAccessoryRow([
          {'id': 'none', 'name': 'None', 'icon': Icons.block_rounded},
          {
            'id': 'snapback_black',
            'name': 'Athletic Cap',
            'icon': Icons.sports_baseball_rounded
          },
          {
            'id': 'visor_neon',
            'name': 'Neon Visor',
            'icon': Icons.sports_tennis_rounded
          },
          {
            'id': 'beanie_gray',
            'name': 'Beanie',
            'icon': Icons.ac_unit_rounded
          },
        ], _profile.capStyle,
            (id) => _updateProfile(_profile.copyWith(capStyle: id))),

        const SizedBox(height: 18),

        _buildSectionTitle('WRIST GEAR', Icons.watch_rounded),
        const SizedBox(height: 10),
        _buildAccessoryRow([
          {'id': 'none', 'name': 'None', 'icon': Icons.block_rounded},
          {
            'id': 'vyra_smartwatch_cyan',
            'name': 'VYRA Watch',
            'icon': Icons.watch_rounded
          },
          {
            'id': 'sport_band_orange',
            'name': 'Sport Band',
            'icon': Icons.fitbit_rounded
          },
          {
            'id': 'gold_chrono',
            'name': 'Gold Chrono',
            'icon': Icons.timer_rounded
          },
        ], _profile.watchStyle,
            (id) => _updateProfile(_profile.copyWith(watchStyle: id))),

        const SizedBox(height: 18),

        // Toggle-style accessories: Headband, Wristband, Sunglasses
        _buildSectionTitle('ACCESSORIES', Icons.diamond_rounded),
        const SizedBox(height: 10),
        _buildAccessoryRow([
          {'id': 'none', 'name': 'None', 'icon': Icons.block_rounded},
          {
            'id': 'sweatband_red',
            'name': 'Headband',
            'icon': Icons.sports_gymnastics_rounded
          },
          {
            'id': 'headphones_silver',
            'name': 'Wristband',
            'icon': Icons.headphones_rounded
          },
          {
            'id': 'sunglasses_stealth',
            'name': 'Sunglasses',
            'icon': Icons.remove_red_eye_rounded
          },
        ], _profile.accessoryStyle,
            (id) => _updateProfile(_profile.copyWith(accessoryStyle: id))),
      ],
    );
  }

  Widget _buildAccessoryRow(
    List<Map<String, dynamic>> items,
    String selectedId,
    ValueChanged<String> onSelect,
  ) {
    return Row(
      children: items.map((item) {
        final isSelected = selectedId == item['id'];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => onSelect(item['id'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            VColor.accent.withValues(alpha: 0.2),
                            VColor.accent.withValues(alpha: 0.05),
                          ],
                        )
                      : null,
                  color: isSelected ? null : VColor.surfaceRaised,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? VColor.accent : VColor.line,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      item['icon'] as IconData,
                      color:
                          isSelected ? VColor.accent : VColor.textLow,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['name'] as String,
                      style: TextStyle(
                        color: isSelected
                            ? VColor.text
                            : VColor.textLow,
                        fontWeight: FontWeight.w700,
                        fontSize: 9,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─────────────── SHARED BUILDERS ───────────────
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: VColor.accent, size: 14),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            color: VColor.textLow,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniButton(
      String label, IconData icon, Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorRow({
    required List<Map<String, dynamic>> items,
    required String selectedId,
    required ValueChanged<String> onSelect,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) {
        final isSelected = selectedId == item['id'];
        return GestureDetector(
          onTap: () => onSelect(item['id'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? (item['color'] as Color).withValues(alpha: 0.2)
                  : VColor.surfaceRaised,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? (item['color'] as Color)
                    : VColor.line,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: item['color'] as Color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  item['name'] as String,
                  style: TextStyle(
                    color: isSelected ? VColor.text : VColor.textLow,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─────────────── SAVE BUTTON ───────────────
  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [VColor.accent, VColor.accentGreen],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: VColor.accent.withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _isSaving
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      setState(() => _isSaving = true);
                      await AvatarCustomizationService.instance
                          .updateProfile(_profile);
                      await Future.delayed(
                          const Duration(milliseconds: 300));
                      if (!mounted) return;
                      setState(() => _isSaving = false);
                      messenger.showSnackBar(
                        SnackBar(
                          backgroundColor: VColor.surface,
                          content: const Row(
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  color: VColor.accentGreen, size: 20),
                              SizedBox(width: 10),
                              Text(
                                'Avatar Saved Successfully!',
                                style: TextStyle(
                                    color: VColor.text,
                                    fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      );
                    },
              child: Center(
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save_rounded,
                              color: VColor.textOnAccent, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'SAVE AVATAR',
                            style: TextStyle(
                              color: VColor.textOnAccent,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// CYBERPUNK GRID BACKGROUND PAINTER
/// ─────────────────────────────────────────────────────────────────────────────
class _CyberGridPainter extends CustomPainter {
  _CyberGridPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = VColor.accent.withValues(alpha: 0.04)
      ..strokeWidth = 0.5;

    // Horizontal grid lines
    for (double y = size.height * 0.5; y < size.height; y += 30) {
      final alpha =
          0.04 * (1 - (y - size.height * 0.5) / (size.height * 0.5));
      linePaint.color =
          VColor.accent.withValues(alpha: alpha.clamp(0.01, 0.06));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Vertical grid lines converging to center
    final cx = size.width / 2;
    for (double x = -size.width; x < size.width * 2; x += 40) {
      final topX = cx + (x - cx) * 0.3;
      linePaint.color = VColor.accent.withValues(alpha: 0.025);
      canvas.drawLine(
          Offset(topX, size.height * 0.5), Offset(x, size.height), linePaint);
    }

    // Animated pulse ring on podium area
    final pulseRadius = 100 + math.sin(progress * math.pi * 2) * 20;
    canvas.drawCircle(
      Offset(cx, size.height * 0.85),
      pulseRadius,
      Paint()
        ..color = VColor.accent.withValues(alpha: 0.03)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _CyberGridPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// ─────────────────────────────────────────────────────────────────────────────
/// FREE FIRE-STYLE ATHLETIC AVATAR PAINTER
/// Full-body athletic character with sport-specific poses, body types,
/// hair styles, accessories, and dynamic outfit rendering.
/// Poses: Running, Boxing, Yoga, Cycling, Weightlifting
/// ─────────────────────────────────────────────────────────────────────────────
class _FreeFireAvatarPainter extends CustomPainter {
  _FreeFireAvatarPainter({
    required this.rotationAngle,
    required this.idleProgress,
    required this.profile,
    required this.poseTransition,
    required this.previousPose,
    required this.outfitPrimary,
    required this.outfitSecondary,
  });

  final double rotationAngle;
  final double idleProgress;
  final AvatarFaceProfile profile;
  final double poseTransition;
  final String previousPose;
  final Color outfitPrimary;
  final Color outfitSecondary;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.48;

    // Idle breathing animation — subtle scale pulse
    final breathe = math.sin(idleProgress * math.pi * 2) * 3.0;
    final breatheScale = 1.0 + math.sin(idleProgress * math.pi * 2) * 0.008;

    // Rotation
    final cosRot = math.cos(rotationAngle);
    final sinRot = math.sin(rotationAngle);

    // Body type multipliers
    double shoulderMult = 1.0;
    double armWidth = 1.0;
    double torsoWidth = 1.0;
    double legWidth = 1.0;

    switch (profile.bodyType) {
      case 'muscular':
        shoulderMult = 1.2;
        armWidth = 1.3;
        torsoWidth = 1.15;
        legWidth = 1.2;
        break;
      case 'lean':
        shoulderMult = 0.88;
        armWidth = 0.85;
        torsoWidth = 0.88;
        legWidth = 0.9;
        break;
    }

    final isMale = profile.avatarGender == 'male';

    // Save canvas for scale transformation (breathing)
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(breatheScale, breatheScale);
    canvas.translate(-cx, -cy);

    // ── 1. PODIUM ──
    _drawPodium(canvas, cx, size.height * 0.88, size);

    // ── 2. SHADOW ──
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, size.height * 0.87),
        width: 150,
        height: 28,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // ── 3. GET POSE LANDMARKS ──
    final pose = _calculatePoseLandmarks(
      cx,
      cy,
      breathe,
      cosRot,
      sinRot,
      isMale,
      shoulderMult,
      profile.sportPose,
    );

    // ── 4. OUTFIT COLORS ──
    final outfit = _getOutfitColors(profile.outfitStyle);
    final skinColors = profile.skinGradientColors;

    // ── 5. DRAW BODY ──

    // Legs
    final legPaint = Paint()
      ..color = outfit['pants']!
      ..strokeWidth = (isMale ? 26 : 22) * legWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(pose['pelvis']!, pose['kneeL']!, legPaint);
    canvas.drawLine(pose['kneeL']!, pose['footL']!, legPaint);
    canvas.drawLine(pose['pelvis']!, pose['kneeR']!, legPaint);
    canvas.drawLine(pose['kneeR']!, pose['footR']!, legPaint);

    // Knee detail
    final kneeHighlight = Paint()
      ..color = outfit['pants']!.withValues(alpha: 0.6)
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(pose['kneeL']!.dx - 4, pose['kneeL']!.dy),
      Offset(pose['kneeL']!.dx + 4, pose['kneeL']!.dy),
      kneeHighlight,
    );
    canvas.drawLine(
      Offset(pose['kneeR']!.dx - 4, pose['kneeR']!.dy),
      Offset(pose['kneeR']!.dx + 4, pose['kneeR']!.dy),
      kneeHighlight,
    );

    // Shoes
    Color shoeColor = VColor.accentOrangeSoft;
    if (profile.shoeColor == 'cyan') shoeColor = VColor.accent;
    if (profile.shoeColor == 'white') shoeColor = Colors.white;
    if (profile.shoeColor == 'stealth') shoeColor = VColor.surfaceHigh;

    final shoePaint = Paint()..color = shoeColor;
    final shoeW = isMale ? 34.0 : 28.0;
    final shoeH = isMale ? 18.0 : 14.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: pose['footL']!, width: shoeW, height: shoeH),
        const Radius.circular(8),
      ),
      shoePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: pose['footR']!, width: shoeW, height: shoeH),
        const Radius.circular(8),
      ),
      shoePaint,
    );
    // Shoe sole
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center:
              Offset(pose['footL']!.dx, pose['footL']!.dy + shoeH * 0.35),
          width: shoeW * 0.9,
          height: 4,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.4),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center:
              Offset(pose['footR']!.dx, pose['footR']!.dy + shoeH * 0.35),
          width: shoeW * 0.9,
          height: 4,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.4),
    );

    // Torso
    final waistWidth =
        (isMale ? 22.0 : 18.0) * torsoWidth * cosRot.abs().clamp(0.3, 1.0);
    final torsoPath = Path()
      ..moveTo(pose['shoulderL']!.dx, pose['shoulderL']!.dy)
      ..lineTo(pose['shoulderR']!.dx, pose['shoulderR']!.dy)
      ..lineTo(pose['pelvis']!.dx + waistWidth, pose['pelvis']!.dy)
      ..lineTo(pose['pelvis']!.dx - waistWidth, pose['pelvis']!.dy)
      ..close();

    // Torso gradient — uses outfit color pickers
    final topGrad = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [outfit['topPrimary']!, outfit['topSecondary']!],
    );
    canvas.drawPath(
      torsoPath,
      Paint()
        ..shader = topGrad.createShader(
          Rect.fromLTRB(
            pose['shoulderL']!.dx,
            pose['shoulderL']!.dy,
            pose['shoulderR']!.dx,
            pose['pelvis']!.dy,
          ),
        ),
    );

    // Collar detail
    canvas.drawLine(
      Offset(
          pose['shoulderL']!.dx * 0.65 + pose['shoulderR']!.dx * 0.35,
          pose['shoulderL']!.dy),
      Offset(
          pose['shoulderL']!.dx * 0.35 + pose['shoulderR']!.dx * 0.65,
          pose['shoulderR']!.dy),
      Paint()
        ..color = outfit['topPrimary']!.withValues(alpha: 0.6)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Sport-specific accent stripe on torso
    if (profile.sportPose == 'running' || profile.sportPose == 'cycling') {
      final stripePaint = Paint()
        ..color = VColor.accent.withValues(alpha: 0.35)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      final midY = (pose['shoulderL']!.dy + pose['pelvis']!.dy) / 2;
      canvas.drawLine(
        Offset(pose['shoulderL']!.dx * 0.8 + cx * 0.2, midY - 10),
        Offset(pose['shoulderL']!.dx * 0.8 + cx * 0.2, midY + 10),
        stripePaint,
      );
    }

    // Belt
    final beltRect = Rect.fromCenter(
      center: pose['pelvis']!,
      width: (isMale ? 50 : 44) *
              torsoWidth *
              cosRot.abs().clamp(0.4, 1.0) +
          10,
      height: 8,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(beltRect, const Radius.circular(4)),
      Paint()..color = outfit['belt']!,
    );
    // Belt buckle
    canvas.drawCircle(
        pose['pelvis']!, 5, Paint()..color = Colors.white.withValues(alpha: 0.8));

    // Arms
    final armPaint = Paint()
      ..strokeWidth = (isMale ? 18 : 14) * armWidth
      ..strokeCap = StrokeCap.round;

    // Left arm (forearm is skin tone for short sleeves)
    armPaint.color = outfit['topSecondary']!;
    canvas.drawLine(pose['shoulderL']!, pose['elbowL']!, armPaint);
    armPaint.color = skinColors[1];
    armPaint.strokeWidth = (isMale ? 16 : 12) * armWidth;
    canvas.drawLine(pose['elbowL']!, pose['handL']!, armPaint);

    // Right arm
    armPaint.color = outfit['topSecondary']!;
    armPaint.strokeWidth = (isMale ? 18 : 14) * armWidth;
    canvas.drawLine(pose['shoulderR']!, pose['elbowR']!, armPaint);
    armPaint.color = skinColors[1];
    armPaint.strokeWidth = (isMale ? 16 : 12) * armWidth;
    canvas.drawLine(pose['elbowR']!, pose['handR']!, armPaint);

    // Hands (skin-colored fists)
    canvas.drawCircle(
      pose['handL']!,
      (isMale ? 8 : 7) * armWidth,
      Paint()..color = skinColors[0],
    );
    canvas.drawCircle(
      pose['handR']!,
      (isMale ? 8 : 7) * armWidth,
      Paint()..color = skinColors[0],
    );

    // Weightlifting barbell
    if (profile.sportPose == 'weightlifting') {
      _drawBarbell(canvas, pose, isMale);
    }

    // Smartwatch
    if (profile.watchStyle != 'none') {
      Color watchColor = VColor.accent;
      if (profile.watchStyle == 'sport_band_orange') {
        watchColor = VColor.accentOrangeSoft;
      }
      if (profile.watchStyle == 'gold_chrono') {
        watchColor = const Color(0xFFFFD700);
      }

      final wrist = Offset(
        (pose['elbowL']!.dx + pose['handL']!.dx) / 2,
        (pose['elbowL']!.dy + pose['handL']!.dy) / 2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: wrist, width: 14, height: 12),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFF1A1A2E),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: wrist, width: 10, height: 8),
          const Radius.circular(2),
        ),
        Paint()..color = watchColor,
      );
    }

    // ── 6. NECK ──
    final neck = pose['neck']!;
    canvas.drawRect(
      Rect.fromCenter(center: neck, width: 16, height: 22),
      Paint()..color = skinColors[1],
    );

    // ── 7. HEADPHONES ──
    if (profile.accessoryStyle == 'headphones_silver') {
      final hpPaint = Paint()
        ..color = VColor.text
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke;
      canvas.drawArc(
        Rect.fromCenter(
            center: Offset(neck.dx, neck.dy - 24), width: 50, height: 30),
        math.pi * 0.8,
        math.pi * 0.4,
        false,
        hpPaint,
      );
      canvas.drawCircle(
        Offset(neck.dx - 24, neck.dy - 10),
        7,
        Paint()..color = VColor.accent,
      );
      canvas.drawCircle(
        Offset(neck.dx + 24, neck.dy - 10),
        7,
        Paint()..color = VColor.accent,
      );
    }

    // ── 8. HEAD & FACE ──
    final head = pose['head']!;
    _drawHead(canvas, head, cosRot, sinRot, skinColors, isMale);

    canvas.restore();
  }

  // ── BARBELL for Weightlifting pose ──
  void _drawBarbell(
      Canvas canvas, Map<String, Offset> pose, bool isMale) {
    final handL = pose['handL']!;
    final handR = pose['handR']!;
    final barPaint = Paint()
      ..color = const Color(0xFFBEC3CC)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    // Bar connecting hands
    canvas.drawLine(
      Offset(handL.dx - 20, handL.dy),
      Offset(handR.dx + 20, handR.dy),
      barPaint,
    );

    // Weight plates — left
    final platePaint = Paint()..color = VColor.accent;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(handL.dx - 24, handL.dy), width: 10, height: 28),
        const Radius.circular(3),
      ),
      platePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(handL.dx - 36, handL.dy), width: 8, height: 22),
        const Radius.circular(2),
      ),
      Paint()..color = VColor.accentOrange,
    );

    // Weight plates — right
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(handR.dx + 24, handR.dy), width: 10, height: 28),
        const Radius.circular(3),
      ),
      platePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(handR.dx + 36, handR.dy), width: 8, height: 22),
        const Radius.circular(2),
      ),
      Paint()..color = VColor.accentOrange,
    );
  }

  // ── POSE CALCULATOR ──
  Map<String, Offset> _calculatePoseLandmarks(
    double cx,
    double cy,
    double breathe,
    double cosRot,
    double sinRot,
    bool isMale,
    double shoulderMult,
    String sport,
  ) {
    // Default standing pose values
    double footLX = cx - 24 * cosRot;
    double footLY = cy + 145;
    double footRX = cx + 24 * cosRot;
    double footRY = cy + 145;
    double kneeLX = cx - 20 * cosRot;
    double kneeLY = cy + 95;
    double kneeRX = cx + 20 * cosRot;
    double kneeRY = cy + 95;
    double pelvisX = cx;
    double pelvisY = cy + 30 - (breathe * 0.2);

    final shoulderSpan = (isMale ? 48.0 : 38.0) * shoulderMult;
    double sLX = cx - shoulderSpan * cosRot;
    double sLY = cy - 50 - breathe;
    double sRX = cx + shoulderSpan * cosRot;
    double sRY = cy - 50 - breathe;

    double eLX = cx - (isMale ? 58 : 52) * cosRot - (sinRot * 10);
    double eLY = cy - 10 - breathe;
    double eRX = cx + (isMale ? 58 : 52) * cosRot + (sinRot * 10);
    double eRY = cy - 10 - breathe;
    double hLX = cx - (isMale ? 26 : 22) * cosRot;
    double hLY = cy + 30 - breathe;
    double hRX = cx + (isMale ? 26 : 22) * cosRot;
    double hRY = cy + 30 - breathe;

    // Apply sport-specific pose modifications
    switch (sport) {
      case 'running':
        // Dynamic running stride
        final runCycle = math.sin(idleProgress * math.pi * 4) * 0.5 + 0.5;
        footLX = cx - 35 * cosRot;
        footLY = cy + 140 - runCycle * 15;
        footRX = cx + 30 * cosRot;
        footRY = cy + 145 + runCycle * 5;
        kneeLX = cx - 25 * cosRot;
        kneeLY = cy + 90 - runCycle * 8;
        kneeRX = cx + 18 * cosRot;
        kneeRY = cy + 95;
        // Arms pumping
        eLX = cx - 55 * cosRot;
        eLY = cy - 20 - breathe - runCycle * 10;
        eRX = cx + 50 * cosRot;
        eRY = cy + 5 - breathe + runCycle * 10;
        hLX = cx - 30 * cosRot;
        hLY = cy - 5 - breathe;
        hRX = cx + 20 * cosRot;
        hRY = cy + 20 - breathe;
        break;

      case 'boxing':
        // Boxing guard stance
        footLX = cx - 30 * cosRot;
        footRX = cx + 20 * cosRot;
        kneeLX = cx - 22 * cosRot;
        kneeLY = cy + 88;
        kneeRX = cx + 16 * cosRot;
        kneeRY = cy + 90;
        // Guard position - fists up
        eLX = cx - 40 * cosRot;
        eLY = cy - 45 - breathe;
        eRX = cx + 35 * cosRot;
        eRY = cy - 40 - breathe;
        hLX = cx - 20 * cosRot;
        hLY = cy - 55 - breathe;
        hRX = cx + 18 * cosRot;
        hRY = cy - 50 - breathe;
        break;

      case 'yoga':
        // Tree pose (Vrksasana)
        footLX = cx;
        footLY = cy + 145;
        footRX = cx - 10 * cosRot;
        footRY = cy + 80;
        kneeLX = cx;
        kneeLY = cy + 95;
        kneeRX = cx + 25 * cosRot;
        kneeRY = cy + 80;
        // Arms above head (namaste)
        eLX = cx - 20 * cosRot;
        eLY = cy - 75 - breathe;
        eRX = cx + 20 * cosRot;
        eRY = cy - 75 - breathe;
        hLX = cx - 5;
        hLY = cy - 100 - breathe;
        hRX = cx + 5;
        hRY = cy - 100 - breathe;
        pelvisY = cy + 30;
        break;

      case 'cycling':
        // Leaning forward cycling position
        pelvisY = cy + 40;
        sLY = cy - 35 - breathe;
        sRY = cy - 35 - breathe;
        footLX = cx - 30 * cosRot;
        footLY = cy + 140;
        footRX = cx + 30 * cosRot;
        footRY = cy + 120;
        kneeLX = cx - 25 * cosRot;
        kneeLY = cy + 95;
        kneeRX = cx + 20 * cosRot;
        kneeRY = cy + 85;
        // Hands on handlebars
        eLX = cx - 45 * cosRot;
        eLY = cy - 15 - breathe;
        eRX = cx + 45 * cosRot;
        eRY = cy - 15 - breathe;
        hLX = cx - 35 * cosRot;
        hLY = cy + 5 - breathe;
        hRX = cx + 35 * cosRot;
        hRY = cy + 5 - breathe;
        break;

      case 'weightlifting':
        // Overhead press / power clean finish
        footLX = cx - 28 * cosRot;
        footLY = cy + 145;
        footRX = cx + 28 * cosRot;
        footRY = cy + 145;
        kneeLX = cx - 24 * cosRot;
        kneeLY = cy + 90;
        kneeRX = cx + 24 * cosRot;
        kneeRY = cy + 90;
        pelvisY = cy + 28;
        // Wider stance shoulders
        sLX = cx - shoulderSpan * 1.05 * cosRot;
        sRX = cx + shoulderSpan * 1.05 * cosRot;
        // Arms up — barbell overhead press
        eLX = cx - 52 * cosRot;
        eLY = cy - 70 - breathe;
        eRX = cx + 52 * cosRot;
        eRY = cy - 70 - breathe;
        hLX = cx - 45 * cosRot;
        hLY = cy - 95 - breathe;
        hRX = cx + 45 * cosRot;
        hRY = cy - 95 - breathe;
        break;
    }

    final neckY = sLY - 15;

    return {
      'footL': Offset(footLX, footLY),
      'footR': Offset(footRX, footRY),
      'kneeL': Offset(kneeLX, kneeLY),
      'kneeR': Offset(kneeRX, kneeRY),
      'pelvis': Offset(pelvisX, pelvisY),
      'shoulderL': Offset(sLX, sLY),
      'shoulderR': Offset(sRX, sRY),
      'elbowL': Offset(eLX, eLY),
      'elbowR': Offset(eRX, eRY),
      'handL': Offset(hLX, hLY),
      'handR': Offset(hRX, hRY),
      'neck': Offset(cx, neckY),
      'head': Offset(cx, neckY - 42),
    };
  }

  Map<String, Color> _getOutfitColors(String style) {
    // Always mix in the user's custom primary/secondary picks
    switch (style) {
      case 'hoodie_white':
        return {
          'topPrimary': outfitPrimary,
          'topSecondary': outfitSecondary,
          'pants': const Color(0xFF3E4C5E),
          'belt': VColor.accentOrange,
        };
      case 'runner_stealth':
        return {
          'topPrimary': outfitPrimary,
          'topSecondary': outfitSecondary,
          'pants': VColor.surfaceRaised,
          'belt': VColor.accent,
        };
      case 'sunset_orange':
        return {
          'topPrimary': outfitPrimary,
          'topSecondary': outfitSecondary,
          'pants': const Color(0xFF2B2D42),
          'belt': const Color(0xFFFFE66D),
        };
      case 'athletic_teal':
      default:
        return {
          'topPrimary': outfitPrimary,
          'topSecondary': outfitSecondary,
          'pants': const Color(0xFF334E68),
          'belt': VColor.accentOrangeSoft,
        };
    }
  }

  // ── PODIUM ──
  void _drawPodium(Canvas canvas, double cx, double cy, Size size) {
    // Outer glow ring
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 6), width: 280, height: 55),
      Paint()
        ..color = VColor.accent.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Platform fill
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 240, height: 46),
      Paint()
        ..color = VColor.bgLift
        ..style = PaintingStyle.fill,
    );

    // Main ring
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 240, height: 46),
      Paint()
        ..color = VColor.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3),
    );

    // Inner ring
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - 2), width: 190, height: 36),
      Paint()
        ..color = VColor.accentGreen.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Hexagonal pattern dots on platform
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi * 2 / 6) * i;
      final dotX = cx + math.cos(angle) * 60;
      final dotY = cy + math.sin(angle) * 12;
      canvas.drawCircle(
        Offset(dotX, dotY),
        2,
        Paint()..color = VColor.accent.withValues(alpha: 0.3),
      );
    }
  }

  // ── HEAD & FACE ──
  void _drawHead(
    Canvas canvas,
    Offset head,
    double cosRot,
    double sinRot,
    List<Color> skinColors,
    bool isMale,
  ) {
    const headRadius = 34.0;

    // Skin gradient
    final skinGrad = RadialGradient(
      center: Alignment(0.2 * cosRot, -0.3),
      radius: 0.85,
      colors: skinColors,
    );
    canvas.drawCircle(
      head,
      headRadius,
      Paint()
        ..shader = skinGrad.createShader(
            Rect.fromCircle(center: head, radius: headRadius)),
    );

    // Ear highlights
    canvas.drawCircle(
      Offset(head.dx - headRadius * cosRot * 0.95, head.dy + 2),
      6,
      Paint()..color = skinColors[1],
    );
    canvas.drawCircle(
      Offset(head.dx + headRadius * cosRot * 0.95, head.dy + 2),
      6,
      Paint()..color = skinColors[1],
    );

    // HAIR
    final hairPaint = Paint()..color = profile.hairColor;
    _drawHairStyle(canvas, head, hairPaint, isMale);

    // CAPS / HEADWEAR
    if (profile.capStyle != 'none') {
      Color capColor = VColor.surfaceHigh;
      if (profile.capStyle == 'visor_neon') capColor = VColor.accent;
      if (profile.capStyle == 'beanie_gray') capColor = VColor.textLow;

      final capPath = Path()
        ..moveTo(head.dx - 36, head.dy - 16)
        ..quadraticBezierTo(head.dx, head.dy - 50, head.dx + 36, head.dy - 16)
        ..close();
      canvas.drawPath(capPath, Paint()..color = capColor);

      if (profile.capStyle == 'snapback_black' ||
          profile.capStyle == 'visor_neon') {
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(head.dx, head.dy - 16), width: 60, height: 12),
          Paint()..color = capColor,
        );
      }
    }

    // SWEATBAND / HEADBAND
    if (profile.accessoryStyle == 'sweatband_red') {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(head.dx, head.dy - 20), width: 62, height: 8),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFFFF4136),
      );
      // Knot detail
      canvas.drawCircle(
        Offset(head.dx + 30, head.dy - 20),
        4,
        Paint()..color = const Color(0xFFCC3333),
      );
    }

    // EYES
    final eyeShiftX = 10 * cosRot;
    final eyeL = Offset(head.dx - 12 + (eyeShiftX * 0.4), head.dy - 4);
    final eyeR = Offset(head.dx + 12 + (eyeShiftX * 0.4), head.dy - 4);

    if (profile.accessoryStyle == 'sunglasses_stealth') {
      // Sunglasses
      final shadesPaint = Paint()..color = const Color(0xFF101622);
      final framePaint = Paint()
        ..color = const Color(0xFF3A3A4A)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: eyeL, width: 24, height: 16),
          const Radius.circular(6),
        ),
        shadesPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: eyeR, width: 24, height: 16),
          const Radius.circular(6),
        ),
        shadesPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: eyeL, width: 24, height: 16),
          const Radius.circular(6),
        ),
        framePaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: eyeR, width: 24, height: 16),
          const Radius.circular(6),
        ),
        framePaint,
      );
      canvas.drawLine(
        Offset(eyeL.dx + 12, eyeL.dy),
        Offset(eyeR.dx - 12, eyeR.dy),
        Paint()
          ..color = const Color(0xFF3A3A4A)
          ..strokeWidth = 2,
      );
      // Lens glare
      canvas.drawLine(
        Offset(eyeL.dx - 6, eyeL.dy - 4),
        Offset(eyeL.dx - 2, eyeL.dy - 6),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.3)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    } else {
      // Eye whites
      canvas.drawOval(
        Rect.fromCenter(center: eyeL, width: 14, height: 17),
        Paint()..color = Colors.white,
      );
      canvas.drawOval(
        Rect.fromCenter(center: eyeR, width: 14, height: 17),
        Paint()..color = Colors.white,
      );

      // Irises
      canvas.drawCircle(eyeL, 6, Paint()..color = const Color(0xFF5C3317));
      canvas.drawCircle(eyeR, 6, Paint()..color = const Color(0xFF5C3317));

      // Pupils
      canvas.drawCircle(eyeL, 3.5, Paint()..color = Colors.black);
      canvas.drawCircle(eyeR, 3.5, Paint()..color = Colors.black);

      // Catchlights
      canvas.drawCircle(
        Offset(eyeL.dx - 1.5, eyeL.dy - 2),
        1.8,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        Offset(eyeR.dx - 1.5, eyeR.dy - 2),
        1.8,
        Paint()..color = Colors.white,
      );
    }

    // Eyebrows
    final browPaint = Paint()
      ..color = profile.hairColor
      ..strokeWidth = isMale ? 3.5 : 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(eyeL.dx - 7, eyeL.dy - 12),
      Offset(eyeL.dx + 7, eyeL.dy - 11),
      browPaint,
    );
    canvas.drawLine(
      Offset(eyeR.dx - 7, eyeR.dy - 11),
      Offset(eyeR.dx + 7, eyeR.dy - 12),
      browPaint,
    );

    // Stubble / facial hair
    if (isMale && profile.facialHair != 'clean') {
      final stubblePaint = Paint()
        ..color = profile.hairColor.withValues(alpha: 0.45)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final stubblePath = Path()
        ..moveTo(head.dx - 18, head.dy + 12)
        ..quadraticBezierTo(head.dx, head.dy + 28, head.dx + 18, head.dy + 12);
      canvas.drawPath(stubblePath, stubblePaint);
    }

    // Nose
    canvas.drawCircle(
      Offset(head.dx + (eyeShiftX * 0.3), head.dy + 8),
      2.5,
      Paint()..color = skinColors[2],
    );

    // Confident smile
    final smilePath = Path()
      ..moveTo(head.dx - 9 + (eyeShiftX * 0.3), head.dy + 17)
      ..quadraticBezierTo(
        head.dx + (eyeShiftX * 0.3),
        head.dy + 24,
        head.dx + 11 + (eyeShiftX * 0.3),
        head.dy + 18,
      );
    canvas.drawPath(
      smilePath,
      Paint()
        ..color = const Color(0xFFBB4444)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  // ── HAIR STYLES ──
  void _drawHairStyle(
      Canvas canvas, Offset head, Paint hairPaint, bool isMale) {
    switch (profile.hairStyle) {
      case 'short_crop':
        // Clean short top
        final topHair = Path()
          ..moveTo(head.dx - 32, head.dy - 10)
          ..quadraticBezierTo(
              head.dx, head.dy - 46, head.dx + 32, head.dy - 10)
          ..quadraticBezierTo(
              head.dx, head.dy - 24, head.dx - 32, head.dy - 10)
          ..close();
        canvas.drawPath(topHair, hairPaint);
        // Sideburns
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(head.dx - 31, head.dy - 2),
                width: 6,
                height: 18),
            const Radius.circular(3),
          ),
          hairPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(head.dx + 31, head.dy - 2),
                width: 6,
                height: 18),
            const Radius.circular(3),
          ),
          hairPaint,
        );
        break;

      case 'buzz_cut':
        // Very short all-over
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(head.dx, head.dy - 8), width: 66, height: 56),
          math.pi,
          math.pi,
          true,
          hairPaint..color = profile.hairColor.withValues(alpha: 0.7),
        );
        hairPaint.color = profile.hairColor;
        break;

      case 'long_tied':
        // Long hair tied back (ponytail)
        // Volume on sides
        canvas.drawCircle(
            Offset(head.dx - 28, head.dy - 8), 18, hairPaint);
        canvas.drawCircle(
            Offset(head.dx + 28, head.dy - 8), 18, hairPaint);
        canvas.drawCircle(
            Offset(head.dx - 30, head.dy + 10), 16, hairPaint);
        canvas.drawCircle(
            Offset(head.dx + 30, head.dy + 10), 16, hairPaint);
        // Top arch
        final topHair = Path()
          ..moveTo(head.dx - 34, head.dy - 12)
          ..quadraticBezierTo(
              head.dx, head.dy - 50, head.dx + 34, head.dy - 12)
          ..quadraticBezierTo(
              head.dx, head.dy - 22, head.dx - 34, head.dy - 12)
          ..close();
        canvas.drawPath(topHair, hairPaint);
        // Ponytail
        final tailPath = Path()
          ..moveTo(head.dx - 5, head.dy + 24)
          ..quadraticBezierTo(
              head.dx + 15, head.dy + 55, head.dx + 5, head.dy + 70);
        canvas.drawPath(
          tailPath,
          Paint()
            ..color = profile.hairColor
            ..strokeWidth = 12
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
        // Hair tie
        canvas.drawCircle(
          Offset(head.dx, head.dy + 28),
          4,
          Paint()..color = VColor.accent,
        );
        break;

      case 'mohawk':
        // Shaved sides + tall center strip
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(head.dx, head.dy - 8), width: 66, height: 56),
          math.pi,
          math.pi,
          true,
          Paint()..color = profile.hairColor.withValues(alpha: 0.3),
        );
        // Mohawk strip
        final mohawkPath = Path()
          ..moveTo(head.dx - 8, head.dy + 10)
          ..quadraticBezierTo(
              head.dx - 6, head.dy - 55, head.dx, head.dy - 55)
          ..quadraticBezierTo(
              head.dx + 6, head.dy - 55, head.dx + 8, head.dy + 10)
          ..close();
        canvas.drawPath(mohawkPath, hairPaint);
        break;

      case 'braided':
        // Braids from top going down sides
        final topHair = Path()
          ..moveTo(head.dx - 32, head.dy - 8)
          ..quadraticBezierTo(
              head.dx, head.dy - 48, head.dx + 32, head.dy - 8)
          ..quadraticBezierTo(
              head.dx, head.dy - 20, head.dx - 32, head.dy - 8)
          ..close();
        canvas.drawPath(topHair, hairPaint);
        // Left braid
        for (int i = 0; i < 5; i++) {
          final y = head.dy + i * 12;
          canvas.drawCircle(
            Offset(head.dx - 32 + math.sin(i * 0.8) * 3, y),
            5,
            hairPaint,
          );
        }
        // Right braid
        for (int i = 0; i < 5; i++) {
          final y = head.dy + i * 12;
          canvas.drawCircle(
            Offset(head.dx + 32 + math.sin(i * 0.8) * 3, y),
            5,
            hairPaint,
          );
        }
        break;

      case 'bald':
        // Just a very subtle hair shadow on top
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(head.dx, head.dy - 10), width: 62, height: 50),
          math.pi,
          math.pi,
          false,
          Paint()
            ..color = profile.hairColor.withValues(alpha: 0.15)
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke,
        );
        break;

      default:
        // Fallback wavy/default
        if (!isMale) {
          canvas.drawCircle(
              Offset(head.dx - 26, head.dy - 10), 18, hairPaint);
          canvas.drawCircle(
              Offset(head.dx + 26, head.dy - 10), 18, hairPaint);
          canvas.drawCircle(
              Offset(head.dx - 28, head.dy + 12), 16, hairPaint);
          canvas.drawCircle(
              Offset(head.dx + 28, head.dy + 12), 16, hairPaint);
          final topHair = Path()
            ..moveTo(head.dx - 32, head.dy - 12)
            ..quadraticBezierTo(
                head.dx, head.dy - 48, head.dx + 32, head.dy - 12)
            ..quadraticBezierTo(
                head.dx, head.dy - 20, head.dx - 32, head.dy - 12)
            ..close();
          canvas.drawPath(topHair, hairPaint);
        } else {
          final maleTopHair = Path()
            ..moveTo(head.dx - 32, head.dy - 8)
            ..quadraticBezierTo(
                head.dx, head.dy - 44, head.dx + 32, head.dy - 8)
            ..quadraticBezierTo(
                head.dx, head.dy - 22, head.dx - 32, head.dy - 8)
            ..close();
          canvas.drawPath(maleTopHair, hairPaint);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(head.dx - 30, head.dy - 2),
                  width: 6,
                  height: 22),
              const Radius.circular(3),
            ),
            hairPaint,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(head.dx + 30, head.dy - 2),
                  width: 6,
                  height: 22),
              const Radius.circular(3),
            ),
            hairPaint,
          );
        }
    }
  }

  @override
  bool shouldRepaint(covariant _FreeFireAvatarPainter oldDelegate) {
    return oldDelegate.rotationAngle != rotationAngle ||
        oldDelegate.idleProgress != idleProgress ||
        oldDelegate.profile != profile ||
        oldDelegate.poseTransition != poseTransition ||
        oldDelegate.outfitPrimary != outfitPrimary ||
        oldDelegate.outfitSecondary != outfitSecondary;
  }
}
