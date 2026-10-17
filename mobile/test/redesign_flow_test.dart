import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qadam/core/services/store_location.dart';
import 'package:qadam/core/theme/app_theme.dart';
import 'package:qadam/data/activity/activity_repository.dart';
import 'package:qadam/data/auth/auth_state_provider.dart';
import 'package:qadam/data/models/activity_models.dart';
import 'package:qadam/data/models/offer_models.dart';
import 'package:qadam/data/models/points_models.dart';
import 'package:qadam/data/models/user_model.dart';
import 'package:qadam/data/models/voucher_models.dart';
import 'package:qadam/data/wallet/wallet_repository.dart';
import 'package:qadam/features/activity/providers/activity_provider.dart';
import 'package:qadam/features/points/providers/points_provider.dart';
import 'package:qadam/features/rewards/providers/rewards_provider.dart';
import 'package:qadam/features/rewards/presentation/reward_card.dart';
import 'package:qadam/features/wallet/providers/wallet_provider.dart';
import 'package:qadam/routing/app_router.dart';

// Fictional preview fixtures. No production identities, offers or reward claims.
final previewOffer = OfferModel(
  id: 'preview-offer',
  partnerId: 'preview-brand',
  partnerName: 'Preview Café',
  partnerLocation: 'Gulberg, Lahore',
  partnerGoogleMapsUrl: 'https://maps.app.goo.gl/PreviewBranch',
  title: 'A good coffee, on a good day.',
  description: 'Use your voucher on any coffee at the partner branch.',
  discountType: 'PERCENT',
  discountValue: 20,
  pointsCost: 200,
  inventory: 50,
  status: 'ACTIVE',
);
final previewVoucher = VoucherModel(
  id: 'preview-voucher',
  offerId: previewOffer.id,
  shortCode: 'SR-DEMO-PASS',
  status: 'ISSUED',
  issuedAt: DateTime.now(),
  expiresAt: DateTime.now().add(const Duration(days: 15)),
  offerTitle: previewOffer.title,
  offerDiscountType: 'PERCENT',
  offerDiscountValue: 20,
);

class PreviewActivity extends StateNotifier<ActivityState>
    implements ActivityNotifier {
  PreviewActivity()
    : super(
        const ActivityState(
          todaySteps: 7240,
          serverSteps: 7240,
          pointsEarnedToday: 72,
          currentStreakDays: 4,
          hasPermission: true,
          lastSyncTime: '10:24 AM',
        ),
      );
  @override
  Future<void> initAndSync({bool force = false}) async {}
  @override
  Future<void> loadHistory(String range) async {
    state = state.copyWith(selectedRange: range);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PreviewPoints extends StateNotifier<PointsState>
    implements PointsNotifier {
  PreviewPoints()
    : super(
        PointsState(
          balanceData: BalanceModel(
            balance: 650,
            totalEarned: 850,
            totalSpent: 200,
          ),
          hasMore: false,
          entries: [
            LedgerEntryModel(
              id: 'preview-entry',
              delta: 72,
              reason: 'STEP_EARN',
              createdAt: DateTime.now(),
            ),
          ],
        ),
      );
  @override
  Future<void> refresh() async {}
  @override
  Future<void> loadMore() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PreviewRewards extends StateNotifier<RewardsState>
    implements RewardsNotifier {
  int purchases = 0, acknowledgements = 0;
  bool fail = false;
  PreviewRewards() : super(RewardsState(offers: [previewOffer]));
  @override
  Future<void> fetchOffers() async {}
  @override
  Future<RedeemResultModel?> redeem(String id) async {
    purchases++;
    if (fail) {
      state = state.copyWith(errorMessage: 'The reward is unavailable.');
      return null;
    }
    return RedeemResultModel(
      voucherId: previewVoucher.id,
      shortCode: previewVoucher.shortCode,
      token: 'preview-token',
      expiresAt: previewVoucher.expiresAt,
      pointsSpent: 200,
      balance: 450,
      requestKey: 'preview-purchase',
    );
  }

  @override
  Future<void> acknowledgePurchase(String id, String? key) async {
    acknowledgements++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PreviewWalletRepository implements WalletRepository {
  final bool used;
  PreviewWalletRepository({this.used = false});
  @override
  Future<List<VoucherModel>> getVouchers({String status = 'active'}) async =>
      status == (used ? 'redeemed' : 'active')
      ? [
          used
              ? VoucherModel(
                  id: previewVoucher.id,
                  offerId: previewOffer.id,
                  shortCode: previewVoucher.shortCode,
                  status: 'REDEEMED',
                  issuedAt: previewVoucher.issuedAt,
                  expiresAt: previewVoucher.expiresAt,
                  redeemedAt: DateTime.now(),
                  offerTitle: previewOffer.title,
                  offerDiscountType: 'PERCENT',
                  offerDiscountValue: 20,
                )
              : previewVoucher,
        ]
      : [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PreviewAuth extends StateNotifier<AuthState> implements AuthNotifier {
  PreviewAuth()
    : super(
        AuthState(
          status: AuthStatus.authenticated,
          googleName: 'Ayesha',
          user: UserModel(
            id: 'preview-user',
            email: 'preview@example.com',
            status: 'ACTIVE',
            country: 'PK',
            timezone: 'Asia/Karachi',
            createdAt: DateTime(2026, 9),
          ),
        ),
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PreviewHistory implements ActivityRepository {
  @override
  Future<ActivityRangeModel> getActivityHistory({
    String range = 'today',
  }) async => ActivityRangeModel(
    range: range,
    totalSteps: 35000,
    days: List.generate(7, (i) {
      final d = DateTime.now().subtract(Duration(days: i));
      return ActivityPeriodModel(
        date:
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
        eligibleSteps: 7240 - i * 600,
      );
    }),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final captureKey = GlobalKey();
Future<ProviderContainer> mountPreview(
  WidgetTester tester, {
  double width = 390,
  double textScale = 1,
  PreviewRewards? rewards,
  bool used = false,
}) async {
  tester.view.physicalSize = Size(width, 980);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => PreviewAuth()),
        onboardingCompleteProvider.overrideWith((ref) async => true),
        activityProvider.overrideWith((ref) => PreviewActivity()),
        pointsProvider.overrideWith((ref) => PreviewPoints()),
        rewardsProvider.overrideWith((ref) => rewards ?? PreviewRewards()),
        walletRepositoryProvider.overrideWithValue(
          PreviewWalletRepository(used: used),
        ),
        activityRepositoryProvider.overrideWithValue(PreviewHistory()),
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: ref.watch(routerProvider),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: true,
            ),
            child: RepaintBoundary(key: captureKey, child: child!),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find.byType(Scrollable).first,
    );
  } else {
    await tester.ensureVisible(finder);
  }
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_UI')) return;
  final boundary =
      captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('../artifacts/redesign/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final family in ['Manrope', 'SpaceGrotesk']) {
      final loader = FontLoader(family)
        ..addFont(rootBundle.load('assets/fonts/$family.ttf'));
      await loader.load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
  });
  for (final width in [320.0, 375.0, 414.0, 768.0]) {
    testWidgets(
      'Main screens fit ${width.toInt()}px with real bundled typography',
      (tester) async {
        final container = await mountPreview(tester, width: width);
        final router = container.read(routerProvider);
        for (final path in [
          '/steps',
          '/points',
          '/rewards',
          '/wallet',
          '/profile',
          '/progress',
        ]) {
          router.go(path);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$path at $width');
          if (width == 414) await capture(tester, path.substring(1));
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('Main screens and confirmation support larger text', (
    tester,
  ) async {
    final container = await mountPreview(tester, width: 320, textScale: 1.6);
    final router = container.read(routerProvider);
    for (final path in [
      '/steps',
      '/points',
      '/rewards',
      '/wallet',
      '/profile',
      '/progress',
    ]) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$path with large text');
    }
    router.go('/rewards');
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const ValueKey('redeem-preview-offer')));
    await tester.tap(find.byKey(const ValueKey('redeem-preview-offer')));
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'Confirmation with large text',
    );
    await reveal(tester, find.text('Confirm & redeem'));
    await tester.tap(find.text('Confirm & redeem'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Show QR'));
    await tester.tap(find.text('Show QR'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'QR with large text');
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'Confirmed reward goes directly to highlighted wallet and opens QR',
    (tester) async {
      final rewards = PreviewRewards();
      final container = await mountPreview(tester, rewards: rewards);
      container.read(routerProvider).go('/rewards');
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('redeem-preview-offer')));
      await tester.tap(find.byKey(const ValueKey('redeem-preview-offer')));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Confirm & redeem'));
      await tester.tap(find.text('Confirm & redeem'));
      await tester.pumpAndSettle();
      expect(find.text('My rewards'), findsOneWidget);
      expect(find.text('Reward unlocked. It’s right here.'), findsOneWidget);
      expect(rewards.purchases, 1);
      expect(rewards.acknowledgements, 1);
      expect(
        container
            .read(routerProvider)
            .routeInformationProvider
            .value
            .uri
            .queryParameters['highlight'],
        previewVoucher.id,
      );
      await reveal(tester, find.text('Show QR'));
      await tester.tap(find.text('Show QR'));
      await tester.pumpAndSettle();
      expect(find.text('Your little win.'), findsOneWidget);
      expect(find.text(previewVoucher.shortCode), findsWidgets);
      expect(tester.takeException(), isNull);
      await capture(tester, 'voucher-qr');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Failed redemption stays in catalog and does not acknowledge purchase',
    (tester) async {
      final rewards = PreviewRewards()..fail = true;
      final container = await mountPreview(tester, rewards: rewards);
      container.read(routerProvider).go('/rewards');
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('redeem-preview-offer')));
      await tester.tap(find.byKey(const ValueKey('redeem-preview-offer')));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Confirm & redeem'));
      await tester.tap(find.text('Confirm & redeem'));
      await tester.pumpAndSettle();
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        '/rewards',
      );
      expect(rewards.acknowledgements, 0);
      expect(find.text('The reward is unavailable.'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Recovered used voucher is located in Used rather than disappearing',
    (tester) async {
      final container = await mountPreview(tester, used: true);
      container
          .read(routerProvider)
          .go('/wallet?highlight=preview-voucher&recovered=true');
      await tester.pumpAndSettle();
      expect(container.read(walletProvider).selectedStatus, 'redeemed');
      expect(
        find.byKey(const ValueKey('voucher-preview-voucher')),
        findsOneWidget,
      );
      expect(find.text('Show QR'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Reward map button uses admin destination independently of affordability',
    (tester) async {
      Uri? opened;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: RewardCard(
                offer: previewOffer,
                balance: 0,
                onRedeem: () => fail('unaffordable'),
                onOpenLocation: (uri) => opened = uri,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('maps-preview-offer')));
      expect(opened.toString(), previewOffer.partnerGoogleMapsUrl);
      expect(find.text('200 more to unlock'), findsOneWidget);
    },
  );
  test('Maps address fallback is encoded and unsafe links never launch', () {
    expect(storeLocationUri(mapsUrl: 'javascript:alert(1)'), isNull);
    expect(
      storeLocationUri(mapsUrl: 'https://google.com.evil.example/maps'),
      isNull,
    );
    final uri = storeLocationUri(
      mapsUrl: 'https://evil.example',
      name: 'Tea & Co',
      address: 'Lahore #2',
    );
    expect(uri!.host, 'www.google.com');
    expect(uri.queryParameters['api'], '1');
    expect(uri.queryParameters['query'], 'Tea & Co, Lahore #2');
    expect(
      storeLocationUri(mapsUrl: 'https://maps.google.com:443/maps'),
      isNull,
    );
    expect(storeLocationUri(address: '  '), isNull);
  });
}
