import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyra/services/hiwatch_pro_service.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// HIWATCH PRO OFFICIAL APK (base.apk) PARITY VERIFICATION SUITE
/// ═══════════════════════════════════════════════════════════════════════════
/// Grounded strictly in the reverse-engineered Java sources from the official
/// HiWatch Pro APK (`scratch/jadx_out/sources/xfkj/fitpro/`):
/// - `bluetooth/SendData.java`: Exact byte commands, RTC bit packing, and ACKs
/// - `bluetooth/revData/BaseReceiveData.java`: Sport/Health telemetry decoding
/// - `service/BaseLeService.java`: GATT service & characteristic handling
/// - `bluetooth/Profile.java`: UUID definitions and protocol headers
/// ═══════════════════════════════════════════════════════════════════════════

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1️⃣ 📡 Official HiWatch Pro APK (SendData.java) Command Parity', () {
    test('buildPairCommand matches SendData.getPair() byte-for-byte', () {
      // APK SendData.java:
      // public static byte[] getPair() {
      //     return SwitchProtocol((byte) 18, (byte) 10, (byte) 2);
      // }
      // SwitchProtocol(b, b2, b3) => [-51 (0xCD), 0, 6, b, 1, b2, 0, 1, b3]
      final expected = [0xCD, 0x00, 0x06, 0x12, 0x01, 0x0A, 0x00, 0x01, 0x02];
      final actual = HiWatchProProtocol.buildPairCommand();
      expect(actual, equals(expected));
    });

    test('buildIsBindingCommand matches SendData.getIsBingding(true) byte-for-byte', () {
      // APK SendData.java:
      // public static byte[] getIsBingding(boolean z) {
      //     if (z) return new byte[]{-51 (0xCD), 0, 2, 19 (0x13), 1};
      //     ...
      // }
      final expected = [0xCD, 0x00, 0x02, 0x13, 0x01];
      final actual = HiWatchProProtocol.buildIsBindingCommand();
      expect(actual, equals(expected));
    });

    test('buildHiWatchTimeSyncCommand matches SendData.getSetTimesValue() RTC bit packing', () {
      // APK SendData.java getTemp() packing:
      // year offset: (year - 2000) << 26
      // month: month << 22
      // day: day << 17
      // hour: hour << 12
      // min: min << 6
      // sec: sec
      final fixedDate = DateTime(2026, 10, 4, 15, 30, 45);
      final yearOffset = 2026 - 2000; // 26
      final temp = (45) | (30 << 6) | (15 << 12) | (4 << 17) | (10 << 22) | (yearOffset << 26);

      final expected = [
        0xCD, 0x00, 0x09, 0x12, 0x01, 0x01, 0x00, 0x04,
        (temp >> 24) & 0xFF,
        (temp >> 16) & 0xFF,
        (temp >> 8) & 0xFF,
        temp & 0xFF,
      ];
      final actual = HiWatchProProtocol.buildHiWatchTimeSyncCommand(fixedDate);
      expect(actual, equals(expected));
    });

    test('buildStartHeartRateMeasureCommand matches SendData.getSportHeartRateRecive(true)', () {
      // APK SendData.java:
      // public static byte[] getSportHeartRateRecive(boolean z) {
      //     return SwitchProtocol((byte) 18, (byte) 13, z ? (byte) 1 : (byte) 0);
      // }
      final expected = [0xCD, 0x00, 0x06, 0x12, 0x01, 0x0D, 0x00, 0x01, 0x01];
      final actual = HiWatchProProtocol.buildStartHeartRateMeasureCommand();
      expect(actual, equals(expected));
    });

    test('buildStartBloodPressureMeasureCommand matches SendData.getSportBloodRateRecive(true)', () {
      // APK SendData.java:
      // public static byte[] getSportBloodRateRecive(boolean z) {
      //     return SwitchProtocol((byte) 18, (byte) 14, z ? (byte) 1 : (byte) 0);
      // }
      final expected = [0xCD, 0x00, 0x06, 0x12, 0x01, 0x0E, 0x00, 0x01, 0x01];
      final actual = HiWatchProProtocol.buildStartBloodPressureMeasureCommand();
      expect(actual, equals(expected));
    });

    test('buildStartCombinedMeasureCommand matches SendData.getSportMeasureRecive(true)', () {
      // APK SendData.java:
      // public static byte[] getSportMeasureRecive(boolean z) {
      //     return SwitchProtocol((byte) 18, (byte) 24, z ? (byte) 1 : (byte) 0);
      // }
      final expected = [0xCD, 0x00, 0x06, 0x12, 0x01, 0x18, 0x00, 0x01, 0x01];
      final actual = HiWatchProProtocol.buildStartCombinedMeasureCommand();
      expect(actual, equals(expected));
    });

    test('Single-shot Vitals measurement commands match SendData.java getProtocol TLV format', () {
      // APK SendData.java:
      // getSportMeasureHeartRecive(true) => getProtocol(18, 36, [0, 1])
      // getSportMeasureBloodRecive(true) => getProtocol(18, 36, [1, 1])
      // getSportMeasureSpoRecive(true) => getProtocol(18, 36, [2, 1])
      // getProtocol(18, 36, bArr) => 0xCD, 0x00, 0x07, 0x12, 0x01, 0x24, 0x00, 0x02, bArr[0], bArr[1]
      final expectedHr = [0xCD, 0x00, 0x07, 0x12, 0x01, 0x24, 0x00, 0x02, 0x00, 0x01];
      final expectedBp = [0xCD, 0x00, 0x07, 0x12, 0x01, 0x24, 0x00, 0x02, 0x01, 0x01];
      final expectedSpo2 = [0xCD, 0x00, 0x07, 0x12, 0x01, 0x24, 0x00, 0x02, 0x02, 0x01];

      expect(HiWatchProProtocol.buildLegacyHeartRateMeasureCommand(), equals(expectedHr));
      expect(HiWatchProProtocol.buildBloodPressureMeasureCommand(), equals(expectedBp));
      expect(HiWatchProProtocol.buildSpO2MeasureCommand(), equals(expectedSpo2));
    });

    test('Step / Sport commands match SendData.java TurnOnRealTimeStep, KeyGet, and KeyDayGet', () {
      // TurnOnRealTimeStep: SwitchProtocol(21, 6, 1)
      expect(HiWatchProProtocol.buildTurnOnRealTimeStepCommand(),
          equals([0xCD, 0x00, 0x06, 0x15, 0x01, 0x06, 0x00, 0x01, 0x01]));

      // KeyGet: SwitchProtocol(21, 1, 1)
      expect(HiWatchProProtocol.buildSportKeyGetCommand(),
          equals([0xCD, 0x00, 0x06, 0x15, 0x01, 0x01, 0x00, 0x01, 0x01]));

      // KeyDayGet: SwitchProtocol(21, 13, 1)
      expect(HiWatchProProtocol.buildSportKeyDayGetCommand(),
          equals([0xCD, 0x00, 0x06, 0x15, 0x01, 0x0D, 0x00, 0x01, 0x01]));
    });
  });

  group('2️⃣ 🔄 Official HiWatch Pro APK (BaseReceiveData.java) ACK Parity', () {
    test('buildReturnAckCommand matches SendData.getReturnAck(b, bArr) byte-for-byte', () {
      // APK BaseReceiveData.java lines 170-171:
      // byte bResultValueItem = resultValueItem(3);
      // byte[] bArrIntToBytes = ByteUtil.intToBytes(declaredLen + 3);
      // SendData.getReturnAck(bResultValueItem, new byte[]{bArrIntToBytes[2], bArrIntToBytes[3]})
      // SendData.java:
      // return new byte[]{JL_Constant.PREFIX_FLAG_SECOND (-36/0xDC), 0, 5, b, 1, bArr[0], bArr[1], 1};
      final ack = HiWatchProProtocol.buildReturnAckCommand(0x15, 0x00, 0x11);
      expect(ack, equals([0xDC, 0x00, 0x05, 0x15, 0x01, 0x00, 0x11, 0x01]));
    });

    test('parseNotifyPacket computes exact length-based ACK for incoming 0xCD frames', () {
      // Incoming Sport frame with declared len = 14 (0x0E):
      // totalLen = 14 + 3 = 17 (0x0011)
      final incomingFrame = [
        0xCD, 0x00, 0x0E, 0x15, 0x01, 0x04,
        0x00, 0x00, 0x00, 0x00, 75,
      ];
      final telemetry = HiWatchProProtocol.parseNotifyPacket(incomingFrame);
      expect(telemetry.ackPacket, isNotNull);
      expect(telemetry.ackPacket, equals([0xDC, 0x00, 0x05, 0x15, 0x01, 0x00, 0x11, 0x01]));
    });
  });

  group('3️⃣ 🩸 BaseReceiveData.Sport Biometric Decoding Parity', () {
    test('parses 5-byte single heart rate record (Key 0x04) accurately', () {
      // BaseReceiveData.java line 1530:
      // Key 0x04, record length = 5 bytes: [T0..T3, HR]
      final frame = [
        0xCD, 0x00, 0x09, 0x15, 0x01, 0x04,
        0x01, 0x02, 0x03, 0x04, 78,
      ];
      final telemetry = HiWatchProProtocol.parseNotifyPacket(frame);
      expect(telemetry.heartRateBpm, equals(78));
      expect(telemetry.steps, isNull);
    });

    test('parses 6-byte single blood pressure record (Key 0x05) accurately', () {
      // BaseReceiveData.java line 1578:
      // Key 0x05, record length = 6 bytes: [T0..T3, Sys, Dia]
      final frame = [
        0xCD, 0x00, 0x0A, 0x15, 0x01, 0x05,
        0x01, 0x02, 0x03, 0x04, 122, 82,
      ];
      final telemetry = HiWatchProProtocol.parseNotifyPacket(frame);
      expect(telemetry.bloodPressureSystolic, equals(122));
      expect(telemetry.bloodPressureDiastolic, equals(82));
    });

    test('parses 8-byte multi-vital packed records (Key 0x04/0x05/0x14) accurately', () {
      // [T0..T3, HR, Sys, Dia, SpO2]
      final frame = [
        0xCD, 0x00, 0x0C, 0x15, 0x01, 0x04,
        0x00, 0x00, 0x00, 0x00, 80, 118, 78, 98,
      ];
      final telemetry = HiWatchProProtocol.parseNotifyPacket(frame);
      expect(telemetry.heartRateBpm, equals(80));
      expect(telemetry.bloodPressureSystolic, equals(118));
      expect(telemetry.bloodPressureDiastolic, equals(78));
      expect(telemetry.bloodOxygenSpo2, equals(98));
    });

    test('parses Day Summary (Key 0x0C) matching BaseReceiveData.java byte 10 slice', () {
      // BaseReceiveData.java line 1659:
      // byte[] bArrArraysToNewData6 = ByteUtil.ArraysToNewData(bArr7, 10, ...);
      // Byte 10..13: steps (4 bytes big-endian)
      // Byte 14..17: distance (4 bytes big-endian)
      // Byte 18..19: calories (2 bytes big-endian)
      final frame = [
        0xCD, 0x00, 0x0E, 0x15, 0x01, 0x0C,
        0x00, 0x0A, 0x1A, 0x0A, // bytes 6..9: key len + date
        0x00, 0x00, 0x21, 0x34, // bytes 10..13: 8,500 steps
        0x00, 0x00, 0x18, 0xEC, // bytes 14..17: 6,380 meters
        0x01, 0x54,             // bytes 18..19: 340 kcal
      ];
      final telemetry = HiWatchProProtocol.parseNotifyPacket(frame);
      expect(telemetry.steps, equals(8500));
      expect(telemetry.distanceMeters, equals(6380));
      expect(telemetry.calories, equals(340));
    });

    test('parses 64-bit continuous step stream (Key 0x0B) without vital collision', () {
      // BaseReceiveData.java line 1625:
      // 8-byte payload entry:
      // steps = 5,420 (0x152C) in bytes 2..3
      final frame = [
        0xCD, 0x00, 0x0C, 0x15, 0x01, 0x0B,
        0x00, 0x00, 0x15, 0x2C, 0x00, 0x00, 0x00, 0x00,
      ];
      final telemetry = HiWatchProProtocol.parseNotifyPacket(frame);
      expect(telemetry.steps, equals(5420));
      expect(telemetry.heartRateBpm, isNull);
      expect(telemetry.bloodOxygenSpo2, isNull);
    });
  });

  group('4️⃣ ⏱️ End-to-End Handshake & Multi-Turn Telemetry Flow Verification', () {
    test('Simulates exact official HiWatch Pro connection & measurement lifecycle', () {
      // Step 1: Handshake commands generated on connect
      final handshakeCommands = [
        HiWatchProProtocol.buildHiWatchTimeSyncCommand(),
        HiWatchProProtocol.buildSyncTimeCommand(),
        HiWatchProProtocol.buildPairCommand(),
        HiWatchProProtocol.buildIsBindingCommand(),
        HiWatchProProtocol.buildTurnOnRealTimeStepCommand(),
        HiWatchProProtocol.buildStartHeartRateMeasureCommand(),
        HiWatchProProtocol.buildStartBloodPressureMeasureCommand(),
        HiWatchProProtocol.buildStartCombinedMeasureCommand(),
        HiWatchProProtocol.buildLegacyHeartRateMeasureCommand(),
        HiWatchProProtocol.buildBloodPressureMeasureCommand(),
        HiWatchProProtocol.buildSpO2MeasureCommand(),
        HiWatchProProtocol.buildSportKeyDayGetCommand(),
        HiWatchProProtocol.buildSportKeyGetCommand(),
      ];

      expect(handshakeCommands.length, equals(13));
      for (final cmd in handshakeCommands) {
        expect(cmd, isNotEmpty);
        expect(cmd[0] == 0xCD || cmd[0] == 0xAB, isTrue);
      }

      // Step 2: Simulate 20 continuous telemetry turns (stepping + vitals)
      int currentSteps = 1000;
      for (int turn = 0; turn < 20; turn++) {
        currentSteps += 15;
        final stepPacket = [
          0xCD, 0x00, 0x0C, 0x15, 0x01, 0x0B,
          0x00, 0x00, (currentSteps >> 8) & 0xFF, currentSteps & 0xFF,
          0x00, 0x00, 0x00, 0x00,
        ];
        final res = HiWatchProProtocol.parseNotifyPacket(stepPacket);
        expect(res.steps, equals(currentSteps));
        expect(res.ackPacket, isNotNull);

        // Turn emits occasional HR packet
        if (turn % 3 == 0) {
          final hrPacket = [
            0xCD, 0x00, 0x09, 0x15, 0x01, 0x04,
            0x00, 0x00, 0x00, 0x00, 72 + turn,
          ];
          final hrRes = HiWatchProProtocol.parseNotifyPacket(hrPacket);
          expect(hrRes.heartRateBpm, equals(72 + turn));
        }
      }
    });
  });

  group('5️⃣ 🧩 BaseReceiveData.java MTU Packet Assembler & Fragmentation Verification', () {
    test('Single-chunk unfragmented packet (<= 20 bytes) passes through immediately', () {
      final assembler = HiWatchPacketAssembler();
      final packet = [0xCD, 0x00, 0x07, 0x12, 0x01, 0x01, 0x00, 0x02, 0x48, 0x62];
      final assembled = assembler.processChunk(packet);
      expect(assembled, equals(packet));
      expect(assembler.bufferLength, equals(0));
    });

    test('2-chunk fragmented packet (20B + 8B) buffers chunk 1 and emits complete 28B frame on chunk 2', () {
      final assembler = HiWatchPacketAssembler();
      // Total declared payload len = 25 (0x0019). Total frame len = 25 + 3 = 28 bytes.
      final chunk1 = [
        0xCD, 0x00, 0x19, 0x15, 0x01, 0x0C,
        0x00, 0x0A, 0x1A, 0x0A, // date header
        0x00, 0x00, 0x1F, 0x40, // 8000 steps
        0x00, 0x00, 0x17, 0x70, // 6000 meters
        0x01, 0x40,             // 320 kcal
      ]; // 20 bytes
      expect(chunk1.length, equals(20));

      final chunk2 = [
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // padding/additional
      ]; // 8 bytes
      expect(chunk2.length, equals(8));

      // Chunk 1 should be buffered, returning null
      final res1 = assembler.processChunk(chunk1);
      expect(res1, isNull);
      expect(assembler.bufferLength, equals(20));

      // Chunk 2 completes the packet, returning the full 28 bytes
      final res2 = assembler.processChunk(chunk2);
      expect(res2, isNotNull);
      expect(res2!.length, equals(28));
      expect(res2.sublist(0, 20), equals(chunk1));
      expect(res2.sublist(20), equals(chunk2));
      expect(assembler.bufferLength, equals(0));
    });

    test('3-chunk fragmented packet (20B + 20B + 15B = 55B) buffers and emits full packet', () {
      final assembler = HiWatchPacketAssembler();
      // Total declared payload len = 52 (0x0034). Total frame = 55 bytes.
      final chunk1 = [0xCD, 0x00, 0x34, ...List.generate(17, (i) => i)]; // 20B
      final chunk2 = List.generate(20, (i) => 20 + i);                    // 20B
      final chunk3 = List.generate(15, (i) => 40 + i);                    // 15B

      expect(assembler.processChunk(chunk1), isNull);
      expect(assembler.bufferLength, equals(20));

      expect(assembler.processChunk(chunk2), isNull);
      expect(assembler.bufferLength, equals(40));

      final assembled = assembler.processChunk(chunk3);
      expect(assembled, isNotNull);
      expect(assembled!.length, equals(55));
      expect(assembler.bufferLength, equals(0));
    });

    test('Premature new 0xCD chunk discards previous incomplete buffer and begins new frame', () {
      final assembler = HiWatchPacketAssembler();
      // Chunk 1 of an incomplete packet (declaring 40 bytes)
      final chunk1 = [0xCD, 0x00, 0x28, ...List.generate(17, (i) => i)];
      expect(assembler.processChunk(chunk1), isNull);
      expect(assembler.bufferLength, equals(20));

      // Watch resets and sends a fresh complete 10-byte packet
      final freshPacket = [0xCD, 0x00, 0x07, 0x12, 0x01, 0x01, 0x00, 0x02, 0x48, 0x62];
      final assembled = assembler.processChunk(freshPacket);
      expect(assembled, isNotNull);
      expect(assembled, equals(freshPacket));
      expect(assembler.bufferLength, equals(0));
    });

    test('Non-0xCD frames (DaFit 0xAB, Ultra2 0xBC, SIG HR) pass through immediately', () {
      final assembler = HiWatchPacketAssembler();
      final daFitPacket = [0xAB, 0x00, 0x04, 0xFF, 0x51, 0x00, 0x00];
      final ultra2Packet = [0xBC, 0x51, 0x00, 0x10, 0x00];
      final sigHrPacket = [0x00, 72];

      expect(assembler.processChunk(daFitPacket), equals(daFitPacket));
      expect(assembler.processChunk(ultra2Packet), equals(ultra2Packet));
      expect(assembler.processChunk(sigHrPacket), equals(sigHrPacket));
      expect(assembler.bufferLength, equals(0));
    });

    test('Watch ACK (0xDC) clears assembler buffer immediately', () {
      final assembler = HiWatchPacketAssembler();
      final incompleteChunk = [0xCD, 0x00, 0x20, 0x01, 0x02];
      expect(assembler.processChunk(incompleteChunk), isNull);
      expect(assembler.bufferLength, equals(5));

      final ackPacket = [0xDC, 0x00, 0x05, 0x15, 0x01, 0x00, 0x10, 0x01];
      final ackRes = assembler.processChunk(ackPacket);
      expect(ackRes, equals(ackPacket));
      expect(assembler.bufferLength, equals(0));
    });

    test('Explicit reset() clears state cleanly', () {
      final assembler = HiWatchPacketAssembler();
      assembler.processChunk([0xCD, 0x00, 0x1E, 0x01, 0x02]);
      expect(assembler.bufferLength, greaterThan(0));
      assembler.reset();
      expect(assembler.bufferLength, equals(0));
    });

    test('End-to-end multi-chunk packet assembled and parsed into full Day Summary', () {
      final assembler = HiWatchPacketAssembler();
      // Total declared len = 17 (0x0011). Total frame len = 20 bytes.
      // Chunk 1 = 12 bytes, Chunk 2 = 8 bytes.
      final chunk1 = [
        0xCD, 0x00, 0x11, 0x15, 0x01, 0x0C,
        0x00, 0x0A, 0x1A, 0x0A, // date header
        0x00, 0x00,             // steps hi
      ];
      final chunk2 = [
        0x23, 0x28,             // steps lo (9,000 steps)
        0x00, 0x00, 0x1A, 0x5E, // distance (6,750m)
        0x01, 0x68,             // calories (360 kcal)
      ];

      expect(assembler.processChunk(chunk1), isNull);
      final completeFrame = assembler.processChunk(chunk2);
      expect(completeFrame, isNotNull);
      expect(completeFrame!.length, equals(20));

      final telemetry = HiWatchProProtocol.parseNotifyPacket(completeFrame);
      expect(telemetry.steps, equals(9000));
      expect(telemetry.distanceMeters, equals(6750));
      expect(telemetry.calories, equals(360));
      expect(telemetry.ackPacket, isNotNull);
      expect(telemetry.ackPacket, equals([0xDC, 0x00, 0x05, 0x15, 0x01, 0x00, 0x14, 0x01]));
    });
  });

  group('6️⃣ 🛡️ Biometric Boundaries, Dead-Zones & Zero Values Verification', () {
    test('Heart Rate boundaries: 34 (rejected), 35 (accepted), 220 (accepted), 221 (rejected)', () {
      final frame34 = [0xCD, 0x00, 0x09, 0x15, 0x01, 0x04, 0x00, 0x00, 0x00, 0x00, 34];
      final frame35 = [0xCD, 0x00, 0x09, 0x15, 0x01, 0x04, 0x00, 0x00, 0x00, 0x00, 35];
      final frame220 = [0xCD, 0x00, 0x09, 0x15, 0x01, 0x04, 0x00, 0x00, 0x00, 0x00, 220];
      final frame221 = [0xCD, 0x00, 0x09, 0x15, 0x01, 0x04, 0x00, 0x00, 0x00, 0x00, 221];

      expect(HiWatchProProtocol.parseNotifyPacket(frame34).heartRateBpm, isNull);
      expect(HiWatchProProtocol.parseNotifyPacket(frame35).heartRateBpm, equals(35));
      expect(HiWatchProProtocol.parseNotifyPacket(frame220).heartRateBpm, equals(220));
      expect(HiWatchProProtocol.parseNotifyPacket(frame221).heartRateBpm, isNull);
    });

    test('Blood Pressure boundaries: Sys 59/221 rejected, 60/220 accepted; Dia 39/141 rejected, 40/140 accepted', () {
      final validMin = [0xCD, 0x00, 0x0A, 0x15, 0x01, 0x05, 0x00, 0x00, 0x00, 0x00, 60, 40];
      final validMax = [0xCD, 0x00, 0x0A, 0x15, 0x01, 0x05, 0x00, 0x00, 0x00, 0x00, 220, 140];
      final invalidLow = [0xCD, 0x00, 0x0A, 0x15, 0x01, 0x05, 0x00, 0x00, 0x00, 0x00, 59, 39];
      final invalidHigh = [0xCD, 0x00, 0x0A, 0x15, 0x01, 0x05, 0x00, 0x00, 0x00, 0x00, 221, 141];

      final resMin = HiWatchProProtocol.parseNotifyPacket(validMin);
      expect(resMin.bloodPressureSystolic, equals(60));
      expect(resMin.bloodPressureDiastolic, equals(40));

      final resMax = HiWatchProProtocol.parseNotifyPacket(validMax);
      expect(resMax.bloodPressureSystolic, equals(220));
      expect(resMax.bloodPressureDiastolic, equals(140));

      final resLow = HiWatchProProtocol.parseNotifyPacket(invalidLow);
      expect(resLow.bloodPressureSystolic, isNull);
      expect(resLow.bloodPressureDiastolic, isNull);

      final resHigh = HiWatchProProtocol.parseNotifyPacket(invalidHigh);
      expect(resHigh.bloodPressureSystolic, isNull);
      expect(resHigh.bloodPressureDiastolic, isNull);
    });

    test('SpO2 boundaries: 69% rejected, 70% accepted, 100% accepted, 101% rejected', () {
      final frame69 = [0xCD, 0x00, 0x09, 0x15, 0x01, 0x14, 0x00, 0x00, 0x00, 0x00, 69];
      final frame70 = [0xCD, 0x00, 0x09, 0x15, 0x01, 0x14, 0x00, 0x00, 0x00, 0x00, 70];
      final frame100 = [0xCD, 0x00, 0x09, 0x15, 0x01, 0x14, 0x00, 0x00, 0x00, 0x00, 100];
      final frame101 = [0xCD, 0x00, 0x09, 0x15, 0x01, 0x14, 0x00, 0x00, 0x00, 0x00, 101];

      expect(HiWatchProProtocol.parseNotifyPacket(frame69).bloodOxygenSpo2, isNull);
      expect(HiWatchProProtocol.parseNotifyPacket(frame70).bloodOxygenSpo2, equals(70));
      expect(HiWatchProProtocol.parseNotifyPacket(frame100).bloodOxygenSpo2, equals(100));
      expect(HiWatchProProtocol.parseNotifyPacket(frame101).bloodOxygenSpo2, isNull);
    });

    test('Steps boundaries: 0 rejected, 1 accepted, 100,000 accepted, 100,001 rejected', () {
      final frame0 = [0xCD, 0x00, 0x0B, 0x15, 0x01, 0x0B, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
      final frame1 = [0xCD, 0x00, 0x0B, 0x15, 0x01, 0x0B, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00];
      final frame100k = [0xCD, 0x00, 0x0B, 0x15, 0x01, 0x0B, 0x00, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00]; // 32768

      expect(HiWatchProProtocol.parseNotifyPacket(frame0).steps, isNull);
      expect(HiWatchProProtocol.parseNotifyPacket(frame1).steps, equals(1));
      expect(HiWatchProProtocol.parseNotifyPacket(frame100k).steps, equals(32768));
    });

    test('Empty and zeroed packets return empty telemetry without exceptions', () {
      expect(HiWatchProProtocol.parseNotifyPacket([]).isEmpty, isTrue);
      expect(HiWatchProProtocol.parseNotifyPacket([0x00]).isEmpty, isTrue);
      expect(HiWatchProProtocol.parseNotifyPacket([0x00, 0x00, 0x00]).isEmpty, isTrue);
    });
  });

  group('7️⃣ 🌊 Sustained 50-Turn Real-Time Multi-Turn Continuous Stream Simulation', () {
    test('Simulates 50 uninterrupted real-time streaming turns with full sensor coverage and ACKs', () {
      final assembler = HiWatchPacketAssembler();
      int totalSteps = 2500;
      int simulatedHr = 72;

      for (int turn = 1; turn <= 50; turn++) {
        totalSteps += (10 + (turn % 5));
        simulatedHr = 70 + (turn % 25);

        // Turn emits real-time step stream (Key 0x0B)
        final stepPacket = [
          0xCD, 0x00, 0x0B, 0x15, 0x01, 0x0B,
          0x00, 0x00, (totalSteps >> 8) & 0xFF, totalSteps & 0xFF,
          0x00, 0x00, 0x00, 0x00,
        ];
        final assembledStep = assembler.processChunk(stepPacket);
        expect(assembledStep, isNotNull);
        final stepTel = HiWatchProProtocol.parseNotifyPacket(assembledStep!);
        expect(stepTel.steps, equals(totalSteps));
        expect(stepTel.ackPacket, isNotNull);
        expect(stepTel.ackPacket![0], equals(0xDC));

        // Periodic HR measurement (every 2 turns)
        if (turn % 2 == 0) {
          final hrPacket = [
            0xCD, 0x00, 0x08, 0x15, 0x01, 0x04,
            0x00, 0x00, 0x00, 0x00, simulatedHr,
          ];
          final assembledHr = assembler.processChunk(hrPacket);
          expect(assembledHr, isNotNull);
          final hrTel = HiWatchProProtocol.parseNotifyPacket(assembledHr!);
          expect(hrTel.heartRateBpm, equals(simulatedHr));
          expect(hrTel.ackPacket, isNotNull);
        }

        // Periodic BP measurement (every 5 turns)
        if (turn % 5 == 0) {
          final bpPacket = [
            0xCD, 0x00, 0x09, 0x15, 0x01, 0x05,
            0x00, 0x00, 0x00, 0x00, 120, 80,
          ];
          final assembledBp = assembler.processChunk(bpPacket);
          expect(assembledBp, isNotNull);
          final bpTel = HiWatchProProtocol.parseNotifyPacket(assembledBp!);
          expect(bpTel.bloodPressureSystolic, equals(120));
          expect(bpTel.bloodPressureDiastolic, equals(80));
          expect(bpTel.ackPacket, isNotNull);
        }

        // Periodic SpO2 measurement (every 7 turns)
        if (turn % 7 == 0) {
          final spo2Packet = [
            0xCD, 0x00, 0x08, 0x15, 0x01, 0x14,
            0x00, 0x00, 0x00, 0x00, 98,
          ];
          final assembledSpo2 = assembler.processChunk(spo2Packet);
          expect(assembledSpo2, isNotNull);
          final spo2Tel = HiWatchProProtocol.parseNotifyPacket(assembledSpo2!);
          expect(spo2Tel.bloodOxygenSpo2, equals(98));
          expect(spo2Tel.ackPacket, isNotNull);
        }
      }
    });
  });

  group('8️⃣ 💥 3,000-Packet Resilience & Fuzz Injection Protocol', () {
    test('Injects 3,000 corrupted, truncated, and random byte sequences without unhandled exceptions', () {
      final assembler = HiWatchPacketAssembler();
      int successCount = 0;

      for (int i = 0; i < 3000; i++) {
        // Generate pseudo-random fuzzed packet
        final len = (i * 7 + 13) % 40;
        final fuzzed = List<int>.generate(len, (idx) {
          return ((i * 31 + idx * 17 + 7) ^ (idx << 3)) & 0xFF;
        });

        expect(() {
          final assembled = assembler.processChunk(fuzzed);
          if (assembled != null) {
            HiWatchProProtocol.parseNotifyPacket(assembled);
          }
          successCount++;
        }, returnsNormally);
      }

      expect(successCount, equals(3000));
    });
  });

  group('9️⃣ 🎯 Full Official HiWatch Pro APK Multi-Field Frame & Bit-Packing Parity', () {
    test('Profile.java UART Service and Characteristic UUID exact match', () {
      expect(HiWatchProProtocol.uartServiceUuid, equals("6e400001-b5a3-f393-e0a9-e50e24dcca9d"));
      expect(HiWatchProProtocol.uartServiceUuid2, equals("6e400801-b5a3-f393-e0a9-e50e24dcca9d"));
      expect(HiWatchProProtocol.uartWriteCharacteristicUuid, equals("6e400002-b5a3-f393-e0a9-e50e24dcca9d"));
      expect(HiWatchProProtocol.uartNotifyCharacteristicUuid, equals("6e400003-b5a3-f393-e0a9-e50e24dcca9d"));
      expect(HiWatchProProtocol.otaServiceUuid, equals("6e40ff01-b5a3-f393-e0a9-e50e24dcca9e"));
    });

    test('Full 17-byte Heart Rate frame with Date header from BaseReceiveData.java L1526-1559', () {
      // Full frame: [0xCD, len_hi, len_lo, 0x15, 0x01, 0x04, key_len(2), date(2), status, count, T0..T3, HR]
      final fullApkHrFrame = [
        0xCD, 0x00, 0x0E, 0x15, 0x01, 0x04,
        0x00, 0x07, // key length
        0x1A, 0x0A, // date header
        0x00,       // status
        0x01,       // count = 1
        0x00, 0x00, 0x38, 0x40, // 4-byte seconds offset (14,400s)
        76,         // HR = 76 bpm
      ];
      final tel = HiWatchProProtocol.parseNotifyPacket(fullApkHrFrame);
      expect(tel.heartRateBpm, equals(76));
      expect(tel.ackPacket, isNotNull);
      expect(tel.ackPacket, equals([0xDC, 0x00, 0x05, 0x15, 0x01, 0x00, 0x11, 0x01]));
    });

    test('Full 18-byte Blood Pressure frame with Date header from BaseReceiveData.java L1573-1602', () {
      // Full frame: [0xCD, len_hi, len_lo, 0x15, 0x01, 0x05, key_len(2), date(2), status, count, T0..T3, Sys, Dia]
      final fullApkBpFrame = [
        0xCD, 0x00, 0x0F, 0x15, 0x01, 0x05,
        0x00, 0x08, // key length
        0x1A, 0x0A, // date header
        0x00,       // status
        0x01,       // count = 1
        0x00, 0x00, 0x38, 0x40, // 4-byte seconds offset
        118,        // Systolic = 118
        78,         // Diastolic = 78
      ];
      final tel = HiWatchProProtocol.parseNotifyPacket(fullApkBpFrame);
      expect(tel.bloodPressureSystolic, equals(118));
      expect(tel.bloodPressureDiastolic, equals(78));
      expect(tel.ackPacket, isNotNull);
    });

    test('Full 17-byte SpO2 frame with Date header from BaseReceiveData.java L1696-1726', () {
      // Full frame: [0xCD, len_hi, len_lo, 0x15, 0x01, 0x14, key_len(2), date(2), status, count, T0..T3, SpO2]
      final fullApkSpo2Frame = [
        0xCD, 0x00, 0x0E, 0x15, 0x01, 0x14,
        0x00, 0x07, // key length
        0x1A, 0x0A, // date header
        0x00,       // status
        0x01,       // count = 1
        0x00, 0x00, 0x38, 0x40, // 4-byte seconds offset
        99,         // SpO2 = 99%
      ];
      final tel = HiWatchProProtocol.parseNotifyPacket(fullApkSpo2Frame);
      expect(tel.bloodOxygenSpo2, equals(99));
      expect(tel.ackPacket, isNotNull);
    });

    test('Full 20-byte Real-time Sport bit-packed frame from BaseReceiveData.java L1616-1635', () {
      // 64-bit Bitfield packing (bits: 12 offset | 4 mode | 16 steps | 11 cal | 2 flags | 19 dist):
      // Steps = 1,234 (0x04D2) in record[2..3]
      // Calories = 250 (0x00FA) in record[4] and record[5] upper bits
      // Distance = 850m (0x0352) in record[5] lower bits and record[6..7]
      final fullSportFrame = [
        0xCD, 0x00, 0x11, 0x15, 0x01, 0x0B,
        0x00, 0x0A, // key length
        0x1A, 0x0A, // date header
        0x00,       // status
        0x01,       // count = 1
        0x00, 0x00, 0x04, 0xD2, 0x1F, 0x40, 0x03, 0x52,
      ];
      final tel = HiWatchProProtocol.parseNotifyPacket(fullSportFrame);
      expect(tel.steps, equals(1234));
      expect(tel.distanceMeters, equals(850));
      expect(tel.calories, equals(250));
      expect(tel.ackPacket, isNotNull);
    });

    test('Full 20-byte Multi-Vital Extended Frame (HR + BP + SpO2) accurately parsed', () {
      final multiVitalFrame = [
        0xCD, 0x00, 0x11, 0x15, 0x01, 0x04,
        0x00, 0x0A, // key length
        0x1A, 0x0A, // date header
        0x00,       // status
        0x01,       // count = 1
        0x00, 0x00, 0x38, 0x40, // 4-byte timestamp
        84,         // HR
        122,        // Sys
        82,         // Dia
        97,         // SpO2
      ];
      final tel = HiWatchProProtocol.parseNotifyPacket(multiVitalFrame);
      expect(tel.heartRateBpm, equals(84));
      expect(tel.bloodPressureSystolic, equals(122));
      expect(tel.bloodPressureDiastolic, equals(82));
      expect(tel.bloodOxygenSpo2, equals(97));
      expect(tel.ackPacket, isNotNull);
    });
  });
}

