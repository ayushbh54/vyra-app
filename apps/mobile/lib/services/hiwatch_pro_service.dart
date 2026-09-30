/// HiWatch Pro & FitPro Smartwatch Protocol & Bluetooth LE Service
///
/// Reverse-engineered directly from `hiwatch pro/base.apk` (com.legend.hiwatchpro.app / xfkj.fitpro)
/// Chipset support: Realtek (RtkUpdateService), Beken (com.beken.beken_ota), YiChip, Telink.
class HiWatchProProtocol {
  // ─── BLE GATT Service & Characteristic UUIDs ───────────────────────────────
  
  /// Primary Nordic UART / FitPro Custom GATT Service UUID
  static const String serviceUuid = "6e40ff01-b5a3-f393-e0a9-e50e24dcca9e";

  /// Characteristic for sending commands to the watch (Write / Write Without Response)
  static const String writeCharacteristicUuid = "6e40ff02-b5a3-f393-e0a9-e50e24dcca9e";

  /// Characteristic for receiving responses & streaming data from the watch (Notify / Indicate)
  static const String notifyCharacteristicUuid = "6e40ff03-b5a3-f393-e0a9-e50e24dcca9e";

  /// Client Characteristic Configuration Descriptor (CCCD) to enable notifications (0x0001)
  static const String cccdDescriptorUuid = "00002902-0000-1000-8000-00805f9b34fb";

  /// Standard Bluetooth SIG Heart Rate Service (fallback)
  static const String standardHeartRateServiceUuid = "0000180d-0000-1000-8000-00805f9b34fb";
  static const String standardHeartRateMeasurementUuid = "00002a37-0000-1000-8000-00805f9b34fb";

  /// Standard Battery Service
  static const String standardBatteryServiceUuid = "0000180f-0000-1000-8000-00805f9b34fb";
  static const String standardBatteryLevelUuid = "00002a19-0000-1000-8000-00805f9b34fb";

  // ─── Recognized Bluetooth Advertised Names ──────────────────────────────────
  static const List<String> recognizedDeviceNames = [
    "HiWatch Pro",
    "HiWatchPro",
    "HiWatch Ultra",
    "HiWatchUltra",
    "HiWatch Plus",
    "FitPro",
    "T800 Ultra",
    "T800",
    "T500",
    "T55",
    "Watch 8 Ultra",
    "Watch 9 Ultra",
    "Watch8",
    "Watch9",
  ];

  // ─── Command Packet Builders (Header 0xCD 0x00 / 0xAB / 0xAA) ──────────────
  
  /// Command to turn on real-time continuous step streaming (from SendData.getTurnOnRealTimeStep)
  static List<int> buildTurnOnRealTimeStepCommand() {
    return [0xCD, 0x00, 0x07, 0x07, 0x01, 0x00, 0x00, 0x00, 0x00];
  }

  /// Command to request current total step and calorie count immediately
  static List<int> buildRequestLiveMetricsCommand() {
    return [0xCD, 0x00, 0x04, 0x07, 0x01];
  }

  /// Command to trigger real-time Heart Rate & SpO2 measurement (from SendData.getSportMeasureHeartRecive)
  static List<int> buildStartHeartRateMeasureCommand() {
    return [0xCD, 0x00, 0x05, 0x09, 0x01, 0x01];
  }

  /// Universal query command for DaFit / HryFine clone chipsets
  static List<int> buildDaFitStepQueryCommand() {
    return [0xAB, 0x00, 0x04, 0xFF, 0x31];
  }

  /// Periodic Heartbeat keep-alive command to prevent watch from closing GATT notify stream
  static List<int> buildUniversalHeartbeatCommand() {
    return [0xCD, 0x00, 0x03, 0x01];
  }

  /// Command to vibrate / find the watch (from SDKCmdMannager.findWatch)
  static List<int> buildFindWatchCommand() {
    return [0xCD, 0x00, 0x04, 0x08, 0x01];
  }

  /// Command to synchronize date and time to the watch (from SDKCmdMannager.synchronTime)
  static List<int> buildSyncTimeCommand([DateTime? dt]) {
    final now = dt ?? DateTime.now();
    return [
      0xCD,
      0x00,
      0x09,
      0x01,
      now.year % 100,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
    ];
  }

  // ─── Packet Parsers ────────────────────────────────────────────────────────
  
  /// Parses raw byte packets received on notify characteristic
  static HiWatchTelemetryData parseNotifyPacket(List<int> bytes) {
    if (bytes.length < 2) {
      return HiWatchTelemetryData.empty();
    }

    final header = bytes[0];

    // 1. Standard Bluetooth SIG Heart Rate Measurement (UUID 0x2A37)
    if (header != 0xCD && header != 0xAB && header != 0xAA && bytes.length >= 2) {
      final flags = bytes[0];
      final is16Bit = (flags & 0x01) != 0;
      final hr = is16Bit && bytes.length >= 3 ? (bytes[1] | (bytes[2] << 8)) : bytes[1];
      if (hr > 35 && hr < 235) {
        return HiWatchTelemetryData(heartRateBpm: hr);
      }
    }

    // 2. HiWatch / FitPro protocol (0xCD 0x00 ...)
    if (header == 0xCD && bytes.length >= 4) {
      final cmdType = bytes[2];

      // Step data packet (cmdType 0x07 / 0x08)
      if ((cmdType == 0x07 || cmdType == 0x08) && bytes.length >= 7) {
        final steps = (bytes[4] << 16) | (bytes[5] << 8) | bytes[6];
        final kcal = bytes.length >= 9 ? (bytes[7] << 8) | bytes[8] : (steps * 0.04).round();
        final distMeters = bytes.length >= 11 ? (bytes[9] << 8) | bytes[10] : (steps * 0.75).round();
        return HiWatchTelemetryData(
          steps: steps,
          calories: kcal,
          distanceMeters: distMeters,
        );
      }

      // Heart Rate & Blood Oxygen packet (cmdType 0x09)
      if (cmdType == 0x09 && bytes.length >= 5) {
        final hr = bytes[4];
        final spo2 = bytes.length >= 6 ? bytes[5] : null;
        return HiWatchTelemetryData(
          heartRateBpm: (hr > 35 && hr < 225) ? hr : null,
          bloodOxygenSpo2: (spo2 != null && spo2 >= 75 && spo2 <= 100) ? spo2 : null,
        );
      }
    }

    // 3. DaFit / Shenzhen protocol (0xAB or 0xAA)
    if ((header == 0xAB || header == 0xAA) && bytes.length >= 4) {
      final cmd = bytes[1];
      if ((cmd == 0x51 || cmd == 0x07 || cmd == 0x08) && bytes.length >= 5) {
        // Steps packet
        final steps = (bytes[2] << 16) | (bytes[3] << 8) | bytes[4];
        final kcal = bytes.length >= 7 ? (bytes[5] << 8) | bytes[6] : (steps * 0.04).round();
        return HiWatchTelemetryData(
          steps: steps > 0 ? steps : null,
          calories: kcal > 0 ? kcal : null,
        );
      } else if (cmd == 0x09 || cmd == 0x31) {
        // HR packet
        final hr = bytes[2];
        final spo2 = bytes.length >= 4 ? bytes[3] : null;
        return HiWatchTelemetryData(
          heartRateBpm: (hr > 35 && hr < 225) ? hr : null,
          bloodOxygenSpo2: (spo2 != null && spo2 >= 75 && spo2 <= 100) ? spo2 : null,
        );
      }
    }

    // 4. Generic HR-first format (many Shenzhen BLE clones send [hr, spo2, ...])
    if (bytes.length >= 2 && header > 35 && header < 225) {
      final possibleSpo2 = bytes[1];
      if (possibleSpo2 >= 75 && possibleSpo2 <= 100) {
        return HiWatchTelemetryData(
          heartRateBpm: header,
          bloodOxygenSpo2: possibleSpo2,
        );
      }
      // HR only packet
      return HiWatchTelemetryData(heartRateBpm: header);
    }

    // 5. Format [0x02, hr, spo2, ...] — used by some HiWatch FitPro variants
    if (header == 0x02 && bytes.length >= 3) {
      final hr = bytes[1];
      final spo2 = bytes[2];
      return HiWatchTelemetryData(
        heartRateBpm: (hr > 35 && hr < 225) ? hr : null,
        bloodOxygenSpo2: (spo2 >= 75 && spo2 <= 100) ? spo2 : null,
      );
    }

    // 6. Format [0x04, 0x00, hr, spo2] — HiWatch Ultra / Watch 8 Ultra variants
    if (header == 0x04 && bytes.length >= 4) {
      final hr = bytes[2];
      final spo2 = bytes[3];
      return HiWatchTelemetryData(
        heartRateBpm: (hr > 35 && hr < 225) ? hr : null,
        bloodOxygenSpo2: (spo2 >= 75 && spo2 <= 100) ? spo2 : null,
      );
    }

    return HiWatchTelemetryData.empty();
  }
}

/// Structured Telemetry Data from HiWatch Pro / Bluetooth LE Smartwatches
class HiWatchTelemetryData {
  final int? steps;
  final int? calories;
  final int? distanceMeters;
  final int? heartRateBpm;
  final int? bloodOxygenSpo2;
  final int? batteryLevel;

  const HiWatchTelemetryData({
    this.steps,
    this.calories,
    this.distanceMeters,
    this.heartRateBpm,
    this.bloodOxygenSpo2,
    this.batteryLevel,
  });

  factory HiWatchTelemetryData.empty() => const HiWatchTelemetryData();

  bool get isEmpty =>
      steps == null &&
      calories == null &&
      heartRateBpm == null &&
      bloodOxygenSpo2 == null;
}
