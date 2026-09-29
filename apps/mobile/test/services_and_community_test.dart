import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vyra/models/models.dart';
import 'package:vyra/services/readings_history_service.dart';
import 'package:vyra/services/report_history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReportHistoryService & SavedBiomarker Tests', () {
    test('SavedBiomarker supports both property access and dynamic map indexing', () {
      const biomarker = SavedBiomarker(
        name: 'Hemoglobin',
        value: '14.5',
        unit: 'g/dL',
        status: 'normal',
        referenceRange: '13.5 - 17.5',
        insight: 'Optimal oxygen carrying capacity.',
      );

      // Property access
      expect(biomarker.name, equals('Hemoglobin'));
      expect(biomarker.value, equals('14.5'));
      expect(biomarker.unit, equals('g/dL'));
      expect(biomarker.status, equals('normal'));
      expect(biomarker.referenceRange, equals('13.5 - 17.5'));
      expect(biomarker.insight, equals('Optimal oxygen carrying capacity.'));

      // Dynamic indexing operator []
      expect(biomarker['name'], equals('Hemoglobin'));
      expect(biomarker['value'], equals('14.5'));
      expect(biomarker['unit'], equals('g/dL'));
      expect(biomarker['status'], equals('normal'));
      expect(biomarker['referenceRange'], equals('13.5 - 17.5'));
      expect(biomarker['insight'], equals('Optimal oxygen carrying capacity.'));
      expect(biomarker['summary'], equals('Optimal oxygen carrying capacity.'));
      expect(biomarker['invalid_key'], isNull);
    });

    test('SavedBiomarker.fromJson correctly handles alias keys', () {
      final jsonWithAliases = {
        'marker': 'Serum Ferritin',
        'value': 95,
        'unit': 'ng/mL',
        'status': 'normal',
        'referenceRange': '30 - 400',
        'summary': 'Iron reserves are balanced.',
      };

      final bio = SavedBiomarker.fromJson(jsonWithAliases);
      expect(bio.name, equals('Serum Ferritin'));
      expect(bio.value, equals('95'));
      expect(bio.unit, equals('ng/mL'));
      expect(bio.insight, equals('Iron reserves are balanced.'));
    });

    test('SavedReportItem serializes and deserializes accurately', () {
      final report = SavedReportItem(
        id: 'rep-001',
        timestamp: DateTime(2026, 9, 29, 10, 0),
        labName: 'Dr Lal PathLabs',
        reportDate: '29 Sep 2026',
        biomarkers: [
          const SavedBiomarker(
            name: 'Blood Glucose (Fasting)',
            value: '92',
            unit: 'mg/dL',
            status: 'normal',
            referenceRange: '70 - 99',
            insight: 'Healthy fasting glucose level.',
          ),
        ],
        insights: ['Your metabolic profile is in an athletic state.'],
        urgentReferral: false,
      );

      final json = report.toJson();
      expect(json['id'], equals('rep-001'));
      expect(json['labName'], equals('Dr Lal PathLabs'));
      expect((json['biomarkers'] as List).length, equals(1));

      final restored = SavedReportItem.fromJson(json);
      expect(restored.id, equals('rep-001'));
      expect(restored.labName, equals('Dr Lal PathLabs'));
      expect(restored.biomarkers.first.name, equals('Blood Glucose (Fasting)'));
      expect(restored.biomarkers.first.value, equals('92'));
    });

    test('ReportHistoryService saves, lists, and deletes reports in mock storage', () async {
      SharedPreferences.setMockInitialValues({});
      final service = ReportHistoryService.instance;
      await service.init();

      final reportA = SavedReportItem(
        id: 'rpt-a',
        timestamp: DateTime(2026, 9, 28, 9, 0),
        labName: 'City Lab A',
        reportDate: '28 Sep 2026',
        biomarkers: [],
        insights: ['Insight A'],
      );

      final reportB = SavedReportItem(
        id: 'rpt-b',
        timestamp: DateTime(2026, 9, 29, 9, 0),
        labName: 'City Lab B',
        reportDate: '29 Sep 2026',
        biomarkers: [],
        insights: ['Insight B'],
      );

      await service.saveReport(reportA);
      await service.saveReport(reportB);

      final currentReports = await service.getReports();
      expect(currentReports.length, equals(2));
      expect(currentReports.first.id, equals('rpt-b')); // Most recent first

      await service.deleteReport('rpt-a');
      final afterDelete = await service.getReports();
      expect(afterDelete.length, equals(1));
      expect(afterDelete.first.id, equals('rpt-b'));
    });
  });

  group('ReadingsHistoryService Zero-Data-Loss Audit Tests', () {
    test('SavedReadingEntry serializes and deserializes accurately', () {
      final entry = SavedReadingEntry(
        id: 'reading-101',
        timestamp: DateTime(2026, 9, 29, 11, 15),
        formattedDateTime: '29/09/2026 11:15',
        steps: 8420,
        waterMl: 2100,
        heartRateBpm: 74,
        weightKg: 71.5,
      );

      final json = entry.toJson();
      expect(json['id'], equals('reading-101'));
      expect(json['steps'], equals(8420));
      expect(json['heartRateBpm'], equals(74));
      expect(json['weightKg'], equals(71.5));

      final restored = SavedReadingEntry.fromJson(json);
      expect(restored.id, equals('reading-101'));
      expect(restored.steps, equals(8420));
      expect(restored.waterMl, equals(2100));
      expect(restored.heartRateBpm, equals(74));
      expect(restored.weightKg, equals(71.5));
    });

    test('ReadingsHistoryService persists real-time telemetry entries reliably', () async {
      SharedPreferences.setMockInitialValues({});
      final service = ReadingsHistoryService.instance;
      await service.init();

      final reading1 = SavedReadingEntry(
        id: 'read-1',
        timestamp: DateTime(2026, 9, 29, 12, 0),
        formattedDateTime: '29/09/2026 12:00',
        steps: 5000,
        waterMl: 1500,
        heartRateBpm: 68,
        weightKg: 70.0,
      );

      await service.saveEntry(reading1);
      expect(service.entries.length, equals(1));
      expect(service.entries.first.steps, equals(5000));
      expect(service.entries.first.heartRateBpm, equals(68));

      await service.deleteEntry('read-1');
      expect(service.entries.isEmpty, isTrue);
    });
  });

  group('Clubs & Events Model and Filter Tests', () {
    test('ClubItem parses and correctly filters by city tag or description', () {
      const clubs = [
        ClubItem(
          id: 'c1',
          name: 'Delhi Striders Running Club',
          description: 'Weekly morning 10k runs at Lodhi Garden',
          interestTag: 'Running',
          memberCount: 230,
          joined: true,
        ),
        ClubItem(
          id: 'c2',
          name: 'Mumbai Cyclists Hub',
          description: 'Marine Drive weekend morning rides',
          interestTag: 'Cycling',
          memberCount: 512,
          joined: false,
        ),
        ClubItem(
          id: 'c3',
          name: 'Bengaluru Functional Calisthenics',
          description: 'Bodyweight strength at Cubbon Park, Bengaluru',
          interestTag: 'Calisthenics',
          memberCount: 145,
          joined: false,
        ),
      ];

      // Simulate ClubsScreen filter logic
      List<ClubItem> filterClubs(String city) {
        if (city == 'All Cities') return clubs;
        final q = city.toLowerCase();
        return clubs.where((c) {
          final text = '${c.name} ${c.description} ${c.interestTag}'.toLowerCase();
          return text.contains(q);
        }).toList();
      }

      expect(filterClubs('All Cities').length, equals(3));
      
      final delhiClubs = filterClubs('Delhi');
      expect(delhiClubs.length, equals(1));
      expect(delhiClubs.first.id, equals('c1'));

      final mumbaiClubs = filterClubs('Mumbai');
      expect(mumbaiClubs.length, equals(1));
      expect(mumbaiClubs.first.id, equals('c2'));

      final blrClubs = filterClubs('Bengaluru');
      expect(blrClubs.length, equals(1));
      expect(blrClubs.first.id, equals('c3'));

      final puneClubs = filterClubs('Pune');
      expect(puneClubs.isEmpty, isTrue);
    });

    test('EventItem parses correctly and retains registration status', () {
      final json = {
        'id': 'ev-99',
        'title': 'Gwalior 21K Half Marathon',
        'sport': 'run',
        'location': 'Fort Circuit, Gwalior',
        'startsAt': '2026-10-15T06:00:00Z',
        'registered': true,
      };

      final event = EventItem.fromJson(json);
      expect(event.id, equals('ev-99'));
      expect(event.title, equals('Gwalior 21K Half Marathon'));
      expect(event.sport, equals('run'));
      expect(event.location, equals('Fort Circuit, Gwalior'));
      expect(event.registered, isTrue);
    });

    test('PostItem visibility and social interaction properties work as expected', () {
      const post = PostItem(
        id: 'post-1',
        userId: 'user-42',
        body: 'Just finished 15km morning endurance cycle ride!',
        imageUrl: 'https://images.unsplash.com/photo-example',
        visibility: 'followers',
        authorHandle: 'cyclist_pro',
        authorName: 'Rohan Sharma',
        kudosGiven: true,
        kudosCount: 28,
        commentCount: 4,
        createdAt: '2026-09-29T08:30:00Z',
      );

      expect(post.isFollowersOnly, isTrue);
      expect(post.kudosGiven, isTrue);
      expect(post.kudosCount, equals(28));
      expect(post.commentCount, equals(4));
    });
  });
}
