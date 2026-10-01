import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/avatar_customization_service.dart';
import '../theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class AvatarProfile {
  final String gender;        // 'male' | 'female'
  final String bodyType;      // 'lean' | 'athletic' | 'muscular'
  final Color skinTone;
  final Color hairColor;
  final String hairStyle;     // 'short' | 'medium' | 'long' | 'bun' | 'bald' | 'curly'
  final Color outfitTop;
  final Color outfitBottom;
  final String outfitStyle;   // 'casual' | 'sport' | 'fighter' | 'yoga'
  final String pose;          // 'idle' | 'run' | 'boxing' | 'yoga' | 'squat' | 'pushup'

  const AvatarProfile({
    this.gender = 'male',
    this.bodyType = 'athletic',
    this.skinTone = const Color(0xFFC68642),
    this.hairColor = const Color(0xFF2C1503),
    this.hairStyle = 'short',
    this.outfitTop = const Color(0xFF00D2FF),
    this.outfitBottom = const Color(0xFF1B2029),
    this.outfitStyle = 'sport',
    this.pose = 'idle',
  });

  AvatarProfile copyWith({
    String? gender, String? bodyType, Color? skinTone,
    Color? hairColor, String? hairStyle,
    Color? outfitTop, Color? outfitBottom, String? outfitStyle, String? pose,
  }) => AvatarProfile(
    gender: gender ?? this.gender,
    bodyType: bodyType ?? this.bodyType,
    skinTone: skinTone ?? this.skinTone,
    hairColor: hairColor ?? this.hairColor,
    hairStyle: hairStyle ?? this.hairStyle,
    outfitTop: outfitTop ?? this.outfitTop,
    outfitBottom: outfitBottom ?? this.outfitBottom,
    outfitStyle: outfitStyle ?? this.outfitStyle,
    pose: pose ?? this.pose,
  );

  Map<String, dynamic> toJson() => {
    'gender': gender, 'bodyType': bodyType,
    'skinTone': skinTone.toARGB32(), 'hairColor': hairColor.toARGB32(),
    'hairStyle': hairStyle,
    'outfitTop': outfitTop.toARGB32(), 'outfitBottom': outfitBottom.toARGB32(),
    'outfitStyle': outfitStyle, 'pose': pose,
  };

  factory AvatarProfile.fromJson(Map<String, dynamic> j) => AvatarProfile(
    gender: j['gender'] as String? ?? 'male',
    bodyType: j['bodyType'] as String? ?? 'athletic',
    skinTone: Color(j['skinTone'] as int? ?? 0xFFC68642),
    hairColor: Color(j['hairColor'] as int? ?? 0xFF2C1503),
    hairStyle: j['hairStyle'] as String? ?? 'short',
    outfitTop: Color(j['outfitTop'] as int? ?? 0xFF00D2FF),
    outfitBottom: Color(j['outfitBottom'] as int? ?? 0xFF1B2029),
    outfitStyle: j['outfitStyle'] as String? ?? 'sport',
    pose: j['pose'] as String? ?? 'idle',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class AvatarStudioScreen extends StatefulWidget {
  const AvatarStudioScreen({super.key});
  @override
  State<AvatarStudioScreen> createState() => _AvatarStudioScreenState();
}

class _AvatarStudioScreenState extends State<AvatarStudioScreen>
    with SingleTickerProviderStateMixin {
  AvatarProfile _profile = const AvatarProfile();
  late AnimationController _breatheCtrl;
  late Animation<double> _breathe;
  int _tabIndex = 0;
  bool _saving = false;

  static const _tabs = ['Body', 'Outfit', 'Hair', 'Skin', 'Poses'];
  static const _tabIcons = [
    Icons.accessibility_new_rounded,
    Icons.checkroom_rounded,
    Icons.face_rounded,
    Icons.palette_rounded,
    Icons.sports_gymnastics_rounded,
  ];

  // ── Skin tones ─────────────────────────────────────────────────────────────
  static const skinTones = [
    Color(0xFFFFDBAC), Color(0xFFF1C27D), Color(0xFFE0AC69),
    Color(0xFFC68642), Color(0xFF8D5524), Color(0xFF4A2912),
  ];

  // ── Hair colors ────────────────────────────────────────────────────────────
  static const hairColors = [
    Color(0xFF2C1503), Color(0xFF6B3A2A), Color(0xFFA0522D),
    Color(0xFFD4A017), Color(0xFFB8B8B8), Color(0xFFEEEEEE),
    Color(0xFF1A1A1A), Color(0xFF8B0000),
  ];

  // ── Outfit accent colors ───────────────────────────────────────────────────
  static const outfitColors = [
    Color(0xFF00D2FF), Color(0xFF34FF8C), Color(0xFFFF4444),
    Color(0xFFFFAF00), Color(0xFFBB86FC), Color(0xFFFF69B4),
    Color(0xFF1A1A2E), Color(0xFFFFFFFF),
  ];

  // ── Poses ──────────────────────────────────────────────────────────────────
  static const poses = [
    {'id': 'idle',      'label': 'Idle',      'icon': Icons.person_rounded},
    {'id': 'run',       'label': 'Running',   'icon': Icons.directions_run_rounded},
    {'id': 'boxing',    'label': 'Boxing',    'icon': Icons.sports_mma_rounded},
    {'id': 'yoga',      'label': 'Yoga',      'icon': Icons.self_improvement_rounded},
    {'id': 'squat',     'label': 'Squat',     'icon': Icons.accessibility_new_rounded},
    {'id': 'pushup',    'label': 'Push-up',   'icon': Icons.fitness_center_rounded},
    {'id': 'cycling',   'label': 'Cycling',   'icon': Icons.directions_bike_rounded},
    {'id': 'jump',      'label': 'Jump',      'icon': Icons.arrow_upward_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _breatheCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _breathe = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _breatheCtrl, curve: Curves.easeInOut),
    );
    _loadProfile();
  }

  @override
  void dispose() {
    _breatheCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('avatar_profile_v2');
      final gender = prefs.getString('user_gender') ??
          prefs.getString('gender') ?? 'male';
      if (!mounted) return;
      if (raw != null) {
        final j = <String, dynamic>{};
        raw.split('|').forEach((pair) {
          final kv = pair.split('=');
          if (kv.length == 2) j[kv[0]] = kv[1];
        });
        // Parse color ints
        final parsed = <String, dynamic>{
          'gender': j['gender'] ?? gender,
          'bodyType': j['bodyType'] ?? 'athletic',
          'skinTone': int.tryParse(j['skinTone'] ?? '') ?? 0xFFC68642,
          'hairColor': int.tryParse(j['hairColor'] ?? '') ?? 0xFF2C1503,
          'hairStyle': j['hairStyle'] ?? 'short',
          'outfitTop': int.tryParse(j['outfitTop'] ?? '') ?? 0xFF00D2FF,
          'outfitBottom': int.tryParse(j['outfitBottom'] ?? '') ?? 0xFF1B2029,
          'outfitStyle': j['outfitStyle'] ?? 'sport',
          'pose': j['pose'] ?? 'idle',
        };
        setState(() => _profile = AvatarProfile.fromJson(parsed));
      } else {
        // First launch — use saved gender from onboarding
        setState(() => _profile = AvatarProfile(gender: gender));
      }
    } catch (_) {}
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final p = _profile;
      final raw = 'gender=${p.gender}|bodyType=${p.bodyType}'
          '|skinTone=${p.skinTone.toARGB32()}|hairColor=${p.hairColor.toARGB32()}'
          '|hairStyle=${p.hairStyle}|outfitTop=${p.outfitTop.toARGB32()}'
          '|outfitBottom=${p.outfitBottom.toARGB32()}|outfitStyle=${p.outfitStyle}'
          '|pose=${p.pose}';
      await prefs.setString('avatar_profile_v2', raw);
      await prefs.setString('user_gender', p.gender);
      AvatarCustomizationService.instance.setActiveExercisePose(p.pose);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Avatar saved successfully!'),
          backgroundColor: VColor.accentGreen.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (_) {}
    if (!mounted) return;
    setState(() => _saving = false);
  }

  void _update(AvatarProfile p) => setState(() => _profile = p);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VColor.bg,
      body: Column(
        children: [
          // ── Top bar ─────────────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const BackButton(color: VColor.text),
                  const Expanded(
                    child: Text(
                      'Avatar Studio',
                      style: TextStyle(
                        color: VColor.text,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Gender toggle
                  Container(
                    decoration: BoxDecoration(
                      color: VColor.surfaceRaised,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _genderBtn('male', '♂'),
                        _genderBtn('female', '♀'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Avatar preview ───────────────────────────────────────────────────
          Expanded(
            flex: 5,
            child: AnimatedBuilder(
              animation: _breathe,
              builder: (_, __) => CustomPaint(
                painter: _AvatarPainter(
                  profile: _profile,
                  breathe: _breathe.value,
                ),
                child: Container(),
              ),
            ),
          ),

          // ── Hint ────────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${_profile.gender == 'female' ? 'Female' : 'Male'} · ${_profile.bodyType} · ${_profile.pose}',
              style: const TextStyle(color: VColor.textMid, fontSize: 12),
            ),
          ),

          // ── Tab bar ─────────────────────────────────────────────────────────
          Container(
            color: VColor.surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: List.generate(_tabs.length, (i) {
                  final sel = _tabIndex == i;
                  return GestureDetector(
                    onTap: () => setState(() => _tabIndex = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? VColor.accent : VColor.surfaceRaised,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_tabIcons[i],
                              size: 16,
                              color: sel ? VColor.textOnAccent : VColor.textMid),
                          const SizedBox(width: 6),
                          Text(
                            _tabs[i],
                            style: TextStyle(
                              color: sel ? VColor.textOnAccent : VColor.textMid,
                              fontSize: 13,
                              fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          // ── Panel ───────────────────────────────────────────────────────────
          Container(
            color: VColor.surface,
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildPanel(),
            ),
          ),

          // ── Save button ──────────────────────────────────────────────────────
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VColor.accent,
                    foregroundColor: VColor.textOnAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: VColor.textOnAccent))
                      : const Text('Save Avatar',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _genderBtn(String g, String label) {
    final sel = _profile.gender == g;
    return GestureDetector(
      onTap: () => _update(_profile.copyWith(gender: g)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? VColor.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: sel ? VColor.textOnAccent : VColor.textMid,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildPanel() {
    switch (_tabIndex) {
      case 0:
        return _buildBodyPanel();
      case 1:
        return _buildOutfitPanel();
      case 2:
        return _buildHairPanel();
      case 3:
        return _buildSkinPanel();
      case 4:
        return _buildPosesPanel();
      default:
        return const SizedBox();
    }
  }

  // ── BODY TAB ────────────────────────────────────────────────────────────────
  Widget _buildBodyPanel() {
    final types = ['lean', 'athletic', 'muscular'];
    final icons = [Icons.airline_seat_recline_normal_rounded,
        Icons.directions_run_rounded, Icons.fitness_center_rounded];
    final descs = ['Slim & toned', 'Balanced build', 'Bulky & strong'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Body Type', style: TextStyle(color: VColor.textMid,
            fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(
          children: List.generate(3, (i) {
            final sel = _profile.bodyType == types[i];
            return Expanded(
              child: GestureDetector(
                onTap: () => _update(_profile.copyWith(bodyType: types[i])),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: sel ? VColor.accentGlow : VColor.surfaceRaised,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: sel ? VColor.accent : VColor.line,
                        width: sel ? 2 : 1),
                  ),
                  child: Column(
                    children: [
                      Icon(icons[i],
                          color: sel ? VColor.accent : VColor.textMid, size: 24),
                      const SizedBox(height: 6),
                      Text(types[i][0].toUpperCase() + types[i].substring(1),
                          style: TextStyle(
                              color: sel ? VColor.accent : VColor.text,
                              fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(descs[i],
                          style: const TextStyle(
                              color: VColor.textMid, fontSize: 10),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ── OUTFIT TAB ───────────────────────────────────────────────────────────────
  Widget _buildOutfitPanel() {
    final styles = ['sport', 'casual', 'fighter', 'yoga'];
    final styleIcons = [Icons.sports_rounded, Icons.person_rounded,
        Icons.sports_mma_rounded, Icons.self_improvement_rounded];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Style', style: TextStyle(color: VColor.textMid,
            fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: List.generate(styles.length, (i) {
            final sel = _profile.outfitStyle == styles[i];
            return GestureDetector(
              onTap: () => _update(_profile.copyWith(outfitStyle: styles[i])),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? VColor.accentGlow : VColor.surfaceRaised,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: sel ? VColor.accent : Colors.transparent),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(styleIcons[i], size: 14,
                        color: sel ? VColor.accent : VColor.textMid),
                    const SizedBox(width: 6),
                    Text(styles[i][0].toUpperCase() + styles[i].substring(1),
                        style: TextStyle(
                            color: sel ? VColor.accent : VColor.textMid,
                            fontSize: 12,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        const Text('Top Color', style: TextStyle(color: VColor.textMid,
            fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _colorRow(outfitColors, _profile.outfitTop,
            (c) => _update(_profile.copyWith(outfitTop: c))),
        const SizedBox(height: 10),
        const Text('Bottom Color', style: TextStyle(color: VColor.textMid,
            fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _colorRow(outfitColors, _profile.outfitBottom,
            (c) => _update(_profile.copyWith(outfitBottom: c))),
      ],
    );
  }

  // ── HAIR TAB ─────────────────────────────────────────────────────────────────
  Widget _buildHairPanel() {
    final styles = ['short', 'medium', 'long', 'bun', 'curly', 'bald'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Hair Style', style: TextStyle(color: VColor.textMid,
            fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: styles.map((s) {
            final sel = _profile.hairStyle == s;
            return GestureDetector(
              onTap: () => _update(_profile.copyWith(hairStyle: s)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? VColor.accentGlow : VColor.surfaceRaised,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: sel ? VColor.accent : Colors.transparent),
                ),
                child: Text(s[0].toUpperCase() + s.substring(1),
                    style: TextStyle(
                        color: sel ? VColor.accent : VColor.textMid,
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        const Text('Hair Color', style: TextStyle(color: VColor.textMid,
            fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _colorRow(hairColors, _profile.hairColor,
            (c) => _update(_profile.copyWith(hairColor: c))),
      ],
    );
  }

  // ── SKIN TAB ─────────────────────────────────────────────────────────────────
  Widget _buildSkinPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Skin Tone', style: TextStyle(color: VColor.textMid,
            fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(
          children: skinTones.map((c) {
            final sel = _profile.skinTone.toARGB32() == c.toARGB32();
            return Expanded(
              child: GestureDetector(
                onTap: () => _update(_profile.copyWith(skinTone: c)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 44,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: sel ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: sel
                        ? [BoxShadow(
                            color: Colors.white.withValues(alpha: 0.4),
                            blurRadius: 6)]
                        : [],
                  ),
                  child: sel
                      ? const Center(child: Icon(Icons.check, color: Colors.white, size: 18))
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── POSES TAB ────────────────────────────────────────────────────────────────
  Widget _buildPosesPanel() {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: poses.map((p) {
        final id = p['id'] as String;
        final label = p['label'] as String;
        final icon = p['icon'] as IconData;
        final sel = _profile.pose == id;
        return GestureDetector(
          onTap: () {
            _update(_profile.copyWith(pose: id));
            AvatarCustomizationService.instance.setActiveExercisePose(id);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? VColor.accentGlow : VColor.surfaceRaised,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sel ? VColor.accent : Colors.transparent),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: sel ? VColor.accent : VColor.textMid),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        color: sel ? VColor.accent : VColor.textMid,
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _colorRow(List<Color> colors, Color selected, void Function(Color) onTap) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: colors.map((c) {
          final sel = selected.toARGB32() == c.toARGB32();
          return GestureDetector(
            onTap: () => onTap(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 34, height: 34,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                    color: sel ? Colors.white : Colors.transparent, width: 3),
                boxShadow: sel
                    ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 8)]
                    : [],
              ),
              child: sel
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AVATAR PAINTER — Realistic human CustomPainter
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarPainter extends CustomPainter {
  final AvatarProfile profile;
  final double breathe; // 0..1 sine breathe

  const _AvatarPainter({required this.profile, required this.breathe});

  @override
  bool shouldRepaint(covariant _AvatarPainter old) =>
      old.breathe != breathe || old.profile != profile;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    // ── Sizing ─────────────────────────────────────────────────────────────
    final isMale = profile.gender == 'male';
    final isMuscular = profile.bodyType == 'muscular';
    final isLean = profile.bodyType == 'lean';

    final double shoulderMult = isMuscular ? 1.22 : (isLean ? 0.88 : 1.0);
    final double hipMult = isMale ? 0.72 : 0.95;

    // Proportional measurements based on canvas size
    final headR = size.height * 0.075;
    final headCy = size.height * 0.13;
    final neckH = headR * 0.6;
    final shoulderY = headCy + headR + neckH;
    final shoulderW = size.width * 0.36 * shoulderMult;
    final torsoH = size.height * 0.22;
    final torsoBottomY = shoulderY + torsoH;
    final hipW = size.width * 0.22 * hipMult;
    final kneeY = torsoBottomY + size.height * 0.23;
    final footY = kneeY + size.height * 0.18;

    final leftShoulder = Offset(cx - shoulderW / 2, shoulderY);
    final rightShoulder = Offset(cx + shoulderW / 2, shoulderY);

    final breatheOff = math.sin(breathe * math.pi) * 2.5;

    // ── Dark background circle behind avatar ───────────────────────────────
    canvas.drawCircle(
      Offset(cx, size.height * 0.5),
      size.width * 0.48,
      Paint()
        ..color = VColor.surfaceRaised.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
    );

    // ── Ground shadow ──────────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, footY + 12), width: 80, height: 14),
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );

    // ── Pose-specific joint positions ──────────────────────────────────────
    final joints = _computeJoints(
      profile.pose, cx, shoulderY, shoulderW, torsoBottomY,
      hipW, kneeY, footY, breatheOff,
    );

    // ── Draw bottom layer (legs + shoes) ───────────────────────────────────
    _drawLegs(canvas, cx, torsoBottomY, hipW, kneeY, footY, joints);

    // ── Torso ──────────────────────────────────────────────────────────────
    _drawTorso(canvas, cx, shoulderY, shoulderW, torsoBottomY, hipW, isMale);

    // ── Arms ──────────────────────────────────────────────────────────────
    _drawArms(canvas, leftShoulder, rightShoulder, joints, isMale, breatheOff);

    // ── Neck ───────────────────────────────────────────────────────────────
    final neckPaint = Paint()..color = profile.skinTone;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, shoulderY - neckH / 2 - breatheOff * 0.5),
          width: 22,
          height: neckH,
        ),
        const Radius.circular(6),
      ),
      neckPaint,
    );

    // ── Head ──────────────────────────────────────────────────────────────
    _drawHead(canvas, cx, headCy - breatheOff * 0.5, headR, isMale);

    // ── Glow aura ─────────────────────────────────────────────────────────
    final aura = 0.04 + 0.02 * math.sin(breathe * math.pi);
    canvas.drawCircle(
      Offset(cx, size.height * 0.42),
      size.width * 0.4,
      Paint()
        ..color = VColor.accent.withValues(alpha: aura)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
    );
  }

  // ── Joint positions per pose ───────────────────────────────────────────────
  Map<String, dynamic> _computeJoints(
    String pose, double cx, double shoulderY, double shoulderW,
    double torsoBottomY, double hipW, double kneeY, double footY,
    double breatheOff,
  ) {
    final lShoulder = Offset(cx - shoulderW / 2, shoulderY);
    final rShoulder = Offset(cx + shoulderW / 2, shoulderY);
    final lHip = Offset(cx - hipW / 2, torsoBottomY);
    final rHip = Offset(cx + hipW / 2, torsoBottomY);

    switch (pose) {
      case 'run':
        return {
          'lElbow': Offset(lShoulder.dx - 18, shoulderY + 55),
          'rElbow': Offset(rShoulder.dx + 10, shoulderY + 35),
          'lHand': Offset(lShoulder.dx - 8, shoulderY + 30),
          'rHand': Offset(rShoulder.dx + 22, shoulderY + 70),
          'lKnee': Offset(lHip.dx - 8, kneeY - 30),
          'rKnee': Offset(rHip.dx + 14, kneeY + 10),
          'lFoot': Offset(lHip.dx - 20, footY - 25),
          'rFoot': Offset(rHip.dx + 18, footY + 5),
        };

      case 'boxing':
        return {
          'lElbow': Offset(lShoulder.dx - 10, shoulderY + 40),
          'rElbow': Offset(rShoulder.dx + 5, shoulderY + 35),
          'lHand': Offset(cx - 40, shoulderY + 15),
          'rHand': Offset(cx + 55, shoulderY - 5),
          'lKnee': Offset(lHip.dx - 6, kneeY),
          'rKnee': Offset(rHip.dx + 6, kneeY),
          'lFoot': Offset(lHip.dx - 22, footY),
          'rFoot': Offset(rHip.dx + 22, footY),
        };

      case 'yoga':
        return {
          'lElbow': Offset(lShoulder.dx - 30, shoulderY - 10),
          'rElbow': Offset(rShoulder.dx + 30, shoulderY - 10),
          'lHand': Offset(cx - 55, shoulderY - 40),
          'rHand': Offset(cx + 55, shoulderY - 40),
          'lKnee': Offset(lHip.dx + 20, kneeY - 20),
          'rKnee': Offset(rHip.dx - 5, kneeY + 30),
          'lFoot': Offset(lHip.dx + 25, kneeY + 15),
          'rFoot': Offset(rHip.dx + 5, footY),
        };

      case 'squat':
        return {
          'lElbow': Offset(lShoulder.dx - 15, shoulderY + 55),
          'rElbow': Offset(rShoulder.dx + 15, shoulderY + 55),
          'lHand': Offset(cx - 30, shoulderY + 75),
          'rHand': Offset(cx + 30, shoulderY + 75),
          'lKnee': Offset(lHip.dx - 30, kneeY - 15),
          'rKnee': Offset(rHip.dx + 30, kneeY - 15),
          'lFoot': Offset(lHip.dx - 35, footY - 20),
          'rFoot': Offset(rHip.dx + 35, footY - 20),
        };

      case 'pushup':
        return {
          'lElbow': Offset(lShoulder.dx - 5, shoulderY + 60),
          'rElbow': Offset(rShoulder.dx + 5, shoulderY + 60),
          'lHand': Offset(lShoulder.dx - 8, shoulderY + 110),
          'rHand': Offset(rShoulder.dx + 8, shoulderY + 110),
          'lKnee': Offset(lHip.dx, kneeY + 30),
          'rKnee': Offset(rHip.dx, kneeY + 30),
          'lFoot': Offset(lHip.dx - 8, footY + 40),
          'rFoot': Offset(rHip.dx + 8, footY + 40),
        };

      case 'cycling':
        return {
          'lElbow': Offset(lShoulder.dx - 5, shoulderY + 45),
          'rElbow': Offset(rShoulder.dx + 5, shoulderY + 45),
          'lHand': Offset(cx - 38, shoulderY + 65),
          'rHand': Offset(cx + 38, shoulderY + 65),
          'lKnee': Offset(lHip.dx - 15, kneeY - 35),
          'rKnee': Offset(rHip.dx + 15, kneeY + 15),
          'lFoot': Offset(lHip.dx - 20, kneeY + 5),
          'rFoot': Offset(rHip.dx + 20, footY - 10),
        };

      case 'jump':
        return {
          'lElbow': Offset(lShoulder.dx - 28, shoulderY - 10),
          'rElbow': Offset(rShoulder.dx + 28, shoulderY - 10),
          'lHand': Offset(cx - 55, shoulderY - 50),
          'rHand': Offset(cx + 55, shoulderY - 50),
          'lKnee': Offset(lHip.dx - 20, kneeY - 30),
          'rKnee': Offset(rHip.dx + 20, kneeY - 30),
          'lFoot': Offset(lHip.dx - 25, footY - 45),
          'rFoot': Offset(rHip.dx + 25, footY - 45),
        };

      default: // idle
        return {
          'lElbow': Offset(lShoulder.dx - 14, shoulderY + 55),
          'rElbow': Offset(rShoulder.dx + 14, shoulderY + 55),
          'lHand': Offset(lShoulder.dx - 16, shoulderY + 108 - breatheOff),
          'rHand': Offset(rShoulder.dx + 16, shoulderY + 108 - breatheOff),
          'lKnee': Offset(lHip.dx - 4, kneeY),
          'rKnee': Offset(rHip.dx + 4, kneeY),
          'lFoot': Offset(lHip.dx - 12, footY),
          'rFoot': Offset(rHip.dx + 12, footY),
        };
    }
  }

  // ── Draw realistic legs ────────────────────────────────────────────────────
  void _drawLegs(Canvas canvas, double cx, double torsoBottomY,
      double hipW, double kneeY, double footY, Map<String, dynamic> j) {
    final bottoms = Paint()
      ..color = profile.outfitBottom
      ..strokeWidth = 28
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final shin = Paint()
      ..color = Color.lerp(profile.outfitBottom, Colors.black, 0.2)!
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final shoePaint = Paint()..color = const Color(0xFF1A1A2E);
    final solePaint = Paint()..color = VColor.accent;

    final lHip = Offset(cx - hipW / 2, torsoBottomY);
    final rHip = Offset(cx + hipW / 2, torsoBottomY);
    final lKnee = j['lKnee'] as Offset;
    final rKnee = j['rKnee'] as Offset;
    final lFoot = j['lFoot'] as Offset;
    final rFoot = j['rFoot'] as Offset;

    // Thighs
    canvas.drawLine(lHip, lKnee, bottoms);
    canvas.drawLine(rHip, rKnee, bottoms);

    // Shins
    canvas.drawLine(lKnee, lFoot, shin);
    canvas.drawLine(rKnee, rFoot, shin);

    // Shoes
    for (final foot in [lFoot, rFoot]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(foot.dx, foot.dy + 10), width: 36, height: 16),
          const Radius.circular(8),
        ),
        shoePaint,
      );
      // Sole stripe
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(foot.dx, foot.dy + 17), width: 38, height: 4),
          const Radius.circular(3),
        ),
        solePaint,
      );
    }
  }

  // ── Draw torso ─────────────────────────────────────────────────────────────
  void _drawTorso(Canvas canvas, double cx, double shoulderY, double shoulderW,
      double torsoBottomY, double hipW, bool isMale) {
    final topLeft = Offset(cx - shoulderW / 2, shoulderY);
    final topRight = Offset(cx + shoulderW / 2, shoulderY);
    final botLeft = Offset(cx - hipW / 2, torsoBottomY);
    final botRight = Offset(cx + hipW / 2, torsoBottomY);

    final torsoPaint = Paint()..color = profile.outfitTop;

    final torsoPath = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(botRight.dx, botRight.dy)
      ..lineTo(botLeft.dx, botLeft.dy)
      ..close();
    canvas.drawPath(torsoPath, torsoPaint);

    // Muscle shadow on chest
    if (isMale) {
      final shadow = Paint()
        ..color = Colors.black.withValues(alpha: 0.15)
        ..strokeWidth = 2;
      // Pec line
      canvas.drawLine(
        Offset(cx - 20, shoulderY + 28),
        Offset(cx + 20, shoulderY + 28),
        shadow,
      );
      // Abs center
      canvas.drawLine(
        Offset(cx, shoulderY + 35),
        Offset(cx, torsoBottomY - 8),
        shadow,
      );
    }

    // Collar
    final collar = Paint()
      ..color = profile.outfitTop.withValues(alpha: 0.6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final collarPath = Path()
      ..moveTo(cx - 14, shoulderY)
      ..lineTo(cx, shoulderY + 20)
      ..lineTo(cx + 14, shoulderY);
    canvas.drawPath(collarPath, collar);

    // Belt line at bottom
    final beltPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..strokeWidth = 5;
    canvas.drawLine(botLeft, botRight, beltPaint);
  }

  // ── Draw arms ──────────────────────────────────────────────────────────────
  void _drawArms(Canvas canvas, Offset lShoulder, Offset rShoulder,
      Map<String, dynamic> j, bool isMale, double breatheOff) {
    final upperArmW = isMale ? 20.0 : 16.0;
    final forearmW = isMale ? 16.0 : 13.0;

    final armPaint = Paint()
      ..color = profile.outfitTop
      ..strokeWidth = upperArmW
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final forearmPaint = Paint()
      ..color = profile.skinTone
      ..strokeWidth = forearmW
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final lElbow = j['lElbow'] as Offset;
    final rElbow = j['rElbow'] as Offset;
    final lHand = j['lHand'] as Offset;
    final rHand = j['rHand'] as Offset;

    // Upper arms (sleeve)
    canvas.drawLine(lShoulder, lElbow, armPaint);
    canvas.drawLine(rShoulder, rElbow, armPaint);

    // Forearms (skin)
    canvas.drawLine(lElbow, lHand, forearmPaint);
    canvas.drawLine(rElbow, rHand, forearmPaint);

    // Hands (fists)
    final handPaint = Paint()..color = profile.skinTone;
    canvas.drawCircle(lHand, 9, handPaint);
    canvas.drawCircle(rHand, 9, handPaint);

    // Boxing gloves on boxing pose
    if (profile.pose == 'boxing') {
      final glovePaint = Paint()..color = const Color(0xFFCC0000);
      canvas.drawCircle(lHand, 12, glovePaint);
      canvas.drawCircle(rHand, 12, glovePaint);
    }
  }

  // ── Draw realistic head ────────────────────────────────────────────────────
  void _drawHead(Canvas canvas, double cx, double headCy, double headR, bool isMale) {
    final skin = profile.skinTone;
    final shadow = Color.lerp(skin, Colors.black, 0.2)!;

    // Head oval
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, headCy),
        width: headR * 1.85,
        height: headR * 2.1,
      ),
      Paint()..color = skin,
    );

    // Jaw shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, headCy + headR * 0.55),
        width: headR * 1.4,
        height: headR * 0.7,
      ),
      Paint()..color = shadow.withValues(alpha: 0.2),
    );

    // ── Hair ────────────────────────────────────────────────────────────────
    _drawHair(canvas, cx, headCy, headR, isMale);

    // ── Eyes ────────────────────────────────────────────────────────────────
    final eyeY = headCy - headR * 0.1;
    final eyeSpacing = headR * 0.48;
    _drawEye(canvas, cx - eyeSpacing, eyeY, headR * 0.19);
    _drawEye(canvas, cx + eyeSpacing, eyeY, headR * 0.19);

    // Eyebrows
    final browPaint = Paint()
      ..color = profile.hairColor
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final browOff = isMale ? 0.0 : -1.0;
    canvas.drawLine(
      Offset(cx - eyeSpacing - 12, eyeY - headR * 0.3 + browOff),
      Offset(cx - eyeSpacing + 12, eyeY - headR * 0.28 + browOff),
      browPaint,
    );
    canvas.drawLine(
      Offset(cx + eyeSpacing - 12, eyeY - headR * 0.28 + browOff),
      Offset(cx + eyeSpacing + 12, eyeY - headR * 0.3 + browOff),
      browPaint,
    );

    // ── Nose ────────────────────────────────────────────────────────────────
    final nosePath = Path()
      ..moveTo(cx, headCy)
      ..quadraticBezierTo(cx - 6, headCy + headR * 0.35, cx - 5, headCy + headR * 0.38)
      ..quadraticBezierTo(cx, headCy + headR * 0.42, cx + 5, headCy + headR * 0.38)
      ..quadraticBezierTo(cx + 6, headCy + headR * 0.35, cx, headCy);
    canvas.drawPath(
      nosePath,
      Paint()
        ..color = shadow.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // ── Lips ────────────────────────────────────────────────────────────────
    final lipY = headCy + headR * 0.6;
    final lipColor = isMale
        ? Color.lerp(skin, Colors.red, 0.2)!
        : Color.lerp(Colors.red, Colors.pink, 0.3)!;

    // Upper lip
    final upperLip = Path()
      ..moveTo(cx - 13, lipY)
      ..cubicTo(cx - 8, lipY - 4, cx - 3, lipY - 6, cx, lipY - 3)
      ..cubicTo(cx + 3, lipY - 6, cx + 8, lipY - 4, cx + 13, lipY);
    canvas.drawPath(
      upperLip,
      Paint()
        ..color = lipColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Lower lip
    canvas.drawPath(
      Path()
        ..moveTo(cx - 11, lipY)
        ..cubicTo(cx - 6, lipY + 6, cx + 6, lipY + 6, cx + 11, lipY),
      Paint()
        ..color = lipColor
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // ── Cheeks (female) ────────────────────────────────────────────────────
    if (!isMale) {
      final blush = Paint()
        ..color = Colors.pink.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(cx - eyeSpacing - 4, eyeY + 12), 9, blush);
      canvas.drawCircle(Offset(cx + eyeSpacing + 4, eyeY + 12), 9, blush);
    }
  }

  // ── Realistic eye ──────────────────────────────────────────────────────────
  void _drawEye(Canvas canvas, double ex, double ey, double r) {
    // Whites
    canvas.drawOval(
      Rect.fromCenter(center: Offset(ex, ey), width: r * 2.2, height: r * 1.4),
      Paint()..color = Colors.white,
    );
    // Iris
    canvas.drawCircle(Offset(ex, ey), r * 0.75,
        Paint()..color = const Color(0xFF3D2B1F));
    // Pupil
    canvas.drawCircle(Offset(ex, ey), r * 0.4,
        Paint()..color = Colors.black);
    // Highlight
    canvas.drawCircle(Offset(ex - r * 0.2, ey - r * 0.25), r * 0.2,
        Paint()..color = Colors.white.withValues(alpha: 0.9));
    // Eyelid line
    canvas.drawArc(
      Rect.fromCenter(center: Offset(ex, ey), width: r * 2.2, height: r * 1.4),
      math.pi, math.pi,
      false,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.7)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
  }

  // ── Hair styles ────────────────────────────────────────────────────────────
  void _drawHair(Canvas canvas, double cx, double headCy, double headR, bool isMale) {
    if (profile.hairStyle == 'bald') return;

    final hairPaint = Paint()..color = profile.hairColor;
    final darkHair = Paint()
      ..color = Color.lerp(profile.hairColor, Colors.black, 0.35)!;

    switch (profile.hairStyle) {
      case 'short':
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx, headCy - headR * 0.35),
            width: headR * 1.9, height: headR * 1.3,
          ),
          hairPaint,
        );
        // Sides
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx - headR * 0.78, headCy),
            width: headR * 0.6, height: headR * 1.1,
          ),
          hairPaint,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx + headR * 0.78, headCy),
            width: headR * 0.6, height: headR * 1.1,
          ),
          hairPaint,
        );
        break;

      case 'medium':
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx, headCy - headR * 0.4),
            width: headR * 2.0, height: headR * 1.5,
          ),
          hairPaint,
        );
        // Side curtains
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(cx - headR * 0.85, headCy + headR * 0.4),
              width: headR * 0.5, height: headR * 1.4,
            ),
            const Radius.circular(8),
          ),
          hairPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(cx + headR * 0.85, headCy + headR * 0.4),
              width: headR * 0.5, height: headR * 1.4,
            ),
            const Radius.circular(8),
          ),
          hairPaint,
        );
        break;

      case 'long':
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx, headCy - headR * 0.3),
            width: headR * 1.95, height: headR * 1.4,
          ),
          hairPaint,
        );
        // Long flowing sides
        final longHairL = Path()
          ..moveTo(cx - headR * 0.9, headCy)
          ..quadraticBezierTo(
            cx - headR * 1.1, headCy + headR * 1.2,
            cx - headR * 0.8, headCy + headR * 2.0,
          );
        final longHairR = Path()
          ..moveTo(cx + headR * 0.9, headCy)
          ..quadraticBezierTo(
            cx + headR * 1.1, headCy + headR * 1.2,
            cx + headR * 0.8, headCy + headR * 2.0,
          );
        canvas.drawPath(
          longHairL,
          Paint()
            ..color = profile.hairColor
            ..strokeWidth = 18
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
        canvas.drawPath(
          longHairR,
          Paint()
            ..color = profile.hairColor
            ..strokeWidth = 18
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
        break;

      case 'bun':
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx, headCy - headR * 0.3),
            width: headR * 1.9, height: headR * 1.3,
          ),
          hairPaint,
        );
        // Bun on top
        canvas.drawCircle(
          Offset(cx, headCy - headR * 1.15),
          headR * 0.4,
          hairPaint,
        );
        // Bun shadow
        canvas.drawCircle(
          Offset(cx + headR * 0.1, headCy - headR * 1.1),
          headR * 0.22,
          darkHair,
        );
        break;

      case 'curly':
        // Curly base
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx, headCy - headR * 0.4),
            width: headR * 2.1, height: headR * 1.6,
          ),
          hairPaint,
        );
        // Curly bumps
        for (int i = 0; i < 8; i++) {
          final angle = (i / 8) * math.pi * 2;
          final bx = cx + math.cos(angle) * headR * 0.85;
          final by = headCy - headR * 0.4 + math.sin(angle) * headR * 0.65;
          canvas.drawCircle(Offset(bx, by), headR * 0.28, hairPaint);
        }
        break;
    }
  }
}
