import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:workmanager/workmanager.dart';
import '../config/env_config.dart';
import 'health_consent.dart';
import 'notification_service.dart';

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
    if (!await HealthConsent.hasConsent()) return true;
    // 1. Auth — bail quietly if the user isn't logged in.
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: _kTokenKey);
    if (token == null || token.isEmpty) {
      return true; // not logged in; nothing to sync, not a failure
    }

    final claims = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1])))) as Map<String, dynamic>;
    await NotificationService.setUser(claims['sub'] as String, clearExisting: false);
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    // 2. Resolve today's step total.
    final steps = await _resolveTodaySteps(now, todayStr);
    await NotificationService.checkProgress(stepsToday: steps);
    await _checkVoucherExpiry(token, claims['sub'] as String, todayStr);
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
  static Future<void> _checkVoucherExpiry(String token, String userId, String today) async {
    final settings = await NotificationService.preferences();
    if (!settings.enabled || !settings.voucherExpiry || NotificationService.isQuietHour(DateTime.now().hour)) return;
    final prefs = await SharedPreferences.getInstance();
    final key = 'expiry_check_${userId}_$today';
    if (prefs.getBool(key) == true) return;
    final dio = Dio(BaseOptions(baseUrl: EnvConfig.baseUrl, connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 15), headers: {'Authorization': 'Bearer $token'}));
    try {
      final response = await dio.get('/vouchers', queryParameters: {'status': 'active'});
      for (final voucher in response.data as List<dynamic>) {
        final expiry = DateTime.parse(voucher['expires_at'] as String).difference(DateTime.now());
        if (expiry.isNegative) continue;
        await NotificationService.showVoucherExpiring(offerTitle: voucher['offer_title'] as String,
          shortCode: voucher['short_code'] as String, daysLeft: expiry.inDays);
      }
      await prefs.setBool(key, true);
    } catch (_) {
      // Optional reminders must never make step syncing fail.
    } finally { dio.close(); }
  }

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
