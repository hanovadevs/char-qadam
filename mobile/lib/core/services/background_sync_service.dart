import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:workmanager/workmanager.dart';
import '../config/env_config.dart';

const String backgroundStepSyncTask = 'walk_n_save_bg_step_sync_task';
const String backgroundStepSyncUniqueName = 'walk_n_save_bg_step_sync';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == backgroundStepSyncTask || task == backgroundStepSyncUniqueName) {
      try {
        const storage = FlutterSecureStorage();
        final token = await storage.read(key: 'auth_jwt_token');
        if (token == null || token.isEmpty) {
          return true;
        }

        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final syncKey = const Uuid().v4();

        final prefs = await SharedPreferences.getInstance();
        final storedDate = prefs.getString('ws_pedometer_baseline_date');
        final stepsToday = (storedDate == todayStr)
            ? (prefs.getInt('ws_pedometer_last_steps_today') ?? 0)
            : 0;

        if (stepsToday <= 0) {
          return true;
        }

        final dio = Dio(
          BaseOptions(
            baseUrl: EnvConfig.baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          ),
        );

        // Sync validated steps to server
        await dio.post(
          '/activity/sync',
          data: {
            'local_date': todayStr,
            'eligible_steps': stepsToday,
            'source': 'background_workmanager',
            'sync_key': syncKey,
          },
        );

        return true;
      } catch (e) {
        debugPrint('Background sync task error: $e');
        return true;
      }
    }
    return true;
  });
}

class BackgroundSyncService {
  static Future<void> initialize() async {
    if (kIsWeb) return; // Background WorkManager not supported on Web

    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );

      await Workmanager().registerPeriodicTask(
        backgroundStepSyncUniqueName,
        backgroundStepSyncTask,
        frequency: const Duration(hours: 1),
        existingWorkPolicy: ExistingWorkPolicy.keep,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );
    } catch (e) {
      debugPrint('Workmanager initialization error: $e');
    }
  }
}
