import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/notification_service.dart';

import '../../../data/activity/activity_repository.dart';
import '../../../data/activity/health_service.dart';
import '../../../data/models/activity_models.dart';

class ActivityState {
  final int todaySteps;
  final int serverSteps;
  final int pointsEarnedToday;
  final int userBalance;
  final int dailyCap;
  final int currentStreakDays;
  final bool isSyncing;
  final bool hasPermission;
  final String? errorMessage;
  final String? lastSyncTime;
  final String selectedRange;
  final ActivityRangeModel? history;

  const ActivityState({
    this.todaySteps = 0,
    this.serverSteps = 0,
    this.pointsEarnedToday = 0,
    this.userBalance = 0,
    this.dailyCap = 20000,
    this.currentStreakDays = 0,
    this.isSyncing = false,
    this.hasPermission = false,
    this.errorMessage,
    this.lastSyncTime,
    this.selectedRange = 'today',
    this.history,
  });

  ActivityState copyWith({
    int? todaySteps,
    int? serverSteps,
    int? pointsEarnedToday,
    int? userBalance,
    int? dailyCap,
    int? currentStreakDays,
    bool? isSyncing,
    bool? hasPermission,
    String? errorMessage,
    String? lastSyncTime,
    String? selectedRange,
    ActivityRangeModel? history,
  }) {
    return ActivityState(
      todaySteps: todaySteps ?? this.todaySteps,
      serverSteps: serverSteps ?? this.serverSteps,
      pointsEarnedToday: pointsEarnedToday ?? this.pointsEarnedToday,
      userBalance: userBalance ?? this.userBalance,
      dailyCap: dailyCap ?? this.dailyCap,
      currentStreakDays: currentStreakDays ?? this.currentStreakDays,
      isSyncing: isSyncing ?? this.isSyncing,
      hasPermission: hasPermission ?? this.hasPermission,
      errorMessage: errorMessage,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      selectedRange: selectedRange ?? this.selectedRange,
      history: history ?? this.history,
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

  StreamSubscription<int>? _stepStreamSub;
  Timer? _debounceTimer;

  bool _permissionsRequested = false;
  DateTime? _lastSyncAt;

  ActivityNotifier({
    required this.healthService,
    required this.activityRepository,
  }) : super(const ActivityState()) {
    _listenToStepStream();
    initAndSync();
  }

  void _listenToStepStream() {
    _stepStreamSub = healthService.stepStream.listen((liveSteps) {
      if (liveSteps > state.todaySteps) {
        state = state.copyWith(todaySteps: liveSteps);
        _scheduleDebouncedSync();
      }
    });
  }

  void _scheduleDebouncedSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 10), () {
      if (state.todaySteps > state.serverSteps) {
        _performSync(
          steps: state.todaySteps,
          source: 'health',
          date: _getTodayString(),
        );
      }
    });
  }

  /// Initialize health permissions, fetch steps, sync with server, and load history.
  ///
  /// Safe to call on every app resume: permissions are only requested once per
  /// session, and repeated calls within a short window are throttled so the
  /// screen doesn't re-sync/reload constantly.
  Future<void> initAndSync() async {
    if (state.isSyncing) return;
    if (_lastSyncAt != null &&
        DateTime.now().difference(_lastSyncAt!) < const Duration(seconds: 30)) {
      return;
    }
    _lastSyncAt = DateTime.now();

    state = state.copyWith(isSyncing: true, errorMessage: null);

    // Request OS permissions only on the first run — re-requesting on every
    // resume spams the permission APIs and floods the log.
    if (!_permissionsRequested) {
      _permissionsRequested = true;
      final hasPerm = await healthService.requestPermissions();
      state = state.copyWith(hasPermission: hasPerm);
    }

    final rawSteps = await healthService.fetchTodaySteps();
    state = state.copyWith(todaySteps: rawSteps);

    // If steps > 0, sync to server
    if (rawSteps > 0) {
      await _performSync(
        steps: rawSteps,
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
      _lastSyncAt = DateTime.now();

      state = state.copyWith(
        todaySteps: syncResponse.eligibleSteps,
        serverSteps: syncResponse.eligibleSteps,
        pointsEarnedToday: syncResponse.pointsAwarded,
        userBalance: syncResponse.balance,
        lastSyncTime: nowFormatted,
      );

      if (syncResponse.pointsAwarded > 0) {
        NotificationService.showPointsEarned(
          pointsAwarded: syncResponse.pointsAwarded,
          totalBalance: syncResponse.balance,
        );
      }

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
      int streak = 0;
      if (historyData.days.isNotEmpty) {
        for (final day in historyData.days.reversed) {
          if (day.eligibleSteps >= 1000) {
            streak++;
          } else {
            break;
          }
        }
      }
      state = state.copyWith(
        selectedRange: range,
        history: historyData,
        currentStreakDays: streak,
      );
    } catch (_) {}
  }

  String _getTodayString() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _stepStreamSub?.cancel();
    super.dispose();
  }
}
