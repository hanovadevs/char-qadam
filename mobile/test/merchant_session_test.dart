import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qadam/data/api/api_client.dart';
import 'package:qadam/data/auth/auth_state_provider.dart';
import 'package:qadam/data/auth/device_identity.dart';
import 'package:qadam/data/auth/token_storage.dart';
import 'package:qadam/data/models/user_model.dart';
import 'package:qadam/features/merchant/presentation/merchant_pos_screen.dart';
import 'package:qadam/routing/app_router.dart';

final merchantProfile = <String, dynamic>{
  'id': 'merchant-test',
  'email': 'store@stepsyapp.com',
  'status': 'ACTIVE',
  'role': 'MERCHANT',
  'partner_id': 'partner-test',
  'partner_name': 'Test Store',
  'created_at': '2026-10-30T00:00:00Z',
  'email_verified': false,
};

class MerchantSessionStorage implements TokenStorage {
  String? token;
  UserModel? user;
  int clears = 0;
  @override
  Future<String?> getToken() async => token;
  @override
  Future<UserModel?> getUser() async => user;
  @override
  Future<void> saveToken(String value) async => token = value;
  @override
  Future<void> saveUser(UserModel value) async => user = value;
  @override
  Future<void> clearAll() async {
    clears++;
    token = null;
    user = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MerchantSessionAdapter implements HttpClientAdapter {
  final bool storeLinked;
  MerchantSessionAdapter({this.storeLinked = true});
  Map<String, dynamic> get profile => {
    ...merchantProfile,
    if (!storeLinked) 'partner_id': null,
    if (!storeLinked) 'partner_name': null,
  };
  final requests = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.path);
    if (options.headers['X-Device-ID'] != 'a' * 64) {
      throw StateError('Missing merchant device identity');
    }
    if (!storeLinked && options.path.startsWith('/partner/v1/')) {
      return ResponseBody.fromString(
        jsonEncode({
          'detail':
              'No store is linked to this merchant account. Ask an administrator to link a store in the admin panel.',
        }),
        403,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    Object body;
    switch (options.path) {
      case '/auth/login':
        body = {
          'access_token': 'merchant-session',
          'role': 'MERCHANT',
          'user': profile,
        };
      case '/auth/me':
        body = profile;
      case '/partner/v1/info':
        body = {
          'partner_id': 'partner-test',
          'name': 'Test Store',
          'status': 'ACTIVE',
        };
      case '/partner/v1/redemptions':
        body = [];
      default:
        throw StateError('Unexpected merchant request: ${options.path}');
    }
    if (options.path != '/auth/login') {
      if (options.headers['Authorization'] != 'Bearer merchant-session') {
        throw StateError('Missing merchant bearer token');
      }
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  testWidgets(
    'a missing store is shown as a recoverable merchant error without signing out',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final adapter = MerchantSessionAdapter(storeLinked: false);
      final storage = MerchantSessionStorage()
        ..token = 'merchant-session'
        ..user = UserModel.fromJson(adapter.profile);
      final api = ApiClient(
        tokenStorage: storage,
        deviceIdentity: DeviceIdentity(loader: () async => 'a' * 64),
      );
      api.dio.httpClientAdapter = adapter;
      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(storage),
          apiClientProvider.overrideWithValue(api),
          onboardingCompleteProvider.overrideWith((ref) async => true),
        ],
      );
      final router = container.read(routerProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MerchantPosScreen), findsOneWidget);
      expect(find.textContaining('No store is linked'), findsOneWidget);
      expect(
        container.read(authStateProvider).status,
        AuthStatus.authenticated,
      );
      expect(storage.clears, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      api.dio.close();
    },
  );
  testWidgets(
    'managed merchant sign-in opens POS and survives profile refresh and restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = MerchantSessionStorage();
      final api = ApiClient(
        tokenStorage: storage,
        deviceIdentity: DeviceIdentity(loader: () async => 'a' * 64),
      );
      final adapter = MerchantSessionAdapter();
      api.dio.httpClientAdapter = adapter;
      final requestErrors = <Object?>[];
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onError: (error, handler) {
            requestErrors.add(error.error);
            handler.next(error);
          },
        ),
      );
      ProviderContainer createContainer() => ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(storage),
          apiClientProvider.overrideWithValue(api),
          onboardingCompleteProvider.overrideWith((ref) async => true),
        ],
      );
      var container = createContainer();
      var router = container.read(routerProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        container.read(authStateProvider).status,
        AuthStatus.unauthenticated,
      );
      final login = container
          .read(authStateProvider.notifier)
          .login(email: 'store@stepsyapp.com', password: 'test-password');
      await tester.pumpAndSettle();
      expect(
        await login,
        isTrue,
        reason:
            '${container.read(authStateProvider).errorMessage}: $requestErrors',
      );
      await tester.pumpAndSettle();
      expect(find.byType(MerchantPosScreen), findsOneWidget);
      expect(
        container.read(authStateProvider).status,
        AuthStatus.authenticated,
      );
      expect(adapter.requests, contains('/partner/v1/redemptions'));
      final refresh = container
          .read(authStateProvider.notifier)
          .refreshProfile();
      await tester.pumpAndSettle();
      await refresh;
      expect(find.byType(MerchantPosScreen), findsOneWidget);
      expect(storage.clears, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();

      container = createContainer();
      router = container.read(routerProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MerchantPosScreen), findsOneWidget);
      expect(
        container.read(authStateProvider).status,
        AuthStatus.authenticated,
      );
      expect(storage.clears, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      api.dio.close();
    },
  );
}
