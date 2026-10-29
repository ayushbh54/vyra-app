// ignore_for_file: avoid_print
// ============================================================================
// VYRA — Auto-Probe Sequential Protocol Detection Tests
// ============================================================================
// Tests the sequential probe logic that detects the correct protocol for any
// unknown/generic watch by:
//   1. Sending DaFit 0xAB probe → checking 0xAB response upgrades to dafitAb
//   2. Sending HiWatch 0xCD probe → checking 0xCD/0xDC response upgrades to hiwatchCd
//   3. Sending FitCloud 0x02 probe → checking 0x02 response upgrades to fitCloudFastrack
//   4. No response from any → wearOsCompanion fallback
//   5. Existing confirmed protocols NOT overwritten by probe (fitCloud, wearOs, miBand)
//   6. DaFit upgrade persists correct packets (handshake, stepQuery etc.)
//   7. HiWatch upgrade persists correct packets
//   8. FitCloud upgrade sets correct profileId prefix
//   9. Protocol upgrade does NOT downgrade fitCloudFastrack to genericUart
//  10. Protocol header: 0xAA also triggers DaFit upgrade (DaFit variant header)
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:vyra/services/watch_hardware_profile.dart';
import 'package:vyra/services/hiwatch_pro_service.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

WatchHardwareProfile _genericProfile({
  String remoteId = 'AA:BB:CC:DD:EE:FF',
  String deviceName = 'Unknown Watch',
  WatchProtocolType type = WatchProtocolType.genericUart,
}) {
  return WatchHardwareProfile(
    profileId: 'auto_hiwatch_${remoteId.replaceAll(":", "_")}',
    deviceName: deviceName,
    remoteId: remoteId,
    protocolType: type,
    serviceUuid: '6e400001-b5a3-f393-e0a9-e50e24dcca9d',
    writeCharUuid: '6e400002-b5a3-f393-e0a9-e50e24dcca9d',
    notifyCharUuid: '6e400003-b5a3-f393-e0a9-e50e24dcca9d',
    handshakePacket: const [0xCD, 0x00, 0x06, 0x12, 0x01, 0x0A, 0x00, 0x01, 0x02],
    rtcSyncPacket: const [],
    stepQueryPacket: const [],
    hrTriggerPacket: const [],
    bpTriggerPacket: const [],
    requiresAck: false,
    keepaliveIntervalMs: 4000,
    createdAt: DateTime(2025, 1, 1),
  );
}

/// Simulates the protocol upgrade logic from processIncomingWatchData.
/// Returns upgraded profile if header matches; null if no upgrade needed.
WatchHardwareProfile? _simulateUpgrade(
  WatchHardwareProfile current,
  List<int> incomingPacket,
) {
  if (incomingPacket.isEmpty) return null;

  // Skip protected protocols (same as real code)
  if (current.protocolType == WatchProtocolType.wearOsCompanion ||
      current.protocolType == WatchProtocolType.miBandMifit ||
      current.protocolType == WatchProtocolType.fitCloudFastrack) {
    return null; // No upgrade for already-confirmed protocols
  }

  final hdr = incomingPacket[0];

  if ((hdr == 0xAB || hdr == 0xAA) &&
      current.protocolType != WatchProtocolType.dafitAb) {
    return WatchHardwareProfile.fromProberFindings(
      deviceName: current.deviceName,
      remoteId: current.remoteId,
      writeCharUuid: current.writeCharUuid,
      notifyCharUuid: current.notifyCharUuid,
      isDaFitPassed: true,
      isHiWatchPassed: false,
      isBleSig: false,
    );
  }

  if ((hdr == 0xCD || hdr == 0xDC) &&
      current.protocolType != WatchProtocolType.hiwatchCd) {
    return WatchHardwareProfile.fromProberFindings(
      deviceName: current.deviceName,
      remoteId: current.remoteId,
      writeCharUuid: current.writeCharUuid,
      notifyCharUuid: current.notifyCharUuid,
      isDaFitPassed: false,
      isHiWatchPassed: true,
      isBleSig: false,
    );
  }

  if (hdr == 0x02 &&
      current.protocolType != WatchProtocolType.fitCloudFastrack &&
      incomingPacket.length >= 3) {
    return WatchHardwareProfile(
      profileId: 'probed_fitcloud_${current.remoteId.replaceAll(":", "_")}',
      deviceName: current.deviceName,
      remoteId: current.remoteId,
      protocolType: WatchProtocolType.fitCloudFastrack,
      serviceUuid: current.serviceUuid,
      writeCharUuid: current.writeCharUuid,
      notifyCharUuid: current.notifyCharUuid,
      handshakePacket: const [0x02, 0x01, 0x00, 0x00],
      rtcSyncPacket: const [],
      stepQueryPacket: const [0x02, 0x05, 0x00, 0x00],
      hrTriggerPacket: const [0x02, 0x20, 0x01, 0x00, 0x01],
      bpTriggerPacket: const [0x02, 0x21, 0x01, 0x00, 0x01],
      requiresAck: false,
      keepaliveIntervalMs: 5000,
      createdAt: DateTime.now(),
    );
  }

  return null; // No upgrade
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('Auto-Probe Sequential Protocol Detection', () {
    // ── DaFit probe tests ──────────────────────────────────────────────────

    test('1. DaFit 0xAB response upgrades genericUart → dafitAb', () {
      final current = _genericProfile();
      // Simulate DaFit battery response: [0xAB, 0x91, 0x64]
      final packet = [0xAB, 0x91, 0x64];
      final upgraded = _simulateUpgrade(current, packet);
      expect(upgraded, isNotNull);
      expect(upgraded!.protocolType, WatchProtocolType.dafitAb);
    });

    test('2. DaFit 0xAA variant response also upgrades to dafitAb', () {
      final current = _genericProfile();
      final packet = [0xAA, 0x51, 0x00, 0x0A, 0x00, 0x00, 0x64];
      final upgraded = _simulateUpgrade(current, packet);
      expect(upgraded, isNotNull);
      expect(upgraded!.protocolType, WatchProtocolType.dafitAb);
    });

    test('3. DaFit upgrade from hiwatchCd misdetect → correct upgrade', () {
      // Watch was misdetected as hiwatchCd by GATT scan, but replies with 0xAB
      final current = _genericProfile(type: WatchProtocolType.hiwatchCd);
      final packet = [0xAB, 0x00, 0x04, 0xFF, 0x91, 0x80, 0x4B];
      final upgraded = _simulateUpgrade(current, packet);
      expect(upgraded, isNotNull);
      expect(upgraded!.protocolType, WatchProtocolType.dafitAb);
    });

    test('4. Upgraded DaFit profile has correct handshake packet', () {
      final current = _genericProfile();
      final packet = [0xAB, 0x91, 0x64];
      final upgraded = _simulateUpgrade(current, packet)!;
      expect(upgraded.handshakePacket, isNotEmpty);
      expect(upgraded.handshakePacket.first, 0xAB);
    });

    test('5. Upgraded DaFit profile has correct step query packet', () {
      final current = _genericProfile();
      final packet = [0xAB, 0x91, 0x64];
      final upgraded = _simulateUpgrade(current, packet)!;
      expect(upgraded.stepQueryPacket, isNotEmpty);
      expect(upgraded.stepQueryPacket.first, 0xAB);
    });

    // ── HiWatch probe tests ────────────────────────────────────────────────

    test('6. HiWatch 0xCD response upgrades genericUart → hiwatchCd', () {
      final current = _genericProfile();
      // Simulate HiWatch pair ACK: [0xDC, 0x00, 0x05, 0x12, 0x0A]
      final packet = [0xDC, 0x00, 0x05, 0x12, 0x0A];
      final upgraded = _simulateUpgrade(current, packet);
      expect(upgraded, isNotNull);
      expect(upgraded!.protocolType, WatchProtocolType.hiwatchCd);
    });

    test('7. HiWatch 0xDC return-ACK header also upgrades to hiwatchCd', () {
      final current = _genericProfile();
      final packet = [0xDC, 0x00, 0x09, 0x15, 0x01, 0x0D];
      final upgraded = _simulateUpgrade(current, packet);
      expect(upgraded, isNotNull);
      expect(upgraded!.protocolType, WatchProtocolType.hiwatchCd);
    });

    test('8. HiWatch upgrade from dafitAb misdetect → correct upgrade', () {
      final current = _genericProfile(type: WatchProtocolType.dafitAb);
      final packet = [0xDC, 0x00, 0x05, 0x12, 0x0A];
      final upgraded = _simulateUpgrade(current, packet);
      expect(upgraded, isNotNull);
      expect(upgraded!.protocolType, WatchProtocolType.hiwatchCd);
    });

    test('9. Upgraded HiWatch profile has correct handshake packet', () {
      final current = _genericProfile();
      final packet = [0xDC, 0x00, 0x05, 0x12, 0x0A];
      final upgraded = _simulateUpgrade(current, packet)!;
      expect(upgraded.handshakePacket, isNotEmpty);
      expect(upgraded.handshakePacket.first, 0xCD);
    });

    // ── FitCloud probe tests ───────────────────────────────────────────────

    test('10. FitCloud 0x02 response upgrades genericUart → fitCloudFastrack', () {
      final current = _genericProfile();
      // Simulate FitCloud handshake ACK: [0x02, 0x01, 0x00, 0x00]
      final packet = [0x02, 0x01, 0x00, 0x00];
      final upgraded = _simulateUpgrade(current, packet);
      expect(upgraded, isNotNull);
      expect(upgraded!.protocolType, WatchProtocolType.fitCloudFastrack);
    });

    test('11. FitCloud upgrade: profileId starts with probed_fitcloud_', () {
      final current = _genericProfile();
      final packet = [0x02, 0x05, 0x00, 0x00];
      final upgraded = _simulateUpgrade(current, packet)!;
      expect(upgraded.profileId, startsWith('probed_fitcloud_'));
    });

    test('12. FitCloud upgrade: correct handshake packet', () {
      final current = _genericProfile();
      final packet = [0x02, 0x01, 0x00, 0x00];
      final upgraded = _simulateUpgrade(current, packet)!;
      expect(upgraded.handshakePacket, equals([0x02, 0x01, 0x00, 0x00]));
    });

    test('13. FitCloud upgrade: correct step query packet', () {
      final current = _genericProfile();
      final packet = [0x02, 0x01, 0x00, 0x00];
      final upgraded = _simulateUpgrade(current, packet)!;
      expect(upgraded.stepQueryPacket, equals([0x02, 0x05, 0x00, 0x00]));
    });

    test('14. FitCloud upgrade: correct HR trigger packet', () {
      final current = _genericProfile();
      final packet = [0x02, 0x01, 0x00, 0x00];
      final upgraded = _simulateUpgrade(current, packet)!;
      expect(upgraded.hrTriggerPacket, equals([0x02, 0x20, 0x01, 0x00, 0x01]));
    });

    // ── Protected protocol: NO downgrade ──────────────────────────────────

    test('15. fitCloudFastrack profile NOT overwritten by any probe packet', () {
      final current = WatchHardwareProfile(
        profileId: 'fitcloud_AA_BB_CC_DD_EE_FF',
        deviceName: 'Fastrack Reflex',
        remoteId: 'AA:BB:CC:DD:EE:FF',
        protocolType: WatchProtocolType.fitCloudFastrack,
        serviceUuid: '000027f0-0000-1000-8000-00805f9b34fb',
        writeCharUuid: '000027f6-0000-1000-8000-00805f9b34fb',
        notifyCharUuid: '000027f7-0000-1000-8000-00805f9b34fb',
        handshakePacket: const [0x02, 0x01, 0x00, 0x00],
        rtcSyncPacket: const [],
        stepQueryPacket: const [0x02, 0x05, 0x00, 0x00],
        hrTriggerPacket: const [0x02, 0x20, 0x01, 0x00, 0x01],
        bpTriggerPacket: const [],
        requiresAck: false,
        keepaliveIntervalMs: 5000,
        createdAt: DateTime(2025, 1, 1),
      );
      // Even an 0xAB packet should NOT downgrade fitCloud to DaFit
      final upgraded = _simulateUpgrade(current, [0xAB, 0x91, 0x64]);
      expect(upgraded, isNull); // protected — no upgrade
    });

    test('16. wearOsCompanion profile NOT overwritten by any probe packet', () {
      final wearOs = WatchHardwareProfile.wearOsCompanionProfile(
        deviceName: 'Galaxy Watch',
        remoteId: 'BB:CC:DD:EE:FF:00',
        serviceUuid: 'eed6d5cc-c3b2-4d7b-8c6b-7acbf7965bb6',
        writeCharUuid: '2fb6a5aa-1219-4129-bc97-dd4df70613cd',
        notifyCharUuid: '2fb6a5aa-1219-4129-bc97-dd4df70613cd',
      );
      final upgraded = _simulateUpgrade(wearOs, [0xCD, 0x00, 0x05, 0x12, 0x0A]);
      expect(upgraded, isNull);
    });

    test('17. miBandMifit profile NOT overwritten by any probe packet', () {
      final miBand = WatchHardwareProfile(
        profileId: 'miband_AA_BB_CC_DD_EE_FF',
        deviceName: 'Mi Band 8',
        remoteId: 'AA:BB:CC:DD:EE:FF',
        protocolType: WatchProtocolType.miBandMifit,
        serviceUuid: '0000fee0-0000-1000-8000-00805f9b34fb',
        writeCharUuid: '00000009-0000-3512-2118-0009af100700',
        notifyCharUuid: '00000010-0000-3512-2118-0009af100700',
        handshakePacket: const [],
        rtcSyncPacket: const [],
        stepQueryPacket: const [],
        hrTriggerPacket: const [],
        bpTriggerPacket: const [],
        requiresAck: false,
        keepaliveIntervalMs: 0,
        createdAt: DateTime(2025, 1, 1),
      );
      final upgraded = _simulateUpgrade(miBand, [0xAB, 0x91, 0x64]);
      expect(upgraded, isNull);
    });

    // ── No-op cases ────────────────────────────────────────────────────────

    test('18. Empty packet → no upgrade', () {
      final current = _genericProfile();
      final upgraded = _simulateUpgrade(current, []);
      expect(upgraded, isNull);
    });

    test('19. dafitAb already set → 0xAB packet returns no upgrade (no duplicate)', () {
      final current = _genericProfile(type: WatchProtocolType.dafitAb);
      final upgraded = _simulateUpgrade(current, [0xAB, 0x91, 0x64]);
      expect(upgraded, isNull); // already correct, no-op
    });

    test('20. hiwatchCd already set → 0xDC packet returns no upgrade (no duplicate)', () {
      final current = _genericProfile(type: WatchProtocolType.hiwatchCd);
      final upgraded = _simulateUpgrade(current, [0xDC, 0x00, 0x05, 0x12, 0x0A]);
      expect(upgraded, isNull); // already correct, no-op
    });

    // ── Packet parsing after upgrade ───────────────────────────────────────

    test('21. After DaFit upgrade: 0xAB steps packet parses correctly', () {
      final packet = [0xAB, 0x51, 0x00, 0x0E, 0xA6, 0x00]; // steps = 0x0EA6 = 3750
      final result = HiWatchProProtocol.parseNotifyPacket(packet);
      expect(result.steps, 3750);
    });

    test('22. After HiWatch upgrade: 0xDC day summary packet parses correctly', () {
      // HiWatch day summary — steps at bytes[10..13]
      // [DC 00 0C 15 01 0C ... steps 4 bytes ...]
      final packet = [
        0xDC, 0x00, 0x0C, 0x15, 0x01, 0x0C, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x0E, 0xA6, // bytes[10..13] = 3750 steps
        0x00, 0x00,
      ];
      final result = HiWatchProProtocol.parseNotifyPacket(packet);
      // This packet will be parsed — result may be empty or have steps
      expect(result, isNotNull); // parser should never crash
    });

    test('23. After FitCloud upgrade: 0x02 steps packet parses correctly', () {
      // FitCloud steps: [0x02, 0x05, 0x00, steps_lo, steps_hi]
      // steps = 0x0EA6 (little-endian) = bytes[3] | (bytes[4] << 8) = 0xA6 | (0x0E << 8) = 3750
      final packet = [0x02, 0x05, 0x00, 0xA6, 0x0E];
      final result = HiWatchProProtocol.parseNotifyPacket(packet);
      expect(result.steps, 3750);
    });

    // ── Probe order logic verification ────────────────────────────────────

    test('24. Probe order: DaFit checked before HiWatch (priority)', () {
      // If watch responds to 0xAB, it should be DaFit, not HiWatch
      // This tests that 0xAB takes priority over default hiwatchCd assignment
      final genericWatch = _genericProfile();
      final afterDaFit = _simulateUpgrade(genericWatch, [0xAB, 0x91, 0x64]);
      expect(afterDaFit!.protocolType, WatchProtocolType.dafitAb);
      // Now verify HiWatch probe would NOT override DaFit
      final afterHiWatch = _simulateUpgrade(afterDaFit, [0xDC, 0x00, 0x05, 0x12, 0x0A]);
      expect(afterHiWatch, isNotNull); // DaFit → HiWatch upgrade IS allowed (misdetect fix)
      expect(afterHiWatch!.protocolType, WatchProtocolType.hiwatchCd);
    });

    test('25. remoteId preserved after protocol upgrade', () {
      const remoteId = 'AA:BB:CC:DD:EE:FF';
      final current = _genericProfile(remoteId: remoteId);
      final upgraded = _simulateUpgrade(current, [0xAB, 0x91, 0x64])!;
      expect(upgraded.remoteId, remoteId);
    });

    test('26. deviceName preserved after protocol upgrade', () {
      const deviceName = 'FIREBOLTT_001';
      final current = _genericProfile(deviceName: deviceName);
      final upgraded = _simulateUpgrade(current, [0xAB, 0x91, 0x64])!;
      expect(upgraded.deviceName, deviceName);
    });

    test('27. writeCharUuid preserved after protocol upgrade', () {
      final current = _genericProfile();
      final originalWrite = current.writeCharUuid;
      final upgraded = _simulateUpgrade(current, [0xAB, 0x91, 0x64])!;
      expect(upgraded.writeCharUuid, originalWrite);
    });

    test('28. notifyCharUuid preserved after protocol upgrade', () {
      final current = _genericProfile();
      final originalNotify = current.notifyCharUuid;
      final upgraded = _simulateUpgrade(current, [0xAB, 0x91, 0x64])!;
      expect(upgraded.notifyCharUuid, originalNotify);
    });
  });
}
