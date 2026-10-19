import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:qadam/data/activity/activity_repository.dart';
import 'package:qadam/data/activity/health_service.dart';
import 'package:qadam/data/activity/daily_step_counter.dart';
import 'package:qadam/data/models/activity_models.dart';
import 'package:qadam/features/activity/providers/activity_provider.dart';

class TestHealth implements HealthService {
  final events = StreamController<int>.broadcast(sync: true);
  int steps = 0;
  @override
  Stream<int> get stepStream => events.stream;
  @override
  Future<bool> requestPermissions() async => true;
  @override
  Future<int> fetchTodaySteps() async => steps;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestActivityRepository implements ActivityRepository {
  int calls = 0;
  final List<String> dates = [];
  int summaries = 0;
  int lastSteps = 0;
  @override
  Future<SyncResponse?> getCachedTodaySummary() async => null;
  Future<SyncResponse> Function(int steps, String date)? respond;
  @override
  Future<SyncResponse> syncActivity({
    required String localDate,
    required int eligibleSteps,
    required String source,
    required String syncKey,
  }) async {
    calls++;
    lastSteps = eligibleSteps;
    dates.add(localDate);
    if (respond != null) return respond!(eligibleSteps, localDate);
    return SyncResponse(
      localDate: localDate,
      eligibleSteps: eligibleSteps.clamp(0, 20000),
      pointsAwarded: 0,
      balance: 0,
      isReplay: false,
    );
  }

  @override
  Future<SyncResponse> getTodaySummary() async {
    summaries++;
    return SyncResponse(
      localDate: dates.isEmpty
          ? DateTime.now().toIso8601String().split('T').first
          : dates.last,
      eligibleSteps: lastSteps,
      pointsAwarded: 0,
      balance: 0,
      isReplay: false,
    );
  }

  @override
  Future<ActivityRangeModel> getActivityHistory({
    String range = 'today',
  }) async => ActivityRangeModel(range: range, totalSteps: 0, days: []);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('continuous walking syncs without waiting for the user to stop', (
    tester,
  ) async {
    final health = TestHealth();
    final repo = TestActivityRepository();
    final notifier = ActivityNotifier(
      healthService: health,
      activityRepository: repo,
      autoStart: false,
    );
    for (var i = 1; i <= 12; i++) {
      health.events.add(i);
      await tester.pump(const Duration(seconds: 1));
    }
    expect(repo.calls, greaterThanOrEqualTo(1));
    notifier.dispose();
    await health.events.close();
  });

  testWidgets(
    'late server responses preserve newer live steps and daily earned total',
    (tester) async {
      final health = TestHealth();
      final repo = TestActivityRepository();
      final response = Completer<SyncResponse>();
      repo.respond = (_, _) => response.future;
      final notifier = ActivityNotifier(
        healthService: health,
        activityRepository: repo,
        autoStart: false,
      );
      health.events.add(500);
      await tester.pump(const Duration(seconds: 10));
      health.events.add(550);
      response.complete(
        SyncResponse(
          localDate: repo.dates.single,
          eligibleSteps: 500,
          pointsAwarded: 0,
          pointsEarnedToday: 5,
          balance: 5,
          isReplay: true,
        ),
      );
      await tester.pump();
      expect(notifier.state.todaySteps, 550);
      expect(notifier.state.serverSteps, 500);
      expect(notifier.state.settledSteps, 500);
      expect(notifier.state.pointsEarnedToday, 5);
      notifier.dispose();
      await health.events.close();
    },
  );

  testWidgets('daily reward cap does not reduce the actual walking count', (
    tester,
  ) async {
    final health = TestHealth();
    final repo = TestActivityRepository();
    final notifier = ActivityNotifier(
      healthService: health,
      activityRepository: repo,
      autoStart: false,
    );
    health.events.add(25000);
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(notifier.state.todaySteps, 25000);
    expect(notifier.state.serverSteps, 20000);
    expect(notifier.state.settledSteps, 25000);
    health.events.add(25100);
    expect(notifier.state.settledSteps, 25100);
    await tester.pump(const Duration(seconds: 10));
    expect(repo.calls, 1);
    notifier.dispose();
    await health.events.close();
  });

  testWidgets(
    'a previous-day response cannot restore yesterday after midnight',
    (tester) async {
      var now = DateTime(2026, 10, 17, 23, 59, 50);
      final health = TestHealth();
      final repo = TestActivityRepository();
      final response = Completer<SyncResponse>();
      repo.respond = (_, _) => response.future;
      final notifier = ActivityNotifier(
        healthService: health,
        activityRepository: repo,
        clock: () => now,
        autoStart: false,
      );
      health.events.add(6000);
      await tester.pump(const Duration(seconds: 10));
      now = DateTime(2026, 10, 18);
      response.complete(
        SyncResponse(
          localDate: '2026-10-17',
          eligibleSteps: 6000,
          pointsAwarded: 0,
          balance: 60,
          isReplay: false,
        ),
      );
      await tester.pump();
      expect(notifier.state.todaySteps, 0);
      expect(notifier.state.serverSteps, 0);
      health.events.add(3);
      expect(notifier.state.todaySteps, 3);
      notifier.dispose();
      await health.events.close();
    },
  );

  test('streaks break on missing days and do not depend on history order', () {
    final days = [
      ActivityPeriodModel(date: '2026-10-14', eligibleSteps: 2000),
      ActivityPeriodModel(date: '2026-10-17', eligibleSteps: 2000),
      ActivityPeriodModel(date: '2026-10-16', eligibleSteps: 2000),
    ];
    expect(ActivityNotifier.countStreak(days, DateTime(2026, 10, 17)), 2);
  });

  test(
    'motion snapshot survives restart and reboot without losing carried steps',
    () {
      final counter = DailyStepCounter();
      final at = DateTime(2026, 10, 17, 12);
      counter.record(5000, at);
      counter.record(5100, at.add(const Duration(seconds: 60)));
      final restored = DailyStepCounter()..restore(counter.toJson());
      restored.record(30, at.add(const Duration(seconds: 120)));
      restored.record(40, at.add(const Duration(seconds: 130)));
      expect(restored.steps, 140);
      restored.mergeHealth(100, at);
      expect(restored.steps, 140);
    },
  );
}
