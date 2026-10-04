/// HiWatch Pro & FitPro Smartwatch Protocol & Bluetooth LE Service
///
/// Reverse-engineered directly from `hiwatch pro/base.apk` (com.legend.hiwatchpro.app / xfkj.fitpro)
/// Chipset support: Realtek (RtkUpdateService), Beken (com.beken.beken_ota), YiChip, Telink.
class HiWatchProProtocol {
  // ─── BLE GATT Service & Characteristic UUIDs ───────────────────────────────
  
  /// Official HiWatch Pro / FitPro Main UART Service UUIDs (Profile.uartServiceUUID / uartServiceUUID2)
  static const String uartServiceUuid = "6e400001-b5a3-f393-e0a9-e50e24dcca9d";
  static const String uartServiceUuid2 = "6e400801-b5a3-f393-e0a9-e50e24dcca9d";

  /// Official HiWatch Pro / FitPro Write Characteristic UUID (Profile.uartWriteCharacteristicUUID)
  static const String uartWriteCharacteristicUuid = "6e400002-b5a3-f393-e0a9-e50e24dcca9d";

  /// Official HiWatch Pro / FitPro Notify Characteristic UUID (Profile.uartNotifyCharacteristicUUID)
  static const String uartNotifyCharacteristicUuid = "6e400003-b5a3-f393-e0a9-e50e24dcca9d";

  /// OTA Firmware Service & Characteristic UUIDs (Profile.otaServiceUUID)
  static const String otaServiceUuid = "6e40ff01-b5a3-f393-e0a9-e50e24dcca9e";
  static const String otaWriteCharacteristicUuid = "6e40ff02-b5a3-f393-e0a9-e50e24dcca9e";
  static const String otaNotifyCharacteristicUuid = "6e40ff03-b5a3-f393-e0a9-e50e24dcca9e";

  /// Primary Nordic UART / FitPro Custom GATT Service UUID (fallback alias)
  static const String serviceUuid = otaServiceUuid;

  /// Characteristic for sending commands to the watch (Write / Write Without Response)
  static const String writeCharacteristicUuid = otaWriteCharacteristicUuid;

  /// Characteristic for receiving responses & streaming data from the watch (Notify / Indicate)
  static const String notifyCharacteristicUuid = otaNotifyCharacteristicUuid;

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
    "Ultra2",
    "Ultra 2",
    "Ultra",
    "T900 Ultra",
    "HK9 Pro",
    "DT900",
    "DT NO.1",
    "FK",
    "ID",
  ];

  // ─── Known Protocol Headers (prevents protocol bytes being misidentified as HR) ──
  static const Set<int> protocolHeaders = {
    0x00, // BLE SIG flags / NULL
    0x01, // ShenZhen / BLE SIG 16-bit
    0x02, // FitPro variant
    0x04, // FitPro variant
    0x4D, // TK protocol
    0x68, // GW / HK9
    0xAA, // DaFit / ShenZhen
    0xAB, // DaFit / ShenZhen
    0xBC, // Ultra2
    0xCD, // FitPro / HiWatch
    0xDC, // FitPro ACK
  };

  // ─── Command Packet Builders ─────────────────────────────────────────────────
  // ALL commands verified directly from decompiled SendData.java in HiWatchPro base.apk
  // SwitchProtocol(b, b2, b3) → [0xCD, 0x00, 0x06, b, 0x01, b2, 0x00, 0x01, b3]
  // getProtocol(b, b2, data)  → [0xCD, 0x00, (3+data.len), b, b2, ...data]

  /// ACK back to watch. Exact impl of SendData.getReturnAck(b, bArr):
  /// [0xDC, 0x00, 0x05, b, 0x01, bArr[0], bArr[1], 0x01]
  static List<int> buildReturnAckCommand(int key, int seq0, int seq1) {
    return [0xDC, 0x00, 0x05, key & 0xFF, 0x01, seq0 & 0xFF, seq1 & 0xFF, 0x01];
  }

  // ─── HEALTH MEASUREMENT COMMANDS (APK-verified) ────────────────────────────

  /// APK: getSportHeartRateRecive(true) = SwitchProtocol(0x12, 0x0D, 0x01)
  /// Enables continuous heart rate streaming from watch.
  static List<int> buildStartHeartRateMeasureCommand() =>
      [0xCD, 0x00, 0x06, 0x12, 0x01, 0x0D, 0x00, 0x01, 0x01];

  /// APK: getSportBloodRateRecive(true) = SwitchProtocol(0x12, 0x0E, 0x01)
  /// Enables blood pressure streaming from watch.
  static List<int> buildStartBloodPressureMeasureCommand() =>
      [0xCD, 0x00, 0x06, 0x12, 0x01, 0x0E, 0x00, 0x01, 0x01];

  /// APK: getSportMeasureRecive(true) = SwitchProtocol(0x12, 0x18, 0x01)
  /// Enables combined measure (HR + SpO2 + BP) streaming.
  static List<int> buildStartCombinedMeasureCommand() =>
      [0xCD, 0x00, 0x06, 0x12, 0x01, 0x18, 0x00, 0x01, 0x01];

  /// APK: getSportMeasureHeartRecive(true) = getProtocol(0x12, 0x24, [0x00, 0x01])
  /// Triggers single-shot heart rate measurement reading.
  static List<int> buildLegacyHeartRateMeasureCommand() =>
      [0xCD, 0x00, 0x07, 0x12, 0x01, 0x24, 0x00, 0x02, 0x00, 0x01];

  /// APK: getSportMeasureSpoRecive(true) = getProtocol(0x12, 0x24, [0x02, 0x01])
  /// Triggers SpO2 (blood oxygen) measurement reading.
  static List<int> buildSpO2MeasureCommand() =>
      [0xCD, 0x00, 0x07, 0x12, 0x01, 0x24, 0x00, 0x02, 0x02, 0x01];

  /// APK: getSportMeasureBloodRecive(true) = getProtocol(0x12, 0x24, [0x01, 0x01])
  /// Triggers blood pressure measurement reading.
  static List<int> buildBloodPressureMeasureCommand() =>
      [0xCD, 0x00, 0x07, 0x12, 0x01, 0x24, 0x00, 0x02, 0x01, 0x01];

  // ─── STEP / SPORT COMMANDS (APK-verified) ─────────────────────────────────

  /// APK: getTurnOnRealTimeStep(true) = SwitchProtocol(0x15, 0x06, 0x01)
  /// Enables real-time continuous step count streaming.
  static List<int> buildTurnOnRealTimeStepCommand() =>
      [0xCD, 0x00, 0x06, 0x15, 0x01, 0x06, 0x00, 0x01, 0x01];

  /// APK: getSportKeyGet(true) = SwitchProtocol(0x15, 0x01, 0x01)
  /// Requests live sport metrics (steps, calories, distance).
  static List<int> buildSportKeyGetCommand() =>
      [0xCD, 0x00, 0x06, 0x15, 0x01, 0x01, 0x00, 0x01, 0x01];

  /// APK: getSportKeyDayGet(true) = SwitchProtocol(0x15, 0x0D, 0x01)
  /// Requests full-day sport summary.
  static List<int> buildSportKeyDayGetCommand() =>
      [0xCD, 0x00, 0x06, 0x15, 0x01, 0x0D, 0x00, 0x01, 0x01];

  /// Alias for buildSportKeyGetCommand — used in periodic polling.
  static List<int> buildRequestLiveMetricsCommand() => buildSportKeyGetCommand();

  // ─── CONNECTION COMMANDS (APK-verified) ────────────────────────────────────

  /// APK: getPair() = SwitchProtocol(0x12, 0x0A, 0x02)
  static List<int> buildPairCommand() =>
      [0xCD, 0x00, 0x06, 0x12, 0x01, 0x0A, 0x00, 0x01, 0x02];

  /// APK: getIsBingding(true) = [0xCD, 0x00, 0x02, 0x13, 0x01]
  static List<int> buildIsBindingCommand() =>
      [0xCD, 0x00, 0x02, 0x13, 0x01];

  /// DaFit / HryFine clone chipset step query.
  static List<int> buildDaFitStepQueryCommand() =>
      [0xAB, 0x00, 0x04, 0xFF, 0x50, 0x00, 0x00];

  /// Periodic keep-alive heartbeat to prevent GATT notify stream closure.
  static List<int> buildUniversalHeartbeatCommand() =>
      [0xAB, 0x00, 0x04, 0xFF, 0x56, 0x00, 0x00];

  /// APK: getSetFindMeValue(true) = SwitchProtocol(0x12, 0x0B, 0x01) — vibrate watch
  static List<int> buildFindWatchCommand() =>
      [0xCD, 0x00, 0x06, 0x12, 0x01, 0x0B, 0x00, 0x01, 0x01];

  /// Official HiWatchPro / FitPro RTC time sync: SendData.getSetTimesValue()
  /// getProtocol(18, 1, tempBytes) where temp packs year-2000, month, day, hour, min, sec
  static List<int> buildHiWatchTimeSyncCommand([DateTime? dt]) {
    final now = dt ?? DateTime.now();
    final yearOffset = now.year - 2000;
    final temp = (now.second) |
        (now.minute << 6) |
        (now.hour << 12) |
        (now.day << 17) |
        (now.month << 22) |
        (yearOffset << 26);
    return [
      0xCD, 0x00, 0x09, 0x12, 0x01, 0x01, 0x00, 0x04,
      (temp >> 24) & 0xFF,
      (temp >> 16) & 0xFF,
      (temp >> 8) & 0xFF,
      temp & 0xFF,
    ];
  }

  /// Sync date/time to watch (DaFit / ShenZhen clone fallback).
  static List<int> buildSyncTimeCommand([DateTime? dt]) {
    final now = dt ?? DateTime.now();
    return [
      0xAB, 0x00, 0x08, 0xFF, 0x92,
      now.year - 2000, now.month, now.day,
      now.hour, now.minute, now.second,
    ];
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
    //    Per Bluetooth SIG spec, Flags byte bits 5..7 are reserved and MUST be 0 (flags & 0xE0 == 0).
    //    This guarantees vendor protocol headers (0xCD, 0xDC, 0xAB, 0xAA, 0xBC, 0x68, 0x4D) are never misclassified.
    if ((header & 0xE0) == 0 &&
        header != 0x02 &&
        header != 0x04 &&
        !(header == 0x01 && bytes.length >= 5) &&
        bytes.length >= 2 &&
        bytes.length <= 8) {
      final flags = bytes[0];
      final is16Bit = (flags & 0x01) != 0;
      final hr = is16Bit && bytes.length >= 3 ? (bytes[1] | (bytes[2] << 8)) : bytes[1];
      if (hr >= 40 && hr <= 200) {
        return HiWatchTelemetryData(heartRateBpm: hr);
      }
      // If not a valid SIG HR, fall through to vendor parsers
    }

    // 2. HiWatch / FitPro protocol (0xCD ...)
    if (header == 0xCD && bytes.length >= 4) {
      int cmdType = bytes[2];
      int subCmd = bytes.length > 3 ? bytes[3] : 0;
      int keyId = subCmd;
      List<int> payload = bytes.length > 4 ? bytes.sublist(4) : const [];
      bool isTlv = false;

      if (bytes[1] == 0x00 && bytes.length >= 5 &&
          (bytes[3] == 0x15 || bytes[3] == 0x12 || bytes[3] == 0x13 || bytes[3] == 0x1C)) {
        cmdType = bytes[3];
        // Check if TLV structure with keyCount (bytes[4]) and keyId (bytes[5]):
        // Typical for 0x15 (Sport) or 0x12 packed vitals with payload >= 8
        isTlv = bytes.length >= 6 &&
            (cmdType == 0x15 || (cmdType == 0x12 && bytes.length >= 14 && bytes[4] == 0x01));
        if (isTlv) {
          keyId = bytes[5];
          subCmd = bytes[5];
          payload = bytes.length > 6 ? bytes.sublist(6) : const [];
        } else {
          // Direct command structure: [0xCD, 0x00, len, cmd, subCmd, payload...]
          subCmd = bytes[4];
          keyId = bytes[4];
          payload = bytes.length > 5 ? bytes.sublist(5) : const [];
        }
      }

      // Build automatic ACK packet matching official BaseReceiveData.java / SendData.getReturnAck:
      // cmdType is bytes[3], bArr is 16-bit totalLen = (declaredLength + 3)
      final rawLen = bytes.length >= 3 ? ((bytes[1] << 8) | bytes[2]) : (bytes.length - 3);
      final totalLen = (rawLen > 0 ? rawLen : bytes.length - 3) + 3;
      final ackCmd = bytes.length > 3 ? bytes[3] : 0x15;
      final ackSeq0 = (totalLen >> 8) & 0xFF;
      final ackSeq1 = totalLen & 0xFF;
      final ack = buildReturnAckCommand(ackCmd, ackSeq0, ackSeq1);

      // A1. APK FitPro Packed Vitals (Key 0x04: HR, 0x05: BP, 0x14: SpO2)
      // Reverse-engineered from BaseReceiveData.Sport:
      // - Key 0x04 (HR): 5-byte records [T0..T3, HR] (or 8-byte multi-vital)
      // - Key 0x05 (BP): 6-byte records [T0..T3, Sys, Dia]
      // - Key 0x14 (SpO2): 5-byte records [T0..T3, SpO2]
      if (keyId == 0x04 || keyId == 0x05 || keyId == 0x14) {
        int? hr;
        int? sys;
        int? dia;
        int? spo2;

        // Check if full official HiWatch Pro APK frame where records start at bytes[12]:
        // [0xCD, len_hi, len_lo, 0x15, 0x01, keyId, key_len(2), date(2), status(1), count(1), record...]
        final isFullApkFrame = bytes.length >= 17 && bytes[4] == 0x01 && bytes[11] > 0;

        if (isFullApkFrame) {
          if (keyId == 0x04) {
            // Heart Rate record at bytes[12..16]: [T0..T3, HR]
            final rawHr = bytes[16];
            if (rawHr >= 35 && rawHr <= 220) hr = rawHr;
            // Check for extended multi-vital frame: [T0..T3, HR, Sys, Dia, SpO2]
            if (bytes.length >= 20) {
              final rawSys = bytes[17];
              final rawDia = bytes[18];
              final rawSpo2 = bytes[19];
              if (rawSys >= 60 && rawSys <= 220) sys = rawSys;
              if (rawDia >= 40 && rawDia <= 140) dia = rawDia;
              if (rawSpo2 >= 70 && rawSpo2 <= 100) spo2 = rawSpo2;
            }
          } else if (keyId == 0x05 && bytes.length >= 18) {
            // Blood Pressure record at bytes[12..17]: [T0..T3, Sys, Dia]
            final v1 = bytes[16];
            final v2 = bytes[17];
            final higher = v1 >= v2 ? v1 : v2;
            final lower = v1 < v2 ? v1 : v2;
            if (higher >= 60 && higher <= 220 && lower >= 40 && lower <= 140) {
              sys = higher;
              dia = lower;
            }
          } else if (keyId == 0x14) {
            // SpO2 record at bytes[12..16]: [T0..T3, SpO2]
            final rawSpo2 = bytes[16];
            if (rawSpo2 >= 70 && rawSpo2 <= 100) spo2 = rawSpo2;
          }
        } else {
          // Compact / shortened TLV frame without full 6-byte date/status header
          if (payload.length >= 8) {
            final rawHr = payload[4];
            final rawSys = payload[5];
            final rawDia = payload[6];
            final rawSpo2 = payload[7];
            if (rawHr >= 35 && rawHr <= 220) hr = rawHr;
            if (rawSys >= 60 && rawSys <= 220) sys = rawSys;
            if (rawDia >= 40 && rawDia <= 140) dia = rawDia;
            if (rawSpo2 >= 70 && rawSpo2 <= 100) spo2 = rawSpo2;
          } else if (keyId == 0x04 && payload.length >= 5) {
            final rawHr = payload[4];
            if (rawHr >= 35 && rawHr <= 220) hr = rawHr;
          } else if (keyId == 0x04 && payload.isNotEmpty) {
            final rawHr = payload[0];
            if (rawHr >= 35 && rawHr <= 220) hr = rawHr;
          } else if (keyId == 0x05 && payload.length >= 6) {
            final v1 = payload[4];
            final v2 = payload[5];
            final higher = v1 >= v2 ? v1 : v2;
            final lower = v1 < v2 ? v1 : v2;
            if (higher >= 60 && higher <= 220 && lower >= 40 && lower <= 140) {
              sys = higher;
              dia = lower;
            }
          } else if (keyId == 0x05 && payload.length >= 2) {
            final v1 = payload[0];
            final v2 = payload[1];
            final higher = v1 >= v2 ? v1 : v2;
            final lower = v1 < v2 ? v1 : v2;
            if (higher >= 60 && higher <= 220 && lower >= 40 && lower <= 140) {
              sys = higher;
              dia = lower;
            }
          } else if (keyId == 0x14 && payload.length >= 5) {
            final rawSpo2 = payload[4];
            if (rawSpo2 >= 70 && rawSpo2 <= 100) spo2 = rawSpo2;
          } else if (keyId == 0x14 && payload.isNotEmpty) {
            final rawSpo2 = payload[0];
            if (rawSpo2 >= 70 && rawSpo2 <= 100) spo2 = rawSpo2;
          }
        }

        if (hr != null || sys != null || dia != null || spo2 != null) {
          return HiWatchTelemetryData(
            heartRateBpm: hr,
            bloodPressureSystolic: sys,
            bloodPressureDiastolic: dia,
            bloodOxygenSpo2: spo2,
            ackPacket: ack,
          );
        }
      }

      // A2. APK FitPro Real-Time Continuous Steps Stream (Key 0x0B / 0x06 / 0x02: Sport Detail & Step Record)
      // Reverse-engineered from BaseReceiveData.Sport (64-bit packed):
      // Bits 0..11  (12 bits): offset
      // Bits 12..15 (4 bits):  mode
      // Bits 16..31 (16 bits): steps
      // Bits 32..42 (11 bits): calories
      // Bits 43..44 (2 bits):  flags
      // Bits 45..63 (19 bits): distance
      if ((isTlv || cmdType == 0x15) && (keyId == 0x0B || keyId == 0x06 || keyId == 0x02)) {
        int? steps;
        int? kcal;
        int? dist;

        final isFullApkFrame = bytes.length >= 20 && bytes[4] == 0x01 && bytes[11] > 0;
        final record = isFullApkFrame
            ? bytes.sublist(12, 20)
            : (payload.length >= 8 ? payload.sublist(0, 8) : null);

        if (record != null && record.length >= 8) {
          if (keyId == 0x02) {
            // Ultra2 / FitPro 8-byte Sport Record Detail (Verified from hardware probe):
            // record[0..1]: steps (16-bit big-endian)
            // record[2..3]: calories (16-bit big-endian)
            // record[4..5]: time bucket (hour, minute)
            // record[6..7]: distance in meters (16-bit big-endian)
            final rawSteps = (record[0] << 8) | record[1];
            final rawKcal = (record[2] << 8) | record[3];
            final rawDist = (record[6] << 8) | record[7];

            if (rawSteps > 0 && rawSteps <= 100000) steps = rawSteps;
            if (rawKcal > 0 && rawKcal <= 15000) kcal = rawKcal;
            if (rawDist > 0 && rawDist <= 500000) dist = rawDist;
          } else {
            final rawSteps = (record[2] << 8) | record[3];
            final rawKcal = (record[4] << 3) | (record[5] >> 5);
            final rawDist = ((record[5] & 0x07) << 16) | (record[6] << 8) | record[7];

            if (rawSteps > 0 && rawSteps <= 100000) steps = rawSteps;
            if (rawKcal > 0 && rawKcal <= 15000) kcal = rawKcal;
            if (rawDist > 0 && rawDist <= 500000) dist = rawDist;
          }

          // Alternate APK packing where bits 0..11 is step and bits 16..31 is distance:
          if (steps == null) {
            final altSteps = ((record[0] & 0xFF) << 4) | ((record[1] >> 4) & 0x0F);
            final altDist = (record[2] << 8) | record[3];
            final altKcal = ((record[5] & 0x07) << 16) | ((record[6] & 0xFF) << 8) | (record[7] & 0xFF);
            if (altSteps > 0 && altSteps <= 100000) steps = altSteps;
            if (altDist > 0 && altDist <= 500000) dist = altDist;
            if (altKcal > 0 && altKcal <= 15000) kcal = altKcal;
          }
        }

        return HiWatchTelemetryData(
          steps: steps,
          calories: kcal,
          distanceMeters: dist,
          ackPacket: ack,
        );
      }


      // A3. APK FitPro Day Real-Time Summary (Key 0x0C / 0x0D / 0x0E)
      // Reverse-engineered from BaseReceiveData.Sport (cmd 0x15, key 0x0C):
      // Full frame: [0xCD, 0x00, len, 0x15, 0x01, 0x0C, Y, M, D, status, S0..S3, D0..D3, C0..C1]
      // payload starts at bytes[6..]
      // If 4-byte date prefix present (payload.length >= 12 or date detected in bytes 0..2):
      //   steps    = payload[4..7]  (4-byte big-endian)
      //   distance = payload[8..11] (4-byte big-endian meters)
      //   calories = payload[12..13] (2-byte big-endian kcal)
      // If date prefix absent (payload.length < 12):
      //   steps    = payload[0..3]
      //   distance = payload[4..7]
      //   calories = payload[8..9]
      if (keyId == 0x0C || keyId == 0x0D || keyId == 0x0E) {
        int steps = 0;
        int? dist;
        int? kcal;

        final hasDatePrefix = payload.length >= 12 ||
            (payload.length >= 8 &&
                payload[0] <= 50 &&
                payload[1] >= 1 &&
                payload[1] <= 12 &&
                payload[2] >= 1 &&
                payload[2] <= 31);

        if (hasDatePrefix && payload.length >= 8) {
          // Steps start at payload[4..7]
          steps = (payload[4] << 24) | (payload[5] << 16) | (payload[6] << 8) | payload[7];
          if (steps == 0 && payload.length >= 7) {
            steps = (payload[4] << 16) | (payload[5] << 8) | payload[6];
          }
          if (steps < 0 || steps > 100000) steps = 0;

          if (payload.length >= 12) {
            final rawDist = (payload[8] << 24) | (payload[9] << 16) | (payload[10] << 8) | payload[11];
            if (rawDist > 0 && rawDist <= 500000) dist = rawDist;
          }
          if (payload.length >= 14) {
            final rawKcal = (payload[12] << 8) | payload[13];
            if (rawKcal > 0 && rawKcal <= 15000) kcal = rawKcal;
          }
        } else if (payload.length >= 4) {
          // Raw steps starting at payload[0..3]
          steps = (payload[0] << 24) | (payload[1] << 16) | (payload[2] << 8) | payload[3];
          if (steps == 0 && payload.length >= 3) {
            steps = (payload[0] << 16) | (payload[1] << 8) | payload[2];
          }
          if (steps < 0 || steps > 100000) steps = 0;

          if (payload.length >= 8) {
            final rawDist = (payload[4] << 24) | (payload[5] << 16) | (payload[6] << 8) | payload[7];
            if (rawDist > 0 && rawDist <= 500000) dist = rawDist;
          }
          if (payload.length >= 10) {
            final rawKcal = (payload[8] << 8) | payload[9];
            if (rawKcal > 0 && rawKcal <= 15000) kcal = rawKcal;
          }
        }

        dist ??= steps > 0 ? (steps * 0.75).round() : null;
        kcal ??= steps > 0 ? (steps * 0.04).round() : null;

        return HiWatchTelemetryData(
          steps: steps > 0 ? steps : null,
          calories: kcal,
          distanceMeters: dist,
          ackPacket: ack,
        );
      }

      // B. StrappedEquipment Real-Time Telemetry Stream (Cmd 0x15 fallback)
      if (!isTlv && (cmdType == 0x15 || subCmd == 0x15)) {
        int rawSteps = 0;
        int? kcal;
        int? distMeters;

        if (bytes.length >= 7) {
          rawSteps = (bytes[4] << 16) | (bytes[5] << 8) | bytes[6];
        }
        if (rawSteps == 0 && bytes.length >= 9) {
          rawSteps = (bytes[6] << 16) | (bytes[7] << 8) | bytes[8];
        }

        final steps = (rawSteps > 0 && rawSteps <= 100000) ? rawSteps : null;

        if (bytes.length >= 9) {
          final rawKcal = (bytes[7] << 8) | bytes[8];
          if (rawKcal > 0 && rawKcal <= 15000) kcal = rawKcal;
        }
        if (bytes.length >= 11) {
          final rawDist = (bytes[9] << 8) | bytes[10];
          if (rawDist > 0 && rawDist <= 500000) distMeters = rawDist;
        }

        distMeters ??= steps != null ? (steps * 0.75).round() : null;
        kcal ??= steps != null ? (steps * 0.04).round() : null;

        return HiWatchTelemetryData(
          steps: steps,
          calories: kcal,
          distanceMeters: distMeters,
          ackPacket: ack,
        );
      }

      // C. Sport & Health Measurement (0x12 / 0x09)
      if (cmdType == 0x12 || subCmd == 0x12 || cmdType == 0x09 || subCmd == 0x09) {
        // C1. Day summary step packet variant (subCmd == 0x06 || 0x0D || 0x11)
        // MUST NEVER scan step bytes for HR / SpO2!
        if (subCmd == 0x06 || subCmd == 0x0D || subCmd == 0x11) {
          int rawSteps = 0;
          int? kcal;
          if (payload.length >= 3) {
            rawSteps = (payload[0] << 16) | (payload[1] << 8) | payload[2];
          } else if (bytes.length >= 7) {
            rawSteps = (bytes[4] << 16) | (bytes[5] << 8) | bytes[6];
          }
          final steps = (rawSteps > 0 && rawSteps <= 100000) ? rawSteps : null;
          if (payload.length >= 5) {
            final rawKcal = (payload[3] << 8) | payload[4];
            if (rawKcal > 0 && rawKcal <= 15000) kcal = rawKcal;
          } else if (bytes.length >= 10) {
            final rawKcal = (bytes[8] << 8) | bytes[9];
            if (rawKcal > 0 && rawKcal <= 15000) kcal = rawKcal;
          }
          return HiWatchTelemetryData(
            steps: steps,
            calories: kcal ?? (steps != null ? (steps * 0.04).round() : null),
            distanceMeters: steps != null ? (steps * 0.75).round() : null,
            ackPacket: ack,
          );
        }

        // C2. Health measurements (HR, BP, SpO2)
        int? hr;
        int? spo2;
        int? sys;
        int? dia;

        // SubCmd 0x01: Heart Rate only
        // SubCmd 0x02: Blood Pressure only (Sys + Dia)
        // SubCmd 0x03: SpO2 only
        // SubCmd 0x04 / 0x18 / 0x24: Combined or Multi-sensor
        if (subCmd == 0x01) {
          final val = payload.isNotEmpty ? payload[0] : (bytes.length >= 5 ? bytes[4] : 0);
          if (val >= 35 && val <= 220) hr = val;
        } else if (subCmd == 0x02) {
          final s = payload.isNotEmpty ? payload[0] : (bytes.length >= 5 ? bytes[4] : 0);
          final d = payload.length >= 2 ? payload[1] : (bytes.length >= 6 ? bytes[5] : 0);
          if (s >= 60 && s <= 220) sys = s;
          if (d >= 40 && d <= 140) dia = d;
        } else if (subCmd == 0x03) {
          final o = payload.isNotEmpty ? payload[0] : (bytes.length >= 5 ? bytes[4] : 0);
          if (o >= 70 && o <= 100) spo2 = o;
        } else if (subCmd == 0x04 || subCmd == 0x18 || subCmd == 0x24) {
          if (payload.length >= 3) {
            final h = payload[0];
            if (h >= 35 && h <= 220) hr = h;
            final s = payload[1];
            final d = payload[2];
            if (s >= 60 && s <= 220 && d >= 40 && d <= 140) {
              sys = s;
              dia = d;
            }
            if (payload.length >= 4) {
              final o = payload[3];
              if (o >= 70 && o <= 100) spo2 = o;
            }
          } else if (bytes.length >= 7) {
            final h = bytes[4];
            if (h >= 35 && h <= 220) hr = h;
            final s = bytes[5];
            final d = bytes[6];
            if (s >= 60 && s <= 220 && d >= 40 && d <= 140) {
              sys = s;
              dia = d;
            }
            if (bytes.length >= 8) {
              final o = bytes[7];
              if (o >= 70 && o <= 100) spo2 = o;
            }
          }
        } else {
          // General scan for health measurements in payload
          for (int i = 0; i < payload.length; i++) {
            final val = payload[i];
            if (hr == null && val >= 40 && val <= 200) {
              hr = val;
            } else if (spo2 == null && hr != null && val >= 70 && val <= 100) {
              spo2 = val;
            }
          }
        }

        return HiWatchTelemetryData(
          heartRateBpm: hr,
          bloodOxygenSpo2: spo2,
          bloodPressureSystolic: sys,
          bloodPressureDiastolic: dia,
          ackPacket: ack,
        );
      }

      // D. Legacy Step data packet (cmdType 0x07 / 0x08)
      if ((cmdType == 0x07 || cmdType == 0x08) && bytes.length >= 7) {
        final rawSteps = (bytes[4] << 16) | (bytes[5] << 8) | bytes[6];
        final steps = (rawSteps > 0 && rawSteps <= 100000) ? rawSteps : null;
        int? kcal = bytes.length >= 9 ? (bytes[7] << 8) | bytes[8] : null;
        if (kcal != null && (kcal <= 0 || kcal > 15000)) kcal = null;
        kcal ??= steps != null ? (steps * 0.04).round() : null;
        int? distMeters = bytes.length >= 11 ? (bytes[9] << 8) | bytes[10] : null;
        if (distMeters != null && (distMeters <= 0 || distMeters > 500000)) distMeters = null;
        distMeters ??= steps != null ? (steps * 0.75).round() : null;
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
        final rawSteps = (bytes[2] << 16) | (bytes[3] << 8) | bytes[4];
        final steps = (rawSteps > 0 && rawSteps <= 100000) ? rawSteps : null;
        int? kcal = bytes.length >= 7 ? (bytes[5] << 8) | bytes[6] : null;
        if (kcal != null && (kcal <= 0 || kcal > 15000)) kcal = null;
        kcal ??= steps != null ? (steps * 0.04).round() : null;
        return HiWatchTelemetryData(
          steps: steps,
          calories: kcal,
        );
      } else if (cmd == 0x09 || cmd == 0x31) {
        final hr = bytes[2];
        final spo2 = bytes.length >= 4 ? bytes[3] : null;
        return HiWatchTelemetryData(
          heartRateBpm: (hr >= 40 && hr <= 200) ? hr : null,
          bloodOxygenSpo2: (spo2 != null && spo2 >= 75 && spo2 <= 100) ? spo2 : null,
        );
      } else if (cmd == 0x00 && bytes.length >= 6) {
        // Length-prefixed 0xAB packet: [0xAB, 0x00, len, target, cmd, payload...]
        final subCmd = (bytes[3] == 0xFF && bytes.length > 4) ? bytes[4] : bytes[3];
        final pOffset = (bytes[3] == 0xFF && bytes.length > 5) ? 5 : 4;
        if ((subCmd == 0x51 || subCmd == 0x52) && bytes.length >= pOffset + 3) {
          final rawSteps = (bytes[pOffset] << 16) | (bytes[pOffset + 1] << 8) | bytes[pOffset + 2];
          return HiWatchTelemetryData(steps: (rawSteps > 0 && rawSteps <= 100000) ? rawSteps : null);
        } else if ((subCmd == 0x09 || subCmd == 0x31) && bytes.length >= pOffset + 1) {
          final hr = bytes[pOffset];
          final spo2 = bytes.length >= pOffset + 2 ? bytes[pOffset + 1] : null;
          return HiWatchTelemetryData(
            heartRateBpm: (hr >= 40 && hr <= 200) ? hr : null,
            bloodOxygenSpo2: (spo2 != null && spo2 >= 70 && spo2 <= 100) ? spo2 : null,
          );
        }
      }
      // If specific 0xAB patterns did not match, fall through to broad scan
    }

    // 4. Format [0x02, hr, spo2, ...] — used by some HiWatch FitPro variants
    if (header == 0x02 && bytes.length >= 3) {
      final hr = bytes[1];
      final spo2 = bytes[2];
      return HiWatchTelemetryData(
        heartRateBpm: (hr >= 35 && hr <= 220) ? hr : null,
        bloodOxygenSpo2: (spo2 >= 70 && spo2 <= 100) ? spo2 : null,
      );
    }

    // 5. Format [0x04, 0x00, hr, spo2] — HiWatch Ultra / Watch 8 Ultra variants
    if (header == 0x04 && bytes.length >= 4) {
      final hr = bytes[2];
      final spo2 = bytes[3];
      return HiWatchTelemetryData(
        heartRateBpm: (hr >= 35 && hr <= 220) ? hr : null,
        bloodOxygenSpo2: (spo2 >= 70 && spo2 <= 100) ? spo2 : null,
      );
    }

    // ── FORMAT: Single byte = raw heart rate (strictly non-protocol bytes) ──
    if (bytes.length == 1 &&
        bytes[0] >= 35 &&
        bytes[0] <= 220 &&
        !protocolHeaders.contains(bytes[0])) {
      return HiWatchTelemetryData(heartRateBpm: bytes[0]);
    }

    // ── FORMAT: [hr, spo2, steps_hi, steps_lo] — Generic BLE watch ─────────
    // Valid only if bytes[0] is not a protocol header and bytes[1] is a valid SpO2
    if (bytes.length >= 4 &&
        !protocolHeaders.contains(header) &&
        header >= 35 &&
        header <= 220) {
      final possibleSpo2 = bytes[1];
      if (possibleSpo2 >= 70 && possibleSpo2 <= 100) {
        final rawSteps = (bytes[2] << 8) | bytes[3];
        final steps = (rawSteps > 0 && rawSteps <= 100000) ? rawSteps : null;
        return HiWatchTelemetryData(
          heartRateBpm: header,
          bloodOxygenSpo2: possibleSpo2,
          steps: steps,
        );
      }
    }

    // ── FORMAT: [0x01, len, 0x12, 0x24, hr, spo2] ──────────────────────────
    if (header == 0x01 && bytes.length >= 6 && bytes[2] == 0x12 && bytes[3] == 0x24) {
      final hr = bytes[4]; final spo2 = bytes[5];
      return HiWatchTelemetryData(
        heartRateBpm: (hr >= 35 && hr <= 220) ? hr : null,
        bloodOxygenSpo2: (spo2 >= 70 && spo2 <= 100) ? spo2 : null,
      );
    }

    // ── Ultra2 / Generic Chinese Watch Protocol ─────────────────────────────
    // Checked BEFORE broad scan — 0xBC = 188 falls in HR range 40-220
    if (header == 0xBC && bytes.length >= 4) {
      final cmd = bytes[1];

      // Ultra2 Step Telemetry: [0xBC, 0x51/0x52/0x07/0x08, S0, S1, S2, C0, C1, D0, D1]
      if (cmd == 0x51 || cmd == 0x52 || cmd == 0x07 || cmd == 0x08) {
        if (bytes.length >= 5) {
          final rawSteps = (bytes[2] << 16) | (bytes[3] << 8) | bytes[4];
          final steps = (rawSteps > 0 && rawSteps <= 100000) ? rawSteps : null;
          int? kcal = bytes.length >= 7 ? (bytes[5] << 8) | bytes[6] : null;
          if (kcal != null && (kcal <= 0 || kcal > 15000)) kcal = null;
          kcal ??= steps != null ? (steps * 0.04).round() : null;
          int? dist = bytes.length >= 9 ? (bytes[7] << 8) | bytes[8] : null;
          if (dist != null && (dist <= 0 || dist > 500000)) dist = null;
          dist ??= steps != null ? (steps * 0.75).round() : null;
          return HiWatchTelemetryData(
            steps: steps,
            calories: kcal,
            distanceMeters: dist,
          );
        }
      }

      // Ultra2 Health Readings: [0xBC, 0x60/0x61/0x62/0x63, hr, spo2, sys, dia]
      if ((cmd >= 0x60 && cmd <= 0x6F) && bytes.length >= 6) {
        final hr = bytes[2];
        final spo2 = bytes[3];
        final sys = bytes[4];
        final dia = bytes[5];

        final validHr = (hr >= 40 && hr <= 200) ? hr : null;
        final validSpo2 = (spo2 >= 70 && spo2 <= 100) ? spo2 : null;
        final validSys = (sys >= 60 && sys <= 220) ? sys : null;
        final validDia = (dia >= 40 && dia <= 140) ? dia : null;

        if (validHr != null || validSpo2 != null || validSys != null) {
          return HiWatchTelemetryData(
            heartRateBpm: validHr,
            bloodOxygenSpo2: validSpo2,
            bloodPressureSystolic: validSys,
            bloodPressureDiastolic: validDia,
          );
        }
        return HiWatchTelemetryData.empty();
      }
    }

    // ── FORMAT: Broad scan — find HR/SpO2 pair in payload ─────────────────
    // Skips known protocol headers to prevent command bytes being read as vitals
    if (bytes.length >= 3 && bytes.length <= 24 && !protocolHeaders.contains(header)) {
      int? foundHr; int? foundSpo2;
      for (int i = 1; i < bytes.length; i++) {
        final v = bytes[i];
        if (foundHr == null && v >= 40 && v <= 200) {
          foundHr = v;
        } else if (foundSpo2 == null && foundHr != null && v >= 70 && v <= 100) {
          foundSpo2 = v;
        }
      }
      if (foundHr != null && foundSpo2 != null) {
        return HiWatchTelemetryData(heartRateBpm: foundHr, bloodOxygenSpo2: foundSpo2);
      }
    }

    // Format variant 2: [0x01, len, cmd, sub, data...] - generic health protocol
    if (header == 0x01 && bytes.length >= 5) {
      final cmd = bytes[2];
      // final sub = bytes[3];
      if (cmd == 0x35 || cmd == 0x36 || cmd == 0x3A) {
        // Health data response
        for (int i = 4; i < bytes.length - 1; i++) {
          final v = bytes[i];
          final v2 = bytes[i + 1];
          if (v >= 40 && v <= 200 && v2 >= 70 && v2 <= 100) {
            return HiWatchTelemetryData(heartRateBpm: v, bloodOxygenSpo2: v2);
          }
        }
      }
      // Step data
      if (cmd == 0x52 && bytes.length >= 8) {
        final rawSteps = (bytes[4] << 16) | (bytes[5] << 8) | bytes[6];
        final steps = (rawSteps > 0 && rawSteps <= 100000) ? rawSteps : null;
        int? kcal = bytes.length >= 10 ? (bytes[7] << 8) | bytes[8] : null;
        if (kcal != null && (kcal <= 0 || kcal > 15000)) kcal = null;
        kcal ??= steps != null ? (steps * 0.04).round() : null;
        return HiWatchTelemetryData(steps: steps, calories: kcal);
      }
    }

    // Format variant 3: TK-style [0x4D, 0x4F, cmd, data...]
    if (header == 0x4D && bytes.length >= 4 && bytes[1] == 0x4F) {
      final cmd = bytes[2];
      if (cmd == 0x15 || cmd == 0x16) {
        // HR + SpO2 data
        if (bytes.length >= 6) {
          final hr = bytes[4];
          final spo2 = bytes[5];
          return HiWatchTelemetryData(
            heartRateBpm: (hr >= 40 && hr <= 200) ? hr : null,
            bloodOxygenSpo2: (spo2 >= 70 && spo2 <= 100) ? spo2 : null,
          );
        }
      }
    }

    // Format variant 4: GW/HK9/T900 Ultra2-style [0x68, data...]
    if (header == 0x68 && bytes.length >= 4) {
      for (int i = 1; i < bytes.length - 1; i++) {
        final v = bytes[i]; final v2 = bytes[i+1];
        if (v >= 40 && v <= 200 && v2 >= 70 && v2 <= 100) {
          return HiWatchTelemetryData(heartRateBpm: v, bloodOxygenSpo2: v2);
        }
      }
    }

    // Format variant 5: [len, cmd, hr, spo2, ...] - many generic BLE chips
    if (bytes.length >= 4) {
      final len = bytes[0];
      if (len == bytes.length - 1 || len == bytes.length) {
        // Length-prefixed packet - scan for vitals in positions 2-6
        for (int i = 2; i < bytes.length.clamp(0, 7); i++) {
          final v = bytes[i];
          if (v >= 40 && v <= 200) {
            // Likely HR
            if (i + 1 < bytes.length) {
              final v2 = bytes[i + 1];
              if (v2 >= 70 && v2 <= 100) {
                return HiWatchTelemetryData(heartRateBpm: v, bloodOxygenSpo2: v2);
              }
            }
            return HiWatchTelemetryData(heartRateBpm: v);
          }
        }
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
  final int? bloodPressureSystolic;
  final int? bloodPressureDiastolic;
  final int? batteryLevel;
  final List<int>? ackPacket;

  const HiWatchTelemetryData({
    this.steps,
    this.calories,
    this.distanceMeters,
    this.heartRateBpm,
    this.bloodOxygenSpo2,
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.batteryLevel,
    this.ackPacket,
  });

  factory HiWatchTelemetryData.empty() => const HiWatchTelemetryData();

  bool get isEmpty =>
      steps == null &&
      calories == null &&
      heartRateBpm == null &&
      bloodOxygenSpo2 == null &&
      bloodPressureSystolic == null &&
      bloodPressureDiastolic == null &&
      ackPacket == null;
}

/// ─── HIWATCH PACKET ASSEMBLER (Official BaseReceiveData.java Parity) ───────
/// Replicates exact fragmentation handling from BaseReceiveData.java lines 143-165:
/// - Reassembles multi-chunk BLE notifications (due to 20-byte MTU limits) into
///   complete protocol frames using the declared length header [0xCD, len_hi, len_lo].
/// - Non-0xCD frames (DaFit 0xAB, Ultra2 0xBC, SIG HR, Watch ACKs 0xDC) pass
///   through immediately without buffering delay.
/// - Incomplete frames are cleared when a new 0xCD start header arrives.
class HiWatchPacketAssembler {
  List<int> _buffer = [];

  /// Processes an incoming raw BLE characteristic chunk.
  /// Returns the complete assembled frame if ready for parsing,
  /// or null if waiting for remaining fragments.
  List<int>? processChunk(List<int> chunk) {
    if (chunk.isEmpty) return null;
    final header = chunk[0];

    // Watch ACK (0xDC) resets buffer and passes through immediately
    if (header == 0xDC) {
      _buffer.clear();
      return chunk;
    }

    // New 0xCD frame starts or chunk > 120 bytes -> reset buffer (BaseReceiveData.java L144)
    if (header == 0xCD || chunk.length > 120) {
      _buffer = List<int>.from(chunk);
    } else if (_buffer.isNotEmpty && _buffer[0] == 0xCD) {
      // Continuation fragment of an ongoing 0xCD frame (BaseReceiveData.java byteMerger L152)
      _buffer.addAll(chunk);
    } else {
      // Standalone non-0xCD packet (DaFit, Ultra2, SIG HR, etc.)
      return chunk;
    }

    // Need at least 3 bytes for [0xCD, len_hi, len_lo]
    if (_buffer.length < 3) return null;

    final declaredPayloadLen = (_buffer[1] << 8) | _buffer[2];
    final currentPayloadLen = _buffer.length - 3;

    // Incomplete packet: waiting for more fragments (BaseReceiveData.java L156)
    if (declaredPayloadLen > currentPayloadLen) {
      return null;
    }

    // Complete packet assembled!
    final completed = List<int>.from(_buffer);
    _buffer.clear();
    return completed;
  }

  /// Clears the assembly buffer (e.g. on disconnect or reset).
  void reset() {
    _buffer.clear();
  }

  /// Current buffer length for diagnostics and testing.
  int get bufferLength => _buffer.length;
}

