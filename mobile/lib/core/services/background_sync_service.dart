import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:workmanager/workmanager.dart';
import '../config/env_config.dart';

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

/// Guaranteed periodic background step sync via Android WorkManager.
///
/// Industry-standard pattern: the OS wakes a short-lived background isolate on
/// a schedule (Android floor is ~15 min), we read the day's step total from the
/// OS health store (Health Connect), and POST it to `/activity/sync`. This runs
/// even when the app process has been killed, so points keep accruing without
/// the user opening the app.
class BackgroundSyncService {
  /// Register the WorkManager engine + periodic task. Call once from `main()`.
  static Future<void> initialize() async {
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
          },
        ),
      );

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
    } on DioException catch (e) {
      // 401 = expired token: nothing we can refresh here, don't hammer retries.
      if (e.response?.statusCode == 401) return true;
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
    // Health Connect / HealthKit — the reliable background source.
    try {
      final health = Health();
      await health.configure();
      final midnight = DateTime(now.year, now.month, now.day);
      final hcSteps = await health.getTotalStepsInInterval(midnight, now);
      if (hcSteps != null && hcSteps > 0) {
        return hcSteps;
      }
    } catch (e) {
      debugPrint('Background Health Connect read failed: $e');
    }

    // Fallback: last value the foreground pedometer stored for today.
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_kPrefBaselineDate) == todayStr) {
        return prefs.getInt(_kPrefLastStepsToday) ?? 0;
      }
    } catch (e) {
      debugPrint('Background prefs read failed: $e');
    }

    return 0;
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
