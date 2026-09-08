import 'package:flutter/material.dart';

/// VYRA design tokens — extracted directly from the Stitch export's own
/// Tailwind config (Material 3 dark scheme), not approximated. Three
/// accents, each meaning one thing, exactly as Stitch uses them:
///   cyan   (#00d2ff) — vitals: heart rate, pace, "live" indicators
///   green  (#34ff8c) — AI/positive state: steps, streaks, "plan ready"
///   orange (#ffaf81) — energy: calories burned
/// A screen that uses only cyan is not matching the reference UI — the
/// three-accent system is the whole point of how it reads as "alive".
class VColor {
  const VColor._();

  static const bg = Color(0xFF0F131D); // Stitch: background / surface
  static const bgLift = Color(0xFF0A0E17); // surface-container-lowest
  static const surface = Color(0xFF171C25); // surface-container-low — most cards
  static const surfaceRaised = Color(0xFF1B2029); // surface-container — nested elements
  static const surfaceHigh = Color(0xFF262A34); // surface-container-high — badges/pills
  static const surfaceHighest = Color(0xFF31353F); // surface-container-highest — progress tracks

  static const line = Color(0x3C859399); // outline, ~24% — subtle card borders
  static const lineSoft = Color(0x1E859399); // outline, ~12%

  static const text = Color(0xFFDFE2F0); // on-surface
  static const textMid = Color(0xFFBBC9CF); // on-surface-variant
  static const textLow = Color(0xFF859399); // outline, used directly as muted text/icons
  static const textOnAccent = Color(0xFF003543); // on-primary — dark text on a cyan/green fill

  static const accent = Color(0xFF00D2FF); // primary-container — cyan
  static const accentDeep = Color(0xFF0099B8);
  static const accentGlow = Color(0x2E00D2FF);

  static const accentGreen = Color(0xFF34FF8C); // secondary-container
  static const accentGreenGlow = Color(0x2E34FF8C);

  static const accentOrange = Color(0xFFFFAF81); // tertiary-container
  static const accentOrangeGlow = Color(0x2EFFAF81);

  static const good = accentGreen; // success/streak — same green as the AI-status accent
  static const warn = Color(0xFFFFC93C);
  static const warnSoft = Color(0x1FFFC93C);
  static const crit = Color(0xFFFFB4AB); // Stitch: error
  static const critSoft = Color(0x1F93000A); // Stitch: error-container, used as a soft fill

  static const steel = Color(0xFF3C494E); // outline-variant

  // Workout calendar states
  static const calDone = good;
  static const calPartial = warn;
  static const calMissed = crit;
  static const calRest = steel;

  // Leaderboard tiers
  static const bronze = Color(0xFFCD7F32);
  static const silver = Color(0xFFC0C6D4);
  static const gold = Color(0xFFFFC93C);
  static const platinum = Color(0xFF7FE7DC);
  static const diamond = Color(0xFF8AD8FF);

  static Color tier(String name) => switch (name) {
        'silver' => silver,
        'gold' => gold,
        'platinum' => platinum,
        'diamond' => diamond,
        _ => bronze,
      };

  /// One hue per health metric, used identically on every screen so a colour
  /// always means the same thing. Mirrors Stitch's own metric-to-accent
  /// mapping (steps=green, calories=orange, heart-rate/vitals=cyan).
  static Color metric(String key) => switch (key) {
        'waterMl' => accent,
        'steps' => accentGreen,
        'caloriesBurned' => accentOrange,
        'heartRateBpm' => const Color(0xFFFF5C7A),
        'bpSystolic' || 'bpDiastolic' => const Color(0xFFB47CFF),
        'spo2' => accent,
        'glucoseMgDl' => warn,
        _ => textMid,
      };
}

/// 4pt spacing scale. Every gap in the app is one of these.
class VSpace {
  const VSpace._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 44;
}

class VRadius {
  const VRadius._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 22;
  static const double pill = 999;
}

/// Minimum touch target, enforced in the button widgets rather than left to
/// each screen — accessibility that relies on everyone remembering eventually
/// stops being accessible.
const double kMinTouchTarget = 48;

ThemeData buildVyraTheme() {
  const base = ColorScheme.dark(
    primary: VColor.accent,
    onPrimary: VColor.textOnAccent,
    secondary: VColor.accentDeep,
    surface: VColor.surface,
    onSurface: VColor.text,
    error: VColor.crit,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: base,
    scaffoldBackgroundColor: VColor.bg,
    fontFamily: 'Inter',
    splashFactory: InkRipple.splashFactory,

    textTheme: const TextTheme(
      displaySmall: TextStyle(
        color: VColor.text, fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.8, height: 1.1),
      headlineMedium: TextStyle(
        color: VColor.text, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.15),
      headlineSmall: TextStyle(
        color: VColor.text, fontSize: 21, fontWeight: FontWeight.w600, letterSpacing: -0.3),
      titleMedium: TextStyle(
        color: VColor.text, fontSize: 17, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: VColor.textMid, fontSize: 15, height: 1.45),
      bodyMedium: TextStyle(color: VColor.textMid, fontSize: 13.5, height: 1.45),
      labelSmall: TextStyle(
        color: VColor.textLow, fontSize: 10.5, letterSpacing: 1.3, fontWeight: FontWeight.w500),
    ),

    // CardThemeData, not CardTheme — renamed in Flutter 3.27+.
    cardTheme: CardThemeData(
      color: VColor.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VRadius.lg),
        side: const BorderSide(color: VColor.line),
      ),
      margin: EdgeInsets.zero,
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: VColor.accent,
        foregroundColor: VColor.textOnAccent,
        minimumSize: const Size(0, kMinTouchTarget),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.pill)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: VColor.text,
        minimumSize: const Size(0, kMinTouchTarget),
        side: const BorderSide(color: VColor.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.pill)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: VColor.bgLift,
      indicatorColor: VColor.accentGlow,
      height: 66,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 10.5,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
          color: states.contains(WidgetState.selected) ? VColor.accent : VColor.textLow,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected) ? VColor.accent : VColor.textLow,
        ),
      ),
    ),

    dividerTheme: const DividerThemeData(color: VColor.lineSoft, thickness: 1, space: 1),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: VColor.bgLift,
      hintStyle: const TextStyle(color: VColor.textLow, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: VSpace.base, vertical: VSpace.md),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VRadius.md),
        borderSide: const BorderSide(color: VColor.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VRadius.md),
        borderSide: const BorderSide(color: VColor.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VRadius.md),
        borderSide: const BorderSide(color: VColor.accent, width: 1.5),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: VColor.surfaceRaised,
      contentTextStyle: const TextStyle(color: VColor.text, fontSize: 14),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.md)),
    ),
  );
}
