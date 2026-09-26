// lib/services/motivation_service.dart
//
// VYRA MotivationService — manages daily motivational slogans.
// Picks slogan based on: time of day, user streak, last workout gap.
// Caches today's slogan in SharedPreferences and refreshes at midnight.
// Supports Hindi & English via LanguageService.

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

// ---------------------------------------------------------------------------
// Data Models
// ---------------------------------------------------------------------------

/// Slogan categories keyed by identifier.
enum SloganCategory {
  morningFire,      // 06:00 – 09:59
  middayPush,       // 10:00 – 13:59
  afternoonGrind,   // 14:00 – 17:59
  eveningWarrior,   // 18:00 – 20:59
  nightChampion,    // 21:00 – 23:59
  restDayRecharge,  // active-rest or no workout today
  streakMilestone,  // streak ∈ {3,7,14,30}
  goalAchieved,     // goal completed
  comeback,         // gap ≥ 3 days since last workout
}

/// A single motivational slogan surface to the UI.
class VyraSlogan {
  const VyraSlogan({
    required this.text,
    required this.emoji,
    required this.category,
    required this.language,
  });

  final String text;
  final String emoji;
  final SloganCategory category;
  final String language; // 'en' | 'hi'

  Map<String, dynamic> toJson() => {
        'text': text,
        'emoji': emoji,
        'category': category.name,
        'language': language,
      };

  factory VyraSlogan.fromJson(Map<String, dynamic> j) => VyraSlogan(
        text: j['text'] as String,
        emoji: j['emoji'] as String,
        category: SloganCategory.values.firstWhere(
          (c) => c.name == j['category'],
          orElse: () => SloganCategory.morningFire,
        ),
        language: j['language'] as String,
      );
}

// ---------------------------------------------------------------------------
// Slogan Bank
// ---------------------------------------------------------------------------

/// Internal class that holds all slogan strings.
class _SloganBank {
  // ── English ──────────────────────────────────────────────────────────────

  static const Map<SloganCategory, List<String>> en = {
    SloganCategory.morningFire: [
      'Rise up — your body is waiting for you.',
      'The morning belongs to those who claim it.',
      'Champions are made before the world wakes up.',
      'Sunrise hustle, sunset results.',
      'Your alarm is your starting gun. Go.',
      'Every great day starts with a great workout.',
      'The early bird doesn\'t just get the worm — it gets the gains.',
      'Morning sweat is the best investment you\'ll make today.',
      'You slept. You rested. Now dominate.',
      'The sun rose, and so did you. Make it count.',
    ],
    SloganCategory.middayPush: [
      'Midday slump? Not on VYRA\'s watch.',
      'Half the day is gone. Make the other half legendary.',
      'The grind doesn\'t take a lunch break.',
      'Fuel up, lace up, show up.',
      'The only bad workout is the one you skipped at noon.',
      'Energy dips are lies your comfort zone tells you.',
      'Peak hours are now. Don\'t waste them.',
      'While others nap, you train.',
      'Noon is the new 5 AM for the dedicated.',
      'The afternoon is a gift — unwrap it with effort.',
    ],
    SloganCategory.afternoonGrind: [
      'Tired? Good. That\'s where growth begins.',
      'The afternoon warrior earns every rep.',
      'Sweat is just fat crying.',
      'Three PM is the new prime time.',
      'Your muscles don\'t know what time it is — train them.',
      'Push through the afternoon fog and find your edge.',
      'The grind is always grinding. Are you?',
      'Every drop of sweat is a down payment on tomorrow.',
      'Afternoon aches are evening trophies.',
      'No excuses after lunch — only results.',
    ],
    SloganCategory.eveningWarrior: [
      'End the day the way you meant to live it.',
      'Evening warriors don\'t quit when the sun sets.',
      'This is your final rep of the day — make it count.',
      'The gym at night belongs to the committed.',
      'Burn it down, then rest like a champion.',
      'Your best workout might be the one you almost skipped tonight.',
      'Night owls can be warriors too.',
      'Close out the day with zero regrets.',
      'Stars only shine in the dark — so do you.',
      'One more set. Then rest easy.',
    ],
    SloganCategory.nightChampion: [
      'Champions are made when no one is watching.',
      'Late nights build legendary bodies.',
      'The world is asleep — you\'re still grinding.',
      'Quiet hours, loud results.',
      'Night is where discipline lives.',
      'While others dream of success, you\'re earning it.',
      'The midnight hustle pays the morning dividend.',
      'No spotlight needed — your effort speaks.',
      'The gym at midnight is your cathedral.',
      'Tonight\'s sweat is tomorrow\'s pride.',
    ],
    SloganCategory.restDayRecharge: [
      'Rest is not laziness — it\'s strategy.',
      'Recovery is part of the program.',
      'Champions recharge so they can roar.',
      'Your muscles grow while you rest. Trust the process.',
      'A rest day is an investment in tomorrow\'s performance.',
      'Even legends take a breath.',
      'Rest today, conquer tomorrow.',
      'Sleep is your secret weapon.',
      'The body repairs, the mind resets, the champion returns.',
      'Embrace the rest. You\'ve earned it.',
    ],
    SloganCategory.streakMilestone: [
      'A streak is a promise you keep to yourself.',
      'Every day added is a wall built against quitting.',
      'Consistency is the rarest superpower.',
      'You didn\'t come this far to only come this far.',
      'Streak strong — the habit is now yours.',
      'Days don\'t lie. Your commitment shows.',
      'Breaking a streak takes one second. Building it takes forever.',
      'You\'re not just working out — you\'re becoming someone.',
      'The streak is proof that you showed up.',
      'Milestone reached. The bar just rose.',
    ],
    SloganCategory.goalAchieved: [
      'Goal crushed. Set a bigger one.',
      'You said you would. You did. That\'s everything.',
      'The summit was just the beginning.',
      'Proof that you are who you claimed to be.',
      'Celebrate, then get back to work.',
      'You levelled up today.',
      'Goals are promises. You kept yours.',
      'Achievement unlocked — now unlock the next.',
      'The finish line is just another starting line.',
      'You made it happen. Remember this feeling.',
    ],
    SloganCategory.comeback: [
      'You\'re back. That\'s what matters.',
      'It\'s not how long you were gone — it\'s that you returned.',
      'The comeback is always stronger than the setback.',
      'Welcome back, warrior.',
      'Life happened. Now fitness happens again.',
      'Every champion has a comeback story.',
      'The gap is closed the moment you start.',
      'You fell. You rose. That\'s the whole story.',
      'Don\'t apologise for the break — just make today count.',
      'Restart. Rebuild. Reclaim.',
    ],
  };

  // ── Hindi ─────────────────────────────────────────────────────────────────

  static const Map<SloganCategory, List<String>> hi = {
    SloganCategory.morningFire: [
      'उठो, सूरज से पहले नहीं, तो कम से कम उसके साथ तो उठो।',
      'सुबह की मेहनत, शाम की जीत।',
      'जो सुबह उठता है, वो दुनिया को हराता है।',
      'आंखें खोलो और रिकॉर्ड तोड़ो।',
      'सुबह का पसीना, शाम का सम्मान।',
      'नींद टूटी, बहाने टूटे — अब खुद बनो।',
      'भोर में जो जागा, वो जीवन भर जागता रहा।',
      'सूरज की किरण से पहले अपनी मेहनत की रोशनी फैलाओ।',
      'सुबह का एक घंटा, पूरे दिन की शक्ति।',
      'आज की शुरुआत, कल की नींव है।',
    ],
    SloganCategory.middayPush: [
      'दोपहर की थकान को हथियार बनाओ।',
      'आधा दिन गया — बाकी आधा जीत लो।',
      'धूप में जो जलता है, वो सोना बन जाता है।',
      'दोपहर की आलस्य को लात मारो।',
      'रुको मत — बस एक और सेट।',
      'दोपहर का योद्धा हर दिन इतिहास बनाता है।',
      'थकान एक झूठ है — उसे मत मानो।',
      'दोपहर के बाद का पसीना, सबसे महंगा होता है।',
      'मध्याह्न की लहर पकड़ो — यही सफलता का समय है।',
      'खाना खाया, अब मेहनत करो।',
    ],
    SloganCategory.afternoonGrind: [
      'आज का दर्द, कल की ताकत है।',
      'शाम ढलने से पहले खुद को साबित करो।',
      'जब थको, तब मत रुको — बस धीमे हो जाओ।',
      'पसीना झूठ नहीं बोलता।',
      'दोपहर ढले तो क्या — जज़्बा अभी भी जल रहा है।',
      'दर्द अस्थायी है, गर्व स्थायी है।',
      'हर बूंद पसीना एक कदम आगे है।',
      'शरीर कहता है रुको — दिमाग कहता है चलो।',
      'शाम से पहले खुद को तोड़ो, फिर बनाओ।',
      'थकान वो मोड़ है जहाँ से असली यात्रा शुरू होती है।',
    ],
    SloganCategory.eveningWarrior: [
      'शाम का योद्धा थकता नहीं — निखरता है।',
      'दिन का आखिरी सेट सबसे ज़रूरी है।',
      'सूरज ढला, पर तुम्हारी मेहनत नहीं।',
      'शाम को जिम में जो होता है, वो सुबह चेहरे पर दिखता है।',
      'आज का आखिरी एक घंटा कल की नींव है।',
      'रात के पहले खुद को जला दो।',
      'शाम की मेहनत, रात की नींद को मीठा बनाती है।',
      'जब दुनिया थक जाए, तब तुम शुरू होते हो।',
      'शाम का पसीना — कल के सपने की कीमत।',
      'एक और रेप, फिर आराम।',
    ],
    SloganCategory.nightChampion: [
      'मेहनत करने वालों की कभी हार नहीं होती।',
      'रात में जो जागता है, वो सुबह जीतता है।',
      'अँधेरे में की गई मेहनत, उजाले में दिखती है।',
      'जब सब सोते हैं, तब चैम्पियन बनते हैं।',
      'रात का अभ्यास, दिन की जीत।',
      'सन्नाटे में की गई कोशिश, सबसे पवित्र होती है।',
      'रात को मेहनत करो — दुनिया को हैरान करो।',
      'नींद उन्हें आती है जो दिन में थकते हैं।',
      'रात का योद्धा कभी हार नहीं मानता।',
      'अँधेरे में बोई गई मेहनत, सुबह का फल देती है।',
    ],
    SloganCategory.restDayRecharge: [
      'आराम भी ताकत का हिस्सा है।',
      'शरीर को सुनो — वो तुमसे प्यार करता है।',
      'रुको, ठीक हो जाओ, फिर जीतो।',
      'आराम आलस्य नहीं, रणनीति है।',
      'आज आराम करो, कल दोगुना करो।',
      'मांसपेशियाँ आराम में बनती हैं।',
      'विराम में विजय की तैयारी होती है।',
      'थके बिना जीत नहीं मिलती — थको, आराम करो, जीतो।',
      'सो जाओ — यह भी एक सेट है।',
      'आज का आराम, कल की रफ़्तार।',
    ],
    SloganCategory.streakMilestone: [
      'एक के बाद एक — यही जीत का रास्ता है।',
      'लगातार मेहनत ही असली ताकत है।',
      'हर दिन एक वादा पूरा किया।',
      'स्ट्रीक टूटे नहीं — यही संकल्प है।',
      'नियमितता वो जादू है जो दुनिया देखती है।',
      'इतने दिनों की मेहनत बेकार नहीं जाती।',
      'आज भी आए — यही काफी है।',
      'आदत बन गई — अब रोकना मुश्किल है।',
      'हर कदम पर एक नया रिकॉर्ड।',
      'तुम सिर्फ workout नहीं कर रहे — तुम खुद को बना रहे हो।',
    ],
    SloganCategory.goalAchieved: [
      'लक्ष्य पूरा हुआ — अब नया लक्ष्य तय करो।',
      'जो कहा, वो किया — यही असली जीत है।',
      'मंजिल मिली — अब नई मंजिल की तलाश।',
      'तुमने खुद से किया वादा निभाया।',
      'जश्न मनाओ, फिर वापस काम पर लगो।',
      'अगला स्तर अनलॉक हो गया।',
      'सपना पूरा हुआ — अब बड़ा सपना देखो।',
      'शाबाश — तुम वो बन गए जो बनना चाहते थे।',
      'गोल हासिल किया — अब बार ऊपर करो।',
      'यह जीत याद रखो — अगली बार और बड़ी जीत होगी।',
    ],
    SloganCategory.comeback: [
      'वापस आ गए — यही सबसे बड़ी जीत है।',
      'गए थे, पर हारे नहीं।',
      'वापसी हमेशा शुरुआत से ज़्यादा शक्तिशाली होती है।',
      'स्वागत है योद्धा — तुम वापस आए।',
      'रुकना ज़रूरी था — अब चलना और ज़रूरी है।',
      'हर चैम्पियन की एक वापसी की कहानी होती है।',
      'गैप बंद हो गया — पहला कदम उठाते ही।',
      'गिरे थे, उठे — यही कहानी काफी है।',
      'बिना माफी माँगे शुरू करो — बस करो।',
      'फिर से शुरू करो। फिर से बनाओ। फिर से जीतो।',
    ],
  };
}

// ---------------------------------------------------------------------------
// MotivationService
// ---------------------------------------------------------------------------

/// Singleton service that provides daily motivational slogans for VYRA.
///
/// Usage:
/// ```dart
/// final slogan = await MotivationService.instance.getSlogan(context: 'home');
/// ```
class MotivationService {
  MotivationService._();
  static final MotivationService instance = MotivationService._();

  // SharedPreferences keys
  static const String _kCachedSlogan  = 'vyra_cached_slogan';
  static const String _kCachedDate    = 'vyra_cached_date';

  final _rng = Random();
  final FlutterLocalNotificationsPlugin _notifPlugin =
      FlutterLocalNotificationsPlugin();

  bool _notifInitialised = false;

  // ── Public API ─────────────────────────────────────────────────────────

  /// Returns today's slogan, using cache when available.
  ///
  /// [context] hints: 'home', 'post_workout', 'login', 'streak', 'goal',
  ///                  'comeback', 'rest_day'.
  /// [streakDays] current consecutive day count.
  /// [daysSinceLastWorkout] 0 = worked out today, null = unknown.
  /// [language] 'en' or 'hi'; defaults to 'en'.
  Future<VyraSlogan> getSlogan({
    required String context,
    int streakDays = 0,
    int? daysSinceLastWorkout,
    String language = 'en',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();

    // Return cached slogan if it was generated today and context hasn't
    // forced a category override (streak / goal / comeback).
    final bool forceOverride = _isOverrideContext(context, streakDays, daysSinceLastWorkout);
    if (!forceOverride) {
      final cachedDate = prefs.getString(_kCachedDate);
      final cachedJson = prefs.getString(_kCachedSlogan);
      if (cachedDate == today && cachedJson != null) {
        try {
          final slogan = VyraSlogan.fromJson(
              jsonDecode(cachedJson) as Map<String, dynamic>);
          // Re-use only if language matches
          if (slogan.language == language) return slogan;
        } catch (_) {
          // Cache corrupt — fall through and regenerate.
        }
      }
    }

    final slogan = _generate(
      context: context,
      streakDays: streakDays,
      daysSinceLastWorkout: daysSinceLastWorkout,
      language: language,
    );

    // Cache (only for time-of-day slogans, not overrides)
    if (!forceOverride) {
      await prefs.setString(_kCachedSlogan, jsonEncode(slogan.toJson()));
      await prefs.setString(_kCachedDate, today);
    }

    return slogan;
  }

  /// Initialise and schedule 3 daily local notifications.
  ///
  /// Times: 06:30, 12:00, 20:00 local time.
  Future<void> scheduleDailyNotifications({String language = 'en'}) async {
    await _ensureNotifInitialised();
    tz_data.initializeTimeZones();

    // Cancel any existing VYRA motivation notifications before rescheduling.
    for (final id in [101, 102, 103]) {
      await _notifPlugin.cancel(id);
    }

    final slots = [
      (id: 101, hour: 6,  minute: 30, category: SloganCategory.morningFire),
      (id: 102, hour: 12, minute: 0,  category: SloganCategory.middayPush),
      (id: 103, hour: 20, minute: 0,  category: SloganCategory.eveningWarrior),
    ];

    for (final slot in slots) {
      final slogan = _pickFromCategory(slot.category, language);
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          'vyra_motivation',
          'VYRA Daily Motivation',
          channelDescription: 'Daily motivational slogans from VYRA',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      );

      await _notifPlugin.zonedSchedule(
        slot.id,
        '${slogan.emoji} VYRA',
        slogan.text,
        _nextOccurrence(slot.hour, slot.minute),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time, // repeat daily
      );
    }

    debugPrint('[MotivationService] 3 daily notifications scheduled.');
  }

  // ── Private helpers ────────────────────────────────────────────────────

  /// Determines whether streak / comeback / goal should override
  /// the time-based slogan cache.
  bool _isOverrideContext(
      String context, int streakDays, int? daysSinceLastWorkout) {
    if (context == 'goal') return true;
    if (context == 'comeback') return true;
    if (context == 'streak' && _isMilestoneStreak(streakDays)) return true;
    if (daysSinceLastWorkout != null && daysSinceLastWorkout >= 3) return true;
    return false;
  }

  /// Core slogan generation logic.
  VyraSlogan _generate({
    required String context,
    required int streakDays,
    required int? daysSinceLastWorkout,
    required String language,
  }) {
    SloganCategory category;

    // Priority order: goal → comeback → streak milestone → rest → time-of-day
    if (context == 'goal') {
      category = SloganCategory.goalAchieved;
    } else if (context == 'comeback' ||
        (daysSinceLastWorkout != null && daysSinceLastWorkout >= 3)) {
      category = SloganCategory.comeback;
    } else if (context == 'rest_day') {
      category = SloganCategory.restDayRecharge;
    } else if (_isMilestoneStreak(streakDays)) {
      category = SloganCategory.streakMilestone;
    } else {
      category = _categoryForHour(DateTime.now().hour);
    }

    return _pickFromCategory(category, language);
  }

  VyraSlogan _pickFromCategory(SloganCategory category, String language) {
    final bank = language == 'hi' ? _SloganBank.hi : _SloganBank.en;
    final list = bank[category] ?? bank[SloganCategory.morningFire]!;
    final text = list[_rng.nextInt(list.length)];
    return VyraSlogan(
      text: text,
      emoji: _emojiForCategory(category),
      category: category,
      language: language,
    );
  }

  /// Maps hour (0-23) to a slogan category.
  SloganCategory _categoryForHour(int hour) {
    if (hour >= 6 && hour < 10)  return SloganCategory.morningFire;
    if (hour >= 10 && hour < 14) return SloganCategory.middayPush;
    if (hour >= 14 && hour < 18) return SloganCategory.afternoonGrind;
    if (hour >= 18 && hour < 21) return SloganCategory.eveningWarrior;
    if (hour >= 21)              return SloganCategory.nightChampion;
    // Midnight to 6 AM — treat as night champion
    return SloganCategory.nightChampion;
  }

  bool _isMilestoneStreak(int streak) =>
      streak == 3 || streak == 7 || streak == 14 || streak == 30;

  String _emojiForCategory(SloganCategory cat) {
    switch (cat) {
      case SloganCategory.morningFire:      return '🔥';
      case SloganCategory.middayPush:       return '⚡';
      case SloganCategory.afternoonGrind:   return '💪';
      case SloganCategory.eveningWarrior:   return '🌟';
      case SloganCategory.nightChampion:    return '🏆';
      case SloganCategory.restDayRecharge:  return '🌙';
      case SloganCategory.streakMilestone:  return '🔥';
      case SloganCategory.goalAchieved:     return '🎯';
      case SloganCategory.comeback:         return '💥';
    }
  }

  /// Today key in YYYY-MM-DD format for cache invalidation.
  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  // ── Notifications ──────────────────────────────────────────────────────

  Future<void> _ensureNotifInitialised() async {
    if (_notifInitialised) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );
    await _notifPlugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _notifInitialised = true;
  }

  tz.TZDateTime _nextOccurrence(int hour, int minute) {
    final now   = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
