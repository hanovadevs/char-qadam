import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:workmanager/workmanager.dart';
import '../config/env_config.dart';

const String backgroundStepSyncTask = 'qadam_bg_step_sync_task';
const String backgroundStepSyncUniqueName = 'qadam_bg_step_sync';

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

        // In a headless background worker, read today's hardware baseline steps
        final baselineDate = await storage.read(key: 'pedometer_baseline_date');
        final baselineValueStr = await storage.read(key: 'pedometer_baseline_value');
        int? baseline = int.tryParse(baselineValueStr ?? '');

        // If no baseline exists for today, skip sync until foreground initializes
        if (baselineDate != todayStr || baseline == null) {
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

        // Best effort background sync with server
        await dio.post(
          '/activity/sync',
          data: {
            'local_date': todayStr,
            'eligible_steps': 0, // Server preserves max steps if higher
            'source': 'background_workmanager',
            'sync_key': syncKey,
          },
        );

        return true;
      } catch (e) {
        debugPrint('Background sync task error: $e');
        return true; // Don't crash worker on network timeout
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
