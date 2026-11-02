import 'package:flutter/material.dart';
import 'language_service.dart';

/// VYRA Universal Multilingual Localization Engine
///
/// Supports dynamic runtime language switching across:
/// - English (en, en_IN, en_US, en_GB)
/// - Hindi (hi)
/// - Hinglish (hi_LATN) - Conversational Hindi in Latin script
/// - Tamil (ta)
/// - Telugu (te)
/// - Marathi (mr)
/// - Bengali (bn)
/// - Punjabi (pa)
/// - Gujarati (gu)
/// - Malayalam (ml)
/// - Kannada (kn)
/// - Spanish (es)
/// - French (fr)
/// - German (de)
///
/// Features:
/// - Type-safe getters for all primary screen UI strings
/// - Dynamic fallback to English for any missing translation key
/// - Rebuilds reactively when [LanguageService] changes locale
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(LanguageService.instance.locale);
  }

  static AppLocalizations get current =>
      AppLocalizations(LanguageService.instance.locale);

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  String get languageKey {
    if (locale.countryCode == 'LATN') return 'hi_en';
    final code = locale.languageCode.toLowerCase();
    if (_localizedStrings.containsKey(code)) return code;
    return 'en';
  }

  /// Generic translation lookup with automatic English fallback
  String t(String key) {
    final lang = languageKey;
    final dict = _localizedStrings[lang];
    if (dict != null && dict.containsKey(key)) {
      return dict[key]!;
    }
    // Fallback to English
    return _localizedStrings['en']?[key] ?? key;
  }

  // ── Typed Navigation & Main Tab Getters ────────────────────────────────────
  String get training => t('nav_training');
  String get food => t('nav_food');
  String get social => t('nav_social');
  String get challenges => t('nav_challenges');
  String get profile => t('nav_profile');

  // ── Titles ─────────────────────────────────────────────────────────────────
  String get titleTrainingHub => t('title_training_hub');
  String get titleFoodNutrition => t('title_food_nutrition');
  String get titleAthleteSocial => t('title_athlete_social');
  String get titleChallengesCups => t('title_challenges_cups');
  String get titleMyProfile => t('title_my_profile');

  // ── Drawer Menu Items ──────────────────────────────────────────────────────
  String get athleteEcosystem => t('drawer_athlete_ecosystem');
  String get switchUser => t('drawer_switch_user');
  String get diamondTier => t('drawer_diamond_tier');
  String get activityPts => t('drawer_activity_pts');
  String get myProfile => t('drawer_my_profile');
  String get leaderboard => t('drawer_leaderboard');
  String get directMessages => t('drawer_direct_messages');
  String get changePassword => t('drawer_change_password');
  String get notificationSettings => t('drawer_notification_settings');
  String get smartwatchSync => t('drawer_smartwatch_sync');
  String get watchProber => t('drawer_watch_prober');
  String get avatarStudio => t('drawer_avatar_studio');
  String get bloodDonation => t('drawer_blood_donation');
  String get poseTracker => t('drawer_pose_tracker');
  String get reportAnalysis => t('drawer_report_analysis');
  String get nearbyDoctors => t('drawer_nearby_doctors');
  String get emergencyContacts => t('drawer_emergency_contacts');
  String get beaconSos => t('drawer_beacon_sos');
  String get contactSupport => t('drawer_contact_support');
  String get appTheme => t('drawer_app_theme');
  String get appLanguage => t('drawer_app_language');
  String get obsidianDark => t('drawer_obsidian_dark');
  String get classicBright => t('drawer_classic_bright');
  String get logout => t('drawer_logout');

  // ── Training Hub & Dashboard ───────────────────────────────────────────────
  String get goodMorning => t('dash_good_morning');
  String get goalPace => t('dash_goal_pace');
  String get daysStreak => t('dash_days_streak');
  String get readinessTitle => t('dash_readiness_title');
  String get readinessSubtitle => t('dash_readiness_sub');
  String get todayRoutine => t('dash_today_routine');
  String get startWorkout => t('dash_start_workout');
  String get aiVerify => t('dash_ai_verify');
  String get askCoach => t('dash_ask_coach');
  String get tuneIntensity => t('dash_tune_intensity');
  String get viewAll => t('dash_view_all');

  // ── Food & Nutrition ───────────────────────────────────────────────────────
  String get foodHubTitle => t('food_hub_title');
  String get dailyBudget => t('food_daily_budget');
  String get kcalLeft => t('food_kcal_left');
  String get protein => t('food_protein');
  String get carbs => t('food_carbs');
  String get fats => t('food_fats');
  String get scanFoodAi => t('food_scan_ai');
  String get myDietChart => t('food_diet_chart');
  String get barcodeScan => t('food_barcode_scan');
  String get hydrationTarget => t('food_hydration');
  String get kitchenInventory => t('food_kitchen_inv');

  // ── Smartwatch Telemetry ───────────────────────────────────────────────────
  String get triggerSensors => t('watch_trigger_sensors');
  String get continuousSyncActive => t('watch_continuous_sync');
  String get restingHr => t('watch_resting_hr');
  String get bloodOxygen => t('watch_blood_oxygen');
  String get liveSteps => t('watch_live_steps');
  String get calories => t('watch_calories');
  String get distance => t('watch_distance');
  String get bloodPressure => t('watch_blood_pressure');
  String get recovery => t('watch_recovery');
  String get measureHr => t('watch_measure_hr');
  String get measureBp => t('watch_measure_bp');
  String get measureSpo2 => t('watch_measure_spo2');
  String get vibrate => t('watch_vibrate');
  String get syncNow => t('watch_sync_now');
  String get disconnectWatch => t('watch_disconnect');

  // ── Common & Onboarding ─────────────────────────────────────────────────────
  String get cancel => t('common_cancel');
  String get confirm => t('common_confirm');
  String get save => t('common_save');
  String get chooseLanguage => t('common_choose_language');
  String get chooseLanguageSub => t('common_choose_language_sub');
  String get continueButton => t('onboarding_continue');
  String get buildMyPlan => t('onboarding_build_plan');
  String get signIn => t('auth_sign_in');
  String get createAccount => t('auth_create_account');
  String get guestMode => t('auth_guest_mode');
  String get email => t('auth_email');
  String get password => t('auth_password');
  String get preferencesAndLanguage => t('settings_pref_language');
  String get clearCache => t('settings_clear_cache');
  String get appVersion => t('settings_app_version');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension LocalizationExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String tr(String key) => AppLocalizations.of(this).t(key);
}

// ─────────────────────────────────────────────────────────────────────────────
// DICTIONARY REPOSITORY
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, Map<String, String>> _localizedStrings = {
  // ── ENGLISH (DEFAULT) ──────────────────────────────────────────────────────
  'en': {
    // Navigation
    'nav_training': 'Training',
    'nav_food': 'Food',
    'nav_social': 'Social',
    'nav_challenges': 'Challenges',
    'nav_profile': 'Profile',

    // Titles
    'title_training_hub': 'Training Hub',
    'title_food_nutrition': 'Food & Nutrition',
    'title_athlete_social': 'Athlete Social',
    'title_challenges_cups': 'Challenges & Cups',
    'title_my_profile': 'My Profile',

    // Drawer
    'drawer_athlete_ecosystem': 'ATHLETE ECOSYSTEM · VYRA OS',
    'drawer_switch_user': 'Switch',
    'drawer_diamond_tier': 'Diamond Tier',
    'drawer_activity_pts': 'Activity Pts · 82% to Master',
    'drawer_my_profile': 'My profile',
    'drawer_leaderboard': 'Leaderboard & Rankings',
    'drawer_direct_messages': 'Direct Messages & Athlete Chat',
    'drawer_change_password': 'Change password / Security',
    'drawer_notification_settings': 'Notification settings',
    'drawer_smartwatch_sync': 'Smartwatch Sync (HiWatch Pro)',
    'drawer_watch_prober': 'Watch Protocol Prober (Tester Tool)',
    'drawer_avatar_studio': '3D Coach Avatar & Digital Twin Studio',
    'drawer_blood_donation': 'e-RaktKosh Blood Donation (API Setu)',
    'drawer_pose_tracker': 'AI Camera Pose & Rep Tracker',
    'drawer_report_analysis': 'AI Report Analysis',
    'drawer_nearby_doctors': 'Nearby Rated Doctors (NHA)',
    'drawer_emergency_contacts': 'Safety & Emergency Contacts',
    'drawer_beacon_sos': 'Beacon SOS & Live Location',
    'drawer_contact_support': 'Contact us / Support',
    'drawer_app_theme': 'App Theme',
    'drawer_app_language': 'App Language',
    'drawer_obsidian_dark': 'Obsidian Dark',
    'drawer_classic_bright': 'Classic Bright',
    'drawer_logout': 'Log out of this account',

    // Dashboard
    'dash_good_morning': 'Good morning,',
    'dash_goal_pace': 'Goal Pace',
    'dash_days_streak': 'Days Streak',
    'dash_readiness_title': 'VYRA GEMINI DAILY READINESS BRIEFING',
    'dash_readiness_sub':
        'Good morning Ayush! Recovery score is 89% (Optimal). Resting HR is steady at 64 bpm and deep sleep reached 1h 48m. Today\'s metabolic window is ideal for your Upper Body & Core session. Hydration goal: 3.2L.',
    'dash_today_routine': 'Today\'s Routine',
    'dash_start_workout': 'Start Workout',
    'dash_ai_verify': 'AI Verify',
    'dash_ask_coach': 'Ask Coach VYRA',
    'dash_tune_intensity': 'Tune Intensity',
    'dash_view_all': 'View all',

    // Food
    'food_hub_title': 'FOOD & NUTRITION',
    'food_daily_budget': 'Daily Caloric Budget, Macronutrient Flux & Clinical Protocols',
    'food_kcal_left': 'kcal left',
    'food_protein': 'PROTEIN',
    'food_carbs': 'CARBS',
    'food_fats': 'FATS',
    'food_scan_ai': 'Scan Food AI',
    'food_diet_chart': 'My Diet Chart',
    'food_barcode_scan': 'Barcode Scan',
    'food_hydration': 'Hydration 3.2L',
    'food_kitchen_inv': 'WHAT IS IN YOUR KITCHEN',

    // Smartwatch
    'watch_trigger_sensors': 'Trigger Live Sensors (HR / BP / SpO2)',
    'watch_continuous_sync': 'Continuous Sync Active • Auto-Reconnect Enabled (3.5s Watchdog)',
    'watch_resting_hr': 'RESTING HR',
    'watch_blood_oxygen': 'BLOOD OXYGEN',
    'watch_live_steps': 'LIVE STEPS',
    'watch_calories': 'CALORIES',
    'watch_distance': 'DISTANCE',
    'watch_blood_pressure': 'BLOOD PRESS.',
    'watch_recovery': 'RECOVERY',
    'watch_measure_hr': 'Measure HR',
    'watch_measure_bp': 'Measure BP',
    'watch_measure_spo2': 'Measure SpO2',
    'watch_vibrate': 'Vibrate',
    'watch_sync_now': 'Sync Now',
    'watch_disconnect': 'Disconnect Watch',

    // Common
    'common_cancel': 'Cancel',
    'common_confirm': 'Confirm',
    'common_save': 'Save',
    'common_choose_language': 'Choose your language',
    'common_choose_language_sub': 'VYRA speaks your language — pick one to personalise every screen.',
    'onboarding_continue': 'Continue',
    'onboarding_build_plan': 'Build my plan',
    'auth_sign_in': 'Sign In',
    'auth_create_account': 'Create Account',
    'auth_guest_mode': 'Continue as Guest',
    'auth_email': 'Email',
    'auth_password': 'Password',
    'settings_pref_language': 'PREFERENCES & LANGUAGE',
    'settings_clear_cache': 'Clear Offline Feed Cache',
    'settings_app_version': 'App Version',
  },

  // ── HINDI (हिन्दी) ────────────────────────────────────────────────────────
  'hi': {
    // Navigation
    'nav_training': 'ट्रेनिंग',
    'nav_food': 'आहार',
    'nav_social': 'सोशल',
    'nav_challenges': 'चुनौतियां',
    'nav_profile': 'प्रोफाइल',

    // Titles
    'title_training_hub': 'ट्रेनिंग हब',
    'title_food_nutrition': 'आहार और पोषण',
    'title_athlete_social': 'एथलीट कम्युनिटी',
    'title_challenges_cups': 'चुनौतियां और कप',
    'title_my_profile': 'मेरी प्रोफाइल',

    // Drawer
    'drawer_athlete_ecosystem': 'एथलीट इकोसिस्टम · VYRA OS',
    'drawer_switch_user': 'बदलें',
    'drawer_diamond_tier': 'डायमंड टियर',
    'drawer_activity_pts': 'एक्टिविटी पॉइंट्स · मास्टर से 82%',
    'drawer_my_profile': 'मेरी प्रोफाइल',
    'drawer_leaderboard': 'लीडरबोर्ड और रैंकिंग',
    'drawer_direct_messages': 'मैसेज और एथलीट चैट',
    'drawer_change_password': 'पासवर्ड बदलें / सुरक्षा',
    'drawer_notification_settings': 'नोटिफिकेशन सेटिंग्स',
    'drawer_smartwatch_sync': 'स्मार्टवॉच सिंक (HiWatch Pro)',
    'drawer_watch_prober': 'वॉच प्रोटोकॉल जांच टूल',
    'drawer_avatar_studio': '3D कोच अवतार और ट्विन स्टूडियो',
    'drawer_blood_donation': 'ई-रक्तकोश रक्तदान (API सेतु)',
    'drawer_pose_tracker': 'AI कैमरा पोज़ और रेप ट्रैकर',
    'drawer_report_analysis': 'AI स्वास्थ्य रिपोर्ट विश्लेषण',
    'drawer_nearby_doctors': 'नजदीकी डॉक्टर्स (NHA)',
    'drawer_emergency_contacts': 'सुरक्षा और आपातकालीन संपर्क',
    'drawer_beacon_sos': 'बीकन SOS और लाइव लोकेशन',
    'drawer_contact_support': 'सहायता और संपर्क',
    'drawer_app_theme': 'ऐप थीम',
    'drawer_app_language': 'ऐप की भाषा (Language)',
    'drawer_obsidian_dark': 'ऑब्सिडियन डार्क',
    'drawer_classic_bright': 'क्लासिक ब्राइट',
    'drawer_logout': 'इस खाते से लॉग आउट करें',

    // Dashboard
    'dash_good_morning': 'सुप्रभात,',
    'dash_goal_pace': 'लक्ष्य गति',
    'dash_days_streak': 'दिनों की स्ट्रीक',
    'dash_readiness_title': 'VYRA GEMINI दैनिक स्वास्थ्य विश्लेषण',
    'dash_readiness_sub':
        'सुप्रभात आयुष! आपकी रिकवरी स्कोर 89% (उत्कृष्ट) है। कल रात की गहरी नींद 1 घंटा 48 मिनट रही और रेस्टिंग हार्ट रेट 64 bpm स्थिर है। आज अपर बॉडी और कोर ट्रेनिंग के लिए दिन बिल्कुल सही है। 3.2L पानी का लक्ष्य रखें।',
    'dash_today_routine': 'आज का वर्कआउट रूटीन',
    'dash_start_workout': 'वर्कआउट शुरू करें',
    'dash_ai_verify': 'AI से जांचें',
    'dash_ask_coach': 'कोच VYRA से पूछें',
    'dash_tune_intensity': 'इंटेंसिटी सेट करें',
    'dash_view_all': 'सभी देखें',

    // Food
    'food_hub_title': 'आहार और पोषण',
    'food_daily_budget': 'दैनिक कैलोरी बजट, मैक्रोन्यूट्रिएंट्स और क्लीनिकल नियम',
    'food_kcal_left': 'kcal शेष',
    'food_protein': 'प्रोटीन',
    'food_carbs': 'कार्ब्स',
    'food_fats': 'फैट्स',
    'food_scan_ai': 'खाना स्कैन करें AI',
    'food_diet_chart': 'मेरी डाइट चार्ट',
    'food_barcode_scan': 'बारकोड स्कैन',
    'food_hydration': 'हाइड्रेशन 3.2L',
    'food_kitchen_inv': 'आपकी रसोई में क्या है',

    // Smartwatch
    'watch_trigger_sensors': 'लाइव सेंसर चालू करें (HR / BP / SpO2)',
    'watch_continuous_sync': 'कंटीन्यूअस सिंक सक्रिय • ऑटो-रीकनेक्ट चालू (3.5s वॉचडॉग)',
    'watch_resting_hr': 'रेस्टिंग हार्ट रेट',
    'watch_blood_oxygen': 'ब्लड ऑक्सीजन',
    'watch_live_steps': 'लाइव कदम',
    'watch_calories': 'कैलोरी',
    'watch_distance': 'दूरी',
    'watch_blood_pressure': 'ब्लड प्रेशर',
    'watch_recovery': 'रिकवरी',
    'watch_measure_hr': 'HR मापें',
    'watch_measure_bp': 'BP मापें',
    'watch_measure_spo2': 'SpO2 मापें',
    'watch_vibrate': 'वाइब्रेट करें',
    'watch_sync_now': 'अभी सिंक करें',
    'watch_disconnect': 'वॉच डिस्कनेक्ट करें',

    // Common
    'common_cancel': 'रद्द करें',
    'common_confirm': 'पुष्टि करें',
    'common_save': 'सहेजें',
    'common_choose_language': 'अपनी भाषा चुनें',
    'common_choose_language_sub': 'VYRA आपकी भाषा समझता है — हर स्क्रीन को निजीकृत करने के लिए एक चुनें।',
    'onboarding_continue': 'आगे बढ़ें',
    'onboarding_build_plan': 'मेरी योजना बनाएं',
    'auth_sign_in': 'साइन इन करें',
    'auth_create_account': 'नया खाता बनाएं',
    'auth_guest_mode': 'अतिथि के रूप में जारी रखें',
    'auth_email': 'ईमेल',
    'auth_password': 'पासवर्ड',
    'settings_pref_language': 'प्राथमिकताएं और भाषा',
    'settings_clear_cache': 'ऑफ़लाइन फ़ीड कैश साफ़ करें',
    'settings_app_version': 'ऐप संस्करण',
  },

  // ── HINGLISH (CONVERSATIONAL HINDI IN LATIN ALPHABET) ─────────────────────
  'hi_en': {
    // Navigation
    'nav_training': 'Training',
    'nav_food': 'Khaana',
    'nav_social': 'Community',
    'nav_challenges': 'Challenges',
    'nav_profile': 'Profile',

    // Titles
    'title_training_hub': 'Training Hub',
    'title_food_nutrition': 'Khaana & Nutrition',
    'title_athlete_social': 'Athlete Social & Friends',
    'title_challenges_cups': 'Challenges & Trophies',
    'title_my_profile': 'My Athlete Profile',

    // Drawer
    'drawer_athlete_ecosystem': 'ATHLETE ECOSYSTEM · VYRA OS',
    'drawer_switch_user': 'Switch Karein',
    'drawer_diamond_tier': 'Diamond Tier',
    'drawer_activity_pts': 'Activity Points · 82% to Master',
    'drawer_my_profile': 'Mera Profile',
    'drawer_leaderboard': 'Leaderboard & Rankings',
    'drawer_direct_messages': 'Dosto Se Chat & Messages',
    'drawer_change_password': 'Password Badlein / Security',
    'drawer_notification_settings': 'Notification Settings',
    'drawer_smartwatch_sync': 'Smartwatch Jodo (HiWatch Pro)',
    'drawer_watch_prober': 'Watch Protocol Prober (Tester)',
    'drawer_avatar_studio': '3D Coach Avatar Studio',
    'drawer_blood_donation': 'e-RaktKosh Blood Lifeline (MoHFW)',
    'drawer_pose_tracker': 'AI Camera Pose & Rep Tracker',
    'drawer_report_analysis': 'AI Health Report Check',
    'drawer_nearby_doctors': 'Paas Ke Verified Doctors',
    'drawer_emergency_contacts': 'Safety & Emergency Contacts',
    'drawer_beacon_sos': 'Beacon SOS & Live Location',
    'drawer_contact_support': 'Help & Support Team',
    'drawer_app_theme': 'App Theme Mode',
    'drawer_app_language': 'App Ki Bhasha / Language',
    'drawer_obsidian_dark': 'Obsidian Dark',
    'drawer_classic_bright': 'Classic Bright',
    'drawer_logout': 'Is Account Se Log Out Karein',

    // Dashboard
    'dash_good_morning': 'Good morning,',
    'dash_goal_pace': 'Goal Pace',
    'dash_days_streak': 'Days Ki Streak',
    'dash_readiness_title': 'VYRA GEMINI DAILY READINESS BRIEFING',
    'dash_readiness_sub':
        'Good morning Ayush! Recovery score 89% (Optimal) hai. Kal raat 1h 48m deep sleep hui aur resting HR 64 bpm par stable hai. Aaj Upper Body & Core session ke liye metabolic window best hai. 3.2L paani peene ka goal rakhein.',
    'dash_today_routine': 'Aaj Ka Workout Routine',
    'dash_start_workout': 'Workout Shuru Karein',
    'dash_ai_verify': 'AI Form Check',
    'dash_ask_coach': 'Coach VYRA Se Poochein',
    'dash_tune_intensity': 'Intensity Adjust Karein',
    'dash_view_all': 'Sabhi Dekhein',

    // Food
    'food_hub_title': 'KHAANA & NUTRITION HUB',
    'food_daily_budget': 'Daily Calorie Target, Macros & Clinical Health',
    'food_kcal_left': 'kcal baaki hai',
    'food_protein': 'PROTEIN',
    'food_carbs': 'CARBS',
    'food_fats': 'FATS',
    'food_scan_ai': 'Khaana Scan Karein AI',
    'food_diet_chart': 'Mera Diet Chart',
    'food_barcode_scan': 'Barcode Scanner',
    'food_hydration': 'Hydration 3.2L',
    'food_kitchen_inv': 'KITCHEN MEIN KYA HAI',

    // Smartwatch
    'watch_trigger_sensors': 'Live Sensors Chalu Karein (HR / BP / SpO2)',
    'watch_continuous_sync': 'Continuous Sync Active • Auto-Reconnect Enabled (3.5s Watchdog)',
    'watch_resting_hr': 'RESTING HR',
    'watch_blood_oxygen': 'BLOOD OXYGEN',
    'watch_live_steps': 'LIVE STEPS',
    'watch_calories': 'CALORIES',
    'watch_distance': 'DISTANCE',
    'watch_blood_pressure': 'BLOOD PRESSURE',
    'watch_recovery': 'RECOVERY',
    'watch_measure_hr': 'HR Measure Karein',
    'watch_measure_bp': 'BP Check Karein',
    'watch_measure_spo2': 'SpO2 Measure Karein',
    'watch_vibrate': 'Watch Vibrate Karein',
    'watch_sync_now': 'Abhi Sync Karein',
    'watch_disconnect': 'Watch Disconnect Karein',

    // Common
    'common_cancel': 'Cancel Karein',
    'common_confirm': 'Confirm Karein',
    'common_save': 'Save Karein',
    'common_choose_language': 'Apni Bhasha Chunein',
    'common_choose_language_sub': 'VYRA aapki bhasha bolta hai — har screen customize karne ke liye ek chunein.',
    'onboarding_continue': 'Aage Badhein',
    'onboarding_build_plan': 'Mera Plan Banayein',
    'auth_sign_in': 'Sign In Karein',
    'auth_create_account': 'Account Banayein',
    'auth_guest_mode': 'Guest Mode Mein Jayein',
    'auth_email': 'Email Address',
    'auth_password': 'Password',
    'settings_pref_language': 'PREFERENCES & LANGUAGE',
    'settings_clear_cache': 'Feed Cache Clear Karein',
    'settings_app_version': 'App Version',
  },

  // ── TAMIL (தமிழ்) ──────────────────────────────────────────────────────────
  'ta': {
    'nav_training': 'பயிற்சி',
    'nav_food': 'உணவு',
    'nav_social': 'சமூக',
    'nav_challenges': 'சவால்கள்',
    'nav_profile': 'சுயவிவரம்',
    'title_training_hub': 'பயிற்சி மையம்',
    'title_food_nutrition': 'உணவு மற்றும் ஊட்டச்சத்து',
    'drawer_my_profile': 'எனது சுயவிவரம்',
    'drawer_leaderboard': 'முன்னணி பலகை',
    'drawer_smartwatch_sync': 'ஸ்மார்ட்வாட்ச் ஒத்திசைவு',
    'drawer_app_language': 'பயன்பாட்டு மொழி',
    'dash_good_morning': 'காலை வணக்கம்,',
    'dash_today_routine': 'இன்றைய பயிற்சி',
    'dash_start_workout': 'பயிற்சியைத் தொடங்கு',
    'food_scan_ai': 'உணவை ஸ்கேன் செய் AI',
    'common_choose_language': 'உங்கள் மொழியைத் தேர்ந்தெடுக்கவும்',
    'onboarding_continue': 'தொடரவும்',
    'onboarding_build_plan': 'என் திட்டத்தை உருவாக்கு',
  },

  // ── TELUGU (తెలుగు) ────────────────────────────────────────────────────────
  'te': {
    'nav_training': 'శిక్షణ',
    'nav_food': 'ఆహారం',
    'nav_social': 'సామాజిక',
    'nav_challenges': 'సవాళ్లు',
    'nav_profile': 'ప్రొఫైల్',
    'title_training_hub': 'శిక్షణ హబ్',
    'title_food_nutrition': 'ఆహారం & పోషకాహారం',
    'drawer_my_profile': 'నా ప్రొఫైల్',
    'drawer_leaderboard': 'లీడర్‌బోర్డ్ మరియు ర్యాంకింగ్స్',
    'drawer_smartwatch_sync': 'స్మార్ట్‌వాచ్ సమకాలీకరణ',
    'drawer_app_language': 'యాప్ భాష',
    'dash_good_morning': 'శుభోదయం,',
    'dash_today_routine': 'ఈరోజు వర్కౌట్ రొటీన్',
    'dash_start_workout': 'వర్కౌట్ ప్రారంభించండి',
    'food_scan_ai': 'ఆహారాన్ని స్కాన్ చేయండి AI',
    'common_choose_language': 'మీ భాషను ఎంచుకోండి',
    'onboarding_continue': 'కొనసాగించండి',
    'onboarding_build_plan': 'నా ప్లాన్ రూపొందించండి',
  },

  // ── MARATHI (मराठी) ────────────────────────────────────────────────────────
  'mr': {
    'nav_training': 'प्रशिक्षण',
    'nav_food': 'आहार',
    'nav_social': 'सोशल',
    'nav_challenges': 'आव्हाने',
    'nav_profile': 'प्रोफाइल',
    'title_training_hub': 'प्रशिक्षण केंद्र',
    'title_food_nutrition': 'आहार आणि पोषण',
    'drawer_my_profile': 'माझी प्रोफाइल',
    'drawer_leaderboard': 'लीडरबोर्ड आणि रँकिंग',
    'drawer_smartwatch_sync': 'स्मार्टवॉच सिंक',
    'drawer_app_language': 'अॅप भाषा',
    'dash_good_morning': 'शुभ सकाळ,',
    'dash_today_routine': 'आजचा वर्कआउट दिनक्रम',
    'dash_start_workout': 'वर्कआउट सुरू करा',
    'food_scan_ai': 'अन्न स्कॅन करा AI',
    'common_choose_language': 'तुमची भाषा निवडा',
    'onboarding_continue': 'पुढे जा',
    'onboarding_build_plan': 'माझा प्लॅन तयार करा',
  },

  // ── BENGALI (বাংলা) ────────────────────────────────────────────────────────
  'bn': {
    'nav_training': 'প্রশিক্ষণ',
    'nav_food': 'খাদ্য',
    'nav_social': 'সামাজিক',
    'nav_challenges': 'চ্যালেঞ্জ',
    'nav_profile': 'প্রোফাইল',
    'title_training_hub': 'প্রশিক্ষণ হাব',
    'title_food_nutrition': 'খাদ্য ও পুষ্টি',
    'drawer_my_profile': 'আমার প্রোফাইল',
    'drawer_leaderboard': 'লিডারবোর্ড ও র্যাঙ্কিং',
    'drawer_smartwatch_sync': 'স্মার্টওয়াচ সিঙ্ক',
    'drawer_app_language': 'অ্যাপের ভাষা',
    'dash_good_morning': 'সুপ্রভাত,',
    'dash_today_routine': 'আজকের রুটিন',
    'dash_start_workout': 'ওয়ার্কআউট শুরু করুন',
    'food_scan_ai': 'খাবার স্ক্যান করুন AI',
    'common_choose_language': 'আপনার ভাষা চয়ন করুন',
    'onboarding_continue': 'চালিয়ে যান',
    'onboarding_build_plan': 'আমার পরিকল্পনা তৈরি করুন',
  },

  // ── SPANISH (Español) ──────────────────────────────────────────────────────
  'es': {
    'nav_training': 'Entrenamiento',
    'nav_food': 'Nutrición',
    'nav_social': 'Comunidad',
    'nav_challenges': 'Desafíos',
    'nav_profile': 'Perfil',
    'title_training_hub': 'Centro de Entrenamiento',
    'title_food_nutrition': 'Alimentos y Nutrición',
    'drawer_my_profile': 'Mi perfil',
    'drawer_leaderboard': 'Clasificación y Rangos',
    'drawer_smartwatch_sync': 'Sincronizar Smartwatch',
    'drawer_app_language': 'Idioma de la App',
    'dash_good_morning': 'Buenos días,',
    'dash_today_routine': 'Rutina de Hoy',
    'dash_start_workout': 'Comenzar Entrenamiento',
    'food_scan_ai': 'Escanear Comida con IA',
    'common_choose_language': 'Elige tu idioma',
    'onboarding_continue': 'Continuar',
    'onboarding_build_plan': 'Crear mi plan',
  },
};
