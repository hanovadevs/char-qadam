import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qadam/main.dart';

void main() {
  testWidgets('WalkNSaveApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: WalkNSaveApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify that the app launches successfully
    expect(find.byType(WalkNSaveApp), findsOneWidget);
  });
}
