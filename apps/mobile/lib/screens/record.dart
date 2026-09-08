import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../services/health_sync_service.dart';
import '../theme.dart';
import 'health_sync.dart';

/// RECORD — GPS + Health Connect dual telemetry activity tracking.
///
/// Phase 4 upgrade over the original:
///   - Steps: polled from Health Connect every 10 s during the session
///     so the stat card shows real steps, not an approximation.
///   - Calorie estimate: stride-length model (MET × weight × time) while
///     Health Connect calorie data is unavailable mid-session.
///   - Route: polyline drawn on OpenStreetMap via flutter_map; each GPS
///     fix is a LatLng so the path renders immediately without waiting for
///     the activity to be saved.
///   - Save: uploads GPS points[] + stepCount so the backend can verify
///     the distance claim against steps (stride-length cross-check).
///
/// Accuracy note: steps from Health Connect represent today's total, not
/// just this session. We snapshot steps at _start() and subtract at each
/// poll to get session steps. If the user walked before opening the app,
/// those steps are excluded correctly.
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

enum _RecordState { idle, recording, paused, finished }

class _SportOption {
  const _SportOption(this.label, this.type, this.icon, this.metValue);
  final String label;
  final String type;   // 'run' | 'walk' | 'ride'
  final IconData icon;
  final double metValue; // MET for calorie estimate fallback
}

const _sports = [
  _SportOption('Run',          'run',  Icons.directions_run,  8.0),
  _SportOption('Trail Run',    'run',  Icons.terrain,         9.0),
  _SportOption('Walk',         'walk', Icons.directions_walk, 3.5),
  _SportOption('Hike',         'walk', Icons.hiking,          5.3),
  _SportOption('Ride',         'ride', Icons.directions_bike, 7.5),
  _SportOption('Mountain Bike','ride', Icons.pedal_bike,      8.5),
];

// Avg body weight used when we cannot read it from the profile
const _fallbackWeightKg = 70.0;

class _RecordScreenState extends State<RecordScreen> {
  // ── State machine ──────────────────────────────────────────────────────────
  _RecordState _state = _RecordState.idle;
  _SportOption _sport = _sports[0];

  // ── GPS ────────────────────────────────────────────────────────────────────
  StreamSubscription<Position>? _positionSub;
  final List<Position> _fixes = [];
  double _distanceM = 0;
  final _mapController = MapController();
  bool _followUser = true;

  // ── Timer ──────────────────────────────────────────────────────────────────
  Timer? _ticker;
  DateTime? _startedAt;
  DateTime? _pausedAt;
  Duration _pausedTotal = Duration.zero;
  Duration _elapsed     = Duration.zero;

  // ── Health Connect – steps ─────────────────────────────────────────────────
  final _health         = HealthSyncService();
  bool  _healthGranted  = false;
  int   _stepsAtStart   = 0;   // today's total at moment we hit Start
  int   _sessionSteps   = 0;   // steps since Start = (current total − at-start)
  Timer? _healthPollTimer;

  // ── Misc ───────────────────────────────────────────────────────────────────
  String? _locationError;
  bool    _saving = false;

  // ── MapController needs to be disposed ────────────────────────────────────
  @override
  void dispose() {
    _positionSub?.cancel();
    _ticker?.cancel();
    _healthPollTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Health Connect plumbing
  // ---------------------------------------------------------------------------

  Future<void> _initHealth() async {
    _healthGranted = await _health.requestPermissions();
    if (_healthGranted) {
      final summary = await _health.fetchTodaySummary();
      _stepsAtStart     = (summary['steps'] ?? 0).toInt();
    }
  }

  Future<void> _pollHealth() async {
    if (!_healthGranted) return;
    try {
      final summary = await _health.fetchTodaySummary();
      final total = (summary['steps'] ?? 0).toInt();
      if (mounted && total >= _stepsAtStart) {
        setState(() {
          _sessionSteps     = total - _stepsAtStart;
        });
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Calorie estimate (MET-based fallback while session is live)
  // ---------------------------------------------------------------------------

  int get _estimatedCalories {
    if (_elapsed.inSeconds < 60) return 0;
    final hours   = _elapsed.inSeconds / 3600;
    final met     = _sport.metValue;
    final weight  = _fallbackWeightKg;
    return (met * weight * hours).round();
  }

  // ---------------------------------------------------------------------------
  // GPS / location plumbing
  // ---------------------------------------------------------------------------

  Future<bool> _ensureLocationReady() async {
    setState(() => _locationError = null);

    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      setState(() => _locationError =
          'Enable Location Services in Settings to record your route.');
      return false;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      setState(() => _locationError =
          'VYRA needs location access to record your route. Enable it in Settings.');
      return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Session lifecycle
  // ---------------------------------------------------------------------------

  Future<void> _start() async {
    if (!await _ensureLocationReady()) return;

    // Snapshot today's steps so we get session-only steps correctly
    await _initHealth();

    setState(() {
      _state        = _RecordState.recording;
      _fixes.clear();
      _distanceM    = 0;
      _sessionSteps = 0;
      _elapsed      = Duration.zero;
      _pausedTotal  = Duration.zero;
      _startedAt    = DateTime.now();
      _followUser   = true;
    });

    // 1-second UI clock
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state == _RecordState.recording && _startedAt != null) {
        setState(() => _elapsed = DateTime.now().difference(_startedAt!) - _pausedTotal);
      }
    });

    // Health Connect step poll every 10 seconds
    _healthPollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_state == _RecordState.recording) _pollHealth();
    });

    // GPS stream – 5 m filter to avoid standing-still jitter
    const settings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5,
    );
    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((pos) {
      if (_state != _RecordState.recording) return;
      if (_fixes.isNotEmpty) {
        final last = _fixes.last;
        _distanceM += Geolocator.distanceBetween(
          last.latitude, last.longitude,
          pos.latitude,  pos.longitude,
        );
      }
      setState(() => _fixes.add(pos));

      // Keep map centred on user while _followUser is true
      if (_followUser) {
        _mapController.move(ll.LatLng(pos.latitude, pos.longitude), 16);
      }
    });
  }

  void _pause() {
    setState(() {
      _state    = _RecordState.paused;
      _pausedAt = DateTime.now();
    });
  }

  void _resume() {
    setState(() {
      _state = _RecordState.recording;
      if (_pausedAt != null) _pausedTotal += DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
    });
  }

  void _stop() {
    _positionSub?.cancel();
    _ticker?.cancel();
    _healthPollTimer?.cancel();
    // Do one final health poll so saved step count is as accurate as possible
    _pollHealth();
    setState(() => _state = _RecordState.finished);
  }

  void _discard() {
    setState(() {
      _state        = _RecordState.idle;
      _fixes.clear();
      _distanceM    = 0;
      _elapsed      = Duration.zero;
      _sessionSteps = 0;
    });
  }

  Future<void> _save(String title) async {
    setState(() => _saving = true);
    try {
      final route = _fixes
          .map((p) => RoutePoint(
                lat: p.latitude,
                lng: p.longitude,
                t: p.timestamp.difference(_startedAt ?? p.timestamp).inSeconds,
              ))
          .toList();

      await context.read<VyraApi>().createActivity(
            type:        _sport.type,
            title:       title.trim().isEmpty ? _sport.label : title.trim(),
            distanceM:   _distanceM,
            durationSec: _elapsed.inSeconds.clamp(1, 86400),
            route:       route,
            startedAt:   _startedAt ?? DateTime.now(),
            stepCount:   _sessionSteps > 0 ? _sessionSteps : null,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_sessionSteps > 0
              ? 'Saved! $_sessionSteps steps · ${_distanceKm.toStringAsFixed(2)} km'
              : 'Activity saved — check your Home feed.'),
          backgroundColor: VColor.accentGreen.withOpacity(0.9),
        ),
      );
      _discard();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Formatting helpers
  // ---------------------------------------------------------------------------

  String get _timeLabel {
    final h  = _elapsed.inHours;
    final m  = _elapsed.inMinutes % 60;
    final s  = _elapsed.inSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  double get _distanceKm => _distanceM / 1000;

  String get _paceLabel {
    if (_distanceKm <= 0.02) return '--:--';
    final secPerKm = _elapsed.inSeconds / _distanceKm;
    if (!secPerKm.isFinite) return '--:--';
    final m = secPerKm ~/ 60;
    final s = (secPerKm % 60).round();
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VColor.bg,
      body: SafeArea(
        child: Stack(children: [
          _buildMap(),
          // Health Connect badge (top-left)
          if (_state != _RecordState.idle) _buildHealthBadge(),
          // Bottom sheet
          if (_state == _RecordState.idle)   _buildSportBar()
          else                               _buildStatsSheet(),
        ]),
      ),
    );
  }

  // ── Map ──────────────────────────────────────────────────────────────────────

  Widget _buildMap() {
    final points = _fixes.map((p) => ll.LatLng(p.latitude, p.longitude)).toList();
    final center = points.isNotEmpty
        ? points.last
        : const ll.LatLng(28.6139, 77.2090); // Delhi fallback

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 15,
        // When user manually pans, stop auto-following
        onPositionChanged: (_, hasGesture) {
          if (hasGesture && _followUser) {
            setState(() => _followUser = false);
          }
        },
      ),
      children: [
        // Dark-style OSM tile layer
        TileLayer(
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.vyra.app',
          // Fallback to standard OSM if CartoDB is unavailable
          fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        ),
        // START marker (green dot)
        if (points.isNotEmpty)
          MarkerLayer(markers: [
            Marker(
              point: points.first,
              width: 20, height: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: VColor.accentGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: VColor.bg, width: 3),
                  boxShadow: [BoxShadow(color: VColor.accentGreenGlow, blurRadius: 8)],
                ),
              ),
            ),
          ]),
        // Route polyline — cyan glow stroke
        if (points.length > 1) ...[
          PolylineLayer(polylines: [
            // Glow layer
            Polyline(points: points, color: VColor.accentGlow, strokeWidth: 10),
            // Main line
            Polyline(points: points, color: VColor.accent, strokeWidth: 4),
          ]),
        ],
        // Current position marker (pulsing cyan dot)
        if (points.isNotEmpty)
          MarkerLayer(markers: [
            Marker(
              point: points.last,
              width: 22, height: 22,
              child: _PulsingDot(),
            ),
          ]),
      ],
    );
  }

  // ── Health badge (top-left during session) ──────────────────────────────────

  Widget _buildHealthBadge() {
    return Positioned(
      top: 12, left: 12,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Re-centre button
        GestureDetector(
          onTap: () {
            if (_fixes.isNotEmpty) {
              final last = _fixes.last;
              _mapController.move(ll.LatLng(last.latitude, last.longitude), 16);
              setState(() => _followUser = true);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: VColor.surface.withOpacity(0.92),
              shape: BoxShape.circle,
              border: Border.all(color: _followUser ? VColor.accent : VColor.line),
            ),
            child: Icon(Icons.my_location_rounded,
                color: _followUser ? VColor.accent : VColor.textLow, size: 20),
          ),
        ),
        const SizedBox(height: 8),
        // Steps badge (tap to open Smartwatch / Health Connect sync)
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HealthSyncScreen(api: context.read<VyraApi>()),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: VColor.surface.withOpacity(0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: VColor.accentGreen.withOpacity(0.4)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.directions_walk_rounded, color: VColor.accentGreen, size: 14),
              const SizedBox(width: 5),
              Text(
                _healthGranted
                    ? '$_sessionSteps steps'
                    : 'Steps: connect Watch/Health',
                style: TextStyle(
                  color: _healthGranted ? VColor.accentGreen : VColor.textLow,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: VColor.textLow, size: 14),
            ]),
          ),
        ),
        if (_estimatedCalories > 0) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: VColor.surface.withOpacity(0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: VColor.accentOrange.withOpacity(0.4)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: VColor.accentOrange, size: 14),
              const SizedBox(width: 5),
              Text('~$_estimatedCalories kcal',
                  style: const TextStyle(
                      color: VColor.accentOrange,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ]),
    );
  }

  // ── Bottom sheet (idle) ─────────────────────────────────────────────────────

  Widget _buildSportBar() {
    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        decoration: const BoxDecoration(
          color: VColor.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Drag handle
          Center(child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(color: VColor.line, borderRadius: BorderRadius.circular(2)),
          )),

          if (_locationError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: VColor.critSoft, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.location_off_rounded, color: VColor.crit, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_locationError!,
                    style: const TextStyle(color: VColor.crit, fontSize: 12))),
                TextButton(
                  onPressed: Geolocator.openLocationSettings,
                  child: const Text('Fix', style: TextStyle(color: VColor.accent, fontSize: 12)),
                ),
              ]),
            ),
            const SizedBox(height: 12),
          ],

          const Text('Choose Activity',
              style: TextStyle(color: VColor.text, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),

          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _sports.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final sp = _sports[i];
                final sel = sp.label == _sport.label;
                return ChoiceChip(
                  label: Text(sp.label),
                  avatar: Icon(sp.icon, size: 16,
                      color: sel ? VColor.textOnAccent : VColor.textMid),
                  selected: sel,
                  onSelected: (_) => setState(() => _sport = sp),
                  selectedColor: VColor.accent,
                  backgroundColor: VColor.surfaceRaised,
                  labelStyle: TextStyle(
                      color: sel ? VColor.textOnAccent : VColor.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          Center(
            child: GestureDetector(
              onTap: _start,
              child: Container(
                width: 76, height: 76,
                decoration: BoxDecoration(
                  color: VColor.accent,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: VColor.accentGlow, blurRadius: 28, spreadRadius: 3)],
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: VColor.textOnAccent, size: 44),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Bottom sheet (recording / paused / finished) ────────────────────────────

  Widget _buildStatsSheet() {
    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
        decoration: BoxDecoration(
          color: VColor.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 16)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Drag handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(color: VColor.line, borderRadius: BorderRadius.circular(2)),
          ),

          // ── Primary stats row ──────────────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _StatCell(label: 'Time', value: _timeLabel, accent: VColor.accent),
            _StatCell(
              label: 'Distance',
              value: _distanceKm.toStringAsFixed(2),
              unit: 'km',
              accent: VColor.accentGreen,
            ),
            _StatCell(label: 'Pace', value: _paceLabel, unit: '/km', accent: VColor.accentOrange),
          ]),

          const SizedBox(height: 10),

          // ── Secondary stats row (steps + calories) ─────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _StatCell(
              label: 'Steps',
              value: _healthGranted ? '$_sessionSteps' : '--',
              accent: VColor.accentGreen,
              icon: Icons.directions_walk_rounded,
              small: true,
            ),
            _StatCell(
              label: 'Calories',
              value: _estimatedCalories > 0 ? '~$_estimatedCalories' : '--',
              unit: 'kcal',
              accent: VColor.accentOrange,
              icon: Icons.local_fire_department_rounded,
              small: true,
            ),
            _StatCell(
              label: 'GPS fixes',
              value: '${_fixes.length}',
              accent: VColor.textMid,
              icon: Icons.satellite_alt_rounded,
              small: true,
            ),
          ]),

          const SizedBox(height: 16),

          if (_state == _RecordState.finished)
            _buildFinishedActions()
          else
            _buildLiveActions(),
        ]),
      ),
    );
  }

  Widget _buildLiveActions() {
    final recording = _state == _RecordState.recording;
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      _RoundBtn(
        icon: recording ? Icons.pause_rounded : Icons.play_arrow_rounded,
        label: recording ? 'Pause' : 'Resume',
        onTap: recording ? _pause : _resume,
        color: VColor.accent,
        filled: true,
      ),
      _RoundBtn(
        icon: Icons.stop_rounded,
        label: 'Stop',
        onTap: _stop,
        color: VColor.crit,
        filled: false,
      ),
    ]);
  }

  Widget _buildFinishedActions() {
    final titleCtrl = TextEditingController(text: _sport.label);
    return Column(children: [
      // Summary card
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: VColor.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: VColor.accentGreenGlow),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _SummaryChip('${_distanceKm.toStringAsFixed(2)} km', Icons.route_rounded, VColor.accent),
          _SummaryChip(_timeLabel, Icons.timer_rounded, VColor.textMid),
          if (_sessionSteps > 0)
            _SummaryChip('$_sessionSteps steps', Icons.directions_walk_rounded, VColor.accentGreen),
          if (_estimatedCalories > 0)
            _SummaryChip('~$_estimatedCalories kcal', Icons.local_fire_department_rounded, VColor.accentOrange),
        ]),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: titleCtrl,
        style: const TextStyle(color: VColor.text),
        decoration: InputDecoration(
          labelText: 'Name this activity',
          labelStyle: const TextStyle(color: VColor.textLow),
          filled: true,
          fillColor: VColor.surfaceRaised,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: _saving ? null : _discard,
          style: OutlinedButton.styleFrom(
            foregroundColor: VColor.textMid,
            side: const BorderSide(color: VColor.line),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Discard'),
        )),
        const SizedBox(width: 12),
        Expanded(child: FilledButton(
          onPressed: _saving ? null : () => _save(titleCtrl.text),
          style: FilledButton.styleFrom(
            backgroundColor: VColor.accent,
            foregroundColor: VColor.textOnAccent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _saving
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: VColor.textOnAccent))
              : const Text('Save Activity', style: TextStyle(fontWeight: FontWeight.w700)),
        )),
      ]),
    ]);
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

/// Pulsing cyan dot — current GPS position indicator
class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _scale = Tween(begin: 0.7, end: 1.3).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: _scale,
    child: Container(
      decoration: BoxDecoration(
        color: VColor.accent,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [BoxShadow(color: VColor.accentGlow, blurRadius: 12, spreadRadius: 2)],
      ),
    ),
  );
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label, required this.value, required this.accent,
    this.unit, this.icon, this.small = false,
  });
  final String label;
  final String value;
  final String? unit;
  final Color accent;
  final IconData? icon;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (icon != null) Icon(icon, color: accent, size: small ? 14 : 18),
      RichText(text: TextSpan(
        children: [
          TextSpan(text: value, style: TextStyle(
            color: accent,
            fontSize: small ? 16 : 24,
            fontWeight: FontWeight.w800,
          )),
          if (unit != null)
            TextSpan(text: ' $unit', style: TextStyle(
              color: accent.withOpacity(0.7),
              fontSize: small ? 10 : 13,
            )),
        ],
      )),
      Text(label, style: const TextStyle(color: VColor.textLow, fontSize: 10)),
    ]);
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.label, required this.onTap,
      required this.color, required this.filled});
  final IconData icon; final String label;
  final VoidCallback onTap; final Color color; final bool filled;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          color: filled ? color : VColor.surfaceRaised,
          shape: BoxShape.circle,
          border: filled ? null : Border.all(color: color, width: 2),
          boxShadow: filled ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12)] : null,
        ),
        child: Icon(icon, color: filled ? VColor.textOnAccent : color, size: 32),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip(this.text, this.icon, this.color);
  final String text; final IconData icon; final Color color;

  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, color: color, size: 18),
    const SizedBox(height: 2),
    Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
  ]);
}
