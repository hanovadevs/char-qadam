import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

final healthServiceProvider = Provider<HealthService>((ref) {
  final service = HealthService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// High-accuracy step counter service.
///
/// Multi-layer Architecture:
/// 1. Primary Source: Google Health Connect (Android) / Apple HealthKit (iOS)
///    - Handles background aggregation, sensor fusion, and multi-source deduplication.
/// 2. Fallback Source: Hardware Pedometer (`Sensor.TYPE_STEP_COUNTER`)
///    - Calibrated against a persistent daily baseline stored in SharedPreferences.
///    - Handles device reboots, day rollovers at midnight, and sensor warm-up cleanly.
class HealthService {
  final Health _health = Health();
  final StreamController<int> _stepStreamController = StreamController<int>.broadcast();

  Stream<int> get stepStream => _stepStreamController.stream;

  static const List<HealthDataType> _types = [HealthDataType.STEPS];

  static const String _prefBaselineDate = 'ws_pedometer_baseline_date';
  static const String _prefBaselineValue = 'ws_pedometer_baseline_val';
  static const String _prefLastStepsToday = 'ws_pedometer_last_steps_today';

  int? _cumulativeHardwareSteps;
  int? _dailyBaseline;
  String? _dailyBaselineDate;
  int _currentTodaySteps = 0;

  StreamSubscription<StepCount>? _pedometerSubscription;
  Completer<int>? _firstReadingCompleter;

  HealthService() {
    _init();
  }

  Future<void> _init() async {
    await _loadStoredBaseline();
    _startPedometerStream();
  }

  Future<void> _loadStoredBaseline() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayString();
      final storedDate = prefs.getString(_prefBaselineDate);
      final storedVal = prefs.getInt(_prefBaselineValue);
      final lastSteps = prefs.getInt(_prefLastStepsToday) ?? 0;

      if (storedDate == today && storedVal != null) {
        _dailyBaselineDate = storedDate;
        _dailyBaseline = storedVal;
        _currentTodaySteps = lastSteps;
      } else {
        // New day or first run: baseline will be set on the next hardware event
        _dailyBaselineDate = today;
        _dailyBaseline = null;
        _currentTodaySteps = 0;
      }
    } catch (e) {
      debugPrint('Error loading baseline: $e');
    }
  }

  void _startPedometerStream() {
    if (kIsWeb) return;
    try {
      _firstReadingCompleter = Completer<int>();
      _pedometerSubscription = Pedometer.stepCountStream.listen(
        _onPedometerEvent,
        onError: (error) {
          debugPrint('Pedometer sensor error: $error');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Failed to initialize pedometer stream: $e');
    }
  }

  Future<void> _onPedometerEvent(StepCount event) async {
    final hardwareCount = event.steps;
    _cumulativeHardwareSteps = hardwareCount;

    if (_firstReadingCompleter != null && !_firstReadingCompleter!.isCompleted) {
      _firstReadingCompleter!.complete(hardwareCount);
    }

    final today = _todayString();
    final prefs = await SharedPreferences.getInstance();

    // 1. Day Rollover or Fresh Baseline
    if (_dailyBaselineDate != today || _dailyBaseline == null) {
      _dailyBaselineDate = today;
      _dailyBaseline = hardwareCount;
      _currentTodaySteps = 0;

      await prefs.setString(_prefBaselineDate, today);
      await prefs.setInt(_prefBaselineValue, hardwareCount);
      await prefs.setInt(_prefLastStepsToday, 0);
    }
    // 2. Device Reboot Detection (Hardware count dropped below baseline)
    else if (hardwareCount < _dailyBaseline!) {
      // The device was restarted mid-day. Reset baseline to current hardwareCount
      // but retain existing steps walked today.
      final carriedOver = _currentTodaySteps;
      _dailyBaseline = hardwareCount - carriedOver;
      if (_dailyBaseline! < 0) _dailyBaseline = 0;

      await prefs.setInt(_prefBaselineValue, _dailyBaseline!);
    }
    // 3. Normal Monotonic Step Counting
    else {
      final computed = hardwareCount - _dailyBaseline!;
      if (computed >= _currentTodaySteps) {
        _currentTodaySteps = computed;
        await prefs.setInt(_prefLastStepsToday, _currentTodaySteps);
      }
    }

    _stepStreamController.add(_currentTodaySteps);
  }

  /// Request runtime permissions for step tracking.
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    // 1. Runtime Activity Recognition permission (Android 10+)
    try {
      final status = await Permission.activityRecognition.request();
      if (!status.isGranted) {
        debugPrint('Activity recognition permission not granted: $status');
      }
    } catch (e) {
      debugPrint('Activity recognition permission error: $e');
    }

    // 2. Health Connect / Apple HealthKit authorization
    try {
      final hasPermission = await _health.hasPermissions(_types);
      if (hasPermission == true) return true;
      return await _health.requestAuthorization(_types);
    } catch (e) {
      debugPrint('Health authorization error: $e');
      return await Permission.activityRecognition.isGranted;
    }
  }

  /// Fetch total step count for today (local midnight 00:00:00 to now).
  ///
  /// Priority:
  /// 1. HealthKit / Health Connect (aggregated by OS)
  /// 2. Calibrated hardware pedometer
  /// 3. Last saved step count in SharedPreferences
  Future<int> fetchTodaySteps() async {
    if (kIsWeb) return 0;

    // 1. Try HealthKit / Health Connect first
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final healthSteps = await _health.getTotalStepsInInterval(midnight, now);

      if (healthSteps != null && healthSteps > 0) {
        _currentTodaySteps = healthSteps;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_prefLastStepsToday, healthSteps);
        return healthSteps;
      }
    } catch (e) {
      debugPrint('Health query failed, falling back to pedometer: $e');
    }

    // 2. If hardware pedometer hasn't emitted an event yet, wait up to 800ms
    if (_cumulativeHardwareSteps == null && _firstReadingCompleter != null) {
      try {
        await _firstReadingCompleter!.future.timeout(const Duration(milliseconds: 800));
      } catch (_) {}
    }

    // 3. Return current calibrated pedometer count
    if (_currentTodaySteps > 0) {
      return _currentTodaySteps;
    }

    // 4. Return last known steps for today from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();
    if (prefs.getString(_prefBaselineDate) == today) {
      return prefs.getInt(_prefLastStepsToday) ?? 0;
    }

    return 0;
  }

  String _todayString() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  void dispose() {
    _pedometerSubscription?.cancel();
    _stepStreamController.close();
  }
}
