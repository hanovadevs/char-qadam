import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qadam/data/api/api_client.dart';
import 'package:qadam/data/auth/device_identity.dart';
import 'package:qadam/data/auth/auth_repository.dart';
import 'package:qadam/data/auth/auth_state_provider.dart';
import 'package:qadam/data/auth/email_verification.dart';
import 'package:qadam/data/auth/google_auth_service.dart';
import 'package:qadam/data/auth/token_storage.dart';
import 'package:qadam/features/auth/presentation/verify_email_screen.dart';

class VerificationAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  bool rejectCode = true;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    Map<String, dynamic> body;
    var status = 200;
    if (options.path == '/auth/me') {
      body = {
        'id': 'verified-user',
        'email': 'runner@example.com',
        'status': 'ACTIVE',
        'email_verified': true,
        'created_at': '2026-10-17T00:00:00Z',
      };
    } else if (options.path == '/auth/verify-email') {
      status = rejectCode ? 400 : 200;
      body = rejectCode
          ? {'detail': 'Incorrect verification code.'}
          : {'access_token': 'verified-access-token'};
    } else {
      body = {
        'verification_required': true,
        'verification_token': options.path == '/auth/resend-verification'
            ? 'renewed-purpose-limited-ticket'
            : 'purpose-limited-ticket',
        'email': 'runner@example.com',
        'resend_after_seconds': 0,
      };
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class VerificationUiNotifier extends AuthNotifier {
  int resends = 0;
  String? submittedCode;
  VerificationUiNotifier(TokenStorage storage, ApiClient api)
    : super(
        tokenStorage: storage,
        apiClient: api,
        authRepository: AuthRepository(apiClient: api),
      );
  @override
  Future<void> checkAuthStatus() async {
    state = const AuthState(
      status: AuthStatus.verificationRequired,
      verification: EmailVerificationRequired(
        token: 'ticket',
        email: 'runner@example.com',
        resendAfterSeconds: 0,
      ),
    );
  }

  @override
  Future<bool> resendVerification() async {
    resends++;
    return true;
  }

  @override
  Future<bool> verifyEmail(String code) async {
    submittedCode = code;
    state = state.copyWith(errorMessage: 'Incorrect verification code.');
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TokenStorage storage;
  late ApiClient api;
  late VerificationAdapter adapter;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    storage = TokenStorage();
    api = ApiClient(
      tokenStorage: storage,
      deviceIdentity: DeviceIdentity(loader: () async => 'a' * 64),
    );
    adapter = VerificationAdapter();
    api.dio.httpClientAdapter = adapter;
  });

  test(
    'email and Google challenge responses cannot become stored access tokens',
    () async {
      final repository = AuthRepository(apiClient: api);
      for (final action in [
        () => repository.register(
          email: 'runner@example.com',
          password: 'password123',
        ),
        () => repository.login(
          email: 'runner@example.com',
          password: 'password123',
        ),
        () => repository.loginWithGoogle(idToken: 'google-id-token'),
      ]) {
        await expectLater(action(), throwsA(isA<EmailVerificationRequired>()));
        expect(await storage.getToken(), isNull);
      }
    },
  );

  test(
    'verification state resends, rejects wrong codes and stores only verified credentials',
    () async {
      final notifier = AuthNotifier(
        tokenStorage: storage,
        apiClient: api,
        authRepository: AuthRepository(apiClient: api),
      );
      addTearDown(notifier.dispose);
      await notifier.checkAuthStatus();
      expect(
        await notifier.register(
          email: 'runner@example.com',
          password: 'password123',
        ),
        isTrue,
      );
      expect(notifier.state.status, AuthStatus.verificationRequired);
      expect(await storage.getToken(), isNull);
      expect(await notifier.resendVerification(), isTrue);
      expect(
        notifier.state.verification!.token,
        'renewed-purpose-limited-ticket',
      );
      expect(await notifier.verifyEmail('123456'), isFalse);
      expect(notifier.state.errorMessage, 'Incorrect verification code.');
      expect(await storage.getToken(), isNull);
      adapter.rejectCode = false;
      expect(await notifier.verifyEmail('123456'), isTrue);
      expect(notifier.state.status, AuthStatus.authenticated);
      expect(await storage.getToken(), 'verified-access-token');
      final attempts = adapter.requests.where(
        (r) => r.path == '/auth/verify-email',
      );
      expect(attempts.length, 2);
      expect(
        attempts.first.data['verification_token'],
        'renewed-purpose-limited-ticket',
      );
      expect(attempts.first.headers['Authorization'], isNull);
    },
  );

  testWidgets('verification screen submits entered code and resends on tap', (
    tester,
  ) async {
    final notifier = VerificationUiNotifier(storage, api);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authStateProvider.overrideWith((ref) => notifier)],
        child: const MaterialApp(home: VerifyEmailScreen()),
      ),
    );
    expect(find.textContaining('runner@example.com'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    await tester.tap(find.text('Resend code'));
    await tester.pumpAndSettle();
    expect(notifier.resends, 1);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.tap(find.text('Verify and continue'));
    await tester.pumpAndSettle();
    expect(notifier.submittedCode, '123456');
    expect(find.text('Incorrect verification code.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'pending verification does not restore an authenticated session after restart',
    () async {
      final repository = AuthRepository(apiClient: api);
      final first = AuthNotifier(
        tokenStorage: storage,
        apiClient: api,
        authRepository: repository,
      );
      await first.checkAuthStatus();
      await first.login(email: 'runner@example.com', password: 'password123');
      expect(first.state.status, AuthStatus.verificationRequired);
      first.dispose();
      final restarted = AuthNotifier(
        tokenStorage: storage,
        apiClient: api,
        authRepository: repository,
      );
      await restarted.checkAuthStatus();
      expect(restarted.state.status, AuthStatus.unauthenticated);
      expect(await storage.getToken(), isNull);
      restarted.dispose();
    },
  );

  test(
    'Google developer configuration errors have useful user-facing text',
    () {
      final message = googleSignInError(
        PlatformException(
          code: 'sign_in_failed',
          message: 'com.google.android.gms.common.api.ApiException: 10:',
        ),
      );
      expect(message, contains('configuration update'));
      expect(message, isNot(contains('PlatformException')));
    },
  );
}
