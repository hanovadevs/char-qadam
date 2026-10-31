import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:qadam/main.dart';

void main() {
  testWidgets('StepsyApp smoke test', (WidgetTester tester) async {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    const notifications = MethodChannel(
      'dexterous.com/flutter/local_notifications',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          notifications,
          (call) async => call.method == 'getNotificationAppLaunchDetails'
              ? {'notificationLaunchedApp': false}
              : true,
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notifications, null),
    );
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: StepsyApp()));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify that the app launches successfully
    expect(find.byType(StepsyApp), findsOneWidget);
  });
}
