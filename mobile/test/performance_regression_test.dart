import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qadam/data/auth/auth_repository.dart';
import 'package:qadam/data/auth/auth_state_provider.dart';
import 'package:qadam/data/auth/token_storage.dart';
import 'package:qadam/data/auth/device_identity.dart';
import 'package:qadam/data/api/api_client.dart';
import 'package:qadam/data/models/user_model.dart';
import 'package:qadam/data/models/activity_models.dart';
import 'package:qadam/data/models/points_models.dart';
import 'package:qadam/data/models/offer_models.dart';
import 'package:qadam/data/models/voucher_models.dart';
import 'package:qadam/data/points/points_repository.dart';
import 'package:qadam/data/rewards/rewards_repository.dart';
import 'package:qadam/data/rewards/redemption_journal.dart';
import 'package:qadam/data/wallet/wallet_repository.dart';
import 'package:qadam/features/points/providers/points_provider.dart';
import 'package:qadam/features/rewards/providers/rewards_provider.dart';
import 'package:qadam/features/wallet/providers/wallet_provider.dart';
import 'package:qadam/features/activity/providers/activity_provider.dart';
import 'tracking_regression_test.dart' show TestHealth, TestActivityRepository;

final savedBalance = BalanceModel(balance: 50, totalEarned: 70, totalSpent: 20);
final emptyLedger = LedgerPageModel(
  total: 0,
  limit: 20,
  offset: 0,
  entries: [],
);

class SlowPoints implements PointsRepository {
  int balances = 0, histories = 0;
  final balance = Completer<BalanceModel>();
  final history = Completer<LedgerPageModel>();
  BalanceModel? nextBalance;
  @override
  Future<BalanceModel?> getCachedBalance() async => savedBalance;
  @override
  Future<LedgerPageModel?> getCachedHistory() async => emptyLedger;
  @override
  Future<BalanceModel> getBalance() {
    balances++;
    return balances > 1 && nextBalance != null
        ? Future.value(nextBalance)
        : balance.future;
  }

  @override
  Future<LedgerPageModel> getHistory({int limit = 20, int offset = 0}) {
    histories++;
    return history.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SlowOffers implements RewardsRepository {
  int calls = 0;
  final response = Completer<List<OfferModel>>();
  @override
  Future<List<OfferModel>?> getCachedOffers() async => [];
  @override
  Future<Map<String, PendingPurchase>> pendingPurchases() async => {};
  @override
  Future<List<OfferModel>> getOffers() {
    calls++;
    return response.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SlowWallet implements WalletRepository {
  final calls = <String, int>{};
  final responses = <String, Completer<List<VoucherModel>>>{};
  @override
  Future<List<VoucherModel>?> getCachedVouchers(String status) async => [];
  @override
  Future<List<VoucherModel>> getVouchers({String status = 'active'}) {
    calls.update(status, (v) => v + 1, ifAbsent: () => 1);
    return responses.putIfAbsent(status, () => Completer()).future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SlowHistory extends TestActivityRepository {
  int histories = 0;
  final history = Completer<ActivityRangeModel>();
  @override
  Future<ActivityRangeModel> getActivityHistory({String range = 'today'}) {
    histories++;
    return history.future;
  }
}

class SavedActivity extends TestActivityRepository {
  final String cachedDate;
  SavedActivity(this.cachedDate);
  @override
  Future<SyncResponse?> getCachedTodaySummary() async => SyncResponse(
    localDate: cachedDate,
    eligibleSteps: 50,
    pointsAwarded: 0,
    balance: 0,
    isReplay: false,
  );
  @override
  Future<SyncResponse> getTodaySummary() async {
    summaries++;
    return SyncResponse(
      localDate: DateTime.now().toIso8601String().split('T').first,
      eligibleSteps: 50,
      pointsAwarded: 0,
      balance: 0,
      isReplay: false,
    );
  }
}

class LocalSession implements TokenStorage {
  String? token;
  UserModel? user;
  @override
  Future<String?> getToken() async => token;
  @override
  Future<UserModel?> getUser() async => user;
  @override
  Future<void> saveToken(String value) async {
    token = value;
  }

  @override
  Future<void> saveUser(UserModel value) async {
    user = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class EmbeddedProfileAuth extends AuthRepository {
  int profileRequests = 0;
  EmbeddedProfileAuth(ApiClient client) : super(apiClient: client);
  @override
  Future<String> login({
    required String email,
    required String password,
  }) async => 'new-token';
  @override
  Future<UserModel> getMe() {
    profileRequests++;
    return Future.error(
      StateError('The profile should already be in the sign-in response'),
    );
  }
}

void main() {
  testWidgets(
    'reopening unchanged steps uses the cached baseline and a read; yesterday cache is ignored',
    (tester) async {
      final today = DateTime.now().toIso8601String().split('T').first;
      for (final cachedDate in [today, '2020-01-01']) {
        final health = TestHealth()..steps = 50;
        final repo = SavedActivity(cachedDate);
        final notifier = ActivityNotifier(
          healthService: health,
          activityRepository: repo,
          autoStart: false,
        );
        await notifier.initAndSync();
        expect(notifier.state.todaySteps, 50);
        expect(repo.calls, cachedDate == today ? 0 : 1);
        expect(repo.summaries, cachedDate == today ? 1 : 0);
        notifier.dispose();
        await health.events.close();
      }
    },
  );
  test(
    'sign-in completes using the verified response profile without another request',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalSession();
      final client = ApiClient(
        tokenStorage: storage,
        deviceIdentity: DeviceIdentity(loader: () async => 'a' * 64),
      );
      final repo = EmbeddedProfileAuth(client)
        ..authenticatedUser = UserModel(
          id: 'verified-user',
          email: 'test@example.com',
          status: 'ACTIVE',
          createdAt: DateTime(2026),
        );
      final notifier = AuthNotifier(
        tokenStorage: storage,
        apiClient: client,
        authRepository: repo,
      );
      await notifier.checkAuthStatus();
      expect(
        await notifier.login(
          email: 'test@example.com',
          password: 'test-password',
        ),
        isTrue,
      );
      expect(repo.profileRequests, 0);
      expect(notifier.state.user?.id, 'verified-user');
      expect(storage.user?.id, 'verified-user');
      notifier.dispose();
      client.dio.close();
    },
  );

  testWidgets(
    'a mutation arriving during refresh fetches a fresh balance afterward',
    (tester) async {
      final repo = SlowPoints()
        ..nextBalance = BalanceModel(
          balance: 80,
          totalEarned: 100,
          totalSpent: 20,
        );
      final notifier = PointsNotifier(pointsRepository: repo);
      await tester.pump();
      final changed = notifier.refreshAfterMutation();
      repo.balance.complete(savedBalance);
      repo.history.complete(emptyLedger);
      await changed;
      expect(repo.balances, 2);
      expect(notifier.state.balanceData?.balance, 80);
      notifier.dispose();
    },
  );
  testWidgets(
    'points show saved balance and start independent reads together; refreshes coalesce',
    (tester) async {
      final repo = SlowPoints();
      final notifier = PointsNotifier(pointsRepository: repo);
      await tester.pump();
      expect(notifier.state.balanceData?.balance, 50);
      expect(repo.balances, 1);
      expect(
        repo.histories,
        1,
      ); // Must start before the balance response arrives.
      final refresh = notifier.refresh();
      expect(repo.balances, 1);
      repo.balance.complete(
        BalanceModel(balance: 60, totalEarned: 80, totalSpent: 20),
      );
      repo.history.complete(emptyLedger);
      await refresh;
      expect(notifier.state.balanceData?.balance, 60);
      expect(notifier.state.isLoading, isFalse);
      notifier.dispose();
    },
  );

  testWidgets('repeated catalog refreshes share one request', (tester) async {
    final repo = SlowOffers();
    final notifier = RewardsNotifier(rewardsRepository: repo);
    await tester.pump();
    final refresh = notifier.fetchOffers();
    expect(repo.calls, 1);
    repo.response.complete([]);
    await refresh;
    expect(notifier.state.isLoading, isFalse);
    notifier.dispose();
  });

  testWidgets(
    'wallet coalesces the same filter and rejects a late previous filter',
    (tester) async {
      final repo = SlowWallet();
      final notifier = WalletNotifier(walletRepository: repo);
      await tester.pump();
      final active = notifier.refresh();
      await tester.pump();
      expect(repo.calls['active'], 1);
      final used = notifier.fetchVouchers('redeemed');
      await tester.pump();
      repo.responses['redeemed']!.complete([]);
      await used;
      repo.responses['active']!.complete([]);
      await active;
      expect(notifier.state.selectedStatus, 'redeemed');
      expect(notifier.state.isLoading, isFalse);
      notifier.dispose();
    },
  );

  testWidgets(
    'sync finishes before slow history and unchanged sync does not reload points',
    (tester) async {
      final health = TestHealth()..steps = 100;
      final repo = SlowHistory();
      var pointRefreshes = 0;
      final notifier = ActivityNotifier(
        healthService: health,
        activityRepository: repo,
        autoStart: false,
        onPointsChanged: () => pointRefreshes++,
      );
      await notifier.initAndSync();
      expect(repo.calls, 1);
      expect(repo.histories, 2);
      expect(notifier.state.isSyncing, isFalse);
      expect(notifier.state.serverSteps, 100);
      await notifier.initAndSync(force: true);
      expect(repo.calls, 1);
      expect(repo.summaries, 1); // No write transaction for unchanged steps.
      expect(repo.histories, 2); // The still-pending history is reused.
      expect(pointRefreshes, 0);
      repo.history.complete(
        ActivityRangeModel(range: 'all', totalSteps: 100, days: []),
      );
      await tester.pump();
      notifier.dispose();
      await health.events.close();
    },
  );
}
