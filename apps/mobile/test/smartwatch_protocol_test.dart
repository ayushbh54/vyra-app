import 'package:flutter_test/flutter_test.dart';
import 'package:vyra/services/hiwatch_pro_service.dart';

void main() {
  group('HiWatchProProtocol Command Builders', () {
    test('buildTurnOnRealTimeStepCommand produces exact FitPro byte sequence', () {
      final cmd = HiWatchProProtocol.buildTurnOnRealTimeStepCommand();
      expect(cmd, equals([0xCD, 0x00, 0x06, 0x15, 0x01, 0x06, 0x00, 0x01, 0x01]));
    });

    test('buildRequestLiveMetricsCommand produces immediate step query packet', () {
      final cmd = HiWatchProProtocol.buildRequestLiveMetricsCommand();
      expect(cmd, equals([0xCD, 0x00, 0x06, 0x15, 0x01, 0x06, 0x00, 0x01, 0x01]));
    });

    test('buildStartHeartRateMeasureCommand triggers continuous HR & SpO2 sensors', () {
      final cmd = HiWatchProProtocol.buildStartHeartRateMeasureCommand();
      expect(cmd, equals([0xCD, 0x00, 0x04, 0x12, 0x24, 0x00, 0x01]));
    });

    test('buildDaFitStepQueryCommand produces DaFit / HryFine query packet', () {
      final cmd = HiWatchProProtocol.buildDaFitStepQueryCommand();
      expect(cmd, equals([0xAB, 0x00, 0x04, 0xFF, 0x50, 0x00, 0x00]));
    });

    test('buildUniversalHeartbeatCommand produces keep-alive packet', () {
      final cmd = HiWatchProProtocol.buildUniversalHeartbeatCommand();
      expect(cmd, equals([0xAB, 0x00, 0x04, 0xFF, 0x56, 0x00, 0x00]));
    });

    test('buildFindWatchCommand produces motor vibration packet', () {
      final cmd = HiWatchProProtocol.buildFindWatchCommand();
      expect(cmd, equals([0xCD, 0x00, 0x04, 0x08, 0x01]));
    });

    test('buildSyncTimeCommand accurately encodes timestamp components', () {
      final testDate = DateTime(2026, 9, 29, 14, 30, 45);
      final cmd = HiWatchProProtocol.buildSyncTimeCommand(testDate);
      expect(cmd, equals([
        0xAB,
        0x00,
        0x08,
        0xFF,
        0x92,
        26, // 2026 - 2000
        9,  // September
        29, // Day 29
        14, // 14 hours
        30, // 30 minutes
        45, // 45 seconds
      ]));
    });
  });

  group('HiWatchProProtocol UUIDs and Device Recognition', () {
    test('standard Nordic UART & FitPro GATT service UUIDs are valid', () {
      expect(HiWatchProProtocol.serviceUuid, equals('6e40ff01-b5a3-f393-e0a9-e50e24dcca9e'));
      expect(HiWatchProProtocol.writeCharacteristicUuid, equals('6e40ff02-b5a3-f393-e0a9-e50e24dcca9e'));
      expect(HiWatchProProtocol.notifyCharacteristicUuid, equals('6e40ff03-b5a3-f393-e0a9-e50e24dcca9e'));
      expect(HiWatchProProtocol.cccdDescriptorUuid, equals('00002902-0000-1000-8000-00805f9b34fb'));
    });

    test('recognizedDeviceNames covers major target smartwatches', () {
      const names = HiWatchProProtocol.recognizedDeviceNames;
      expect(names, contains('HiWatch Pro'));
      expect(names, contains('HiWatchPro'));
      expect(names, contains('HiWatch Ultra'));
      expect(names, contains('FitPro'));
      expect(names, contains('T800 Ultra'));
      expect(names, contains('Watch 8 Ultra'));
      expect(names, contains('Watch 9 Ultra'));
    });
  });

  group('HiWatchProProtocol Notify Packet Parsing', () {
    test('parses standard BLE SIG 8-bit Heart Rate Measurement (UUID 0x2A37)', () {
      // flags = 0x00 (8-bit HR), heartRate = 72 bpm
      final packet = [0x00, 72];
      final data = HiWatchProProtocol.parseNotifyPacket(packet);
      expect(data.heartRateBpm, equals(72));
      expect(data.isEmpty, isFalse);
    });

    test('parses standard BLE SIG 16-bit Heart Rate Measurement', () {
      // flags = 0x01 (16-bit HR), bytes = [0x01, 0x88, 0x00] -> 136 bpm
      final packet = [0x01, 0x88, 0x00];
      final data = HiWatchProProtocol.parseNotifyPacket(packet);
      expect(data.heartRateBpm, equals(136));
      expect(data.isEmpty, isFalse);
    });

    test('filters physiological heart rate outliers from standard BLE SIG', () {
      // Aberrant 15 bpm or 240 bpm should not parse as valid live HR
      expect(HiWatchProProtocol.parseNotifyPacket([0x00, 15]).heartRateBpm, isNull);
      expect(HiWatchProProtocol.parseNotifyPacket([0x00, 240]).heartRateBpm, isNull);
    });

    test('parses proprietary HiWatch/FitPro (0xCD) Step and Distance Telemetry', () {
      // Header: 0xCD, 0x00, Cmd: 0x07, Sub: 0x00, Steps: [0x00, 0x12, 0x34] = 4660, Kcal: [0x00, 0xC8] = 200, Dist: [0x0E, 0x10] = 3600m
      final packet = [0xCD, 0x00, 0x07, 0x00, 0x00, 0x12, 0x34, 0x00, 0xC8, 0x0E, 0x10];
      final data = HiWatchProProtocol.parseNotifyPacket(packet);
      expect(data.steps, equals(4660));
      expect(data.calories, equals(200));
      expect(data.distanceMeters, equals(3600));
      expect(data.isEmpty, isFalse);
    });

    test('parses proprietary HiWatch/FitPro (0xCD) Live HR & SpO2 Telemetry', () {
      // Header: 0xCD, 0x00, Cmd: 0x09, Sub: 0x00, HR: 78 bpm, SpO2: 98%
      final packet = [0xCD, 0x00, 0x09, 0x00, 78, 98];
      final data = HiWatchProProtocol.parseNotifyPacket(packet);
      expect(data.heartRateBpm, equals(78));
      expect(data.bloodOxygenSpo2, equals(98));
      expect(data.isEmpty, isFalse);
    });

    test('parses DaFit/Shenzhen (0xAB) Step packet', () {
      // Header: 0xAB, Cmd: 0x51, Steps: [0x00, 0x0A, 0x00] = 2560, Kcal: [0x00, 0x64] = 100
      final packet = [0xAB, 0x51, 0x00, 0x0A, 0x00, 0x00, 0x64];
      final data = HiWatchProProtocol.parseNotifyPacket(packet);
      expect(data.steps, equals(2560));
      expect(data.calories, equals(100));
      expect(data.isEmpty, isFalse);
    });

    test('parses DaFit/Shenzhen (0xAB) Live HR & SpO2 packet', () {
      // Header: 0xAB, Cmd: 0x09, HR: 84 bpm, SpO2: 99%
      final packet = [0xAB, 0x09, 84, 99];
      final data = HiWatchProProtocol.parseNotifyPacket(packet);
      expect(data.heartRateBpm, equals(84));
      expect(data.bloodOxygenSpo2, equals(99));
      expect(data.isEmpty, isFalse);
    });

    test('parses reverse-engineered APK FitPro packed vitals (HR, BP, SpO2)', () {
      // APK Sport packet with Key 0x04: [CD 00 0E 15 01 04 T0 T1 T2 T3 HR Sys Dia SpO2]
      final packet = [0xCD, 0x00, 0x0E, 0x15, 0x01, 0x04, 0x00, 0x00, 0x00, 0x00, 78, 122, 82, 99];
      final data = HiWatchProProtocol.parseNotifyPacket(packet);
      expect(data.heartRateBpm, equals(78));
      expect(data.bloodPressureSystolic, equals(122));
      expect(data.bloodPressureDiastolic, equals(82));
      expect(data.bloodOxygenSpo2, equals(99));
      expect(data.ackPacket, isNotNull);
      expect(data.ackPacket![0], equals(0xDC));
      expect(data.isEmpty, isFalse);
    });

    test('parses reverse-engineered APK FitPro 64-bit Real-Time Steps Stream (Key 0x0B)', () {
      // 64-bit payload matching APK BaseReceiveData.Sport:
      // steps = 7890 (0x1ED2), cal = 340 (11 bits), dist = 5200 (19 bits)
      // binary: 12 bits offset, 4 bits mode, 16 bits steps, 11 bits cal, 2 bits flags, 19 bits dist
      final binStr = '${100.toRadixString(2).padLeft(12, '0')}'
          '${1.toRadixString(2).padLeft(4, '0')}'
          '${7890.toRadixString(2).padLeft(16, '0')}'
          '${340.toRadixString(2).padLeft(11, '0')}'
          '00'
          '${5200.toRadixString(2).padLeft(19, '0')}';
      final payload = <int>[];
      for (int i = 0; i < 64; i += 8) {
        payload.add(int.parse(binStr.substring(i, i + 8), radix: 2));
      }
      final packet = [0xCD, 0x00, 0x0C, 0x15, 0x01, 0x0B, ...payload];
      final data = HiWatchProProtocol.parseNotifyPacket(packet);
      expect(data.steps, equals(7890));
      expect(data.calories, equals(340));
      expect(data.distanceMeters, equals(5200));
      expect(data.isEmpty, isFalse);
    });

    test('parses reverse-engineered APK FitPro Day Summary (Key 0x0C)', () {
      // APK Sport packet with Key 0x0C: [CD 00 12 15 01 0C Date(4B) Steps(4B) Dist(2B) Cal(2B)]
      // steps = 10450 (0x000028D2), dist = 7800 (0x1E78), cal = 450 (0x01C2)
      final payload = [
        0x00, 0x00, 0x00, 0x00, // Date / record index
        0x00, 0x00, 0x28, 0xD2, // Steps: 10450
        0x1E, 0x78,             // Distance: 7800m
        0x01, 0xC2,             // Calories: 450 kcal
      ];
      final packet = [0xCD, 0x00, 0x12, 0x15, 0x01, 0x0C, ...payload];
      final data = HiWatchProProtocol.parseNotifyPacket(packet);
      expect(data.steps, equals(10450));
      expect(data.distanceMeters, equals(7800));
      expect(data.calories, equals(450));
      expect(data.isEmpty, isFalse);
    });

    test('returns empty HiWatchTelemetryData for incomplete or invalid packets', () {
      final shortPacket = [0xCD];
      final emptyData = HiWatchProProtocol.parseNotifyPacket(shortPacket);
      expect(emptyData.isEmpty, isTrue);
      expect(emptyData.heartRateBpm, isNull);
      expect(emptyData.steps, isNull);
    });
  });
}
