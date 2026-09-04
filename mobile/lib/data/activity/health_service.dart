import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/notification_service.dart';

final healthServiceProvider = Provider<HealthService>((ref) {
  final service = HealthService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// High-accuracy 24/7 step counter service.
///
/// Multi-layer Architecture:
/// 1. Google Health Connect (Android) / Apple HealthKit (iOS)
///    - OS-level 24/7 background step aggregation.
/// 2. Hardware Pedometer (`Sensor.TYPE_STEP_COUNTER` + `TYPE_STEP_DETECTOR`)
///    - Continuous background stream with ongoing notification.
/// 3. Persistent daily baseline calibrated against device reboots & midnight rollovers.
///    - Accurately tracks steps taken while app is closed/killed.
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
  int _lastNotifiedSteps = 0;
  String _pedestrianStatus = 'unknown';
  String get pedestrianStatus => _pedestrianStatus;

  // Only refresh the ongoing notification once the step count has moved this
  // many steps. The pedometer stream fires on nearly every step, and updating
  // the notification (and its logging) on each event is the main source of
  // visible "refresh spam".
  static const int _notificationStepThreshold = 25;

  StreamSubscription<StepCount>? _pedometerSubscription;
  StreamSubscription<PedestrianStatus>? _statusSubscription;
  Completer<int>? _firstReadingCompleter;

  HealthService() {
    _init();
  }

  Future<void> _init() async {
    // The health plugin must be configured before any Health Connect / HealthKit
    // call, otherwise reads silently fail.
    try {
      await _health.configure();
    } catch (e) {
      debugPrint('Health configure error: $e');
    }
    await _loadStoredBaseline();
    _startPedometerStreams();
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
        _dailyBaselineDate = today;
        _dailyBaseline = null;
        _currentTodaySteps = 0;
      }
    } catch (e) {
      debugPrint('Error loading baseline: $e');
    }
  }

  void _startPedometerStreams() {
    if (kIsWeb) return;
    try {
      _firstReadingCompleter = Completer<int>();

      // 1. Step count hardware stream
      _pedometerSubscription = Pedometer.stepCountStream.listen(
        _onPedometerEvent,
        onError: (error) {
          debugPrint('Pedometer step count stream error: $error');
        },
        cancelOnError: false,
      );

      // 2. Pedestrian status stream (keeps motion coprocessor sensor active)
      _statusSubscription = Pedometer.pedestrianStatusStream.listen(
        (PedestrianStatus event) {
          _pedestrianStatus = event.status;
        },
        onError: (error) {
          debugPrint('Pedestrian status stream error: $error');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Failed to initialize pedometer streams: $e');
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

    final storedDate = prefs.getString(_prefBaselineDate);
    final storedVal = prefs.getInt(_prefBaselineValue);

    // 1. If we already have a baseline saved on disk for today, use it (do not overwrite!)
    if (storedDate == today && storedVal != null) {
      _dailyBaselineDate = storedDate;
      _dailyBaseline = storedVal;
    }
    // 2. Fresh baseline on day rollover or very first run
    else if (_dailyBaselineDate != today || _dailyBaseline == null) {
      _dailyBaselineDate = today;
      _dailyBaseline = hardwareCount;
      _currentTodaySteps = 0;

      await prefs.setString(_prefBaselineDate, today);
      await prefs.setInt(_prefBaselineValue, hardwareCount);
      await prefs.setInt(_prefLastStepsToday, 0);
    }

    // 3. Device Reboot Detection (Hardware count dropped below baseline)
    if (_dailyBaseline != null && hardwareCount < _dailyBaseline!) {
      final carriedOver = _currentTodaySteps;
      _dailyBaseline = hardwareCount - carriedOver;
      if (_dailyBaseline! < 0) _dailyBaseline = 0;

      await prefs.setInt(_prefBaselineValue, _dailyBaseline!);
    }
    // 4. Normal Step Accumulation (Tracks all steps taken even while app was closed)
    else if (_dailyBaseline != null) {
      final computed = hardwareCount - _dailyBaseline!;
      if (computed >= _currentTodaySteps) {
        _currentTodaySteps = computed;
        await prefs.setInt(_prefLastStepsToday, _currentTodaySteps);
      }
    }

    _stepStreamController.add(_currentTodaySteps);

    // Update ongoing persistent notification for 24/7 background tracking,
    // throttled so we don't churn the notification on every sensor tick.
    if ((_currentTodaySteps - _lastNotifiedSteps).abs() >= _notificationStepThreshold) {
      _lastNotifiedSteps = _currentTodaySteps;
      NotificationService.updateOngoingStepNotification(
        stepsToday: _currentTodaySteps,
        dailyGoal: 20000,
      );
    }
  }

  /// Request all permissions needed for continuous 24/7 background tracking:
  /// - Activity Recognition (Motion sensor)
  /// - Body Sensors
  /// - Notifications (POST_NOTIFICATIONS for foreground tracking)
  /// - Ignore Battery Optimizations (Prevents OEM aggressive killing)
  /// - Health Connect (OS-level background step ledger)
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    // 1. Activity Recognition — this is the permission that powers the live
    // hardware pedometer, which is the app's primary step source. If it is
    // granted we can track steps regardless of Health Connect availability.
    bool activityGranted = false;
    try {
      final status = await Permission.activityRecognition.request();
      activityGranted = status.isGranted;
    } catch (e) {
      debugPrint('Activity recognition error: $e');
    }

    // 2. Body Sensors
    try {
      await Permission.sensors.request();
    } catch (e) {
      debugPrint('Sensors permission error: $e');
    }

    // 3. Notifications (for 24/7 ongoing service and rewards)
    try {
      await Permission.notification.request();
    } catch (e) {
      debugPrint('Notification permission error: $e');
    }

    // 4. Request Battery Optimization Exemption
    try {
      final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
      if (!batteryStatus.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    } catch (e) {
      debugPrint('Battery optimization request error: $e');
    }

    // 5. Health Connect / Apple HealthKit (best-effort — enriches step data but
    // is NOT required to enter the app; the hardware pedometer suffices).
    bool healthGranted = false;
    try {
      final hasPermission = await _health.hasPermissions(_types);
      healthGranted = hasPermission == true
          ? true
          : await _health.requestAuthorization(_types);
    } catch (e) {
      debugPrint('Health authorization error: $e');
    }

    // Consider tracking enabled if EITHER source is available. Gating solely on
    // Health Connect leaves users stuck on onboarding when it is denied or not
    // installed, even though the pedometer can already count their steps.
    return activityGranted || healthGranted;
  }

  /// Fetch total step count for today (local midnight 00:00:00 to now).
  Future<int> fetchTodaySteps() async {
    if (kIsWeb) return 0;

    // 1. Check Google Health Connect / Apple HealthKit first
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final healthSteps = await _health.getTotalStepsInInterval(midnight, now);

      if (healthSteps != null && healthSteps > 0) {
        _currentTodaySteps = healthSteps;
        _lastNotifiedSteps = healthSteps;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_prefLastStepsToday, healthSteps);

        NotificationService.updateOngoingStepNotification(
          stepsToday: healthSteps,
          dailyGoal: 20000,
        );

        return healthSteps;
      }
    } catch (e) {
      debugPrint('Health Connect query failed: $e');
    }

    // 2. Wait up to 800ms for hardware pedometer stream event
    if (_cumulativeHardwareSteps == null && _firstReadingCompleter != null) {
      try {
        await _firstReadingCompleter!.future.timeout(const Duration(milliseconds: 800));
      } catch (_) {}
    }

    // 3. Return current calibrated pedometer count
    if (_currentTodaySteps > 0) {
      return _currentTodaySteps;
    }

    // 4. Return last known steps for today
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
    _statusSubscription?.cancel();
    _stepStreamController.close();
  }
}

