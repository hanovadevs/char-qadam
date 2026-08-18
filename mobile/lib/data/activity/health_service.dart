import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

final healthServiceProvider = Provider<HealthService>((ref) {
  return HealthService();
});

class HealthService {
  final Health _health = Health();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Latest cumulative step count reported by the hardware pedometer.
  /// The pedometer reports steps since device boot, NOT steps today.
  int? _cumulativeSteps;
  StreamSubscription<StepCount>? _pedometerSubscription;

  static const List<HealthDataType> _types = [
    HealthDataType.STEPS,
  ];

  static const _baselineDateKey = 'pedometer_baseline_date';
  static const _baselineValueKey = 'pedometer_baseline_value';

  HealthService() {
    _initPedometer();
  }

  void _initPedometer() {
    if (kIsWeb) return;
    try {
      _pedometerSubscription = Pedometer.stepCountStream.listen(
        (StepCount event) {
          _cumulativeSteps = event.steps;
        },
        onError: (error) {
          debugPrint('Pedometer error: $error');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Failed to initialize pedometer stream: $e');
    }
  }

  /// Request all permissions needed for step tracking.
  ///
  /// This requests BOTH:
  ///  - ACTIVITY_RECOGNITION (Android 10+) / Motion (iOS): required for the
  ///    hardware pedometer stream to emit any events at all.
  ///  - Health Connect / Apple HealthKit read access to step data.
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    // 1. Runtime sensor permission — WITHOUT this the pedometer stream is silent.
    try {
      final status = await Permission.activityRecognition.request();
      if (!status.isGranted) {
        debugPrint('Activity recognition permission not granted: $status');
      }
    } catch (e) {
      debugPrint('Activity recognition permission error: $e');
    }

    // 2. Health Connect / HealthKit authorization (best effort).
    try {
      final hasPermission = await _health.hasPermissions(_types);
      if (hasPermission == true) return true;
      return await _health.requestAuthorization(_types);
    } catch (e) {
      debugPrint('Health permission error: $e');
      // Sensor permission alone is enough for the pedometer fallback.
      return await Permission.activityRecognition.isGranted;
    }
  }

  /// Fetch total step count for today (local midnight to now).
  ///
  /// Prefers Health Connect / HealthKit (which aggregates steps by day).
  /// Falls back to the hardware pedometer, converting the cumulative
  /// since-boot count into steps-since-first-reading-today via a stored baseline.
  Future<int> fetchTodaySteps() async {
    if (kIsWeb) return 0;
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      final steps = await _health.getTotalStepsInInterval(midnight, now);
      if (steps != null && steps > 0) {
        return steps;
      }
    } catch (e) {
      debugPrint('Error fetching health steps: $e');
    }

    return await _pedometerStepsToday();
  }

  /// Convert the cumulative (since-boot) pedometer reading into an estimate of
  /// today's steps using a per-day baseline persisted in secure storage.
  Future<int> _pedometerStepsToday() async {
    final cumulative = _cumulativeSteps;
    if (cumulative == null) return 0;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final baselineDate = await _storage.read(key: _baselineDateKey);
    final baselineValueStr = await _storage.read(key: _baselineValueKey);
    int? baseline = int.tryParse(baselineValueStr ?? '');

    // Start a new baseline when the day rolls over, on first run, or if the
    // device rebooted (cumulative dropped below the stored baseline).
    if (baselineDate != today || baseline == null || cumulative < baseline) {
      baseline = cumulative;
      await _storage.write(key: _baselineDateKey, value: today);
      await _storage.write(key: _baselineValueKey, value: cumulative.toString());
    }

    final todaySteps = cumulative - baseline;
    return todaySteps < 0 ? 0 : todaySteps;
  }

  void dispose() {
    _pedometerSubscription?.cancel();
  }
}
