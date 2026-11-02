import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/client.dart';

/// SMART COGNITIVE ACTIVE ENGAGEMENT TRACKER
///
/// Accurately tracks genuine active application engagement (coaching, viewing 3D avatar,
/// reading health reports, food scanning, pose tracking, chatting with coach).
///
/// Prevents phantom/unusual idle counting:
/// - Intercepts all screen interactions (touches, scrolls, gestures, keystrokes).
/// - Enforces a strict 60-second idle threshold [idleTimeoutSeconds]. If the user leaves
///   the app open on a table without interacting, timer immediately halts.
/// - Supports explicit active sessions (camera pose tracking, voice coach playback)
///   so hands-free exercises are counted accurately.
class ActivityUsageService with WidgetsBindingObserver {
  ActivityUsageService._();
  static final ActivityUsageService instance = ActivityUsageService._();

  VyraApi? _api;
  Timer? _samplingTimer;
  bool _isInitialized = false;

  /// User interaction timestamp
  DateTime _lastInteractionTime = DateTime.now();

  /// Explicit active sessions (e.g. camera pose tracking, voice audio playing)
  final Set<String> _activeSessions = <String>{};

  /// Idle timeout: 60 seconds of zero interaction stops counting
  static const int idleTimeoutSeconds = 60;

  /// Sampling interval: 5 seconds
  static const int samplingIntervalSeconds = 5;

  /// Flush interval: 30 seconds of accumulated active time
  static const int flushThresholdSeconds = 30;

  /// Active seconds accumulated since last flush
  int _pendingActiveSeconds = 0;

  /// Is the app currently in the foreground (resumed)
  bool _isAppInForeground = true;

  void initialize(VyraApi api) {
    if (_isInitialized) {
      _api = api;
      return;
    }
    _api = api;
    _isInitialized = true;
    _lastInteractionTime = DateTime.now();
    _isAppInForeground = true;
    WidgetsBinding.instance.addObserver(this);

    // Initial checkin check and start active engagement sampling loop
    unawaited(_performAutoCheckin());
    _startSamplingLoop();
  }

  /// Called globally on every touch, scroll, drag, or key event in the app.
  void notifyUserInteraction() {
    _lastInteractionTime = DateTime.now();
  }

  /// Starts an explicit hands-free active session (e.g. camera pose tracking).
  void beginActiveSession(String sessionId) {
    _activeSessions.add(sessionId);
    _lastInteractionTime = DateTime.now();
  }

  /// Ends an explicit hands-free active session.
  void endActiveSession(String sessionId) {
    _activeSessions.remove(sessionId);
    _lastInteractionTime = DateTime.now();
  }

  /// Checks whether the user is genuinely engaged with the app right now.
  bool get isActivelyEngaged {
    if (!_isAppInForeground) return false;

    // 1. Hands-free active session (e.g. squatting in front of camera pose tracker)
    if (_activeSessions.isNotEmpty) return true;

    // 2. Interactive engagement within idle threshold
    final elapsedSec = DateTime.now().difference(_lastInteractionTime).inSeconds;
    return elapsedSec <= idleTimeoutSeconds;
  }

  String _todayDateStr() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _performAutoCheckin() async {
    final api = _api;
    if (api == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayDateStr();
      const lastCheckinKey = 'vyra_last_checkin_date';
      final lastCheckin = prefs.getString(lastCheckinKey);

      if (lastCheckin != today) {
        final res = await api.checkin(date: today);
        if (res['ok'] == true) {
          await prefs.setString(lastCheckinKey, today);
        }
      }
    } catch (_) {
      // Background non-fatal catch
    }
  }

  void _startSamplingLoop() {
    _samplingTimer?.cancel();
    _samplingTimer = Timer.periodic(
      const Duration(seconds: samplingIntervalSeconds),
      (_) => _onSamplingTick(),
    );
  }

  void _stopSamplingLoop() {
    _samplingTimer?.cancel();
    _samplingTimer = null;
    unawaited(_flushUsageToStorageAndCloud());
  }

  void _onSamplingTick() {
    if (isActivelyEngaged) {
      _pendingActiveSeconds += samplingIntervalSeconds;
      if (_pendingActiveSeconds >= flushThresholdSeconds) {
        unawaited(_flushUsageToStorageAndCloud());
      }
    }
  }

  /// Manually trigger a flush of pending active usage to SharedPreferences and backend.
  Future<void> forceFlush() => _flushUsageToStorageAndCloud();

  Future<void> _flushUsageToStorageAndCloud() async {
    final api = _api;
    final toFlush = _pendingActiveSeconds;
    if (toFlush <= 0) return;

    // Deduct immediately so concurrent ticks don't double count
    _pendingActiveSeconds = 0;
    final today = _todayDateStr();

    try {
      final prefs = await SharedPreferences.getInstance();
      final localUsageKey = 'vyra_active_usage_sec_$today';
      final currentTotal = (prefs.getInt(localUsageKey) ?? 0) + toFlush;
      await prefs.setInt(localUsageKey, currentTotal);

      // Heartbeat sync with backend
      if (api != null) {
        await api.sendHeartbeat(usageSec: toFlush, date: today);
      }
    } catch (e) {
      // Restore failed seconds to pending so they sync on next attempt
      _pendingActiveSeconds += toFlush;
      if (kDebugMode) {
        debugPrint('[ActivityUsageService] Heartbeat flush postponed: $e');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isAppInForeground = true;
      _lastInteractionTime = DateTime.now();
      unawaited(_performAutoCheckin());
      _startSamplingLoop();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _isAppInForeground = false;
      _stopSamplingLoop();
    }
  }

  /// Returns today's total active engagement time in seconds.
  Future<int> getTodayLocalUsageSeconds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayDateStr();
      final savedSec = prefs.getInt('vyra_active_usage_sec_$today') ?? 0;
      return savedSec + _pendingActiveSeconds;
    } catch (_) {
      return _pendingActiveSeconds;
    }
  }

  /// Formats seconds into human-readable hours and minutes (e.g. "0h 42m").
  static String formatHoursAndMinutes(int seconds) {
    final m = seconds ~/ 60;
    final h = m ~/ 60;
    final remM = m % 60;
    return '${h}h ${remM}m';
  }

  void dispose() {
    _stopSamplingLoop();
    WidgetsBinding.instance.removeObserver(this);
    _isInitialized = false;
  }
}
