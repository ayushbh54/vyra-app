import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

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

  static bool isDark = false;

  // Canvas / Surface — Calibrated comfortable obsidian surfaces
  static const Color bg = Color(0xFF0F131D);
  static const Color bgLift = Color(0xFF0A0E17);
  static const Color surface = Color(0xFF171C25);
  static const Color surfaceRaised = Color(0xFF1B2029);
  static const Color surfaceHigh = Color(0xFF262A34);
  static const Color surfaceHighest = Color(0xFF31353F);

  // Borders — soft non-glaring borders
  static const Color line = Color(0x3C859399);
  static const Color lineSoft = Color(0x1E859399);

  // Typography — readable, eye-friendly slate typography
  static const Color text = Color(0xFFDFE2F0);
  static const Color textMid = Color(0xFFBBC9CF);
  static const Color textLow = Color(0xFF859399);
  static const Color textMuted = textLow;
  static const Color textDim = textLow;
  static const Color textOnAccent = Color(0xFF003543);

  // Accents — balanced Stitch brand tones
  static const Color accent = Color(0xFF00D2FF);
  static const Color accentCyan = Color(0xFF00D2FF);
  static const Color accentDeep = Color(0xFF0099B8);
  static const Color accentGlow = Color(0x2E00D2FF);

  static const Color accentGreen = Color(0xFF34FF8C);
  static const Color accentGreenGlow = Color(0x2E34FF8C);

  static const Color accentOrange = Color(0xFFFF7700);
  static const Color accentOrangeGlow = Color(0x33FF7700);
  static const Color accentOrangeSoft = Color(0xFFFFAF81);

  static const Color good = accentGreen;
  static const Color warn = Color(0xFFFFC93C);
  static const Color warnSoft = Color(0x1FFFC93C);
  static const Color crit = Color(0xFFFFB4AB);
  static const Color critSoft = Color(0x1F93000A);

  static const Color steel = Color(0xFF3C494E);

  // Workout calendar states
  static const Color calDone = good;
  static const Color calPartial = warn;
  static const Color calMissed = crit;
  static const Color calRest = steel;

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

/// 4pt spacing scale.
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
  static const double full = 999;
}

const double kMinTouchTarget = 48;

ThemeData buildVyraTheme() => VColor.isDark ? buildVyraDarkTheme() : buildVyraLightTheme();

ThemeData buildVyraLightTheme() {
  const base = ColorScheme.light(
    primary: Color(0xFF0284C7),
    onPrimary: Colors.white,
    secondary: Color(0xFF0369A1),
    surface: Colors.white,
    onSurface: Color(0xFF0F172A),
    error: Color(0xFFEF4444),
    outline: Color(0xFFE2E8F0),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: base,
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    fontFamily: 'Inter',
    splashFactory: InkRipple.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF0F172A),
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        color: Color(0xFF0F172A), fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.8, height: 1.1),
      headlineMedium: TextStyle(
        color: Color(0xFF0F172A), fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.15),
      headlineSmall: TextStyle(
        color: Color(0xFF0F172A), fontSize: 21, fontWeight: FontWeight.w600, letterSpacing: -0.3),
      titleMedium: TextStyle(
        color: Color(0xFF0F172A), fontSize: 17, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: Color(0xFF475569), fontSize: 15, height: 1.45),
      bodyMedium: TextStyle(color: Color(0xFF475569), fontSize: 13.5, height: 1.45),
      labelSmall: TextStyle(
        color: Color(0xFF94A3B8), fontSize: 10.5, letterSpacing: 1.3, fontWeight: FontWeight.w500),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VRadius.lg),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        minimumSize: const Size(0, kMinTouchTarget),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.pill)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF0F172A),
        minimumSize: const Size(0, kMinTouchTarget),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.pill)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFFE0F2FE),
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? const Color(0xFF0284C7) : const Color(0xFF64748B),
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected) ? const Color(0xFF0284C7) : const Color(0xFF64748B),
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFE2E8F0), thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: VSpace.base, vertical: VSpace.md),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VRadius.md),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VRadius.md),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VRadius.md),
        borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF0F172A),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.md)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
      },
    ),
  );
}

ThemeData buildVyraDarkTheme() {
  const base = ColorScheme.dark(
    primary: Color(0xFF00D2FF),
    onPrimary: Color(0xFF003543),
    secondary: Color(0xFF0099B8),
    surface: Color(0xFF171C25),
    onSurface: Color(0xFFDFE2F0),
    error: Color(0xFFFFB4AB),
    outline: Color(0x3C859399),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: base,
    scaffoldBackgroundColor: const Color(0xFF0F131D),
    fontFamily: 'Inter',
    splashFactory: InkRipple.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF171C25),
      foregroundColor: Color(0xFFDFE2F0),
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: Color(0xFFDFE2F0),
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        color: Color(0xFFDFE2F0), fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.8, height: 1.1),
      headlineMedium: TextStyle(
        color: Color(0xFFDFE2F0), fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.15),
      headlineSmall: TextStyle(
        color: Color(0xFFDFE2F0), fontSize: 21, fontWeight: FontWeight.w600, letterSpacing: -0.3),
      titleMedium: TextStyle(
        color: Color(0xFFDFE2F0), fontSize: 17, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: Color(0xFFBBC9CF), fontSize: 15, height: 1.45),
      bodyMedium: TextStyle(color: Color(0xFFBBC9CF), fontSize: 13.5, height: 1.45),
      labelSmall: TextStyle(
        color: Color(0xFF859399), fontSize: 10.5, letterSpacing: 1.3, fontWeight: FontWeight.w500),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF171C25),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VRadius.lg),
        side: const BorderSide(color: Color(0x3C859399)),
      ),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF00D2FF),
        foregroundColor: const Color(0xFF003543),
        minimumSize: const Size(0, kMinTouchTarget),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.pill)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFDFE2F0),
        minimumSize: const Size(0, kMinTouchTarget),
        side: const BorderSide(color: Color(0x3C859399)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.pill)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF0A0E17),
      indicatorColor: const Color(0x2E00D2FF),
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 10.5,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
          color: states.contains(WidgetState.selected) ? const Color(0xFF00D2FF) : const Color(0xFF859399),
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected) ? const Color(0xFF00D2FF) : const Color(0xFF859399),
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Color(0x1E859399), thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0A0E17),
      hintStyle: const TextStyle(color: Color(0xFF859399), fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: VSpace.base, vertical: VSpace.md),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VRadius.md),
        borderSide: const BorderSide(color: Color(0x3C859399)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VRadius.md),
        borderSide: const BorderSide(color: Color(0x3C859399)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VRadius.md),
        borderSide: const BorderSide(color: Color(0xFF00D2FF), width: 1.5),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF1B2029),
      contentTextStyle: const TextStyle(color: Color(0xFFDFE2F0), fontSize: 14),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.md)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
      },
    ),
  );
}
