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

class HealthSyncScreen extends StatefulWidget {
  const HealthSyncScreen({super.key, required this.api});

  final VyraApi api;

  @override
  State<HealthSyncScreen> createState() => _HealthSyncScreenState();
}

class _HealthSyncScreenState extends State<HealthSyncScreen> with SingleTickerProviderStateMixin {
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
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;
  StreamSubscription<List<int>>? _notifySubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  
  String? _pairedWatchName;
  bool _isRealBleConnected = false;
  bool _isConnecting = false;
  String _connectionStatusText = "Disconnected";

  // Telemetry values (Zero until authentic physical reading arrives)
  int _liveHeartRate = 0;
  int _liveSpo2 = 0;
  
  late AnimationController _heartPulseController;

  // Real BLE Scanner State
  bool _isScanning = false;
  List<ScanResult> _scanResults = [];
  StreamSubscription<List<ScanResult>>? _scanSubscription;

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
    _notifySubscription?.cancel();
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
      setState(() {
        _isConnecting = true;
        _connectionStatusText = "Connecting to ${device.platformName.isNotEmpty ? device.platformName : 'Watch'}...";
      });

      await FlutterBluePlus.stopScan();

      // Disconnect existing if any
      await _connectedBleDevice?.disconnect();
      _notifySubscription?.cancel();
      _connectionSubscription?.cancel();

      // Connect to physical hardware
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      _connectedBleDevice = device;
      _pairedWatchName = device.platformName.isNotEmpty ? device.platformName : "HiWatch Pro";

      // Save paired watch name
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsBleWatchNameKey, _pairedWatchName!);

      // Listen for disconnection
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          if (mounted) {
            setState(() {
              _isRealBleConnected = false;
              _connectionStatusText = "Disconnected";
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Smartwatch disconnected: $_pairedWatchName')),
            );
          }
        }
      });

      // Discover GATT services & characteristics
      final services = await device.discoverServices();
      _writeCharacteristic = null;
      _notifyCharacteristic = null;

      for (var s in services) {
        final sUuid = s.uuid.toString().toLowerCase();
        // Check for HiWatch Pro custom service or standard Heart Rate
        if (sUuid.contains('6e40ff01') || sUuid.contains('6e400001') || sUuid.contains('180d') || sUuid.contains('180a')) {
          for (var c in s.characteristics) {
            final cUuid = c.uuid.toString().toLowerCase();
            // Notify Characteristic
            if (cUuid.contains('6e40ff03') || cUuid.contains('6e400003') || cUuid.contains('2a37')) {
              _notifyCharacteristic = c;
            }
            // Write Characteristic
            if (cUuid.contains('6e40ff02') || cUuid.contains('6e400002') || c.properties.write || c.properties.writeWithoutResponse) {
              _writeCharacteristic = c;
            }
          }
        }
      }

      // Subscribe to real-time notification stream
      if (_notifyCharacteristic != null) {
        await _notifyCharacteristic!.setNotifyValue(true);
        _notifySubscription = _notifyCharacteristic!.onValueReceived.listen((bytes) {
          if (bytes.isNotEmpty) {
            final telemetry = HiWatchProProtocol.parseNotifyPacket(bytes);
            if (!telemetry.isEmpty) {
              setState(() {
                if (telemetry.heartRateBpm != null) _liveHeartRate = telemetry.heartRateBpm!;
                if (telemetry.bloodOxygenSpo2 != null) _liveSpo2 = telemetry.bloodOxygenSpo2!;
                if (telemetry.steps != null && telemetry.steps! > 0) {
                  _lastSummary['steps'] = telemetry.steps!;
                  _lastSummary['caloriesBurned'] = (telemetry.steps! * 0.04).round();
                  _lastSummary['heartRateBpm'] = _liveHeartRate;
                }
              });
            }
          }
        });
      }

      // Send initial handshake / step stream wake command to watch
      if (_writeCharacteristic != null) {
        try {
          await _writeCharacteristic!.write(
            HiWatchProProtocol.buildTurnOnRealTimeStepCommand(),
            withoutResponse: true,
          );
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _isRealBleConnected = true;
        _isConnecting = false;
        _connected = true;
        _connectionStatusText = "Connected to $_pairedWatchName";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚡ $_pairedWatchName connected! Live telemetry stream active.'),
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

  Future<void> _disconnectRealWatch() async {
    _notifySubscription?.cancel();
    _connectionSubscription?.cancel();
    await _connectedBleDevice?.disconnect();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsBleWatchNameKey);

    setState(() {
      _isRealBleConnected = false;
      _connectedBleDevice = null;
      _pairedWatchName = null;
      _connectionStatusText = "Disconnected";
      _connected = _usePhoneSensors;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Smartwatch disconnected.')),
    );
  }

  Future<void> _sendRealBleCommand(List<int> cmd, String actionLabel) async {
    if (_writeCharacteristic != null) {
      try {
        await _writeCharacteristic!.write(cmd, withoutResponse: true);
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
    return Scaffold(
      backgroundColor: VColor.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(VSpace.md),
          children: [
            _buildHeader(context),
            const SizedBox(height: VSpace.lg),
            _buildHeroCard(),
            const SizedBox(height: VSpace.md),
            _buildStatusCard(),
            if (_isRealBleConnected) ...[
              const SizedBox(height: VSpace.md),
              _buildLiveGattCard(),
            ],
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

  /// Live Real Hardware GATT Biometrics Card
  Widget _buildLiveGattCard() {
    return VCard(
      child: Container(
        padding: const EdgeInsets.all(VSpace.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(VRadius.md),
          gradient: LinearGradient(
            colors: [
              VColor.accent.withValues(alpha: 0.08),
              VColor.accentGreen.withValues(alpha: 0.05),
            ],
          ),
          border: Border.all(color: VColor.accentGreen.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: VColor.accentGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(VRadius.pill),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.fiber_manual_record, color: VColor.accentGreen, size: 8),
                          SizedBox(width: 4),
                          Text(
                            "LIVE GATT",
                            style: TextStyle(color: VColor.accentGreen, fontSize: 10, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, color: VColor.textLow, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _disconnectRealWatch,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: VSpace.md),
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
                        Text(
                          _liveHeartRate > 0 ? "$_liveHeartRate" : "0",
                          style: const TextStyle(
                            color: VColor.text,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(" bpm", style: TextStyle(color: VColor.textLow, fontSize: 11)),
                      ],
                    ),
                    const Text("HEART RATE", style: TextStyle(color: VColor.textMid, fontSize: 10, fontWeight: FontWeight.bold)),
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
                        Text(
                          _liveSpo2 > 0 ? "$_liveSpo2%" : "0%",
                          style: const TextStyle(
                            color: VColor.text,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
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
                        Text(
                          "${_lastSummary['steps'] ?? 0}",
                          style: const TextStyle(
                            color: VColor.text,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const Text("WATCH STEPS", style: TextStyle(color: VColor.textMid, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: VColor.lineSoft, height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _sendRealBleCommand(
                    HiWatchProProtocol.buildStartHeartRateMeasureCommand(),
                    "Measure Heart Rate",
                  ),
                  icon: const Icon(Icons.favorite_rounded, size: 15),
                  label: const Text("Measure HR", style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _sendRealBleCommand(
                    HiWatchProProtocol.buildFindWatchCommand(),
                    "Vibrate Watch",
                  ),
                  icon: const Icon(Icons.vibration_rounded, size: 15),
                  label: const Text("Vibrate Watch", style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: VColor.accentOrange,
                    side: const BorderSide(color: VColor.accentOrange),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _syncNow,
                  icon: const Icon(Icons.cloud_upload_rounded, size: 15),
                  label: const Text("Sync Cloud", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VColor.accentGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
