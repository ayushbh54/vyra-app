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
    final isMale = profile.avatarGender == 'male';
    final skin = profile.skinGradientColors;
    final breathe = math.sin(idleProgress * math.pi * 2) * 3.0;
    final breatheScale = 1.0 + math.sin(idleProgress * math.pi * 2) * 0.012;

    // Body type
    double shoulderW = isMale ? size.width * 0.42 : size.width * 0.34;
    double hipW = isMale ? size.width * 0.32 : size.width * 0.38;
    if (profile.bodyType == 'muscular') { shoulderW *= 1.2; hipW *= 1.05; }
    if (profile.bodyType == 'lean') { shoulderW *= 0.88; hipW *= 0.9; }

    // Vertical layout
    final headR = size.height * 0.075;
    final headCy = size.height * 0.14 + breathe * 0.3;
    final neckY = headCy + headR * 0.95;
    final shoulderY = neckY + headR * 0.55;
    final elbowY = shoulderY + size.height * 0.16;
    final wristY = elbowY + size.height * 0.13;
    final torsoEndY = shoulderY + size.height * 0.24;
    final kneeY = torsoEndY + size.height * 0.22;
    final ankleY = kneeY + size.height * 0.19;

    canvas.save();
    canvas.translate(cx, size.height * 0.5);
    canvas.scale(breatheScale, breatheScale);
    canvas.translate(-cx, -size.height * 0.5);

    // ── OUTFIT COLORS ──
    Color topColor, pantsColor, shoeBaseColor, shoeSoleColor;
    switch (profile.outfitStyle) {
      case 'hoodie_white':
        topColor = const Color(0xFFE8ECEF);
        pantsColor = const Color(0xFF2C3E50);
        break;
      case 'runner_stealth':
        topColor = const Color(0xFF1A1A2E);
        pantsColor = const Color(0xFF16213E);
        break;
      case 'sunset_orange':
        topColor = const Color(0xFFE05C2A);
        pantsColor = const Color(0xFF2B2D42);
        break;
      case 'athletic_teal':
      default:
        topColor = const Color(0xFF0A9396);
        pantsColor = const Color(0xFF1A1A2E);
    }
    if (!isMale) topColor = Color.lerp(topColor, Colors.white, 0.15)!;

    switch (profile.shoeColor) {
      case 'cyan':    shoeBaseColor = const Color(0xFF006D77); shoeSoleColor = const Color(0xFF00B4D8); break;
      case 'white':   shoeBaseColor = const Color(0xFFEEEEEE); shoeSoleColor = const Color(0xFFCCCCCC); break;
      case 'stealth': shoeBaseColor = const Color(0xFF1A1A2E); shoeSoleColor = const Color(0xFF3A3A5E); break;
      case 'orange': default:
        shoeBaseColor = const Color(0xFFE05C2A); shoeSoleColor = const Color(0xFFFF8C42);
    }

    // ── LEGS / PANTS ──
    final legL = cx - hipW * 0.3;
    final legR = cx + hipW * 0.3;
    final footL = cx - hipW * 0.38;
    final footR = cx + hipW * 0.38;
    final pantP = Paint()..color = pantsColor..strokeWidth = isMale ? 30 : 26..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(legL, torsoEndY), Offset(legL - 4, kneeY), pantP);
    canvas.drawLine(Offset(legL - 4, kneeY), Offset(footL, ankleY), pantP);
    canvas.drawLine(Offset(legR, torsoEndY), Offset(legR + 4, kneeY), pantP);
    canvas.drawLine(Offset(legR + 4, kneeY), Offset(footR, ankleY), pantP);
    // Pants crease
    canvas.drawLine(Offset(legL - 2, torsoEndY + 10), Offset(legL - 4, kneeY - 10),
        Paint()..color = pantsColor.withValues(alpha: 0.4)..strokeWidth = 1.5);
    canvas.drawLine(Offset(legR + 2, torsoEndY + 10), Offset(legR + 4, kneeY - 10),
        Paint()..color = pantsColor.withValues(alpha: 0.4)..strokeWidth = 1.5);

    // ── SHOES ──
    final shW = isMale ? 44.0 : 38.0;
    for (final fx in [footL - 4, footR + 4]) {
      final dir = fx < cx ? -1 : 1;
      canvas.drawRRect(RRect.fromRectAndCorners(
        Rect.fromCenter(center: Offset(fx + dir * 4, ankleY + 8), width: shW, height: 18),
        bottomLeft: const Radius.circular(8), bottomRight: const Radius.circular(8),
        topLeft: const Radius.circular(4), topRight: const Radius.circular(4),
      ), Paint()..color = shoeBaseColor);
      canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(fx + dir * 4, ankleY + 15), width: shW + 2, height: 6),
        const Radius.circular(3)), Paint()..color = shoeSoleColor);
      canvas.drawLine(Offset(fx + dir * 4 - 8, ankleY + 4), Offset(fx + dir * 4 + 8, ankleY + 4),
          Paint()..color = Colors.white.withValues(alpha: 0.4)..strokeWidth = 1.5);
    }

    // ── TORSO / TOP ──
    final torsoPath = Path()
      ..moveTo(cx - shoulderW / 2, shoulderY)
      ..lineTo(cx + shoulderW / 2, shoulderY)
      ..lineTo(cx + hipW / 2, torsoEndY)
      ..lineTo(cx - hipW / 2, torsoEndY)
      ..close();
    canvas.drawPath(torsoPath, Paint()
      ..shader = LinearGradient(
        colors: [topColor, Color.lerp(topColor, Colors.black, 0.3)!],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTRB(cx - shoulderW / 2, shoulderY, cx + shoulderW / 2, torsoEndY)));

    // Collar / neckline
    if (isMale) {
      final collarPath = Path()
        ..moveTo(cx - shoulderW * 0.18, shoulderY)
        ..lineTo(cx, shoulderY + 18)
        ..lineTo(cx + shoulderW * 0.18, shoulderY);
      canvas.drawPath(collarPath, Paint()
        ..color = Color.lerp(topColor, Colors.black, 0.4)!
        ..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    } else {
      final collarPath = Path()
        ..moveTo(cx - shoulderW * 0.2, shoulderY + 2)
        ..quadraticBezierTo(cx, shoulderY + 20, cx + shoulderW * 0.2, shoulderY + 2);
      canvas.drawPath(collarPath, Paint()
        ..color = Color.lerp(topColor, Colors.black, 0.35)!
        ..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    }
    canvas.drawCircle(Offset(cx + 12, shoulderY + 35), 5,
        Paint()..color = Colors.white.withValues(alpha: 0.25));

    // ── BELT ──
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, torsoEndY + 4), width: hipW * 0.92, height: 10),
        const Radius.circular(4)),
        Paint()..color = Colors.black.withValues(alpha: 0.5));
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, torsoEndY + 4), width: 14, height: 8),
        Paint()..color = Colors.white.withValues(alpha: 0.3));

    // ── ARMS ──
    final armW = isMale ? 22.0 : 17.0;
    final forearmW = isMale ? 18.0 : 14.0;
    final leftShoulder = Offset(cx - shoulderW / 2, shoulderY + 4);
    final rightShoulder = Offset(cx + shoulderW / 2, shoulderY + 4);
    final leftElbow = Offset(cx - shoulderW / 2 - 12, elbowY);
    final rightElbow = Offset(cx + shoulderW / 2 + 12, elbowY);
    final leftWrist = Offset(cx - shoulderW / 2 - 6, wristY);
    final rightWrist = Offset(cx + shoulderW / 2 + 6, wristY);

    canvas.drawLine(leftShoulder, leftElbow, Paint()..color = topColor..strokeWidth = armW..strokeCap = StrokeCap.round);
    canvas.drawLine(rightShoulder, rightElbow, Paint()..color = topColor..strokeWidth = armW..strokeCap = StrokeCap.round);
    canvas.drawLine(leftElbow, leftWrist, Paint()..color = skin[0]..strokeWidth = forearmW..strokeCap = StrokeCap.round);
    canvas.drawLine(rightElbow, rightWrist, Paint()..color = skin[0]..strokeWidth = forearmW..strokeCap = StrokeCap.round);
    canvas.drawCircle(leftWrist, forearmW * 0.65, Paint()..color = skin[0]);
    canvas.drawCircle(rightWrist, forearmW * 0.65, Paint()..color = skin[0]);
    canvas.drawLine(leftWrist, Offset(leftWrist.dx - 6, leftWrist.dy + 8),
        Paint()..color = skin[1]..strokeWidth = 4..strokeCap = StrokeCap.round);
    canvas.drawLine(rightWrist, Offset(rightWrist.dx + 6, rightWrist.dy + 8),
        Paint()..color = skin[1]..strokeWidth = 4..strokeCap = StrokeCap.round);

    // ── NECK ──
    final neckW = isMale ? 22.0 : 17.0;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, neckY + headR * 0.1), width: neckW, height: headR * 1.1),
        const Radius.circular(8)),
        Paint()..color = skin[0]);

    // ── HEAD / FACE ──
    final faceW = isMale ? headR * 1.75 : headR * 1.65;
    final faceH = isMale ? headR * 2.0 : headR * 2.05;
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, headCy), width: faceW, height: faceH),
        Paint()..color = skin[0]);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, headCy + headR * 0.55), width: faceW * 0.9, height: headR * 0.9),
        Paint()..color = skin[2].withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    if (!isMale || profile.skinTone == 'fair') {
      for (final side in [-1.0, 1.0]) {
        canvas.drawCircle(Offset(cx + side * faceW * 0.3, headCy + headR * 0.2), headR * 0.22,
            Paint()..color = const Color(0xFFFFB3C6).withValues(alpha: 0.2)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      }
    }

    // ── EYEBROWS ──
    final browY = headCy - headR * 0.28;
    final browColor = Color.lerp(profile.hairColor, Colors.black, 0.4)!;
    final browPaint = Paint()..color = browColor..strokeWidth = isMale ? 3.0 : 2.5..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - faceW * 0.36, browY + (isMale ? 2 : 1)), Offset(cx - faceW * 0.12, browY), browPaint);
    canvas.drawLine(Offset(cx + faceW * 0.12, browY), Offset(cx + faceW * 0.36, browY + (isMale ? 2 : 1)), browPaint);

    // ── EYES ──
    final eyeY = headCy - headR * 0.1;
    final eyeSpacing = faceW * 0.24;
    final eyeW = headR * 0.28;
    final eyeH = isMale ? headR * 0.18 : headR * 0.22;
    for (final ex in [cx - eyeSpacing, cx + eyeSpacing]) {
      canvas.drawOval(Rect.fromCenter(center: Offset(ex, eyeY), width: eyeW * 2, height: eyeH * 2),
          Paint()..color = Colors.white);
      canvas.drawCircle(Offset(ex, eyeY), eyeH * 0.85, Paint()..color = const Color(0xFF3E2723));
      canvas.drawCircle(Offset(ex, eyeY), eyeH * 0.45, Paint()..color = Colors.black);
      canvas.drawCircle(Offset(ex + eyeH * 0.3, eyeY - eyeH * 0.3), eyeH * 0.2,
          Paint()..color = Colors.white.withValues(alpha: 0.85));
      final eyelidPath = Path()
        ..moveTo(ex - eyeW, eyeY)
        ..quadraticBezierTo(ex, eyeY - eyeH * 1.4, ex + eyeW, eyeY)
        ..close();
      canvas.drawPath(eyelidPath, Paint()..color = skin[0]);
      canvas.drawPath(eyelidPath, Paint()
        ..color = Colors.black.withValues(alpha: 0.7)
        ..strokeWidth = 1.5..style = PaintingStyle.stroke);
      if (!isMale) {
        for (int l = 0; l < 5; l++) {
          final lx = ex - eyeW * 0.8 + l * eyeW * 0.4;
          final ly = eyeY - eyeH * 1.35;
          canvas.drawLine(Offset(lx, ly), Offset(lx - 2 + l.toDouble(), ly - 5),
              Paint()..color = Colors.black..strokeWidth = 1.5..strokeCap = StrokeCap.round);
        }
      }
      canvas.drawOval(Rect.fromCenter(center: Offset(ex, eyeY), width: eyeW * 2, height: eyeH * 2),
          Paint()..color = Colors.black.withValues(alpha: 0.4)..strokeWidth = 1.2..style = PaintingStyle.stroke);
    }

    // ── NOSE ──
    final noseY = headCy + headR * 0.2;
    final nosePath = Path()
      ..moveTo(cx, eyeY + headR * 0.1)
      ..quadraticBezierTo(cx + headR * 0.05, noseY, cx, noseY + headR * 0.05);
    canvas.drawPath(nosePath, Paint()
      ..color = skin[2].withValues(alpha: 0.5)..strokeWidth = 1.8
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    canvas.drawCircle(Offset(cx - headR * 0.1, noseY + headR * 0.04), 2.5,
        Paint()..color = skin[2].withValues(alpha: 0.6));
    canvas.drawCircle(Offset(cx + headR * 0.1, noseY + headR * 0.04), 2.5,
        Paint()..color = skin[2].withValues(alpha: 0.6));

    // ── LIPS ──
    final lipY = headCy + headR * 0.5;
    final lipColor = !isMale
        ? const Color(0xFFD4526C)
        : Color.lerp(skin[1], const Color(0xFFAA4433), 0.5)!;
    final lipW = headR * 0.52;
    final upperLip = Path()
      ..moveTo(cx - lipW, lipY)
      ..quadraticBezierTo(cx - lipW * 0.4, lipY - headR * 0.12, cx, lipY - headR * 0.04)
      ..quadraticBezierTo(cx + lipW * 0.4, lipY - headR * 0.12, cx + lipW, lipY)
      ..close();
    canvas.drawPath(upperLip, Paint()..color = lipColor);
    final lowerLip = Path()
      ..moveTo(cx - lipW * 0.9, lipY + headR * 0.02)
      ..quadraticBezierTo(cx, lipY + headR * 0.2, cx + lipW * 0.9, lipY + headR * 0.02)
      ..lineTo(cx + lipW * 0.9, lipY)
      ..lineTo(cx - lipW * 0.9, lipY)
      ..close();
    canvas.drawPath(lowerLip, Paint()..color = Color.lerp(lipColor, Colors.white, 0.15)!);
    canvas.drawLine(Offset(cx - lipW * 0.85, lipY), Offset(cx + lipW * 0.85, lipY),
        Paint()..color = lipColor.withValues(alpha: 0.6)..strokeWidth = 0.8);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, lipY + headR * 0.08), width: lipW * 0.5, height: headR * 0.06),
        Paint()..color = Colors.white.withValues(alpha: !isMale ? 0.3 : 0.1));

    // ── FACIAL HAIR (male) ──
    if (isMale && profile.facialHair != 'clean') {
      final hairCol = Color.lerp(profile.hairColor, Colors.black, 0.3)!;
      if (profile.facialHair == 'stubble') {
        final rand = math.Random(99);
        for (int i = 0; i < 30; i++) {
          final fx = cx + (rand.nextDouble() - 0.5) * faceW * 0.7;
          final fy = lipY + headR * 0.1 + rand.nextDouble() * headR * 0.5;
          canvas.drawCircle(Offset(fx, fy), 1.2, Paint()..color = hairCol.withValues(alpha: 0.5));
        }
      } else if (profile.facialHair == 'neat_beard') {
        final beardPath = Path()
          ..moveTo(cx - faceW * 0.42, headCy + headR * 0.35)
          ..quadraticBezierTo(cx - faceW * 0.46, headCy + headR * 0.8, cx, headCy + headR * 1.0)
          ..quadraticBezierTo(cx + faceW * 0.46, headCy + headR * 0.8, cx + faceW * 0.42, headCy + headR * 0.35)
          ..quadraticBezierTo(cx, lipY + headR * 0.2, cx - faceW * 0.42, headCy + headR * 0.35)
          ..close();
        canvas.drawPath(beardPath, Paint()..color = hairCol.withValues(alpha: 0.75));
      }
    }

    // ── HAIR ──
    _drawHumanHair(canvas, cx, headCy, headR, faceW, profile.hairStyle, profile.hairColor, isMale);

    // ── ACCESSORIES ──
    if (profile.accessoryStyle == 'sunglasses_stealth') {
      _drawAccessorySunglasses(canvas, cx, eyeY, headR, faceW);
    } else if (profile.accessoryStyle == 'headphones_silver') {
      _drawHeadphones(canvas, cx, headCy, headR, faceW);
    } else if (profile.accessoryStyle == 'sweatband_red') {
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, headCy - headR * 0.62), width: faceW * 1.1, height: headR * 0.18),
          const Radius.circular(4)),
          Paint()..color = const Color(0xFFD32F2F));
    }
    if (profile.capStyle != 'none') {
      _drawCap(canvas, cx, headCy, headR, faceW, profile.capStyle, profile.hairColor);
    }

    canvas.restore();
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


// ─────────────────────────────────────────────────────────────────────────────
// HUMAN HAIR STYLES — 8 styles for male & female
// ─────────────────────────────────────────────────────────────────────────────
void _drawHumanHair(
  Canvas canvas,
  double cx,
  double headCy,
  double headR,
  double faceW,
  String style,
  Color hairColor,
  bool isMale,
) {
  final hp = Paint()..color = hairColor;
  final hpDark = Paint()..color = Color.lerp(hairColor, Colors.black, 0.35)!;
  final hpLight = Paint()..color = Color.lerp(hairColor, Colors.white, 0.25)!;

  switch (style) {
    case 'pixar_wavy': // Wavy flowing — default female
      // Base cap
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, headCy - headR * 0.2), width: faceW * 1.12, height: headR * 1.5),
        hp,
      );
      // Side waves left
      final lWave = Path()
        ..moveTo(cx - faceW * 0.52, headCy - headR * 0.5)
        ..quadraticBezierTo(cx - faceW * 0.7, headCy + headR * 0.4, cx - faceW * 0.58, headCy + headR * 1.0)
        ..quadraticBezierTo(cx - faceW * 0.5, headCy + headR * 0.7, cx - faceW * 0.42, headCy - headR * 0.3)
        ..close();
      canvas.drawPath(lWave, hp);
      // Side waves right
      final rWave = Path()
        ..moveTo(cx + faceW * 0.52, headCy - headR * 0.5)
        ..quadraticBezierTo(cx + faceW * 0.7, headCy + headR * 0.4, cx + faceW * 0.58, headCy + headR * 1.0)
        ..quadraticBezierTo(cx + faceW * 0.5, headCy + headR * 0.7, cx + faceW * 0.42, headCy - headR * 0.3)
        ..close();
      canvas.drawPath(rWave, hp);
      // Hair shine
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx - headR * 0.15, headCy - headR * 0.55), width: headR * 0.45, height: headR * 0.18),
        Paint()..color = hpLight.color.withValues(alpha: 0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      break;

    case 'ponytail':
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, headCy - headR * 0.2), width: faceW * 1.1, height: headR * 1.4),
        hp,
      );
      // Ponytail at back
      final pt = Path()
        ..moveTo(cx - headR * 0.25, headCy - headR * 0.7)
        ..quadraticBezierTo(cx - headR * 0.5, headCy + headR * 0.5, cx - headR * 0.2, headCy + headR * 1.6)
        ..quadraticBezierTo(cx + headR * 0.1, headCy + headR * 1.5, cx + headR * 0.2, headCy - headR * 0.5)
        ..close();
      canvas.drawPath(pt, hpDark);
      // Hair tie
      canvas.drawCircle(Offset(cx, headCy + headR * 0.5), 5,
          Paint()..color = const Color(0xFF222222));
      break;

    case 'high_bun':
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, headCy - headR * 0.2), width: faceW * 1.1, height: headR * 1.35),
        hp,
      );
      // Bun on top
      canvas.drawCircle(
        Offset(cx, headCy - headR * 1.0), headR * 0.42, hp,
      );
      canvas.drawCircle(
        Offset(cx, headCy - headR * 1.0), headR * 0.42,
        Paint()..color = hpDark.color..style = PaintingStyle.stroke..strokeWidth = 2.5,
      );
      break;

    case 'short_crop': // Short cropped — male/female
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, headCy - headR * 0.3), width: faceW * 1.08, height: headR * 1.1),
        hp,
      );
      // Texture lines
      for (int i = 0; i < 4; i++) {
        final lx = cx - headR * 0.5 + i * headR * 0.3;
        canvas.drawLine(Offset(lx, headCy - headR * 0.9), Offset(lx + 6, headCy - headR * 0.5),
            Paint()..color = hpDark.color..strokeWidth = 1.5..strokeCap = StrokeCap.round);
      }
      break;

    case 'crew_fade': // Crew / fade — masculine
      final fadePath = Path()
        ..moveTo(cx - faceW * 0.53, headCy - headR * 0.0)
        ..quadraticBezierTo(cx - faceW * 0.52, headCy - headR * 1.0, cx, headCy - headR * 1.1)
        ..quadraticBezierTo(cx + faceW * 0.52, headCy - headR * 1.0, cx + faceW * 0.53, headCy - headR * 0.0)
        ..close();
      canvas.drawPath(fadePath, hp);
      // Side fade gradient
      canvas.drawRect(
        Rect.fromLTWH(cx - faceW * 0.55, headCy - headR * 0.3, faceW * 0.15, headR * 0.4),
        Paint()..shader = LinearGradient(
          colors: [hairColor.withValues(alpha: 0), hairColor],
          begin: Alignment.centerLeft, end: Alignment.centerRight,
        ).createShader(Rect.fromLTWH(cx - faceW * 0.55, headCy - headR * 0.3, faceW * 0.15, headR * 0.4)),
      );
      canvas.drawRect(
        Rect.fromLTWH(cx + faceW * 0.4, headCy - headR * 0.3, faceW * 0.15, headR * 0.4),
        Paint()..shader = LinearGradient(
          colors: [hairColor, hairColor.withValues(alpha: 0)],
          begin: Alignment.centerLeft, end: Alignment.centerRight,
        ).createShader(Rect.fromLTWH(cx + faceW * 0.4, headCy - headR * 0.3, faceW * 0.15, headR * 0.4)),
      );
      break;

    case 'braided':
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, headCy - headR * 0.2), width: faceW * 1.1, height: headR * 1.4),
        hp,
      );
      // Braid down right side
      for (int i = 0; i < 6; i++) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx + faceW * 0.42, headCy + headR * (0.1 + i * 0.2)), width: headR * 0.22, height: headR * 0.15),
          Paint()..color = i.isEven ? hairColor : hpDark.color,
        );
      }
      break;

    case 'bald':
      // Just a clean scalp — no extra drawing
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, headCy - headR * 0.1), width: faceW * 1.02, height: headR * 1.15),
        Paint()..color = Color.lerp(hairColor, const Color(0xFF888888), 0.85)!..style = PaintingStyle.stroke..strokeWidth = 2,
      );
      break;

    case 'mohawk':
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, headCy - headR * 0.15), width: faceW * 1.08, height: headR * 1.2),
        Paint()..color = hpDark.color,
      );
      // Mohawk strip
      final moPath = Path()
        ..moveTo(cx - headR * 0.16, headCy - headR * 0.8)
        ..lineTo(cx - headR * 0.13, headCy - headR * 1.85)
        ..lineTo(cx + headR * 0.13, headCy - headR * 1.85)
        ..lineTo(cx + headR * 0.16, headCy - headR * 0.8)
        ..close();
      canvas.drawPath(moPath, hp);
      break;

    default:
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, headCy - headR * 0.2), width: faceW * 1.1, height: headR * 1.45),
        hp,
      );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACCESSORY: SUNGLASSES
// ─────────────────────────────────────────────────────────────────────────────
void _drawAccessorySunglasses(Canvas canvas, double cx, double eyeY, double headR, double faceW) {
  final framePaint = Paint()..color = const Color(0xFF1A1A2E);
  final lensPaint = Paint()..color = const Color(0xFF0D0D0D).withValues(alpha: 0.85);
  final eyeSpacing = faceW * 0.24;
  final lensW = headR * 0.62;
  final lensH = headR * 0.28;

  for (final ex in [cx - eyeSpacing, cx + eyeSpacing]) {
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(ex, eyeY), width: lensW * 2, height: lensH * 2),
      const Radius.circular(6)), lensPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(ex, eyeY), width: lensW * 2, height: lensH * 2),
      const Radius.circular(6)),
      Paint()..color = const Color(0xFF00E5FF).withValues(alpha: 0.12)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    // Lens glare
    canvas.drawOval(Rect.fromCenter(center: Offset(ex - lensW * 0.3, eyeY - lensH * 0.3), width: lensW * 0.35, height: lensH * 0.25),
        Paint()..color = Colors.white.withValues(alpha: 0.15));
  }
  // Bridge
  canvas.drawLine(Offset(cx - eyeSpacing + lensW, eyeY), Offset(cx + eyeSpacing - lensW, eyeY),
      Paint()..color = framePaint.color..strokeWidth = 3);
  // Temples
  canvas.drawLine(Offset(cx - eyeSpacing - lensW, eyeY), Offset(cx - eyeSpacing - lensW - headR * 0.35, eyeY + 4),
      Paint()..color = framePaint.color..strokeWidth = 2.5);
  canvas.drawLine(Offset(cx + eyeSpacing + lensW, eyeY), Offset(cx + eyeSpacing + lensW + headR * 0.35, eyeY + 4),
      Paint()..color = framePaint.color..strokeWidth = 2.5);
}

// ─────────────────────────────────────────────────────────────────────────────
// ACCESSORY: HEADPHONES
// ─────────────────────────────────────────────────────────────────────────────
void _drawHeadphones(Canvas canvas, double cx, double headCy, double headR, double faceW) {
  const silver = Color(0xFFBDBDBD);
  // Arc over head
  final arcRect = Rect.fromCenter(center: Offset(cx, headCy - headR * 0.15), width: faceW * 1.3, height: headR * 1.4);
  canvas.drawArc(arcRect, math.pi, math.pi, false,
      Paint()..color = silver..strokeWidth = 6..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
  // Ear cups
  for (final side in [-1.0, 1.0]) {
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx + side * faceW * 0.62, headCy - headR * 0.1), width: 18, height: 26),
      const Radius.circular(6)),
      Paint()..color = const Color(0xFF424242));
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx + side * faceW * 0.62, headCy - headR * 0.1), width: 12, height: 18),
      const Radius.circular(5)),
      Paint()..color = const Color(0xFF212121));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACCESSORY: CAP / HAT
// ─────────────────────────────────────────────────────────────────────────────
void _drawCap(Canvas canvas, double cx, double headCy, double headR, double faceW, String capStyle, Color hairColor) {
  Color capColor;
  switch (capStyle) {
    case 'visor_neon':  capColor = const Color(0xFF00E5FF); break;
    case 'beanie_gray': capColor = const Color(0xFF607D8B); break;
    case 'backward_cap':
    case 'snapback_black':
    default: capColor = const Color(0xFF1A1A2E);
  }

  if (capStyle == 'beanie_gray') {
    // Beanie — covers top of head
    final bPath = Path()
      ..moveTo(cx - faceW * 0.52, headCy - headR * 0.12)
      ..quadraticBezierTo(cx - faceW * 0.5, headCy - headR * 1.3, cx, headCy - headR * 1.35)
      ..quadraticBezierTo(cx + faceW * 0.5, headCy - headR * 1.3, cx + faceW * 0.52, headCy - headR * 0.12)
      ..close();
    canvas.drawPath(bPath, Paint()..color = capColor);
    // Beanie ribbing
    canvas.drawLine(Offset(cx - faceW * 0.52, headCy - headR * 0.12), Offset(cx + faceW * 0.52, headCy - headR * 0.12),
        Paint()..color = Colors.white.withValues(alpha: 0.2)..strokeWidth = 5);
  } else {
    // Cap base (panel)
    final capPath = Path()
      ..moveTo(cx - faceW * 0.54, headCy - headR * 0.08)
      ..quadraticBezierTo(cx - faceW * 0.5, headCy - headR * 1.2, cx, headCy - headR * 1.25)
      ..quadraticBezierTo(cx + faceW * 0.5, headCy - headR * 1.2, cx + faceW * 0.54, headCy - headR * 0.08)
      ..close();
    canvas.drawPath(capPath, Paint()..color = capColor);
    // Brim
    if (capStyle != 'backward_cap') {
      canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - faceW * 0.12, headCy - headR * 0.05), width: faceW * 0.7, height: 10),
        const Radius.circular(4)),
        Paint()..color = Color.lerp(capColor, Colors.black, 0.4)!);
    } else {
      // Backward brim at back
      canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + faceW * 0.2, headCy - headR * 0.05), width: faceW * 0.6, height: 9),
        const Radius.circular(4)),
        Paint()..color = Color.lerp(capColor, Colors.black, 0.4)!);
    }
    // Cap logo
    canvas.drawCircle(Offset(cx, headCy - headR * 0.6), 5,
        Paint()..color = Colors.white.withValues(alpha: 0.35));
  }
}

