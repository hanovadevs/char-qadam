import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qadam/data/api/api_client.dart';
import 'package:qadam/data/auth/device_identity.dart';
import 'package:qadam/data/auth/token_storage.dart';

class IdentityAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'detail': 'Please sign in again.'}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('stepsy/device_identity');
  final key = 'a' * 64;
  var calls = 0;
  setUp(() {
    calls = 0;
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'fingerprint');
          calls++;
          return key;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'native identity is cached once and survives logout for background sync',
    () async {
      final identity = DeviceIdentity();
      expect(await Future.wait([identity.getKey(), identity.getKey()]), [
        key,
        key,
      ]);
      expect(calls, 1);
      final storage = TokenStorage();
      await storage.saveToken('session-token');
      await storage.clearAll();
      expect(await DeviceIdentity.getBackgroundKey(), key);
      expect(await storage.getToken(), isNull);
    },
  );

  test(
    'a fresh process checks the native identity instead of trusting restored storage',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        DeviceIdentity.storageKey: 'b' * 64,
      });
      expect(await DeviceIdentity().getKey(), key);
      expect(await DeviceIdentity.getBackgroundKey(), key);
      expect(calls, 1);
    },
  );

  test(
    'identity failure retries without generating a replacement identity',
    () async {
      var attempt = 0;
      final identity = DeviceIdentity(
        loader: () async {
          if (attempt++ == 0) throw PlatformException(code: 'UNAVAILABLE');
          return key;
        },
      );
      await expectLater(identity.getKey(), throwsA(isA<PlatformException>()));
      expect(await identity.getKey(), key);
      expect(attempt, 2);
    },
  );

  test(
    'all requests use the same identity including login and step sync',
    () async {
      final storage = TokenStorage();
      final api = ApiClient(tokenStorage: storage);
      final adapter = IdentityAdapter();
      api.dio.httpClientAdapter = adapter;
      for (final path in [
        '/auth/login',
        '/auth/register',
        '/auth/google',
        '/auth/verify-email',
        '/activity/sync',
      ]) {
        await api.post(path, data: {});
      }
      expect(
        adapter.requests.every((r) => r.headers['X-Device-ID'] == key),
        isTrue,
      );
      expect(calls, 1);
      api.dio.close();
    },
  );

  test('invalid device identity blocks network access', () async {
    final api = ApiClient(
      tokenStorage: TokenStorage(),
      deviceIdentity: DeviceIdentity(loader: () async => 'invalid'),
    );
    final adapter = IdentityAdapter();
    api.dio.httpClientAdapter = adapter;
    await expectLater(api.post('/auth/login'), throwsA(isA<DioException>()));
    expect(adapter.requests, isEmpty);
    api.dio.close();
  });

  test(
    'upgrade-required response clears the matching legacy session',
    () async {
      final storage = TokenStorage();
      await storage.saveToken('legacy-session');
      final api = ApiClient(tokenStorage: storage);
      api.dio.httpClientAdapter = IdentityAdapter()..status = 426;
      var loggedOut = false;
      api.onUnauthorized = () => loggedOut = true;
      await expectLater(api.get('/auth/me'), throwsA(isA<DioException>()));
      expect(await storage.getToken(), isNull);
      expect(loggedOut, isTrue);
      api.dio.close();
    },
  );
}
