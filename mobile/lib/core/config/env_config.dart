import 'package:flutter/foundation.dart';

/// Environment configuration for the Stepsy mobile app.
///
/// Base URL & Google Client ID can be overridden at build/run time via:
///   `flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000`
class EnvConfig {
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _envGoogleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');

  /// Production live API URL on Render
  static const String productionBaseUrl = 'https://char-qadam.onrender.com';

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl;
    }
    // In local development/debug mode, connect to the local FastAPI backend
    if (kDebugMode) {
      if (kIsWeb) {
        return 'http://127.0.0.1:8000';
      }
      // Android emulator uses 10.0.2.2 to access host machine localhost
      if (defaultTargetPlatform == TargetPlatform.android) {
        return 'http://10.0.2.2:8000';
      }
      return 'http://127.0.0.1:8000';
    }
    // Default to live production URL for release builds
    return productionBaseUrl;
  }

  static String get googleClientId {
    if (_envGoogleClientId.isNotEmpty) {
      return _envGoogleClientId;
    }
    return '762647497862-fskb3lmbg5hkuqee4cb0hmjv7goelf92.apps.googleusercontent.com';
  }
}
