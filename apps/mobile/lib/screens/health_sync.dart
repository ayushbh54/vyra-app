// ─────────────────────────────────────────────────────────────────────────
// ASSUMPTION NOTE (please read before wiring this in):
// The uploaded zip contained only the Stitch UI export (HTML + screenshots),
// not the actual lib/theme.dart / lib/widgets/common.dart / lib/api/client.dart
// source. So the exact constructor signatures of VCard / VLabel /
// VDisclaimer / VEmptyState / VLoading / VErrorView are ASSUMED below using
// the most common pattern for this style of design-system widget:
//
//   VCard({Key? key, required Widget child, EdgeInsetsGeometry? padding})
//   VLabel(String text, {TextStyle? style})
//   VDisclaimer({Key? key, required String text, IconData? icon})
//   VEmptyState({Key? key, required IconData icon, required String title, String? message})
//   VLoading({Key? key, String? label})
//   VErrorView({Key? key, required String message, VoidCallback? onRetry})
//
// If your real signatures differ, only the widget-construction lines below
// need renaming — none of the sync/permission logic depends on them.
// ─────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme.dart';
import '../widgets/common.dart';
import '../api/client.dart';
import '../services/health_sync_service.dart';

class HealthSyncScreen extends StatefulWidget {
  const HealthSyncScreen({super.key, required this.api});

  /// Existing VYRA API client (lib/api/client.dart).
  final VyraApi api;

  @override
  State<HealthSyncScreen> createState() => _HealthSyncScreenState();
}

class _HealthSyncScreenState extends State<HealthSyncScreen> {
  static const _prefsLastSyncedKey = 'vyra_health_last_synced_at';
  static const _prefsStepsKey = 'vyra_health_last_steps';
  static const _prefsCaloriesKey = 'vyra_health_last_calories';
  static const _prefsHeartRateKey = 'vyra_health_last_hr';

  final HealthSyncService _healthService = HealthSyncService();

  bool _checkingStatus = true;
  bool _connected = false;
  bool _requesting = false;
  bool _syncing = false;
  String? _error;
  DateTime? _lastSyncedAt;
  Map<String, num> _lastSummary = {};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _restoreLastSyncInfo();
    final granted = await _healthService.hasPermissions();
    if (!mounted) return;
    setState(() {
      _connected = granted;
      _checkingStatus = false;
    });
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
    } catch (_) {
      // SharedPreferences unavailable — non-fatal, just no persisted state.
    }
  }

  Future<void> _connect() async {
    setState(() {
      _requesting = true;
      _error = null;
    });
    final granted = await _healthService.requestPermissions();
    if (!mounted) return;
    setState(() {
      _requesting = false;
      _connected = granted;
      if (!granted) {
        _error =
            'Permission nahi mili. Settings mein Health Connect / Apple Health '
            'kholkar VYRA ko access allow karein.';
      }
    });
  }

  Future<void> _syncNow() async {
    setState(() {
      _syncing = true;
      _error = null;
    });

    try {
      final summary = await _healthService.fetchTodaySummary();

      if (summary.isEmpty) {
        if (!mounted) return;
        setState(() {
          _syncing = false;
          _error = 'Aaj ke liye koi health data nahi mila.';
        });
        return;
      }

      // NOTE: assuming VyraApi.logTracking returns null on success and an
      // error-message string on failure (matches this app's other API
      // methods). Adjust the null-check below if your convention differs.
      final apiError = await widget.api.logTracking(
        summary,
        source: 'health_connect',
      );

      final now = DateTime.now();
      await _persistSyncResult(now, summary);

      if (!mounted) return;
      setState(() {
        _syncing = false;
        _lastSyncedAt = now;
        _lastSummary = summary;
        _error = apiError; // null => no error shown
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _error = 'Sync fail ho gaya. Thodi der baad dobara try karein.';
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
    } catch (_) {
      // Non-fatal — sync still succeeded, just won't survive app restart.
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VColor.bg,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(VSpace.md),
          children: [
            _buildHeader(context),
            SizedBox(height: VSpace.lg),
            _buildHeroCard(),
            SizedBox(height: VSpace.md),
            _buildStatusCard(),
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
              'VYRA aapka biometric health data kabhi sell ya kisi third-party '
              'ad exchange / insurer ko expose nahi karta. Sirf sync ke liye '
              'istemal hota hai.',
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
                'Connect Smartwatch & Devices',
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
        const SizedBox(width: 48), // balances the back button
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
            const Row(
              children: [
                Icon(Icons.watch_rounded, color: VColor.accent, size: 28),
                SizedBox(width: VSpace.sm),
                Icon(Icons.favorite, color: VColor.accentOrange, size: 24),
                SizedBox(width: VSpace.sm),
                Icon(Icons.monitor_heart, color: VColor.accentGreen, size: 24),
              ],
            ),
            const SizedBox(height: VSpace.md),
            const Text(
              'Smartwatch & Biometric Sync',
              style: TextStyle(
                color: VColor.text,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: VSpace.xs),
            const Text(
              'Aapki smartwatch (Wear OS, Samsung Galaxy Watch, Apple Watch, '
              'Garmin, Fitbit, ya Amazfit) ka data Health Connect / HealthKit ke '
              'through real-time VYRA me sync hota hai — live BPM, daily steps aur calories.',
              style: TextStyle(color: VColor.textMid, fontSize: 13, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final dotColor = _connected ? VColor.accentGreen : VColor.textLow;
    final statusText = _checkingStatus
        ? 'Checking…'
        : (_connected ? 'Connected' : 'Not connected');

    return VCard(
      child: Padding(
        padding: EdgeInsets.all(VSpace.md),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            SizedBox(width: VSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: TextStyle(
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
                        style: TextStyle(color: VColor.textLow, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            if (_checkingStatus)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevicesCard() {
    final watchConnected = _connected;
    return VCard(
      child: Padding(
        padding: const EdgeInsets.all(VSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                VLabel('DETECTED & SUPPORTED HARDWARE'),
                Icon(Icons.bluetooth_connected_rounded, size: 16, color: VColor.accent),
              ],
            ),
            const SizedBox(height: VSpace.md),
            _deviceRow(
              icon: Icons.watch_rounded,
              title: 'Smartwatch (Wear OS / Galaxy / Apple)',
              subtitle: watchConnected
                  ? 'Real-time telemetry stream active'
                  : 'Syncs via Health Connect / HealthKit',
              connected: watchConnected,
              badge: watchConnected ? 'ACTIVE' : 'READY',
            ),
            const Divider(height: VSpace.lg, color: VColor.line),
            _deviceRow(
              icon: Icons.phone_android_rounded,
              title: 'Smartphone Sensor Hub',
              subtitle: 'Built-in GPS & pedometer step counter',
              connected: true,
              badge: 'READY',
            ),
            const Divider(height: VSpace.lg, color: VColor.line),
            _deviceRow(
              icon: Icons.monitor_heart_rounded,
              title: 'Bluetooth Heart Rate Monitor (BLE)',
              subtitle: 'Polar H10, Garmin HRM-Pro, Wahoo TICKR',
              connected: watchConnected,
              badge: watchConnected ? 'PAIRED' : 'BLE READY',
            ),
          ],
        ),
      ),
    );
  }

  Widget _deviceRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool connected,
    required String badge,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: connected ? VColor.accentGlow : VColor.surfaceRaised,
            shape: BoxShape.circle,
            border: Border.all(
              color: connected ? VColor.accent : VColor.line,
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: connected ? VColor.accent : VColor.textLow,
          ),
        ),
        const SizedBox(width: VSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: VColor.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: VColor.textLow,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: connected ? VColor.accentGreenGlow : VColor.surfaceRaised,
            borderRadius: BorderRadius.circular(VRadius.sm),
            border: Border.all(
              color: connected ? VColor.accentGreen : VColor.line,
            ),
          ),
          child: Text(
            badge,
            style: TextStyle(
              color: connected ? VColor.accentGreen : VColor.textLow,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final steps = _lastSummary['steps'];
    final calories = _lastSummary['caloriesBurned'];
    final hr = _lastSummary['heartRateBpm'];

    return VCard(
      child: Padding(
        padding: EdgeInsets.all(VSpace.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _statChip('Steps', steps, VColor.accent),
            _statChip('Kcal', calories, VColor.accentOrange),
            _statChip('BPM', hr, VColor.accentGreen),
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
        SizedBox(height: 2),
        Text(label, style: TextStyle(color: VColor.textLow, fontSize: 11)),
      ],
    );
  }

  Widget _buildPrimaryActions() {
    return Column(
      children: [
        // "Connect" — gradient CTA (accent -> accentGreen), matches the
        // reference screenshot's "Allow & Synchronize All" button.
        SizedBox(
          width: double.infinity,
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(VRadius.md),
              gradient: LinearGradient(
                colors: [VColor.accent, VColor.accentGreen],
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(VRadius.md),
                onTap: _requesting ? null : _connect,
                child: Center(
                  child: _requesting
                      ? const VLoading()
                      : Text(
                          _connected
                              ? 'Reconnect Health Connect / Apple Health'
                              : 'Connect to Health Connect / Apple Health',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: VSpace.sm),
        // "Sync now" — outline style, enabled only once connected.
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: (_connected && !_syncing) ? _syncNow : null,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: VColor.surface),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(VRadius.md),
              ),
            ),
            child: _syncing
                ? const VLoading()
                : Text(
                    'Sync now',
                    style: TextStyle(
                      color: VColor.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
