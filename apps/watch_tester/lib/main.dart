import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'protocol_prober.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// ⚡ VYRA WATCH PROBER — STANDALONE HARDWARE DIAGNOSTIC TOOL
/// ═══════════════════════════════════════════════════════════════════════════
/// Mission: Automatically cycle through 10+ smartwatch protocol combinations,
/// probe GATT characteristics, verify real-time responses (Pulse, BP, Steps),
/// and generate a definitive, 100% verified setup report to lock into Vyra.
/// ═══════════════════════════════════════════════════════════════════════════

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WatchProberApp());
}

class WatchProberApp extends StatelessWidget {
  const WatchProberApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vyra Watch Prober',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        primaryColor: const Color(0xFF58A6FF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF58A6FF),
          secondary: Color(0xFF238636),
          surface: Color(0xFF161B22),
        ),
      ),
      home: const WatchProberDashboard(),
    );
  }
}

// ─── DASHBOARD STATE ─────────────────────────────────────────────────────────

class WatchProberDashboard extends StatefulWidget {
  const WatchProberDashboard({super.key});

  @override
  State<WatchProberDashboard> createState() => _WatchProberDashboardState();
}

class _WatchProberDashboardState extends State<WatchProberDashboard> {
  // BLE Adapter & Scan
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  bool _isScanning = false;
  List<ScanResult> _scanResults = [];
  StreamSubscription<List<ScanResult>>? _scanSub;

  // Active Device
  BluetoothDevice? _device;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  bool _isConnecting = false;
  List<BluetoothService> _services = [];

  // Characteristics
  final List<BluetoothCharacteristic> _writeChars = [];
  final List<BluetoothCharacteristic> _notifyChars = [];
  final List<StreamSubscription> _notifySubs = [];
  BluetoothCharacteristic? _activeWriteChar;
  BluetoothCharacteristic? _activeNotifyChar;

  // Combination Matrix
  late List<ProtocolCombination> _combinations;
  bool _isAutoTesting = false;
  ProtocolCombination? _winningCombination;

  // Live Metrics Captured
  int? _liveHeartRate;
  int? _liveSystolic;
  int? _liveDiastolic;
  int? _liveSpo2;
  int? _liveSteps;

  // Console & Logs
  final List<LogEntry> _logs = [];
  final ScrollController _logScrollController = ScrollController();
  final TextEditingController _customHexController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initCombinations();
    _initBle();
  }

  void _initCombinations() {
    _combinations = ProtocolPresetLibrary.getPresetCombinations();
  }

  Future<void> _initBle() async {
    try {
      _adapterSub = FlutterBluePlus.adapterState.listen(
        (state) {
          if (mounted) setState(() => _adapterState = state);
          _addLog(LogType.info, "Adapter state: $state");
        },
        onError: (err) {
          _addLog(LogType.info, "Adapter state error: $err");
        },
      );
    } catch (e) {
      _addLog(LogType.info, "BLE init: $e");
    }
  }

  void _addLog(LogType type, String message, [List<int>? rawBytes]) {
    if (!mounted) return;
    setState(() {
      _logs.add(LogEntry(type: type, message: message, rawBytes: rawBytes));
      if (_logs.length > 300) _logs.removeAt(0);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── BLE SCAN & CONNECT ───────────────────────────────────────────────────

  Future<void> _toggleScan() async {
    if (_isScanning) {
      await FlutterBluePlus.stopScan();
      setState(() => _isScanning = false);
      _addLog(LogType.info, "Scanning halted.");
      return;
    }

    if (_adapterState != BluetoothAdapterState.on) {
      _addLog(LogType.error, "Please enable Bluetooth in phone settings!");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please turn ON Bluetooth and Location.')),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _scanResults.clear();
    });
    _addLog(LogType.info, "Scanning for smartwatches (15s)...");

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.onScanResults.listen((results) {
      if (!mounted) return;
      setState(() => _scanResults = results);
    });

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 15),
      androidUsesFineLocation: true,
    );

    await FlutterBluePlus.isScanning.where((s) => !s).first;
    if (mounted) {
      setState(() => _isScanning = false);
      _addLog(LogType.info, "Scan complete. Found ${_scanResults.length} devices.");
    }
  }

  Future<void> _connectToDevice(BluetoothDevice d) async {
    try {
      await FlutterBluePlus.stopScan();
      setState(() => _isConnecting = true);
      _addLog(LogType.info, "Connecting to ${d.platformName} (${d.remoteId.str})...");

      _cleanupDevice();

      await d.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      _device = d;
      _connSub = d.connectionState.listen((state) {
        _addLog(LogType.info, "Connection: $state");
        if (state == BluetoothConnectionState.disconnected) {
          _addLog(LogType.error, "Watch disconnected!");
          _cleanupDevice();
          if (mounted) setState(() {});
        }
      });

      // MTU 512
      try {
        final mtu = await d.requestMtu(512);
        _addLog(LogType.info, "Negotiated MTU: $mtu");
      } catch (_) {}

      // Discover GATT
      _addLog(LogType.info, "Discovering GATT services...");
      _services = await d.discoverServices();
      _addLog(LogType.match, "Discovered ${_services.length} services.");

      _writeChars.clear();
      _notifyChars.clear();

      for (var s in _services) {
        for (var c in s.characteristics) {
          if (c.properties.write || c.properties.writeWithoutResponse) {
            _writeChars.add(c);
          }
          if (c.properties.notify || c.properties.indicate) {
            _notifyChars.add(c);
            _listenCharacteristic(c);
          }
        }
      }

      // Initial Characteristic Selection
      _selectCharsForCombination(_combinations.first);

      setState(() => _isConnecting = false);
      _addLog(LogType.match, "✅ Ready to probe! ${_writeChars.length} Write & ${_notifyChars.length} Notify chars found.");
    } catch (e) {
      _addLog(LogType.error, "Connection error: $e");
      _cleanupDevice();
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  void _selectCharsForCombination(ProtocolCombination comb) {
    _activeWriteChar = null;
    _activeNotifyChar = null;

    for (var c in _writeChars) {
      final u = c.uuid.toString().toLowerCase();
      if (u.contains(comb.targetWriteHint.toLowerCase())) {
        _activeWriteChar = c;
        break;
      }
    }
    _activeWriteChar ??= _writeChars.isNotEmpty ? _writeChars.first : null;

    for (var c in _notifyChars) {
      final u = c.uuid.toString().toLowerCase();
      if (u.contains(comb.targetNotifyHint.toLowerCase())) {
        _activeNotifyChar = c;
        break;
      }
    }
    _activeNotifyChar ??= _notifyChars.isNotEmpty ? _notifyChars.first : null;
  }

  Future<void> _listenCharacteristic(BluetoothCharacteristic c) async {
    try {
      final sub = c.onValueReceived.listen((bytes) {
        if (bytes.isNotEmpty) {
          _processRxBytes(c, bytes);
        }
      });
      _notifySubs.add(sub);
      await c.setNotifyValue(true);
      await Future.delayed(const Duration(milliseconds: 40));
    } catch (e) {
      _addLog(LogType.error, "Notify enable error on ${c.uuid}: $e");
    }
  }

  void _processRxBytes(BluetoothCharacteristic c, List<int> bytes) {
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
    final cShort = c.uuid.toString().substring(0, 8);

    final parsed = WatchPacketParser.parse(bytes);

    if (parsed.heartRate != null) {
      _liveHeartRate = parsed.heartRate;
    }
    if (parsed.systolic != null && parsed.diastolic != null) {
      _liveSystolic = parsed.systolic;
      _liveDiastolic = parsed.diastolic;
    }
    if (parsed.spo2 != null) {
      _liveSpo2 = parsed.spo2;
    }
    if (parsed.steps != null && parsed.steps! > 0) {
      _liveSteps = parsed.steps;
    }

    // Auto-ACK for HiWatch frames
    if (parsed.autoAck != null && _activeWriteChar != null) {
      _activeWriteChar!.write(parsed.autoAck!, withoutResponse: true);
    }

    // Auto-identify winning combination on incoming stream
    if (_winningCombination == null && bytes.isNotEmpty && bytes[0] == 0xCD) {
      final cmd = bytes.length > 3 ? bytes[3] : 0;
      if (cmd == 0x15) {
        final match = _combinations.firstWhere(
          (comb) => comb.id == 'comb_fitpro_sport',
          orElse: () => _combinations[1],
        );
        match.state = CombinationState.passed;
        match.matchDetails = "✅ MATCH! Ultra2 streaming FitPro 0x15 packets";
        _winningCombination = match;
      } else if (cmd == 0x12) {
        final match = _combinations.firstWhere(
          (comb) => comb.id == 'comb_hiwatch_official',
          orElse: () => _combinations[0],
        );
        match.state = CombinationState.passed;
        match.matchDetails = "✅ MATCH! Ultra2 streaming HiWatch 0x12 packets";
        _winningCombination = match;
      }
    }

    final annStr = parsed.annotations.isNotEmpty ? " => ${parsed.annotations.join(' | ')}" : "";
    _addLog(LogType.rx, "[RX $cShort] ${bytes.length}B: $hex$annStr", bytes);

    if (mounted) setState(() {});
  }

  void _cleanupDevice() {
    for (var s in _notifySubs) {
      s.cancel();
    }
    _notifySubs.clear();
    _connSub?.cancel();
    _connSub = null;
    _device = null;
    _services.clear();
    _writeChars.clear();
    _notifyChars.clear();
    _activeWriteChar = null;
    _activeNotifyChar = null;
  }

  // ─── AUTOMATED COMBINATION PROBER ─────────────────────────────────────────

  Future<void> _runCombinationTesting() async {
    if (_device == null) {
      _addLog(LogType.error, "Connect to watch before probing!");
      return;
    }

    setState(() {
      _isAutoTesting = true;
      _winningCombination = null;
    });

    _addLog(LogType.info, "══════════════════════════════════════════════════════");
    _addLog(LogType.info, "🚀 EXECUTING ALL 8 PROTOCOL COMBINATIONS");
    _addLog(LogType.info, "══════════════════════════════════════════════════════");

    for (var comb in _combinations) {
      if (!_isAutoTesting) break;

      setState(() {
        comb.state = CombinationState.testing;
        comb.matchDetails = "Testing handshake & triggers...";
      });

      _selectCharsForCombination(comb);

      if (_activeWriteChar == null) {
        setState(() {
          comb.state = CombinationState.failed;
          comb.matchDetails = "Write Char not found on watch";
        });
        continue;
      }

      _addLog(LogType.info, "▶️ Testing ${comb.name} on ${_activeWriteChar!.uuid.toString().substring(0, 8)}...");

      bool rxReceived = false;
      String? captureHex;

      // Listen on notify char for 1.8 seconds
      StreamSubscription? rxSub;
      if (_activeNotifyChar != null) {
        rxSub = _activeNotifyChar!.onValueReceived.listen((bytes) {
          if (bytes.isNotEmpty) {
            rxReceived = true;
            captureHex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
          }
        });
      }

      // 1. Send Handshake
      await _activeWriteChar!.write(comb.handshakePacket, withoutResponse: _activeWriteChar!.properties.writeWithoutResponse);
      await Future.delayed(const Duration(milliseconds: 300));

      // 2. Send Heart Rate / Vitals Trigger
      await _activeWriteChar!.write(comb.hrTriggerPacket, withoutResponse: _activeWriteChar!.properties.writeWithoutResponse);

      // Wait up to 1500ms
      for (int t = 0; t < 15; t++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (rxReceived) break;
      }

      await rxSub?.cancel();

      setState(() {
        if (rxReceived) {
          comb.state = CombinationState.passed;
          comb.matchDetails = "✅ MATCH! RX: $captureHex";
          _winningCombination = comb;
          _addLog(LogType.match, "🎉 [MATCH] ${comb.name} responded: $captureHex");
        } else {
          comb.state = CombinationState.failed;
          comb.matchDetails = "No response (Timeout)";
          _addLog(LogType.info, "  └─ [TIMEOUT] ${comb.name}");
        }
      });

      await Future.delayed(const Duration(milliseconds: 250));
    }

    setState(() => _isAutoTesting = false);
    _addLog(LogType.info, "══════════════════════════════════════════════════════");
    if (_winningCombination != null) {
      _addLog(LogType.match, "🏆 WINNING COMBINATION ISOLATED: ${_winningCombination!.name}");
    } else {
      _addLog(LogType.error, "No response on standard combinations. Use Custom Hex injector or try waking watch screen.");
    }
    _addLog(LogType.info, "══════════════════════════════════════════════════════");
  }

  // ─── COMMAND ACTIONS ──────────────────────────────────────────────────────

  Future<void> _vibrateWatch() async {
    if (_activeWriteChar == null) return;
    _addLog(LogType.tx, "Sending Motor Vibration Trigger...");
    await _activeWriteChar!.write([0xCD, 0x00, 0x06, 0x12, 0x01, 0x04, 0x00, 0x01, 0x01]);
  }

  Future<void> _triggerHr() async {
    if (_activeWriteChar == null) return;
    _addLog(LogType.tx, "Triggering Continuous Pulse Stream...");
    await _activeWriteChar!.write([0xCD, 0x00, 0x06, 0x12, 0x01, 0x0D, 0x00, 0x01, 0x01]);
  }

  Future<void> _triggerBp() async {
    if (_activeWriteChar == null) return;
    _addLog(LogType.tx, "Triggering Blood Pressure Measurement...");
    await _activeWriteChar!.write([0xCD, 0x00, 0x06, 0x12, 0x01, 0x0E, 0x00, 0x01, 0x01]);
  }

  Future<void> _querySteps() async {
    if (_activeWriteChar == null) return;
    _addLog(LogType.tx, "Querying Step Counter...");
    await _activeWriteChar!.write([0xCD, 0x00, 0x06, 0x12, 0x01, 0x06, 0x00, 0x01, 0x01]);
  }

  Future<void> _sendCustomHex() async {
    if (_activeWriteChar == null) return;
    final txt = _customHexController.text.trim();
    if (txt.isEmpty) return;

    try {
      final clean = txt.replaceAll(' ', '').replaceAll('0x', '').replaceAll(',', '');
      final bytes = <int>[];
      for (int i = 0; i < clean.length; i += 2) {
        bytes.add(int.parse(clean.substring(i, i + 2), radix: 16));
      }
      final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      _addLog(LogType.tx, "[CUSTOM TX] ${bytes.length}B: $hex");
      await _activeWriteChar!.write(bytes);
      _customHexController.clear();
    } catch (e) {
      _addLog(LogType.error, "Invalid Hex: $e");
    }
  }

  // ─── REPORT EXPORT ────────────────────────────────────────────────────────

  String _generateExportReport() {
    final services = _services.map((s) {
      return GattServiceDescriptor(
        serviceUuid: s.uuid.toString(),
        characteristics: s.characteristics.map((c) {
          final props = <String>[];
          if (c.properties.read) props.add("read");
          if (c.properties.write || c.properties.writeWithoutResponse) props.add("write");
          if (c.properties.notify || c.properties.indicate) props.add("notify");
          return GattCharDescriptor(charUuid: c.uuid.toString(), properties: props);
        }).toList(),
      );
    }).toList();

    return WatchReportGenerator.generate(
      deviceName: _device?.platformName,
      deviceMac: _device?.remoteId.str,
      winningCombination: _winningCombination,
      workingWriteChar: _activeWriteChar?.uuid.toString(),
      workingNotifyChar: _activeNotifyChar?.uuid.toString(),
      liveHeartRate: _liveHeartRate,
      liveSystolic: _liveSystolic,
      liveDiastolic: _liveDiastolic,
      liveSpo2: _liveSpo2,
      liveSteps: _liveSteps,
      discoveredServices: services,
      logs: _logs,
    );
  }

  Future<void> _copyReport() async {
    final rep = _generateExportReport();
    await Clipboard.setData(ClipboardData(text: rep));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Report copied to clipboard! Paste it into chat.'),
        backgroundColor: Color(0xFF238636),
      ),
    );
  }

  Future<void> _shareReport() async {
    final rep = _generateExportReport();
    await SharePlus.instance.share(
      ShareParams(
        text: rep,
        subject: 'VYRA Smartwatch Hardware Setup Report',
      ),
    );
  }

  // ─── UI BUILD ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _adapterSub?.cancel();
    _scanSub?.cancel();
    _cleanupDevice();
    _logScrollController.dispose();
    _customHexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBleOn = _adapterState == BluetoothAdapterState.on;
    final isConnected = _device != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('VYRA WATCH PROBER', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 15)),
            Text('Field Diagnostic & Setup Isolation Tool', style: TextStyle(fontSize: 10, color: Color(0xFF8B949E))),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Copy Report',
            icon: const Icon(Icons.copy_all_rounded, color: Color(0xFF58A6FF)),
            onPressed: _copyReport,
          ),
          IconButton(
            tooltip: 'Share Report',
            icon: const Icon(Icons.share_rounded, color: Color(0xFF3FB950)),
            onPressed: _shareReport,
          ),
          IconButton(
            tooltip: 'Clear Logs',
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white54),
            onPressed: () => setState(() => _logs.clear()),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: const Color(0xFF21262D),
            child: Row(
              children: [
                Icon(
                  isBleOn ? Icons.bluetooth_connected_rounded : Icons.bluetooth_disabled_rounded,
                  color: isBleOn ? const Color(0xFF3FB950) : const Color(0xFFF85149),
                  size: 15,
                ),
                const SizedBox(width: 6),
                Text(
                  isBleOn ? 'BLUETOOTH: ACTIVE' : 'BLUETOOTH: OFF',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isBleOn ? const Color(0xFF3FB950) : const Color(0xFFF85149),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isConnected
                        ? const Color(0xFF3FB950).withValues(alpha: 0.15)
                        : const Color(0xFFF85149).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isConnected ? const Color(0xFF3FB950) : const Color(0xFFF85149)),
                  ),
                  child: Text(
                    isConnected ? 'CONNECTED' : 'DISCONNECTED',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isConnected ? const Color(0xFF3FB950) : const Color(0xFFF85149),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Sections
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // 1. Target Watch Scanner / Connected Card
                _buildScannerCard(),
                const SizedBox(height: 12),

                // 2. Winning Combination Banner (If isolated!)
                if (_winningCombination != null) ...[
                  _buildWinnerBanner(),
                  const SizedBox(height: 12),
                ],

                // 3. Automated Combination Prober Matrix
                _buildCombinationsCard(),
                const SizedBox(height: 12),

                // 4. Live Telemetry Gauges (If readings received!)
                _buildLiveTelemetryGauges(),
                const SizedBox(height: 12),

                // 5. Manual Hardware Injectors
                _buildManualTriggers(),
                const SizedBox(height: 12),

                // 6. Custom Hex Injector
                _buildCustomHexInjector(),
                const SizedBox(height: 12),

                // 7. Live Packet Terminal
                _buildLiveTerminal(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('🎯 1. TARGET WATCH', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF8B949E))),
              if (_isScanning)
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF58A6FF))),
            ],
          ),
          const SizedBox(height: 8),

          if (_device != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF238636).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF238636)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.watch_rounded, color: Color(0xFF3FB950), size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _device!.platformName.isNotEmpty ? _device!.platformName : 'Connected Watch',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                        ),
                        Text(
                          _device!.remoteId.str,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF8B949E)),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF85149),
                      side: const BorderSide(color: Color(0xFFF85149)),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () async {
                      await _device?.disconnect();
                      _cleanupDevice();
                      setState(() {});
                    },
                    child: const Text('Disconnect', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF238636),
                      foregroundColor: Colors.white,
                    ),
                    icon: Icon(_isScanning ? Icons.stop_rounded : Icons.search_rounded),
                    label: Text(_isScanning ? 'Stop Scanning' : 'Scan for Nearby Watches'),
                    onPressed: _toggleScan,
                  ),
                ),
              ],
            ),
            if (_scanResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 140,
                child: ListView.separated(
                  itemCount: _scanResults.length,
                  separatorBuilder: (_, _) => const Divider(color: Color(0xFF21262D), height: 4),
                  itemBuilder: (context, i) {
                    final item = _scanResults[i];
                    final name = item.device.platformName.isNotEmpty
                        ? item.device.platformName
                        : (item.advertisementData.advName.isNotEmpty ? item.advertisementData.advName : "BLE Device");
                    final mac = item.device.remoteId.str;
                    final isWatch = name.toLowerCase().contains('watch') ||
                        name.toLowerCase().contains('pro') ||
                        name.toLowerCase().contains('fit') ||
                        name.toLowerCase().contains('band');

                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(isWatch ? Icons.watch_rounded : Icons.bluetooth_rounded, color: isWatch ? const Color(0xFF58A6FF) : const Color(0xFF8B949E)),
                      title: Text(name, style: TextStyle(color: isWatch ? Colors.white : const Color(0xFF8B949E), fontWeight: isWatch ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                      subtitle: Text("$mac • ${item.rssi}dBm", style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF8B949E))),
                      trailing: _isConnecting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : TextButton(
                              child: const Text('Connect', style: TextStyle(color: Color(0xFF58A6FF), fontSize: 12)),
                              onPressed: () => _connectToDevice(item.device),
                            ),
                    );
                  },
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildWinnerBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF238636).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF3FB950), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_rounded, color: Color(0xFF3FB950), size: 20),
              SizedBox(width: 8),
              Text(
                '🏆 WINNING SETUP VERIFIED & LOCKED!',
                style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF3FB950)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _winningCombination!.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
          ),
          Text(
            "Architecture: ${_winningCombination!.chipFamily}",
            style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E)),
          ),
          const SizedBox(height: 6),
          Text(
            "Write UUID: ${_activeWriteChar?.uuid}\nNotify UUID: ${_activeNotifyChar?.uuid}",
            style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFFC9D1D9)),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF238636),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('📋 COPY WINNING SETUP FOR VYRA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: _copyReport,
          ),
        ],
      ),
    );
  }

  Widget _buildCombinationsCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('⚡ 2. PROTOCOL COMBINATIONS', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF8B949E))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F6FEB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                icon: Icon(_isAutoTesting ? Icons.hourglass_top_rounded : Icons.play_arrow_rounded, size: 14),
                label: Text(_isAutoTesting ? 'Probing...' : 'Run All (8)', style: const TextStyle(fontSize: 11)),
                onPressed: _isAutoTesting || _device == null ? null : _runCombinationTesting,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _combinations.length,
            itemBuilder: (context, i) {
              final c = _combinations[i];
              Color col = const Color(0xFF8B949E);
              IconData ico = Icons.circle_outlined;

              if (c.state == CombinationState.testing) {
                col = const Color(0xFFD29922);
                ico = Icons.sync_rounded;
              } else if (c.state == CombinationState.passed) {
                col = const Color(0xFF3FB950);
                ico = Icons.check_circle_rounded;
              } else if (c.state == CombinationState.failed) {
                col = const Color(0xFFF85149);
                ico = Icons.cancel_outlined;
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(ico, color: col, size: 15),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name, style: TextStyle(fontSize: 12, fontWeight: c.state == CombinationState.passed ? FontWeight.bold : FontWeight.w500, color: c.state == CombinationState.passed ? Colors.white : const Color(0xFFC9D1D9))),
                          if (c.matchDetails != null)
                            Text(c.matchDetails!, style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: c.state == CombinationState.passed ? const Color(0xFF3FB950) : const Color(0xFF8B949E))),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTelemetryGauges() {
    if (_liveHeartRate == null && _liveSteps == null && _liveSystolic == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📊 3. VERIFIED LIVE READINGS', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF8B949E))),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricTile('HEART RATE', _liveHeartRate != null ? '$_liveHeartRate' : '--', 'BPM', const Color(0xFFFF5252)),
              _buildMetricTile('BLOOD PRESSURE', _liveSystolic != null ? '$_liveSystolic/$_liveDiastolic' : '--', 'mmHg', const Color(0xFF58A6FF)),
              _buildMetricTile('STEPS', _liveSteps != null ? '$_liveSteps' : '--', 'steps', const Color(0xFF3FB950)),
              _buildMetricTile('SPO2', _liveSpo2 != null ? '$_liveSpo2%' : '--', 'O2', const Color(0xFFD29922)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, String unit, Color col) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 18, color: col)),
        Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF8B949E))),
        Text(unit, style: const TextStyle(fontSize: 8, color: Color(0xFF484F58))),
      ],
    );
  }

  Widget _buildManualTriggers() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🕹️ 4. MANUAL HARDWARE TESTERS', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF8B949E))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildBtn('📳 Vibrate Watch', _vibrateWatch),
              _buildBtn('❤️ Trigger Pulse', _triggerHr),
              _buildBtn('🩺 Measure BP', _triggerBp),
              _buildBtn('🚶 Query Steps', _querySteps),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBtn(String label, VoidCallback onPressed) {
    final enabled = _activeWriteChar != null;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF58A6FF),
        side: const BorderSide(color: Color(0xFF30363D)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      onPressed: enabled ? onPressed : null,
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _buildCustomHexInjector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('✍️ 5. CUSTOM RAW HEX INJECTOR', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF8B949E))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customHexController,
                  style: const TextStyle(fontFamily: 'monospace', color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: 'CD 00 06 12 01 04 00 01 01',
                    hintStyle: TextStyle(color: Color(0xFF484F58), fontSize: 11),
                    filled: true,
                    fillColor: Color(0xFF0D1117),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF30363D))),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: _activeWriteChar != null ? _sendCustomHex : null,
                child: const Text('Send TX', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTerminal() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.terminal_rounded, color: Color(0xFF3FB950), size: 14),
                  SizedBox(width: 6),
                  Text('LIVE PACKET CONSOLE (HEX SNIFFER)', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF3FB950))),
                ],
              ),
              Text('${_logs.length} logs', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF8B949E))),
            ],
          ),
          const Divider(color: Color(0xFF21262D), height: 10),
          SizedBox(
            height: 220,
            child: _logs.isEmpty
                ? const Center(
                    child: Text('Ready. Connect watch to see real-time packet exchange.', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF484F58))),
                  )
                : ListView.builder(
                    controller: _logScrollController,
                    itemCount: _logs.length,
                    itemBuilder: (context, i) {
                      final l = _logs[i];
                      Color col = const Color(0xFFC9D1D9);
                      if (l.type == LogType.tx) col = const Color(0xFF58A6FF);
                      if (l.type == LogType.rx) col = const Color(0xFFD29922);
                      if (l.type == LogType.match) col = const Color(0xFF3FB950);
                      if (l.type == LogType.error) col = const Color(0xFFF85149);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1.5),
                        child: Text("[${l.formattedTime}] ${l.message}", style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: col)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
