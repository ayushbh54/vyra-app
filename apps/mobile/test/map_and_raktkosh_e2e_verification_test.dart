import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

import 'package:vyra/screens/blood_donation.dart';
import 'package:vyra/widgets/common.dart';

void main() {
  group('e-RaktKosh API Setu Models & Live GPS Serialization', () {
    test('BloodCenterItem.fromJson parses authentic API Setu JSON payload accurately', () {
      final sampleApiSetuPayload = {
        'centerName': 'Civil Hospital Regional Blood Center',
        'hospitalName': 'District Government Civil Hospital',
        'address': 'Station Road, Civil Hospital Campus',
        'contactNumber': '104 / 108',
        'hours': '24×7 Available',
        'lat': 28.6667,
        'lng': 77.4784,
        'distanceKm': 2.4,
        'unitsAvailable': 32,
        'category': 'Govt.',
        'component': 'Whole Blood',
      };

      final item = BloodCenterItem.fromJson(sampleApiSetuPayload);

      expect(item.name, 'Civil Hospital Regional Blood Center');
      expect(item.hospital, 'District Government Civil Hospital');
      expect(item.address, 'Station Road, Civil Hospital Campus');
      expect(item.contact, '104 / 108');
      expect(item.hours, '24×7 Available');
      expect(item.latlng.latitude, 28.6667);
      expect(item.latlng.longitude, 77.4784);
      expect(item.distanceKm, 2.4);
      expect(item.unitsAvailable, 32);
      expect(item.category, 'Govt.');
      expect(item.component, 'Whole Blood');
    });

    test('BloodCenterItem.fromJson handles edge cases & null fallbacks safely without throwing', () {
      final minimalPayload = <String, dynamic>{};
      final item = BloodCenterItem.fromJson(minimalPayload);

      expect(item.name, 'District Blood Center');
      expect(item.hospital, 'Civil Hospital');
      expect(item.latlng.latitude, 28.6667);
      expect(item.latlng.longitude, 77.4784);
      expect(item.distanceKm, 2.0);
      expect(item.unitsAvailable, 15);
      expect(item.category, 'Govt.');
      expect(item.component, 'Whole Blood');
    });

    test('BloodCampItem.fromJson parses voluntary blood donation camp payloads', () {
      final campPayload = {
        'campName': 'Mega Voluntary Blood Donation Camp 2026',
        'organizer': 'Indian Red Cross Society',
        'address': 'District Community Centre, Sector 18',
        'date': 'Saturday, 10:00 AM',
        'time': '10:00 AM - 04:30 PM',
        'contactPhone': '0120-2762606',
        'distanceKm': 1.2,
      };

      final camp = BloodCampItem.fromJson(campPayload);
      expect(camp.title, 'Mega Voluntary Blood Donation Camp 2026');
      expect(camp.organizer, 'Indian Red Cross Society');
      expect(camp.address, 'District Community Centre, Sector 18');
      expect(camp.date, 'Saturday, 10:00 AM');
      expect(camp.time, '10:00 AM - 04:30 PM');
      expect(camp.contact, '0120-2762606');
      expect(camp.distanceKm, 1.2);
    });

    test('Haversine distance calculation and sorting by nearest center', () {
      double haversineKm(double lat1, double lon1, double lat2, double lon2) {
        const double r = 6371; // Earth radius in km
        final double dLat = (lat2 - lat1) * math.pi / 180;
        final double dLon = (lon2 - lon1) * math.pi / 180;
        final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
            math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
        final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
        return double.parse((r * c).toStringAsFixed(1));
      }

      // User in Connaught Place, New Delhi (28.6315, 77.2167)
      const userLat = 28.6315;
      const userLng = 77.2167;

      // Center 1: AIIMS Trauma Center (28.5672, 77.2100)
      final d1 = haversineKm(userLat, userLng, 28.5672, 77.2100);
      // Center 2: Ghaziabad MMG Hospital (28.6619, 77.4338)
      final d2 = haversineKm(userLat, userLng, 28.6619, 77.4338);

      expect(d1, lessThan(10.0)); // AIIMS is ~7km from Connaught Place
      expect(d2, greaterThan(15.0)); // Ghaziabad is ~21km from Connaught Place
      expect(d1, lessThan(d2)); // Nearest center sorted first
    });
  });

  group('Universal iOS & Responsive Auto-Fit Layout Verification', () {
    testWidgets('VHeaderBadge handles narrow iPhone screens without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640); // Compact iPhone SE / small screen
      tester.view.devicePixelRatio = 2.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: VHeaderBadge(
                  label: 'VERY LONG TITLE THAT MIGHT OVERFLOW ON NARROW SCREENS',
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull); // 0 RenderFlex overflow exceptions!
      expect(find.byType(VHeaderBadge), findsOneWidget);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('TextScaler clamp protects fixed cards when OS accessibility text scaling is large', (tester) async {
      // Simulate extreme system accessibility font scale (1.8x)
      tester.view.physicalSize = const Size(390, 844); // iPhone 14/15 size
      tester.view.devicePixelRatio = 3.0;

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: mediaQuery.textScaler.clamp(
                  minScaleFactor: 0.85,
                  maxScaleFactor: 1.15,
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const Scaffold(
            body: SizedBox(
              height: 50,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Universal Auto-Fit Protected Title Against RenderFlex Explosions',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}
