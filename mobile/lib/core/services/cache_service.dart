import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/auth/auth_state_provider.dart';

final cacheServiceProvider = Provider<CacheService>((ref) {
  final userId = ref.watch(authStateProvider.select((state) => state.user?.id));
  return CacheService(userId: userId);
});

/// Lightweight local JSON response cache for offline mode & instant load.
class CacheService {
  final String? userId;
  CacheService({this.userId});
  static const String _cachePrefix = 'qadam_cache_';
  static const String _timePrefix = 'qadam_cache_ts_';

  Future<String> scopedKey(String key) async => key;

  Future<void> cacheData(String key, dynamic data) async {
    if (userId == null) return;
    key = '${userId}_$key';
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(data);
      await prefs.setString('$_cachePrefix$key', jsonStr);
      await prefs.setInt(
        '$_timePrefix$key',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  Future<dynamic> getCachedData(String key) async {
    if (userId == null) return null;
    key = '${userId}_$key';
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
    if (userId == null) return null;
    key = '${userId}_$key';
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
    if (userId == null) return;
    key = '${userId}_$key';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_cachePrefix$key');
      await prefs.remove('$_timePrefix$key');
    } catch (_) {}
  }

  Future<void> clearAccountCache() async {
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where(
          (key) =>
              key.startsWith('$_cachePrefix${userId}_') ||
              key.startsWith('$_timePrefix${userId}_'),
        )
        .toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
