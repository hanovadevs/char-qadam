import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/notification_service.dart';

import '../../../data/activity/activity_repository.dart';
import '../../../data/activity/health_service.dart';
import '../../../data/models/activity_models.dart';
import '../../points/providers/points_provider.dart';
import '../../../core/services/background_sync_service.dart';
import '../../../data/auth/auth_state_provider.dart';

class ActivityState {
  final int todaySteps;
  final int serverSteps;
  final int pointsEarnedToday;
  final int userBalance;
  final int dailyCap;
  final int stepsPerPoint;
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
    this.stepsPerPoint = 100,
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
    int? stepsPerPoint,
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
      stepsPerPoint: stepsPerPoint ?? this.stepsPerPoint,
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

final activityProvider = StateNotifierProvider<ActivityNotifier, ActivityState>(
  (ref) {
    final healthService = ref.watch(healthServiceProvider);
    final activityRepository = ref.watch(activityRepositoryProvider);
    final authenticated = ref.watch(
      authStateProvider.select(
        (state) => state.status == AuthStatus.authenticated,
      ),
    );
    if (authenticated) unawaited(BackgroundSyncService.initialize());
    return ActivityNotifier(
      healthService: healthService,
      activityRepository: activityRepository,
      onPointsChanged: () => ref.invalidate(pointsProvider),
      autoStart: authenticated,
    );
  },
);

class ActivityNotifier extends StateNotifier<ActivityState> {
  final HealthService healthService;
  final ActivityRepository activityRepository;
  final DateTime Function() now;
  final void Function()? onPointsChanged;
  final _uuid = const Uuid();
  StreamSubscription<int>? _stepStreamSub;
  Timer? _syncTimer;
  Timer? _dayTimer;
  bool _permissionsRequested = false;
  DateTime? _lastSyncAt;
  late String _day;
  int _historyRequest = 0;
  bool _requestInFlight = false;

  ActivityNotifier({
    required this.healthService,
    required this.activityRepository,
    DateTime Function()? clock,
    this.onPointsChanged,
    bool autoStart = true,
  }) : now = clock ?? DateTime.now,
       super(const ActivityState()) {
    _day = _today();
    _stepStreamSub = healthService.stepStream.listen((steps) {
      if (!mounted) return;
      _checkDay();
      if (steps > state.todaySteps) {
        state = state.copyWith(todaySteps: steps);
        _scheduleSync();
      }
    });
    if (autoStart) {
      _dayTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_checkDay()) initAndSync(force: true);
      });
    }
    if (autoStart) initAndSync();
  }

  bool _checkDay() {
    final day = _today();
    if (day == _day) return false;
    _day = day;
    _lastSyncAt = null;
    _syncTimer?.cancel();
    _syncTimer = null;
    state = ActivityState(
      hasPermission: state.hasPermission,
      userBalance: state.userBalance,
      dailyCap: state.dailyCap,
      stepsPerPoint: state.stepsPerPoint,
      selectedRange: state.selectedRange,
    );
    return true;
  }

  void _scheduleSync({Duration delay = const Duration(seconds: 10)}) {
    if (_syncTimer != null ||
        _requestInFlight ||
        !mounted ||
        min(state.todaySteps, state.dailyCap) <= state.serverSteps) {
      return;
    }
    // A fixed window keeps syncing during continuous walking. A resetting
    // debounce waits forever if the user never stops moving.
    _syncTimer = Timer(delay, () {
      _syncTimer = null;
      _checkDay();
      if (min(state.todaySteps, state.dailyCap) > state.serverSteps) {
        _performSync(steps: state.todaySteps, source: 'health', date: _day);
      }
    });
  }

  Future<void> initAndSync({bool force = false}) async {
    _checkDay();
    if (_requestInFlight) return;
    if (!force &&
        _lastSyncAt != null &&
        now().difference(_lastSyncAt!) < const Duration(seconds: 30)) {
      return;
    }
    _requestInFlight = true;
    state = state.copyWith(isSyncing: true);
    final date = _day;
    try {
      if (!_permissionsRequested || force) {
        _permissionsRequested = true;
        final permitted = await healthService.requestPermissions();
        if (!mounted) return;
        state = state.copyWith(hasPermission: permitted);
      }
      final steps = await healthService.fetchTodaySteps();
      if (!mounted) return;
      if (_checkDay() || _day != date) return;
      state = state.copyWith(todaySteps: max(state.todaySteps, steps));
      // Even a zero-step sync restores today's server count and balance after
      // reopening; it does not mint points or invent missing sensor readings.
      await _send(steps: state.todaySteps, source: 'health', date: date);
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      _requestInFlight = false;
      if (mounted) {
        state = state.copyWith(
          isSyncing: false,
          errorMessage: state.errorMessage,
        );
        _scheduleSync(
          delay: state.errorMessage == null
              ? const Duration(seconds: 10)
              : const Duration(seconds: 30),
        );
      }
    }
  }

  Future<bool> _performSync({
    required int steps,
    required String source,
    required String date,
  }) async {
    if (_requestInFlight || !mounted) return false;
    _requestInFlight = true;
    state = state.copyWith(isSyncing: true);
    var success = false;
    try {
      success = await _send(steps: steps, source: source, date: date);
    } finally {
      _requestInFlight = false;
      if (mounted) {
        state = state.copyWith(
          isSyncing: false,
          errorMessage: state.errorMessage,
        );
        _scheduleSync(
          delay: success
              ? const Duration(seconds: 10)
              : const Duration(seconds: 30),
        );
      }
    }
    return success;
  }

  Future<bool> _send({
    required int steps,
    required String source,
    required String date,
  }) async {
    try {
      final response = await activityRepository.syncActivity(
        localDate: date,
        eligibleSteps: steps,
        source: source,
        syncKey: _uuid.v4(),
      );
      if (!mounted) return false;
      _checkDay();
      if (_day != date) return true;
      _lastSyncAt = now();
      state = state.copyWith(
        todaySteps: max(state.todaySteps, response.eligibleSteps),
        serverSteps: response.eligibleSteps,
        pointsEarnedToday:
            response.pointsEarnedToday ??
            max(
              state.pointsEarnedToday,
              response.eligibleSteps ~/ response.stepsPerPoint,
            ),
        stepsPerPoint: response.stepsPerPoint,
        dailyCap: response.dailyStepCap,
        userBalance: response.balance,
        lastSyncTime: DateFormat('hh:mm a').format(now()),
      );
      onPointsChanged?.call();
      if (response.pointsAwarded > 0) {
        unawaited(
          NotificationService.showPointsEarned(
            pointsAwarded: response.pointsAwarded,
            totalBalance: response.balance,
          ),
        );
      }
      await loadHistory(state.selectedRange);
      return true;
    } catch (e) {
      if (mounted && date == _day) {
        state = state.copyWith(
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        );
      }
      return false;
    }
  }

  Future<bool> syncManualSteps({required int steps}) async {
    if (!kDebugMode) return false;
    _checkDay();
    return _performSync(steps: steps, source: 'manual_debug', date: _day);
  }

  Future<void> loadHistory(String range) async {
    final request = ++_historyRequest;
    state = state.copyWith(
      selectedRange: range,
      errorMessage: state.errorMessage,
    );
    try {
      final history = await activityRepository.getActivityHistory(range: range);
      // Streaks are independent of the visible filter and missing dates break them.
      final streakHistory = range == 'all'
          ? history
          : await activityRepository.getActivityHistory(range: 'all');
      if (!mounted || request != _historyRequest) return;
      state = state.copyWith(
        history: history,
        currentStreakDays: countStreak(streakHistory.days, now()),
        errorMessage: state.errorMessage,
      );
    } catch (e) {
      if (mounted && request == _historyRequest) {
        state = state.copyWith(
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  static int countStreak(List<ActivityPeriodModel> days, DateTime now) {
    final totals = {for (final day in days) day.date: day.eligibleSteps};
    var day = DateTime(now.year, now.month, now.day);
    final format = DateFormat('yyyy-MM-dd');
    if ((totals[format.format(day)] ?? 0) < 1000) {
      day = day.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while ((totals[format.format(day)] ?? 0) >= 1000) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  String _today() => DateFormat('yyyy-MM-dd').format(now());

  @override
  void dispose() {
    _syncTimer?.cancel();
    _dayTimer?.cancel();
    _stepStreamSub?.cancel();
    super.dispose();
  }
}
