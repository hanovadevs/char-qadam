import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qadam/core/services/background_sync_service.dart';
import 'package:qadam/features/activity/presentation/tracking_controls.dart';
import 'package:qadam/features/activity/providers/tracking_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  var paused = true;
  setUp(() {
    calls.clear();
    paused = true;
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(TrackingController.channel, (call) async {
          calls.add(call);
          if (call.method == 'pause') {
            paused = true;
            return null;
          }
          if (call.method == 'start') {
            paused = false;
            return true;
          }
          if (call.method == 'ensureTracking') {
            return jsonEncode({
              'paused': paused,
              'running': !paused,
              'unrestricted': false,
            });
          }
          return null;
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
    'Background sync does no authenticated or health work while explicitly paused',
    () async {
      SharedPreferences.setMockInitialValues({'stepsy_tracking_paused': true});
      expect(await BackgroundSyncService.performSync(), isTrue);
      // No secure-storage/Health Connect plugin is installed in this test. A
      // failure to honour Stop would reach those plugins instead of returning.
      expect(calls, isEmpty);
    },
  );
  testWidgets(
    'Reopening paused controls never resumes; only an explicit resume does',
    (tester) async {
      tester.view.physicalSize = const Size(320, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: const Scaffold(
                body: SingleChildScrollView(child: TrackingControls()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tracking paused'), findsOneWidget);
      expect(find.text('Resume tracking'), findsOneWidget);
      expect(calls.where((c) => c.method == 'start'), isEmpty);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TrackingControls)),
      );
      await container.read(trackingControllerProvider.notifier).refresh();
      expect(calls.where((c) => c.method == 'start'), isEmpty);
      expect(
        await container.read(trackingControllerProvider.notifier).resume(),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(calls.singleWhere((c) => c.method == 'start').arguments, {
        'resume': true,
      });
      expect(find.text('Background tracking on'), findsOneWidget);
      await tester.tap(find.text('Stop tracking'));
      await tester.pumpAndSettle();
      expect(find.text('Tracking paused'), findsOneWidget);
      expect(paused, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
