import 'dart:io';
import 'package:flutter/foundation.dart';

/// Environment configuration for the Qadam mobile app.
///
/// Base URL can be overridden at build/run time via:
///   `flutter run --dart-define=API_BASE_URL=http://your-ip:8000`
class EnvConfig {
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl;
    }
    // Default fallback based on platform
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    if (Platform.isAndroid) {
      // 10.0.2.2 points to host localhost from Android emulator
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }
}
