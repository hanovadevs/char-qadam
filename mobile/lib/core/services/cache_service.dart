import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/auth/token_storage.dart';

final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheService(tokenStorage: ref.watch(tokenStorageProvider));
});

/// Lightweight local JSON response cache for offline mode & instant load.
class CacheService {
  final TokenStorage tokenStorage;
  CacheService({TokenStorage? tokenStorage}) : tokenStorage = tokenStorage ?? TokenStorage();

  Future<String> scopedKey(String key) async {
    final token = await tokenStorage.getToken();
    if (token == null) return 'signed_out_$key';
    try {
      final claims = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1])))) as Map<String, dynamic>;
      final subject = claims['sub'] as String;
      return '${Uri.encodeComponent(subject)}_$key';
    } catch (_) {
      return 'invalid_session_$key';
    }
  }

  static const String _cachePrefix = 'qadam_cache_';
  static const String _timePrefix = 'qadam_cache_ts_';

  static Future<void> clearAllPersonalCaches() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_cachePrefix) || key.startsWith(_timePrefix)).toList();
    for (final key in keys) { await prefs.remove(key); }
  }

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
