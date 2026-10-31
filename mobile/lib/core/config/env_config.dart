import 'package:flutter/foundation.dart';


/// Environment configuration for the Stepsy mobile app.
///
/// Base URL & Google Client ID can be overridden at build/run time via:
///   `flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000`
class EnvConfig {
  static const supportEmail = String.fromEnvironment('SUPPORT_EMAIL');
  static const publisherName = String.fromEnvironment('PUBLISHER_NAME');
  static const privacyPolicyUrl = String.fromEnvironment('PRIVACY_POLICY_URL');
  static const accountDeletionUrl = String.fromEnvironment('ACCOUNT_DELETION_URL');

  static void validateReleaseConfiguration() {
    if (!kReleaseMode) return;
    for (final url in [_envBaseUrl, privacyPolicyUrl, accountDeletionUrl]) {
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        throw StateError('Release requires HTTPS API, privacy policy and account deletion URLs');
      }
    }
    if (publisherName.trim().isEmpty || !supportEmail.contains('@')) {
      throw StateError('Release requires PUBLISHER_NAME and SUPPORT_EMAIL');
    }
  }

  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _envGoogleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');

  /// Production API served through Stepsy's verified HTTPS domain.
  static const String productionBaseUrl = 'https://api.stepsyapp.com';

  static String get baseUrl {
    if (kReleaseMode) {
      final uri = Uri.tryParse(_envBaseUrl);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        throw StateError('Release builds require --dart-define=API_BASE_URL=https://your-api-domain');
      }
    }
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
    return '98556293307-3mrudhprtrgadopvjjfucclb22hoq6ls.apps.googleusercontent.com';
  }
}
