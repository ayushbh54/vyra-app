import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vyra/services/app_localizations.dart';
import 'package:vyra/services/language_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('VYRA Universal Multilingual & Localization Suite', () {
    test('1. kVyraLanguages Catalog Integrity', () {
      expect(kVyraLanguages, isNotEmpty);
      expect(kVyraLanguages.length, greaterThanOrEqualTo(15));

      // Key Indian and international languages must be present
      final codes = kVyraLanguages.map((l) => l.prefsKey).toSet();
      expect(codes.contains('en_IN'), isTrue, reason: 'English (India) must be present');
      expect(codes.contains('hi'), isTrue, reason: 'Hindi must be present');
      expect(codes.contains('hi_LATN'), isTrue, reason: 'Hinglish must be present');
      expect(codes.contains('ta'), isTrue, reason: 'Tamil must be present');
      expect(codes.contains('te'), isTrue, reason: 'Telugu must be present');
      expect(codes.contains('mr'), isTrue, reason: 'Marathi must be present');
      expect(codes.contains('bn'), isTrue, reason: 'Bengali must be present');
      expect(codes.contains('es'), isTrue, reason: 'Spanish must be present');

      // Verify every language has flag emoji, non-empty nativeName, and displayName
      for (final lang in kVyraLanguages) {
        expect(lang.flag, isNotEmpty);
        expect(lang.nativeName, isNotEmpty);
        expect(lang.displayName, isNotEmpty);
        expect(lang.languageCode, isNotEmpty);
      }
    });

    test('2. LanguageService Persistence & Reactive Switching', () async {
      final service = LanguageService.instance;
      await service.init();

      // Switch to Hindi
      final hindi = kVyraLanguages.firstWhere((l) => l.prefsKey == 'hi');
      await service.setLanguage(hindi);
      expect(service.current.languageCode, equals('hi'));
      expect(service.locale.languageCode, equals('hi'));

      // Switch to Hinglish
      final hinglish = kVyraLanguages.firstWhere((l) => l.prefsKey == 'hi_LATN');
      await service.setLanguage(hinglish);
      expect(service.current.languageCode, equals('hi'));
      expect(service.current.countryCode, equals('LATN'));

      // Verify persistence in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('vyra_language'), equals('hi_LATN'));

      // Test recovery from prefs key
      final restored = VyraLanguage.fromPrefsKey('hi_LATN');
      expect(restored.nativeName, equals('Hinglish'));

      // Switch back to English (India)
      final english = kVyraLanguages.firstWhere((l) => l.prefsKey == 'en_IN');
      await service.setLanguage(english);
      expect(service.current.languageCode, equals('en'));
    });

    test('3. AppLocalizations Multi-Language Resolution (en, hi, hi_en, ta, te, es)', () {
      // English
      final l10nEn = AppLocalizations(const Locale('en', 'IN'));
      expect(l10nEn.training, equals('Training'));
      expect(l10nEn.food, equals('Food'));
      expect(l10nEn.goodMorning, equals('Good morning,'));
      expect(l10nEn.todayRoutine, equals("Today's Routine"));
      expect(l10nEn.continueButton, equals('Continue'));
      expect(l10nEn.buildMyPlan, equals('Build my plan'));
      expect(l10nEn.smartwatchSync, contains('Smartwatch Sync'));

      // Hindi
      final l10nHi = AppLocalizations(const Locale('hi'));
      expect(l10nHi.training, equals('ट्रेनिंग'));
      expect(l10nHi.food, equals('आहार'));
      expect(l10nHi.goodMorning, equals('सुप्रभात,'));
      expect(l10nHi.todayRoutine, equals('आज का वर्कआउट रूटीन'));
      expect(l10nHi.continueButton, equals('आगे बढ़ें'));
      expect(l10nHi.buildMyPlan, equals('मेरी योजना बनाएं'));
      expect(l10nHi.smartwatchSync, contains('स्मार्टवॉच सिंक'));

      // Hinglish (hi_LATN)
      final l10nHinglish = AppLocalizations(const Locale('hi', 'LATN'));
      expect(l10nHinglish.food, equals('Khaana'));
      expect(l10nHinglish.goodMorning, equals('Good morning,'));
      expect(l10nHinglish.todayRoutine, equals('Aaj Ka Workout Routine'));
      expect(l10nHinglish.continueButton, equals('Aage Badhein'));
      expect(l10nHinglish.buildMyPlan, equals('Mera Plan Banayein'));
      expect(l10nHinglish.smartwatchSync, contains('Smartwatch'));

      // Tamil
      final l10nTa = AppLocalizations(const Locale('ta'));
      expect(l10nTa.training, equals('பயிற்சி'));
      expect(l10nTa.food, equals('உணவு'));
      expect(l10nTa.goodMorning, equals('காலை வணக்கம்,'));
      expect(l10nTa.continueButton, equals('தொடரவும்'));

      // Telugu
      final l10nTe = AppLocalizations(const Locale('te'));
      expect(l10nTe.training, equals('శిక్షణ'));
      expect(l10nTe.food, equals('ఆహారం'));
      expect(l10nTe.goodMorning, equals('శుభోదయం,'));
      expect(l10nTe.continueButton, equals('కొనసాగించండి'));

      // Spanish
      final l10nEs = AppLocalizations(const Locale('es'));
      expect(l10nEs.training, equals('Entrenamiento'));
      expect(l10nEs.food, equals('Nutrición'));
      expect(l10nEs.goodMorning, equals('Buenos días,'));
      expect(l10nEs.continueButton, equals('Continuar'));
    });

    test('4. Graceful Fallback to English for Missing Keys', () {
      // Spanish may not have every niche key (e.g. watch_calories)
      final l10nEs = AppLocalizations(const Locale('es'));
      // Missing key falls back to English dictionary, never crashes
      expect(l10nEs.t('watch_calories'), equals('CALORIES'));

      // Completely nonexistent key returns raw key string as fallback
      expect(l10nEs.t('nonexistent_arbitrary_key_xyz'), equals('nonexistent_arbitrary_key_xyz'));
    });

    testWidgets('5. Dynamic Reactive Widget Re-rendering on Language Change', (tester) async {
      final service = LanguageService.instance;
      await service.setLanguage(kVyraLanguages.firstWhere((l) => l.prefsKey == 'en_IN'));

      await tester.pumpWidget(
        AnimatedBuilder(
          animation: service,
          builder: (context, _) {
            return MaterialApp(
              locale: service.locale,
              supportedLocales: kVyraLanguages.map((l) => l.locale).toList(),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: Builder(
                builder: (context) {
                  return Scaffold(
                    body: Column(
                      children: [
                        Text(context.l10n.goodMorning, key: const Key('greeting_text')),
                        Text(context.l10n.todayRoutine, key: const Key('routine_text')),
                        Text(context.l10n.continueButton, key: const Key('continue_btn')),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial English rendering
      expect(find.text('Good morning,'), findsOneWidget);
      expect(find.text("Today's Routine"), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      // Switch to Hindi dynamically
      final hindi = kVyraLanguages.firstWhere((l) => l.prefsKey == 'hi');
      await service.setLanguage(hindi);
      await tester.pumpAndSettle();

      // Verify UI automatically updated to Hindi
      expect(find.text('सुप्रभात,'), findsOneWidget);
      expect(find.text('आज का वर्कआउट रूटीन'), findsOneWidget);
      expect(find.text('आगे बढ़ें'), findsOneWidget);

      // Switch to Hinglish dynamically
      final hinglish = kVyraLanguages.firstWhere((l) => l.prefsKey == 'hi_LATN');
      await service.setLanguage(hinglish);
      await tester.pumpAndSettle();

      // Verify UI automatically updated to Hinglish
      expect(find.text('Aaj Ka Workout Routine'), findsOneWidget);
      expect(find.text('Aage Badhein'), findsOneWidget);

      // Reset to English
      await service.setLanguage(kVyraLanguages.firstWhere((l) => l.prefsKey == 'en_IN'));
      await tester.pumpAndSettle();
    });
  });
}
