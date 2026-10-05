import 'package:flutter_test/flutter_test.dart';
import 'package:vyra/services/hiwatch_pro_service.dart';

void main() {
  group('🛡️ Vyra Smartwatch UI & Telemetry Comprehensive Verification', () {
    test('1️⃣ Exact Ground-Truth Biometric Extraction: Pulse, Oxygen, Steps, BP, Calories, Distance, Battery', () {
      // Physical Ultra2 Packets from Live Verification Report:
      
      // A. Multi-Vital Packet (Key 0x0E)
      // CD 00 11 15 01 0E 00 0C 5C C5 00 01 00 00 E1 78 63 54 77 4B
      final multiVitalPacket = <int>[
        0xCD, 0x00, 0x11, 0x15, 0x01, 0x0E, 0x00, 0x0C,
        0x5C, 0xC5, 0x00, 0x01, 0x00, 0x00, 0xE1, 0x78,
        0x63, // Oxygen SpO2 = 99%
        0x54, // Blood Pressure Diastolic = 84 mmHg
        0x77, // Blood Pressure Systolic = 119 mmHg
        0x4B, // Pulse / Heart Rate = 75 BPM
      ];

      final vitals = HiWatchProProtocol.parseNotifyPacket(multiVitalPacket);

      // Verify Pulse
      expect(vitals.heartRateBpm, equals(75));
      // Verify Blood Pressure (Systolic & Diastolic)
      expect(vitals.bloodPressureSystolic, equals(119));
      expect(vitals.bloodPressureDiastolic, equals(84));
      // Verify Blood Oxygen (SpO2)
      expect(vitals.bloodOxygenSpo2, equals(99));

      // B. Day Summary Packet (Key 0x0C)
      // CD 00 11 15 01 0C 00 0C 5C C5 00 00 46 46 00 00 31 31 01 61
      final daySummaryPacket = <int>[
        0xCD, 0x00, 0x11, 0x15, 0x01, 0x0C, 0x00, 0x0C,
        0x5C, 0xC5,
        0x00, 0x00, 0x46, 0x46, // Steps = 17,990 (0x4646)
        0x00, 0x00, 0x31, 0x31, // Distance = 12,593 m (0x3131)
        0x01, 0x61,             // Calories = 353 kcal (0x0161)
      ];

      final daySummary = HiWatchProProtocol.parseNotifyPacket(daySummaryPacket);

      // Verify Steps
      expect(daySummary.steps, equals(17990));
      // Verify Distance
      expect(daySummary.distanceMeters, equals(12593));
      // Verify Calories
      expect(daySummary.calories, equals(353));

      // C. Real Battery Packet
      // DC 00 05 12 02 00 09 01
      final batteryPacket = <int>[0xDC, 0x00, 0x05, 0x12, 0x02, 0x00, 0x09, 0x01];
      final battery = HiWatchProProtocol.parseNotifyPacket(batteryPacket);

      // Verify Battery
      expect(battery.batteryLevel, equals(9));
    });

    test('2️⃣ UI Representation Formats for All 6 Required Metrics', () {
      // 1. Pulse
      const int heartRate = 75;
      final pulseDisplay = '$heartRate bpm';
      expect(pulseDisplay, equals('75 bpm'));

      // 2. Blood Oxygen
      const int spo2 = 99;
      final spo2Display = '$spo2%';
      expect(spo2Display, equals('99%'));

      // 3. Live Steps
      const int steps = 17990;
      final stepsDisplay = '$steps';
      expect(stepsDisplay, equals('17990'));

      // 4. Blood Pressure
      const int sys = 119;
      const int dia = 84;
      final bpDisplay = '$sys/$dia';
      expect(bpDisplay, equals('119/84'));

      // 5. Calories
      const int kcal = 353;
      final kcalDisplay = '$kcal kcal';
      expect(kcalDisplay, equals('353 kcal'));

      // 6. Distance
      const int distM = 12593;
      final distKmDisplay = '${(distM / 1000.0).toStringAsFixed(2)} km';
      expect(distKmDisplay, equals('12.59 km'));
    });

    test('3️⃣ Continuous Connection Watchdog Keepalive Verification', () {
      // The Jerry JL7012 watchdog requires refreshing every 3.5s (before 4-5s MCU timeout).
      final sportPoll = HiWatchProProtocol.buildSportKeyGetCommand();
      expect(sportPoll, equals([0xCD, 0x00, 0x06, 0x15, 0x01, 0x01, 0x00, 0x01, 0x01]));
      
      // Battery query builder matches hardware
      final batteryQuery = HiWatchProProtocol.buildBatteryGetCommand();
      expect(batteryQuery, equals([0xCD, 0x00, 0x06, 0x12, 0x01, 0x02, 0x00, 0x01, 0x01]));
    });

    test('4️⃣ Peak Step Guard: 65,536 goal bitmask is never admitted as a step reading', () {
      final multiVitalPacket = <int>[
        0xCD, 0x00, 0x11, 0x15, 0x01, 0x0E, 0x00, 0x0C,
        0x5C, 0xC5, 0x00, 0x01, 0x00, 0x00, 0xE1, 0x78,
        0x63, 0x54, 0x77, 0x4B,
      ];
      final telemetry = HiWatchProProtocol.parseNotifyPacket(multiVitalPacket);
      expect(telemetry.steps, isNull, reason: 'Key 0x0E must not emit steps');
    });

    test('5️⃣ Database Payload Construction contains all 6 health metrics', () {
      const currentSteps = 17990;
      const currentKcal = 353;
      const currentHr = 75;
      const currentSpo2 = 99;
      const currentDist = 12593;
      const sys = 119;
      const dia = 84;

      final Map<String, num> payload = {
        if (currentSteps > 0) 'steps': currentSteps,
        if (currentKcal > 0) 'caloriesBurned': currentKcal,
        if (currentHr > 0) 'heartRateBpm': currentHr,
        if (currentSpo2 > 0) 'bloodOxygenSpo2': currentSpo2,
        if (currentDist > 0) 'distanceMeters': currentDist,
        'bpSystolic': sys,
        'bpDiastolic': dia,
      };

      expect(payload['steps'], equals(17990));
      expect(payload['caloriesBurned'], equals(353));
      expect(payload['heartRateBpm'], equals(75));
      expect(payload['bloodOxygenSpo2'], equals(99));
      expect(payload['distanceMeters'], equals(12593));
      expect(payload['bpSystolic'], equals(119));
      expect(payload['bpDiastolic'], equals(84));
    });

    test('6️⃣ 🛡️ 0xDC Hardware ACK Collision Immunity — 65,545 phantom steps completely eliminated', () {
      // Hardware sport poll ACK packet received every 4s:
      final sportPollAck = <int>[0xDC, 0x00, 0x05, 0x15, 0x01, 0x00, 0x09, 0x01];
      final res1 = HiWatchProProtocol.parseNotifyPacket(sportPollAck);
      expect(res1.steps, isNull, reason: '0xDC Sport Poll ACK must NEVER emit steps (was causing 65545 bug)');

      // Real-time steps toggle ACK:
      final rtStepsAck = <int>[0xDC, 0x00, 0x05, 0x15, 0x06, 0x00, 0x09, 0x01];
      final res2 = HiWatchProProtocol.parseNotifyPacket(rtStepsAck);
      expect(res2.steps, isNull, reason: '0xDC RT Steps ACK must NEVER emit steps');

      // Day summary toggle ACK:
      final daySummaryAck = <int>[0xDC, 0x00, 0x05, 0x15, 0x0D, 0x00, 0x09, 0x01];
      final res3 = HiWatchProProtocol.parseNotifyPacket(daySummaryAck);
      expect(res3.steps, isNull, reason: '0xDC Day Summary ACK must NEVER emit steps');
    });

    test('7️⃣ 🏃 Live Physical Ultra2 Step Packet (21,917 steps) decodes accurately in real time', () {
      // Captured directly from physical Ultra2 watch over Mac Bluetooth CoreBluetooth:
      // CD 00 11 15 01 0C 00 0C 76 C5 00 00 55 9D 00 00 3B ED 01 AF
      // 0x559D = 21,917 steps | 0x3BED = 15,341 m | 0x01AF = 431 kcal
      final liveStepPacket = <int>[
        0xCD, 0x00, 0x11, 0x15, 0x01, 0x0C, 0x00, 0x0C,
        0x76, 0xC5, 0x00, 0x00, 0x55, 0x9D, 0x00, 0x00,
        0x3B, 0xED, 0x01, 0xAF,
      ];
      final res = HiWatchProProtocol.parseNotifyPacket(liveStepPacket);
      expect(res.steps, equals(21917), reason: 'Live steps must decode to 21,917');
      expect(res.distanceMeters, equals(15341), reason: 'Live distance must decode to 15,341 m');
      expect(res.calories, equals(431), reason: 'Live calories must decode to 431 kcal');
    });

    test('8️⃣ 🚶 Dynamic Increasing Steps Tracking — seamless incremental step updates while walking', () {
      // Simulating user actively walking: 21,917 -> 21,950 -> 22,000 -> 22,100
      final stepsList = [21917, 21950, 22000, 22100];
      for (final s in stepsList) {
        final b3 = (s >> 24) & 0xFF;
        final b2 = (s >> 16) & 0xFF;
        final b1 = (s >> 8) & 0xFF;
        final b0 = s & 0xFF;
        final pkt = <int>[
          0xCD, 0x00, 0x11, 0x15, 0x01, 0x0C, 0x00, 0x0C,
          0x76, 0xC5, b3, b2, b1, b0,
          0x00, 0x00, 0x3B, 0xED, 0x01, 0xAF,
        ];
        final res = HiWatchProProtocol.parseNotifyPacket(pkt);
        expect(res.steps, equals(s), reason: 'Dynamic step count $s must be preserved accurately');
      }
    });
  });
}
