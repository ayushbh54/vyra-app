import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight Gemini response cache.
/// Caches non-personalized AI responses to avoid redundant API calls.
/// Personalized queries (containing user-specific words) are never cached.
class GeminiResponseCache {
  GeminiResponseCache._();
  static final instance = GeminiResponseCache._();

  static const _prefix = 'gai_cache_v1_';
  static const _ttlMs = 24 * 60 * 60 * 1000; // 24 hours

  // Words that indicate a personalized query — never cache these.
  // INTENTIONALLY NARROW: generic questions like "how many calories in a banana"
  // or "best dumbbell weight for biceps" are NOT personalized and SHOULD be cached.
  static const _personalWords = [
    'my ', ' i ', "i'", 'me ', 'mine', 'today', 'yesterday',
    'feel', 'feeling', 'hurt', 'pain',
    'mera ', 'meri ', 'mujhe', 'aaj ',
    'live_heart_rate', 'live_steps', 'my report', 'my blood',
  ];

  bool _isPersonalized(String query) {
    final q = query.toLowerCase();
    return _personalWords.any((w) => q.contains(w));
  }

  /// Stable djb2 hash — deterministic across all Dart runtimes and app reinstalls.
  /// Unlike Dart's built-in hashCode, this never changes between sessions.
  static int _djb2(String s) {
    int h = 5381;
    for (final c in s.codeUnits) {
      h = ((h << 5) + h + c) & 0x1FFFFFFF;
    }
    return h.abs();
  }

  String _cacheKey(String query) {
    final normalized = query.toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .trim();
    return '$_prefix${_djb2(normalized)}';
  }

  /// Returns cached response if available and fresh. Returns null if cache miss.
  Future<String?> get(String query) async {
    if (_isPersonalized(query)) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _cacheKey(query);
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final ts = data['ts'] as int? ?? 0;
      if (DateTime.now().millisecondsSinceEpoch - ts > _ttlMs) {
        prefs.remove(key); // expired
        return null;
      }
      return data['r'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Saves response to cache. Skips personalized queries automatically.
  Future<void> set(String query, String response) async {
    if (_isPersonalized(query)) return;
    if (response.length < 20) return; // too short to cache
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey(query),
        jsonEncode({'r': response, 'ts': DateTime.now().millisecondsSinceEpoch}),
      );
    } catch (_) {}
  }

  /// Evicts all expired cache entries (call on app start, max once per day)
  Future<void> evictExpired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final k in keys) {
        try {
          final raw = prefs.getString(k);
          if (raw == null) continue;
          final ts = (jsonDecode(raw) as Map)['ts'] as int? ?? 0;
          if (now - ts > _ttlMs) await prefs.remove(k);
        } catch (_) {}
      }
    } catch (_) {}
  }
}
