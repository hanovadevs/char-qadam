import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

/// Storage wrapper around [FlutterSecureStorage] for managing JWT tokens and cached user data.
class TokenStorage {
  static const String _tokenKey = 'qadam_access_token';
  static const String _userKey = 'qadam_cached_user';
  final FlutterSecureStorage _storage;
  String? _token;
  bool _tokenLoaded = false;
  int _tokenVersion = 0;
  Future<String?>? _tokenRead;

  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
    _tokenVersion++;
    _token = token;
    _tokenLoaded = true;
    _tokenRead = null;
  }

  Future<String?> getToken() async {
    if (_tokenLoaded) return _token;
    final version = _tokenVersion;
    final read = _tokenRead ??= _storage.read(key: _tokenKey);
    try {
      final token = await read;
      if (version != _tokenVersion) return _token;
      _token = token;
      _tokenLoaded = true;
      return token;
    } finally {
      if (identical(_tokenRead, read)) _tokenRead = null;
    }
  }

  void _clearMemoryToken() {
    _tokenVersion++;
    _token = null;
    _tokenLoaded = true;
    _tokenRead = null;
  }

  Future<void> deleteToken() async {
    _clearMemoryToken();
    await _storage.delete(key: _tokenKey);
  }

  Future<void> saveUser(UserModel user) async {
    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
  }

  Future<UserModel?> getUser() async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteUser() async {
    await _storage.delete(key: _userKey);
  }

  /// Clears both access token and cached user profile in secure storage.
  Future<void> clearAll() async {
    _clearMemoryToken();
    await Future.wait([
      _storage.delete(key: _tokenKey),
      _storage.delete(key: _userKey),
    ]);
  }
}
