import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qadam/core/theme/app_theme.dart';
import 'package:qadam/features/guided_tour/guided_tour.dart';
import 'package:qadam/features/guided_tour/tour_content.dart';
import 'package:qadam/features/guided_tour/tour_provider.dart';
import 'package:qadam/features/activity/providers/tracking_controller.dart';
import 'package:qadam/routing/app_router.dart';
import 'redesign_flow_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final family in ['Nunito']) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$family.ttf'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
  });
  final trackingCalls = <String>[];
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    trackingCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(TrackingController.channel, (call) async {
          trackingCalls.add(call.method);
          return call.method == 'ensureTracking'
              ? '{"paused":true,"running":false,"unrestricted":true}'
              : null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('stepsy/tracking_state'),
          (_) async => null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(TrackingController.channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('stepsy/tracking_state'),
          null,
        );
  });

  test(
    'Checkpoints resume, skip and complete independently for each customer',
    () async {
      final a = TourController('alice');
      await a.ready;
      expect(a.state.status, 'new');
      await a.start();
      await a.move(8);
      final resumed = TourController('alice');
      await resumed.ready;
      expect(resumed.state.active, isTrue);
      expect(resumed.state.index, 8);
      await resumed.finish(skipped: true);
      final skipped = TourController('alice');
      await skipped.ready;
      expect(skipped.state.status, 'skipped');
      await skipped.start();
      await skipped.move(tourStops.length - 1);
      await skipped.finish();
      final completed = TourController('alice');
      await completed.ready;
      expect(completed.state.status, 'completed');
      final b = TourController('bob');
      await b.ready;
      expect(b.state.status, 'new');
      final anonymous = TourController(null);
      await anonymous.start();
      expect(anonymous.state.status, 'disabled');
      for (final c in [a, resumed, skipped, completed, b, anonymous]) {
        c.dispose();
      }
    },
  );

  test(
    'Invalid saved progress recovers and cannot navigate outside tour bounds',
    () async {
      SharedPreferences.setMockInitialValues({
        'stepsy.guided-tour.v1.alice': '{"status":"active","index":999}',
        'stepsy.guided-tour.v1.bob': 'corrupt',
      });
      final a = TourController('alice');
      final b = TourController('bob');
      await Future.wait([a.ready, b.ready]);
      expect(a.state.index, tourStops.length - 1);
      expect(b.state.status, 'new');
      await a.move(-4);
      expect(a.state.index, 0);
      a.dispose();
      b.dispose();
    },
  );

  Future<void> settleTour(WidgetTester tester) async {
    // Several frames are needed for lazy-list creation and target scrolling.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 90));
    }
    await tester.pumpAndSettle();
  }

  testWidgets(
    'First visit starts once; all sections highlight without claiming or pausing',
    (tester) async {
      final rewards = fixtures.PreviewRewards();
      final container = await fixtures.mountPreview(
        tester,
        initialPath: '/steps',
        rewards: rewards,
        height: 850,
      );
      await settleTour(tester);
      expect(find.text('Shall we take a little tour?'), findsOneWidget);
      for (var i = 0; i < tourStops.length; i++) {
        expect(container.read(guidedTourProvider).index, i);
        final overlay = tester.widget<TourOverlay>(find.byType(TourOverlay));
        expect(overlay.locating, isFalse, reason: 'Target settled at stop $i');
        if (tourStops[i].target != null) {
          expect(
            overlay.target,
            isNotNull,
            reason: 'Real section found at ${tourStops[i].target}',
          );
        }
        expect(
          tester.takeException(),
          isNull,
          reason: 'No layout or routing failures at stop $i',
        );
        if (tourStops[i].title == 'Look at the details first.' &&
            const bool.fromEnvironment('CAPTURE_TOUR')) {
          final boundary =
              fixtures.captureKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            await precacheImage(
              const AssetImage('assets/companion/static/rest.png'),
              fixtures.captureKey.currentContext!,
            );
          });
          await tester.pump();
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1.5);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File('build/guided-tour-preview.png');
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(
          find.widgetWithText(
            ElevatedButton,
            i == 0
                ? 'Show me around'
                : i == tourStops.length - 1
                ? 'Let’s walk'
                : 'Next',
          ),
        );
        await settleTour(tester);
      }
      expect(container.read(guidedTourProvider).status, 'completed');
      expect(rewards.purchases, 0);
      expect(rewards.acknowledgements, 0);
      expect(
        trackingCalls.where((method) => method == 'start' || method == 'pause'),
        isEmpty,
      );
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        '/steps',
      );
      expect(find.byType(TourOverlay), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Skip stays dismissed and replay returns to the welcome stop', (
    tester,
  ) async {
    final container = await fixtures.mountPreview(
      tester,
      initialPath: '/steps',
    );
    await settleTour(tester);
    await tester.tap(find.text('Skip tour'));
    await settleTour(tester);
    expect(container.read(guidedTourProvider).status, 'skipped');
    container.read(routerProvider).go('/profile');
    await settleTour(tester);
    await fixtures.reveal(tester, find.text('Replay guided tour'));
    await tester.tap(find.text('Replay guided tour'));
    await settleTour(tester);
    expect(container.read(guidedTourProvider).index, 0);
    expect(find.text('Shall we take a little tour?'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'An external Wallet destination ends the tour without redirecting it',
    (tester) async {
      final container = await fixtures.mountPreview(
        tester,
        initialPath: '/steps',
      );
      await settleTour(tester);
      await container.read(guidedTourProvider.notifier).move(9);
      await settleTour(tester);
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        '/points',
      );
      container.read(routerProvider).go('/wallet');
      await settleTour(tester);
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        '/wallet',
      );
      expect(container.read(guidedTourProvider).status, 'skipped');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Saved checkpoint reopens its correct tab and Back finds the earlier section',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'stepsy.guided-tour.v1.preview-user': '{"status":"active","index":10}',
      });
      final container = await fixtures.mountPreview(
        tester,
        initialPath: '/steps',
      );
      await settleTour(tester);
      expect(container.read(guidedTourProvider).index, 10);
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        '/points',
      );
      await tester.tap(find.byTooltip('Previous tour step'));
      await settleTour(tester);
      expect(container.read(guidedTourProvider).index, 9);
      expect(
        tester.widget<TourOverlay>(find.byType(TourOverlay)).target,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final size in [const Size(320, 640), const Size(740, 360)]) {
    for (final index in [0, 7, tourStops.length - 1]) {
      testWidgets(
        'Thought cloud $index fits $size at 200% text with readable scrolling',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var next = 0;
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: MediaQuery(
                  data: const MediaQueryData(
                    textScaler: TextScaler.linear(2),
                    disableAnimations: true,
                  ),
                  child: Scaffold(
                    body: TourOverlay(
                      progress: TourProgress(
                        loaded: true,
                        status: 'active',
                        index: index,
                      ),
                      onBack: () {},
                      onNext: () => next++,
                      onSkip: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(
            find.widgetWithText(
              ElevatedButton,
              index == 0
                  ? 'Show me around'
                  : index == tourStops.length - 1
                  ? 'Let’s walk'
                  : 'Next',
            ),
          );
          expect(next, 1);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
