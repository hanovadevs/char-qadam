import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qadam/data/api/api_client.dart';
import 'package:qadam/data/auth/auth_state_provider.dart';
import 'package:qadam/data/auth/token_storage.dart';
import 'package:qadam/routing/app_router.dart';

class MemoryTokenStorage implements TokenStorage {
  String? token = 'old-session';
  int clears = 0;
  @override
  Future<String?> getToken() async => token;
  @override
  Future<void> clearAll() async {
    clears++;
    token = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DeferredAdapter implements HttpClientAdapter {
  final started = Completer<void>();
  final response = Completer<ResponseBody>();
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    started.complete();
    return response.future;
  }

  @override
  void close({bool force = false}) {}
}

class TestAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  TestAuthNotifier() : super(const AuthState(status: AuthStatus.authenticated));
  void updateProfile() {
    state = state.copyWith(isLoading: true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'a delayed 401 from an old session cannot log out the new session',
    () async {
      final storage = MemoryTokenStorage();
      final client = ApiClient(tokenStorage: storage);
      final adapter = DeferredAdapter();
      client.dio.httpClientAdapter = adapter;
      final request = client.get('/auth/me');
      final assertion = expectLater(request, throwsA(isA<DioException>()));
      await adapter.started.future;
      storage.token = 'new-session';
      adapter.response.complete(ResponseBody.fromString('{}', 401));
      await assertion;
      expect(storage.token, 'new-session');
      expect(storage.clears, 0);
      client.dio.close();
    },
  );

  testWidgets('profile refresh preserves the router and the current screen', (
    tester,
  ) async {
    final auth = TestAuthNotifier();
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => auth),
        onboardingCompleteProvider.overrideWith((ref) async => true),
      ],
    );
    await container.read(onboardingCompleteProvider.future);
    final router = container.read(routerProvider);
    router.go('/v/SR-TEST-1234');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SR-TEST-1234'), findsOneWidget);
    auth.updateProfile();
    await tester.pumpAndSettle();
    expect(identical(router, container.read(routerProvider)), isTrue);
    expect(find.text('SR-TEST-1234'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });
}
