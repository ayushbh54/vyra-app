// lib/widgets/daily_slogan_banner.dart
//
// VYRA DailySloganBanner — animated motivational slogan card.
//
// • Slides in from the top with a spring curve.
// • Gradient background: dark surface → cyan glow (#00d2ff).
// • Shows emoji + slogan text, language-aware.
// • Tap to dismiss (slides back up) OR auto-dismisses after 5 s.
// • Use [DailySloganBanner.show] as a static helper on any screen.

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/motivation_service.dart';

// ---------------------------------------------------------------------------
// Design tokens (mirrors VColor / VSpace / VRadius constants)
// ---------------------------------------------------------------------------
class _V {
  static const Color bg          = Color(0xFF0A0A0F);
  static const Color surface     = Color(0xFF13131A);
  static const Color accent      = Color(0xFF00D2FF);
  static const Color accentGreen = Color(0xFF34FF8C);
  static const Color text        = Color(0xFFFFFFFF);
  static const Color textMid     = Color(0xFFB0B0C3);
  static const Color line        = Color(0xFF1E1E2E);
  static const Color accentGlow  = Color(0x3300D2FF); // 20% opacity cyan

  static const double xs   = 4;
  static const double sm   = 8;
  static const double base = 16;
  static const double lg   = 24;
  static const double xl   = 32;

  static const double radiusMd  = 8;
  static const double radiusLg  = 12;
  static const double radiusPill = 100;
}

// ---------------------------------------------------------------------------
// DailySloganBanner
// ---------------------------------------------------------------------------

/// Animated VYRA motivational banner.
///
/// Typical usage — call from a screen's initState / post-workout callback:
/// ```dart
/// DailySloganBanner.show(
///   context: context,
///   streakDays: 7,
///   language: 'hi',
/// );
/// ```
class DailySloganBanner extends StatefulWidget {
  const DailySloganBanner({
    super.key,
    required this.slogan,
    this.onDismissed,
  });

  /// The slogan to display.
  final VyraSlogan slogan;

  /// Optional callback when the banner is dismissed.
  final VoidCallback? onDismissed;

  // ── Static convenience helper ──────────────────────────────────────────

  /// Fetches a fresh slogan and injects the banner as an [OverlayEntry].
  ///
  /// [sloganContext] maps to [MotivationService.getSlogan] context param.
  static Future<void> show({
    required BuildContext context,
    String sloganContext = 'home',
    int streakDays = 0,
    int? daysSinceLastWorkout,
    String language = 'en',
  }) async {
    final slogan = await MotivationService.instance.getSlogan(
      context: sloganContext,
      streakDays: streakDays,
      daysSinceLastWorkout: daysSinceLastWorkout,
      language: language,
    );

    if (!context.mounted) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => DailySloganBanner(
        slogan: slogan,
        onDismissed: () => entry.remove(),
      ),
    );
    Overlay.of(context).insert(entry);
  }

  @override
  State<DailySloganBanner> createState() => _DailySloganBannerState();
}

// ---------------------------------------------------------------------------
// State — animation controller + timer
// ---------------------------------------------------------------------------

class _DailySloganBannerState extends State<DailySloganBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset>   _slide;
  late final Animation<double>   _fade;

  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    // Slide from (-1, 0) → (0, 0) — enters from the top
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end:   Offset.zero,
    ).animate(CurvedAnimation(
      parent: _ctrl,
      curve:   Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    ));

    _fade = CurvedAnimation(
      parent: _ctrl,
      curve:   const Interval(0.0, 0.6, curve: Curves.easeIn),
      reverseCurve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );

    // Enter
    _ctrl.forward();

    // Auto-dismiss after 5 seconds
    _autoTimer = Timer(const Duration(seconds: 5), _dismiss);
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    _autoTimer?.cancel();
    await _ctrl.reverse();
    widget.onDismissed?.call();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(
            opacity: _fade,
            child: GestureDetector(
              onTap: _dismiss,
              // Also allow swipe-up to dismiss
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! < -200) {
                  _dismiss();
                }
              },
              child: _BannerCard(slogan: widget.slogan),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _BannerCard — pure visual, no state
// ---------------------------------------------------------------------------

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.slogan});
  final VyraSlogan slogan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: _V.base, vertical: _V.sm),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_V.radiusLg),
          // Subtle cyan glow border
          border: Border.all(color: _V.accentGlow, width: 1.2),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF13131A), // VColor.surface
              Color(0xFF0D1E26), // dark teal hint
              Color(0xFF0A1520), // deeper edge
            ],
            stops: [0.0, 0.6, 1.0],
          ),
          boxShadow: const [
            // Cyan glow underneath the card
            BoxShadow(
              color: Color(0x4400D2FF),
              blurRadius: 24,
              spreadRadius: 0,
              offset: Offset(0, 6),
            ),
            BoxShadow(
              color: Color(0xBB0A0A0F),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: _V.lg, vertical: _V.base),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Emoji badge ─────────────────────────────────────────────
              _EmojiBadge(emoji: slogan.emoji, category: slogan.category),
              const SizedBox(width: _V.base),
              // ── Slogan text ─────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category label
                    Text(
                      _categoryLabel(slogan.category, slogan.language),
                      style: const TextStyle(
                        color: _V.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: _V.xs),
                    // Slogan body
                    Text(
                      slogan.text,
                      style: TextStyle(
                        color: _V.text,
                        fontSize: slogan.language == 'hi' ? 14 : 13.5,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                        // Use a font that renders Devanagari well when Hindi
                        fontFamily: slogan.language == 'hi' ? 'Noto Sans' : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: _V.sm),
              // ── Dismiss hint ─────────────────────────────────────────────
              const Icon(
                Icons.keyboard_arrow_up_rounded,
                color: _V.textMid,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Human-readable category label, language-aware.
  String _categoryLabel(SloganCategory cat, String lang) {
    if (lang == 'hi') {
      switch (cat) {
        case SloganCategory.morningFire:     return 'VYRA • सुबह की ऊर्जा';
        case SloganCategory.middayPush:      return 'VYRA • दोपहर की ताकत';
        case SloganCategory.afternoonGrind:  return 'VYRA • शाम की मेहनत';
        case SloganCategory.eveningWarrior:  return 'VYRA • सायं योद्धा';
        case SloganCategory.nightChampion:   return 'VYRA • रात के चैम्पियन';
        case SloganCategory.restDayRecharge: return 'VYRA • आराम का दिन';
        case SloganCategory.streakMilestone: return 'VYRA • स्ट्रीक माइलस्टोन';
        case SloganCategory.goalAchieved:    return 'VYRA • लक्ष्य हासिल!';
        case SloganCategory.comeback:        return 'VYRA • वापसी';
      }
    }
    switch (cat) {
      case SloganCategory.morningFire:     return 'VYRA • MORNING FIRE';
      case SloganCategory.middayPush:      return 'VYRA • MIDDAY PUSH';
      case SloganCategory.afternoonGrind:  return 'VYRA • AFTERNOON GRIND';
      case SloganCategory.eveningWarrior:  return 'VYRA • EVENING WARRIOR';
      case SloganCategory.nightChampion:   return 'VYRA • NIGHT CHAMPION';
      case SloganCategory.restDayRecharge: return 'VYRA • REST & RECHARGE';
      case SloganCategory.streakMilestone: return 'VYRA • STREAK MILESTONE 🔥';
      case SloganCategory.goalAchieved:    return 'VYRA • GOAL ACHIEVED!';
      case SloganCategory.comeback:        return 'VYRA • COMEBACK';
    }
  }
}

// ---------------------------------------------------------------------------
// _EmojiBadge — glowing circular emoji container
// ---------------------------------------------------------------------------

class _EmojiBadge extends StatelessWidget {
  const _EmojiBadge({required this.emoji, required this.category});
  final String emoji;
  final SloganCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _badgeColor(category).withOpacity(0.12),
        border: Border.all(
          color: _badgeColor(category).withOpacity(0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _badgeColor(category).withOpacity(0.25),
            blurRadius: 14,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 22)),
      ),
    );
  }

  Color _badgeColor(SloganCategory cat) {
    switch (cat) {
      case SloganCategory.morningFire:
      case SloganCategory.streakMilestone:
        return const Color(0xFFFF6B35); // orange-fire
      case SloganCategory.middayPush:
      case SloganCategory.nightChampion:
        return _V.accent; // cyan
      case SloganCategory.afternoonGrind:
      case SloganCategory.eveningWarrior:
        return _V.accentGreen; // green
      case SloganCategory.restDayRecharge:
        return const Color(0xFF8B5CF6); // violet
      case SloganCategory.goalAchieved:
        return const Color(0xFFFFD700); // gold
      case SloganCategory.comeback:
        return const Color(0xFFFF3D71); // red
    }
  }
}
