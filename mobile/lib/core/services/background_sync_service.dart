import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../config/env_config.dart';

/// Periodic background sync manager running on periodic timer and app lifecycle.
class BackgroundSyncService {
  static Timer? _syncTimer;

  static Future<void> initialize() async {
    _syncTimer?.cancel();
    // Schedule periodic step sync every 15 minutes when app is active
    _syncTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      performSync();
    });
  }

  static Future<void> performSync() async {
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'auth_jwt_token');
      if (token == null || token.isEmpty) {
        return;
      }

      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final syncKey = const Uuid().v4();

      final prefs = await SharedPreferences.getInstance();
      final storedDate = prefs.getString('ws_pedometer_baseline_date');
      final stepsToday = (storedDate == todayStr)
          ? (prefs.getInt('ws_pedometer_last_steps_today') ?? 0)
          : 0;

      if (stepsToday <= 0) {
        return;
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

      await dio.post(
        '/activity/sync',
        data: {
          'local_date': todayStr,
          'eligible_steps': stepsToday,
          'source': 'background_workmanager',
          'sync_key': syncKey,
        },
      );
    } catch (e) {
      debugPrint('Background periodic sync error: $e');
    }
  }

  static void dispose() {
    _syncTimer?.cancel();
  }
}
