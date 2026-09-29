import 'package:flutter_test/flutter_test.dart';
import 'package:vyra/services/hiwatch_pro_service.dart';

void main() {
  group('HiWatchProProtocol Command Builders', () {
    test('buildTurnOnRealTimeStepCommand produces exact FitPro byte sequence', () {
      final cmd = HiWatchProProtocol.buildTurnOnRealTimeStepCommand();
      expect(cmd, equals([0xCD, 0x00, 0x07, 0x07, 0x01, 0x00, 0x00, 0x00, 0x00]));
    });

    test('buildRequestLiveMetricsCommand produces immediate step query packet', () {
      final cmd = HiWatchProProtocol.buildRequestLiveMetricsCommand();
      expect(cmd, equals([0xCD, 0x00, 0x04, 0x07, 0x01]));
    });

    test('buildStartHeartRateMeasureCommand triggers continuous HR & SpO2 sensors', () {
      final cmd = HiWatchProProtocol.buildStartHeartRateMeasureCommand();
      expect(cmd, equals([0xCD, 0x00, 0x05, 0x09, 0x01, 0x01]));
    });

    test('buildDaFitStepQueryCommand produces DaFit / HryFine query packet', () {
      final cmd = HiWatchProProtocol.buildDaFitStepQueryCommand();
      expect(cmd, equals([0xAB, 0x00, 0x04, 0xFF, 0x31]));
    });

    test('buildUniversalHeartbeatCommand produces keep-alive packet', () {
      final cmd = HiWatchProProtocol.buildUniversalHeartbeatCommand();
      expect(cmd, equals([0xCD, 0x00, 0x03, 0x01]));
    });

    test('buildFindWatchCommand produces motor vibration packet', () {
      final cmd = HiWatchProProtocol.buildFindWatchCommand();
      expect(cmd, equals([0xCD, 0x00, 0x04, 0x08, 0x01]));
    });

    test('buildSyncTimeCommand accurately encodes timestamp components', () {
      final testDate = DateTime(2026, 9, 29, 14, 30, 45);
      final cmd = HiWatchProProtocol.buildSyncTimeCommand(testDate);
      expect(cmd, equals([
        0xCD,
        0x00,
        0x09,
        0x01,
        26, // 2026 % 100
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

    test('returns empty HiWatchTelemetryData for incomplete or invalid packets', () {
      final shortPacket = [0xCD];
      final emptyData = HiWatchProProtocol.parseNotifyPacket(shortPacket);
      expect(emptyData.isEmpty, isTrue);
      expect(emptyData.heartRateBpm, isNull);
      expect(emptyData.steps, isNull);
    });
  });
}
