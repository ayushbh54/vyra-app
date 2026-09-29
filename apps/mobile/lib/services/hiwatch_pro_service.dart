
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

  // ─── Command Packet Builders (Header 0xCD 0x00 / 0xAB) ─────────────────────
  
  /// Command to turn on real-time continuous step streaming (from SendData.getTurnOnRealTimeStep)
  static List<int> buildTurnOnRealTimeStepCommand() {
    return [0xCD, 0x00, 0x07, 0x07, 0x01, 0x00, 0x00, 0x00, 0x00];
  }

  /// Command to trigger real-time Heart Rate & SpO2 measurement (from SendData.getSportMeasureHeartRecive)
  static List<int> buildStartHeartRateMeasureCommand() {
    return [0xCD, 0x00, 0x05, 0x09, 0x01, 0x01];
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
  
  /// Parses raw byte packets received on notify characteristic (6e40ff03)
  static HiWatchTelemetryData parseNotifyPacket(List<int> bytes) {
    if (bytes.length < 4) {
      return HiWatchTelemetryData.empty();
    }

    final header = bytes[0];
    // Standard Bluetooth SIG Heart Rate Measurement (UUID 0x2A37)
    if ((header != 0xCD && header != 0xAB) && bytes.length >= 2) {
      final flags = bytes[0];
      final is16Bit = (flags & 0x01) != 0;
      final hr = is16Bit && bytes.length >= 3 ? (bytes[1] | (bytes[2] << 8)) : bytes[1];
      if (hr > 30 && hr < 240) {
        return HiWatchTelemetryData(heartRateBpm: hr);
      }
    }

    // Check packet header
    if (header != 0xCD && header != 0xAB) {
      return HiWatchTelemetryData.empty();
    }

    final cmdType = bytes[2];

    // Step data packet (cmdType 0x07 / 0x08)
    if ((cmdType == 0x07 || cmdType == 0x08) && bytes.length >= 8) {
      final steps = (bytes[4] << 16) | (bytes[5] << 8) | bytes[6];
      final kcal = bytes.length >= 10 ? (bytes[7] << 8) | bytes[8] : (steps * 0.04).round();
      final distMeters = bytes.length >= 12 ? (bytes[9] << 8) | bytes[10] : (steps * 0.75).round();
      return HiWatchTelemetryData(
        steps: steps,
        calories: kcal,
        distanceMeters: distMeters,
      );
    }

    // Heart Rate & Blood Oxygen packet (cmdType 0x09)
    if (cmdType == 0x09 && bytes.length >= 6) {
      final hr = bytes[4];
      final spo2 = bytes.length >= 6 ? bytes[5] : 0;
      return HiWatchTelemetryData(
        heartRateBpm: (hr > 30 && hr < 220) ? hr : null,
        bloodOxygenSpo2: (spo2 >= 70 && spo2 <= 100) ? spo2 : null,
      );
    }

    return HiWatchTelemetryData.empty();
  }
}

/// Structured Telemetry Data from HiWatch Pro
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
