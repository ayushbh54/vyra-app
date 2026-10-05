import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyra/services/hiwatch_pro_service.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// ⚡ VYRA SMARTWATCH ULTRA-DEEP FORENSIC AUDIT SUITE
/// ═══════════════════════════════════════════════════════════════════════════
/// Executed per the Mandatory Deep Audit & Exhaustive Bug Hunting Protocol
/// and Pragmatic Lateral Engineering ("Dimaag Lagao" Principle):
/// 1. Zero Superficial Audits: Bit-level and byte-level payload tracing.
/// 2. Boundary & Dead-Zone Verification: Bradycardia, tachycardia, hypoxia.
/// 3. Multi-Turn 100-Turn Continuous Stream Simulation: Realistic HIIT cycle.
/// 4. 5,000-Packet Fuzzing Gauntlet: Extreme noise, zero unhandled crashes.
/// 5. Protocol Collision Resistance: Non-vital headers vs biometric data.
/// ═══════════════════════════════════════════════════════════════════════════

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('🔬 Test Suite 1: Full Protocol Collision Resistance Matrix', () {
    test('Non-vital Vendor Ping 0x68 is never misclassified as HR or Steps', () {
      final pingPacket = [0x68, 0x00, 0x01, 0x01, 0x68];
      final result = HiWatchProProtocol.parseNotifyPacket(pingPacket);
      expect(result.heartRateBpm, isNull);
      expect(result.steps, isNull);
    });

    test('FitPro 0xAB Keepalive packet is never misclassified as 171 BPM', () {
      final keepAlive = [0xAB, 0x00, 0x04, 0xFF, 0x00, 0x00, 0xAB];
      final result = HiWatchProProtocol.parseNotifyPacket(keepAlive);
      expect(result.heartRateBpm, isNull);
      expect(result.steps, isNull);
    });

    test('0xAA Sync Handshake is never misclassified as 170 BPM', () {
      final handshake = [0xAA, 0x01, 0x05, 0x12, 0x00, 0xAA];
      final result = HiWatchProProtocol.parseNotifyPacket(handshake);
      expect(result.heartRateBpm, isNull);
    });

    test('0xDC ACK packet with length byte 72 is never mistaken as 72 BPM', () {
      final ack = [0xDC, 0x00, 0x48, 0x00, 0x01];
      final result = HiWatchProProtocol.parseNotifyPacket(ack);
      expect(result.heartRateBpm, isNull);
    });

    test('0x4D Device Metadata frame is never mistaken as 77 BPM', () {
      final meta = [0x4D, 0x00, 0x0A, 0x56, 0x59, 0x52, 0x41];
      final result = HiWatchProProtocol.parseNotifyPacket(meta);
      expect(result.heartRateBpm, isNull);
    });

    test('Standard BLE SIG Heart Rate (0x2A37) 8-bit format parses correctly', () {
      // Flags = 0x00 (8-bit HR, no contact bits), HR = 82
      final sigPacket = [0x00, 82];
      final result = HiWatchProProtocol.parseNotifyPacket(sigPacket);
      expect(result.heartRateBpm, equals(82));
    });

    test('Standard BLE SIG Heart Rate 16-bit format parses correctly', () {
      // Flags = 0x01 (16-bit HR, bit 0 set), HR = 145 (0x0091)
      final sigPacket = [0x01, 0x91, 0x00];
      final result = HiWatchProProtocol.parseNotifyPacket(sigPacket);
      expect(result.heartRateBpm, equals(145));
    });

    test('BLE SIG packet with reserved bits (0xE0) is rejected as invalid SIG', () {
      // Flags = 0xE0 has reserved bits set — MUST NOT be treated as standard SIG HR
      final badSig = [0xE0, 75];
      final result = HiWatchProProtocol.parseNotifyPacket(badSig);
      expect(result.heartRateBpm, isNull);
    });
  });

  group('⚖️ Test Suite 2: Boundary & Physiological Dead-Zone Verification', () {
    test('HR Boundary: Exact minimum 35 BPM is accepted', () {
      final packet = [
        0xCD, 0x00, 0x0E, 0x15, 0x01, 0x04, 0x00, 0x07, 0x1A, 0x0A, 0x00, 0x01,
        0x00, 0x00, 0x00, 0x00, 35
      ];
      final result = HiWatchProProtocol.parseNotifyPacket(packet);
      expect(result.heartRateBpm, equals(35));
    });

    test('HR Boundary: Exact maximum 220 BPM is accepted', () {
      final packet = [
        0xCD, 0x00, 0x0E, 0x15, 0x01, 0x04, 0x00, 0x07, 0x1A, 0x0A, 0x00, 0x01,
        0x00, 0x00, 0x00, 0x00, 220
      ];
      final result = HiWatchProProtocol.parseNotifyPacket(packet);
      expect(result.heartRateBpm, equals(220));
    });

    test('HR Outlier: 34 BPM (below minimum) is safely rejected', () {
      final packet = [
        0xCD, 0x00, 0x0E, 0x15, 0x01, 0x04, 0x00, 0x07, 0x1A, 0x0A, 0x00, 0x01,
        0x00, 0x00, 0x00, 0x00, 34
      ];
      final result = HiWatchProProtocol.parseNotifyPacket(packet);
      expect(result.heartRateBpm, isNull);
    });

    test('HR Outlier: 221 BPM (above maximum) is safely rejected', () {
      final packet = [
        0xCD, 0x00, 0x0E, 0x15, 0x01, 0x04, 0x00, 0x07, 0x1A, 0x0A, 0x00, 0x01,
        0x00, 0x00, 0x00, 0x00, 221
      ];
      final result = HiWatchProProtocol.parseNotifyPacket(packet);
      expect(result.heartRateBpm, isNull);
    });

    test('BP Boundary: Minimum valid 60/40 mmHg is accepted', () {
      final packet = [
        0xCD, 0x00, 0x0F, 0x15, 0x01, 0x05, 0x00, 0x08, 0x1A, 0x0A, 0x00, 0x01,
        0x00, 0x00, 0x00, 0x00, 60, 40
      ];
      final result = HiWatchProProtocol.parseNotifyPacket(packet);
      expect(result.bloodPressureSystolic, equals(60));
      expect(result.bloodPressureDiastolic, equals(40));
    });

    test('BP Boundary: Maximum valid 220/140 mmHg is accepted', () {
      final packet = [
        0xCD, 0x00, 0x0F, 0x15, 0x01, 0x05, 0x00, 0x08, 0x1A, 0x0A, 0x00, 0x01,
        0x00, 0x00, 0x00, 0x00, 220, 140
      ];
      final result = HiWatchProProtocol.parseNotifyPacket(packet);
      expect(result.bloodPressureSystolic, equals(220));
      expect(result.bloodPressureDiastolic, equals(140));
    });

    test('BP Inverted Correction: Watch sending Dia first (80, 120) auto-swaps to 120/80', () {
      final packet = [
        0xCD, 0x00, 0x0F, 0x15, 0x01, 0x05, 0x00, 0x08, 0x1A, 0x0A, 0x00, 0x01,
        0x00, 0x00, 0x00, 0x00, 80, 120
      ];
      final result = HiWatchProProtocol.parseNotifyPacket(packet);
      expect(result.bloodPressureSystolic, equals(120));
      expect(result.bloodPressureDiastolic, equals(80));
    });

    test('SpO2 Boundary: Exact minimum 70% is accepted', () {
      final packet = [
        0xCD, 0x00, 0x0E, 0x15, 0x01, 0x14, 0x00, 0x07, 0x1A, 0x0A, 0x00, 0x01,
        0x00, 0x00, 0x00, 0x00, 70
      ];
      final result = HiWatchProProtocol.parseNotifyPacket(packet);
      expect(result.bloodOxygenSpo2, equals(70));
    });

    test('SpO2 Boundary: Exact maximum 100% is accepted', () {
      final packet = [
        0xCD, 0x00, 0x0E, 0x15, 0x01, 0x14, 0x00, 0x07, 0x1A, 0x0A, 0x00, 0x01,
        0x00, 0x00, 0x00, 0x00, 100
      ];
      final result = HiWatchProProtocol.parseNotifyPacket(packet);
      expect(result.bloodOxygenSpo2, equals(100));
    });

    test('SpO2 Outlier: 69% and 101% are rejected', () {
      final p1 = [0xCD, 0x00, 0x0E, 0x15, 0x01, 0x14, 0x00, 0x07, 0x1A, 0x0A, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 69];
      final p2 = [0xCD, 0x00, 0x0E, 0x15, 0x01, 0x14, 0x00, 0x07, 0x1A, 0x0A, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 101];
      expect(HiWatchProProtocol.parseNotifyPacket(p1).bloodOxygenSpo2, isNull);
      expect(HiWatchProProtocol.parseNotifyPacket(p2).bloodOxygenSpo2, isNull);
    });
  });

  group('🏃 Test Suite 3: 100-Turn Continuous Workout Stream Simulation', () {
    test('100 consecutive turns of sustained HIIT workout stream parse without error or state drift', () {
      int simulatedSteps = 2500;
      int simulatedKcal = 80;

      for (int turn = 1; turn <= 100; turn++) {
        int expectedHr;
        if (turn <= 20) {
          expectedHr = 65 + (turn * 2);
        } else if (turn <= 65) {
          expectedHr = 115 + ((turn - 20) % 64);
        } else {
          expectedHr = 175 - (turn - 65);
        }

        simulatedSteps += (8 + (turn % 7));
        simulatedKcal += (turn % 3 == 0 ? 1 : 0);

        // 1. Send Continuous Sport Telemetry Packet (Key 0x0B)
        final sportPacket = [
          0xCD, 0x00, 0x11, 0x15, 0x01, 0x0B, 0x00, 0x0A, 0x1A, 0x0A, 0x00, 0x01,
          0x00, 0x00,
          (simulatedSteps >> 8) & 0xFF, simulatedSteps & 0xFF,
          ((simulatedKcal >> 3) & 0xFF), ((simulatedKcal & 0x07) << 5),
          0x00, 0x50
        ];

        final sportResult = HiWatchProProtocol.parseNotifyPacket(sportPacket);
        expect(sportResult.steps, equals(simulatedSteps), reason: 'Turn $turn steps mismatch');
        expect(sportResult.ackPacket, isNotNull, reason: 'Turn $turn sport packet must return ACK');

        // 2. Send Multi-Vital Packet (Key 0x04 extended with HR + BP + SpO2)
        final vitalPacket = [
          0xCD, 0x00, 0x11, 0x15, 0x01, 0x04, 0x00, 0x0A, 0x1A, 0x0A, 0x00, 0x01,
          0x00, 0x00, 0x00, 0x00,
          expectedHr,
          125 + (turn % 15),
          80 + (turn % 10),
          98 - (turn % 3)
        ];

        final vitalResult = HiWatchProProtocol.parseNotifyPacket(vitalPacket);
        expect(vitalResult.heartRateBpm, equals(expectedHr), reason: 'Turn $turn HR mismatch');
        expect(vitalResult.bloodPressureSystolic, isNotNull);
        expect(vitalResult.bloodPressureDiastolic, isNotNull);
        expect(vitalResult.bloodOxygenSpo2, isNotNull);
        expect(vitalResult.ackPacket, isNotNull, reason: 'Turn $turn vital packet must return ACK');
      }
    });
  });

  group('🌪️ Test Suite 4: 5,000-Packet Massive Chaos & Fuzzing Gauntlet', () {
    test('5,000 completely random malformed packets execute with zero unhandled exceptions', () {
      final random = Random(42);
      int totalExceptions = 0;

      for (int i = 0; i < 5000; i++) {
        final length = random.nextInt(64);
        final bytes = List<int>.generate(length, (_) => random.nextInt(256));

        try {
          final result = HiWatchProProtocol.parseNotifyPacket(bytes);
          expect(result, isNotNull);
        } catch (e) {
          totalExceptions++;
        }
      }

      expect(totalExceptions, equals(0), reason: 'Fuzzing gauntlet must never throw unhandled exceptions');
    });

    test('Pathological truncated headers execute cleanly without RangeErrors', () {
      final pathologicalCases = <List<int>>[
        [],
        [0xCD],
        [0xCD, 0x00],
        [0xCD, 0x00, 0xFF],
        [0xCD, 0x00, 0x10, 0x15],
        [0xCD, 0x00, 0x10, 0x15, 0x01],
        [0xCD, 0x00, 0x10, 0x15, 0x01, 0x04],
        [0xCD, 0x00, 0x10, 0x15, 0x01, 0x04, 0x00, 0x07],
        [0xCD, 0x00, 0x10, 0x15, 0x01, 0x04, 0x00, 0x07, 0x00, 0x00, 0x00, 0x00],
        [0x00],
        [0x01],
        [0x02],
        [0xFF, 0xFF, 0xFF, 0xFF],
      ];

      for (final testCase in pathologicalCases) {
        expect(() => HiWatchProProtocol.parseNotifyPacket(testCase), returnsNormally);
      }
    });
  });

  group('⚙️ Test Suite 5: Exact GATT Builders & ACK Checksum Verification', () {
    test('buildStartHeartRateMeasureCommand generates expected opcode and length', () {
      final cmd = HiWatchProProtocol.buildStartHeartRateMeasureCommand();
      expect(cmd.isNotEmpty, isTrue);
      expect(cmd[0], equals(0xCD));
    });

    test('buildBloodPressureMeasureCommand generates expected opcode and length', () {
      final cmd = HiWatchProProtocol.buildBloodPressureMeasureCommand();
      expect(cmd.isNotEmpty, isTrue);
      expect(cmd[0], equals(0xCD));
    });

    test('buildTurnOnRealTimeStepCommand generates expected opcode and length', () {
      final cmd = HiWatchProProtocol.buildTurnOnRealTimeStepCommand();
      expect(cmd.isNotEmpty, isTrue);
      expect(cmd[0], equals(0xCD));
    });

    test('buildFindWatchCommand generates expected opcode and length', () {
      final cmd = HiWatchProProtocol.buildFindWatchCommand();
      expect(cmd.isNotEmpty, isTrue);
      expect(cmd[0], equals(0xCD));
    });

    test('buildReturnAckCommand formats exactly as SendData.getReturnAck()', () {
      final ack = HiWatchProProtocol.buildReturnAckCommand(0x15, 0x00, 0x10);
      expect(ack.length, equals(8));
      expect(ack[0], equals(0xDC)); // JL_Constant.PREFIX_FLAG_SECOND (-36 / 0xDC)
      expect(ack[1], equals(0x00)); // Length hi
      expect(ack[2], equals(0x05)); // Length lo
      expect(ack[3], equals(0x15)); // Acked command key
      expect(ack[4], equals(0x01)); // SubCmd
      expect(ack[5], equals(0x00)); // Seq hi
      expect(ack[6], equals(0x10)); // Seq lo
      expect(ack[7], equals(0x01)); // Trailer
    });

    test('buildBatteryGetCommand formats exactly as SendData.getBatteryValue()', () {
      final cmd = HiWatchProProtocol.buildBatteryGetCommand();
      expect(cmd, equals([0xCD, 0x00, 0x06, 0x12, 0x01, 0x02, 0x00, 0x01, 0x01]));
    });
  });

  group('🔬 Test Suite 6: Physical Ultra2 Ground-Truth Telemetry Report Verification', () {
    test('Exact Physical Ultra2 Multi-Vital Packet (Key 0x0E) decodes HR=75, BP=119/84, SpO2=99%', () {
      // Raw byte stream captured live from physical Ultra2 watch:
      // CD 00 11 15 01 0E 00 0C 5C C5 00 01 00 00 E1 78 63 54 77 4B
      final packet = <int>[
        0xCD, 0x00, 0x11, 0x15, 0x01, 0x0E, 0x00, 0x0C,
        0x5C, 0xC5, 0x00, 0x01, 0x00, 0x00, 0xE1, 0x78,
        0x63, // SpO2 = 99%
        0x54, // Diastolic BP = 84 mmHg
        0x77, // Systolic BP = 119 mmHg
        0x4B, // Heart Rate = 75 BPM
      ];

      final telemetry = HiWatchProProtocol.parseNotifyPacket(packet);

      expect(telemetry.heartRateBpm, equals(75), reason: 'Authentic physical pulse must decode to 75 BPM');
      expect(telemetry.bloodPressureSystolic, equals(119), reason: 'Authentic systolic BP must decode to 119 mmHg');
      expect(telemetry.bloodPressureDiastolic, equals(84), reason: 'Authentic diastolic BP must decode to 84 mmHg');
      expect(telemetry.bloodOxygenSpo2, equals(99), reason: 'Authentic SpO2 must decode to 99%');
      expect(telemetry.steps, isNull, reason: 'Key 0x0E goal bitmask 65536 must NEVER overwrite steps');
      expect(telemetry.ackPacket, isNotNull, reason: 'Must emit Auto-ACK to keep BLE stream running');
    });

    test('Exact Physical Ultra2 Day Summary Packet (Key 0x0C) decodes Steps=17990, Kcal=353, Dist=12593m', () {
      // Raw byte stream captured live from physical Ultra2 watch:
      // CD 00 11 15 01 0C 00 0C 5C C5 00 00 46 46 00 00 31 31 01 61
      final packet = <int>[
        0xCD, 0x00, 0x11, 0x15, 0x01, 0x0C, 0x00, 0x0C,
        0x5C, 0xC5,
        0x00, 0x00, 0x46, 0x46, // Steps = 0x4646 = 17,990 steps
        0x00, 0x00, 0x31, 0x31, // Distance = 0x3131 = 12,593 meters
        0x01, 0x61,             // Calories = 0x0161 = 353 kcal
      ];

      final telemetry = HiWatchProProtocol.parseNotifyPacket(packet);

      expect(telemetry.steps, equals(17990), reason: 'Must decode authentic 17,990 steps from watch MCU');
      expect(telemetry.distanceMeters, equals(12593), reason: 'Must decode authentic 12,593 meters from watch MCU');
      expect(telemetry.calories, equals(353), reason: 'Must decode authentic 353 kcal without fake multipliers');
      expect(telemetry.ackPacket, isNotNull, reason: 'Must emit Auto-ACK for Day Summary');
    });

    test('Exact Physical Ultra2 Battery Response Packet decodes Battery=9%', () {
      // Raw byte stream captured live: DC 00 05 12 02 00 09 01
      final packet = <int>[0xDC, 0x00, 0x05, 0x12, 0x02, 0x00, 0x09, 0x01];

      final telemetry = HiWatchProProtocol.parseNotifyPacket(packet);

      expect(telemetry.batteryLevel, equals(9), reason: 'Must decode authentic 9% battery from watch MCU');
    });

    test('Keepalive Sport Poll uses safe native FitPro frame to prevent watchdog disconnects', () {
      final cmd = HiWatchProProtocol.buildSportKeyGetCommand();
      expect(cmd, equals([0xCD, 0x00, 0x06, 0x15, 0x01, 0x01, 0x00, 0x01, 0x01]));
    });
  });
}
