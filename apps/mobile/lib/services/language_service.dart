import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// All 17 languages VYRA supports.
///
/// Each entry: (languageCode, countryCode?, nativeName, displayName, flagEmoji)
const List<VyraLanguage> kVyraLanguages = [
  VyraLanguage('hi', null,   'हिन्दी',         'Hindi',             '🇮🇳'),
  VyraLanguage('en', 'IN',   'English (India)', 'English (India)',   '🇮🇳'),
  VyraLanguage('en', 'GB',   'English (UK)',    'English (British)', '🇬🇧'),
  VyraLanguage('en', 'US',   'English (US)',    'English (American)','🇺🇸'),
  VyraLanguage('ta', null,   'தமிழ்',           'Tamil',             '🇮🇳'),
  VyraLanguage('te', null,   'తెలుగు',          'Telugu',            '🇮🇳'),
  VyraLanguage('ml', null,   'മലയാളം',          'Malayalam',         '🇮🇳'),
  VyraLanguage('pa', null,   'ਪੰਜਾਬੀ',          'Punjabi',           '🇮🇳'),
  VyraLanguage('kn', null,   'ಕನ್ನಡ',           'Kannada',           '🇮🇳'),
  VyraLanguage('mr', null,   'मराठी',           'Marathi',           '🇮🇳'),
  VyraLanguage('bn', null,   'বাংলা',           'Bengali',           '🇮🇳'),
  VyraLanguage('gu', null,   'ગુજરાતી',         'Gujarati',          '🇮🇳'),
  VyraLanguage('fr', null,   'Français',        'French',            '🇫🇷'),
  VyraLanguage('de', null,   'Deutsch',         'German',            '🇩🇪'),
  VyraLanguage('es', null,   'Español',         'Spanish',           '🇪🇸'),
  VyraLanguage('pt', null,   'Português',       'Portuguese',        '🇧🇷'),
  VyraLanguage('nl', null,   'Nederlands',      'Dutch',             '🇳🇱'),
];

class VyraLanguage {
  const VyraLanguage(
    this.languageCode,
    this.countryCode,
    this.nativeName,
    this.displayName,
    this.flag,
  );

  final String languageCode;
  final String? countryCode;
  final String nativeName;
  final String displayName;
  final String flag;

  Locale get locale => Locale(languageCode, countryCode);

  /// Persisted key used in SharedPreferences.
  String get prefsKey =>
      countryCode != null ? '${languageCode}_$countryCode' : languageCode;

  static VyraLanguage fromPrefsKey(String key) {
    return kVyraLanguages.firstWhere(
      (l) => l.prefsKey == key,
      orElse: () => kVyraLanguages.first, // fallback → Hindi
    );
  }
}

/// Global provider — wraps [Locale] in a [ValueNotifier] so [MaterialApp]
/// can react to it immediately without a full restart.
class LanguageService extends ChangeNotifier {
  static const _kPrefsKey = 'vyra_language';

  LanguageService._();
  static final instance = LanguageService._();

  VyraLanguage _current = kVyraLanguages[0]; // Hindi by default
  bool _loaded = false;

  VyraLanguage get current => _current;
  Locale get locale => _current.locale;
  bool get isLoaded => _loaded;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kPrefsKey);
    if (saved != null) {
      _current = VyraLanguage.fromPrefsKey(saved);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLanguage(VyraLanguage lang) async {
    if (_current.prefsKey == lang.prefsKey) return;
    _current = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, lang.prefsKey);
  }
}
