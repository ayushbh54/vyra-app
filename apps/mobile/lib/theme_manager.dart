import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';

class ThemeManager {
  ThemeManager._();
  static final ThemeManager instance = ThemeManager._();

  static const String _prefKey = 'vyra_theme_mode';

  final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  bool get isDark => themeModeNotifier.value == ThemeMode.dark;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_prefKey);
      if (savedMode == 'dark') {
        themeModeNotifier.value = ThemeMode.dark;
        VColor.isDark = true;
      } else {
        // Default to Classic Bright Light Mode as requested by user
        themeModeNotifier.value = ThemeMode.light;
        VColor.isDark = false;
      }
    } catch (_) {
      themeModeNotifier.value = ThemeMode.light;
      VColor.isDark = false;
    }
  }

  Future<void> toggleTheme() async {
    if (isDark) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    VColor.isDark = (mode == ThemeMode.dark);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, mode == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }
}
