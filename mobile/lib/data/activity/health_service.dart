import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'daily_step_counter.dart';
import '../auth/auth_state_provider.dart';

final healthServiceProvider = Provider<HealthService>((ref) {
  ref.watch(authStateProvider.select((state) => state.user?.id));
  final service = HealthService();
  ref.onDispose(service.dispose);
  return service;
});

/// Health-store totals and a persisted hardware counter are overlapping sources.
/// Android owns its sensor in a foreground service; iOS uses the motion plugin.
class HealthService {
  static const nativeSnapshotKey = 'stepsy_native_steps_v1';
  static const _channel = MethodChannel('stepsy/step_tracking');
  static const _events = EventChannel('stepsy/step_events');
  static const _types = [HealthDataType.STEPS];
  static const _readAccess = [HealthDataAccess.READ];
  final Health _health = Health();
  final _controller = StreamController<int>.broadcast();
  final _counter = DailyStepCounter();
  late final Future<void> _ready;
  StreamSubscription<dynamic>? _subscription;
  Future<void> _pending = Future.value();
  bool _disposed = false;
  int _currentSteps = 0;
  String _currentDate = '';
  int? _lastHealthSteps;
  DateTime? _lastHealthRead;
  DateTime? _lastHealthCheck;

  Stream<int> get stepStream => _controller.stream;
  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _ios => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  HealthService() {
    _ready = _configure();
  }

  Future<void> _configure() async {
    if (!_android && !_ios) return;
    try {
      await _health.configure();
    } catch (e) {
      debugPrint('Health configuration unavailable: $e');
    }
  }

  Future<bool> requestPermissions() async {
    await _ready;
    if (_disposed || (!_android && !_ios)) return false;
    var motion = false;
    try {
      motion = _android
          ? (await Permission.activityRecognition.request()).isGranted
          : (await Permission.sensors.request()).isGranted;
    } catch (e) {
      debugPrint('Motion permission unavailable: $e');
    }
    var health = false;
    try {
      health =
          await _health.hasPermissions(_types, permissions: _readAccess) ==
              true ||
          await _health.requestAuthorization(_types, permissions: _readAccess);
      if (_android &&
          health &&
          await _health.isHealthDataInBackgroundAvailable() &&
          !await _health.isHealthDataInBackgroundAuthorized()) {
        await _health.requestHealthDataInBackgroundAuthorization();
      }
    } catch (e) {
      debugPrint('Health permission unavailable: $e');
    }
    if (_disposed) return false;
    if (motion) {
      try {
        await Permission.notification.request();
        if (_disposed) return false;
        if (_android) {
          motion = await _channel.invokeMethod<bool>('start') ?? false;
          _subscription ??= _events.receiveBroadcastStream().listen(
            (event) {
              _emit(event as int);
            },
            onError: (Object e) {
              debugPrint('Step sensor unavailable: $e');
            },
          );
        } else {
          await _loadMotionSnapshot();
          if (_disposed) return false;
          _subscription ??= Pedometer.stepCountStream.listen(
            (event) {
              // Serialize persistence so a slow older write cannot replace newer steps.
              _pending = _pending
                  .then((_) async {
                    if (_disposed) return;
                    _counter.record(event.steps, event.timeStamp);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString(
                      'stepsy_motion_steps_v1',
                      jsonEncode(_counter.toJson()),
                    );
                    _emit(_counter.steps);
                  })
                  .catchError((Object e) {
                    debugPrint('Motion persistence failed: $e');
                  });
            },
            onError: (Object e) {
              debugPrint('Motion sensor unavailable: $e');
            },
          );
        }
      } catch (e) {
        motion = false;
        debugPrint('Step tracking could not start: $e');
      }
    }
    return motion || health;
  }

  Future<void> _loadMotionSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('stepsy_motion_steps_v1');
    if (raw != null) {
      try {
        _counter.restore(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  void _emit(int steps) {
    if (_disposed) return;
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (_currentDate != date) {
      _currentDate = date;
      _currentSteps = 0;
    }
    _currentSteps = max(_currentSteps, steps);
    _controller.add(_currentSteps);
  }

  Future<int> fetchTodaySteps() async {
    await _ready;
    if (_disposed || (!_android && !_ios)) return 0;
    final now = DateTime.now();
    final day = DateFormat('yyyy-MM-dd').format(now);
    var hardware = 0;
    int? rawAtRead;
    int? bootAtRead;
    var healthEnd = now;
    if (_android) {
      try {
        final raw = await _channel.invokeMethod<String>('snapshot');
        final data = jsonDecode(raw ?? '{}') as Map<String, dynamic>;
        if (data['date'] == day) {
          hardware = data['steps'] as int? ?? 0;
          final at = data['at'] as int? ?? 0;
          if (data['raw'] != null &&
              at > 0 &&
              at <= now.millisecondsSinceEpoch) {
            healthEnd = DateTime.fromMillisecondsSinceEpoch(at);
            rawAtRead = data['raw'] as int?;
            bootAtRead = data['boot'] as int?;
          }
        }
      } catch (e) {
        debugPrint('Step snapshot unavailable: $e');
      }
    } else if (_counter.date == day) {
      hardware = _counter.steps;
    }
    // Restore the native counter before waiting on optional Health Connect.
    // Never reuse an old health total with a newer hardware baseline.
    _emit(hardware);
    if (_lastHealthCheck != null &&
        _lastHealthCheck!.year == now.year &&
        _lastHealthCheck!.month == now.month &&
        _lastHealthCheck!.day == now.day &&
        now.difference(_lastHealthCheck!) < const Duration(seconds: 30)) {
      return _currentSteps;
    }
    var health = 0;
    try {
      health =
          await _health.getTotalStepsInInterval(
            DateTime(now.year, now.month, now.day),
            healthEnd,
            includeManualEntry: false,
          ) ??
          0;
      _lastHealthSteps = health;
      _lastHealthRead = healthEnd;
      _lastHealthCheck = now;
    } catch (e) {
      debugPrint('Health read unavailable: $e');
    }
    // A result from yesterday must not appear in today's UI or sync payload.
    if (DateFormat('yyyy-MM-dd').format(DateTime.now()) != day) {
      return fetchTodaySteps();
    }
    if (_android) {
      try {
        final raw = await _channel.invokeMethod<String>('mergeHealth', {
          'steps': health,
          'raw': rawAtRead,
          'boot': bootAtRead,
        });
        final data = jsonDecode(raw ?? '{}') as Map<String, dynamic>;
        hardware = data['steps'] as int? ?? hardware;
      } catch (e) {
        debugPrint('Step reconciliation unavailable: $e');
      }
    } else {
      await _pending;
      _counter.mergeHealth(health, now);
      hardware = _counter.steps;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'stepsy_motion_steps_v1',
        jsonEncode(_counter.toJson()),
      );
    }
    _emit(max(hardware, health));
    return _currentSteps;
  }

  static Future<void> stopTracking() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel.invokeMethod<void>('stop');
      } catch (_) {}
    }
  }

  Future<Map<String, String>> diagnostics() async {
    final result = <String, String>{
      'Tracking date': _currentDate,
      'Displayed steps': '$_currentSteps',
      'Health store steps': _lastHealthSteps?.toString() ?? 'Unavailable',
      'Health read through':
          _lastHealthRead?.toLocal().toString() ?? 'Unavailable',
    };
    if (_android) {
      try {
        final raw = await _channel.invokeMethod<String>('snapshot');
        final data = jsonDecode(raw ?? '{}') as Map<String, dynamic>;
        result['Sensor counter since boot'] =
            data['raw']?.toString() ?? 'Waiting for sensor';
        result['Saved daily steps'] = data['steps']?.toString() ?? '0';
        final at = data['at'] as int? ?? 0;
        result['Last sensor reading'] = at == 0
            ? 'Waiting for sensor'
            : DateTime.fromMillisecondsSinceEpoch(at).toString();
        result['Boot count'] = data['boot']?.toString() ?? 'Unavailable';
        result['Tracking service'] = data['service_running'] == true
            ? 'Running'
            : 'Stopped';
        result['Step sensor'] = data['sensor_available'] == true
            ? 'Available'
            : 'Unavailable';
      } catch (_) {
        result['Sensor status'] = 'Unavailable';
      }
    }
    return result;
  }

  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _controller.close();
  }
}
