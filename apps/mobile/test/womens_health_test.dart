import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vyra/screens/womens_health_screen.dart';
import 'package:vyra/services/womens_health_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('🌸 WomensHealthService Core Unit Tests', () {
    test('init() loads default state cleanly', () async {
      final service = WomensHealthService.instance;
      await service.init();

      expect(service.isPregnancyMode, false);
      expect(service.doctorInstructions.isNotEmpty, true);
      expect(service.customReminders.isNotEmpty, true);
    });

    test('computes cycle analytics and detects phases accurately', () async {
      final service = WomensHealthService.instance;
      final today = DateTime(2026, 11, 3);

      final analytics = service.computeCycleAnalytics(referenceDate: today);

      expect(analytics['currentCycleDay'], isNotNull);
      expect(analytics['phase'], isNotNull);
      expect(analytics['phaseName'], isNotNull);
      expect(analytics['daysUntilNext'], greaterThanOrEqualTo(1));
      expect(analytics['nextPeriodDate'], isNotNull);
      expect(analytics['ovulationDate'], isNotNull);
      expect(analytics['fertileStart'], isNotNull);
      expect(analytics['fertileEnd'], isNotNull);
      expect(analytics['regularityDiagnosis'], contains('Regular'));
    });

    test('computes pregnancy analytics from LMP with fruit milestone', () async {
      final service = WomensHealthService.instance;
      final lmp = DateTime.now().subtract(const Duration(days: 140)); // ~20 weeks
      await service.setPregnancyLmp(lmp);

      final analytics = service.computePregnancyAnalytics();

      expect(analytics['currentWeek'], 21);
      expect(analytics['trimester'], MaternalTrimester.second);
      expect(analytics['trimesterName'], contains('2nd Trimester'));
      expect(analytics['daysUntilDelivery'], greaterThan(0));

      final milestone = analytics['milestone'] as MaternalFetalMilestone;
      expect(milestone.fruitAnalogy, contains('Banana'));
      expect(milestone.approximateWeightGrams, greaterThan(200));
      expect(milestone.developmentHighlights.isNotEmpty, true);
    });

    test('generates 24-hour Chrono-routine for all cycle phases', () {
      final service = WomensHealthService.instance;

      for (final phase in FeminaPhase.values) {
        final routine = service.getFeminaChronoRoutine(phase);
        expect(routine.length, 8);
        expect(routine.first.periodOfDay, 'morning_wake');
        expect(routine.last.periodOfDay, 'bedtime');
        expect(routine.any((s) => s.periodOfDay == 'breakfast'), true);
        expect(routine.any((s) => s.periodOfDay == 'lunch'), true);
        expect(routine.any((s) => s.periodOfDay == 'dinner'), true);
      }
    });

    test('generates 24-hour Maternal Chrono-routine with bedside crackers protocol', () {
      final service = WomensHealthService.instance;
      final routine = service.getMaternalChronoRoutine(12, MaternalTrimester.first);

      expect(routine.length, 8);
      final wake = routine.firstWhere((s) => s.periodOfDay == 'morning_wake');
      expect(wake.nutritionOrAction.toLowerCase(), contains('crackers'));

      final nap = routine.firstWhere((s) => s.periodOfDay == 'afternoon_rest');
      expect(nap.guidance, contains('Inferior Vena Cava'));
    });

    test('generates fruit therapy with strict contraindications for pregnancy', () {
      final service = WomensHealthService.instance;
      final fruitGuide = service.getMaternalFruitTherapy(MaternalTrimester.first);

      expect(fruitGuide.recommendedFruits.any((f) => f.name == 'Pomegranate'), true);
      expect(fruitGuide.recommendedFruits.any((f) => f.name == 'Fresh Avocado'), true);

      final greenPapaya = fruitGuide.avoidOrCautionFruits.firstWhere((c) => c.name.contains('Papaya'));
      expect(greenPapaya.riskLevel, 'strict_avoid');
      expect(greenPapaya.scientificMechanism, contains('Papain'));
    });

    test('generates sleep sanctuary with left-lateral SOS protocol', () {
      final service = WomensHealthService.instance;
      final sleepProtocol = service.getMaternalSleepProtocol(24, MaternalTrimester.second);

      expect(sleepProtocol.targetSleepHours, contains('8.5'));
      expect(sleepProtocol.optimalPosture, contains('Left-Lateral'));
      expect(sleepProtocol.circadianTip, contains('Week 16'));
    });

    test('generates medication schedule with strict Iron vs Calcium timing rule', () {
      final service = WomensHealthService.instance;
      final meds = service.getMaternalMedicationSchedule(20, MaternalTrimester.second);

      final iron = meds.firstWhere((m) => m.name.contains('Iron'));
      expect(iron.interactionWarning, contains('NEVER take Calcium and Iron together'));

      final calcium = meds.firstWhere((m) => m.name.contains('Calcium'));
      expect(calcium.interactionWarning, contains('NEVER take Calcium and Iron together'));
    });

    test('generates partner empathy guide with dos, donts, gifts and share text', () {
      final service = WomensHealthService.instance;
      final guide = service.getFeminaPartnerGuide(FeminaPhase.menstrual, 2);

      expect(guide.dosList.isNotEmpty, true);
      expect(guide.dontsList.isNotEmpty, true);
      expect(guide.suggestedGiftsAndCare.any((g) => g['item']!.contains('Dark Chocolate')), true);
      expect(guide.readyToShareMessage, contains('VYRA'));
      expect(guide.readyToShareMessage, contains('Day 2'));
    });

    test('generates smartwatch biometric telemetry with BBT offset', () {
      final service = WomensHealthService.instance;
      final watch = service.getFeminaSmartWatchSync(FeminaPhase.luteal);

      expect(watch.skinTemperatureOffsetCelsius, greaterThan(0.3));
      expect(watch.biphasicOvulationConfirmed, true);
      expect(watch.bloodOxygenSpo2, greaterThanOrEqualTo(95));
      expect(watch.biometricInsight, contains('Basal Body Temperature'));
    });

    test('custom care reminders CRUD operations', () async {
      final service = WomensHealthService.instance;
      await service.init();

      final initialCount = service.customReminders.length;
      final testReminder = CareReminderItem(
        id: 'test_rem_1',
        category: 'medication',
        title: 'Prenatal Vitamin D3',
        timeSlot: '10:00 AM',
        notes: 'Take with meal',
      );

      await service.addCareReminder(testReminder);
      expect(service.customReminders.length, initialCount + 1);

      await service.toggleCareReminder('test_rem_1');
      final toggled = service.customReminders.firstWhere((r) => r.id == 'test_rem_1');
      expect(toggled.isEnabled, false);

      await service.deleteCareReminder('test_rem_1');
      expect(service.customReminders.any((r) => r.id == 'test_rem_1'), false);
    });

    test('records and retrieves fetal kick counting sessions', () async {
      final service = WomensHealthService.instance;
      await service.init();

      await service.recordKickSession(10, 1200);
      expect(service.kickSessions.isNotEmpty, true);
      expect(service.kickSessions.first.kickCount, 10);
      expect(service.kickSessions.first.durationSeconds, 1200);
    });
  });

  group('🌸 WomensHealthScreen Widget Tests', () {
    testWidgets('renders FeminaCycle mode and toggles to MaternalCare mode without overflows', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      await tester.pumpWidget(
        const MaterialApp(
          home: WomensHealthScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check header and mode toggle
      expect(find.text('FeminaCycle™'), findsOneWidget);
      expect(find.text('🌸 Periods & Cycles'), findsOneWidget);
      expect(find.text('🤰 9-Month Pregnancy'), findsOneWidget);

      // Check Hero Dial & Chrono Timeline
      expect(find.text('24-Hour Circadian Care Chrono-Rhythm'), findsOneWidget);
      expect(find.text('Fruit Therapy & Seed Cycling'), findsOneWidget);
      expect(find.text('Sleep Sanctuary Protocol'), findsOneWidget);
      expect(find.text('Clinical Medication & Supplement Schedule'), findsOneWidget);
      expect(find.text('Natural Clinical Home Remedies'), findsOneWidget);
      expect(find.text('Restorative Asanas for Pain Relief'), findsOneWidget);
      expect(find.text('1-Tap Daily Symptom & Flow Logger'), findsOneWidget);

      // Tap Mode Switcher to switch to MaternalCare
      await tester.tap(find.text('🤰 9-Month Pregnancy'));
      await tester.pumpAndSettle();

      // Check MaternalCare elements
      expect(find.text('MaternalCare™'), findsOneWidget);
      expect(find.text('Pregnancy Fruit Safety & Superfoods'), findsOneWidget);
      expect(find.text('Maternal Sleep Sanctuary (SOS)'), findsOneWidget);
      expect(find.text('Pregnancy Discomfort Home Remedies'), findsOneWidget);
      expect(find.text('Daily Doctor\'s Orders & Compliance'), findsOneWidget);
      expect(find.text('Fetal Kick Counter'), findsOneWidget);
      expect(find.text('Sonography & Clinical Scans Roadmap'), findsOneWidget);

      // Verify zero overflow errors
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens Partner Sync, Reminders, and Watch Sync sheets cleanly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      await tester.pumpWidget(
        const MaterialApp(
          home: WomensHealthScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Open Partner Sync
      await tester.tap(find.text('Partner Sync'));
      await tester.pumpAndSettle();

      expect(find.text('Partner Sync™ Empathy Companion'), findsOneWidget);
      expect(find.text('🧠 What She Is Biologically Experiencing:'), findsOneWidget);
      expect(find.text('Share Update to Partner (WhatsApp / SMS)'), findsOneWidget);

      // Close sheet
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // 2. Open Reminders Sheet
      await tester.tap(find.text('Reminders'));
      await tester.pumpAndSettle();

      expect(find.text('Care & Health Reminders'), findsOneWidget);

      // Close sheet
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // 3. Open Watch Sync Sheet
      await tester.tap(find.text('Watch Sync'));
      await tester.pumpAndSettle();

      expect(find.text('SmartWatch Vitals & Telemetry'), findsOneWidget);
      expect(find.text('Skin Temp / BBT'), findsOneWidget);
      expect(find.text('Resting HR'), findsOneWidget);

      // Close sheet
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('interacts with Fetal Kick Counter and saves session', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1100));

      await tester.pumpWidget(
        const MaterialApp(
          home: WomensHealthScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Pregnancy mode
      await tester.tap(find.text('🤰 9-Month Pregnancy'));
      await tester.pumpAndSettle();

      // Scroll to kick counter using primary vertical scrollable
      await tester.scrollUntilVisible(
        find.text('Fetal Kick Counter'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('TAP KICK'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);

      // Tap Kick button 3 times
      await tester.tap(find.text('TAP KICK'));
      await tester.pump();
      await tester.tap(find.text('TAP KICK'));
      await tester.pump();
      await tester.tap(find.text('TAP KICK'));
      await tester.pump();

      expect(find.text('3'), findsOneWidget);

      // Save session (which stops the timer)
      await tester.tap(find.text('Save Session'));
      await tester.pumpAndSettle();

      expect(find.text('0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
