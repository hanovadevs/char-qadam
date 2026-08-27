import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../data/activity/activity_repository.dart';
import '../../../data/activity/health_service.dart';
import '../../../data/models/activity_models.dart';

class ActivityState {
  final int todaySteps;
  final int serverSteps;
  final int pointsEarnedToday;
  final int userBalance;
  final int dailyCap;
  final bool isSyncing;
  final bool hasPermission;
  final String selectedRange;
  final ActivityRangeModel? history;
  final String? errorMessage;
  final String? lastSyncTime;

  const ActivityState({
    this.todaySteps = 0,
    this.serverSteps = 0,
    this.pointsEarnedToday = 0,
    this.userBalance = 0,
    this.dailyCap = 20000,
    this.isSyncing = false,
    this.hasPermission = false,
    this.selectedRange = 'today',
    this.history,
    this.errorMessage,
    this.lastSyncTime,
  });

  ActivityState copyWith({
    int? todaySteps,
    int? serverSteps,
    int? pointsEarnedToday,
    int? userBalance,
    int? dailyCap,
    bool? isSyncing,
    bool? hasPermission,
    String? selectedRange,
    ActivityRangeModel? history,
    String? errorMessage,
    String? lastSyncTime,
  }) {
    return ActivityState(
      todaySteps: todaySteps ?? this.todaySteps,
      serverSteps: serverSteps ?? this.serverSteps,
      pointsEarnedToday: pointsEarnedToday ?? this.pointsEarnedToday,
      userBalance: userBalance ?? this.userBalance,
      dailyCap: dailyCap ?? this.dailyCap,
      isSyncing: isSyncing ?? this.isSyncing,
      hasPermission: hasPermission ?? this.hasPermission,
      selectedRange: selectedRange ?? this.selectedRange,
      history: history ?? this.history,
      errorMessage: errorMessage,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}

final activityProvider =
    StateNotifierProvider<ActivityNotifier, ActivityState>((ref) {
  final healthService = ref.watch(healthServiceProvider);
  final activityRepository = ref.watch(activityRepositoryProvider);
  return ActivityNotifier(
    healthService: healthService,
    activityRepository: activityRepository,
  );
});

class ActivityNotifier extends StateNotifier<ActivityState> {
  final HealthService healthService;
  final ActivityRepository activityRepository;
  final _uuid = const Uuid();

  ActivityNotifier({
    required this.healthService,
    required this.activityRepository,
  }) : super(const ActivityState()) {
    initAndSync();
  }

  /// Initialize health permissions, fetch steps, sync with server, and load history.
  Future<void> initAndSync() async {
    state = state.copyWith(isSyncing: true, errorMessage: null);

    final hasPerm = await healthService.requestPermissions();
    state = state.copyWith(hasPermission: hasPerm);

    final steps = await healthService.fetchTodaySteps();
    state = state.copyWith(todaySteps: steps);

    // If steps > 0, sync to server
    if (steps > 0) {
      await _performSync(
        steps: steps,
        source: 'health',
        date: _getTodayString(),
      );
    } else {
      await loadHistory(state.selectedRange);
      state = state.copyWith(isSyncing: false);
    }
  }

  Future<bool> _performSync({
    required int steps,
    required String source,
    required String date,
  }) async {
    try {
      final syncKey = _uuid.v4();
      final syncResponse = await activityRepository.syncActivity(
        localDate: date,
        eligibleSteps: steps,
        source: source,
        syncKey: syncKey,
      );

      final nowFormatted = DateFormat('hh:mm a').format(DateTime.now());

      state = state.copyWith(
        serverSteps: syncResponse.eligibleSteps,
        pointsEarnedToday: syncResponse.pointsAwarded,
        userBalance: syncResponse.balance,
        lastSyncTime: nowFormatted,
      );

      await loadHistory(state.selectedRange);
      state = state.copyWith(isSyncing: false);
      return true;
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(isSyncing: false, errorMessage: msg);
      return false;
    }
  }

  /// Manually sync step count (for testing/sandbox or manual entry)
  Future<bool> syncManualSteps({required int steps}) async {
    state = state.copyWith(isSyncing: true, todaySteps: steps);
    return _performSync(
      steps: steps,
      source: 'manual_debug',
      date: _getTodayString(),
    );
  }

  /// Load activity history for the selected range ('today', 'week', 'month').
  Future<void> loadHistory(String range) async {
    try {
      final historyData = await activityRepository.getActivityHistory(range: range);
      state = state.copyWith(
        selectedRange: range,
        history: historyData,
      );
    } catch (_) {}
  }

  String _getTodayString() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }
}
