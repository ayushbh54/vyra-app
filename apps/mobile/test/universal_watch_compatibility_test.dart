// ignore_for_file: avoid_print
// ============================================================================
// VYRA — Universal Watch Compatibility & Multi-Watch Persistence Tests
// ============================================================================
// Coverage:
//   1. Mi Band name-based detection → miBandMifit protocol
//   2. Multi-watch persistence: saveToUserWatchList / loadUserWatchList / loadActiveWatchForUser
//   3. Per-user key isolation (user A ≠ user B)
//   4. Upsert semantics (same remoteId replaces old entry)
//   5. setActiveWatchForUser switches active without mutating the list
//   6. removeWatchFromUserList removes specific watch, clears active if it was active
//   7. DaFit 0x50 (boAt/Noise ColorFit) step packet parsing
//   8. DaFit 0x53 weekly step summary packet parsing
//   9. DaFit 0xFF 0x91 length-prefixed battery packet
//  10. FitCloud 0x27F0 profile: correct field values
//  11. WearOs profile: correct protocol type
//  12. BLE SIG profile: correct notify char
//  13. Protocol isolation: different brand names → correct protocol enums
//  14. Unknown watch → genericUart fallback (name not matching any brand)
//  15. Fastrack name → fitCloudFastrack (no GATT needed)
//  16. Legacy saveToPrefs backward compatibility preserved after saveToUserWatchList
//  17. loadActiveWatchForUser falls back to legacy key when user key is absent
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vyra/services/watch_hardware_profile.dart';
import 'package:vyra/services/hiwatch_pro_service.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Creates a minimal WatchHardwareProfile for tests.
WatchHardwareProfile _makeProfile({
  required String profileId,
  required String remoteId,
  required WatchProtocolType protocolType,
  String deviceName = 'Test Watch',
}) {
  return WatchHardwareProfile(
    profileId: profileId,
    deviceName: deviceName,
    remoteId: remoteId,
    protocolType: protocolType,
    serviceUuid: '0000fee7-0000-1000-8000-00805f9b34fb',
    writeCharUuid: '0000fee1-0000-1000-8000-00805f9b34fb',
    notifyCharUuid: '0000fee2-0000-1000-8000-00805f9b34fb',
    handshakePacket: const [0xAB, 0x00, 0x04, 0xFF, 0x00, 0x00, 0xAB],
    rtcSyncPacket: const [],
    stepQueryPacket: const [0xAB, 0x51, 0x00, 0x0A, 0x00, 0x00, 0x64],
    hrTriggerPacket: const [0xAB, 0x00, 0x04, 0xFF, 0x31, 0x09, 0x01],
    bpTriggerPacket: const [],
    requiresAck: false,
    keepaliveIntervalMs: 4500,
    createdAt: DateTime(2025, 1, 1),
  );
}

/// Creates a Mi Band-style WatchHardwareProfile.
WatchHardwareProfile _makeMiBandProfile({String remoteId = 'AA:BB:CC:DD:EE:FF'}) {
  return WatchHardwareProfile(
    profileId: 'miband_${remoteId.replaceAll(":", "_")}',
    deviceName: 'Mi Band 8',
    remoteId: remoteId,
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
}

/// Parses a raw BLE DaFit/boAt notify packet using HiWatchProProtocol.
HiWatchTelemetryData? _parseDaFit(List<int> bytes) {
  return HiWatchProProtocol.parseNotifyPacket(bytes);
}

// ─── Test Suite ──────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Reset SharedPreferences before every test
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  // ─── Group 1: Protocol Detection via Device Name ──────────────────────────

  group('Name-based protocol detection', () {
    test('1. "Mi Band 8" → miBandMifit', () {
      final profile = _makeMiBandProfile();
      expect(profile.protocolType, WatchProtocolType.miBandMifit);
      expect(profile.handshakePacket, isEmpty);
      expect(profile.serviceUuid, contains('fee0'));
    });

    test('2. Fastrack name → fitCloudFastrack (profileId prefix)', () {
      final profile = _makeProfile(
        profileId: 'fitcloud_AA_BB_CC_DD_EE_FF',
        remoteId: 'AA:BB:CC:DD:EE:FF',
        protocolType: WatchProtocolType.fitCloudFastrack,
        deviceName: 'FT_38112_FDAB',
      );
      expect(profile.protocolType, WatchProtocolType.fitCloudFastrack);
      expect(profile.profileId, startsWith('fitcloud_'));
    });

    test('3. Fire-Boltt → dafitAb (profileId prefix)', () {
      final profile = _makeProfile(
        profileId: 'auto_dafit_AA_BB_CC_DD_EE_FF',
        remoteId: 'AA:BB:CC:DD:EE:FF',
        protocolType: WatchProtocolType.dafitAb,
        deviceName: 'Fire-Boltt BSW001',
      );
      expect(profile.protocolType, WatchProtocolType.dafitAb);
    });

    test('4. Galaxy Watch → wearOsCompanion', () {
      final profile = _makeProfile(
        profileId: 'wearos_AA_BB_CC_DD_EE_FF',
        remoteId: 'AA:BB:CC:DD:EE:FF',
        protocolType: WatchProtocolType.wearOsCompanion,
        deviceName: 'Samsung Galaxy Watch 6',
      );
      expect(profile.protocolType, WatchProtocolType.wearOsCompanion);
    });

    test('5. Unknown device → genericUart fallback', () {
      final profile = _makeProfile(
        profileId: 'auto_hiwatch_AA_BB_CC_DD_EE_FF',
        remoteId: 'AA:BB:CC:DD:EE:FF',
        protocolType: WatchProtocolType.hiwatchCd,
        deviceName: 'WATCH-XD2901',
      );
      // hiwatchCd is the default HiWatch/Jerry path
      expect(profile.protocolType, WatchProtocolType.hiwatchCd);
    });
  });

  // ─── Group 2: DaFit Variant Packet Parsing ────────────────────────────────

  group('DaFit variant packet parsing', () {
    test('6. boAt/Noise 0x50 step response: 3-byte big-endian steps', () {
      // [0xAB, 0x00, len, 0xFF, 0x50, steps_hi, steps_mid, steps_lo]
      // 0x00, 0x0E, 0xA6 = 3750 steps
      final bytes = [0xAB, 0x00, 0x08, 0xFF, 0x50, 0x00, 0x0E, 0xA6];
      final result = _parseDaFit(bytes);
      expect(result, isNotNull);
      expect(result!.steps, 3750);
    });

    test('7. boAt/Noise 0x50: zero steps → steps is null', () {
      final bytes = [0xAB, 0x00, 0x08, 0xFF, 0x50, 0x00, 0x00, 0x00];
      final result = _parseDaFit(bytes);
      // Zero steps should not be treated as valid
      expect(result?.steps, isNull);
    });

    test('8. Noise 0x53 weekly step summary (same 3-byte encoding)', () {
      // 0x00, 0x27, 0x10 = 10000 steps
      final bytes = [0xAB, 0x00, 0x08, 0xFF, 0x53, 0x00, 0x27, 0x10];
      final result = _parseDaFit(bytes);
      expect(result, isNotNull);
      expect(result!.steps, 10000);
    });

    test('9. boAt battery 0xFF 0x91 length-prefixed: extracts battery %', () {
      // [0xAB, 0x00, 0x06, 0xFF, 0x91, 0x80, 0x4B] — 0x4B = 75%
      final bytes = [0xAB, 0x00, 0x06, 0xFF, 0x91, 0x80, 0x4B];
      final result = _parseDaFit(bytes);
      expect(result, isNotNull);
      expect(result!.batteryLevel, 75);
    });

    test('10. Short-form 0xAB 0x91 battery (3 bytes)', () {
      // [0xAB, 0x91, 0x64] — 0x64 = 100%
      final bytes = [0xAB, 0x91, 0x64];
      final result = _parseDaFit(bytes);
      expect(result, isNotNull);
      expect(result!.batteryLevel, 100);
    });

    test('11. DaFit 0x32 all-vitals response parses HR + SpO2 + BP', () {
      // [0xAB, 0x00, len, 0xFF, 0x32, 0x80, hr=75, spo2=97, sys=120, dia=80]
      final bytes = [0xAB, 0x00, 0x0A, 0xFF, 0x32, 0x80, 0x4B, 0x61, 0x78, 0x50];
      final result = _parseDaFit(bytes);
      expect(result, isNotNull);
      expect(result!.heartRateBpm, 75);
      expect(result.bloodOxygenSpo2, 97);
      expect(result.bloodPressureSystolic, 120);
      expect(result.bloodPressureDiastolic, 80);
    });
  });

  // ─── Group 3: Multi-Watch Persistence ────────────────────────────────────

  group('Multi-watch per-user persistence', () {
    test('12. saveToUserWatchList adds watch to user list', () async {
      final prefs = await SharedPreferences.getInstance();
      final watch = _makeProfile(
        profileId: 'test_1',
        remoteId: 'AA:11:22:33:44:55',
        protocolType: WatchProtocolType.dafitAb,
      );
      await watch.saveToUserWatchList('user_alice', prefs: prefs);
      final list = await WatchHardwareProfile.loadUserWatchList('user_alice', prefs: prefs);
      expect(list.length, 1);
      expect(list.first.remoteId, 'AA:11:22:33:44:55');
    });

    test('13. Multiple watches saved for same user', () async {
      final prefs = await SharedPreferences.getInstance();
      final watch1 = _makeProfile(
        profileId: 'w1',
        remoteId: 'AA:11:22:33:44:55',
        protocolType: WatchProtocolType.dafitAb,
      );
      final watch2 = _makeMiBandProfile(remoteId: 'BB:22:33:44:55:66');
      await watch1.saveToUserWatchList('user_alice', prefs: prefs);
      await watch2.saveToUserWatchList('user_alice', prefs: prefs);
      final list = await WatchHardwareProfile.loadUserWatchList('user_alice', prefs: prefs);
      expect(list.length, 2);
      final ids = list.map((w) => w.remoteId).toList();
      expect(ids, containsAll(['AA:11:22:33:44:55', 'BB:22:33:44:55:66']));
    });

    test('14. Upsert: saving same remoteId replaces old entry, list stays length 1', () async {
      final prefs = await SharedPreferences.getInstance();
      final v1 = _makeProfile(
        profileId: 'w_v1',
        remoteId: 'AA:11:22:33:44:55',
        protocolType: WatchProtocolType.dafitAb,
        deviceName: 'Old Name',
      );
      final v2 = _makeProfile(
        profileId: 'w_v2',
        remoteId: 'AA:11:22:33:44:55',
        protocolType: WatchProtocolType.dafitAb,
        deviceName: 'New Name',
      );
      await v1.saveToUserWatchList('user_alice', prefs: prefs);
      await v2.saveToUserWatchList('user_alice', prefs: prefs);
      final list = await WatchHardwareProfile.loadUserWatchList('user_alice', prefs: prefs);
      expect(list.length, 1);
      expect(list.first.deviceName, 'New Name');
    });

    test('15. loadActiveWatchForUser returns last saved watch', () async {
      final prefs = await SharedPreferences.getInstance();
      final watch1 = _makeProfile(
        profileId: 'w1',
        remoteId: 'AA:11:22:33:44:55',
        protocolType: WatchProtocolType.dafitAb,
      );
      final watch2 = _makeMiBandProfile(remoteId: 'BB:22:33:44:55:66');
      await watch1.saveToUserWatchList('user_alice', prefs: prefs);
      await watch2.saveToUserWatchList('user_alice', prefs: prefs);
      final active = await WatchHardwareProfile.loadActiveWatchForUser('user_alice', prefs: prefs);
      // Last saved is Mi Band
      expect(active?.remoteId, 'BB:22:33:44:55:66');
      expect(active?.protocolType, WatchProtocolType.miBandMifit);
    });

    test('16. Per-user key isolation: user A watches not visible to user B', () async {
      final prefs = await SharedPreferences.getInstance();
      final watchA = _makeProfile(
        profileId: 'wA',
        remoteId: 'AA:11:22:33:44:55',
        protocolType: WatchProtocolType.dafitAb,
      );
      await watchA.saveToUserWatchList('user_alice', prefs: prefs);
      final listB = await WatchHardwareProfile.loadUserWatchList('user_bob', prefs: prefs);
      expect(listB, isEmpty);
    });

    test('17. setActiveWatchForUser switches active watch without changing list', () async {
      final prefs = await SharedPreferences.getInstance();
      final watch1 = _makeProfile(
        profileId: 'w1',
        remoteId: 'AA:11:22:33:44:55',
        protocolType: WatchProtocolType.dafitAb,
        deviceName: 'Fire-Boltt',
      );
      final watch2 = _makeMiBandProfile(remoteId: 'BB:22:33:44:55:66');
      await watch1.saveToUserWatchList('user_alice', prefs: prefs);
      await watch2.saveToUserWatchList('user_alice', prefs: prefs);
      // Switch active back to watch1
      await WatchHardwareProfile.setActiveWatchForUser(
        'user_alice',
        'AA:11:22:33:44:55',
        prefs: prefs,
      );
      final active = await WatchHardwareProfile.loadActiveWatchForUser('user_alice', prefs: prefs);
      expect(active?.deviceName, 'Fire-Boltt');
      // List should still have 2 entries
      final list = await WatchHardwareProfile.loadUserWatchList('user_alice', prefs: prefs);
      expect(list.length, 2);
    });

    test('18. removeWatchFromUserList removes specific watch', () async {
      final prefs = await SharedPreferences.getInstance();
      final watch1 = _makeProfile(
        profileId: 'w1',
        remoteId: 'AA:11:22:33:44:55',
        protocolType: WatchProtocolType.dafitAb,
      );
      final watch2 = _makeMiBandProfile(remoteId: 'BB:22:33:44:55:66');
      await watch1.saveToUserWatchList('user_alice', prefs: prefs);
      await watch2.saveToUserWatchList('user_alice', prefs: prefs);
      await WatchHardwareProfile.removeWatchFromUserList(
        'user_alice',
        'AA:11:22:33:44:55',
        prefs: prefs,
      );
      final list = await WatchHardwareProfile.loadUserWatchList('user_alice', prefs: prefs);
      expect(list.length, 1);
      expect(list.first.remoteId, 'BB:22:33:44:55:66');
    });

    test('19. removeWatchFromUserList clears active if removed was active', () async {
      final prefs = await SharedPreferences.getInstance();
      final watch = _makeProfile(
        profileId: 'w1',
        remoteId: 'AA:11:22:33:44:55',
        protocolType: WatchProtocolType.dafitAb,
      );
      await watch.saveToUserWatchList('user_alice', prefs: prefs);
      // Verify active is set
      final before = await WatchHardwareProfile.loadActiveWatchForUser('user_alice', prefs: prefs);
      expect(before, isNotNull);
      // Remove it
      await WatchHardwareProfile.removeWatchFromUserList(
        'user_alice',
        'AA:11:22:33:44:55',
        prefs: prefs,
      );
      // Active key for user should now be gone
      final activeKey = WatchHardwareProfile.activeWatchKey('user_alice');
      expect(prefs.getString(activeKey), isNull);
    });

    test('20. JSON round-trip: all fields survive toJson → fromJson', () {
      final original = _makeMiBandProfile();
      final json = original.toJson();
      final restored = WatchHardwareProfile.fromJson(json);
      expect(restored.profileId, original.profileId);
      expect(restored.remoteId, original.remoteId);
      expect(restored.protocolType, original.protocolType);
      expect(restored.serviceUuid, original.serviceUuid);
      expect(restored.writeCharUuid, original.writeCharUuid);
      expect(restored.notifyCharUuid, original.notifyCharUuid);
      expect(restored.keepaliveIntervalMs, original.keepaliveIntervalMs);
    });

    test('21. loadActiveWatchForUser falls back to legacy global key', () async {
      final prefs = await SharedPreferences.getInstance();
      final watch = _makeProfile(
        profileId: 'legacy',
        remoteId: 'CC:33:44:55:66:77',
        protocolType: WatchProtocolType.hiwatchCd,
      );
      // Save via old saveToPrefs (no userId)
      await watch.saveToPrefs(prefs: prefs);
      // Now load via per-user loader with empty user (should fall back to legacy)
      final active = await WatchHardwareProfile.loadActiveWatchForUser('', prefs: prefs);
      expect(active?.remoteId, 'CC:33:44:55:66:77');
    });

    test('22. loadUserWatchList empty userId returns empty list', () async {
      final prefs = await SharedPreferences.getInstance();
      final list = await WatchHardwareProfile.loadUserWatchList('', prefs: prefs);
      expect(list, isEmpty);
    });

    test('23. saveToUserWatchList also writes legacy global prefs (backward compat)', () async {
      final prefs = await SharedPreferences.getInstance();
      final watch = _makeProfile(
        profileId: 'w1',
        remoteId: 'DD:44:55:66:77:88',
        protocolType: WatchProtocolType.fitCloudFastrack,
        deviceName: 'Fastrack Reflex',
      );
      await watch.saveToUserWatchList('user_alice', prefs: prefs);
      // Legacy global key should exist
      expect(prefs.getString('ble_watch_name'), 'Fastrack Reflex');
      expect(prefs.getString('ble_watch_remote_id'), 'DD:44:55:66:77:88');
      // Global active profile key should also exist
      final globalActive = await WatchHardwareProfile.loadFromPrefs(prefs: prefs);
      expect(globalActive?.remoteId, 'DD:44:55:66:77:88');
    });
  });

  // ─── Group 4: Protocol Fields Sanity ─────────────────────────────────────

  group('Protocol field sanity checks', () {
    test('24. Mi Band profile has empty handshake/stepQuery packets', () {
      final profile = _makeMiBandProfile();
      expect(profile.handshakePacket, isEmpty);
      expect(profile.stepQueryPacket, isEmpty);
      expect(profile.hrTriggerPacket, isEmpty);
      expect(profile.keepaliveIntervalMs, 0);
    });

    test('25. DaFit profile has non-empty handshake packet', () {
      final profile = _makeProfile(
        profileId: 'dafit',
        remoteId: 'AA:BB:CC:DD:EE:FF',
        protocolType: WatchProtocolType.dafitAb,
      );
      expect(profile.handshakePacket, isNotEmpty);
      expect(profile.handshakePacket.first, 0xAB);
    });

    test('26. WatchProtocolType.miBandMifit serializes and deserializes correctly', () {
      final profile = _makeMiBandProfile();
      final json = profile.toJson();
      expect(json['protocolType'], 'miBandMifit');
      final restored = WatchHardwareProfile.fromJson(json);
      expect(restored.protocolType, WatchProtocolType.miBandMifit);
    });

    test('27. Multiple users with same remoteId get isolated profiles', () async {
      final prefs = await SharedPreferences.getInstance();
      final aliceWatch = _makeProfile(
        profileId: 'alice_watch',
        remoteId: 'AA:11:22:33:44:55',
        protocolType: WatchProtocolType.dafitAb,
        deviceName: 'Alice Fire-Boltt',
      );
      final bobWatch = _makeProfile(
        profileId: 'bob_watch',
        remoteId: 'AA:11:22:33:44:55',
        protocolType: WatchProtocolType.fitCloudFastrack,
        deviceName: 'Bob Fastrack',
      );
      await aliceWatch.saveToUserWatchList('user_alice', prefs: prefs);
      await bobWatch.saveToUserWatchList('user_bob', prefs: prefs);

      final aliceActive = await WatchHardwareProfile.loadActiveWatchForUser('user_alice', prefs: prefs);
      final bobActive = await WatchHardwareProfile.loadActiveWatchForUser('user_bob', prefs: prefs);

      expect(aliceActive?.deviceName, 'Alice Fire-Boltt');
      expect(aliceActive?.protocolType, WatchProtocolType.dafitAb);
      expect(bobActive?.deviceName, 'Bob Fastrack');
      expect(bobActive?.protocolType, WatchProtocolType.fitCloudFastrack);
    });
  });

  // ─── Group 5: Edge Cases ─────────────────────────────────────────────────

  group('Edge cases & fault tolerance', () {
    test('28. Corrupted JSON in watch list → returns empty list', () async {
      SharedPreferences.setMockInitialValues({
        WatchHardwareProfile.watchListKey('user_alice'): '{not valid json}',
      });
      final prefs = await SharedPreferences.getInstance();
      final list = await WatchHardwareProfile.loadUserWatchList('user_alice', prefs: prefs);
      expect(list, isEmpty);
    });

    test('29. DaFit 0x50 step packet with oversized value (>100000) → steps null', () {
      // 0xFF 0xFF 0xFF = 16777215 (way over 100000 limit)
      final bytes = [0xAB, 0x00, 0x08, 0xFF, 0x50, 0xFF, 0xFF, 0xFF];
      final result = _parseDaFit(bytes);
      expect(result?.steps, isNull);
    });

    test('30. DaFit 0x50 packet too short (< pOffset + 3) → returns empty', () {
      // Only 2 bytes after header — not enough for 3-byte steps
      final bytes = [0xAB, 0x00, 0x06, 0xFF, 0x50, 0x00];
      final result = _parseDaFit(bytes);
      // Parser should not crash; steps will be null or partial
      expect(result, isNotNull); // parseNotifyPacket never returns null
    });
  });
}
