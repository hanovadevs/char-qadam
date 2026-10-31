import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qadam/core/services/notification_service.dart';
import 'package:qadam/core/theme/app_theme.dart';
import 'package:qadam/data/auth/auth_state_provider.dart';
import 'package:qadam/data/models/user_model.dart';
import 'package:qadam/features/notifications/notification_coordinator.dart';
import 'package:qadam/features/notifications/notification_preferences.dart';
import 'package:qadam/features/notifications/notification_settings_screen.dart';
import 'package:qadam/features/notifications/reminder_bridge.dart';
import 'package:qadam/routing/app_router.dart';

class NotificationAuth extends StateNotifier<AuthState>
    implements AuthNotifier {
  NotificationAuth()
    : super(const AuthState(status: AuthStatus.unauthenticated));
  void signIn({bool merchant = false}) {
    state = AuthState(
      status: AuthStatus.authenticated,
      user: UserModel.fromJson({
        'id': merchant ? 'merchant' : 'customer',
        'email': 'fixture@example.test',
        'role': merchant ? 'MERCHANT' : 'USER',
        'status': 'ACTIVE',
        'created_at': '2026-10-31T00:00:00Z',
      }),
    );
  }

  void signOut() {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AndroidFlutterLocalNotificationsPlugin.registerWith();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final configs = <Map<dynamic, dynamic>>[];
  String? coldRoute;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NotificationService.destination.value = null;
    configs.clear();
    coldRoute = null;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => call.method == 'getNotificationAppLaunchDetails'
          ? {'notificationLaunchedApp': false}
          : true,
    );
    messenger.setMockMethodCallHandler(ReminderBridge.channel, (call) async {
      if (call.method == 'configure') {
        configs.add(call.arguments as Map<dynamic, dynamic>);
      }
      if (call.method == 'consumeLaunch') {
        final route = coldRoute;
        coldRoute = null;
        return route;
      }
      if (call.method == 'preview') return true;
      if (call.method == 'eventAllowed') return false;
      return null;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (call) async => call.method == 'openAppSettings' ? true : 1,
    );
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      null,
    );
    messenger.setMockMethodCallHandler(ReminderBridge.channel, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      null,
    );
  });
  test(
    'Preferences serialize concurrent changes and stay isolated by account',
    () async {
      final a = NotificationPreferencesNotifier('alice');
      await a.ready;
      await Future.wait([
        a.update({'walking': false}),
        a.update({'points': true}),
        a.update({'hour': 10, 'minute': 15}),
      ]);
      expect(a.state.walking, isFalse);
      expect(a.state.points, isTrue);
      expect(a.state.hour, 10);
      final b = NotificationPreferencesNotifier('bob');
      await b.ready;
      expect(b.state.walking, isTrue);
      expect(b.state.points, isFalse);
      final restored = NotificationPreferencesNotifier('alice');
      await restored.ready;
      expect(restored.state.walking, isFalse);
      expect(restored.state.minute, 15);
      a.dispose();
      b.dispose();
      restored.dispose();
    },
  );
  test(
    'Corrupt settings recover and reminder times remain inside quiet-hour boundaries',
    () async {
      SharedPreferences.setMockInitialValues({
        'stepsy.notifications.v1.alice': 'broken',
      });
      final prefs = NotificationPreferencesNotifier('alice');
      await prefs.ready;
      expect(prefs.state.loaded, isTrue);
      await prefs.update({'hour': 23, 'minute': 100});
      expect(prefs.state.hour, 20);
      expect(prefs.state.minute, 59);
      prefs.dispose();
    },
  );
  test('Only allowed app destinations can be queued', () {
    for (final route in [
      'https://evil.example',
      '/merchant-pos',
      '/wallet?token=secret',
      'javascript:alert(1)',
    ]) {
      NotificationService.queueDestination(route);
      expect(NotificationService.destination.value, isNull);
    }
    NotificationService.queueDestination('/tracking-help');
    expect(NotificationService.destination.value, '/tracking-help');
    NotificationService.queueDestination(null);
    expect(NotificationService.destination.value, '/tracking-help');
  });
  Future<GoRouter> host(
    WidgetTester tester,
    NotificationAuth auth, {
    String? cold,
  }) async {
    coldRoute = cold;
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        for (final path in ['/login', '/steps', '/wallet', '/tracking-help'])
          GoRoute(
            path: path,
            builder: (_, _) => Scaffold(body: Text(path)),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => auth),
          routerProvider.overrideWithValue(router),
        ],
        child: NotificationCoordinator(
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets(
    'Cold notification waits for customer auth and opens its destination once',
    (tester) async {
      final auth = NotificationAuth();
      final router = await host(tester, auth, cold: '/tracking-help');
      expect(router.routeInformationProvider.value.uri.path, '/login');
      expect(NotificationService.destination.value, '/tracking-help');
      auth.signIn();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/tracking-help');
      expect(NotificationService.destination.value, isNull);
      expect(configs.last['customer'], isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Merchant sessions disable customer reminders and discard customer destinations',
    (tester) async {
      final auth = NotificationAuth()..signIn(merchant: true);
      final router = await host(tester, auth);
      NotificationService.queueDestination('/wallet');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/login');
      expect(NotificationService.destination.value, isNull);
      expect(configs.last['customer'], isFalse);
      auth.signOut();
      await tester.pumpAndSettle();
      expect(configs.last['customer'], isFalse);
      expect(configs.last['userId'], isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Active app notification tap opens the authenticated help route',
    (tester) async {
      final auth = NotificationAuth()..signIn();
      final router = await host(tester, auth);
      NotificationService.queueDestination('/tracking-help');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/tracking-help');
      expect(configs.last['goal'], 8000);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final width in [320.0, 390.0]) {
    testWidgets('Notification preferences fit width $width and large text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = NotificationAuth()..signIn();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authStateProvider.overrideWith((ref) => auth)],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.8)),
              child: const NotificationSettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final walking = find.widgetWithText(
        SwitchListTile,
        'Walking encouragement',
      );
      final toggle = find.descendant(
        of: walking,
        matching: find.byType(Switch),
      );
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NotificationSettingsScreen)),
      );
      expect(container.read(notificationPreferencesProvider).walking, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
