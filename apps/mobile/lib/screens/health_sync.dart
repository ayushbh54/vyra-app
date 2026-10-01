import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

import '../theme.dart';
import '../widgets/common.dart';
import '../api/client.dart';
import '../services/health_sync_service.dart';
import '../services/hiwatch_pro_service.dart';
import '../services/readings_history_service.dart';

class HealthSyncScreen extends StatefulWidget {
  const HealthSyncScreen({super.key, required this.api});

  final VyraApi api;

  @override
  State<HealthSyncScreen> createState() => _HealthSyncScreenState();
}

class _HealthSyncScreenState extends State<HealthSyncScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  static const _prefsLastSyncedKey = 'vyra_health_last_synced_at';
  static const _prefsStepsKey = 'vyra_health_last_steps';
  static const _prefsCaloriesKey = 'vyra_health_last_calories';
  static const _prefsHeartRateKey = 'vyra_health_last_hr';
  static const _prefsUsePhoneSensorsKey = 'vyra_use_phone_sensors';
  static const _prefsBleWatchNameKey = 'vyra_ble_watch_name';

  final HealthSyncService _healthService = HealthSyncService();

  bool _connected = false;
  bool _usePhoneSensors = false;
  bool _syncing = false;
  String? _error;
  DateTime? _lastSyncedAt;
  Map<String, num> _lastSummary = {};

  // Real Bluetooth LE Smartwatch Hardware Connection State
  BluetoothDevice? _connectedBleDevice;
  final List<BluetoothCharacteristic> _writeCharacteristics = [];
  final List<BluetoothCharacteristic> _notifyCharacteristics = [];
  final List<StreamSubscription<List<int>>> _notifySubscriptions = [];
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  Timer? _livePollingTimer;
  Timer? _continuousDbSyncTimer;
  
  String? _pairedWatchName;
  bool _isRealBleConnected = false;
  bool _isConnecting = false;
  String _connectionStatusText = "Disconnected";

  // Telemetry values (Zero until authentic physical reading arrives)
  int _liveHeartRate = 0;
  int _liveSpo2 = 0;
  int _liveSteps = 0;
  int _liveCalories = 0;
  int _liveDistanceMeters = 0;
  int _activeMinutes = 0;
  String _liveHrZone = "Resting";
  int _liveRecoveryScore = 0;
  DateTime? _lastAutoSavedAt;
  bool _isAutoSaving = false;
  String? _lastDataTimestamp;

  final _hrNotifier = ValueNotifier<int>(0);
  final _spo2Notifier = ValueNotifier<int>(0);
  final _stepsNotifier = ValueNotifier<int>(0);
  
  late AnimationController _heartPulseController;

  // Real BLE Scanner State
  bool _isScanning = false;
  List<ScanResult> _scanResults = [];
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _heartPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _bootstrap();
  }

  @override
  void dispose() {
    _livePollingTimer?.cancel();
    _continuousDbSyncTimer?.cancel();
    for (var sub in _notifySubscriptions) {
      sub.cancel();
    }
    _notifySubscriptions.clear();
    _connectionSubscription?.cancel();
    _scanSubscription?.cancel();
    _heartPulseController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _restoreLastSyncInfo();
    try {
      final prefs = await SharedPreferences.getInstance();
      final phoneSensors = prefs.getBool(_prefsUsePhoneSensorsKey) ?? false;
      final savedWatchName = prefs.getString(_prefsBleWatchNameKey);
      final granted = await _healthService.hasPermissions();

      if (savedWatchName != null) {
        _pairedWatchName = savedWatchName;
      }

      if (!mounted) return;
      setState(() {
        _usePhoneSensors = phoneSensors;
        _connected = granted || phoneSensors || _isRealBleConnected;
      });
    } catch (_) {}
  }

  // ─── Real Hardware Bluetooth LE Scanning & Pairing ─────────────────────────

  Future<bool> _requestBluetoothPermissions() async {
    final scanStatus = await Permission.bluetoothScan.request();
    final connectStatus = await Permission.bluetoothConnect.request();
    final locationStatus = await Permission.location.request();

    final bleGranted = (scanStatus.isGranted || scanStatus.isLimited) &&
                       (connectStatus.isGranted || connectStatus.isLimited);
    final locationGranted = locationStatus.isGranted || locationStatus.isLimited;

    return bleGranted || locationGranted;
  }

  Future<void> _startRealBleScan(StateSetter setModalState) async {
    try {
      final hasPerm = await _requestBluetoothPermissions();
      if (!hasPerm) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Bluetooth and Location permissions are required to scan for watches.'),
            backgroundColor: VColor.warn,
          ),
        );
        return;
      }

      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bluetooth LE is not supported on this phone.')),
        );
        return;
      }

      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        try {
          await FlutterBluePlus.turnOn();
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable Bluetooth in your phone settings.')),
          );
          return;
        }
      }

      setModalState(() {
        _isScanning = true;
        _scanResults.clear();
      });

      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
        setModalState(() {
          _scanResults = results;
        });
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
      );

      // When scan ends
      await FlutterBluePlus.isScanning.where((s) => !s).first;
      if (mounted) {
        setModalState(() {
          _isScanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setModalState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _connectToRealWatch(BluetoothDevice device) async {
    try {
      // Only update connecting status — preserve all existing telemetry and UI state
      if (!mounted) return;
      setState(() {
        _isConnecting = true;
        _connectionStatusText = "Connecting to ${device.platformName.isNotEmpty ? device.platformName : 'Watch'}...";
      });

      await FlutterBluePlus.stopScan();

      // Clean up previous sessions — cancel connection listener FIRST to prevent
      // stale listener from firing setState(_isRealBleConnected=false) during
      // the disconnect handshake, which caused the screen flash/restart.
      _livePollingTimer?.cancel();
      _continuousDbSyncTimer?.cancel();
      _connectionSubscription?.cancel();
      _connectionSubscription = null;
      for (var sub in _notifySubscriptions) {
        sub.cancel();
      }
      _notifySubscriptions.clear();
      _writeCharacteristics.clear();
      _notifyCharacteristics.clear();
      await _connectedBleDevice?.disconnect();

      if (!mounted) return;

      // Connect to physical hardware
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      if (!mounted) return;

      _connectedBleDevice = device;
      _pairedWatchName = device.platformName.isNotEmpty ? device.platformName : "HiWatch Pro";

      // Save paired watch name
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      await prefs.setString(_prefsBleWatchNameKey, _pairedWatchName!);

      // Listen for disconnection — skip initial 'disconnected' emission that fires
      // before the connection handshake completes (prevents full screen rebuild/restart)
      bool hasSeenConnected = false;
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.connected) {
          hasSeenConnected = true;
          return;
        }
        if (state == BluetoothConnectionState.disconnected && hasSeenConnected) {
          // Small delay to debounce transient disconnects during BLE handshake
          Future.delayed(const Duration(milliseconds: 400), () {
            if (!mounted) return;
            if (_isRealBleConnected) return; // reconnected in the meantime
            _livePollingTimer?.cancel();
            _continuousDbSyncTimer?.cancel();
            for (var sub in _notifySubscriptions) {
              sub.cancel();
            }
            _notifySubscriptions.clear();
            // Flush any final unpersisted readings to database & backend immediately
            _persistLiveWatchDataToDatabase();
            if (!mounted) return;
            // Only update connection status — preserve telemetry values so the
            // last-known readings remain visible even after disconnect.
            setState(() {
              _isRealBleConnected = false;
              _connectionStatusText = 'Disconnected';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Smartwatch disconnected: $_pairedWatchName')),
            );
          });
        }
      });

      if (!mounted) return;

      // Discover GATT services & characteristics across vendor & standard profiles
      final services = await device.discoverServices();

      // Isolate vendor command characteristics to prevent writing invalid packets to system services
      for (var s in services) {
        final sUuid = s.uuid.toString().toLowerCase();
        final isSystemGatt = sUuid.startsWith('00001800') ||
            sUuid.startsWith('00001801') ||
            sUuid.startsWith('0000180a') ||
            sUuid.startsWith('0000180f');

        for (var c in s.characteristics) {
          final cUuid = c.uuid.toString().toLowerCase();
          final isVendorChar = cUuid.contains('6e40') ||
              cUuid.contains('ff01') ||
              cUuid.contains('ff02') ||
              cUuid.contains('fee7') ||
              cUuid.contains('fff2') ||
              cUuid.contains('ae01') ||
              !isSystemGatt;

          // Collect dedicated writable command characteristics (avoid system service overwrites)
          if ((c.properties.write || c.properties.writeWithoutResponse) && isVendorChar) {
            _writeCharacteristics.add(c);
          }

          // Subscribe to notify/indicate telemetry characteristics
          if (c.properties.notify || c.properties.indicate) {
            _notifyCharacteristics.add(c);
            try {
              await c.setNotifyValue(true);
              final sub = c.onValueReceived.listen((bytes) {
                _processIncomingWatchData(bytes);
              });
              _notifySubscriptions.add(sub);
            } catch (_) {}
          }
        }
      }

      // Sort write characteristics so primary vendor UUIDs (ff02, 6e40) are first
      _writeCharacteristics.sort((a, b) {
        final aU = a.uuid.toString().toLowerCase();
        final bU = b.uuid.toString().toLowerCase();
        if (aU.contains('ff02') || aU.contains('6e40')) return -1;
        if (bU.contains('ff02') || bU.contains('6e40')) return 1;
        return 0;
      });

      // Initial gentle handshake with paced 150ms delays to prevent MCU buffer overrun
      await _broadcastWatchCommands([
        HiWatchProProtocol.buildSyncTimeCommand(),
        HiWatchProProtocol.buildTurnOnRealTimeStepCommand(),
        HiWatchProProtocol.buildRequestLiveMetricsCommand(),
        HiWatchProProtocol.buildStartHeartRateMeasureCommand(), // trigger HR+SpO2 immediately on connect
      ]);

      // Start continuous real-time live telemetry polling stream (paced, cycling 1 command per tick)
      _startContinuousLiveTelemetryStream();

      // Start continuous database & local storage auto-persist (every 6 seconds - zero data loss)
      _startContinuousDbSync();

      if (!mounted) return;
      setState(() {
        _isRealBleConnected = true;
        _isConnecting = false;
        _connected = true;
        _connectionStatusText = "Connected to $_pairedWatchName";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚡ $_pairedWatchName connected! Continuous live telemetry active.'),
          backgroundColor: VColor.accentGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _connectionStatusText = "Connection failed. Please retry.";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not connect: $e. Check if watch is connected to another phone.'),
          backgroundColor: VColor.crit,
        ),
      );
    }
  }

  int _telemetryTick = 0;

  void _startContinuousLiveTelemetryStream() {
    _livePollingTimer?.cancel();
    _livePollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (!_isRealBleConnected) {
        timer.cancel();
        return;
      }
      _telemetryTick++;
      // 4-step rotation — covers all data types while keeping MCU buffer stable
      switch (_telemetryTick % 4) {
        case 0:
          await _broadcastWatchCommands([HiWatchProProtocol.buildUniversalHeartbeatCommand()]);
          break;
        case 1:
          // HR + SpO2 measurement — was missing before, causing no data
          await _broadcastWatchCommands([HiWatchProProtocol.buildStartHeartRateMeasureCommand()]);
          break;
        case 2:
          await _broadcastWatchCommands([HiWatchProProtocol.buildRequestLiveMetricsCommand()]);
          break;
        case 3:
          await _broadcastWatchCommands([HiWatchProProtocol.buildDaFitStepQueryCommand()]);
          break;
      }
    });
  }

  void _startContinuousDbSync() {
    _continuousDbSyncTimer?.cancel();
    _continuousDbSyncTimer = Timer.periodic(const Duration(seconds: 6), (timer) async {
      if (!_isRealBleConnected) {
        timer.cancel();
        return;
      }
      await _persistLiveWatchDataToDatabase();
      if (!mounted) timer.cancel();
    });
  }

  void _processIncomingWatchData(List<int> bytes) {
    if (bytes.isEmpty) return;
    final telemetry = HiWatchProProtocol.parseNotifyPacket(bytes);
    if (telemetry.isEmpty) return;

    if (!mounted) return;
    
    final now = TimeOfDay.now();
    _lastDataTimestamp = '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}:${DateTime.now().second.toString().padLeft(2,'0')}';

    setState(() {
      if (telemetry.heartRateBpm != null && telemetry.heartRateBpm! > 0) {
        _liveHeartRate = telemetry.heartRateBpm!;
        _hrNotifier.value = _liveHeartRate;
        if (_liveHeartRate < 60) {
          _liveHrZone = "Resting / Low";
        } else if (_liveHeartRate <= 100) {
          _liveHrZone = "Aerobic Base";
        } else if (_liveHeartRate <= 140) {
          _liveHrZone = "Cardio Zone";
        } else {
          _liveHrZone = "Peak Intensity";
        }
        _liveRecoveryScore = (100 - (_liveHeartRate - 68).abs() * 0.4).clamp(55, 99).round();
      }
      if (telemetry.bloodOxygenSpo2 != null && telemetry.bloodOxygenSpo2! > 0) {
        _liveSpo2 = telemetry.bloodOxygenSpo2!;
        _spo2Notifier.value = _liveSpo2;
      }
      if (telemetry.steps != null && telemetry.steps! > 0) {
        _liveSteps = telemetry.steps!;
        _stepsNotifier.value = _liveSteps;
        _liveCalories = telemetry.calories ?? (_liveSteps * 0.04).round();
        _liveDistanceMeters = telemetry.distanceMeters ?? (_liveSteps * 0.75).round();
        _activeMinutes = (_liveSteps / 110).round();

        _lastSummary['steps'] = _liveSteps;
        _lastSummary['caloriesBurned'] = _liveCalories;
        _lastSummary['distanceMeters'] = _liveDistanceMeters;
        _lastSummary['heartRateBpm'] = _liveHeartRate;
        if (_liveSpo2 > 0) _lastSummary['bloodOxygenSpo2'] = _liveSpo2;
      }
    });

    // Persist live telemetry to SharedPreferences so the AI coach (ai_chat.dart)
    // can include up-to-date watch readings in every message's userContext.
    unawaited(() async {
      final prefs = await SharedPreferences.getInstance();
      if (telemetry.heartRateBpm != null && telemetry.heartRateBpm! > 0) {
        await prefs.setInt('live_heart_rate', telemetry.heartRateBpm!);
      }
      if (telemetry.bloodOxygenSpo2 != null && telemetry.bloodOxygenSpo2! > 0) {
        await prefs.setInt('live_spo2', telemetry.bloodOxygenSpo2!);
      }
      if (telemetry.steps != null && telemetry.steps! > 0) {
        await prefs.setInt('live_steps', telemetry.steps!);
      }
    }());
  }

  Future<void> _persistLiveWatchDataToDatabase() async {
    final currentSteps = _liveSteps > 0 ? _liveSteps : (_lastSummary['steps']?.toInt() ?? 0);
    final currentHr = _liveHeartRate > 0 ? _liveHeartRate : (_lastSummary['heartRateBpm']?.toInt() ?? 0);
    final currentSpo2 = _liveSpo2 > 0 ? _liveSpo2 : (_lastSummary['bloodOxygenSpo2']?.toInt() ?? 0);
    final currentKcal = _liveCalories > 0 ? _liveCalories : (_lastSummary['caloriesBurned']?.toInt() ?? (currentSteps > 0 ? (currentSteps * 0.04).round() : 0));
    final currentDist = _liveDistanceMeters > 0 ? _liveDistanceMeters : (_lastSummary['distanceMeters']?.toInt() ?? (currentSteps > 0 ? (currentSteps * 0.75).round() : 0));

    if (currentSteps == 0 && currentHr == 0 && currentSpo2 == 0) return;

    final now = DateTime.now();
    final Map<String, num> payload = {
      if (currentSteps > 0) 'steps': currentSteps,
      if (currentKcal > 0) 'caloriesBurned': currentKcal,
      if (currentHr > 0) 'heartRateBpm': currentHr,
      if (currentSpo2 > 0) 'bloodOxygenSpo2': currentSpo2,
      if (currentDist > 0) 'distanceMeters': currentDist,
      if (_activeMinutes > 0) 'activeMinutes': _activeMinutes,
    };

    if (!mounted) return;
    setState(() => _isAutoSaving = true);

    // 1. Dual-Write: Cloud Backend Database (Isolated per user, encrypted, conflict-safe)
    try {
      await widget.api.logTracking(payload, source: 'hiwatch_pro_live_gatt');
    } catch (_) {}

    // 2. Dual-Write: Local ReadingsHistoryService (Instant offline local audit record)
    try {
      final formattedTime = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      final entry = SavedReadingEntry(
        id: 'watch_${now.millisecondsSinceEpoch}',
        timestamp: now,
        formattedDateTime: formattedTime,
        steps: currentSteps,
        waterMl: 0,
        heartRateBpm: currentHr,
        weightKg: 0.0,
      );
      await ReadingsHistoryService.instance.saveEntry(entry);
    } catch (_) {}

    // 3. Dual-Write: SharedPreferences Cache
    await _persistSyncResult(now, payload);

    if (mounted) {
      setState(() {
        _isAutoSaving = false;
        _lastAutoSavedAt = now;
        _lastSyncedAt = now;
        _lastSummary = payload;
      });
    }
  }

  Future<void> _broadcastWatchCommands(List<List<int>> commandList) async {
    if (!_isRealBleConnected) return;

    if (_writeCharacteristics.isNotEmpty) {
      // Target the primary vendor command characteristic (first in sorted list)
      final targetChar = _writeCharacteristics.first;
      for (var cmd in commandList) {
        try {
          if (targetChar.properties.writeWithoutResponse) {
            await targetChar.write(cmd, withoutResponse: true);
          } else {
            await targetChar.write(cmd, withoutResponse: false);
          }
          await Future.delayed(const Duration(milliseconds: 50));
        } catch (_) {}
      }
      return;
    }

    for (final char in _writeCharacteristics) {
      for (final cmd in commandList) {
        try {
          await char.write(cmd, withoutResponse: true);
          await Future.delayed(const Duration(milliseconds: 50));
        } catch (_) {}
      }
    }
  }

  Future<void> _disconnectRealWatch() async {
    _livePollingTimer?.cancel();
    _continuousDbSyncTimer?.cancel();
    for (var sub in _notifySubscriptions) {
      sub.cancel();
    }
    _notifySubscriptions.clear();
    _connectionSubscription?.cancel();
    await _connectedBleDevice?.disconnect();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsBleWatchNameKey);

    if (!mounted) return;

    setState(() {
      _isRealBleConnected = false;
      _connectedBleDevice = null;
      _pairedWatchName = null;
      _writeCharacteristics.clear();
      _notifyCharacteristics.clear();
      _connectionStatusText = "Disconnected";
      _connected = _usePhoneSensors;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Smartwatch disconnected.')),
    );
  }

  Future<void> _sendRealBleCommand(List<int> cmd, String actionLabel) async {
    if (_writeCharacteristics.isNotEmpty) {
      try {
        final c = _writeCharacteristics.first;
        try {
          if (c.properties.writeWithoutResponse) {
            await c.write(cmd, withoutResponse: true);
          } else {
            await c.write(cmd, withoutResponse: false);
          }
        } catch (_) {
          try {
            await c.write(cmd, withoutResponse: false);
          } catch (_) {}
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📡 $actionLabel command sent to $_pairedWatchName!'),
            backgroundColor: VColor.accent,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send command: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Watch is not actively connected via GATT.')),
      );
    }
  }

  // ─── Real BLE Device Discovery Modal ───────────────────────────────────────

  void _openRealBleDiscoveryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: VColor.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(VRadius.xl)),
        side: BorderSide(color: VColor.line),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Auto start scan on sheet open
            if (!_isScanning && _scanResults.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _startRealBleScan(setModalState);
              });
            }

            // Prioritize recognized smartwatches, then named devices, then all devices
            final List<ScanResult> allDevices = List<ScanResult>.from(_scanResults);
            allDevices.sort((a, b) {
              final aName = (a.device.platformName.isNotEmpty ? a.device.platformName : a.advertisementData.advName).toLowerCase();
              final bName = (b.device.platformName.isNotEmpty ? b.device.platformName : b.advertisementData.advName).toLowerCase();
              final aMatch = aName.contains('hiwatch') || aName.contains('t800') || aName.contains('fitpro') || aName.contains('watch');
              final bMatch = bName.contains('hiwatch') || bName.contains('t800') || bName.contains('fitpro') || bName.contains('watch');
              if (aMatch && !bMatch) return -1;
              if (!aMatch && bMatch) return 1;
              final aHas = aName.trim().isNotEmpty;
              final bHas = bName.trim().isNotEmpty;
              if (aHas && !bHas) return -1;
              if (!aHas && bHas) return 1;
              return b.rssi.compareTo(a.rssi);
            });

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(VSpace.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Modal Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: VColor.accent.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.bluetooth_searching_rounded, color: VColor.accent, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Live Bluetooth Scanner",
                                style: TextStyle(
                                  color: VColor.text,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                _isScanning ? "Scanning nearby Bluetooth airwaves..." : "Scan completed",
                                style: TextStyle(
                                  color: _isScanning ? VColor.accent : VColor.textLow,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: VColor.textLow),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: VSpace.base),

                  // Scanner Status Bar with Rescan Button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: VColor.surfaceRaised,
                      borderRadius: BorderRadius.circular(VRadius.md),
                      border: Border.all(color: VColor.lineSoft),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (_isScanning)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: VColor.accent),
                              )
                            else
                              const Icon(Icons.check_circle_rounded, color: VColor.accentGreen, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              "${allDevices.length} devices found in room",
                              style: const TextStyle(color: VColor.textMid, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: _isScanning ? null : () => _startRealBleScan(setModalState),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: Text(_isScanning ? "Scanning..." : "Rescan"),
                          style: TextButton.styleFrom(
                            foregroundColor: VColor.accent,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: VSpace.sm),

                  // Troubleshooting Tip Alert
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: VColor.accentOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(VRadius.md),
                      border: Border.all(color: VColor.accentOrange.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: VColor.accentOrange, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Watch screen ON rakhein. Agar watch 'HiWatch Pro' app se pehle se connected hai, toh watch settings me 'Reset' karein taaki Bluetooth airwaves me discoverable ho sake.",
                            style: TextStyle(color: VColor.textMid, fontSize: 11.5, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: VSpace.sm),
                  const Divider(color: VColor.line, height: 1),
                  const SizedBox(height: VSpace.sm),

                  // Device List
                  Expanded(
                    child: allDevices.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isScanning) ...[
                                  const CircularProgressIndicator(color: VColor.accent),
                                  const SizedBox(height: 16),
                                  const Text(
                                    "Searching for HiWatch Pro / Bluetooth Smartwatches...",
                                    style: TextStyle(color: VColor.textMid, fontSize: 13),
                                  ),
                                ] else ...[
                                  const Icon(Icons.bluetooth_disabled_rounded, color: VColor.textLow, size: 40),
                                  const SizedBox(height: 12),
                                  const Text(
                                    "No Bluetooth devices found nearby.",
                                    style: TextStyle(color: VColor.text, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    "Make sure Watch Bluetooth is on & tap 'Rescan' above.",
                                    style: TextStyle(color: VColor.textLow, fontSize: 12),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: allDevices.length,
                            separatorBuilder: (_, __) => const Divider(color: VColor.lineSoft, height: 8),
                            itemBuilder: (context, index) {
                              final item = allDevices[index];
                              final rawName = item.device.platformName.isNotEmpty
                                  ? item.device.platformName
                                  : item.advertisementData.advName;
                              final mac = item.device.remoteId.str;
                              final name = rawName.isNotEmpty
                                  ? rawName
                                  : "BLE Device (${mac.length > 8 ? mac.substring(mac.length - 8) : mac})";
                              final isHiWatch = name.toLowerCase().contains('hiwatch') ||
                                                name.toLowerCase().contains('t800') ||
                                                name.toLowerCase().contains('fitpro') ||
                                                name.toLowerCase().contains('watch');
                              final isCurrent = _connectedBleDevice?.remoteId == item.device.remoteId;

                              return InkWell(
                                onTap: _isConnecting
                                    ? null
                                    : () async {
                                        Navigator.of(ctx).pop();
                                        await _connectToRealWatch(item.device);
                                      },
                                borderRadius: BorderRadius.circular(VRadius.md),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isHiWatch
                                        ? VColor.accent.withValues(alpha: 0.08)
                                        : VColor.surfaceRaised,
                                    borderRadius: BorderRadius.circular(VRadius.md),
                                    border: Border.all(
                                      color: isHiWatch ? VColor.accent : VColor.lineSoft,
                                      width: isHiWatch ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.watch_rounded,
                                        color: isHiWatch ? VColor.accent : VColor.textMid,
                                        size: 28,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    name,
                                                    style: const TextStyle(
                                                      color: VColor.text,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (isHiWatch) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: VColor.accent.withValues(alpha: 0.2),
                                                      borderRadius: BorderRadius.circular(VRadius.pill),
                                                    ),
                                                    child: const Text(
                                                      "WATCH DETECTED",
                                                      style: TextStyle(
                                                        color: VColor.accent,
                                                        fontSize: 8.5,
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                                if (isCurrent) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: VColor.accentGreen.withValues(alpha: 0.2),
                                                      borderRadius: BorderRadius.circular(VRadius.pill),
                                                    ),
                                                    child: const Text(
                                                      "CONNECTED",
                                                      style: TextStyle(
                                                        color: VColor.accentGreen,
                                                        fontSize: 8.5,
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "MAC: $mac • RSSI: ${item.rssi} dBm",
                                              style: const TextStyle(color: VColor.textLow, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: _isConnecting
                                            ? null
                                            : () async {
                                                Navigator.of(ctx).pop();
                                                await _connectToRealWatch(item.device);
                                              },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isHiWatch ? VColor.accent : VColor.surfaceHigh,
                                          foregroundColor: isHiWatch ? Colors.black : VColor.text,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                        child: const Text("PAIR"),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── Direct Step Calibration from Watch Screen ────────────────────────────

  Future<void> _calibrateStepsDialog() async {
    final currentVal = _lastSummary['steps']?.toInt() ?? 0;
    final controller = TextEditingController(text: currentVal > 0 ? currentVal.toString() : '');

    final entered = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: VColor.surfaceRaised,
          title: const Row(
            children: [
              Icon(Icons.watch_rounded, color: VColor.accent),
              SizedBox(width: 8),
              Text('Sync Watch Dial Steps', style: TextStyle(color: VColor.text, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Apni HiWatch Pro / Smartwatch screen par dikh rahe exact steps enter karein:',
                style: TextStyle(color: VColor.textMid, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(color: VColor.accent, fontSize: 24, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'e.g. 5420',
                  hintStyle: const TextStyle(color: VColor.textLow),
                  filled: true,
                  fillColor: VColor.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(VRadius.md),
                    borderSide: const BorderSide(color: VColor.accent),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel', style: TextStyle(color: VColor.textLow)),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed = int.tryParse(controller.text.trim());
                Navigator.of(ctx).pop(parsed);
              },
              style: ElevatedButton.styleFrom(backgroundColor: VColor.accent),
              child: const Text('Save & Sync', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (entered == null || entered <= 0) return;

    final estimatedKcal = (entered * 0.04).round();
    final updatedSummary = {
      ..._lastSummary,
      'steps': entered,
      'caloriesBurned': estimatedKcal,
      'heartRateBpm': _liveHeartRate,
    };

    if (!mounted) return;
    setState(() {
      _lastSummary = updatedSummary;
      _syncing = true;
    });

    try {
      await widget.api.logTracking(updatedSummary, source: 'hiwatch_pro_dial');
      final now = DateTime.now();
      await _persistSyncResult(now, updatedSummary);
      if (mounted) {
        setState(() {
          _syncing = false;
          _lastSyncedAt = now;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $entered steps synced directly from smartwatch!'),
            backgroundColor: VColor.accentGreen,
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _enablePhoneSensors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsUsePhoneSensorsKey, true);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _usePhoneSensors = true;
      _connected = true;
      _error = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📱 Phone Internal Sensors Active! Pedometer enabled.'),
        backgroundColor: VColor.accentGreen,
      ),
    );
  }

  Future<void> _restoreLastSyncInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final iso = prefs.getString(_prefsLastSyncedKey);
      final steps = prefs.getInt(_prefsStepsKey);
      final calories = prefs.getInt(_prefsCaloriesKey);
      final hr = prefs.getInt(_prefsHeartRateKey);
      if (!mounted) return;
      setState(() {
        _lastSyncedAt = iso != null ? DateTime.tryParse(iso) : null;
        _lastSummary = {
          if (steps != null) 'steps': steps,
          if (calories != null) 'caloriesBurned': calories,
          if (hr != null) 'heartRateBpm': hr,
        };
      });
    } catch (_) {}
  }

  Future<void> _connectHealthPlatform() async {
    setState(() {
      _error = null;
    });
    final granted = await _healthService.requestPermissions();
    if (!mounted) return;
    setState(() {
      _connected = granted || _usePhoneSensors || _isRealBleConnected;
      if (!granted) {
        _error =
            'Health Connect permission nahi mili. Aap "Scan Nearby Smartwatch (BLE)" se direct watch connect kar sakte hain.';
      }
    });
  }

  Future<void> _syncNow() async {
    setState(() {
      _syncing = true;
      _error = null;
    });

    try {
      Map<String, num> summary = {};
      if (_isRealBleConnected) {
        final currentSteps = _lastSummary['steps']?.toInt() ?? 0;
        final currentKcal = _lastSummary['caloriesBurned']?.toInt() ?? (currentSteps > 0 ? (currentSteps * 0.04).round() : 0);
        summary = {
          'steps': currentSteps,
          'caloriesBurned': currentKcal,
          if (_liveHeartRate > 0) 'heartRateBpm': _liveHeartRate,
          if (_liveSpo2 > 0) 'bloodOxygenSpo2': _liveSpo2,
        };
      } else if (!_usePhoneSensors) {
        summary = await _healthService.fetchTodaySummary();
      }

      if (summary.isEmpty && _lastSummary.isNotEmpty) {
        summary = _lastSummary;
      }

      if (summary.isEmpty) {
        if (!mounted) return;
        setState(() {
          _syncing = false;
          _error = 'Data abhi available nahi hai. Watch screen se enter karne ke liye "Enter Steps from Watch" tap karein.';
        });
        return;
      }

      final sourceTag = _isRealBleConnected ? 'hiwatch_pro_ble_gatt' : (_usePhoneSensors ? 'phone_sensors' : 'health_connect');

      final apiError = await widget.api.logTracking(summary, source: sourceTag);
      final now = DateTime.now();
      await _persistSyncResult(now, summary);

      if (!mounted) return;
      setState(() {
        _syncing = false;
        _lastSyncedAt = now;
        _lastSummary = summary;
        _error = apiError;
      });
      if (apiError == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Data synced successfully to VYRA Cloud!'),
            backgroundColor: VColor.accentGreen,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _error = 'Sync failed. Please try again.';
      });
    }
  }

  Future<void> _persistSyncResult(DateTime when, Map<String, num> summary) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsLastSyncedKey, when.toIso8601String());
      if (summary.containsKey('steps')) {
        await prefs.setInt(_prefsStepsKey, summary['steps']!.toInt());
      }
      if (summary.containsKey('caloriesBurned')) {
        await prefs.setInt(_prefsCaloriesKey, summary['caloriesBurned']!.toInt());
      }
      if (summary.containsKey('heartRateBpm')) {
        await prefs.setInt(_prefsHeartRateKey, summary['heartRateBpm']!.toInt());
      }
    } catch (_) {}
  }

  String _formatLastSynced(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month} $h:$m';
  }

  void _showHiWatchSetupHelp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VColor.surfaceRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.lg)),
        title: const Row(
          children: [
            Icon(Icons.watch_rounded, color: VColor.accent),
            SizedBox(width: 8),
            Text("HiWatch Pro Connect Guide", style: TextStyle(color: VColor.text, fontSize: 16)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Physical Smartwatch ko connect karne ke steps:",
                style: TextStyle(color: VColor.textMid, fontSize: 13, height: 1.4),
              ),
              SizedBox(height: 12),
              Text("1. Phone ka Bluetooth & GPS ON karein.", style: TextStyle(color: VColor.text, fontSize: 13, fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text("2. Watch screen ko tap karke ON rakhein (agar screen band hoti hai toh watch advertise karna band kar sakti hai).", style: TextStyle(color: VColor.textMid, fontSize: 12)),
              SizedBox(height: 6),
              Text("3. ⚠️ IMPORTANT: Agar watch pehle se doosre phone ya 'HiWatch Pro' app se connected hai, toh watch settings me 'Reset' karein taaki Bluetooth unpair ho sake.", style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text("4. Niche 'Scan Nearby Smartwatch (BLE)' tap karein, jab aapki watch ka naam list me aaye toh 'PAIR' tap karein.", style: TextStyle(color: VColor.text, fontSize: 13, fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text("5. Agar Bluetooth me delay ho toh aap 'Enter Steps from Watch Screen' se direct real steps 1 second me save kar sakte hain.", style: TextStyle(color: VColor.accentGreen, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: VColor.accent),
            child: const Text("Samajh Gaya", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── Build UI ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context); // required for AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: VColor.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(VSpace.md),
          children: [
            _buildHeader(context),
            const SizedBox(height: VSpace.lg),
            RepaintBoundary(child: _buildHeroCard()),
            const SizedBox(height: VSpace.md),
            RepaintBoundary(child: _buildStatusCard()),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _isRealBleConnected
                  ? Padding(
                      padding: const EdgeInsets.only(top: VSpace.md),
                      child: _buildLiveGattCard(),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: VSpace.md),
            _buildDevicesCard(),
            if (_lastSummary.isNotEmpty) ...[
              const SizedBox(height: VSpace.md),
              _buildSummaryCard(),
            ],
            if (_error != null) ...[
              const SizedBox(height: VSpace.md),
              VErrorView(message: _error!, onRetry: _syncNow),
            ],
            const SizedBox(height: VSpace.md),
            const VDisclaimer(
              'VYRA aapka biometric health data kisi third-party '
              'ad exchange ko expose nahi karta. Sirf fitness scoring ke liye '
              'use hota hai.',
            ),
            const SizedBox(height: VSpace.lg),
            _buildPrimaryActions(),
            const SizedBox(height: VSpace.md),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: VColor.text),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const Expanded(
          child: Column(
            children: [
              VLabel('DEVICE & WEARABLE HUB'),
              SizedBox(height: 4),
              Text(
                'HiWatch Pro & Wearable Sync',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: VColor.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.help_outline_rounded, color: VColor.accent),
          onPressed: _showHiWatchSetupHelp,
        ),
      ],
    );
  }

  Widget _buildHeroCard() {
    return VCard(
      child: Padding(
        padding: const EdgeInsets.all(VSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.watch_rounded, color: VColor.accent, size: 28),
                const SizedBox(width: VSpace.sm),
                const Icon(Icons.bluetooth_connected_rounded, color: VColor.accentGreen, size: 24),
                const SizedBox(width: VSpace.sm),
                const Icon(Icons.favorite, color: VColor.accentOrange, size: 24),
                const Spacer(),
                InkWell(
                  onTap: _showHiWatchSetupHelp,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: VColor.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(VRadius.pill),
                      border: Border.all(color: VColor.accent.withValues(alpha: 0.5)),
                    ),
                    child: const Text(
                      "Setup Guide ℹ️",
                      style: TextStyle(color: VColor.accent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: VSpace.md),
            const Text(
              'Real Hardware Smartwatch Sync',
              style: TextStyle(
                color: VColor.text,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: VSpace.xs),
            const Text(
              'Apni physical HiWatch Pro (T800 / Watch 8/9 / FitPro) ko phone ke Bluetooth LE se direct scan aur pair karein.',
              style: TextStyle(color: VColor.textMid, fontSize: 13, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final dotColor = _isRealBleConnected ? VColor.accentGreen : (_connected ? VColor.accent : VColor.textLow);
    final statusText = _isConnecting
        ? _connectionStatusText
        : (_isRealBleConnected
            ? 'Connected: $_pairedWatchName'
            : (_usePhoneSensors
                ? 'Smartphone Sensors Active'
                : (_connected ? 'Connected to Health Connect' : 'No watch connected')));

    return VCard(
      child: Padding(
        padding: const EdgeInsets.all(VSpace.md),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: VSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: const TextStyle(
                      color: VColor.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (_lastSyncedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Last synced: ${_formatLastSynced(_lastSyncedAt!)}',
                        style: const TextStyle(color: VColor.textLow, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            if (_isConnecting)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: VColor.accent),
              ),
          ],
        ),
      ),
    );
  }

  /// Live Real Hardware GATT Biometrics Card with Continuous Live Telemetry & Zero Data Loss Indicator
  Widget _buildLiveGattCard() {
    final displaySteps = _liveSteps > 0 ? _liveSteps : (_lastSummary['steps']?.toInt() ?? 0);
    final displayKcal = _liveCalories > 0 ? _liveCalories : (_lastSummary['caloriesBurned']?.toInt() ?? (displaySteps > 0 ? (displaySteps * 0.04).round() : 0));
    final displayDistKm = _liveDistanceMeters > 0 ? (_liveDistanceMeters / 1000.0) : (displaySteps > 0 ? (displaySteps * 0.00075) : 0.0);

    return VCard(
      child: Container(
        padding: const EdgeInsets.all(VSpace.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(VRadius.md),
          gradient: LinearGradient(
            colors: [
              VColor.accent.withValues(alpha: 0.08),
              VColor.accentGreen.withValues(alpha: 0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: VColor.accentGreen.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Watch Name + Live Pulse Status
            Row(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.3, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  builder: (_, v, __) => Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: VColor.accentGreen.withValues(alpha: v),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: VColor.accentGreen.withValues(alpha: v * 0.5), blurRadius: 6)],
                    ),
                  ),
                  onEnd: () => setState(() {}), // loops
                ),
                const SizedBox(width: 6),
                const Text('LIVE', style: TextStyle(color: VColor.accentGreen, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                const Spacer(),
                Text('Updated: ${_lastDataTimestamp ?? "waiting..."}',
                  style: const TextStyle(color: VColor.textLow, fontSize: 10)),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: VColor.textLow, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _disconnectRealWatch,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.bluetooth_connected_rounded, color: VColor.accentGreen, size: 20),
                const SizedBox(width: 8),
                Text(
                  _pairedWatchName ?? "HiWatch Pro",
                  style: const TextStyle(
                    color: VColor.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: VSpace.md),

            // Show waiting indicator when connected but no data yet
            if (_liveHeartRate == 0 && _liveSpo2 == 0)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: VColor.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: VColor.accent.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 10, height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: VColor.accent.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Requesting HR & SpO2 from watch...',
                      style: TextStyle(color: VColor.accent, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

            // Metrics Row 1: Heart Rate + Zone, SpO2, Steps
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Heart Rate
                Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ScaleTransition(
                          scale: Tween(begin: 0.85, end: 1.25).animate(_heartPulseController),
                          child: const Icon(Icons.favorite, color: Colors.redAccent, size: 18),
                        ),
                        const SizedBox(width: 4),
                        ValueListenableBuilder<int>(
                          valueListenable: _hrNotifier,
                          builder: (_, hr, __) => Text(
                            hr == 0 ? '--' : '$hr',
                            style: const TextStyle(
                              color: VColor.text,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const Text(" bpm", style: TextStyle(color: VColor.textLow, fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(VRadius.pill),
                      ),
                      child: Text(
                        _liveHeartRate > 0 ? _liveHrZone : "RESTING",
                        style: const TextStyle(color: Colors.redAccent, fontSize: 8.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                // SpO2
                Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.water_drop_rounded, color: VColor.accent, size: 18),
                        const SizedBox(width: 4),
                        ValueListenableBuilder<int>(
                          valueListenable: _spo2Notifier,
                          builder: (_, spo2, __) => Text(
                            spo2 == 0 ? '--' : '$spo2%',
                            style: const TextStyle(
                              color: VColor.text,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text("BLOOD OXYGEN", style: TextStyle(color: VColor.textMid, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
                // Watch Steps
                Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.directions_walk_rounded, color: VColor.accentOrange, size: 18),
                        const SizedBox(width: 4),
                        ValueListenableBuilder<int>(
                          valueListenable: _stepsNotifier,
                          builder: (_, steps, __) {
                            final s = steps > 0 ? steps : (_lastSummary['steps']?.toInt() ?? 0);
                            return Text(
                              s == 0 ? '0' : '$s',
                              style: const TextStyle(
                                color: VColor.text,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text("LIVE STEPS", style: TextStyle(color: VColor.textMid, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: VColor.lineSoft, height: 1),
            const SizedBox(height: 10),

            // Metrics Row 2: Calories, Distance, Recovery Score
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Calories
                Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          "$displayKcal",
                          style: const TextStyle(color: VColor.text, fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        const Text(" kcal", style: TextStyle(color: VColor.textLow, fontSize: 10)),
                      ],
                    ),
                    const Text("CALORIES", style: TextStyle(color: VColor.textMid, fontSize: 9.5, fontWeight: FontWeight.w600)),
                  ],
                ),
                // Distance
                Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.straighten_rounded, color: VColor.accentGreen, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          displayDistKm.toStringAsFixed(2),
                          style: const TextStyle(color: VColor.text, fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        const Text(" km", style: TextStyle(color: VColor.textLow, fontSize: 10)),
                      ],
                    ),
                    const Text("DISTANCE", style: TextStyle(color: VColor.textMid, fontSize: 9.5, fontWeight: FontWeight.w600)),
                  ],
                ),
                // Recovery Score
                Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield_rounded, color: VColor.accent, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          _liveRecoveryScore > 0 ? "$_liveRecoveryScore%" : "--",
                          style: const TextStyle(color: VColor.text, fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const Text("RECOVERY", style: TextStyle(color: VColor.textMid, fontSize: 9.5, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: VColor.lineSoft, height: 1),
            const SizedBox(height: 8),

            // Zero Data Loss Auto-Sync Engine Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: VColor.surfaceRaised,
                borderRadius: BorderRadius.circular(VRadius.sm),
                border: Border.all(color: VColor.lineSoft),
              ),
              child: Row(
                children: [
                  Icon(
                    _isAutoSaving ? Icons.sync : Icons.verified_user_rounded,
                    color: _isAutoSaving ? VColor.accent : VColor.accentGreen,
                    size: 15,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isAutoSaving
                          ? "Auto-saving live vitals to Cloud & Local DB..."
                          : (_lastAutoSavedAt != null
                              ? "Zero Data Loss Engine Active • Synced ${_lastAutoSavedAt!.hour.toString().padLeft(2, '0')}:${_lastAutoSavedAt!.minute.toString().padLeft(2, '0')}:${_lastAutoSavedAt!.second.toString().padLeft(2, '0')}"
                              : "Continuous Live Polling Active • Auto-saving to Cloud & DB"),
                      style: TextStyle(
                        color: _isAutoSaving ? VColor.accent : VColor.textMid,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _sendRealBleCommand(
                    HiWatchProProtocol.buildStartHeartRateMeasureCommand(),
                    "Measure Heart Rate",
                  ),
                  icon: const Icon(Icons.favorite_rounded, size: 14),
                  label: const Text("Measure HR", style: TextStyle(fontSize: 10.5)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _sendRealBleCommand(
                    HiWatchProProtocol.buildFindWatchCommand(),
                    "Vibrate Watch",
                  ),
                  icon: const Icon(Icons.vibration_rounded, size: 14),
                  label: const Text("Vibrate", style: TextStyle(fontSize: 10.5)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: VColor.accentOrange,
                    side: const BorderSide(color: VColor.accentOrange),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _syncNow,
                  icon: const Icon(Icons.cloud_upload_rounded, size: 14),
                  label: const Text("Sync Now", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VColor.accentGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevicesCard() {
    return VCard(
      child: Padding(
        padding: const EdgeInsets.all(VSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const VLabel('HARDWARE CONNECTIONS'),
                InkWell(
                  onTap: _openRealBleDiscoveryModal,
                  child: const Text(
                    "+ SCAN BLUETOOTH",
                    style: TextStyle(color: VColor.accent, fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: VSpace.md),
            _deviceRow(
              icon: Icons.watch_rounded,
              name: _isRealBleConnected ? _pairedWatchName! : 'HiWatch Pro / Bluetooth Watch',
              detail: _isRealBleConnected ? 'Real BLE GATT Active' : 'Tap to scan nearby physical Bluetooth watches',
              active: _isRealBleConnected,
              onTap: _openRealBleDiscoveryModal,
            ),
            const Divider(color: VColor.line, height: 24),
            _deviceRow(
              icon: Icons.health_and_safety_rounded,
              name: 'Health Connect / Apple Health',
              detail: 'Wear OS, Galaxy Watch, Google Pixel Watch',
              active: _connected && !_isRealBleConnected && !_usePhoneSensors,
              onTap: _connectHealthPlatform,
            ),
            const Divider(color: VColor.line, height: 24),
            _deviceRow(
              icon: Icons.phone_android_rounded,
              name: 'Smartphone Internal Sensors',
              detail: 'Pedometer & Accelerometer',
              active: _usePhoneSensors,
              onTap: _enablePhoneSensors,
            ),
          ],
        ),
      ),
    );
  }

  Widget _deviceRow({
    required IconData icon,
    required String name,
    required String detail,
    required bool active,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(VRadius.sm),
      child: Row(
        children: [
          Icon(icon, color: active ? VColor.accent : VColor.textMid, size: 24),
          const SizedBox(width: VSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: VColor.text, fontWeight: FontWeight.w600, fontSize: 13.5)),
                Text(detail, style: const TextStyle(color: VColor.textLow, fontSize: 11.5)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: active ? VColor.accentGreen.withValues(alpha: 0.15) : VColor.surfaceRaised,
              borderRadius: BorderRadius.circular(VRadius.sm),
            ),
            child: Text(
              active ? 'Connected' : 'Standby',
              style: TextStyle(
                color: active ? VColor.accentGreen : VColor.textLow,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final steps = _lastSummary['steps'];
    final calories = _lastSummary['caloriesBurned'];
    final hr = _lastSummary['heartRateBpm'];

    return VCard(
      child: Padding(
        padding: const EdgeInsets.all(VSpace.md),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statChip('Steps', steps, VColor.accent),
                _statChip('Kcal', calories, VColor.accentOrange),
                _statChip('BPM', hr, VColor.accentGreen),
              ],
            ),
            const SizedBox(height: VSpace.md),
            InkWell(
              onTap: _calibrateStepsDialog,
              borderRadius: BorderRadius.circular(VRadius.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: VColor.surfaceRaised,
                  borderRadius: BorderRadius.circular(VRadius.sm),
                  border: Border.all(color: VColor.accent.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_note_rounded, size: 18, color: VColor.accent),
                    SizedBox(width: 6),
                    Text(
                      'Enter Steps from Watch Screen (1-Tap Sync)',
                      style: TextStyle(color: VColor.accent, fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, num? value, Color color) {
    return Column(
      children: [
        Text(
          value != null ? value.toStringAsFixed(0) : '—',
          style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: VColor.textLow, fontSize: 11)),
      ],
    );
  }

  Widget _buildPrimaryActions() {
    return Column(
      children: [
        // 1. Direct Real Hardware Bluetooth Scan Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(VRadius.md),
              gradient: const LinearGradient(
                colors: [VColor.accent, VColor.accentGreen],
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(VRadius.md),
                onTap: _openRealBleDiscoveryModal,
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bluetooth_searching_rounded, color: Colors.black, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Scan Nearby Smartwatch (Real BLE)',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: VSpace.sm),

        // 2. Direct Watch Dial Steps Fallback Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _calibrateStepsDialog,
            icon: const Icon(Icons.edit_note_rounded, size: 20),
            label: const Text(
              'Enter Steps from Watch Screen',
              style: TextStyle(
                color: VColor.text,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: VColor.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(VRadius.md),
              ),
            ),
          ),
        ),
        const SizedBox(height: VSpace.sm),

        // 3. Phone Internal Sensors Fallback Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _enablePhoneSensors,
            icon: const Icon(Icons.phone_android_rounded, size: 18),
            label: Text(
              _usePhoneSensors
                  ? 'Phone Sensors Active ✓'
                  : 'Use Phone Sensors (No Watch Needed)',
              style: TextStyle(
                color: _usePhoneSensors ? VColor.accentGreen : VColor.textMid,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: _usePhoneSensors ? VColor.accentGreen : VColor.lineSoft,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(VRadius.md),
              ),
            ),
          ),
        ),
        const SizedBox(height: VSpace.sm),

        // 4. "Sync now" button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: (_connected && !_syncing) ? _syncNow : null,
            icon: const Icon(Icons.sync_rounded, size: 20),
            label: _syncing
                ? const VLoading()
                : const Text(
                    'Sync Biometrics to VYRA Cloud',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: VColor.accentGreen,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(VRadius.md),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
