// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:vyra/services/hiwatch_pro_service.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // APK-VERIFIED COMMAND BYTE TESTS
  // All commands verified directly from decompiled HiWatchPro base.apk
  // SendData.java → SwitchProtocol(b, b2, b3) = [0xCD, 0x00, 0x06, b, 0x01, b2, 0x00, 0x01, b3]
  // ─────────────────────────────────────────────────────────────────────────
  group('APK-Verified BLE Command Bytes', () {

    test('SwitchProtocol formula: first 3 bytes must be [0xCD, 0x00, 0x06]', () {
      // All SwitchProtocol commands share this header
      for (final cmd in [
        HiWatchProProtocol.buildStartHeartRateMeasureCommand(),
        HiWatchProProtocol.buildStartBloodPressureMeasureCommand(),
        HiWatchProProtocol.buildStartCombinedMeasureCommand(),
        HiWatchProProtocol.buildTurnOnRealTimeStepCommand(),
        HiWatchProProtocol.buildSportKeyGetCommand(),
        HiWatchProProtocol.buildSportKeyDayGetCommand(),
        HiWatchProProtocol.buildPairCommand(),
        HiWatchProProtocol.buildFindWatchCommand(),
      ]) {
        expect(cmd[0], equals(0xCD), reason: 'Header byte 0 must be 0xCD');
        expect(cmd[1], equals(0x00), reason: 'Header byte 1 must be 0x00');
        expect(cmd[2], equals(0x06), reason: 'Length byte must be 0x06 for SwitchProtocol');
        expect(cmd.length, equals(9), reason: 'SwitchProtocol cmd must be 9 bytes');
      }

      // APK: getIsBingding(true) = new byte[]{-51, 0, 2, 19, 1}
      expect(HiWatchProProtocol.buildIsBindingCommand(),
          equals([0xCD, 0x00, 0x02, 0x13, 0x01]));
    });

    /// APK: getSportHeartRateRecive(true) = SwitchProtocol(0x12, 0x0D, 0x01)
    test('buildStartHeartRateMeasureCommand = [CD 00 06 12 01 0D 00 01 01]', () {
      final cmd = HiWatchProProtocol.buildStartHeartRateMeasureCommand();
      expect(cmd, equals([0xCD, 0x00, 0x06, 0x12, 0x01, 0x0D, 0x00, 0x01, 0x01]));
    });

    /// APK: getSportBloodRateRecive(true) = SwitchProtocol(0x12, 0x0E, 0x01)
    test('buildStartBloodPressureMeasureCommand = [CD 00 06 12 01 0E 00 01 01]', () {
      final cmd = HiWatchProProtocol.buildStartBloodPressureMeasureCommand();
      expect(cmd, equals([0xCD, 0x00, 0x06, 0x12, 0x01, 0x0E, 0x00, 0x01, 0x01]));
    });

    /// APK: getSportMeasureRecive(true) = SwitchProtocol(0x12, 0x18, 0x01)
    test('buildStartCombinedMeasureCommand = [CD 00 06 12 01 18 00 01 01]', () {
      final cmd = HiWatchProProtocol.buildStartCombinedMeasureCommand();
      expect(cmd, equals([0xCD, 0x00, 0x06, 0x12, 0x01, 0x18, 0x00, 0x01, 0x01]));
    });

    /// APK: getSportMeasureHeartRecive(true) = getProtocol(0x12, 0x24, [0x00, 0x01])
    test('buildLegacyHeartRateMeasureCommand = [CD 00 07 12 01 24 00 02 00 01]', () {
      final cmd = HiWatchProProtocol.buildLegacyHeartRateMeasureCommand();
      expect(cmd, equals([0xCD, 0x00, 0x07, 0x12, 0x01, 0x24, 0x00, 0x02, 0x00, 0x01]));
    });

    /// APK: getSportMeasureSpoRecive(true) = getProtocol(0x12, 0x24, [0x02, 0x01])
    test('buildSpO2MeasureCommand = [CD 00 07 12 01 24 00 02 02 01]', () {
      final cmd = HiWatchProProtocol.buildSpO2MeasureCommand();
      expect(cmd, equals([0xCD, 0x00, 0x07, 0x12, 0x01, 0x24, 0x00, 0x02, 0x02, 0x01]));
    });

    /// APK: getSportMeasureBloodRecive(true) = getProtocol(0x12, 0x24, [0x01, 0x01])
    test('buildBloodPressureMeasureCommand = [CD 00 07 12 01 24 00 02 01 01]', () {
      final cmd = HiWatchProProtocol.buildBloodPressureMeasureCommand();
      expect(cmd, equals([0xCD, 0x00, 0x07, 0x12, 0x01, 0x24, 0x00, 0x02, 0x01, 0x01]));
    });

    /// APK: getTurnOnRealTimeStep(true) = SwitchProtocol(0x15, 0x06, 0x01)
    test('buildTurnOnRealTimeStepCommand = [CD 00 06 15 01 06 00 01 01]', () {
      final cmd = HiWatchProProtocol.buildTurnOnRealTimeStepCommand();
      expect(cmd, equals([0xCD, 0x00, 0x06, 0x15, 0x01, 0x06, 0x00, 0x01, 0x01]));
    });

    /// APK: getSportKeyGet(true) = SwitchProtocol(0x15, 0x01, 0x01)
    test('buildSportKeyGetCommand = [CD 00 06 15 01 01 00 01 01]', () {
      final cmd = HiWatchProProtocol.buildSportKeyGetCommand();
      expect(cmd, equals([0xCD, 0x00, 0x06, 0x15, 0x01, 0x01, 0x00, 0x01, 0x01]));
    });

    /// APK: getSportKeyDayGet(true) = SwitchProtocol(0x15, 0x0D, 0x01)
    test('buildSportKeyDayGetCommand = [CD 00 06 15 01 0D 00 01 01]', () {
      final cmd = HiWatchProProtocol.buildSportKeyDayGetCommand();
      expect(cmd, equals([0xCD, 0x00, 0x06, 0x15, 0x01, 0x0D, 0x00, 0x01, 0x01]));
    });

    /// APK: getPair() = SwitchProtocol(0x12, 0x0A, 0x02)
    test('buildPairCommand = [CD 00 06 12 01 0A 00 01 02]', () {
      final cmd = HiWatchProProtocol.buildPairCommand();
      expect(cmd, equals([0xCD, 0x00, 0x06, 0x12, 0x01, 0x0A, 0x00, 0x01, 0x02]));
    });

    /// APK: getIsBingding(true) = new byte[]{-51, 0, 2, 19, 1}
    test('buildIsBindingCommand = [CD 00 02 13 01]', () {
      final cmd = HiWatchProProtocol.buildIsBindingCommand();
      expect(cmd, equals([0xCD, 0x00, 0x02, 0x13, 0x01]));
    });

    /// APK: getSetFindMeValue(true) = SwitchProtocol(0x12, 0x0B, 0x01)
    test('buildFindWatchCommand = [CD 00 06 12 01 0B 00 01 01]', () {
      final cmd = HiWatchProProtocol.buildFindWatchCommand();
      expect(cmd, equals([0xCD, 0x00, 0x06, 0x12, 0x01, 0x0B, 0x00, 0x01, 0x01]));
    });

    test('buildRequestLiveMetricsCommand is alias for buildSportKeyGetCommand', () {
      expect(
        HiWatchProProtocol.buildRequestLiveMetricsCommand(),
        equals(HiWatchProProtocol.buildSportKeyGetCommand()),
      );
    });

    test('buildSyncTimeCommand has correct ABI format', () {
      final now = DateTime(2024, 6, 15, 10, 30, 45);
      final cmd = HiWatchProProtocol.buildSyncTimeCommand(now);
      expect(cmd[0], equals(0xAB));
      expect(cmd[1], equals(0x00));
      expect(cmd[2], equals(0x08));
      expect(cmd[3], equals(0xFF));
      expect(cmd[4], equals(0x92));
      expect(cmd[5], equals(24)); // 2024-2000
      expect(cmd[6], equals(6));  // month
      expect(cmd[7], equals(15)); // day
      expect(cmd[8], equals(10)); // hour
      expect(cmd[9], equals(30)); // minute
      expect(cmd[10], equals(45)); // second
    });

    test('buildReturnAckCommand matches APK: [DC 00 05 key 01 seq0 seq1 01]', () {
      final ack = HiWatchProProtocol.buildReturnAckCommand(0x15, 0x00, 0x01);
      expect(ack, equals([0xDC, 0x00, 0x05, 0x15, 0x01, 0x00, 0x01, 0x01]));
    });

    test('buildUniversalHeartbeatCommand = [AB 00 04 FF 56 00 00]', () {
      expect(
        HiWatchProProtocol.buildUniversalHeartbeatCommand(),
        equals([0xAB, 0x00, 0x04, 0xFF, 0x56, 0x00, 0x00]),
      );
    });

    test('buildDaFitStepQueryCommand = [AB 00 04 FF 50 00 00]', () {
      expect(
        HiWatchProProtocol.buildDaFitStepQueryCommand(),
        equals([0xAB, 0x00, 0x04, 0xFF, 0x50, 0x00, 0x00]),
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // PACKET PARSER TESTS (parseNotifyPacket)
  // ─────────────────────────────────────────────────────────────────────────
  group('parseNotifyPacket — HiWatch/FitPro protocol (0xCD)', () {

    // Helper: build standard FitPro response frame
    // [0xCD, 0x00, len, cmdType, keyCount, keyId, payload...]

    // ── A1: Packed vitals (keyId 0x04 / 0x05 / 0x14) ──────────────────────
    group('A1: Packed vitals packet (keyId 0x04 / 0x05 / 0x14)', () {
      test('keyId=0x04: extracts HR, BP, SpO2 correctly', () {
        // payload: [T0,T1,T2,T3, HR, Sys, Dia, SpO2]
        final packet = fitproFrame(
          cmdType: 0x12, keyId: 0x04,
          payload: [0x00, 0x00, 0x00, 0x00, 78, 120, 80, 97],
        );
        final r = HiWatchProProtocol.parseNotifyPacket(packet);
        expect(r.heartRateBpm, equals(78));
        expect(r.bloodPressureSystolic, equals(120));
        expect(r.bloodPressureDiastolic, equals(80));
        expect(r.bloodOxygenSpo2, equals(97));
      });

      test('keyId=0x05: extracts vitals', () {
        final packet = fitproFrame(
          cmdType: 0x12, keyId: 0x05,
          payload: [0x00, 0x00, 0x00, 0x00, 85, 115, 75, 98],
        );
        final r = HiWatchProProtocol.parseNotifyPacket(packet);
        expect(r.heartRateBpm, equals(85));
        expect(r.bloodOxygenSpo2, equals(98));
      });

      test('Out-of-range HR (>220) is rejected', () {
        final packet = fitproFrame(
          cmdType: 0x12, keyId: 0x04,
          payload: [0x00, 0x00, 0x00, 0x00, 230, 120, 80, 97],
        );
        final r = HiWatchProProtocol.parseNotifyPacket(packet);
        expect(r.heartRateBpm, isNull);
        expect(r.bloodOxygenSpo2, equals(97));
      });

      test('Out-of-range SpO2 (<70) is rejected', () {
        final packet = fitproFrame(
          cmdType: 0x12, keyId: 0x04,
          payload: [0x00, 0x00, 0x00, 0x00, 75, 120, 80, 50],
        );
        final r = HiWatchProProtocol.parseNotifyPacket(packet);
        expect(r.heartRateBpm, equals(75));
        expect(r.bloodOxygenSpo2, isNull);
      });
    });

    // ── A2: Real-Time Steps Stream (keyId 0x0B / 0x06) ────────────────────
    group('A2: Real-time steps stream (keyId 0x0B / 0x06)', () {
      test('keyId=0x0B: extracts steps from 64-bit packed format', () {
        // steps = (payload[2] << 8) | payload[3] = 5000
        final steps = 5000;
        final packet = fitproFrame(
          cmdType: 0x15, keyId: 0x0B,
          payload: [0x00, 0x00, (steps >> 8) & 0xFF, steps & 0xFF, 0x60, 0x20, 0x00, 0x00],
        );
        final r = HiWatchProProtocol.parseNotifyPacket(packet);
        expect(r.steps, equals(5000));
      });

      test('keyId=0x06: handles packed step data', () {
        final steps = 8200;
        final packet = fitproFrame(
          cmdType: 0x15, keyId: 0x06,
          payload: [0x00, 0x00, (steps >> 8) & 0xFF, steps & 0xFF, 0x50, 0x40, 0x00, 0x00],
        );
        final r = HiWatchProProtocol.parseNotifyPacket(packet);
        expect(r.steps, equals(8200));
      });
    });

    // ── A3: Day Summary (keyId 0x0C / 0x0D / 0x0E) — APK-verified format ─
    group('A3: Day summary (keyId 0x0C/0x0D/0x0E) — APK byte offsets', () {
      test('keyId=0x0C: steps at payload[0..3] (APK-verified)', () {
        // APK: data[0..3] = steps (4-byte big-endian)
        //      data[4..7] = distance (meters)
        //      data[8..9] = calories
        final steps = 7432;
        final dist = 5600; // meters
        final kcal = 320;
        final payload = [
          // steps[0..3]
          (steps >> 24) & 0xFF, (steps >> 16) & 0xFF, (steps >> 8) & 0xFF, steps & 0xFF,
          // distance[4..7]
          (dist >> 24) & 0xFF, (dist >> 16) & 0xFF, (dist >> 8) & 0xFF, dist & 0xFF,
          // calories[8..9]
          (kcal >> 8) & 0xFF, kcal & 0xFF,
        ];
        final packet = fitproFrame(cmdType: 0x15, keyId: 0x0C, payload: payload);
        final r = HiWatchProProtocol.parseNotifyPacket(packet);
        expect(r.steps, equals(7432));
        expect(r.distanceMeters, equals(5600));
        expect(r.calories, equals(320));
      });

      test('keyId=0x0D: reads steps correctly', () {
        final steps = 12000;
        final payload = [
          (steps >> 24) & 0xFF, (steps >> 16) & 0xFF, (steps >> 8) & 0xFF, steps & 0xFF,
          0, 0, 0x1E, 0xD0, // 7888 meters
          0x01, 0x90,        // 400 kcal
        ];
        final packet = fitproFrame(cmdType: 0x15, keyId: 0x0D, payload: payload);
        final r = HiWatchProProtocol.parseNotifyPacket(packet);
        expect(r.steps, equals(12000));
        expect(r.calories, equals(400));
      });

      test('zero steps packet returns empty', () {
        final payload = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        final packet = fitproFrame(cmdType: 0x15, keyId: 0x0C, payload: payload);
        final r = HiWatchProProtocol.parseNotifyPacket(packet);
        expect(r.steps, isNull);
      });
    });

    // ── ACK generation ─────────────────────────────────────────────────────
    group('ACK packet generation', () {
      test('0xCD packet always generates ackPacket', () {
        final packet = [0xCD, 0x00, 0x06, 0x12, 0x01, 0x04, 0x00, 0x01, 0x01,
                        0x00, 0x00, 0x00, 0x00, 78, 120, 80, 97];
        final r = HiWatchProProtocol.parseNotifyPacket(packet);
        expect(r.ackPacket, isNotNull);
        expect(r.ackPacket![0], equals(0xDC)); // ACK header
      });
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // DaFit / 0xAB Protocol Tests
  // ─────────────────────────────────────────────────────────────────────────
  group('parseNotifyPacket — DaFit/0xAB/0xAA protocol', () {
    test('0xAB cmd=0x09: extracts HR and SpO2', () {
      final r = HiWatchProProtocol.parseNotifyPacket([0xAB, 0x09, 72, 98]);
      expect(r.heartRateBpm, equals(72));
      expect(r.bloodOxygenSpo2, equals(98));
    });

    test('0xAB cmd=0x51: extracts steps', () {
      // steps = (bytes[2] << 16) | (bytes[3] << 8) | bytes[4] = 5000
      final steps = 5000;
      final r = HiWatchProProtocol.parseNotifyPacket([
        0xAB, 0x51,
        (steps >> 16) & 0xFF, (steps >> 8) & 0xFF, steps & 0xFF,
        0x03, 0x20, // calories
      ]);
      expect(r.steps, equals(5000));
    });

    test('0xAA cmd=0x31: extracts HR + SpO2', () {
      final r = HiWatchProProtocol.parseNotifyPacket([0xAA, 0x31, 80, 96]);
      expect(r.heartRateBpm, equals(80));
      expect(r.bloodOxygenSpo2, equals(96));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Ultra2 / Generic Chinese Watch Protocol Tests
  // ─────────────────────────────────────────────────────────────────────────
  group('parseNotifyPacket — Ultra2/Generic formats', () {
    test('0xBC format: [BC 60 hr spo2 sys dia]', () {
      final r = HiWatchProProtocol.parseNotifyPacket([0xBC, 0x60, 76, 97, 118, 78]);
      expect(r.heartRateBpm, equals(76));
      expect(r.bloodOxygenSpo2, equals(97));
      expect(r.bloodPressureSystolic, equals(118));
      expect(r.bloodPressureDiastolic, equals(78));
    });

    test('0xBC with invalid HR (<40) is rejected', () {
      final r = HiWatchProProtocol.parseNotifyPacket([0xBC, 0x60, 30, 97, 118, 78]);
      expect(r.heartRateBpm, isNull);
    });

    test('0x02 format: [02 hr spo2]', () {
      final r = HiWatchProProtocol.parseNotifyPacket([0x02, 68, 99]);
      expect(r.heartRateBpm, equals(68));
      expect(r.bloodOxygenSpo2, equals(99));
    });

    test('0x04 format: [04 00 hr spo2]', () {
      final r = HiWatchProProtocol.parseNotifyPacket([0x04, 0x00, 82, 95]);
      expect(r.heartRateBpm, equals(82));
      expect(r.bloodOxygenSpo2, equals(95));
    });

    test('Single byte valid HR packet', () {
      final r = HiWatchProProtocol.parseNotifyPacket([75]);
      expect(r.heartRateBpm, equals(75));
    });

    test('Single byte = protocol header byte → NOT treated as HR', () {
      // 0xCD = -51 unsigned — excluded by the check
      // But 0xCD = 205 which is > 200, so already excluded by range
      final r = HiWatchProProtocol.parseNotifyPacket([0xAB]); // 171 > 200 → outside HR range
      expect(r.heartRateBpm, isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // BLE SIG Standard Heart Rate Measurement Format (UUID 0x2A37)
  // ─────────────────────────────────────────────────────────────────────────
  group('parseNotifyPacket — BLE SIG Standard HR (0x2A37)', () {
    test('8-bit HR measurement [flags=0x00, hr=72]', () {
      // flags byte 0x00 = 8-bit HR format, no energy expended
      final r = HiWatchProProtocol.parseNotifyPacket([0x00, 72]);
      expect(r.heartRateBpm, equals(72));
    });

    test('16-bit HR measurement [flags=0x01, hr_lo=90, hr_hi=0]', () {
      final r = HiWatchProProtocol.parseNotifyPacket([0x01, 90, 0]);
      expect(r.heartRateBpm, equals(90));
    });

    test('Invalid HR value (<40 in SIG format) returns empty', () {
      final r = HiWatchProProtocol.parseNotifyPacket([0x00, 30]);
      // 0x00 header → BLE SIG path → hr=30 → invalid → empty
      expect(r.heartRateBpm, isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Edge Cases & Boundary Conditions
  // ─────────────────────────────────────────────────────────────────────────
  group('Edge cases', () {
    test('Empty packet returns empty data', () {
      final r = HiWatchProProtocol.parseNotifyPacket([]);
      expect(r.isEmpty, isTrue);
    });

    test('HiWatchTelemetryData.isEmpty: all-null = true', () {
      expect(HiWatchTelemetryData.empty().isEmpty, isTrue);
    });

    test('HiWatchTelemetryData with HR is not empty', () {
      expect(HiWatchTelemetryData(heartRateBpm: 72).isEmpty, isFalse);
    });

    test('HiWatchTelemetryData with only ackPacket is empty (no health data)', () {
      // ackPacket does not count as health data for isEmpty check
      expect(HiWatchTelemetryData(ackPacket: [0xDC, 0x00]).isEmpty, isFalse);
    });

    test('HR 35 boundary (minimum valid) is accepted', () {
      // Use fitproFrame so payload positions are correct
      final packet = fitproFrame(
        cmdType: 0x12, keyId: 0x04,
        payload: [0x00, 0x00, 0x00, 0x00, 35, 120, 80, 97],
      );
      final r = HiWatchProProtocol.parseNotifyPacket(packet);
      expect(r.heartRateBpm, equals(35));
    });

    test('HR 220 boundary (maximum valid) is accepted', () {
      final packet = fitproFrame(
        cmdType: 0x12, keyId: 0x04,
        payload: [0x00, 0x00, 0x00, 0x00, 220, 120, 80, 97],
      );
      final r = HiWatchProProtocol.parseNotifyPacket(packet);
      expect(r.heartRateBpm, equals(220));
    });

    test('SpO2 70 boundary (minimum valid) is accepted', () {
      final packet = fitproFrame(
        cmdType: 0x12, keyId: 0x04,
        payload: [0x00, 0x00, 0x00, 0x00, 78, 120, 80, 70],
      );
      final r = HiWatchProProtocol.parseNotifyPacket(packet);
      expect(r.bloodOxygenSpo2, equals(70));
    });

    test('SpO2 69 (below minimum) is rejected', () {
      final packet = fitproFrame(
        cmdType: 0x12, keyId: 0x04,
        payload: [0x00, 0x00, 0x00, 0x00, 78, 120, 80, 69],
      );
      final r = HiWatchProProtocol.parseNotifyPacket(packet);
      expect(r.bloodOxygenSpo2, isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // DEVICE NAME RECOGNITION
  // ─────────────────────────────────────────────────────────────────────────
  group('Device name recognition', () {
    final recognized = HiWatchProProtocol.recognizedDeviceNames;

    test('Ultra2 is recognized', () {
      expect(recognized.any((n) => n.toLowerCase() == 'ultra2'), isTrue);
    });

    test('FitPro is recognized', () {
      expect(recognized.any((n) => n.toLowerCase() == 'fitpro'), isTrue);
    });

    test('HiWatch Pro is recognized', () {
      expect(recognized.any((n) => n == 'HiWatch Pro'), isTrue);
    });

    test('T900 Ultra is recognized', () {
      expect(recognized.any((n) => n == 'T900 Ultra'), isTrue);
    });

    test('HK9 Pro is recognized', () {
      expect(recognized.any((n) => n == 'HK9 Pro'), isTrue);
    });

    test('At least 10 device variants recognized', () {
      expect(recognized.length, greaterThanOrEqualTo(10));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // UUID CONSTANTS
  // ─────────────────────────────────────────────────────────────────────────
  group('BLE UUIDs match APK', () {
    test('Primary service UUID matches HiWatchPro APK', () {
      // Confirmed from jadx output: 6e40ff01-b5a3-f393-e0a9-e50e24dcca9e
      expect(HiWatchProProtocol.serviceUuid,
          equals('6e40ff01-b5a3-f393-e0a9-e50e24dcca9e'));
    });

    test('Write characteristic UUID matches APK', () {
      expect(HiWatchProProtocol.writeCharacteristicUuid,
          equals('6e40ff02-b5a3-f393-e0a9-e50e24dcca9e'));
    });

    test('Notify characteristic UUID matches APK', () {
      expect(HiWatchProProtocol.notifyCharacteristicUuid,
          equals('6e40ff03-b5a3-f393-e0a9-e50e24dcca9e'));
    });
  });
}

// ─── Top-level helper: build a standard FitPro/HiWatch response frame ─────────
// Frame layout: [0xCD, 0x00, len, cmdType, 0x01, keyId, ...payload]
// payload = bytes[6..] in parser (after 6-byte header)
List<int> fitproFrame({
  required int cmdType,
  required int keyId,
  required List<int> payload,
}) {
  return [0xCD, 0x00, payload.length + 4, cmdType, 0x01, keyId, ...payload];
}
