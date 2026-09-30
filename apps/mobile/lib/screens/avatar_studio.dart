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
        if (!mounted) return;
        if (_isAutoTurntable) {
          setState(() {
            _rotationAngle += 0.008;
            if (_rotationAngle > math.pi * 2) _rotationAngle -= math.pi * 2;
          });
        }
        // Breathing animation rebuild is handled by AnimatedBuilder's Listenable.merge
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
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(0, -0.3),
                          radius: 0.9,
                          colors: [
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
                      animation: Listenable.merge([_poseTransition, _idleAnimCtrl]),
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
        return {'name': 'Boxing', 'icon': Icons.sports_mma_rounded, 'color': const Color(0xFFFF4136)};
      case 'yoga':
        return {'name': 'Yoga', 'icon': Icons.self_improvement_rounded, 'color': const Color(0xFF9B59B6)};
      case 'cycling':
        return {'name': 'Cycling', 'icon': Icons.directions_bike_rounded, 'color': VColor.accentGreen};
      case 'weightlifting':
        return {'name': 'Weights', 'icon': Icons.fitness_center_rounded, 'color': VColor.accentOrange};
      case 'squat':
        return {'name': 'Squat', 'icon': Icons.accessibility_new_rounded, 'color': const Color(0xFFFF6B6B)};
      case 'plank':
        return {'name': 'Plank', 'icon': Icons.horizontal_rule_rounded, 'color': const Color(0xFF2ECC71)};
      case 'pushup':
        return {'name': 'Push-up', 'icon': Icons.arrow_downward_rounded, 'color': const Color(0xFF3498DB)};
      case 'swimming':
        return {'name': 'Swimming', 'icon': Icons.pool_rounded, 'color': const Color(0xFF1ABC9C)};
      case 'dancing':
        return {'name': 'Dance', 'icon': Icons.music_note_rounded, 'color': const Color(0xFFE91E63)};
      case 'football':
        return {'name': 'Football', 'icon': Icons.sports_soccer_rounded, 'color': const Color(0xFF27AE60)};
      case 'cricket':
        return {'name': 'Cricket', 'icon': Icons.sports_cricket_rounded, 'color': const Color(0xFFF39C12)};
      case 'skipping':
        return {'name': 'Skipping', 'icon': Icons.loop_rounded, 'color': const Color(0xFF8E44AD)};
      case 'running':
      default:
        return {'name': 'Running', 'icon': Icons.directions_run_rounded, 'color': VColor.accent};
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
        // Sport Pose — all 13 exercises in scrollable grid
        _buildSectionTitle('SPORT POSE', Icons.sports_score_rounded),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildSportChip('running',      'Run',      Icons.directions_run_rounded,   VColor.accent),
            _buildSportChip('boxing',       'Boxing',   Icons.sports_mma_rounded,        const Color(0xFFFF4136)),
            _buildSportChip('yoga',         'Yoga',     Icons.self_improvement_rounded,  const Color(0xFF9B59B6)),
            _buildSportChip('cycling',      'Cycle',    Icons.directions_bike_rounded,   VColor.accentGreen),
            _buildSportChip('weightlifting','Weights',  Icons.fitness_center_rounded,    VColor.accentOrange),
            _buildSportChip('squat',        'Squat',    Icons.accessibility_new_rounded, const Color(0xFFFF6B6B)),
            _buildSportChip('plank',        'Plank',    Icons.horizontal_rule_rounded,   const Color(0xFF2ECC71)),
            _buildSportChip('pushup',       'Push-up',  Icons.arrow_downward_rounded,    const Color(0xFF3498DB)),
            _buildSportChip('swimming',     'Swim',     Icons.pool_rounded,              const Color(0xFF1ABC9C)),
            _buildSportChip('dancing',      'Dance',    Icons.music_note_rounded,        const Color(0xFFE91E63)),
            _buildSportChip('football',     'Football', Icons.sports_soccer_rounded,     const Color(0xFF27AE60)),
            _buildSportChip('cricket',      'Cricket',  Icons.sports_cricket_rounded,    const Color(0xFFF39C12)),
            _buildSportChip('skipping',     'Skip',     Icons.loop_rounded,              const Color(0xFF8E44AD)),
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


  /// Compact chip for the 13-exercise Wrap grid.
  Widget _buildSportChip(String id, String label, IconData icon, Color color) {
    final isSelected = _profile.sportPose == id;
    return GestureDetector(
      onTap: () => _updateProfile(_profile.copyWith(sportPose: id)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.12)])
              : null,
          color: isSelected ? null : VColor.surfaceRaised,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : VColor.line, width: isSelected ? 2 : 1),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? color : VColor.textLow, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : VColor.textLow,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
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
    final paint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.1)
      ..strokeWidth = 1.0;
    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
    // Also horizontal perspective lines could be drawn, but let's keep it simple.
  }

  @override
  bool shouldRepaint(covariant _CyberGridPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
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

    // 1. Dark gradient background behind character
    final bgGrad = RadialGradient(
      center: Alignment.center,
      radius: 0.8,
      colors: [const Color(0xFF1A1030), const Color(0xFF0A0810)],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = bgGrad.createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Body type multipliers
    double shoulderMult = 1.0;
    if (profile.bodyType == 'muscular') {
      shoulderMult = 1.2;
    } else if (profile.bodyType == 'lean') {
      shoulderMult = 0.88;
    }

    final skinColors = profile.skinGradientColors;

    // 2. Make body positions CORRECT for tall athletic character
    final headR = size.height * 0.072; // head radius
    final headCy = size.height * 0.13; // head center y
    final neckTop = headCy + headR * 0.7;
    final shoulderY = neckTop + headR * 0.7;
    final shoulderWidth = size.width * 0.38 * shoulderMult;
    final elbowY = shoulderY + size.height * 0.15;
    final handY = elbowY + size.height * 0.14;
    final torsoBottomY = shoulderY + size.height * 0.22;
    final hipWidth = size.width * 0.18;
    final kneeY = torsoBottomY + size.height * 0.22;
    final footY = kneeY + size.height * 0.2;
    final leftX = cx - shoulderWidth / 2;
    final rightX = cx + shoulderWidth / 2;
    final leftLegX = cx - hipWidth;
    final rightLegX = cx + hipWidth;
    final leftFootX = cx - hipWidth * 1.3;
    final rightFootX = cx + hipWidth * 1.3;

    // 9. Add overall glow effect
    final auraGlow = Paint()
      ..color = const Color(0xFF00B8D4).withValues(alpha: 0.06 + 0.03 * math.sin(idleProgress * math.pi * 2))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, (shoulderY + torsoBottomY) / 2), width: shoulderWidth * 2.2, height: size.height * 0.55),
      auraGlow);

    // 3. Draw legs FIRST (black tactical pants with cyan accent)
    final pantPaint = Paint()
      ..color = const Color(0xFF0D0D12)
      ..strokeWidth = 38
      ..strokeCap = StrokeCap.round;
    // Left leg
    canvas.drawLine(Offset(leftLegX, torsoBottomY), Offset(leftLegX - 6, kneeY), pantPaint);
    canvas.drawLine(Offset(leftLegX - 6, kneeY), Offset(leftFootX, footY), pantPaint);
    // Right leg
    canvas.drawLine(Offset(rightLegX, torsoBottomY), Offset(rightLegX + 6, kneeY), pantPaint);
    canvas.drawLine(Offset(rightLegX + 6, kneeY), Offset(rightFootX, footY), pantPaint);

    // Cyan accent stripe on right leg
    final cyanStripe = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(rightLegX + 10, torsoBottomY + 10), Offset(rightFootX + 8, kneeY + 20), cyanStripe);
    // Spider-web pattern on left knee area
    _drawSpiderPattern(canvas, Offset(leftLegX - 6, kneeY), 22);

    // 4. Draw shoes
    // Black shoes with cyan accent sole
    final shoePaint = Paint()..color = const Color(0xFF111118);
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(leftFootX - 4, footY + 8), width: 42, height: 20),
      const Radius.circular(8)), shoePaint);
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(rightFootX + 4, footY + 8), width: 42, height: 20),
      const Radius.circular(8)), shoePaint);
    // Cyan accent sole line
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(leftFootX - 4, footY + 16), width: 44, height: 5),
      const Radius.circular(3)),
      Paint()..color = const Color(0xFF00B8D4));
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(rightFootX + 4, footY + 16), width: 44, height: 5),
      const Radius.circular(3)),
      Paint()..color = const Color(0xFF00B8D4));

    // 5. Draw muscular torso (skin tone base + blue electric glow)
    // Torso base — skin tone trapezoid
    final torsoPath = Path()
      ..moveTo(leftX, shoulderY)
      ..lineTo(rightX, shoulderY)
      ..lineTo(cx + hipWidth * 1.1, torsoBottomY)
      ..lineTo(cx - hipWidth * 1.1, torsoBottomY)
      ..close();
    canvas.drawPath(torsoPath,
      Paint()..color = skinColors[0]);

    // Muscle definition lines on abs/chest
    final musclePaint = Paint()
      ..color = skinColors[1].withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    // Abs center line
    canvas.drawLine(Offset(cx, shoulderY + 20), Offset(cx, torsoBottomY - 10), musclePaint);
    // Pec line
    canvas.drawLine(Offset(cx - 18, shoulderY + 25), Offset(cx + 18, shoulderY + 25), musclePaint);
    // Ribs
    for (int i = 1; i <= 3; i++) {
      final ribY = shoulderY + 40 + i * 18.0;
      canvas.drawLine(Offset(cx - 22, ribY), Offset(cx + 22, ribY),
        Paint()..color = skinColors[1].withValues(alpha: 0.25)..strokeWidth = 1.5);
    }

    // === ELECTRIC BLUE LIGHTNING GLOW ON TORSO ===
    _drawLightningGlow(canvas, cx, shoulderY, torsoBottomY, size, idleProgress);

    // 8. Black tactical waistband / belt
    // Belt / waistband
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, torsoBottomY + 5), width: hipWidth * 2.8, height: 14),
      const Radius.circular(5)),
      Paint()..color = const Color(0xFF1A1830));
    // Belt buckle
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, torsoBottomY + 5), width: 18, height: 12),
      Paint()..color = const Color(0xFF2A2850));
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, torsoBottomY + 5), width: 10, height: 6),
      Paint()..color = const Color(0xFF00B8D4).withValues(alpha: 0.7));

    // 6. Draw arms with armored gauntlets
    // Upper arms — skin tone
    final armPaint = Paint()
      ..strokeWidth = 28
      ..strokeCap = StrokeCap.round
      ..color = skinColors[0];
    canvas.drawLine(Offset(leftX, shoulderY), Offset(leftX - 12, elbowY), armPaint);
    canvas.drawLine(Offset(rightX, shoulderY), Offset(rightX + 12, elbowY), armPaint);

    // Forearms — DARK ARMOR GAUNTLETS
    final gauntletPaint = Paint()
      ..strokeWidth = 26
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF1A1A28);
    canvas.drawLine(Offset(leftX - 12, elbowY), Offset(leftX - 18, handY), gauntletPaint);
    canvas.drawLine(Offset(rightX + 12, elbowY), Offset(rightX + 18, handY), gauntletPaint);

    // Gauntlet cyan accent lines
    final gauntletAccent = Paint()..color = const Color(0xFF00E5FF)..strokeWidth = 2;
    canvas.drawLine(Offset(leftX - 10, elbowY + 10), Offset(leftX - 16, handY - 15), gauntletAccent);
    canvas.drawLine(Offset(rightX + 10, elbowY + 10), Offset(rightX + 16, handY - 15), gauntletAccent);

    // Blue glow on upper arms too
    _drawArmLightning(canvas, Offset(leftX, shoulderY), Offset(leftX - 12, elbowY), idleProgress);
    _drawArmLightning(canvas, Offset(rightX, shoulderY), Offset(rightX + 12, elbowY), idleProgress);

    // Hands/fists
    canvas.drawCircle(Offset(leftX - 18, handY), 12, Paint()..color = const Color(0xFF1A1A28));
    canvas.drawCircle(Offset(rightX + 18, handY), 12, Paint()..color = const Color(0xFF1A1A28));

    // 7. Draw head and face
    // Neck
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, neckTop + headR * 0.3), width: 24, height: headR * 1.0),
      const Radius.circular(6)), Paint()..color = skinColors[0]);

    // Head
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, headCy), width: headR * 1.8, height: headR * 2.1),
      Paint()..color = skinColors[0]);

    // === HAIR — Silver/White Spiky ===
    _drawSpikeyHair(canvas, cx, headCy, headR);

    // === DARK SUNGLASSES ===
    _drawSunglasses(canvas, cx, headCy, headR);

    // Jaw shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, headCy + headR * 0.6), width: headR * 1.4, height: headR * 0.6),
      Paint()..color = skinColors[2].withValues(alpha: 0.4));
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


void _drawLightningGlow(Canvas canvas, double cx, double shoulderY, double torsoBottomY, Size size, double progress) {
  final rand = math.Random(42);
  final glowPaint = Paint()
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 1.5
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  
  // Animate lightning using sin waves
  final pulse = math.sin(progress * math.pi * 2);
  final numBolts = 12;
  for (int i = 0; i < numBolts; i++) {
    final startX = cx + (rand.nextDouble() - 0.5) * 70;
    final startY = shoulderY + rand.nextDouble() * (torsoBottomY - shoulderY);
    final endX = startX + (rand.nextDouble() - 0.5) * 40;
    final endY = startY + rand.nextDouble() * 40 - 10;
    final alpha = (0.4 + 0.5 * pulse + rand.nextDouble() * 0.3).clamp(0.0, 1.0);
    glowPaint.color = Color.fromRGBO(100, 200, 255, alpha);
    
    // Jagged lightning path
    final path = Path();
    path.moveTo(startX, startY);
    final midX = (startX + endX) / 2 + (rand.nextDouble() - 0.5) * 15;
    final midY = (startY + endY) / 2;
    path.lineTo(midX, midY);
    path.lineTo(endX, endY);
    canvas.drawPath(path, glowPaint);
  }
  
  // Main central bright bolt
  final mainGlow = Paint()
    ..color = Color.fromRGBO(150, 230, 255, (0.6 + 0.4 * pulse).clamp(0.0, 1.0))
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
  canvas.drawLine(
    Offset(cx - 15, shoulderY + 20),
    Offset(cx + 10, shoulderY + 60),
    mainGlow);
  canvas.drawLine(
    Offset(cx + 10, shoulderY + 60),
    Offset(cx - 8, shoulderY + 100),
    mainGlow);
}

void _drawArmLightning(Canvas canvas, Offset top, Offset bottom, double progress) {
  final rand = math.Random(7);
  final pulse = math.sin(progress * math.pi * 2 + 1.0);
  final numLines = 4;
  final glowPaint = Paint()
    ..strokeWidth = 1.2
    ..strokeCap = StrokeCap.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
  for (int i = 0; i < numLines; i++) {
    final t = rand.nextDouble();
    final x = top.dx + (bottom.dx - top.dx) * t + (rand.nextDouble() - 0.5) * 18;
    final y = top.dy + (bottom.dy - top.dy) * t;
    final ex = x + (rand.nextDouble() - 0.5) * 20;
    final ey = y + rand.nextDouble() * 20;
    glowPaint.color = Color.fromRGBO(100, 200, 255, (0.3 + 0.4 * pulse).clamp(0.0, 1.0));
    canvas.drawLine(Offset(x, y), Offset(ex, ey), glowPaint);
  }
}

void _drawSpikeyHair(Canvas canvas, double cx, double headCy, double headR) {
  final hairPaint = Paint()..color = const Color(0xFFE8E8F0); // Silver white
  
  // Base hair — rounded cap
  canvas.drawOval(
    Rect.fromCenter(center: Offset(cx, headCy - headR * 0.3), width: headR * 1.9, height: headR * 1.5),
    hairPaint);
  
  // Spiky top — multiple triangular spikes
  final spikes = [
    [cx - 8.0, headCy - headR * 0.9, cx - 20.0, headCy - headR * 1.8, cx + 2.0, headCy - headR * 0.8],
    [cx + 2.0, headCy - headR * 0.8, cx - 2.0, headCy - headR * 2.0, cx + 15.0, headCy - headR * 0.9],
    [cx + 10.0, headCy - headR * 0.9, cx + 16.0, headCy - headR * 1.7, cx + 24.0, headCy - headR * 0.8],
    [cx - 22.0, headCy - headR * 0.6, cx - 30.0, headCy - headR * 1.4, cx - 10.0, headCy - headR * 0.6],
  ];
  for (final spike in spikes) {
    final path = Path()
      ..moveTo(spike[0], spike[1])
      ..lineTo(spike[2], spike[3])
      ..lineTo(spike[4], spike[5])
      ..close();
    canvas.drawPath(path, hairPaint);
  }
  // Shadow on hair
  canvas.drawOval(
    Rect.fromCenter(center: Offset(cx + 10, headCy - headR * 0.2), width: headR * 0.8, height: headR * 0.8),
    Paint()..color = const Color(0xFF8888A0).withValues(alpha: 0.25));
}

void _drawSunglasses(Canvas canvas, double cx, double headCy, double headR) {
  final glassesY = headCy - headR * 0.05;
  // Frame
  final framePaint = Paint()
    ..color = const Color(0xFF111118)
    ..style = PaintingStyle.fill;
  // Left lens
  canvas.drawRRect(RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset(cx - headR * 0.35, glassesY), width: headR * 0.65, height: headR * 0.28),
    const Radius.circular(5)), framePaint);
  // Right lens
  canvas.drawRRect(RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset(cx + headR * 0.35, glassesY), width: headR * 0.65, height: headR * 0.28),
    const Radius.circular(5)), framePaint);
  // Bridge between lenses
  canvas.drawRect(
    Rect.fromCenter(center: Offset(cx, glassesY), width: headR * 0.18, height: headR * 0.1),
    Paint()..color = const Color(0xFF222230));
  // Lens tint/glare
  canvas.drawRRect(RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset(cx - headR * 0.45, glassesY - 3), width: headR * 0.2, height: headR * 0.08),
    const Radius.circular(3)),
    Paint()..color = Colors.white.withValues(alpha: 0.15));
  // Side temples
  canvas.drawLine(
    Offset(cx - headR * 0.68, glassesY),
    Offset(cx - headR * 0.95, glassesY + 5),
    Paint()..color = const Color(0xFF111118)..strokeWidth = 3);
  canvas.drawLine(
    Offset(cx + headR * 0.68, glassesY),
    Offset(cx + headR * 0.95, glassesY + 5),
    Paint()..color = const Color(0xFF111118)..strokeWidth = 3);
}

void _drawSpiderPattern(Canvas canvas, Offset center, double radius) {
  final paint = Paint()
    ..color = const Color(0xFF2A2A3A)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;
  // Radial web lines
  for (int i = 0; i < 6; i++) {
    final angle = i * math.pi / 3;
    canvas.drawLine(center,
      Offset(center.dx + math.cos(angle) * radius, center.dy + math.sin(angle) * radius),
      paint);
  }
  // Concentric rings
  canvas.drawCircle(center, radius * 0.4, paint);
  canvas.drawCircle(center, radius * 0.75, paint);
}
