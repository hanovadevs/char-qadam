import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';

final healthServiceProvider = Provider<HealthService>((ref) {
  return HealthService();
});

class HealthService {
  final Health _health = Health();
  int _lastPedometerSteps = 0;
  StreamSubscription<StepCount>? _pedometerSubscription;

  static const List<HealthDataType> _types = [
    HealthDataType.STEPS,
  ];

  HealthService() {
    _initPedometer();
  }

  void _initPedometer() {
    if (kIsWeb) return;
    try {
      _pedometerSubscription = Pedometer.stepCountStream.listen(
        (StepCount event) {
          _lastPedometerSteps = event.steps;
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

  /// Request authorization to read step count data.
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    try {
      final hasPermission = await _health.hasPermissions(_types);
      if (hasPermission == true) return true;

      final requested = await _health.requestAuthorization(_types);
      return requested ?? false;
    } catch (e) {
      debugPrint('Health permission error: $e');
      return false;
    }
  }

  /// Fetch total step count for today (local midnight to now).
  /// Falls back to hardware pedometer sensor if Health Connect is unavailable.
  Future<int> fetchTodaySteps() async {
    if (kIsWeb) return 0;
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      // Attempt Health Connect / Apple HealthKit fetch
      final steps = await _health.getTotalStepsInInterval(midnight, now);
      if (steps != null && steps > 0) {
        return steps;
      }
    } catch (e) {
      debugPrint('Error fetching health steps: $e');
    }

    // Fallback: Return hardware pedometer step count
    return _lastPedometerSteps;
  }

  void dispose() {
    _pedometerSubscription?.cancel();
  }
}
