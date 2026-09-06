import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qadam/data/activity/activity_repository.dart';
import 'package:qadam/data/models/activity_models.dart';
import 'package:qadam/features/activity/presentation/progress_screen.dart';

class FakeActivityRepository implements ActivityRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<ActivityRangeModel> getActivityHistory({String range = 'today'}) async {
    return ActivityRangeModel(
      range: range,
      totalSteps: 75000,
      days: [
        ActivityPeriodModel(date: '2026-08-01', eligibleSteps: 8500),
        ActivityPeriodModel(date: '2026-08-02', eligibleSteps: 11200),
        ActivityPeriodModel(date: '2026-08-03', eligibleSteps: 9400),
        ActivityPeriodModel(date: '2026-08-04', eligibleSteps: 12100),
        ActivityPeriodModel(date: '2026-08-05', eligibleSteps: 10500),
        ActivityPeriodModel(date: '2026-08-06', eligibleSteps: 13000),
        ActivityPeriodModel(date: '2026-08-07', eligibleSteps: 10300),
      ],
    );
  }
}

void main() {
  testWidgets('ProgressScreen renders Apple-style segmented control and bar chart', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeRepo = FakeActivityRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activityRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: ProgressScreen(),
        ),
      ),
    );

    // Initial frame
    await tester.pump();
    // Complete async data load
    await tester.pump(const Duration(milliseconds: 200));

    // Verify Title and Tabs
    expect(find.text('Progress & trends'), findsOneWidget);
    expect(find.text('Weeks'), findsOneWidget);
    expect(find.text('Months'), findsOneWidget);

    // Verify Metric Labels
    expect(find.text('Daily average'), findsOneWidget);
    expect(find.text('Estimated distance'), findsOneWidget);
    expect(find.text('Active days'), findsOneWidget);
    expect(find.text('Estimated energy'), findsOneWidget);

    // Verify breakdown section in Weeks mode
    expect(find.text('Weekly breakdown'), findsOneWidget);

    // Switch to 'Months' segment
    await tester.tap(find.text('Months'));
    await tester.pumpAndSettle();

    // Verify breakdown section is updated to Months
    expect(find.text('Monthly breakdown'), findsOneWidget);
  });
}
