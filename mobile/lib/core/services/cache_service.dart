import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheService();
});

/// Lightweight local JSON response cache for offline mode & instant load.
class CacheService {
  static const String _cachePrefix = 'qadam_cache_';
  static const String _timePrefix = 'qadam_cache_ts_';

  Future<void> cacheData(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(data);
      await prefs.setString('$_cachePrefix$key', jsonStr);
      await prefs.setInt('$_timePrefix$key', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<dynamic> getCachedData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('$_cachePrefix$key');
      if (jsonStr == null || jsonStr.isEmpty) return null;
      return jsonDecode(jsonStr);
    } catch (_) {
      return null;
    }
  }

  Future<DateTime?> getCacheTimestamp(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt('$_timePrefix$key');
      if (ms == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_cachePrefix$key');
      await prefs.remove('$_timePrefix$key');
    } catch (_) {}
  }
}
