import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qadam/core/theme/app_theme.dart';
import 'package:qadam/data/auth/auth_state_provider.dart';
import 'package:qadam/data/auth/email_verification.dart';
import 'package:qadam/routing/app_router.dart';

class CozyAuthFixture extends StateNotifier<AuthState> implements AuthNotifier {
  CozyAuthFixture()
    : super(const AuthState(status: AuthStatus.unauthenticated));
  int logins = 0, registrations = 0, google = 0, resetRequests = 0, resets = 0;
  String? email, password, resetToken;
  bool requestFails = false;
  @override
  Future<bool> login({required String email, required String password}) async {
    logins++;
    this.email = email;
    this.password = password;
    state = state.copyWith(errorMessage: 'Fixture sign-in error');
    return false;
  }

  @override
  Future<bool> signInWithGoogle({String? country, String? timezone}) async {
    google++;
    return false;
  }

  @override
  Future<bool> register({
    required String email,
    required String password,
    String? country,
    String? timezone,
  }) async {
    registrations++;
    this.email = email;
    this.password = password;
    state = AuthState(
      status: AuthStatus.verificationRequired,
      verification: EmailVerificationRequired(
        token: 'fixture-challenge',
        email: email,
        resendAfterSeconds: 60,
      ),
    );
    return false;
  }

  @override
  Future<String?> forgotPassword({required String email}) async {
    resetRequests++;
    this.email = email;
    state = state.copyWith(
      errorMessage: requestFails ? 'Fixture service unavailable' : null,
    );
    return null;
  }

  @override
  Future<bool> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    resets++;
    this.resetToken = resetToken;
    password = newPassword;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _capture = GlobalKey();
Future<GoRouter> mount(
  WidgetTester tester,
  CozyAuthFixture auth, {
  String path = '/welcome',
  double width = 390,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => auth),
        onboardingCompleteProvider.overrideWith((ref) async => true),
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: ref.watch(routerProvider),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: TextScaler.linear(scale),
            ),
            child: RepaintBoundary(key: _capture, child: child!),
          ),
        ),
      ),
    ),
  );
  final router = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  ).read(routerProvider);
  await tester.pumpAndSettle();
  router.go(path);
  await tester.pumpAndSettle();
  return router;
}

Future<void> tapText(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> screenshot(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_UI')) return;
  final context = tester.element(find.byType(MaterialApp));
  await tester.runAsync(() async {
    for (final pose in ['welcome', 'walk', 'peek', 'wave', 'letter', 'sit']) {
      await precacheImage(
        AssetImage('assets/companion/portraits/$pose.png'),
        context,
      );
    }
  });
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary =
        _capture.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = const String.fromEnvironment(
      'CAPTURE_DIRECTORY',
      defaultValue: '../artifacts/cozy',
    );
    final file = File('$directory/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    for (final family in ['Nunito']) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$family.ttf'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets('Welcome routes email and Google to established auth handlers', (
    tester,
  ) async {
    final auth = CozyAuthFixture();
    final router = await mount(tester, auth);
    await screenshot(tester, 'welcome');
    await tapText(tester, 'Continue with Google');
    expect(auth.google, 1);
    await tapText(tester, 'Continue with email');
    expect(router.routeInformationProvider.value.uri.path, '/login');
    expect(find.text('Welcome back.'), findsOneWidget);
    await screenshot(tester, 'sign-in');
    await tapText(tester, 'Sign in');
    expect(
      auth.logins,
      0,
      reason: 'Invalid forms must not call authentication',
    );
    await tester.enterText(
      find.byType(TextFormField).at(0),
      ' walker@example.test ',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'fixture-pass-123',
    );
    await tapText(tester, 'Sign in');
    expect(auth.logins, 1);
    expect(auth.email, 'walker@example.test');
    expect(auth.password, 'fixture-pass-123');
    expect(find.text('Fixture sign-in error'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('New account still requires the server email challenge', (
    tester,
  ) async {
    final auth = CozyAuthFixture();
    final router = await mount(tester, auth, path: '/register');
    await screenshot(tester, 'create-account');
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'new@example.test',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'short');
    await tapText(tester, 'Create account');
    expect(auth.registrations, 0);
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'fixture-pass-123',
    );
    await tapText(tester, 'Create account');
    expect(auth.registrations, 1);
    expect(router.routeInformationProvider.value.uri.path, '/verify-email');
    expect(auth.state.status, AuthStatus.verificationRequired);
    expect(find.textContaining('new@example.test'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Recovery error remains on email; success allows token reset', (
    tester,
  ) async {
    final auth = CozyAuthFixture()..requestFails = true;
    final router = await mount(tester, auth, path: '/forgot-password');
    await screenshot(tester, 'recover-access');
    await tester.enterText(
      find.byType(TextFormField).first,
      'walker@example.test',
    );
    await tapText(tester, 'Send reset instructions');
    expect(find.text('Fixture service unavailable'), findsOneWidget);
    expect(find.text('Reset token from your email'), findsNothing);
    auth.requestFails = false;
    await tapText(tester, 'Send reset instructions');
    expect(find.text('Reset token from your email'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'fixture-reset-token',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'fixture-new-pass',
    );
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'fixture-new-pass',
    );
    await tapText(tester, 'Update password');
    expect(auth.resets, 1);
    expect(auth.resetToken, 'fixture-reset-token');
    expect(router.routeInformationProvider.value.uri.path, '/login');
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Auth layouts and keyboard fit $width at text scale $scale', (
        tester,
      ) async {
        final auth = CozyAuthFixture();
        final router = await mount(tester, auth, width: width, scale: scale);
        for (final path in [
          '/welcome',
          '/login',
          '/register',
          '/forgot-password',
          '/welcome',
        ]) {
          router.go(path);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: path);
          if (path == '/login') {
            await tester.showKeyboard(find.byType(TextFormField).first);
            tester.view.viewInsets = const FakeViewPadding(bottom: 300);
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text('Sign in'));
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: 'Sign in stays reachable above keyboard',
            );
            tester.view.resetViewInsets();
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  test('Muted palette preserves readable text and action contrast', () {
    double ratio(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
    }

    for (final surface in [
      AppTheme.surface,
      AppTheme.surfaceMuted,
      AppTheme.sageWash,
      AppTheme.peachWash,
    ]) {
      expect(ratio(AppTheme.inkPrimary, surface), greaterThanOrEqualTo(4.5));
      expect(ratio(AppTheme.inkSecondary, surface), greaterThanOrEqualTo(4.5));
    }
    expect(
      ratio(AppTheme.onDeep, AppTheme.accentSolid),
      greaterThanOrEqualTo(4.5),
    );
  });
}
