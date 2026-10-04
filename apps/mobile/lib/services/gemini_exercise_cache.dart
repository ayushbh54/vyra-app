import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/models.dart';

/// Gemini-powered exercise detail generator with permanent SharedPreferences cache.
/// Called ONLY when the backend API returns no data for an exercise slug.
/// Once generated, data is cached forever — Gemini is NEVER called twice for the same exercise.
class GeminiExerciseCacheService {
  GeminiExerciseCacheService._();
  static final instance = GeminiExerciseCacheService._();

  static const _prefix = 'gemini_ex_v1_';
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  /// Returns a LibraryItem for the given slug.
  /// 1. Checks SharedPreferences cache first (permanent).
  /// 2. If not cached, calls Gemini once, saves result, returns it.
  /// 3. If Gemini fails, returns a safe structural fallback.
  Future<LibraryItem> getOrGenerate(String slug, String displayName) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_prefix${slug.replaceAll(RegExp(r'[^a-z0-9]'), '_')}';

    // ── Cache hit: return immediately, zero Gemini cost ──
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      try {
        final map = jsonDecode(cached) as Map<String, dynamic>;
        return _fromMap(slug, map);
      } catch (_) {}
    }

    // ── Cache miss: call Gemini ONCE ──
    LibraryItem item;
    try {
      item = await _generateFromGemini(slug, displayName);
    } catch (_) {
      item = _structuralFallback(slug, displayName);
    }

    // Save permanently — never call Gemini again for this exercise
    try {
      await prefs.setString(cacheKey, jsonEncode(_toMap(item)));
    } catch (_) {}

    return item;
  }

  Future<LibraryItem> _generateFromGemini(String slug, String displayName) async {
    if (_apiKey.isEmpty) throw Exception('No API key');

    final model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.2,
        maxOutputTokens: 1024, // Increased: 512 was truncating complex exercises
      ),
    );

    // Token-efficient prompt with bilingual audio script + 6 detailed steps
    final prompt = '''
Exercise: "$displayName" (slug: $slug)
Return ONLY valid JSON (no markdown):
{
  "instructions": ["step1","step2","step3","step4","step5","step6"],
  "bodyParts": ["primary_muscle","secondary_muscle"],
  "equipment": ["item1"],
  "difficulty": "beginner|intermediate|advanced",
  "durationSec": 60,
  "audioScript": "one motivating English coaching cue for this exercise",
  "audioScriptHi": "ek motivating Hindi coaching cue isi exercise ke liye",
  "isLowImpact": false,
  "isSeatedFriendly": false,
  "contraindications": ["specific condition to avoid if any"]
}''';

    final resp = await model.generateContent([Content.text(prompt)]);
    final text = resp.text ?? '';
    // Strip markdown fences if present
    final clean = text.replaceAll(RegExp(r'```[a-z]*\n?'), '').trim();
    final map = jsonDecode(clean) as Map<String, dynamic>;
    return _fromMap(slug, map, displayName: displayName);
  }

  LibraryItem _fromMap(String slug, Map<String, dynamic> m, {String? displayName}) {
    List<String> strList(dynamic v) =>
        v is List ? v.map((e) => e.toString()).toList() : [];

    return LibraryItem(
      slug: slug,
      name: displayName ?? slug.replaceAll('_', ' ').replaceAll('-', ' '),
      category: 'exercise',
      subcategory: 'session',
      bodyParts: strList(m['bodyParts']),
      difficulty: (m['difficulty'] as String? ?? 'intermediate'),
      instructions: strList(m['instructions']),
      audioScript: (m['audioScript'] as String? ?? ''),
      defaultDurationSec: (m['durationSec'] as int? ?? 60),
      equipment: strList(m['equipment']),
      contraindications: strList(m['contraindications']),
      isSeatedFriendly: m['isSeatedFriendly'] as bool? ?? false,
      isLowImpact: m['isLowImpact'] as bool? ?? false,
      isRecoveryFor: const [],
      thumbnailUrl: '',
      gifUrl: '',
    );
  }

  Map<String, dynamic> _toMap(LibraryItem i) => {
    'instructions': i.instructions,
    'bodyParts': i.bodyParts,
    'equipment': i.equipment,
    'difficulty': i.difficulty,
    'durationSec': i.defaultDurationSec,
    'audioScript': i.audioScript,
    'isLowImpact': i.isLowImpact,
    'isSeatedFriendly': i.isSeatedFriendly,
    'contraindications': i.contraindications,
  };

  LibraryItem _structuralFallback(String slug, String name) => LibraryItem(
    slug: slug,
    name: name,
    category: 'exercise',
    subcategory: 'session',
    bodyParts: _inferBodyParts(slug),
    difficulty: 'intermediate',
    instructions: _inferInstructions(slug, name),
    audioScript: 'Focus on controlled movement and steady breathing.',
    defaultDurationSec: 60,
    equipment: _inferEquipment(slug),
    contraindications: const [],
    isSeatedFriendly: false,
    isLowImpact: slug.contains('yoga') || slug.contains('stretch') || slug.contains('mobility'),
    isRecoveryFor: const [],
    thumbnailUrl: '',
    gifUrl: '',
  );

  List<String> _inferBodyParts(String slug) {
    final s = slug.toLowerCase();
    if (s.contains('chest') || s.contains('bench') || s.contains('push')) return ['chest', 'triceps', 'shoulders'];
    if (s.contains('back') || s.contains('row') || s.contains('pull') || s.contains('lat')) return ['back', 'biceps'];
    if (s.contains('leg') || s.contains('squat') || s.contains('lunge') || s.contains('deadlift')) return ['quadriceps', 'hamstrings', 'glutes'];
    if (s.contains('shoulder') || s.contains('delt') || s.contains('press') || s.contains('raise')) return ['shoulders', 'triceps'];
    if (s.contains('bicep') || s.contains('curl')) return ['biceps', 'forearms'];
    if (s.contains('tricep') || s.contains('extension') || s.contains('dip')) return ['triceps', 'chest'];
    if (s.contains('core') || s.contains('ab') || s.contains('crunch') || s.contains('plank')) return ['core', 'abs'];
    if (s.contains('cardio') || s.contains('run') || s.contains('jump') || s.contains('burpee')) return ['full body', 'cardiovascular'];
    if (s.contains('yoga') || s.contains('stretch') || s.contains('flex')) return ['flexibility', 'full body'];
    return ['core', 'full body'];
  }

  List<String> _inferEquipment(String slug) {
    final s = slug.toLowerCase();
    if (s.contains('barbell') || s.contains('bench')) return ['barbell', 'bench'];
    if (s.contains('dumbbell') || s.contains('db_')) return ['dumbbell'];
    if (s.contains('cable') || s.contains('machine')) return ['cable machine'];
    if (s.contains('kettlebell') || s.contains('kb_')) return ['kettlebell'];
    if (s.contains('resistance') || s.contains('band')) return ['resistance band'];
    if (s.contains('pull_up') || s.contains('chin_up')) return ['pull-up bar'];
    if (s.contains('treadmill') || s.contains('run')) return ['treadmill'];
    return [];
  }

  List<String> _inferInstructions(String slug, String name) => [
    'Stand in a comfortable position with feet shoulder-width apart.',
    'Engage your core and maintain a neutral spine throughout the movement.',
    'Perform $name with controlled motion — slow on the eccentric phase.',
    'Exhale during exertion, inhale during the return phase.',
    'Complete the set and rest 60–90 seconds before the next.',
  ];
}
