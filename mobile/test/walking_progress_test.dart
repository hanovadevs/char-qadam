import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qadam/core/theme/app_theme.dart';
import 'package:qadam/features/activity/presentation/walking_progress.dart';

void main() {
  testWidgets(
    'Walking buddy pauses offscreen, in background and under reduced motion',
    (tester) async {
      Widget scene({
        bool visible = true,
        bool reduce = false,
        bool tracking = true,
        int steps = 1240,
      }) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduce),
          child: TickerMode(
            enabled: visible,
            child: Scaffold(
              backgroundColor: AppTheme.accentDeep,
              body: WalkingProgress(
                steps: steps,
                goal: 5000,
                enabled: tracking,
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(scene());
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      expect(find.text('1,240'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.transientCallbackCount, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(scene(visible: false));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(scene(reduce: true, steps: 1241));
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(find.text('1,241'), findsOneWidget);
      await tester.pumpWidget(scene(tracking: false));
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
