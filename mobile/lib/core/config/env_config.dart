
/// Environment configuration for the Stepsy mobile app.
///
/// Base URL & Google Client ID can be overridden at build/run time via:
///   `flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000`
class EnvConfig {
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _envGoogleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');

  /// Production API served through Stepsy's verified HTTPS domain.
  static const String productionBaseUrl = 'https://api.stepsyapp.com';

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl;
    }
    // Default to the live VPS backend URL
    return productionBaseUrl;
  }

  static String get googleClientId {
    if (_envGoogleClientId.isNotEmpty) {
      return _envGoogleClientId;
    }
    return '762647497862-fskb3lmbg5hkuqee4cb0hmjv7goelf92.apps.googleusercontent.com';
  }
}
