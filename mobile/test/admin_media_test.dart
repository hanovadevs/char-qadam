import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qadam/core/theme/app_theme.dart';
import 'package:qadam/data/models/offer_models.dart';
import 'package:qadam/data/models/voucher_models.dart';
import 'package:qadam/data/wallet/wallet_repository.dart';
import 'package:qadam/features/rewards/presentation/reward_card.dart';
import 'package:qadam/features/wallet/presentation/wallet_screen.dart';
import 'package:qadam/features/wallet/providers/wallet_provider.dart';

OfferModel coveredOffer() => OfferModel.fromJson({
  'id': 'cover-offer',
  'partner_id': 'cover-store',
  'partner_name': 'Fixture café',
  'partner_cover_image_url': 'https://example.com/cover.webp',
  'partner_google_maps_url': 'https://maps.app.goo.gl/fixture',
  'title': 'Coffee reward',
  'discount_type': 'PERCENT',
  'discount_value': 20,
  'points_cost': 10,
  'status': 'ACTIVE',
});

class CancelledWallet implements WalletRepository {
  final requests = <String>[];
  @override
  Future<List<VoucherModel>?> getCachedVouchers(String status) async => null;
  @override
  Future<List<VoucherModel>> getVouchers({String status = 'active'}) async {
    requests.add(status);
    return status == 'cancelled'
        ? [
            VoucherModel(
              id: 'cancelled-voucher',
              offerId: 'cover-offer',
              shortCode: 'FIXTURE',
              status: 'CANCELLED',
              issuedAt: DateTime.now(),
              expiresAt: DateTime.now().add(const Duration(days: 7)),
              offerTitle: 'Cancelled coffee',
              offerDiscountType: 'PERCENT',
              offerDiscountValue: 20,
            ),
          ]
        : [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('Claiming retains the admin cover and Maps destination', () {
    final offer = coveredOffer();
    final claimed = offer.asClaimed();
    expect(claimed.partnerCoverImageUrl, offer.partnerCoverImageUrl);
    expect(claimed.partnerGoogleMapsUrl, offer.partnerGoogleMapsUrl);
    expect(claimed.alreadyRedeemed, isTrue);
  });

  testWidgets('Unavailable cover keeps its space and reward usable', (
    tester,
  ) async {
    var purchases = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: RewardCard(
              offer: coveredOffer(),
              balance: 20,
              onRedeem: () => purchases++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('cover-cover-offer'))),
      const Size(82, 108),
    );
    expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);
    final button = find.byKey(const ValueKey('redeem-cover-offer'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    expect(purchases, 1);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 414.0]) {
    testWidgets('Recovered cancelled voucher stays visible at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = CancelledWallet();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [walletRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const WalletScreen(
              highlightId: 'cancelled-voucher',
              recovered: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(WalletScreen)),
      );
      expect(container.read(walletProvider).selectedStatus, 'cancelled');
      expect(
        repository.requests,
        containsAllInOrder(['active', 'redeemed', 'expired', 'cancelled']),
      );
      expect(find.text('Cancelled coffee'), findsOneWidget);
      expect(find.text('Show QR'), findsNothing);
      expect(
        find.text('Expired'),
        findsOneWidget,
      ); // Filter only, not the voucher's status.
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
