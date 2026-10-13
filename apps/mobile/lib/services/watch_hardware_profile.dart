import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'hiwatch_pro_service.dart';

/// Supported Smartwatch Protocol Families in VYRA
enum WatchProtocolType {
  /// HiWatch Pro / FitPro / Jerry JL7012 / AC695X (0xCD / 0xDC, UART 0x6E40)
  hiwatchCd,

  /// DaFit / Shenzhen MoYoung / NRF52832 (0xAB, UUID 0xFEE7 / 0xFEE1 / 0xFEE2)
  dafitAb,

  /// Standard Bluetooth SIG Heart Rate Profile (Service 0x180D, Notify 0x2A37)
  bleSig,

  /// Samsung Galaxy Watch / Google Wear OS / Encrypted Companion GATT Bridge
  /// (Services: eed6d5cc / e73e0001 / 180a, Char: 2fb6a5aa / e73e0002)
  wearOsCompanion,

  /// Generic Custom UART stream
  genericUart,
}

/// Universal Hardware Profile for any Smartwatch discovered by VYRA Prober.
///
/// Enables a seamless 1-time setup for any user's smartwatch:
/// 1. Prober tests candidate protocols and identifies optimal configuration.
/// 2. Prober exports this [WatchHardwareProfile] into SharedPreferences.
/// 3. Vyra Sync Engine (`health_sync.dart`) reads this profile and dynamically
///    adapts its GATT UUIDs, handshakes, keepalive pings, and telemetry parsers.
class WatchHardwareProfile {
  static const String prefsActiveProfileKey = 'vyra_active_watch_profile';

  final String profileId;
  final String deviceName;
  final String remoteId;
  final WatchProtocolType protocolType;
  final String serviceUuid;
  final String writeCharUuid;
  final String notifyCharUuid;
  final List<int> handshakePacket;
  final List<int> rtcSyncPacket;
  final List<int> stepQueryPacket;
  final List<int> hrTriggerPacket;
  final List<int> bpTriggerPacket;
  final bool requiresAck;
  final int keepaliveIntervalMs;
  final DateTime createdAt;

  const WatchHardwareProfile({
    required this.profileId,
    required this.deviceName,
    required this.remoteId,
    required this.protocolType,
    required this.serviceUuid,
    required this.writeCharUuid,
    required this.notifyCharUuid,
    required this.handshakePacket,
    required this.rtcSyncPacket,
    required this.stepQueryPacket,
    required this.hrTriggerPacket,
    required this.bpTriggerPacket,
    this.requiresAck = true,
    this.keepaliveIntervalMs = 3500,
    required this.createdAt,
  });

  /// Default ground-truth profile for Ultra 2 / HiWatch Pro (Jerry JL7012)
  static WatchHardwareProfile defaultUltra2Profile({String? remoteId}) {
    return WatchHardwareProfile(
      profileId: 'ultra2_hiwatch_default',
      deviceName: 'Ultra2',
      remoteId: remoteId ?? '71:7E:FB:00:03:CB',
      protocolType: WatchProtocolType.hiwatchCd,
      serviceUuid: HiWatchProProtocol.uartServiceUuid2, // 6e400801
      writeCharUuid: HiWatchProProtocol.uartWriteCharacteristicUuid, // 6e400002
      notifyCharUuid: HiWatchProProtocol.uartNotifyCharacteristicUuid, // 6e400003
      handshakePacket: const [0xCD, 0x00, 0x06, 0x12, 0x01, 0x0A, 0x00, 0x01, 0x02],
      rtcSyncPacket: HiWatchProProtocol.buildHiWatchTimeSyncCommand(),
      stepQueryPacket: const [0xCD, 0x00, 0x06, 0x12, 0x01, 0x06, 0x00, 0x01, 0x01],
      hrTriggerPacket: const [0xCD, 0x00, 0x06, 0x12, 0x01, 0x0D, 0x00, 0x01, 0x01],
      bpTriggerPacket: const [0xCD, 0x00, 0x06, 0x12, 0x01, 0x0E, 0x00, 0x01, 0x01],
      requiresAck: true,
      keepaliveIntervalMs: 3500,
      createdAt: DateTime.now(),
    );
  }

  /// Preset profile for DaFit / MoYoung smartwatches (0xAB Protocol)
  static WatchHardwareProfile daFitProfile({
    required String deviceName,
    required String remoteId,
  }) {
    return WatchHardwareProfile(
      profileId: 'dafit_shenzhen_${remoteId.replaceAll(":", "_")}',
      deviceName: deviceName,
      remoteId: remoteId,
      protocolType: WatchProtocolType.dafitAb,
      serviceUuid: '0000fee7-0000-1000-8000-00805f9b34fb',
      writeCharUuid: '0000fee1-0000-1000-8000-00805f9b34fb',
      notifyCharUuid: '0000fee2-0000-1000-8000-00805f9b34fb',
      handshakePacket: const [0xAB, 0x00, 0x04, 0xFF, 0x00, 0x00, 0xAB],
      rtcSyncPacket: const [0xAB, 0x00, 0x04, 0xFF, 0x00, 0x00, 0xAB],
      stepQueryPacket: const [0xAB, 0x51, 0x00, 0x0A, 0x00, 0x00, 0x64],
      hrTriggerPacket: const [0xAB, 0x09, 0x54, 0x63],
      bpTriggerPacket: const [0xAB, 0x09, 0x54, 0x63],
      requiresAck: false,
      keepaliveIntervalMs: 5000,
      createdAt: DateTime.now(),
    );
  }

  /// Preset profile for standard Bluetooth SIG Heart Rate Profile (0x180D)
  static WatchHardwareProfile bleSigProfile({
    required String deviceName,
    required String remoteId,
  }) {
    return WatchHardwareProfile(
      profileId: 'ble_sig_${remoteId.replaceAll(":", "_")}',
      deviceName: deviceName,
      remoteId: remoteId,
      protocolType: WatchProtocolType.bleSig,
      serviceUuid: '0000180d-0000-1000-8000-00805f9b34fb',
      writeCharUuid: '00002a39-0000-1000-8000-00805f9b34fb',
      notifyCharUuid: '00002a37-0000-1000-8000-00805f9b34fb',
      handshakePacket: const [0x00],
      rtcSyncPacket: const [],
      stepQueryPacket: const [],
      hrTriggerPacket: const [0x01],
      bpTriggerPacket: const [],
      requiresAck: false,
      keepaliveIntervalMs: 5000,
      createdAt: DateTime.now(),
    );
  }

  /// Preset profile for Samsung Galaxy Watch / Wear OS Companion GATT Bridge
  static WatchHardwareProfile wearOsCompanionProfile({
    required String deviceName,
    required String remoteId,
    String serviceUuid = 'eed6d5cc-c3b2-4d7b-8c6b-7acbf7965bb6',
    String writeCharUuid = '2fb6a5aa-1219-4129-bc97-dd4df70613cd',
    String notifyCharUuid = '2fb6a5aa-1219-4129-bc97-dd4df70613cd',
  }) {
    return WatchHardwareProfile(
      profileId: 'wearos_companion_${remoteId.replaceAll(":", "_")}',
      deviceName: deviceName,
      remoteId: remoteId,
      protocolType: WatchProtocolType.wearOsCompanion,
      serviceUuid: serviceUuid,
      writeCharUuid: writeCharUuid,
      notifyCharUuid: notifyCharUuid,
      handshakePacket: const [0x01, 0x00, 0x04, 0x00],
      rtcSyncPacket: const [0x01, 0x02, 0x00, 0x00],
      stepQueryPacket: const [0x01, 0x51, 0x00, 0x01],
      hrTriggerPacket: const [0x01, 0x0D, 0x00, 0x01],
      bpTriggerPacket: const [0x01, 0x0E, 0x00, 0x01],
      requiresAck: false,
      keepaliveIntervalMs: 4000,
      createdAt: DateTime.now(),
    );
  }

  /// Automatically inspects discovered GATT services & characteristics to infer
  /// the optimal profile for any new smartwatch in a single step (Zero-configuration).
  static WatchHardwareProfile fromDiscoveredServices({
    required String deviceName,
    required String remoteId,
    required List<BluetoothService> services,
  }) {
    String jerryServiceUuid = '';
    String jerryWriteCharUuid = '';
    String jerryNotifyCharUuid = '';

    String dafitServiceUuid = '';
    String dafitWriteCharUuid = '';
    String dafitNotifyCharUuid = '';

    String sigServiceUuid = '';
    String sigWriteCharUuid = '';
    String sigNotifyCharUuid = '';

    String fallbackServiceUuid = '';
    String fallbackWriteCharUuid = '';
    String fallbackNotifyCharUuid = '';

    bool hasJerry = false;
    bool hasDaFit = false;
    bool hasBleSig = false;

    // Scan all services & characteristics without cross-overwriting between families
    for (final s in services) {
      final sUuid = s.uuid.toString().toLowerCase();

      // 1. Check for Jerry / HiWatch / FitPro / HryFine / Bluetrum / FitCloudPro UART
      //    (6e40, ff01, ae00, ae01, fff0, ffd0, ffe0, ff00, ffe5, f000)
      if (sUuid.contains('6e40') ||
          sUuid.contains('ff01') ||
          sUuid.contains('ae00') ||
          sUuid.contains('ae01') ||
          sUuid.contains('fff0') ||
          sUuid.contains('ffd0') ||
          sUuid.contains('ffe0') ||
          sUuid.contains('ff00') ||
          sUuid.contains('ffe5') ||
          sUuid.contains('f000')) {
        hasJerry = true;
        if (jerryServiceUuid.isEmpty || sUuid.contains('6e40')) {
          jerryServiceUuid = s.uuid.toString();
        }
        for (final c in s.characteristics) {
          final cUuid = c.uuid.toString().toLowerCase();
          final canWrite = c.properties.write || c.properties.writeWithoutResponse;
          final canNotify = c.properties.notify || c.properties.indicate;

          if (cUuid.contains('6e400002') ||
              cUuid.contains('ff02') ||
              cUuid.contains('fff2') ||
              cUuid.contains('ae01') ||
              cUuid.contains('ffd1') ||
              cUuid.contains('f001') ||
              (canWrite && jerryWriteCharUuid.isEmpty)) {
            if (jerryWriteCharUuid.isEmpty || cUuid.contains('6e400002')) {
              jerryWriteCharUuid = c.uuid.toString();
            }
          }
          if (cUuid.contains('6e400003') ||
              cUuid.contains('ff03') ||
              cUuid.contains('fff1') ||
              cUuid.contains('ae02') ||
              cUuid.contains('ffd2') ||
              cUuid.contains('ffe1') ||
              cUuid.contains('f002') ||
              (canNotify && jerryNotifyCharUuid.isEmpty)) {
            if (jerryNotifyCharUuid.isEmpty || cUuid.contains('6e400003')) {
              jerryNotifyCharUuid = c.uuid.toString();
            }
          }
        }
      }

      // 2. Check for DaFit / MoYoung / Fire-Boltt / Noise / boAt / Amazfit
      //    (fee7, feea, fee1, fee2, fee3, fec7, fec8, fea0)
      if (sUuid.contains('fee7') ||
          sUuid.contains('feea') ||
          sUuid.contains('fee1') ||
          sUuid.contains('fee2') ||
          sUuid.contains('fec7') ||
          sUuid.contains('fea0')) {
        hasDaFit = true;
        if (dafitServiceUuid.isEmpty || sUuid.contains('fee7') || sUuid.contains('feea')) {
          dafitServiceUuid = s.uuid.toString();
        }
        for (final c in s.characteristics) {
          final cUuid = c.uuid.toString().toLowerCase();
          final canWrite = c.properties.write || c.properties.writeWithoutResponse;
          final canNotify = c.properties.notify || c.properties.indicate;

          if (cUuid.contains('fee1') ||
              cUuid.contains('fee2') && canWrite && !canNotify ||
              cUuid.contains('fec7') ||
              (canWrite && dafitWriteCharUuid.isEmpty)) {
            if (dafitWriteCharUuid.isEmpty || cUuid.contains('fee1')) {
              dafitWriteCharUuid = c.uuid.toString();
            }
          }
          if (cUuid.contains('fee2') && canNotify ||
              cUuid.contains('fee3') ||
              cUuid.contains('fec8') ||
              (canNotify && dafitNotifyCharUuid.isEmpty)) {
            if (dafitNotifyCharUuid.isEmpty || cUuid.contains('fee2') || cUuid.contains('fee3')) {
              dafitNotifyCharUuid = c.uuid.toString();
            }
          }
        }
      }

      // 3. Check for Standard Bluetooth SIG Heart Rate (0x180D) or Running Speed/Cadence (0x1814)
      if (sUuid.contains('180d') || sUuid.contains('1814')) {
        hasBleSig = true;
        if (sigServiceUuid.isEmpty || sUuid.contains('180d')) {
          sigServiceUuid = s.uuid.toString();
        }
        for (final c in s.characteristics) {
          final cUuid = c.uuid.toString().toLowerCase();
          if (cUuid.contains('2a37') || (sigNotifyCharUuid.isEmpty && cUuid.contains('2a53'))) {
            sigNotifyCharUuid = c.uuid.toString();
          }
          if (c.properties.write || c.properties.writeWithoutResponse) {
            sigWriteCharUuid = c.uuid.toString();
          }
        }
      }
    }

    String wearOsServiceUuid = '';
    String wearOsWriteCharUuid = '';
    String wearOsNotifyCharUuid = '';
    bool hasWearOs = false;

    // Fallback + Wear OS / Samsung Companion GATT detection (eed6d5cc / e73e0001 / 2fb6a5aa)
    for (final s in services) {
      final sUuid = s.uuid.toString().toLowerCase();
      if (sUuid.contains('eed6d5cc') || sUuid.contains('e73e0001')) {
        hasWearOs = true;
        if (wearOsServiceUuid.isEmpty || sUuid.contains('eed6d5cc')) {
          wearOsServiceUuid = s.uuid.toString();
        }
        for (final c in s.characteristics) {
          final cUuid = c.uuid.toString().toLowerCase();
          if (cUuid.contains('2fb6a5aa')) {
            wearOsWriteCharUuid = c.uuid.toString();
            wearOsNotifyCharUuid = c.uuid.toString();
          } else if (c.properties.read && wearOsNotifyCharUuid.isEmpty) {
            wearOsNotifyCharUuid = c.uuid.toString();
          }
        }
      }

      final isSystem = sUuid.startsWith('00001800') ||
          sUuid.startsWith('00001801') ||
          sUuid.startsWith('0000180a') ||
          sUuid.startsWith('0000180f') ||
          sUuid.startsWith('00001812');
      if (isSystem) continue;

      for (final c in s.characteristics) {
        if (fallbackWriteCharUuid.isEmpty && (c.properties.write || c.properties.writeWithoutResponse)) {
          fallbackWriteCharUuid = c.uuid.toString();
          fallbackServiceUuid = s.uuid.toString();
        }
        if (fallbackNotifyCharUuid.isEmpty && (c.properties.notify || c.properties.indicate)) {
          fallbackNotifyCharUuid = c.uuid.toString();
          if (fallbackServiceUuid.isEmpty) fallbackServiceUuid = s.uuid.toString();
        }
      }
    }

    // Also check device name hints
    final lowerName = deviceName.toLowerCase();
    final nameSuggestsWearOs = lowerName.contains('galaxy') ||
        lowerName.contains('samsung') ||
        lowerName.contains('sm-r') ||
        lowerName.contains('pixel watch') ||
        lowerName.contains('wear os') ||
        lowerName.contains('ticwatch') ||
        lowerName.contains('fossil');
    final nameSuggestsDaFit = lowerName.contains('dafit') ||
        lowerName.contains('fire') ||
        lowerName.contains('boltt') ||
        lowerName.contains('noise') ||
        lowerName.contains('colorfit') ||
        lowerName.contains('boat') ||
        lowerName.contains('xtend') ||
        lowerName.contains('wave') ||
        lowerName.contains('storm');

    // Select protocol priority without losing vendor notify characteristics
    if ((hasWearOs || nameSuggestsWearOs) && !hasJerry && !hasDaFit && !hasBleSig) {
      return WatchHardwareProfile.wearOsCompanionProfile(
        deviceName: deviceName.isNotEmpty ? deviceName : 'Galaxy Watch (Wear OS)',
        remoteId: remoteId,
        serviceUuid: wearOsServiceUuid.isNotEmpty
            ? wearOsServiceUuid
            : (fallbackServiceUuid.isNotEmpty ? fallbackServiceUuid : 'eed6d5cc-c3b2-4d7b-8c6b-7acbf7965bb6'),
        writeCharUuid: wearOsWriteCharUuid.isNotEmpty
            ? wearOsWriteCharUuid
            : (fallbackWriteCharUuid.isNotEmpty ? fallbackWriteCharUuid : '2fb6a5aa-1219-4129-bc97-dd4df70613cd'),
        notifyCharUuid: wearOsNotifyCharUuid.isNotEmpty
            ? wearOsNotifyCharUuid
            : (fallbackNotifyCharUuid.isNotEmpty ? fallbackNotifyCharUuid : '2fb6a5aa-1219-4129-bc97-dd4df70613cd'),
      );
    } else if (hasDaFit && (!hasJerry || nameSuggestsDaFit)) {
      return WatchHardwareProfile(
        profileId: 'auto_dafit_${remoteId.replaceAll(":", "_")}',
        deviceName: deviceName.isNotEmpty ? deviceName : 'DaFit Watch',
        remoteId: remoteId,
        protocolType: WatchProtocolType.dafitAb,
        serviceUuid: dafitServiceUuid.isNotEmpty
            ? dafitServiceUuid
            : (fallbackServiceUuid.isNotEmpty ? fallbackServiceUuid : '0000fee7-0000-1000-8000-00805f9b34fb'),
        writeCharUuid: dafitWriteCharUuid.isNotEmpty
            ? dafitWriteCharUuid
            : (fallbackWriteCharUuid.isNotEmpty ? fallbackWriteCharUuid : '0000fee1-0000-1000-8000-00805f9b34fb'),
        notifyCharUuid: dafitNotifyCharUuid.isNotEmpty
            ? dafitNotifyCharUuid
            : (fallbackNotifyCharUuid.isNotEmpty ? fallbackNotifyCharUuid : '0000fee2-0000-1000-8000-00805f9b34fb'),
        handshakePacket: const [0xAB, 0x00, 0x04, 0xFF, 0x00, 0x00, 0xAB],
        rtcSyncPacket: const [0xAB, 0x00, 0x04, 0xFF, 0x91, 0x80, 0x01],
        stepQueryPacket: const [0xAB, 0x51, 0x00, 0x0A, 0x00, 0x00, 0x64],
        hrTriggerPacket: const [0xAB, 0x00, 0x04, 0xFF, 0x31, 0x09, 0x01],
        bpTriggerPacket: const [0xAB, 0x00, 0x04, 0xFF, 0x31, 0x21, 0x01],
        requiresAck: false,
        keepaliveIntervalMs: 4500,
        createdAt: DateTime.now(),
      );
    } else if (hasBleSig && !hasJerry && !hasDaFit) {
      return WatchHardwareProfile(
        profileId: 'auto_sig_${remoteId.replaceAll(":", "_")}',
        deviceName: deviceName.isNotEmpty ? deviceName : 'BLE HR Watch',
        remoteId: remoteId,
        protocolType: WatchProtocolType.bleSig,
        serviceUuid: sigServiceUuid.isNotEmpty ? sigServiceUuid : '0000180d-0000-1000-8000-00805f9b34fb',
        writeCharUuid: sigWriteCharUuid.isNotEmpty ? sigWriteCharUuid : '00002a39-0000-1000-8000-00805f9b34fb',
        notifyCharUuid: sigNotifyCharUuid.isNotEmpty ? sigNotifyCharUuid : '00002a37-0000-1000-8000-00805f9b34fb',
        handshakePacket: const [0x00],
        rtcSyncPacket: const [],
        stepQueryPacket: const [],
        hrTriggerPacket: const [0x01],
        bpTriggerPacket: const [],
        requiresAck: false,
        keepaliveIntervalMs: 5000,
        createdAt: DateTime.now(),
      );
    } else {
      // Default to Jerry / HiWatch / FitPro / Universal UART
      final resolvedService = jerryServiceUuid.isNotEmpty
          ? jerryServiceUuid
          : (fallbackServiceUuid.isNotEmpty ? fallbackServiceUuid : HiWatchProProtocol.uartServiceUuid2);
      final resolvedWrite = jerryWriteCharUuid.isNotEmpty
          ? jerryWriteCharUuid
          : (fallbackWriteCharUuid.isNotEmpty ? fallbackWriteCharUuid : HiWatchProProtocol.uartWriteCharacteristicUuid);
      final resolvedNotify = jerryNotifyCharUuid.isNotEmpty
          ? jerryNotifyCharUuid
          : (fallbackNotifyCharUuid.isNotEmpty ? fallbackNotifyCharUuid : HiWatchProProtocol.uartNotifyCharacteristicUuid);

      return WatchHardwareProfile(
        profileId: 'auto_hiwatch_${remoteId.replaceAll(":", "_")}',
        deviceName: deviceName.isNotEmpty ? deviceName : 'Smartwatch',
        remoteId: remoteId,
        protocolType: WatchProtocolType.hiwatchCd,
        serviceUuid: resolvedService,
        writeCharUuid: resolvedWrite,
        notifyCharUuid: resolvedNotify,
        handshakePacket: const [0xCD, 0x00, 0x06, 0x12, 0x01, 0x0A, 0x00, 0x01, 0x02],
        rtcSyncPacket: HiWatchProProtocol.buildHiWatchTimeSyncCommand(),
        stepQueryPacket: const [0xCD, 0x00, 0x06, 0x15, 0x01, 0x0D, 0x00, 0x01, 0x01],
        hrTriggerPacket: const [0xCD, 0x00, 0x06, 0x12, 0x01, 0x0D, 0x00, 0x01, 0x01],
        bpTriggerPacket: const [0xCD, 0x00, 0x06, 0x12, 0x01, 0x0E, 0x00, 0x01, 0x01],
        requiresAck: true,
        keepaliveIntervalMs: 3500,
        createdAt: DateTime.now(),
      );
    }
  }

  /// Auto-constructs a validated [WatchHardwareProfile] from prober findings
  static WatchHardwareProfile fromProberFindings({
    required String deviceName,
    required String remoteId,
    required String writeCharUuid,
    required String notifyCharUuid,
    String? serviceUuid,
    required bool isDaFitPassed,
    required bool isHiWatchPassed,
    required bool isBleSig,
    bool isWearOsCompanion = false,
  }) {
    final lowerWrite = writeCharUuid.toLowerCase();
    final lowerName = deviceName.toLowerCase();
    if (isWearOsCompanion ||
        lowerWrite.contains('2fb6a5aa') ||
        lowerName.contains('galaxy') ||
        lowerName.contains('samsung') ||
        lowerName.contains('wear os')) {
      return WatchHardwareProfile.wearOsCompanionProfile(
        deviceName: deviceName,
        remoteId: remoteId,
        serviceUuid: serviceUuid ?? 'eed6d5cc-c3b2-4d7b-8c6b-7acbf7965bb6',
        writeCharUuid: writeCharUuid.isNotEmpty ? writeCharUuid : '2fb6a5aa-1219-4129-bc97-dd4df70613cd',
        notifyCharUuid: notifyCharUuid.isNotEmpty ? notifyCharUuid : '2fb6a5aa-1219-4129-bc97-dd4df70613cd',
      );
    }

    if (isDaFitPassed && !isHiWatchPassed) {
      return WatchHardwareProfile(
        profileId: 'probed_dafit_${remoteId.replaceAll(":", "_")}',
        deviceName: deviceName,
        remoteId: remoteId,
        protocolType: WatchProtocolType.dafitAb,
        serviceUuid: serviceUuid ?? '0000fee7-0000-1000-8000-00805f9b34fb',
        writeCharUuid: writeCharUuid,
        notifyCharUuid: notifyCharUuid,
        handshakePacket: const [0xAB, 0x00, 0x04, 0xFF, 0x00, 0x00, 0xAB],
        rtcSyncPacket: const [0xAB, 0x00, 0x04, 0xFF, 0x00, 0x00, 0xAB],
        stepQueryPacket: const [0xAB, 0x51, 0x00, 0x0A, 0x00, 0x00, 0x64],
        hrTriggerPacket: const [0xAB, 0x09, 0x54, 0x63],
        bpTriggerPacket: const [0xAB, 0x09, 0x54, 0x63],
        requiresAck: false,
        keepaliveIntervalMs: 5000,
        createdAt: DateTime.now(),
      );
    }

    if (isBleSig && !isHiWatchPassed) {
      return WatchHardwareProfile(
        profileId: 'probed_sig_${remoteId.replaceAll(":", "_")}',
        deviceName: deviceName,
        remoteId: remoteId,
        protocolType: WatchProtocolType.bleSig,
        serviceUuid: serviceUuid ?? '0000180d-0000-1000-8000-00805f9b34fb',
        writeCharUuid: writeCharUuid,
        notifyCharUuid: notifyCharUuid,
        handshakePacket: const [0x00],
        rtcSyncPacket: const [],
        stepQueryPacket: const [],
        hrTriggerPacket: const [0x01],
        bpTriggerPacket: const [],
        requiresAck: false,
        keepaliveIntervalMs: 5000,
        createdAt: DateTime.now(),
      );
    }

    // Default to HiWatch / Jerry 0xCD UART
    return WatchHardwareProfile(
      profileId: 'probed_hiwatch_${remoteId.replaceAll(":", "_")}',
      deviceName: deviceName,
      remoteId: remoteId,
      protocolType: WatchProtocolType.hiwatchCd,
      serviceUuid: serviceUuid ?? HiWatchProProtocol.uartServiceUuid2,
      writeCharUuid: writeCharUuid,
      notifyCharUuid: notifyCharUuid,
      handshakePacket: const [0xCD, 0x00, 0x06, 0x12, 0x01, 0x0A, 0x00, 0x01, 0x02],
      rtcSyncPacket: HiWatchProProtocol.buildHiWatchTimeSyncCommand(),
      stepQueryPacket: const [0xCD, 0x00, 0x06, 0x12, 0x01, 0x06, 0x00, 0x01, 0x01],
      hrTriggerPacket: const [0xCD, 0x00, 0x06, 0x12, 0x01, 0x0D, 0x00, 0x01, 0x01],
      bpTriggerPacket: const [0xCD, 0x00, 0x06, 0x12, 0x01, 0x0E, 0x00, 0x01, 0x01],
      requiresAck: true,
      keepaliveIntervalMs: 3500,
      createdAt: DateTime.now(),
    );
  }

  // ─── Serialization ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'profileId': profileId,
        'deviceName': deviceName,
        'remoteId': remoteId,
        'protocolType': protocolType.name,
        'serviceUuid': serviceUuid,
        'writeCharUuid': writeCharUuid,
        'notifyCharUuid': notifyCharUuid,
        'handshakePacket': handshakePacket,
        'rtcSyncPacket': rtcSyncPacket,
        'stepQueryPacket': stepQueryPacket,
        'hrTriggerPacket': hrTriggerPacket,
        'bpTriggerPacket': bpTriggerPacket,
        'requiresAck': requiresAck,
        'keepaliveIntervalMs': keepaliveIntervalMs,
        'createdAt': createdAt.toIso8601String(),
      };

  factory WatchHardwareProfile.fromJson(Map<String, dynamic> json) {
    return WatchHardwareProfile(
      profileId: json['profileId'] as String? ?? 'unknown_profile',
      deviceName: json['deviceName'] as String? ?? 'Smartwatch',
      remoteId: json['remoteId'] as String? ?? '',
      protocolType: WatchProtocolType.values.firstWhere(
        (e) => e.name == json['protocolType'],
        orElse: () => WatchProtocolType.hiwatchCd,
      ),
      serviceUuid: json['serviceUuid'] as String? ?? '',
      writeCharUuid: json['writeCharUuid'] as String? ?? '',
      notifyCharUuid: json['notifyCharUuid'] as String? ?? '',
      handshakePacket: (json['handshakePacket'] as List?)?.cast<int>() ?? const [],
      rtcSyncPacket: (json['rtcSyncPacket'] as List?)?.cast<int>() ?? const [],
      stepQueryPacket: (json['stepQueryPacket'] as List?)?.cast<int>() ?? const [],
      hrTriggerPacket: (json['hrTriggerPacket'] as List?)?.cast<int>() ?? const [],
      bpTriggerPacket: (json['bpTriggerPacket'] as List?)?.cast<int>() ?? const [],
      requiresAck: json['requiresAck'] as bool? ?? true,
      keepaliveIntervalMs: json['keepaliveIntervalMs'] as int? ?? 3500,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  // ─── Persistence ───────────────────────────────────────────────────────────

  /// Persists this profile as the active smartwatch profile in SharedPreferences.
  Future<void> saveToPrefs({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(toJson());
    await p.setString(prefsActiveProfileKey, jsonStr);
    // Also update legacy watch name and remote ID keys for seamless compatibility
    await p.setString('ble_watch_name', deviceName);
    await p.setString('ble_watch_remote_id', remoteId);
  }

  /// Loads the currently active smartwatch profile from SharedPreferences.
  /// Falls back to null if no custom profile has been configured.
  static Future<WatchHardwareProfile?> loadFromPrefs({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final jsonStr = p.getString(prefsActiveProfileKey);
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      return null;
    }
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return WatchHardwareProfile.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Clears active profile from SharedPreferences.
  static Future<void> clearFromPrefs({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.remove(prefsActiveProfileKey);
  }
}
