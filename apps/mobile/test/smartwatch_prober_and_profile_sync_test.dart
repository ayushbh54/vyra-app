import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vyra/services/hiwatch_pro_service.dart';
import 'package:vyra/services/watch_hardware_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('⚡ Universal Smartwatch Prober & 1-Tap Sync System Verification', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1️⃣ Default Ultra 2 / HiWatch Pro Profile Presets', () {
      final profile = WatchHardwareProfile.defaultUltra2Profile(remoteId: '71:7E:FB:00:03:CB');

      expect(profile.profileId, equals('ultra2_hiwatch_default'));
      expect(profile.deviceName, equals('Ultra2'));
      expect(profile.remoteId, equals('71:7E:FB:00:03:CB'));
      expect(profile.protocolType, equals(WatchProtocolType.hiwatchCd));
      expect(profile.serviceUuid, equals(HiWatchProProtocol.uartServiceUuid2));
      expect(profile.writeCharUuid, equals(HiWatchProProtocol.uartWriteCharacteristicUuid));
      expect(profile.notifyCharUuid, equals(HiWatchProProtocol.uartNotifyCharacteristicUuid));
      expect(profile.requiresAck, isTrue);
      expect(profile.keepaliveIntervalMs, equals(3500));
      expect(profile.handshakePacket, equals([0xCD, 0x00, 0x06, 0x12, 0x01, 0x0A, 0x00, 0x01, 0x02]));
    });

    test('2️⃣ DaFit / MoYoung Profile Preset Construction', () {
      final daFit = WatchHardwareProfile.daFitProfile(
        deviceName: 'Noise ColorFit Pro',
        remoteId: 'AA:BB:CC:DD:EE:FF',
      );

      expect(daFit.deviceName, equals('Noise ColorFit Pro'));
      expect(daFit.protocolType, equals(WatchProtocolType.dafitAb));
      expect(daFit.serviceUuid, contains('fee7'));
      expect(daFit.writeCharUuid, contains('fee1'));
      expect(daFit.notifyCharUuid, contains('fee2'));
      expect(daFit.handshakePacket.first, equals(0xAB));
      expect(daFit.stepQueryPacket.first, equals(0xAB));
      expect(daFit.requiresAck, isFalse);
    });

    test('3️⃣ Standard Bluetooth SIG Heart Rate Profile Preset', () {
      final sig = WatchHardwareProfile.bleSigProfile(
        deviceName: 'Polar H10',
        remoteId: '11:22:33:44:55:66',
      );

      expect(sig.protocolType, equals(WatchProtocolType.bleSig));
      expect(sig.serviceUuid, contains('180d'));
      expect(sig.notifyCharUuid, contains('2a37'));
    });

    test('4️⃣ Prober Findings to Active Profile Auto-Conversion', () {
      // Scenario A: Prober identifies DaFit 0xAB winning response
      final dafitProbed = WatchHardwareProfile.fromProberFindings(
        deviceName: 'Fire-Boltt Phoenix',
        remoteId: 'FB:01:02:03:04:05',
        writeCharUuid: '0000fee1-0000-1000-8000-00805f9b34fb',
        notifyCharUuid: '0000fee2-0000-1000-8000-00805f9b34fb',
        isDaFitPassed: true,
        isHiWatchPassed: false,
        isBleSig: false,
      );
      expect(dafitProbed.protocolType, equals(WatchProtocolType.dafitAb));
      expect(dafitProbed.handshakePacket.first, equals(0xAB));

      // Scenario B: Prober identifies HiWatch 0xCD winning response
      final hiwatchProbed = WatchHardwareProfile.fromProberFindings(
        deviceName: 'T800 Ultra',
        remoteId: 'T8:00:11:22:33:44',
        writeCharUuid: '6e400002-b5a3-f393-e0a9-e50e24dcca9d',
        notifyCharUuid: '6e400003-b5a3-f393-e0a9-e50e24dcca9d',
        isDaFitPassed: false,
        isHiWatchPassed: true,
        isBleSig: false,
      );
      expect(hiwatchProbed.protocolType, equals(WatchProtocolType.hiwatchCd));
      expect(hiwatchProbed.handshakePacket.first, equals(0xCD));
      expect(hiwatchProbed.requiresAck, isTrue);

      // Scenario C: Prober identifies Standard BLE SIG Heart Rate
      final sigProbed = WatchHardwareProfile.fromProberFindings(
        deviceName: 'Garmin HRM',
        remoteId: 'GA:00:11:22:33:44',
        writeCharUuid: '00002a39-0000-1000-8000-00805f9b34fb',
        notifyCharUuid: '00002a37-0000-1000-8000-00805f9b34fb',
        isDaFitPassed: false,
        isHiWatchPassed: false,
        isBleSig: true,
      );
      expect(sigProbed.protocolType, equals(WatchProtocolType.bleSig));
    });

    test('5️⃣ SharedPreferences Persistence & 1-Tap Load Roundtrip', () async {
      final initialProfile = WatchHardwareProfile.daFitProfile(
        deviceName: 'boAt Wave Call',
        remoteId: 'BT:AA:BB:CC:DD:EE',
      );

      // Save profile
      await initialProfile.saveToPrefs();

      // Read back profile
      final loaded = await WatchHardwareProfile.loadFromPrefs();
      expect(loaded, isNotNull);
      expect(loaded!.deviceName, equals('boAt Wave Call'));
      expect(loaded.remoteId, equals('BT:AA:BB:CC:DD:EE'));
      expect(loaded.protocolType, equals(WatchProtocolType.dafitAb));
      expect(loaded.serviceUuid, contains('fee7'));
      expect(loaded.writeCharUuid, contains('fee1'));
      expect(loaded.notifyCharUuid, contains('fee2'));
      expect(loaded.handshakePacket, equals(initialProfile.handshakePacket));
      expect(loaded.keepaliveIntervalMs, equals(5000));

      // Check legacy keys updated
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ble_watch_name'), equals('boAt Wave Call'));
      expect(prefs.getString('ble_watch_remote_id'), equals('BT:AA:BB:CC:DD:EE'));

      // Clear profile
      await WatchHardwareProfile.clearFromPrefs();
      final cleared = await WatchHardwareProfile.loadFromPrefs();
      expect(cleared, isNull);
    });

    test('6️⃣ Telemetry Parsing Across All Protocol Families', () {
      // Family A: HiWatch / Jerry JL7012 Multi-Vitals
      final jerryVitals = <int>[
        0xCD, 0x00, 0x11, 0x15, 0x01, 0x0E, 0x00, 0x0C,
        0x5C, 0xC5, 0x00, 0x01, 0x00, 0x00, 0xE1, 0x78,
        0x62, // SpO2 = 98%
        0x50, // Diastolic = 80 mmHg
        0x78, // Systolic = 120 mmHg
        0x48, // Pulse = 72 BPM
      ];
      final jData = HiWatchProProtocol.parseNotifyPacket(jerryVitals);
      expect(jData.heartRateBpm, equals(72));
      expect(jData.bloodPressureSystolic, equals(120));
      expect(jData.bloodPressureDiastolic, equals(80));
      expect(jData.bloodOxygenSpo2, equals(98));
      expect(jData.ackPacket, isNotNull);

      // Family B: Standard Bluetooth SIG Heart Rate (0x2A37)
      // Flags = 0x00 (8-bit HR), Heart Rate = 78 BPM
      final sigHrPacket = <int>[0x00, 78];
      final sData = HiWatchProProtocol.parseNotifyPacket(sigHrPacket);
      expect(sData.heartRateBpm, equals(78));

      // Family C1: DaFit / Shenzhen 0xAB Steps Stream (Cmd 0x51)
      // [0xAB, 0x00, 0x06, 0xFF, 0x51, 0x00, 0x10, 0x27] => Steps = 4135
      final dafitStepsPacket = <int>[
        0xAB, 0x00, 0x06, 0xFF, 0x51, 0x00, 0x10, 0x27
      ];
      final dStepsData = HiWatchProProtocol.parseNotifyPacket(dafitStepsPacket);
      expect(dStepsData.steps, equals(4135));

      // Family C2: DaFit / Shenzhen 0xAB Live Vitals (Cmd 0x09)
      // [0xAB, 0x00, 0x05, 0xFF, 0x09, 76, 98] => HR = 76, SpO2 = 98
      final dafitHrPacket = <int>[
        0xAB, 0x00, 0x05, 0xFF, 0x09, 76, 98
      ];
      final dHrData = HiWatchProProtocol.parseNotifyPacket(dafitHrPacket);
      expect(dHrData.heartRateBpm, equals(76));
      expect(dHrData.bloodOxygenSpo2, equals(98));
    });

    test('7️⃣ MoYoung / DaFit Sub-Typed 0x51 Steps, 0x31 Vitals, 0x32 All-in-One & 0x91 Battery', () {
      // MoYoung 0x51 0x08 daily step summary: subType=0x08, steps=0x0009C4 (2500), cal=0x00006E (110 kcal)
      final moyoungSteps = <int>[
        0xAB, 0x00, 0x0E, 0xFF, 0x51, 0x08,
        0x00, 0x09, 0xC4, // 2500 steps
        0x00, 0x00, 0x6E, // 110 kcal
        0x00, 0x07, 0x08, // 1800m = 1.8km
      ];
      final mStepsData = HiWatchProProtocol.parseNotifyPacket(moyoungSteps);
      expect(mStepsData.steps, equals(2500));
      expect(mStepsData.calories, equals(110));
      expect(mStepsData.distanceMeters, equals(1800));

      // MoYoung 0x31 sub-typed real-time HR (subType 0x0A, HR = 84 BPM)
      final moyoungHr = <int>[0xAB, 0x00, 0x05, 0xFF, 0x31, 0x0A, 84];
      final mHrData = HiWatchProProtocol.parseNotifyPacket(moyoungHr);
      expect(mHrData.heartRateBpm, equals(84));

      // MoYoung 0x31 sub-typed SpO2 (subType 0x12, SpO2 = 97%)
      final moyoungSpo2 = <int>[0xAB, 0x00, 0x05, 0xFF, 0x31, 0x12, 97];
      final mSpo2Data = HiWatchProProtocol.parseNotifyPacket(moyoungSpo2);
      expect(mSpo2Data.bloodOxygenSpo2, equals(97));

      // MoYoung 0x31 sub-typed Blood Pressure (subType 0x22, Sys = 122, Dia = 81)
      final moyoungBp = <int>[0xAB, 0x00, 0x06, 0xFF, 0x31, 0x22, 122, 81];
      final mBpData = HiWatchProProtocol.parseNotifyPacket(moyoungBp);
      expect(mBpData.bloodPressureSystolic, equals(122));
      expect(mBpData.bloodPressureDiastolic, equals(81));

      // DaFit 0x32 One-Key Measure All (subType 0x80, HR=79, SpO2=99, Sys=118, Dia=78)
      final dafitAll = <int>[0xAB, 0x00, 0x08, 0xFF, 0x32, 0x80, 79, 99, 118, 78];
      final mAllData = HiWatchProProtocol.parseNotifyPacket(dafitAll);
      expect(mAllData.heartRateBpm, equals(79));
      expect(mAllData.bloodOxygenSpo2, equals(99));
      expect(mAllData.bloodPressureSystolic, equals(118));
      expect(mAllData.bloodPressureDiastolic, equals(78));

      // DaFit 0x91 Battery response (charging=0x00, level=88%)
      final dafitBat = <int>[0xAB, 0x00, 0x05, 0xFF, 0x91, 0x00, 88];
      final mBatData = HiWatchProProtocol.parseNotifyPacket(dafitBat);
      expect(mBatData.batteryLevel, equals(88));
    });

    test('8️⃣ FitCloudPro / Realtek (0xFE / 0xEA) & Universal Brand Recognition', () {
      final realtekVitals = <int>[0xFE, 0xEA, 0x10, 0x05, 74, 98, 120, 80];
      final rData = HiWatchProProtocol.parseNotifyPacket(realtekVitals);
      expect(rData.heartRateBpm, equals(74));
      expect(rData.bloodOxygenSpo2, equals(98));
      expect(rData.bloodPressureSystolic, equals(120));
      expect(rData.bloodPressureDiastolic, equals(80));

      for (final brand in [
        'Fire-Boltt',
        'Noise',
        'ColorFit',
        'boAt',
        'Fastrack',
        'Titan',
        'DaFit',
        'FitPro',
        'HiWatch',
        'Ultra2',
        'Galaxy Watch',
        'Samsung',
        'K5PZ',
        'Pixel Watch',
      ]) {
        expect(
          HiWatchProProtocol.recognizedDeviceNames.any(
            (n) => n.toLowerCase() == brand.toLowerCase(),
          ),
          isTrue,
          reason: 'Expected $brand in recognizedDeviceNames',
        );
      }
    });

    test('9️⃣ Samsung Galaxy Watch4 Classic (K5PZ) / Wear OS Companion GATT Profile Auto-Detection', () async {
      final profile = WatchHardwareProfile.fromProberFindings(
        deviceName: 'Galaxy Watch4 Classic (K5PZ)',
        remoteId: 'C41BDCB4-371E-5B9B-0236-3114D5A8EEFA',
        writeCharUuid: '2fb6a5aa-1219-4129-bc97-dd4df70613cd',
        notifyCharUuid: '2fb6a5aa-1219-4129-bc97-dd4df70613cd',
        isDaFitPassed: false,
        isHiWatchPassed: false,
        isBleSig: false,
        isWearOsCompanion: true,
      );

      expect(profile.profileId, startsWith('wearos_companion_'));
      expect(profile.protocolType, equals(WatchProtocolType.wearOsCompanion));
      expect(profile.writeCharUuid, equals('2fb6a5aa-1219-4129-bc97-dd4df70613cd'));
      expect(profile.notifyCharUuid, equals('2fb6a5aa-1219-4129-bc97-dd4df70613cd'));

      await profile.saveToPrefs();
      final loaded = await WatchHardwareProfile.loadFromPrefs();
      expect(loaded, isNotNull);
      expect(loaded!.protocolType, equals(WatchProtocolType.wearOsCompanion));
      expect(loaded.deviceName, equals('Galaxy Watch4 Classic (K5PZ)'));
    });
  });
}
