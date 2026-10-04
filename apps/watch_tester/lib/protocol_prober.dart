import 'dart:math';

/// Log categories for color-coded sniffer output
enum LogType { info, tx, rx, match, error }

/// Represents an event or packet log in the Watch Prober
class LogEntry {
  final DateTime timestamp;
  final LogType type;
  final String message;
  final List<int>? rawBytes;

  LogEntry({
    required this.type,
    required this.message,
    this.rawBytes,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get formattedTime =>
      "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}.${timestamp.millisecond.toString().padLeft(3, '0')}";
}

/// State of a protocol combination during testing
enum CombinationState { idle, testing, passed, failed }

/// Definition of a smartwatch hardware protocol candidate
class ProtocolCombination {
  final String id;
  final String name;
  final String chipFamily;
  final String targetServiceHint;
  final String targetWriteHint;
  final String targetNotifyHint;
  final List<int> handshakePacket;
  final List<int> hrTriggerPacket;
  final List<int> stepQueryPacket;
  final List<int> vibratePacket;
  CombinationState state;
  String? matchDetails;
  int? parsedHr;
  int? parsedSteps;

  ProtocolCombination({
    required this.id,
    required this.name,
    required this.chipFamily,
    required this.targetServiceHint,
    required this.targetWriteHint,
    required this.targetNotifyHint,
    required this.handshakePacket,
    required this.hrTriggerPacket,
    required this.stepQueryPacket,
    required this.vibratePacket,
    this.state = CombinationState.idle,
    this.matchDetails,
    this.parsedHr,
    this.parsedSteps,
  });
}

/// Structured vitals extracted from a BLE packet
class ParsedPacketData {
  final int? heartRate;
  final int? systolic;
  final int? diastolic;
  final int? spo2;
  final int? steps;
  final List<int>? autoAck;
  final List<String> annotations;

  const ParsedPacketData({
    this.heartRate,
    this.systolic,
    this.diastolic,
    this.spo2,
    this.steps,
    this.autoAck,
    this.annotations = const [],
  });

  bool get hasVitals =>
      heartRate != null || systolic != null || diastolic != null || spo2 != null || steps != null;
}

/// GATT Service summary descriptor for reports
class GattServiceDescriptor {
  final String serviceUuid;
  final List<GattCharDescriptor> characteristics;

  GattServiceDescriptor({
    required this.serviceUuid,
    required this.characteristics,
  });
}

/// GATT Characteristic descriptor for reports
class GattCharDescriptor {
  final String charUuid;
  final List<String> properties;

  GattCharDescriptor({
    required this.charUuid,
    required this.properties,
  });
}

/// Library of 8 verified candidate protocols for low-cost smartwatches
class ProtocolPresetLibrary {
  static List<ProtocolCombination> getPresetCombinations({DateTime? referenceTime}) {
    final now = referenceTime ?? DateTime.now();

    final hiWatchRtc = [
      0xCD, 0x00, 0x0C, 0x12, 0x01, 0x01, 0x00, 0x07,
      (now.year >> 8) & 0xFF, now.year & 0xFF, now.month, now.day, now.hour, now.minute, now.second, 0x00
    ];

    return [
      ProtocolCombination(
        id: 'comb_hiwatch_official',
        name: 'Comb 1: HiWatch Pro Official (0xCD Key 0x12)',
        chipFamily: 'Beken / JL AC6954 (HiWatch Pro APK)',
        targetServiceHint: '6e40',
        targetWriteHint: '6e400002',
        targetNotifyHint: '6e400003',
        handshakePacket: [0xCD, 0x00, 0x06, 0x12, 0x01, 0x0A, 0x00, 0x01, 0x02],
        hrTriggerPacket: [0xCD, 0x00, 0x06, 0x12, 0x01, 0x0D, 0x00, 0x01, 0x01],
        stepQueryPacket: [0xCD, 0x00, 0x06, 0x12, 0x01, 0x06, 0x00, 0x01, 0x01],
        vibratePacket: [0xCD, 0x00, 0x06, 0x12, 0x01, 0x04, 0x00, 0x01, 0x01],
      ),
      ProtocolCombination(
        id: 'comb_fitpro_sport',
        name: 'Comb 2: FitPro Sport Stream (0xCD Key 0x15)',
        chipFamily: 'FitPro BaseReceiveData (Key 0x0B/0x04)',
        targetServiceHint: '6e40',
        targetWriteHint: '6e400002',
        targetNotifyHint: '6e400003',
        handshakePacket: [0xCD, 0x00, 0x06, 0x12, 0x01, 0x07, 0x00, 0x01, 0x01],
        hrTriggerPacket: [0xCD, 0x00, 0x06, 0x15, 0x01, 0x04, 0x00, 0x01, 0x01],
        stepQueryPacket: [0xCD, 0x00, 0x06, 0x15, 0x01, 0x0C, 0x00, 0x01, 0x01],
        vibratePacket: [0xCD, 0x00, 0x06, 0x12, 0x01, 0x04, 0x00, 0x01, 0x01],
      ),
      ProtocolCombination(
        id: 'comb_ota_chars',
        name: 'Comb 3: Beken/Telink OTA UUIDs (FF01/FF02)',
        chipFamily: 'Beken BK3431 / Telink TLSR8266',
        targetServiceHint: 'ff01',
        targetWriteHint: 'ff02',
        targetNotifyHint: 'ff03',
        handshakePacket: [0xCD, 0x00, 0x06, 0x12, 0x01, 0x0A, 0x00, 0x01, 0x02],
        hrTriggerPacket: [0xCD, 0x00, 0x06, 0x12, 0x01, 0x0D, 0x00, 0x01, 0x01],
        stepQueryPacket: [0xCD, 0x00, 0x06, 0x12, 0x01, 0x06, 0x00, 0x01, 0x01],
        vibratePacket: [0xCD, 0x00, 0x06, 0x12, 0x01, 0x04, 0x00, 0x01, 0x01],
      ),
      ProtocolCombination(
        id: 'comb_dafit_shenzhen',
        name: 'Comb 4: DaFit / Shenzhen 0xAB Protocol',
        chipFamily: 'MoYoung / NRF52832 DaFit',
        targetServiceHint: 'fee7',
        targetWriteHint: 'fee1',
        targetNotifyHint: 'fee2',
        handshakePacket: [0xAB, 0x00, 0x04, 0xFF, 0x00, 0x00, 0xAB],
        hrTriggerPacket: [0xAB, 0x09, 0x54, 0x63],
        stepQueryPacket: [0xAB, 0x51, 0x00, 0x0A, 0x00, 0x00, 0x64],
        vibratePacket: [0xAB, 0x03, 0x01, 0xAB],
      ),
      ProtocolCombination(
        id: 'comb_hryfine',
        name: 'Comb 5: HryFine / Y95 Protocol (0xCD Big-Endian)',
        chipFamily: 'HryFine Smartwatch',
        targetServiceHint: '6e400001',
        targetWriteHint: '6e400002',
        targetNotifyHint: '6e400003',
        handshakePacket: [0xCD, 0x00, 0x07, 0x00, 0x00, 0x12, 0x34, 0x00, 0xC8, 0x0E, 0x10],
        hrTriggerPacket: [0xCD, 0x00, 0x09, 0x00, 0x4E, 0x62],
        stepQueryPacket: [0xCD, 0x00, 0x07, 0x00, 0x00, 0x12, 0x34, 0x00, 0xC8, 0x0E, 0x10],
        vibratePacket: [0xCD, 0x00, 0x06, 0x12, 0x01, 0x04, 0x00, 0x01, 0x01],
      ),
      ProtocolCombination(
        id: 'comb_ble_sig',
        name: 'Comb 6: Standard Bluetooth SIG (0x180D/0x2A37)',
        chipFamily: 'Standard Bluetooth SIG Heart Rate',
        targetServiceHint: '180d',
        targetWriteHint: '2a39',
        targetNotifyHint: '2a37',
        handshakePacket: [0x00],
        hrTriggerPacket: [0x01],
        stepQueryPacket: [0x00],
        vibratePacket: [0xCD, 0x00, 0x06, 0x12, 0x01, 0x04, 0x00, 0x01, 0x01],
      ),
      ProtocolCombination(
        id: 'comb_rtc_sync',
        name: 'Comb 7: Direct RTC Clock Synchronization',
        chipFamily: 'Universal Chinese Watch RTC',
        targetServiceHint: '6e400001',
        targetWriteHint: '6e400002',
        targetNotifyHint: '6e400003',
        handshakePacket: hiWatchRtc,
        hrTriggerPacket: [0xCD, 0x00, 0x06, 0x12, 0x01, 0x0D, 0x00, 0x01, 0x01],
        stepQueryPacket: [0xCD, 0x00, 0x06, 0x12, 0x01, 0x06, 0x00, 0x01, 0x01],
        vibratePacket: [0xCD, 0x00, 0x06, 0x12, 0x01, 0x04, 0x00, 0x01, 0x01],
      ),
      ProtocolCombination(
        id: 'comb_keepalive_ping',
        name: 'Comb 8: Vendor Wakeup Ping & Keepalive',
        chipFamily: 'Generic FitPro Sleep Wakeup',
        targetServiceHint: '6e400001',
        targetWriteHint: '6e400002',
        targetNotifyHint: '6e400003',
        handshakePacket: [0x68, 0x00, 0x01, 0x01, 0x68],
        hrTriggerPacket: [0xCD, 0x00, 0x06, 0x12, 0x01, 0x0D, 0x00, 0x01, 0x01],
        stepQueryPacket: [0xCD, 0x00, 0x06, 0x12, 0x01, 0x06, 0x00, 0x01, 0x01],
        vibratePacket: [0xCD, 0x00, 0x06, 0x12, 0x01, 0x04, 0x00, 0x01, 0x01],
      ),
    ];
  }
}

/// Raw byte packet decoder and Auto-ACK engine
class WatchPacketParser {
  /// Parses raw byte packets from any smartwatch GATT notification
  static ParsedPacketData parse(List<int> bytes) {
    if (bytes.isEmpty) {
      return const ParsedPacketData();
    }

    int? hr;
    int? sys;
    int? dia;
    int? spo2;
    int? steps;
    List<int>? autoAck;
    final annotations = <String>[];

    final header = bytes[0];

    // 1. Standard Bluetooth SIG Heart Rate (0x2A37)
    // Bits 5..7 reserved (MUST be 0). Byte 1 is HR (or bytes 1..2 if 16-bit).
    if ((header & 0xE0) == 0 &&
        header != 0x02 &&
        header != 0x04 &&
        !(header == 0x01 && bytes.length >= 5) &&
        bytes.length >= 2 &&
        bytes.length <= 8) {
      final is16Bit = (header & 0x01) != 0;
      final val = is16Bit && bytes.length >= 3 ? (bytes[1] | (bytes[2] << 8)) : bytes[1];
      if (val >= 35 && val <= 220) {
        hr = val;
      }
    }

    // 2. HiWatch / FitPro protocol (0xCD)
    if (header == 0xCD) {
      // 2A. TLV packed vitals (Key 0x04)
      if (bytes.length >= 17 && bytes[4] == 0x01 && bytes[5] == 0x04) {
        final val = bytes[16];
        if (val >= 35 && val <= 220) hr = val;
        if (bytes.length >= 20) {
          final s = bytes[17];
          final d = bytes[18];
          final sp = bytes[19];
          if (s >= 50 && s <= 250 && d >= 30 && d <= 150) {
            sys = max(s, d);
            dia = min(s, d);
          }
          if (sp >= 70 && sp <= 100) spo2 = sp;
        }
      }
      // 2B. Direct BP packet (Key 0x05)
      else if (bytes.length >= 18 && bytes[5] == 0x05) {
        final v1 = bytes[16];
        final v2 = bytes[17];
        if (v1 >= 30 && v1 <= 250 && v2 >= 30 && v2 <= 250) {
          sys = max(v1, v2);
          dia = min(v1, v2);
        }
      }
      // 2C. Step count packet (Key 0x02 Sport Record Detail or Key 0x0B Live Steps)
      else if (bytes.length >= 14 && bytes[5] == 0x02) {
        // Ultra2 / FitPro Sport detail record: record at bytes 12..19 (steps in 12..13)
        final s = (bytes[12] << 8) | bytes[13];
        if (s > 0 && s <= 100000) steps = s;
      } else if (bytes.length >= 20 && bytes[5] == 0x0B) {
        steps = (bytes[14] << 8) | bytes[15];
      }

      // 2D. Auto-ACK generation for HiWatch
      if (bytes.length >= 4) {
        final ackCmd = bytes[3];
        autoAck = [0xDC, 0x00, 0x05, ackCmd, 0x01, 0x00, 0x10, 0x01];
        annotations.add("🔄 ACK SENT (0x${ackCmd.toRadixString(16).padLeft(2, '0').toUpperCase()})");
      }
    }

    // 3. DaFit / Shenzhen protocol (0xAB)
    if (header == 0xAB) {
      if (bytes.length >= 4 && bytes[1] == 0x09) {
        final val = bytes[3];
        if (val >= 35 && val <= 220) hr = val;
      } else if (bytes.length >= 7 && bytes[1] == 0x51) {
        steps = (bytes[4] << 8) | bytes[5];
      }
    }

    // Assemble user-readable annotations
    if (hr != null) annotations.add("❤️ PULSE: $hr BPM");
    if (sys != null && dia != null) annotations.add("🩺 BP: $sys/$dia mmHg");
    if (spo2 != null) annotations.add("🫁 SpO2: $spo2%");
    if (steps != null && steps > 0) annotations.add("🚶 STEPS: $steps");

    return ParsedPacketData(
      heartRate: hr,
      systolic: sys,
      diastolic: dia,
      spo2: spo2,
      steps: steps,
      autoAck: autoAck,
      annotations: annotations,
    );
  }
}

/// Diagnostic report builder for easy sharing back to Vyra developers
class WatchReportGenerator {
  static String generate({
    String? deviceName,
    String? deviceMac,
    ProtocolCombination? winningCombination,
    String? workingWriteChar,
    String? workingNotifyChar,
    int? liveHeartRate,
    int? liveSystolic,
    int? liveDiastolic,
    int? liveSpo2,
    int? liveSteps,
    List<GattServiceDescriptor> discoveredServices = const [],
    List<LogEntry> logs = const [],
  }) {
    final sb = StringBuffer();
    sb.writeln("═════════════════════════════════════════════════════════════");
    sb.writeln("⚡ VYRA SMARTWATCH HARDWARE VERIFICATION & PROTOCOL REPORT");
    sb.writeln("Generated: ${DateTime.now().toIso8601String()}");
    sb.writeln("═════════════════════════════════════════════════════════════\n");

    sb.writeln("📱 PHYSICAL WATCH IDENTIFIER:");
    if (deviceName != null || deviceMac != null) {
      sb.writeln("  - Platform Name: ${deviceName ?? 'Unknown'}");
      sb.writeln("  - Bluetooth Remote ID / MAC: ${deviceMac ?? 'Unknown'}");
    } else {
      sb.writeln("  - Status: Not connected during export");
    }

    sb.writeln("\n🏆 WINNING HARDWARE COMBINATION:");
    if (winningCombination != null) {
      sb.writeln("  - Combination Name: ${winningCombination.name}");
      sb.writeln("  - Chipset / Architecture: ${winningCombination.chipFamily}");
      sb.writeln("  - Working Write Char: ${workingWriteChar ?? 'Not specified'}");
      sb.writeln("  - Working Notify Char: ${workingNotifyChar ?? 'Not specified'}");
      sb.writeln("  - Match Evidence: ${winningCombination.matchDetails ?? 'Responded to handshake'}");
    } else {
      sb.writeln("  - No single auto-combination matched. Inspect raw logs below.");
    }

    sb.writeln("\n📊 VERIFIED LIVE TELEMETRY:");
    sb.writeln("  - Pulse: ${liveHeartRate != null ? '$liveHeartRate BPM (VERIFIED)' : 'Not verified'}");
    sb.writeln("  - Blood Pressure: ${liveSystolic != null ? '$liveSystolic/$liveDiastolic mmHg (VERIFIED)' : 'Not verified'}");
    sb.writeln("  - Oxygen SpO2: ${liveSpo2 != null ? '$liveSpo2% (VERIFIED)' : 'Not verified'}");
    sb.writeln("  - Steps: ${liveSteps != null ? '$liveSteps (VERIFIED)' : 'Not verified'}");

    sb.writeln("\n🔍 DISCOVERED GATT ARCHITECTURE:");
    if (discoveredServices.isEmpty) {
      sb.writeln("  (No GATT services captured)");
    } else {
      for (var s in discoveredServices) {
        sb.writeln("  ├─ Service: ${s.serviceUuid}");
        for (var c in s.characteristics) {
          sb.writeln("  │   └─ Char: ${c.charUuid} [${c.properties.join(', ')}]");
        }
      }
    }

    sb.writeln("\n📜 LAST 30 CAPTURED PACKETS (TX / RX):");
    final slice = logs.length > 30 ? logs.sublist(logs.length - 30) : logs;
    if (slice.isEmpty) {
      sb.writeln("  (No packets captured)");
    } else {
      for (var l in slice) {
        sb.writeln("  [${l.formattedTime}] ${l.message}");
      }
    }

    sb.writeln("\n═════════════════════════════════════════════════════════════");
    sb.writeln("END OF REPORT — Share this report with Antigravity to lock in setup");
    sb.writeln("═════════════════════════════════════════════════════════════");
    return sb.toString();
  }
}
