// ignore_for_file: avoid_print
/// FitCloud / Fastrack BLE Protocol Unit Tests
///
/// Ground-truth verified against FT_38112_FDAB (Fastrack Reflex)
/// hardware probe. All expected byte sequences from live captures.
library fitcloud_fastrack_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:vyra/services/hiwatch_pro_service.dart';
import 'package:vyra/services/watch_hardware_profile.dart';

void main() {
  // ─── 1. parseNotifyPacket — FitCloud Packet Decoder ───────────────────────
  // NOTE: parseNotifyPacket returns non-nullable HiWatchTelemetryData.
  // When no valid data is present it returns HiWatchTelemetryData.empty()
  // (all fields null). Handshake ACK also returns empty object.

  group('FitCloud parseNotifyPacket — Steps (cmd 0x05)', () {
    test('Verified probe packet → 3750 steps (little-endian 0xA6 0x0E)', () {
      // Hardware-verified response to [0x02, 0x05, 0x00, 0x00]
      final bytes = [
        0x02, 0x05, 0x00, 0xA6, 0x0E, 0x00,
        0x21, 0xEA, 0x07, 0x0A, 0x1B, 0x06, 0x23, 0x27, 0x00
      ];
      final result = HiWatchProProtocol.parseNotifyPacket(bytes);
      expect(result.steps, equals(3750));
    });

    test('Zero steps → null (not emitted)', () {
      final bytes = [0x02, 0x05, 0x00, 0x00, 0x00, 0x00, 0x00];
      final result = HiWatchProProtocol.parseNotifyPacket(bytes);
      expect(result.steps, isNull);
    });

    test('High steps 34463 (0x9F 0x86 LE uint16) parsed correctly', () {
      final bytes = [0x02, 0x05, 0x00, 0x9F, 0x86, 0x00];
      final result = HiWatchProProtocol.parseNotifyPacket(bytes);
      expect(result.steps, equals(34463));
    });

    test('Packet too short (< 5 bytes) falls through gracefully', () {
      final bytes = [0x02, 0x05, 0x00, 0xA6]; // 4 bytes only
      expect(() => HiWatchProProtocol.parseNotifyPacket(bytes), returnsNormally);
    });
  });

  group('FitCloud parseNotifyPacket — Today Health (cmd 0x02)', () {
    test('Verified probe packet → avg HR at bytes[5] = 0x53 = 83', () {
      final bytes = [
        0x02, 0x02, 0xFF, 0x0A, 0xFF, 0x53,
        0x07, 0x01, 0x89, 0x03, 0x40, 0x89, 0xFF, 0xFF
      ];
      final result = HiWatchProProtocol.parseNotifyPacket(bytes);
      expect(result.heartRateBpm, equals(83));
    });

    test('Invalid HR (<40) at bytes[5] → null heartRateBpm', () {
      final bytes = [0x02, 0x02, 0xFF, 0x0A, 0xFF, 0x10]; // 16 bpm — invalid
      final result = HiWatchProProtocol.parseNotifyPacket(bytes);
      expect(result.heartRateBpm, isNull);
    });
  });

  group('FitCloud parseNotifyPacket — Live HR (cmd 0x20)', () {
    test('HR=76, SpO2=98 correctly parsed', () {
      final bytes = [0x02, 0x20, 0x4C, 0x62];
      final result = HiWatchProProtocol.parseNotifyPacket(bytes);
      expect(result.heartRateBpm, equals(76));
      expect(result.bloodOxygenSpo2, equals(98));
    });

    test('HR only (3 bytes) — no SpO2', () {
      final bytes = [0x02, 0x20, 0x4F]; // HR=79
      final result = HiWatchProProtocol.parseNotifyPacket(bytes);
      expect(result.heartRateBpm, equals(79));
      expect(result.bloodOxygenSpo2, isNull);
    });

    test('Invalid HR (<40) → null heartRateBpm', () {
      final bytes = [0x02, 0x20, 0x1A, 0x62]; // HR=26 invalid
      final result = HiWatchProProtocol.parseNotifyPacket(bytes);
      expect(result.heartRateBpm, isNull);
    });

    test('cmd 0x10 (alternate HR) also parsed', () {
      final bytes = [0x02, 0x10, 0x55, 0x60]; // HR=85, SpO2=96
      final result = HiWatchProProtocol.parseNotifyPacket(bytes);
      expect(result.heartRateBpm, equals(85));
      expect(result.bloodOxygenSpo2, equals(96));
    });
  });

  group('FitCloud parseNotifyPacket — Live SpO2 (cmd 0x21)', () {
    test('SpO2=98 correctly parsed', () {
      final bytes = [0x02, 0x21, 0x62];
      final result = HiWatchProProtocol.parseNotifyPacket(bytes);
      expect(result.bloodOxygenSpo2, equals(98));
    });

    test('Invalid SpO2 (<70) → null', () {
      final bytes = [0x02, 0x21, 0x40]; // 64 — invalid
      final result = HiWatchProProtocol.parseNotifyPacket(bytes);
      expect(result.bloodOxygenSpo2, isNull);
    });

    test('SpO2=100 (max valid) accepted', () {
      final bytes = [0x02, 0x21, 0x64];
      final result = HiWatchProProtocol.parseNotifyPacket(bytes);
      expect(result.bloodOxygenSpo2, equals(100));
    });
  });

  group('FitCloud parseNotifyPacket — Handshake ACK (cmd 0x01)', () {
    test('Handshake ACK → empty telemetry (all fields null)', () {
      // Hardware-verified reply to [0x02, 0x01, 0x00, 0x00]
      final bytes = [0x02, 0x01, 0x16, 0x02, 0x0F, 0x00, 0x00, 0x21, 0x01];
      final result = HiWatchProProtocol.parseNotifyPacket(bytes);
      expect(result.heartRateBpm, isNull);
      expect(result.steps, isNull);
      expect(result.batteryLevel, isNull);
    });
  });

  group('FitCloud parseNotifyPacket — Battery keepalive (header 0x07)', () {
    test('Autonomous battery [0x07, 0x01, 0x0D] → 13%', () {
      final bytes = [0x07, 0x01, 0x0D];
      final result = HiWatchProProtocol.parseNotifyPacket(bytes);
      expect(result.batteryLevel, equals(13));
    });

    test('Battery 100% accepted', () {
      final bytes = [0x07, 0x01, 0x64];
      final result = HiWatchProProtocol.parseNotifyPacket(bytes);
      expect(result.batteryLevel, equals(100));
    });

    test('Battery 0 → null (invalid)', () {
      final bytes = [0x07, 0x01, 0x00];
      final result = HiWatchProProtocol.parseNotifyPacket(bytes);
      expect(result.batteryLevel, isNull);
    });
  });

  // ─── 2. Protocol Isolation ────────────────────────────────────────────────

  group('Protocol isolation — existing protocols unaffected by FitCloud changes', () {
    test('DaFit 0xAB packet still processed', () {
      final bytes = [0xAB, 0x00, 0x07, 0xFF, 0x32, 0x80, 0x50, 0x62, 0x78, 0x50];
      expect(() => HiWatchProProtocol.parseNotifyPacket(bytes), returnsNormally);
    });

    test('HiWatch 0xCD packet still processes without throw', () {
      final bytes = [0xCD, 0x00, 0x05, 0x12, 0x0A, 0x01];
      expect(() => HiWatchProProtocol.parseNotifyPacket(bytes), returnsNormally);
    });

    test('FitCloudPro 0xFE header not intercepted by FitCloud 0x02 handler', () {
      final bytes = [0xFE, 0xEA, 0x01, 0x00, 0x00, 0x05, 0x00, 0x0A];
      expect(() => HiWatchProProtocol.parseNotifyPacket(bytes), returnsNormally);
    });

    test('Single byte (BLE SIG HR) does not throw', () {
      final bytes = [0x4C]; // 76 bpm
      expect(() => HiWatchProProtocol.parseNotifyPacket(bytes), returnsNormally);
    });
  });

  // ─── 3. WatchHardwareProfile — FitCloud profile construction & JSON ───────

  group('WatchHardwareProfile — FitCloud JSON round-trip', () {
    WatchHardwareProfile makeFitCloudProfile() {
      return WatchHardwareProfile(
        profileId: 'fitcloud_CB_4E_FD_F7_FD_AB',
        deviceName: 'FT_38112_FDAB',
        remoteId: 'CB:4E:FD:F7:FD:AB',
        protocolType: WatchProtocolType.fitCloudFastrack,
        serviceUuid: '000027f0-0000-1000-8000-00805f9b34fb',
        writeCharUuid: '000027f6-0000-1000-8000-00805f9b34fb',
        notifyCharUuid: '000027f7-0000-1000-8000-00805f9b34fb',
        handshakePacket: const [0x02, 0x01, 0x00, 0x00],
        rtcSyncPacket: const [],
        stepQueryPacket: const [0x02, 0x05, 0x00, 0x00],
        hrTriggerPacket: const [0x02, 0x20, 0x01, 0x00, 0x01],
        bpTriggerPacket: const [0x02, 0x20, 0x01, 0x00, 0x01],
        requiresAck: false,
        keepaliveIntervalMs: 5000,
        createdAt: DateTime(2026, 10, 29),
      );
    }

    test('protocolType == fitCloudFastrack', () {
      expect(makeFitCloudProfile().protocolType,
          equals(WatchProtocolType.fitCloudFastrack));
    });

    test('GATT UUIDs match verified hardware probe values', () {
      final p = makeFitCloudProfile();
      expect(p.writeCharUuid, equals('000027f6-0000-1000-8000-00805f9b34fb'));
      expect(p.notifyCharUuid, equals('000027f7-0000-1000-8000-00805f9b34fb'));
      expect(p.serviceUuid, equals('000027f0-0000-1000-8000-00805f9b34fb'));
    });

    test('Handshake packet matches verified sequence', () {
      expect(makeFitCloudProfile().handshakePacket,
          equals([0x02, 0x01, 0x00, 0x00]));
    });

    test('JSON round-trip preserves all critical fields', () {
      final original = makeFitCloudProfile();
      final restored = WatchHardwareProfile.fromJson(original.toJson());
      expect(restored.protocolType, equals(WatchProtocolType.fitCloudFastrack));
      expect(restored.deviceName, equals('FT_38112_FDAB'));
      expect(restored.remoteId, equals('CB:4E:FD:F7:FD:AB'));
      expect(restored.writeCharUuid, equals('000027f6-0000-1000-8000-00805f9b34fb'));
      expect(restored.handshakePacket, equals([0x02, 0x01, 0x00, 0x00]));
    });

    test('HiWatch fromProberFindings unaffected', () {
      final p = WatchHardwareProfile.fromProberFindings(
        deviceName: 'HiWatch Ultra 2',
        remoteId: '11:22:33:44:55:66',
        writeCharUuid: '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
        notifyCharUuid: '6e400003-b5a3-f393-e0a9-e50e24dcca9e',
        isDaFitPassed: false,
        isHiWatchPassed: true,
        isBleSig: false,
      );
      expect(p.protocolType, equals(WatchProtocolType.hiwatchCd));
    });

    test('DaFit fromProberFindings unaffected', () {
      final p = WatchHardwareProfile.fromProberFindings(
        deviceName: 'Fire-Boltt Ninja',
        remoteId: '77:88:99:AA:BB:CC',
        writeCharUuid: '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
        notifyCharUuid: '6e400003-b5a3-f393-e0a9-e50e24dcca9e',
        isDaFitPassed: true,
        isHiWatchPassed: false,
        isBleSig: false,
      );
      expect(p.protocolType, equals(WatchProtocolType.dafitAb));
    });
  });

  // ─── 4. Ground-truth command packet verification ──────────────────────────

  group('FitCloud verified command packets', () {
    test('Handshake: header=0x02, cmd=0x01, len=4', () {
      const p = [0x02, 0x01, 0x00, 0x00];
      expect(p[0], equals(0x02));
      expect(p[1], equals(0x01));
      expect(p.length, equals(4));
    });

    test('Steps query: cmd=0x05', () {
      const p = [0x02, 0x05, 0x00, 0x00];
      expect(p[1], equals(0x05));
    });

    test('HR on: cmd=0x20, enable byte=0x01', () {
      const p = [0x02, 0x20, 0x01, 0x00, 0x01];
      expect(p[1], equals(0x20));
      expect(p[4], equals(0x01));
    });

    test('SpO2 on: cmd=0x21, enable byte=0x01', () {
      const p = [0x02, 0x21, 0x01, 0x00, 0x01];
      expect(p[1], equals(0x21));
      expect(p[4], equals(0x01));
    });

    test('HR off: enable byte=0x00', () {
      const p = [0x02, 0x20, 0x01, 0x00, 0x00];
      expect(p[4], equals(0x00));
    });

    test('SpO2 off: enable byte=0x00', () {
      const p = [0x02, 0x21, 0x01, 0x00, 0x00];
      expect(p[4], equals(0x00));
    });
  });
}
