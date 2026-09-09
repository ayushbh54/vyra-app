import 'package:health/health.dart';

/// Wraps the `health` package (pub.dev, v13.3.2) to sync
/// Steps / Active Calories Burned / Heart Rate from
/// Health Connect (Android) or Apple Health (iOS).
///
/// Design notes:
/// - Never throws. Every public method swallows platform / permission
///   errors and returns a "safe empty" result (`false` or `{}`), so the
///   calling screen never needs try/catch and never crashes if
///   Health Connect isn't installed or the user denies access.
/// - `fetchTodaySummary()` fetches each metric independently, so if (say)
///   heart-rate read fails but steps succeeds, steps are still returned
///   (partial data > no data).
class HealthSyncService {
  HealthSyncService() : _health = Health();

  final Health _health;

  bool _configured = false;

  /// The 3 data types this feature cares about.
  static const List<HealthDataType> _types = <HealthDataType>[
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.HEART_RATE,
  ];

  /// `Health().configure()` must run once before any other call.
  /// Safe to call repeatedly — only configures on the first call.
  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Requests read access for steps / active energy / heart rate.
  ///
  /// Returns `true` only if the user actually granted access.
  /// Returns `false` (never throws) if:
  ///  - Health Connect isn't installed on the device (Android), or
  ///  - the user denies the permission dialog, or
  ///  - any platform exception occurs.
  Future<bool> requestPermissions() async {
    try {
      await _ensureConfigured();

      final bool alreadyGranted =
          await _health.hasPermissions(_types) ?? false;
      if (alreadyGranted) return true;

      final bool granted = await _health.requestAuthorization(_types);
      return granted;
    } catch (_) {
      // Health Connect not installed / user denied / platform exception.
      // Deliberately swallowed — caller just sees "not connected".
      return false;
    }
  }

  /// Quick check (no permission prompt) of whether we currently have
  /// read access. Useful for restoring "Connected" status on screen
  /// load without re-triggering the OS permission dialog.
  Future<bool> hasPermissions() async {
    try {
      await _ensureConfigured();
      return await _health.hasPermissions(_types) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Fetches today's (since local midnight) steps, active calories
  /// burned, and average heart rate.
  ///
  /// Returns a map with only the keys that were actually available:
  ///   {'steps': 6421, 'caloriesBurned': 312, 'heartRateBpm': 78}
  /// Returns an empty map if nothing could be read (never throws).
  Future<Map<String, num>> fetchTodaySummary() async {
    final Map<String, num> summary = <String, num>{};

    try {
      await _ensureConfigured();
    } catch (_) {
      // Health Connect / Apple Health unavailable on this device.
      return summary;
    }

    final DateTime now = DateTime.now();
    final DateTime midnight = DateTime(now.year, now.month, now.day);

    // --- Steps (First attempt: dedicated interval aggregation) -----------
    try {
      final int? steps = await _health.getTotalStepsInInterval(midnight, now);
      if (steps != null && steps > 0) {
        summary['steps'] = steps;
      }
    } catch (_) {
      // Fall through to point-by-point aggregation
    }

    // --- Secondary attempt if steps is still missing or zero -------------
    if (!summary.containsKey('steps') || (summary['steps'] ?? 0) <= 0) {
      try {
        final List<HealthDataPoint> stepPoints = await _health.getHealthDataFromTypes(
          types: const [HealthDataType.STEPS],
          startTime: midnight,
          endTime: now,
        );
        final List<HealthDataPoint> dedupedSteps = _health.removeDuplicates(stepPoints);
        num totalSteps = 0;
        for (final p in dedupedSteps) {
          final v = p.value;
          if (v is NumericHealthValue) {
            totalSteps += v.numericValue;
          }
        }
        if (totalSteps > 0) {
          summary['steps'] = totalSteps.round();
        }
      } catch (_) {}
    }

    // --- Active calories + heart rate -------------------------------------
    try {
      final List<HealthDataPoint> points = await _health.getHealthDataFromTypes(
        types: const [
          HealthDataType.ACTIVE_ENERGY_BURNED,
          HealthDataType.HEART_RATE,
        ],
        startTime: midnight,
        endTime: now,
      );

      final List<HealthDataPoint> deduped = _health.removeDuplicates(points);

      num caloriesSum = 0;
      final List<num> heartRateReadings = <num>[];

      for (final HealthDataPoint point in deduped) {
        final HealthValue value = point.value;
        if (value is! NumericHealthValue) continue;
        final num reading = value.numericValue;

        if (point.type == HealthDataType.ACTIVE_ENERGY_BURNED) {
          caloriesSum += reading;
        } else if (point.type == HealthDataType.HEART_RATE) {
          heartRateReadings.add(reading);
        }
      }

      if (caloriesSum > 0) {
        summary['caloriesBurned'] = caloriesSum.round();
      }
      if (heartRateReadings.isNotEmpty) {
        final double avg =
            heartRateReadings.reduce((a, b) => a + b) / heartRateReadings.length;
        summary['heartRateBpm'] = avg.round();
      }
    } catch (_) {
      // Leave calories/heart-rate out; steps (if any) are still returned.
    }

    return summary;
  }
}
