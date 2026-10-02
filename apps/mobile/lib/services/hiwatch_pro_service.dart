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

  /// Return ACK command sent back to the watch upon receiving notify data
  /// Reverse-engineered directly from `SendData.getReturnAck(key, seq)` in `xfkj.fitpro`
  static List<int> buildReturnAckCommand(int key, int seq0, int seq1) {
    return [0xDC, 0x00, 0x05, key & 0xFF, 0x01, seq0 & 0xFF, seq1 & 0xFF, 0x01];
  }

  /// Command to turn on real-time continuous step streaming
  /// Reverse-engineered from `SendData.getTurnOnRealTimeStep(true)`:
  /// `SwitchProtocol(0x15, 0x06, 0x01)`
  static List<int> buildTurnOnRealTimeStepCommand() {
    return [0xCD, 0x00, 0x06, 0x15, 0x01, 0x06, 0x00, 0x01, 0x01];
  }

  /// Command to query full day sport summary (from SendData.getSportKeyDayGet(true)):
  /// `SwitchProtocol(0x15, 0x0D, 0x01)`
  static List<int> buildSportKeyDayGetCommand() {
    return [0xCD, 0x00, 0x06, 0x15, 0x01, 0x0D, 0x00, 0x01, 0x01];
  }

  /// Command to query live sport metrics (from SendData.getSportKeyGet(true)):
  /// `SwitchProtocol(0x15, 0x01, 0x01)`
  static List<int> buildSportKeyGetCommand() {
    return [0xCD, 0x00, 0x06, 0x15, 0x01, 0x01, 0x00, 0x01, 0x01];
  }

  /// Command to request current total step and calorie count immediately
  static List<int> buildRequestLiveMetricsCommand() {
    return [0xCD, 0x00, 0x06, 0x15, 0x01, 0x06, 0x00, 0x01, 0x01];
  }

  /// Command to trigger real-time Heart Rate & SpO2 measurement
  /// Reverse-engineered from `SendData.getSportMeasureHeartRecive(true)`:
  /// `getProtocol(0x12, 0x24, [0x00, 0x01])`
  static List<int> buildStartHeartRateMeasureCommand() {
    return [0xCD, 0x00, 0x04, 0x12, 0x24, 0x00, 0x01];
  }

  /// Secondary measurement trigger command for older FitPro variants
  static List<int> buildLegacyHeartRateMeasureCommand() =>
      [0xCD, 0x00, 0x03, 0x12, 0x01, 0x01];

  /// Command to negotiate BLE pairing (from SendData.getPair())
  static List<int> buildPairCommand() {
    return [0xCD, 0x00, 0x06, 0x12, 0x01, 0x0A, 0x00, 0x01, 0x02];
  }

  /// Command to confirm bonding / binding status (from SendData.getIsBingding(true))
  static List<int> buildIsBindingCommand() {
    return [0xCD, 0x00, 0x02, 0x13, 0x01];
  }

  /// Universal query command for DaFit / HryFine clone chipsets
  static List<int> buildDaFitStepQueryCommand() =>
      [0xAB, 0x00, 0x04, 0xFF, 0x50, 0x00, 0x00];

  /// Periodic Heartbeat keep-alive command to prevent watch from closing GATT notify stream
  static List<int> buildUniversalHeartbeatCommand() =>
      [0xAB, 0x00, 0x04, 0xFF, 0x56, 0x00, 0x00];

  /// Command to vibrate / find the watch (from SDKCmdMannager.findWatch)
  static List<int> buildFindWatchCommand() {
    return [0xCD, 0x00, 0x04, 0x08, 0x01];
  }

  /// Command to synchronize date and time to the watch (from SDKCmdMannager.synchronTime)
  static List<int> buildSyncTimeCommand([DateTime? dt]) {
    final now = dt ?? DateTime.now();
    return [0xAB, 0x00, 0x08, 0xFF, 0x92,
      now.year - 2000, now.month, now.day,
      now.hour, now.minute, now.second];
  }

  // ─── Packet Parsers ────────────────────────────────────────────────────────
  
  /// Parses raw byte packets received on notify characteristic
  static HiWatchTelemetryData parseNotifyPacket(List<int> bytes) {
    if (bytes.isEmpty) {
      return HiWatchTelemetryData.empty();
    }

    // ignore: avoid_print
    print('[WATCH-RAW] ${bytes.length}B: ${bytes.map((b) => '0x${b.toRadixString(16).padLeft(2,'0').toUpperCase()}').join(' ')}');

    final header = bytes[0];

    // 1. Standard Bluetooth SIG Heart Rate Measurement (UUID 0x2A37)
    //    Only applies when header is NOT a known HiWatch/DaFit command byte.
    if (header != 0xCD && header != 0xDC && header != 0xAB && header != 0xAA &&
        header != 0x02 && header != 0x04 && bytes.length >= 2) {
      final flags = bytes[0];
      final is16Bit = (flags & 0x01) != 0;
      final hr = is16Bit && bytes.length >= 3 ? (bytes[1] | (bytes[2] << 8)) : bytes[1];
      if (hr >= 40 && hr <= 200) {
        return HiWatchTelemetryData(heartRateBpm: hr);
      }
      return HiWatchTelemetryData.empty();
    }

    // 2. HiWatch / FitPro protocol (0xCD ...)
    if (header == 0xCD && bytes.length >= 4) {
      // Build automatic ACK packet so watch continues continuous streaming
      final ackKey = bytes.length > 3 ? bytes[3] : 0x01;
      final ackSeq0 = bytes.length > 4 ? bytes[4] : 0x00;
      final ackSeq1 = bytes.length > 5 ? bytes[5] : 0x00;
      final ack = buildReturnAckCommand(ackKey, ackSeq0, ackSeq1);

      final cmdType = bytes[2];
      final subCmd = bytes[3];

      // A. StrappedEquipment Real-Time Telemetry Stream (0x15)
      if (cmdType == 0x15 || subCmd == 0x15) {
        int steps = 0;
        int? kcal;
        int? distMeters;

        if (bytes.length >= 7) {
          steps = (bytes[4] << 16) | (bytes[5] << 8) | bytes[6];
        }
        if (steps == 0 && bytes.length >= 9) {
          steps = (bytes[6] << 16) | (bytes[7] << 8) | bytes[8];
        }

        if (bytes.length >= 9) {
          kcal = (bytes[7] << 8) | bytes[8];
        }
        if (bytes.length >= 11) {
          distMeters = (bytes[9] << 8) | bytes[10];
        }

        return HiWatchTelemetryData(
          steps: steps > 0 ? steps : null,
          calories: kcal,
          distanceMeters: distMeters,
          ackPacket: ack,
        );
      }

      // B. Sport & Health Measurement (0x12 / 0x09)
      if (cmdType == 0x12 || subCmd == 0x12 || cmdType == 0x09 || subCmd == 0x09) {
        int? hr;
        int? spo2;
        int? steps;
        int? kcal;

        // Check if day summary data packet
        if (bytes.length >= 8 && (subCmd == 0x06 || subCmd == 0x0D || subCmd == 0x11)) {
          steps = (bytes[4] << 16) | (bytes[5] << 8) | bytes[6];
          if (steps == 0 && bytes.length >= 9) {
            steps = (bytes[5] << 16) | (bytes[6] << 8) | bytes[7];
          }
          if (bytes.length >= 10) {
            kcal = (bytes[8] << 8) | bytes[9];
          }
        }

        // Scan payload for valid HR (40-200) and SpO2 (75-100)
        for (int i = 4; i < bytes.length; i++) {
          final val = bytes[i];
          if (hr == null && val >= 40 && val <= 200) {
            hr = val;
          } else if (spo2 == null && val >= 75 && val <= 100) {
            spo2 = val;
          }
        }

        return HiWatchTelemetryData(
          heartRateBpm: hr,
          bloodOxygenSpo2: spo2,
          steps: steps != null && steps > 0 ? steps : null,
          calories: kcal,
          ackPacket: ack,
        );
      }

      // C. Legacy Step data packet (cmdType 0x07 / 0x08)
      if ((cmdType == 0x07 || cmdType == 0x08) && bytes.length >= 7) {
        final steps = (bytes[4] << 16) | (bytes[5] << 8) | bytes[6];
        final kcal = bytes.length >= 9 ? (bytes[7] << 8) | bytes[8] : (steps * 0.04).round();
        final distMeters = bytes.length >= 11 ? (bytes[9] << 8) | bytes[10] : (steps * 0.75).round();
        return HiWatchTelemetryData(
          steps: steps,
          calories: kcal,
          distanceMeters: distMeters,
          ackPacket: ack,
        );
      }

      // Return ack so watch stream continues even on unknown packet IDs
      return HiWatchTelemetryData(ackPacket: ack);
    }

    // 3. DaFit / Shenzhen protocol (0xAB or 0xAA)
    if ((header == 0xAB || header == 0xAA) && bytes.length >= 4) {
      final cmd = bytes[1];
      if ((cmd == 0x51 || cmd == 0x07 || cmd == 0x08) && bytes.length >= 5) {
        final steps = (bytes[2] << 16) | (bytes[3] << 8) | bytes[4];
        final kcal = bytes.length >= 7 ? (bytes[5] << 8) | bytes[6] : (steps * 0.04).round();
        return HiWatchTelemetryData(
          steps: steps > 0 ? steps : null,
          calories: kcal > 0 ? kcal : null,
        );
      } else if (cmd == 0x09 || cmd == 0x31) {
        final hr = bytes[2];
        final spo2 = bytes.length >= 4 ? bytes[3] : null;
        return HiWatchTelemetryData(
          heartRateBpm: (hr >= 40 && hr <= 200) ? hr : null,
          bloodOxygenSpo2: (spo2 != null && spo2 >= 75 && spo2 <= 100) ? spo2 : null,
        );
      }
      return HiWatchTelemetryData.empty();
    }

    // 4. Format [0x02, hr, spo2, ...] — used by some HiWatch FitPro variants
    if (header == 0x02 && bytes.length >= 3) {
      final hr = bytes[1];
      final spo2 = bytes[2];
      return HiWatchTelemetryData(
        heartRateBpm: (hr >= 40 && hr <= 200) ? hr : null,
        bloodOxygenSpo2: (spo2 >= 75 && spo2 <= 100) ? spo2 : null,
      );
    }

    // 5. Format [0x04, 0x00, hr, spo2] — HiWatch Ultra / Watch 8 Ultra variants
    if (header == 0x04 && bytes.length >= 4) {
      final hr = bytes[2];
      final spo2 = bytes[3];
      return HiWatchTelemetryData(
        heartRateBpm: (hr >= 40 && hr <= 200) ? hr : null,
        bloodOxygenSpo2: (spo2 >= 75 && spo2 <= 100) ? spo2 : null,
      );
    }

    // ── FORMAT: Single byte = raw heart rate ────────────────────────────────
    if (bytes.length == 1 && bytes[0] >= 40 && bytes[0] <= 220) {
      return HiWatchTelemetryData(heartRateBpm: bytes[0]);
    }

    // ── FORMAT: [0x04, 0x00, hr, spo2] ─────────────────────────────────────
    if (header == 0x04 && bytes.length >= 4) {
      final hr = bytes[2]; final spo2 = bytes[3];
      return HiWatchTelemetryData(
        heartRateBpm: (hr >= 40 && hr <= 220) ? hr : null,
        bloodOxygenSpo2: (spo2 >= 75 && spo2 <= 100) ? spo2 : null,
      );
    }

    // ── FORMAT: [0x02, hr, spo2, ...] ──────────────────────────────────────
    if (header == 0x02 && bytes.length >= 3) {
      final hr = bytes[1]; final spo2 = bytes[2];
      return HiWatchTelemetryData(
        heartRateBpm: (hr >= 40 && hr <= 220) ? hr : null,
        bloodOxygenSpo2: (spo2 >= 75 && spo2 <= 100) ? spo2 : null,
      );
    }

    // ── FORMAT: [hr, spo2, steps_hi, steps_lo] — Generic BLE watch ─────────
    if (bytes.length >= 4 && header >= 40 && header <= 220) {
      final possibleSpo2 = bytes[1];
      if (possibleSpo2 >= 75 && possibleSpo2 <= 100) {
        final steps = (bytes[2] << 8) | bytes[3];
        return HiWatchTelemetryData(
          heartRateBpm: header,
          bloodOxygenSpo2: possibleSpo2,
          steps: steps > 0 ? steps : null,
        );
      }
      return HiWatchTelemetryData(heartRateBpm: header);
    }

    // ── FORMAT: [0x01, len, 0x12, 0x24, hr, spo2] ──────────────────────────
    if (header == 0x01 && bytes.length >= 6 && bytes[2] == 0x12 && bytes[3] == 0x24) {
      final hr = bytes[4]; final spo2 = bytes[5];
      return HiWatchTelemetryData(
        heartRateBpm: (hr >= 40 && hr <= 220) ? hr : null,
        bloodOxygenSpo2: (spo2 >= 75 && spo2 <= 100) ? spo2 : null,
      );
    }

    // ── FORMAT: Broad scan — find HR/SpO2 anywhere ─────────────────────────
    if (bytes.length >= 3 && bytes.length <= 24) {
      int? foundHr; int? foundSpo2; int? foundSteps;
      for (int i = 0; i < bytes.length; i++) {
        final v = bytes[i];
        if (foundHr == null && v >= 45 && v <= 200) {
          foundHr = v;
        } else if (foundSpo2 == null && foundHr != null && v >= 85 && v <= 100) {
          foundSpo2 = v;
        }
      }
      if (bytes.length >= 6) {
        for (int i = 0; i <= bytes.length - 3; i++) {
          final s = (bytes[i] << 16) | (bytes[i+1] << 8) | bytes[i+2];
          if (s > 0 && s < 100000) { foundSteps = s; break; }
        }
      }
      if (foundHr != null) {
        return HiWatchTelemetryData(heartRateBpm: foundHr, bloodOxygenSpo2: foundSpo2, steps: foundSteps);
      }
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
  final List<int>? ackPacket;

  const HiWatchTelemetryData({
    this.steps,
    this.calories,
    this.distanceMeters,
    this.heartRateBpm,
    this.bloodOxygenSpo2,
    this.batteryLevel,
    this.ackPacket,
  });

  factory HiWatchTelemetryData.empty() => const HiWatchTelemetryData();

  bool get isEmpty =>
      steps == null &&
      calories == null &&
      heartRateBpm == null &&
      bloodOxygenSpo2 == null &&
      ackPacket == null;
}
