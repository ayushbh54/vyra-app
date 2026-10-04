import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_tester/protocol_prober.dart';

void main() {
  group('1. Protocol Preset Library & Combinations Audit', () {
    test('Library yields exactly 8 distinct hardware combinations', () {
      final combs = ProtocolPresetLibrary.getPresetCombinations();
      expect(combs.length, equals(8));

      final ids = combs.map((c) => c.id).toSet();
      expect(ids.length, equals(8), reason: 'Every combination must have a unique ID');
    });

    test('All 8 combinations have non-empty packets and valid hints', () {
      final combs = ProtocolPresetLibrary.getPresetCombinations();
      for (final c in combs) {
        expect(c.name, isNotEmpty);
        expect(c.chipFamily, isNotEmpty);
        expect(c.targetServiceHint, isNotEmpty);
        expect(c.targetWriteHint, isNotEmpty);
        expect(c.targetNotifyHint, isNotEmpty);
        expect(c.handshakePacket, isNotEmpty, reason: '${c.name} handshake must not be empty');
        expect(c.hrTriggerPacket, isNotEmpty, reason: '${c.name} HR trigger must not be empty');
        expect(c.stepQueryPacket, isNotEmpty, reason: '${c.name} step query must not be empty');
        expect(c.vibratePacket, isNotEmpty, reason: '${c.name} vibrate packet must not be empty');
        expect(c.state, equals(CombinationState.idle));
      }
    });

    test('Comb 1 (HiWatch Pro Official) payload shapes match APK reverse-engineering', () {
      final combs = ProtocolPresetLibrary.getPresetCombinations();
      final comb1 = combs.firstWhere((c) => c.id == 'comb_hiwatch_official');

      expect(comb1.targetServiceHint, equals('6e40'));
      expect(comb1.targetWriteHint, equals('6e400002'));
      expect(comb1.targetNotifyHint, equals('6e400003'));

      // Handshake: CD 00 06 12 01 0A 00 01 02
      expect(comb1.handshakePacket, equals([0xCD, 0x00, 0x06, 0x12, 0x01, 0x0A, 0x00, 0x01, 0x02]));
      // HR trigger: CD 00 06 12 01 0D 00 01 01
      expect(comb1.hrTriggerPacket, equals([0xCD, 0x00, 0x06, 0x12, 0x01, 0x0D, 0x00, 0x01, 0x01]));
      // Step query: CD 00 06 12 01 06 00 01 01
      expect(comb1.stepQueryPacket, equals([0xCD, 0x00, 0x06, 0x12, 0x01, 0x06, 0x00, 0x01, 0x01]));
      // Vibrate: CD 00 06 12 01 04 00 01 01
      expect(comb1.vibratePacket, equals([0xCD, 0x00, 0x06, 0x12, 0x01, 0x04, 0x00, 0x01, 0x01]));
    });

    test('Comb 2 (FitPro Sport Stream) payload shapes match Profile.java', () {
      final combs = ProtocolPresetLibrary.getPresetCombinations();
      final comb2 = combs.firstWhere((c) => c.id == 'comb_fitpro_sport');

      expect(comb2.hrTriggerPacket, equals([0xCD, 0x00, 0x06, 0x15, 0x01, 0x04, 0x00, 0x01, 0x01]));
      expect(comb2.stepQueryPacket, equals([0xCD, 0x00, 0x06, 0x15, 0x01, 0x0C, 0x00, 0x01, 0x01]));
    });

    test('Comb 3 (Beken/Telink OTA) targets FF01 / FF02 / FF03', () {
      final combs = ProtocolPresetLibrary.getPresetCombinations();
      final comb3 = combs.firstWhere((c) => c.id == 'comb_ota_chars');

      expect(comb3.targetServiceHint, equals('ff01'));
      expect(comb3.targetWriteHint, equals('ff02'));
      expect(comb3.targetNotifyHint, equals('ff03'));
    });

    test('Comb 4 (DaFit / Shenzhen) targets FEE7 and uses 0xAB framing', () {
      final combs = ProtocolPresetLibrary.getPresetCombinations();
      final comb4 = combs.firstWhere((c) => c.id == 'comb_dafit_shenzhen');

      expect(comb4.targetServiceHint, equals('fee7'));
      expect(comb4.targetWriteHint, equals('fee1'));
      expect(comb4.targetNotifyHint, equals('fee2'));
      expect(comb4.handshakePacket.first, equals(0xAB));
      expect(comb4.hrTriggerPacket.first, equals(0xAB));
    });

    test('Comb 6 (Bluetooth SIG) targets 0x180D / 0x2A39 / 0x2A37', () {
      final combs = ProtocolPresetLibrary.getPresetCombinations();
      final comb6 = combs.firstWhere((c) => c.id == 'comb_ble_sig');

      expect(comb6.targetServiceHint, equals('180d'));
      expect(comb6.targetWriteHint, equals('2a39'));
      expect(comb6.targetNotifyHint, equals('2a37'));
    });

    test('Comb 7 (Direct RTC) encodes current year, month, day, hour, min, sec accurately', () {
      final fixedDate = DateTime(2026, 10, 4, 15, 30, 45);
      final combs = ProtocolPresetLibrary.getPresetCombinations(referenceTime: fixedDate);
      final comb7 = combs.firstWhere((c) => c.id == 'comb_rtc_sync');

      final rtc = comb7.handshakePacket;
      expect(rtc.length, equals(16));
      expect(rtc[0], equals(0xCD));
      expect(rtc[3], equals(0x12));
      expect(rtc[7], equals(0x07)); // 7-byte timestamp length
      expect((rtc[8] << 8) | rtc[9], equals(2026)); // Year
      expect(rtc[10], equals(10)); // Month
      expect(rtc[11], equals(4)); // Day
      expect(rtc[12], equals(15)); // Hour
      expect(rtc[13], equals(30)); // Minute
      expect(rtc[14], equals(45)); // Second
    });

    test('Comb 8 (Vendor Keepalive Ping) encodes 0x68 framing', () {
      final combs = ProtocolPresetLibrary.getPresetCombinations();
      final comb8 = combs.firstWhere((c) => c.id == 'comb_keepalive_ping');

      expect(comb8.handshakePacket, equals([0x68, 0x00, 0x01, 0x01, 0x68]));
    });
  });

  group('2. Raw Packet Parser & Telemetry Decoding Audit', () {
    test('Empty packet returns empty parsed data without crashing', () {
      final res = WatchPacketParser.parse([]);
      expect(res.hasVitals, isFalse);
      expect(res.heartRate, isNull);
      expect(res.autoAck, isNull);
    });

    test('Standard BLE SIG Heart Rate (8-bit val: 78 BPM)', () {
      final bytes = [0x00, 78];
      final res = WatchPacketParser.parse(bytes);

      expect(res.heartRate, equals(78));
      expect(res.hasVitals, isTrue);
      expect(res.annotations, contains('❤️ PULSE: 78 BPM'));
      expect(res.autoAck, isNull);
    });

    test('Standard BLE SIG Heart Rate (16-bit val: 85 BPM)', () {
      final bytes = [0x01, 85, 0x00];
      final res = WatchPacketParser.parse(bytes);

      expect(res.heartRate, equals(85));
      expect(res.hasVitals, isTrue);
    });

    test('BLE SIG HR ignores out-of-range physiological extremes (<35 or >220)', () {
      final low = WatchPacketParser.parse([0x00, 20]);
      expect(low.heartRate, isNull);

      final high = WatchPacketParser.parse([0x00, 245]);
      expect(high.heartRate, isNull);
    });

    test('HiWatch Pro 0xCD TLV Vitals Packet decodes HR, SYS, DIA, SPO2 and generates Auto-ACK', () {
      // 0xCD 0x00 0x10 0x12 0x01 0x04 ... 16:HR, 17:SYS, 18:DIA, 19:SPO2
      final bytes = [
        0xCD, 0x00, 0x10, 0x12, 0x01, 0x04,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        76, // byte 16: HR (76 bpm)
        122, // byte 17: SYS (122 mmHg)
        82, // byte 18: DIA (82 mmHg)
        98, // byte 19: SpO2 (98%)
      ];

      final res = WatchPacketParser.parse(bytes);

      expect(res.heartRate, equals(76));
      expect(res.systolic, equals(122));
      expect(res.diastolic, equals(82));
      expect(res.spo2, equals(98));
      expect(res.hasVitals, isTrue);

      // Auto-ACK validation for cmd 0x12
      expect(res.autoAck, equals([0xDC, 0x00, 0x05, 0x12, 0x01, 0x00, 0x10, 0x01]));
      expect(res.annotations.any((a) => a.contains('ACK SENT (0x12)')), isTrue);
    });

    test('HiWatch Pro BP packet normalizes Inverted Order (Sys > Dia guarantee)', () {
      // If sensor transmits lower first [80, 125], parser must enforce sys = 125, dia = 80
      final bytes = [
        0xCD, 0x00, 0x10, 0x12, 0x01, 0x05,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        80, // byte 16
        125, // byte 17
      ];

      final res = WatchPacketParser.parse(bytes);

      expect(res.systolic, equals(125));
      expect(res.diastolic, equals(80));
      expect(res.systolic! > res.diastolic!, isTrue);
      expect(res.annotations, contains('🩺 BP: 125/80 mmHg'));
    });

    test('HiWatch Pro Step Count packet decodes big-endian accumulation', () {
      // 0xCD ... key 0x0B, bytes 14..15 is step count
      final bytes = List<int>.filled(20, 0);
      bytes[0] = 0xCD;
      bytes[3] = 0x15;
      bytes[5] = 0x0B;
      bytes[14] = 0x14; // (0x14 << 8) | 0x50 = 5200 steps
      bytes[15] = 0x50;

      final res = WatchPacketParser.parse(bytes);

      expect(res.steps, equals(5200));
      expect(res.annotations, contains('🚶 STEPS: 5200'));
      expect(res.autoAck, equals([0xDC, 0x00, 0x05, 0x15, 0x01, 0x00, 0x10, 0x01]));
    });

    test('Real Ultra2 hardware sport packet (CD 00 11 15 01 02...) decodes 5,839 steps', () {
      // Exact packet captured from user's physical Ultra2 watch:
      final bytes = [
        0xCD, 0x00, 0x11, 0x15, 0x01, 0x02, 0x00, 0x0C,
        0x32, 0x26, 0x00, 0x01,
        0x16, 0xCF, // 0x16CF = 5,839 steps!
        0x00, 0xFE, // 0x00FE = 254 kcal
        0x04, 0x48, // Time: 04:48 AM
        0x1C, 0x20, // Distance: 7,200m
      ];

      final res = WatchPacketParser.parse(bytes);

      expect(res.steps, equals(5839));
      expect(res.annotations, contains('🚶 STEPS: 5839'));
      expect(res.autoAck, equals([0xDC, 0x00, 0x05, 0x15, 0x01, 0x00, 0x10, 0x01]));
    });

    test('DaFit 0xAB Heart Rate packet decodes accurately', () {
      final bytes = [0xAB, 0x09, 0x54, 74];
      final res = WatchPacketParser.parse(bytes);

      expect(res.heartRate, equals(74));
      expect(res.annotations, contains('❤️ PULSE: 74 BPM'));
    });

    test('DaFit 0xAB Step Count packet decodes accurately', () {
      final bytes = [0xAB, 0x51, 0x00, 0x0A, 0x0F, 0xA0, 0x64]; // 0x0FA0 = 4000 steps
      final res = WatchPacketParser.parse(bytes);

      expect(res.steps, equals(4000));
      expect(res.annotations, contains('🚶 STEPS: 4000'));
    });
  });

  group('3. Multi-Turn Stream Simulation & Fuzz Resilience', () {
    test('50-turn simulated workout stream preserves continuous state progression', () {
      int simulatedSteps = 1000;
      int simulatedHr = 75;

      for (int turn = 1; turn <= 50; turn++) {
        simulatedSteps += 20;
        simulatedHr = 75 + (turn % 40);

        final bytes = [
          0xCD, 0x00, 0x10, 0x12, 0x01, 0x04,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          simulatedHr, 120, 80, 98
        ];

        final res = WatchPacketParser.parse(bytes);

        expect(res.heartRate, equals(simulatedHr));
        expect(res.systolic, equals(120));
        expect(res.diastolic, equals(80));
        expect(res.autoAck, isNotNull);
      }
    });

    test('1,000 randomized fuzz packets never throw unhandled exceptions', () {
      final rng = Random(42);

      for (int i = 0; i < 1000; i++) {
        final len = rng.nextInt(64);
        final bytes = List<int>.generate(len, (_) => rng.nextInt(256));

        expect(() => WatchPacketParser.parse(bytes), returnsNormally);
      }
    });
  });

  group('4. Diagnostic Report Generation Audit', () {
    test('Report generates comprehensive text including device, vitals, GATT & logs', () {
      final comb = ProtocolPresetLibrary.getPresetCombinations().first;
      comb.state = CombinationState.passed;
      comb.matchDetails = 'ACK received in 85ms';

      final service = GattServiceDescriptor(
        serviceUuid: '00006e40-0001-1000-8000-00805f9b34fb',
        characteristics: [
          GattCharDescriptor(
            charUuid: '00006e40-0002-1000-8000-00805f9b34fb',
            properties: ['write'],
          ),
          GattCharDescriptor(
            charUuid: '00006e40-0003-1000-8000-00805f9b34fb',
            properties: ['notify'],
          ),
        ],
      );

      final logs = [
        LogEntry(type: LogType.tx, message: 'TX: Handshake sent'),
        LogEntry(type: LogType.rx, message: 'RX: 0xCD Handshake ACK received'),
        LogEntry(type: LogType.match, message: 'MATCH: Comb 1 verified'),
      ];

      final report = WatchReportGenerator.generate(
        deviceName: 'HiWatch Pro Ultra',
        deviceMac: 'FC:58:FA:7E:6D:94',
        winningCombination: comb,
        workingWriteChar: '6e400002',
        workingNotifyChar: '6e400003',
        liveHeartRate: 78,
        liveSystolic: 120,
        liveDiastolic: 80,
        liveSpo2: 98,
        liveSteps: 6420,
        discoveredServices: [service],
        logs: logs,
      );

      expect(report, contains('⚡ VYRA SMARTWATCH HARDWARE VERIFICATION & PROTOCOL REPORT'));
      expect(report, contains('HiWatch Pro Ultra'));
      expect(report, contains('FC:58:FA:7E:6D:94'));
      expect(report, contains('Comb 1: HiWatch Pro Official'));
      expect(report, contains('78 BPM (VERIFIED)'));
      expect(report, contains('120/80 mmHg (VERIFIED)'));
      expect(report, contains('98% (VERIFIED)'));
      expect(report, contains('6420 (VERIFIED)'));
      expect(report, contains('00006e40-0001-1000-8000-00805f9b34fb'));
      expect(report, contains('6e400002'));
      expect(report, contains('6e400003'));
      expect(report, contains('TX: Handshake sent'));
      expect(report, contains('END OF REPORT'));
    });

    test('Report handles null/empty gracefully without crashing', () {
      final report = WatchReportGenerator.generate();

      expect(report, contains('Status: Not connected during export'));
      expect(report, contains('No single auto-combination matched'));
      expect(report, contains('Not verified'));
      expect(report, contains('(No GATT services captured)'));
      expect(report, contains('(No packets captured)'));
    });
  });
}
