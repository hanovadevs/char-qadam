import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qadam/core/services/cache_service.dart';
import 'package:qadam/data/api/api_client.dart';
import 'package:qadam/data/auth/device_identity.dart';
import 'package:qadam/data/models/offer_models.dart';
import 'package:qadam/data/rewards/rewards_repository.dart';
import 'package:qadam/features/rewards/presentation/reward_card.dart';
import 'reward_recovery_test.dart' show NoToken;

const offerJson = {
  'id': 'one-reward',
  'partner_id': 'store',
  'title': 'Coffee on Stepsy',
  'discount_type': 'PERCENT',
  'discount_value': 20,
  'points_cost': 10,
  'status': 'ACTIVE',
  'inventory': 20,
};

class ClaimAdapter implements HttpClientAdapter {
  final started = Completer<void>();
  final oldCatalog = Completer<ResponseBody>();
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    if (options.method == 'GET') {
      if (!started.isCompleted) started.complete();
      return oldCatalog.future;
    }
    return ResponseBody.fromString(
      jsonEncode({
        'voucher_id': 'voucher',
        'short_code': 'SR-ABCD-EFGH',
        'token': 'token',
        'expires_at': '2027-01-01T00:00:00Z',
        'points_spent': 10,
        'balance': 90,
        'is_replay': false,
      }),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'claim survives an older catalog response, restart and offline cache',
    () async {
      final cache = CacheService(userId: 'alice');
      await cache.cacheData('offers_catalog', [offerJson]);
      final api = ApiClient(
        tokenStorage: NoToken(),
        deviceIdentity: DeviceIdentity(loader: () async => 'a' * 64),
      );
      final adapter = ClaimAdapter();
      api.dio.httpClientAdapter = adapter;
      addTearDown(api.dio.close);
      final repo = RewardsRepository(apiClient: api, cacheService: cache);
      final stale = repo.getOffers();
      await adapter.started.future;
      await repo.redeemOffer('one-reward', expectedPointsCost: 10);
      expect((await repo.getCachedOffers())!.single.alreadyRedeemed, isTrue);
      adapter.oldCatalog.complete(
        ResponseBody.fromString(
          jsonEncode([offerJson]),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      expect((await stale).single.alreadyRedeemed, isTrue);
      final restarted = RewardsRepository(apiClient: api, cacheService: cache);
      expect(
        (await restarted.getCachedOffers())!.single.alreadyRedeemed,
        isTrue,
      );
      expect(
        await RewardsRepository(
          apiClient: api,
          cacheService: CacheService(userId: 'bob'),
        ).getCachedOffers(),
        isNull,
      );
    },
  );

  testWidgets(
    'claimed card cannot purchase again even with sufficient points',
    (tester) async {
      var purchases = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RewardCard(
                offer: OfferModel.fromJson({
                  ...offerJson,
                  'already_redeemed': true,
                }),
                balance: 1000,
                onRedeem: () => purchases++,
              ),
            ),
          ),
        ),
      );
      final button = find.byKey(const ValueKey('redeem-one-reward'));
      expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
      expect(find.text('Claimed'), findsOneWidget);
      expect(find.text('Get reward'), findsNothing);
      await tester.ensureVisible(button);
      await tester.tap(button);
      expect(purchases, 0);
    },
  );
}
