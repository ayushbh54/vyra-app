import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../services/hiwatch_pro_service.dart';
import '../theme.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// ⚡ SMARTWATCH HARDWARE PROTOCOL TESTER & FIELD DIAGNOSTIC SUITE
/// ═══════════════════════════════════════════════════════════════════════════
/// Dedicated automated testing and protocol probing tool:
/// 1. Comprehensive BLE Scanner (Shows all devices, RSSI, MAC, Advertised UUIDs)
/// 2. Deep GATT Characteristic Inspector (Lists all Services, Read/Write/Notify)
/// 3. Automated 10-Step Protocol Prober (Tests 0xCD, 0xAB, UART, BLE SIG, ACKs)
/// 4. Live Hex Terminal Sniffer (Real-time TX/RX packet byte inspector)
/// 5. Manual Diagnostic Triggers (Vibrate Motor, Pulse, BP, Steps, Custom Hex)
/// 6. 1-Click Diagnostic Report Generator (Copy/Share full report to developer)
/// ═══════════════════════════════════════════════════════════════════════════

enum LogType { info, tx, rx, success, error }

class LogEntry {
  final DateTime timestamp;
  final LogType type;
  final String message;
  final List<int>? rawBytes;

  LogEntry({
    required this.type,
    required this.message,
    this.rawBytes,
  }) : timestamp = DateTime.now();

  String get formattedTime =>
      "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}.${timestamp.millisecond.toString().padLeft(3, '0')}";

  String get hexString => rawBytes != null
      ? rawBytes!
          .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(' ')
      : '';
}

enum ProbeState { pending, running, passed, failed }

class ProbeItem {
  final String id;
  final String title;
  final String description;
  final List<int> commandBytes;
  ProbeState state;
  String? resultDetails;

  ProbeItem({
    required this.id,
    required this.title,
    required this.description,
    required this.commandBytes,
    this.state = ProbeState.pending,
    this.resultDetails,
  });
}

class SmartwatchDiagnosticScreen extends StatefulWidget {
  const SmartwatchDiagnosticScreen({super.key});

  @override
  State<SmartwatchDiagnosticScreen> createState() =>
      _SmartwatchDiagnosticScreenState();
}

class _SmartwatchDiagnosticScreenState
    extends State<SmartwatchDiagnosticScreen> {
  // BLE states
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  bool _isScanning = false;
  List<ScanResult> _scanResults = [];
  StreamSubscription<List<ScanResult>>? _scanSub;

  // Active Connection
  BluetoothDevice? _connectedDevice;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  bool _isConnecting = false;
  List<BluetoothService> _discoveredServices = [];

  // Characteristics
  final List<BluetoothCharacteristic> _writeChars = [];
  final List<BluetoothCharacteristic> _notifyChars = [];
  final List<StreamSubscription> _notifySubs = [];
  BluetoothCharacteristic? _primaryWriteChar;
  BluetoothCharacteristic? _primaryNotifyChar;

  // Logs & Console
  final List<LogEntry> _logs = [];
  final ScrollController _logScrollController = ScrollController();
  final TextEditingController _customHexController = TextEditingController();

  // Automated Prober
  bool _isProbing = false;
  late List<ProbeItem> _probes;

  // Verified Vitals
  int? _verifiedHr;
  int? _verifiedSys;
  int? _verifiedDia;
  int? _verifiedSpo2;
  int? _verifiedSteps;

  @override
  void initState() {
    super.initState();
    _initProbes();
    _initBluetooth();
  }

  void _initProbes() {
    _probes = [
      ProbeItem(
        id: 'rtc_time',
        title: '1. HiWatch RTC Time Sync',
        description: 'Syncs current year/month/day/hour/min/sec to watch clock',
        commandBytes: HiWatchProProtocol.buildHiWatchTimeSyncCommand(),
      ),
      ProbeItem(
        id: 'pair',
        title: '2. Official FitPro/HiWatch Pair',
        description: 'SendData.getPair() [0xCD 0x00 0x06 0x12 0x01 0x0A 0x00 0x01 0x02]',
        commandBytes: HiWatchProProtocol.buildPairCommand(),
      ),
      ProbeItem(
        id: 'binding',
        title: '3. Binding Status Check',
        description: 'SendData.getIsBingding() to confirm bonding handshake',
        commandBytes: HiWatchProProtocol.buildIsBindingCommand(),
      ),
      ProbeItem(
        id: 'vibrate',
        title: '4. Find Watch Vibration Motor',
        description: 'Triggers motor vibration on watch wrist (visual confirmation)',
        commandBytes: HiWatchProProtocol.buildFindWatchCommand(),
      ),
      ProbeItem(
        id: 'step_stream',
        title: '5. Real-Time Step Streaming',
        description: 'Enables 64-bit continuous step stream [Key 0x06 / 0x0B]',
        commandBytes: HiWatchProProtocol.buildTurnOnRealTimeStepCommand(),
      ),
      ProbeItem(
        id: 'hr_stream',
        title: '6. Continuous Heart Rate Trigger',
        description: 'Activates PPG optical green LEDs for live pulse stream',
        commandBytes: HiWatchProProtocol.buildStartHeartRateMeasureCommand(),
      ),
      ProbeItem(
        id: 'bp_measure',
        title: '7. Blood Pressure Measurement',
        description: 'Triggers systolic/diastolic optical calibration sequence',
        commandBytes: HiWatchProProtocol.buildStartBloodPressureMeasureCommand(),
      ),
      ProbeItem(
        id: 'combined_measure',
        title: '8. Combined Multi-Vital Trigger',
        description: 'Triggers simultaneous HR + BP + SpO2 measurement',
        commandBytes: HiWatchProProtocol.buildStartCombinedMeasureCommand(),
      ),
      ProbeItem(
        id: 'step_query',
        title: '9. Daily Step Summary Query',
        description: 'Queries cumulative steps, distance & calories for today',
        commandBytes: HiWatchProProtocol.buildSportKeyDayGetCommand(),
      ),
      ProbeItem(
        id: 'dafit_probe',
        title: '10. DaFit / Shenzhen 0xAB Query',
        description: 'Fallback Shenzhen DaFit protocol query packet [0xAB]',
        commandBytes: HiWatchProProtocol.buildDaFitStepQueryCommand(),
      ),
    ];
  }

  Future<void> _initBluetooth() async {
    _adapterSub = FlutterBluePlus.adapterState.listen((state) {
      if (mounted) setState(() => _adapterState = state);
      _addLog(LogType.info, "Bluetooth Adapter state: $state");
    });

    final isSupported = await FlutterBluePlus.isSupported;
    if (!isSupported) {
      _addLog(LogType.error, "BLE is NOT supported on this device!");
    }
  }

  void _addLog(LogType type, String message, [List<int>? rawBytes]) {
    if (!mounted) return;
    setState(() {
      _logs.add(LogEntry(type: type, message: message, rawBytes: rawBytes));
      if (_logs.length > 250) _logs.removeAt(0);
    });

    // Auto-scroll to bottom of console
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── BLE SCANNING ─────────────────────────────────────────────────────────

  Future<void> _startScan() async {
    try {
      if (_adapterState != BluetoothAdapterState.on) {
        _addLog(LogType.error, "Cannot scan: Bluetooth is OFF. Please turn ON Bluetooth & Location.");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please turn ON Bluetooth and Location/GPS in settings.')),
        );
        return;
      }

      setState(() {
        _isScanning = true;
        _scanResults.clear();
      });
      _addLog(LogType.info, "Starting BLE discovery (15s timeout)...");

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
        _addLog(LogType.info, "Scan completed. Found ${_scanResults.length} BLE devices.");
      }
    } catch (e) {
      _addLog(LogType.error, "Scan error: $e");
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _stopScan() async {
    await FlutterBluePlus.stopScan();
    if (mounted) setState(() => _isScanning = false);
    _addLog(LogType.info, "Scan stopped.");
  }

  // ─── CONNECTION & GATT DISCOVERY ──────────────────────────────────────────

  Future<void> _connect(BluetoothDevice device) async {
    try {
      await _stopScan();
      setState(() => _isConnecting = true);
      _addLog(LogType.info, "Connecting to ${device.platformName} (${device.remoteId.str})...");

      // Clean up previous sessions
      _cleanupConnection();

      // Connect with 15s timeout
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      _connectedDevice = device;
      _connSub = device.connectionState.listen((state) {
        _addLog(LogType.info, "Connection state: $state");
        if (state == BluetoothConnectionState.disconnected) {
          _addLog(LogType.error, "Device disconnected.");
          _cleanupConnection();
          if (mounted) setState(() {});
        }
      });

      // Request MTU 512 for full frames
      try {
        final mtu = await device.requestMtu(512);
        _addLog(LogType.info, "Negotiated MTU: $mtu");
      } catch (e) {
        _addLog(LogType.info, "MTU request: $e (defaulting)");
      }

      // Discover Services
      _addLog(LogType.info, "Discovering GATT Services...");
      _discoveredServices = await device.discoverServices();
      _addLog(LogType.success, "Discovered ${_discoveredServices.length} GATT Services.");

      _writeChars.clear();
      _notifyChars.clear();

      for (var s in _discoveredServices) {
        final sUuid = s.uuid.toString().toLowerCase();
        _addLog(LogType.info, "  ├─ Service: $sUuid");

        for (var c in s.characteristics) {
          final cUuid = c.uuid.toString().toLowerCase();
          final props = [];
          if (c.properties.read) props.add("READ");
          if (c.properties.write) props.add("WRITE");
          if (c.properties.writeWithoutResponse) props.add("WRITE_NO_RESP");
          if (c.properties.notify) props.add("NOTIFY");
          if (c.properties.indicate) props.add("INDICATE");

          _addLog(LogType.info, "  │   └─ Char: $cUuid [${props.join(', ')}]");

          if (c.properties.write || c.properties.writeWithoutResponse) {
            _writeChars.add(c);
          }

          if (c.properties.notify || c.properties.indicate) {
            _notifyChars.add(c);
            _subscribeToNotify(c);
          }
        }
      }

      // Automatically select primary write & notify characteristics
      _selectOptimalCharacteristics();

      setState(() => _isConnecting = false);
      _addLog(LogType.success, "✅ Ready! ${_writeChars.length} Write Chars, ${_notifyChars.length} Notify Chars active.");
    } catch (e) {
      _addLog(LogType.error, "Connection failed: $e");
      _cleanupConnection();
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  void _selectOptimalCharacteristics() {
    // Priority 1: Official HiWatch Pro / Nordic UART (6E400002 / 6E400003)
    for (var c in _writeChars) {
      final u = c.uuid.toString().toLowerCase();
      if (u.contains('6e400002') || (u.contains('6e40') && !u.contains('ff02'))) {
        _primaryWriteChar = c;
        break;
      }
    }
    _primaryWriteChar ??= _writeChars.isNotEmpty ? _writeChars.first : null;

    for (var c in _notifyChars) {
      final u = c.uuid.toString().toLowerCase();
      if (u.contains('6e400003') || (u.contains('6e40') && !u.contains('ff01'))) {
        _primaryNotifyChar = c;
        break;
      }
    }
    _primaryNotifyChar ??= _notifyChars.isNotEmpty ? _notifyChars.first : null;

    _addLog(LogType.info, "Selected Primary TX: ${_primaryWriteChar?.uuid.toString().substring(0, 8)}...");
    _addLog(LogType.info, "Selected Primary RX: ${_primaryNotifyChar?.uuid.toString().substring(0, 8)}...");
  }

  Future<void> _subscribeToNotify(BluetoothCharacteristic c) async {
    try {
      final sub = c.onValueReceived.listen((bytes) {
        if (bytes.isNotEmpty) {
          _handleIncomingBytes(c, bytes);
        }
      });
      _notifySubs.add(sub);
      await c.setNotifyValue(true);
      await Future.delayed(const Duration(milliseconds: 40));
    } catch (e) {
      _addLog(LogType.error, "Failed to enable notify on ${c.uuid}: $e");
    }
  }

  void _handleIncomingBytes(BluetoothCharacteristic c, List<int> bytes) {
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
    final cShort = c.uuid.toString().substring(0, 8);

    // Parse with Vyra parser
    final telemetry = HiWatchProProtocol.parseNotifyPacket(bytes);
    final details = <String>[];

    if (telemetry.heartRateBpm != null) {
      _verifiedHr = telemetry.heartRateBpm;
      details.add("❤️ HR: ${telemetry.heartRateBpm} BPM");
    }
    if (telemetry.bloodPressureSystolic != null && telemetry.bloodPressureDiastolic != null) {
      _verifiedSys = telemetry.bloodPressureSystolic;
      _verifiedDia = telemetry.bloodPressureDiastolic;
      details.add("🩺 BP: ${telemetry.bloodPressureSystolic}/${telemetry.bloodPressureDiastolic} mmHg");
    }
    if (telemetry.bloodOxygenSpo2 != null) {
      _verifiedSpo2 = telemetry.bloodOxygenSpo2;
      details.add("🫁 SpO2: ${telemetry.bloodOxygenSpo2}%");
    }
    if (telemetry.steps != null) {
      _verifiedSteps = telemetry.steps;
      details.add("🚶 Steps: ${telemetry.steps}");
    }
    if (telemetry.ackPacket != null) {
      details.add("🔄 ACK Generated");
      // Auto-send ACK back so watch keeps streaming
      if (_primaryWriteChar != null) {
        _sendRawBytes(_primaryWriteChar!, telemetry.ackPacket!, logTx: false);
      }
    }

    final detailStr = details.isNotEmpty ? " => ${details.join(' | ')}" : "";
    _addLog(LogType.rx, "[RX $cShort] ${bytes.length}B: $hex$detailStr", bytes);

    if (mounted) setState(() {});
  }

  void _cleanupConnection() {
    for (var s in _notifySubs) {
      s.cancel();
    }
    _notifySubs.clear();
    _connSub?.cancel();
    _connSub = null;
    _connectedDevice = null;
    _discoveredServices.clear();
    _writeChars.clear();
    _notifyChars.clear();
    _primaryWriteChar = null;
    _primaryNotifyChar = null;
  }

  // ─── TRANSMISSION ─────────────────────────────────────────────────────────

  Future<bool> _sendRawBytes(BluetoothCharacteristic char, List<int> bytes, {bool logTx = true}) async {
    try {
      if (logTx) {
        final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
        final cShort = char.uuid.toString().substring(0, 8);
        _addLog(LogType.tx, "[TX $cShort] ${bytes.length}B: $hex", bytes);
      }

      await char.write(bytes, withoutResponse: char.properties.writeWithoutResponse);
      return true;
    } catch (e) {
      _addLog(LogType.error, "TX Failed: $e");
      return false;
    }
  }

  Future<void> _sendCustomHex() async {
    if (_primaryWriteChar == null) {
      _addLog(LogType.error, "No connected write characteristic!");
      return;
    }

    final raw = _customHexController.text.trim();
    if (raw.isEmpty) return;

    try {
      final clean = raw.replaceAll(' ', '').replaceAll('0x', '').replaceAll(',', '');
      final bytes = <int>[];
      for (int i = 0; i < clean.length; i += 2) {
        bytes.add(int.parse(clean.substring(i, i + 2), radix: 16));
      }

      await _sendRawBytes(_primaryWriteChar!, bytes);
      _customHexController.clear();
    } catch (e) {
      _addLog(LogType.error, "Invalid hex string format: $e");
    }
  }

  // ─── AUTOMATED PROTOCOL PROBE ENGINE ──────────────────────────────────────

  Future<void> _runFullProtocolProbe() async {
    if (_connectedDevice == null || _primaryWriteChar == null) {
      _addLog(LogType.error, "Please connect to a watch first!");
      return;
    }

    setState(() => _isProbing = true);
    _addLog(LogType.info, "═════════════════════════════════════════════");
    _addLog(LogType.info, "🚀 STARTING AUTOMATED 10-STEP PROTOCOL PROBE");
    _addLog(LogType.info, "═════════════════════════════════════════════");

    for (var probe in _probes) {
      if (!_isProbing) break;

      setState(() {
        probe.state = ProbeState.running;
        probe.resultDetails = "Transmitting command...";
      });

      _addLog(LogType.info, "Testing ${probe.title}...");
      bool receivedResponse = false;
      String? captureInfo;

      // Temporary listener to capture first response during probe window
      final tempSub = FlutterBluePlus.onScanResults.listen((_) {}); // placeholder
      StreamSubscription? rxSub;

      if (_primaryNotifyChar != null) {
        rxSub = _primaryNotifyChar!.onValueReceived.listen((bytes) {
          if (bytes.isNotEmpty) {
            receivedResponse = true;
            captureInfo = bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
          }
        });
      }

      await _sendRawBytes(_primaryWriteChar!, probe.commandBytes);

      // Wait up to 1500ms for watch response
      for (int i = 0; i < 15; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (receivedResponse) break;
      }

      await rxSub?.cancel();
      await tempSub.cancel();

      setState(() {
        if (receivedResponse) {
          probe.state = ProbeState.passed;
          probe.resultDetails = "✅ Response: $captureInfo";
          _addLog(LogType.success, "  └─ [PASS] ${probe.title} responded: $captureInfo");
        } else {
          probe.state = ProbeState.failed;
          probe.resultDetails = "Timed out (No RX packet)";
          _addLog(LogType.info, "  └─ [TIMEOUT] ${probe.title} (No response)");
        }
      });

      // Pacing delay between probes
      await Future.delayed(const Duration(milliseconds: 300));
    }

    setState(() => _isProbing = false);
    _addLog(LogType.info, "═════════════════════════════════════════════");
    _addLog(LogType.success, "🎉 PROTOCOL PROBE COMPLETED! Ready to export report.");
    _addLog(LogType.info, "═════════════════════════════════════════════");
  }

  // ─── DIAGNOSTIC REPORT GENERATOR ──────────────────────────────────────────

  String _generateReport() {
    final sb = StringBuffer();
    sb.writeln("══════════════════════════════════════════════════════");
    sb.writeln("⚡ VYRA SMARTWATCH FIELD PROTOCOL DIAGNOSTIC REPORT");
    sb.writeln("Generated: ${DateTime.now().toIso8601String()}");
    sb.writeln("══════════════════════════════════════════════════════\n");

    sb.writeln("📱 DEVICE INFORMATION:");
    if (_connectedDevice != null) {
      sb.writeln("  - Name: ${_connectedDevice!.platformName}");
      sb.writeln("  - MAC / Remote ID: ${_connectedDevice!.remoteId.str}");
    } else {
      sb.writeln("  - Status: Not connected during report export");
    }

    sb.writeln("\n🔌 GATT ARCHITECTURE:");
    if (_discoveredServices.isNotEmpty) {
      for (var s in _discoveredServices) {
        sb.writeln("  - Service: ${s.uuid}");
        for (var c in s.characteristics) {
          final props = [];
          if (c.properties.read) props.add("read");
          if (c.properties.write) props.add("write");
          if (c.properties.writeWithoutResponse) props.add("writeWithoutResponse");
          if (c.properties.notify) props.add("notify");
          if (c.properties.indicate) props.add("indicate");
          sb.writeln("      Char: ${c.uuid} [${props.join(', ')}]");
        }
      }
    } else {
      sb.writeln("  - No services discovered");
    }

    sb.writeln("\n🎯 OPTIMAL CHARACTERISTICS DETECTED:");
    sb.writeln("  - Primary Write TX: ${_primaryWriteChar?.uuid ?? 'None'}");
    sb.writeln("  - Primary Notify RX: ${_primaryNotifyChar?.uuid ?? 'None'}");

    sb.writeln("\n🧪 PROTOCOL PROBE TEST RESULTS:");
    for (var p in _probes) {
      final statusStr = p.state == ProbeState.passed ? "PASS ✅" : (p.state == ProbeState.failed ? "TIMEOUT ❌" : "PENDING");
      sb.writeln("  [${statusStr.padRight(9)}] ${p.title}");
      if (p.resultDetails != null) {
        sb.writeln("               └─ ${p.resultDetails}");
      }
    }

    sb.writeln("\n📊 VERIFIED LIVE TELEMETRY:");
    sb.writeln("  - Heart Rate: ${_verifiedHr != null ? '$_verifiedHr BPM' : 'Not verified'}");
    sb.writeln("  - Blood Pressure: ${_verifiedSys != null ? '$_verifiedSys/$_verifiedDia mmHg' : 'Not verified'}");
    sb.writeln("  - SpO2 Oxygen: ${_verifiedSpo2 != null ? '$_verifiedSpo2%' : 'Not verified'}");
    sb.writeln("  - Step Count: ${_verifiedSteps != null ? '$_verifiedSteps steps' : 'Not verified'}");

    sb.writeln("\n📜 RECENT PACKET LOGS (Last 25 entries):");
    final recentLogs = _logs.length > 25 ? _logs.sublist(_logs.length - 25) : _logs;
    for (var l in recentLogs) {
      sb.writeln("  [${l.formattedTime}] ${l.message}");
    }

    sb.writeln("\n══════════════════════════════════════════════════════");
    sb.writeln("END OF REPORT — Share this report with Antigravity");
    sb.writeln("══════════════════════════════════════════════════════");
    return sb.toString();
  }

  Future<void> _copyReportToClipboard() async {
    final report = _generateReport();
    await Clipboard.setData(ClipboardData(text: report));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Diagnostic report copied to clipboard! Paste it into chat.'),
        backgroundColor: VColor.accentGreen,
      ),
    );
  }

  Future<void> _shareReport() async {
    final report = _generateReport();
    await SharePlus.instance.share(
      ShareParams(
        text: report,
        subject: 'VYRA Smartwatch Diagnostic Report',
      ),
    );
  }

  // ─── UI RENDERING ─────────────────────────────────────────────────────────

  @override
  void dispose() {
    _adapterSub?.cancel();
    _scanSub?.cancel();
    _cleanupConnection();
    _logScrollController.dispose();
    _customHexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117), // Deep Hacker Dark
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.biotech_rounded, color: Color(0xFF58A6FF)),
            SizedBox(width: 8),
            Text(
              'Watch Protocol Prober',
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Copy Report',
            icon: const Icon(Icons.copy_all_rounded, color: Color(0xFF58A6FF)),
            onPressed: _copyReportToClipboard,
          ),
          IconButton(
            tooltip: 'Share Report',
            icon: const Icon(Icons.share_rounded, color: Color(0xFF3FB950)),
            onPressed: _shareReport,
          ),
          IconButton(
            tooltip: 'Clear Console',
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white54),
            onPressed: () => setState(() => _logs.clear()),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 1. Status Bar ──────────────────────────────────────────────
          _buildStatusBar(),

          // ── 2. Scrollable Control & Diagnostic Sections ────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // Device Connection Card
                _buildDeviceCard(),
                const SizedBox(height: 12),

                // Automated Protocol Prober Card
                _buildProberCard(),
                const SizedBox(height: 12),

                // Manual Hardware Trigger Buttons
                _buildManualTriggersCard(),
                const SizedBox(height: 12),

                // Custom Hex Command Sender
                _buildCustomHexSender(),
                const SizedBox(height: 12),

                // Discovered Services Accordion
                _buildServicesAccordion(),
                const SizedBox(height: 12),

                // Live Terminal Packet Sniffer (Pinned Height)
                _buildTerminalCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    final isBleOn = _adapterState == BluetoothAdapterState.on;
    final isConnected = _connectedDevice != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF21262D),
      child: Row(
        children: [
          Icon(
            isBleOn ? Icons.bluetooth_connected_rounded : Icons.bluetooth_disabled_rounded,
            color: isBleOn ? const Color(0xFF3FB950) : const Color(0xFFF85149),
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            isBleOn ? 'BLE: ON' : 'BLE: OFF',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: isBleOn ? const Color(0xFF3FB950) : const Color(0xFFF85149),
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isConnected
                  ? const Color(0xFF3FB950).withValues(alpha: 0.2)
                  : const Color(0xFFF85149).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isConnected ? const Color(0xFF3FB950) : const Color(0xFFF85149),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 3,
                  backgroundColor: isConnected ? const Color(0xFF3FB950) : const Color(0xFFF85149),
                ),
                const SizedBox(width: 5),
                Text(
                  isConnected ? 'CONNECTED' : 'DISCONNECTED',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isConnected ? const Color(0xFF3FB950) : const Color(0xFFF85149),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard() {
    return Container(
      padding: const EdgeInsets.all(14),
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
              const Text(
                '🎯 TARGET HARDWARE',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B949E),
                ),
              ),
              if (_isScanning)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF58A6FF)),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (_connectedDevice != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF238636).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF238636)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.watch_rounded, color: Color(0xFF3FB950), size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _connectedDevice!.platformName.isNotEmpty ? _connectedDevice!.platformName : 'Unknown Watch',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          _connectedDevice!.remoteId.str,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: Color(0xFF8B949E),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF85149),
                      side: const BorderSide(color: Color(0xFFF85149)),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: () async {
                      await _connectedDevice?.disconnect();
                      _cleanupConnection();
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
                    label: Text(_isScanning ? 'Stop Scan' : 'Scan for Watches'),
                    onPressed: _isScanning ? _stopScan : _startScan,
                  ),
                ),
              ],
            ),
            if (_scanResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Discovered BLE Devices (Tap to connect):',
                style: TextStyle(fontSize: 11, color: Color(0xFF8B949E)),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 160,
                child: ListView.separated(
                  itemCount: _scanResults.length,
                  separatorBuilder: (_, __) => const Divider(color: Color(0xFF21262D), height: 4),
                  itemBuilder: (context, i) {
                    final item = _scanResults[i];
                    final name = item.device.platformName.isNotEmpty
                        ? item.device.platformName
                        : (item.advertisementData.advName.isNotEmpty ? item.advertisementData.advName : "BLE Device");
                    final mac = item.device.remoteId.str;
                    final rssi = item.rssi;
                    final isProbableWatch = name.toLowerCase().contains('watch') ||
                        name.toLowerCase().contains('pro') ||
                        name.toLowerCase().contains('fit') ||
                        name.toLowerCase().contains('band') ||
                        name.toLowerCase().contains('ultra');

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      leading: Icon(
                        isProbableWatch ? Icons.watch_rounded : Icons.bluetooth_rounded,
                        color: isProbableWatch ? const Color(0xFF58A6FF) : const Color(0xFF8B949E),
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          color: isProbableWatch ? Colors.white : const Color(0xFFC9D1D9),
                          fontWeight: isProbableWatch ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        "$mac • ${rssi}dBm",
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF8B949E)),
                      ),
                      trailing: _isConnecting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : TextButton(
                              child: const Text('Connect', style: TextStyle(color: Color(0xFF58A6FF), fontSize: 12)),
                              onPressed: () => _connect(item.device),
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

  Widget _buildProberCard() {
    return Container(
      padding: const EdgeInsets.all(14),
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
              const Text(
                '⚡ AUTOMATED PROTOCOL PROBER',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B949E),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F6FEB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: Icon(_isProbing ? Icons.hourglass_top_rounded : Icons.play_arrow_rounded, size: 16),
                label: Text(_isProbing ? 'Probing...' : 'Run Full Probe', style: const TextStyle(fontSize: 12)),
                onPressed: _isProbing || _connectedDevice == null ? null : _runFullProtocolProbe,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _probes.length,
            itemBuilder: (context, i) {
              final p = _probes[i];
              Color iconColor = const Color(0xFF8B949E);
              IconData icon = Icons.circle_outlined;

              if (p.state == ProbeState.running) {
                iconColor = const Color(0xFFD29922);
                icon = Icons.refresh_rounded;
              } else if (p.state == ProbeState.passed) {
                iconColor = const Color(0xFF3FB950);
                icon = Icons.check_circle_rounded;
              } else if (p.state == ProbeState.failed) {
                iconColor = const Color(0xFFF85149);
                icon = Icons.cancel_rounded;
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: iconColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.title,
                            style: TextStyle(
                              color: p.state == ProbeState.passed ? Colors.white : const Color(0xFFC9D1D9),
                              fontWeight: p.state == ProbeState.passed ? FontWeight.bold : FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                          if (p.resultDetails != null)
                            Text(
                              p.resultDetails!,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: p.state == ProbeState.passed ? const Color(0xFF3FB950) : const Color(0xFF8B949E),
                                fontSize: 10,
                              ),
                            ),
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

  Widget _buildManualTriggersCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🕹️ MANUAL COMMAND INJECTORS',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8B949E),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildActionBtn('📳 Vibrate Watch', () {
                if (_primaryWriteChar != null) {
                  _sendRawBytes(_primaryWriteChar!, HiWatchProProtocol.buildFindWatchCommand());
                }
              }),
              _buildActionBtn('❤️ Start Pulse Sensor', () {
                if (_primaryWriteChar != null) {
                  _sendRawBytes(_primaryWriteChar!, HiWatchProProtocol.buildStartHeartRateMeasureCommand());
                }
              }),
              _buildActionBtn('🩺 Measure BP', () {
                if (_primaryWriteChar != null) {
                  _sendRawBytes(_primaryWriteChar!, HiWatchProProtocol.buildStartBloodPressureMeasureCommand());
                }
              }),
              _buildActionBtn('🚶 Step Stream ON', () {
                if (_primaryWriteChar != null) {
                  _sendRawBytes(_primaryWriteChar!, HiWatchProProtocol.buildTurnOnRealTimeStepCommand());
                }
              }),
              _buildActionBtn('⏰ Sync Clock', () {
                if (_primaryWriteChar != null) {
                  _sendRawBytes(_primaryWriteChar!, HiWatchProProtocol.buildHiWatchTimeSyncCommand());
                }
              }),
              _buildActionBtn('🔄 Send ACK', () {
                if (_primaryWriteChar != null) {
                  _sendRawBytes(_primaryWriteChar!, HiWatchProProtocol.buildReturnAckCommand(0x15, 0x00, 0x01));
                }
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(String label, VoidCallback onPressed) {
    final enabled = _primaryWriteChar != null;
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

  Widget _buildCustomHexSender() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '✍️ CUSTOM RAW HEX SENDER',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8B949E),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customHexController,
                  style: const TextStyle(fontFamily: 'monospace', color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'e.g. CD 00 06 12 01 04 00 01 01',
                    hintStyle: TextStyle(color: Color(0xFF484F58), fontSize: 12),
                    filled: true,
                    fillColor: Color(0xFF0D1117),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF30363D)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF58A6FF)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: _primaryWriteChar != null ? _sendCustomHex : null,
                child: const Text('Send TX', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServicesAccordion() {
    if (_discoveredServices.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: ExpansionTile(
        title: Text(
          '🔍 DISCOVERED GATT SERVICES (${_discoveredServices.length})',
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B949E),
          ),
        ),
        children: _discoveredServices.map((s) {
          final sUuid = s.uuid.toString();
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Service: $sUuid",
                  style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF58A6FF), fontSize: 11, fontWeight: FontWeight.bold),
                ),
                ...s.characteristics.map((c) {
                  final props = [];
                  if (c.properties.write || c.properties.writeWithoutResponse) props.add("W");
                  if (c.properties.notify || c.properties.indicate) props.add("N");
                  if (c.properties.read) props.add("R");
                  return Padding(
                    padding: const EdgeInsets.only(left: 12, top: 2),
                    child: Text(
                      "└─ Char: ${c.uuid} [${props.join('/')}]",
                      style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF8B949E), fontSize: 10),
                    ),
                  );
                }),
                const SizedBox(height: 6),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTerminalCard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF000000), // Pure Black Hacker Terminal
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
                  Text(
                    'LIVE HEX TERMINAL & SNIFFER',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3FB950),
                    ),
                  ),
                ],
              ),
              Text(
                '${_logs.length} entries',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF8B949E)),
              ),
            ],
          ),
          const Divider(color: Color(0xFF21262D), height: 12),
          SizedBox(
            height: 240,
            child: _logs.isEmpty
                ? const Center(
                    child: Text(
                      'Ready. Connect watch and run probe to inspect live packets.',
                      style: TextStyle(fontFamily: 'monospace', color: Color(0xFF484F58), fontSize: 11),
                    ),
                  )
                : ListView.builder(
                    controller: _logScrollController,
                    itemCount: _logs.length,
                    itemBuilder: (context, i) {
                      final l = _logs[i];
                      Color col = const Color(0xFFC9D1D9);
                      if (l.type == LogType.tx) col = const Color(0xFF58A6FF);
                      if (l.type == LogType.rx) col = const Color(0xFFD29922);
                      if (l.type == LogType.success) col = const Color(0xFF3FB950);
                      if (l.type == LogType.error) col = const Color(0xFFF85149);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1.5),
                        child: Text(
                          "[${l.formattedTime}] ${l.message}",
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: col,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
