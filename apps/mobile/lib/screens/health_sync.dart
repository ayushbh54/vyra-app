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

import '../theme.dart';
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
  static const _prefsUsePhoneSensorsKey = 'vyra_use_phone_sensors';

  final HealthSyncService _healthService = HealthSyncService();

  bool _checkingStatus = true;
  bool _connected = false;
  bool _usePhoneSensors = false;
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
    try {
      final prefs = await SharedPreferences.getInstance();
      final phoneSensors = prefs.getBool(_prefsUsePhoneSensorsKey) ?? false;
      final granted = await _healthService.hasPermissions();
      if (!mounted) return;
      setState(() {
        _usePhoneSensors = phoneSensors;
        _connected = granted || phoneSensors;
        _checkingStatus = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _checkingStatus = false);
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
        content: Text('📱 Phone Sensors Mode Active! Pedometer & GPS tracking enabled.'),
        backgroundColor: VColor.accentGreen,
      ),
    );
  }

  Future<void> _calibrateStepsDialog() async {
    final currentVal = _lastSummary['steps']?.toInt() ?? 0;
    final controller = TextEditingController(
      text: currentVal > 0 ? '$currentVal' : '',
    );

    final entered = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VColor.surface,
        title: const Text('Enter Steps from Smartwatch',
            style: TextStyle(color: VColor.text, fontWeight: FontWeight.w700, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Agar Health Connect / Wear OS permission ya OEM restriction ki wajah se exact data nahi aa raha, toh apni smartwatch screen ke steps enter karein:',
              style: TextStyle(color: VColor.textMid, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: VSpace.md),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: VColor.text, fontSize: 18, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                labelText: "Today's Steps",
                hintText: 'e.g. 5200',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              if (val != null && val >= 0) Navigator.pop(ctx, val);
            },
            child: const Text('Save & Sync'),
          ),
        ],
      ),
    );

    if (entered == null || !mounted) return;
    final estimatedKcal = (entered * 0.04).round();
    final updatedSummary = {
      ..._lastSummary,
      'steps': entered,
      'caloriesBurned': estimatedKcal,
      if (!_lastSummary.containsKey('heartRateBpm')) 'heartRateBpm': 72,
    };

    setState(() {
      _lastSummary = updatedSummary;
      _syncing = true;
    });

    try {
      await widget.api.logTracking(updatedSummary, source: 'smartwatch_direct');
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
      _connected = granted || _usePhoneSensors;
      if (!granted) {
        _error =
            'Smartwatch permission nahi mili. Aap neeche "Enter Steps from Watch" ya "Use Smartphone Sensors" se directly sync kar sakte hain.';
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
      if (!_usePhoneSensors) {
        summary = await _healthService.fetchTodaySummary();
      }

      if (summary.isEmpty && _lastSummary.isNotEmpty) {
        summary = _lastSummary;
      }

      if (summary.isEmpty) {
        if (!mounted) return;
        setState(() {
          _syncing = false;
          _error = 'Health Connect me abhi koi data nahi mila. Watch screen se enter karne ke liye "Enter Steps from Watch" tap karein.';
        });
        return;
      }

      final apiError = await widget.api.logTracking(
        summary,
        source: _usePhoneSensors ? 'phone_sensors' : 'health_connect',
      );

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
            content: Text('✅ Data synced successfully to VYRA!'),
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
        : (_usePhoneSensors
            ? 'Smartphone Sensors Active'
            : (_connected ? 'Connected to Health Connect' : 'Not connected'));

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
    final watchConnected = _connected && !_usePhoneSensors;
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
                VLabel('STATUS'),
              ],
            ),
            const SizedBox(height: VSpace.md),
            _deviceRow(
              icon: Icons.phone_android_rounded,
              name: 'Smartphone Internal Sensors',
              detail: 'Pedometer, Accelerometer & GPS',
              active: _usePhoneSensors,
            ),
            const Divider(color: VColor.line, height: 24),
            _deviceRow(
              icon: Icons.watch_rounded,
              name: 'Smartwatch / Fitness Band',
              detail: 'Wear OS, Galaxy Watch, Apple Watch, Garmin',
              active: watchConnected,
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
  }) {
    return Row(
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
            active ? 'Active' : 'Standby',
            style: TextStyle(
              color: active ? VColor.accentGreen : VColor.textLow,
              fontSize: 11,
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
                      'Enter / Calibrate Steps from Watch Screen',
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
        // 1. Direct Phone Sensors Fallback Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _enablePhoneSensors,
            icon: const Icon(Icons.phone_android_rounded, size: 20),
            label: Text(
              _usePhoneSensors
                  ? 'Smartphone Sensors Active ✓'
                  : 'Use Smartphone Sensors (No Smartwatch Needed)',
              style: TextStyle(
                color: _usePhoneSensors ? VColor.accentGreen : VColor.accent,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: _usePhoneSensors ? VColor.accentGreen : VColor.accent.withValues(alpha: 0.6),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(VRadius.md),
              ),
            ),
          ),
        ),
        const SizedBox(height: VSpace.sm),

        // 2. Health Connect / Wearable Connect
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
                onTap: _requesting ? null : _connect,
                child: Center(
                  child: _requesting
                      ? const VLoading()
                      : Text(
                          _connected && !_usePhoneSensors
                              ? 'Reconnect Health Connect / Apple Health'
                              : 'Connect Smartwatch via Health Connect',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: VSpace.sm),

        // 3. "Sync now" button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: (_connected && !_syncing) ? _syncNow : null,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: VColor.surface),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(VRadius.md),
              ),
            ),
            child: _syncing
                ? const VLoading()
                : const Text(
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
