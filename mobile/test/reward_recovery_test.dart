import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qadam/features/wallet/providers/wallet_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qadam/core/services/cache_service.dart';
import 'package:qadam/data/api/api_client.dart';
import 'package:qadam/data/auth/device_identity.dart';
import 'package:qadam/data/auth/token_storage.dart';
import 'package:qadam/data/models/offer_models.dart';
import 'package:qadam/data/rewards/redemption_journal.dart';
import 'package:qadam/data/rewards/rewards_repository.dart';
import 'package:qadam/features/points/providers/points_provider.dart';
import 'package:qadam/features/rewards/providers/rewards_provider.dart';
import 'package:qadam/features/rewards/presentation/rewards_screen.dart';
import 'package:qadam/features/rewards/presentation/reward_fireworks.dart';

class NoToken implements TokenStorage {
  @override
  Future<String?> getToken() async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PurchaseAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int? failureStatus;
  bool timeout = true;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (timeout) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    }
    return ResponseBody.fromString(
      jsonEncode(
        failureStatus == null
            ? {
                'voucher_id': 'voucher-one',
                'short_code': 'SR-ABCD-EFGH',
                'token': 'opaque-token',
                'expires_at': '2027-01-01T00:00:00Z',
                'points_spent': 50,
                'balance': 20,
                'is_replay': true,
              }
            : {'detail': 'Purchase rejected'},
      ),
      failureStatus ?? 201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class RecoveryRewards extends StateNotifier<RewardsState>
    implements RewardsNotifier {
  int recovered = 0;
  int acknowledged = 0;
  RecoveryRewards()
    : super(
        const RewardsState(
          pendingPurchases: {
            'hidden-offer': PendingPurchase('purchase-key', 50),
          },
        ),
      );
  @override
  Future<void> fetchOffers() async {}
  @override
  Future<RedeemResultModel?> redeem(String offerId) async {
    recovered++;
    return RedeemResultModel(
      voucherId: 'existing-voucher',
      shortCode: 'SR-ABCD-EFGH',
      token: 'token',
      expiresAt: DateTime(2027),
      pointsSpent: 50,
      balance: 20,
      isReplay: true,
      requestKey: 'purchase-key',
    );
  }

  @override
  Future<void> acknowledgePurchase(String offerId, String? requestKey) async {
    acknowledged++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RecoveryPoints extends StateNotifier<PointsState>
    implements PointsNotifier {
  RecoveryPoints() : super(const PointsState());
  @override
  Future<void> refresh() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RecoveryWallet extends StateNotifier<WalletState>
    implements WalletNotifier {
  RecoveryWallet() : super(const WalletState());
  @override
  Future<void> fetchVouchers(String status) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'restart and concurrent callers preserve one purchase ID and original price',
    () async {
      final first = RedemptionJournal(userId: 'alice');
      final other = RedemptionJournal(userId: 'alice');
      final purchases = await Future.wait([
        first.getOrCreate('offer', expectedPointsCost: 50),
        other.getOrCreate('offer', expectedPointsCost: 99),
      ]);
      expect(purchases.map((p) => p.requestKey).toSet(), hasLength(1));
      final resumed = await RedemptionJournal(
        userId: 'alice',
      ).getOrCreate('offer');
      expect(resumed.requestKey, purchases.first.requestKey);
      expect(resumed.expectedPointsCost, 50);
    },
  );

  test(
    'pending purchases are isolated by account and survive cache logout cleanup',
    () async {
      final alice = RedemptionJournal(userId: 'alice');
      final bob = RedemptionJournal(userId: 'bob');
      final a = await alice.getOrCreate('offer', expectedPointsCost: 50);
      expect(await bob.pending(), isEmpty);
      await CacheService(userId: 'alice').clearAccountCache();
      expect((await alice.pending())['offer']?.requestKey, a.requestKey);
      expect(
        () => RedemptionJournal(
          userId: null,
        ).getOrCreate('offer', expectedPointsCost: 50),
        throwsStateError,
      );
    },
  );

  test('a stale acknowledgement cannot clear a newer purchase', () async {
    final journal = RedemptionJournal(userId: 'alice');
    final old = await journal.getOrCreate('offer', expectedPointsCost: 50);
    await journal.acknowledge('offer', old.requestKey);
    final newer = await journal.getOrCreate('offer', expectedPointsCost: 60);
    await journal.acknowledge('offer', old.requestKey);
    expect((await journal.pending())['offer']?.requestKey, newer.requestKey);
  });

  test(
    'corrupt recovery data blocks a new purchase without overwriting the old record',
    () async {
      SharedPreferences.setMockInitialValues({
        'stepsy_reward_requests_alice': 'broken',
      });
      final journal = RedemptionJournal(userId: 'alice');
      await expectLater(
        journal.getOrCreate('offer', expectedPointsCost: 50),
        throwsStateError,
      );
      expect(
        (await SharedPreferences.getInstance()).getString(
          'stepsy_reward_requests_alice',
        ),
        'broken',
      );
      expect(await RedemptionJournal(userId: 'bob').pending(), isEmpty);
    },
  );

  test(
    'timeout retry after restart sends the same ID and price; success waits for acknowledgement',
    () async {
      final api = ApiClient(
        tokenStorage: NoToken(),
        deviceIdentity: DeviceIdentity(loader: () async => 'a' * 64),
      );
      final adapter = PurchaseAdapter();
      api.dio.httpClientAdapter = adapter;
      RewardsRepository repository() => RewardsRepository(
        apiClient: api,
        cacheService: CacheService(userId: 'alice'),
      );
      await expectLater(
        repository().redeemOffer('offer', expectedPointsCost: 50),
        throwsException,
      );
      final originalKey = adapter.requests.single.headers['Idempotency-Key'];
      adapter.timeout = false;
      final resumed = await repository().redeemOffer(
        'offer',
        expectedPointsCost: 99,
      );
      expect(adapter.requests.last.headers['Idempotency-Key'], originalKey);
      expect(adapter.requests.last.data, {'expected_points_cost': 50});
      expect(resumed.isReplay, isTrue);
      expect(await repository().pendingPurchases(), contains('offer'));
      await repository().acknowledgePurchase('offer', resumed.requestKey!);
      expect(await repository().pendingPurchases(), isEmpty);
      api.dio.close();
    },
  );

  for (final status in [402, 503]) {
    test(
      '$status response ${status == 402 ? 'clears rejected' : 'retains uncertain'} purchase',
      () async {
        final api = ApiClient(
          tokenStorage: NoToken(),
          deviceIdentity: DeviceIdentity(loader: () async => 'a' * 64),
        );
        api.dio.httpClientAdapter = PurchaseAdapter()
          ..timeout = false
          ..failureStatus = status;
        final repo = RewardsRepository(
          apiClient: api,
          cacheService: CacheService(userId: 'alice'),
        );
        await expectLater(
          repo.redeemOffer('offer', expectedPointsCost: 50),
          throwsException,
        );
        expect(
          (await repo.pendingPurchases()).containsKey('offer'),
          status == 503,
        );
        api.dio.close();
      },
    );
  }

  testWidgets(
    'missing catalog offer recovers directly into wallet before acknowledgement',
    (tester) async {
      final rewards = RecoveryRewards();
      final router = GoRouter(
        initialLocation: '/rewards',
        routes: [
          GoRoute(path: '/rewards', builder: (_, _) => const RewardsScreen()),
          GoRoute(
            path: '/wallet',
            builder: (_, _) => const Scaffold(body: Text('My rewards')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rewardsProvider.overrideWith((ref) => rewards),
            pointsProvider.overrideWith((ref) => RecoveryPoints()),
            walletProvider.overrideWith((ref) => RecoveryWallet()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Recover purchase'), findsOneWidget);
      await tester.ensureVisible(find.text('Recover purchase'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recover purchase'));
      await tester.pumpAndSettle();
      expect(find.text('My rewards'), findsOneWidget);
      expect(rewards.recovered, 1);
      expect(rewards.acknowledged, 1);
      expect(
        find.byType(RewardFireworks),
        findsNothing,
        reason: 'An old recovered purchase is not a new win',
      );
      expect(
        router.routeInformationProvider.value.uri.queryParameters['highlight'],
        'existing-voucher',
      );
      expect(
        router.routeInformationProvider.value.uri.queryParameters['recovered'],
        'true',
      );
    },
  );
}
