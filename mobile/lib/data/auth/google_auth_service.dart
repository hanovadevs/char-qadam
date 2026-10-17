import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/config/env_config.dart';

String googleSignInError(PlatformException error) {
  final message = error.message ?? '';
  if (error.code == 'sign_in_failed' &&
      RegExp(
        r'(ApiException:\s*10\b|Api10\b|DEVELOPER_ERROR)',
      ).hasMatch(message)) {
    return 'Google sign-in needs an app configuration update. Please use email sign-in for now.';
  }
  if (error.code == 'network_error' || message.contains('NETWORK_ERROR')) {
    return 'Could not connect to Google. Check your connection and try again.';
  }
  return 'Google sign-in could not finish. Please try again.';
}

class GoogleAuthService {
  static final _client = GoogleSignIn(
    serverClientId: EnvConfig.googleClientId,
    scopes: const ['email', 'profile'],
  );

  static Future<({String token, String? name, String? photo})?> signIn() async {
    try {
      final account = await _client.signIn();
      if (account == null) return null;
      final authentication = await account.authentication;
      final token = authentication.idToken;
      if (token == null || token.isEmpty) {
        throw Exception(
          'Google did not return a sign-in token. Please try again.',
        );
      }
      return (token: token, name: account.displayName, photo: account.photoUrl);
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_canceled') return null;
      throw Exception(googleSignInError(e));
    }
  }
}
