import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:workmanager/workmanager.dart';
import '../config/env_config.dart';
import '../../data/auth/device_identity.dart';

/// Unique identifiers for the WorkManager job.
const String _kPeriodicSyncTask = 'com.stepsy.run.periodicStepSync';
const String _kPeriodicSyncName = 'stepsy-periodic-step-sync';

// Keys must match the ones used elsewhere in the app:
//  - token: TokenStorage._tokenKey ('qadam_access_token')
//  - step prefs: HealthService (_prefBaselineDate / _prefLastStepsToday)
const String _kTokenKey = 'qadam_access_token';
const String _kPrefBaselineDate = 'ws_pedometer_baseline_date';
const String _kPrefLastStepsToday = 'ws_pedometer_last_steps_today';

/// Entry point invoked by the OS in a **background isolate** (even when the app
/// is killed). Must be a top-level or static function annotated with
/// `@pragma('vm:entry-point')` so it survives tree-shaking / AOT.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    // Returning true tells WorkManager the work succeeded; false triggers a
    // retry with backoff. Never throw — an uncaught error is treated as failure.
    try {
      return await BackgroundSyncService.performSync();
    } catch (e) {
      debugPrint('WorkManager task error: $e');
      return false;
    }
  });
}

/// Best-effort periodic background step sync via Android WorkManager.
///
/// Industry-standard pattern: the OS wakes a short-lived background isolate on
/// a schedule (Android floor is ~15 min), we read the day's step total from the
/// OS health store (Health Connect), and POST it to `/activity/sync`. This runs
/// even when the app process has been killed, so points keep accruing without
/// the user opening the app.
class BackgroundSyncService {
  /// Register the WorkManager engine + periodic task. Call once from `main()`.
  static Future<void> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await Workmanager().initialize(callbackDispatcher);

      await Workmanager().registerPeriodicTask(
        _kPeriodicSyncName,
        _kPeriodicSyncTask,
        frequency: const Duration(minutes: 15), // Android minimum interval
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 5),
      );
    } catch (e) {
      debugPrint('WorkManager initialize error: $e');
    }
  }

  /// Read today's step total (Health Connect first, stored pedometer fallback)
  /// and sync it to the backend. Returns true on success / nothing-to-do.
  static Future<bool> performSync() async {
    // 1. Auth — bail quietly if the user isn't logged in.
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: _kTokenKey);
    if (token == null || token.isEmpty) {
      return true; // not logged in; nothing to sync, not a failure
    }
    final deviceKey = await DeviceIdentity.getBackgroundKey();
    if (deviceKey == null) {
      return true; // foreground app must establish identity first
    }

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    // 2. Resolve today's step total.
    final steps = await _resolveTodaySteps(now, todayStr);
    if (steps <= 0) {
      return true; // no steps recorded yet today
    }

    // 3. Sync to backend. Idempotent server-side via sync_key.
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: EnvConfig.baseUrl,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'X-Device-ID': deviceKey,
          },
        ),
      );

      try {
        await dio.post(
          '/activity/sync',
          data: {
            'local_date': todayStr,
            'eligible_steps': steps,
            'source': 'background_workmanager',
            'sync_key': const Uuid().v4(),
          },
        );
        return true;
      } finally {
        dio.close();
      }
    } on DioException catch (e) {
      // 401 = expired token: nothing we can refresh here, don't hammer retries.
      if ([401, 426].contains(e.response?.statusCode)) return true;
      debugPrint('Background sync HTTP error: ${e.message}');
      return false; // transient (network/5xx) → let WorkManager retry
    } catch (e) {
      debugPrint('Background sync error: $e');
      return false;
    }
  }

  /// Prefer the OS health store (updates while the app is closed); fall back to
  /// the last pedometer total the foreground app persisted for today.
  static Future<int> _resolveTodaySteps(DateTime now, String todayStr) async {
    var storedSteps = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      // The foreground service writes outside this isolate's preference cache.
      await prefs.reload();
      final raw = prefs.getString('stepsy_native_steps_v1');
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        if (data['date'] == todayStr) storedSteps = data['steps'] as int? ?? 0;
      } else if (prefs.getString(_kPrefBaselineDate) == todayStr) {
        storedSteps = prefs.getInt(_kPrefLastStepsToday) ?? 0;
      }
    } catch (e) {
      debugPrint('Background snapshot unavailable: $e');
    }
    try {
      final health = Health();
      await health.configure();
      if (await health.isHealthDataInBackgroundAuthorized()) {
        final midnight = DateTime(now.year, now.month, now.day);
        final healthSteps =
            await health.getTotalStepsInInterval(
              midnight,
              now,
              includeManualEntry: false,
            ) ??
            0;
        return max(storedSteps, healthSteps);
      }
    } catch (e) {
      debugPrint('Background health read unavailable: $e');
    }
    return storedSteps;
  }

  /// Cancel the periodic job (e.g. on logout).
  static Future<void> cancel() async {
    try {
      await Workmanager().cancelByUniqueName(_kPeriodicSyncName);
    } catch (e) {
      debugPrint('WorkManager cancel error: $e');
    }
  }
}
