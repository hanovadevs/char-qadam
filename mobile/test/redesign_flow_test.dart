import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'package:qadam/features/companion/experience_provider.dart';
import 'package:qadam/features/companion/companion.dart';
import 'package:qadam/features/points/providers/points_provider.dart';
import 'package:qadam/features/rewards/providers/rewards_provider.dart';
import 'package:qadam/features/rewards/presentation/reward_card.dart';
import 'package:qadam/features/rewards/presentation/reward_fireworks.dart';
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
  PreviewActivity({ActivityState? snapshot})
    : super(
        snapshot ??
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
  void liveSteps(int steps, {bool? syncing}) {
    state = state.copyWith(
      todaySteps: steps,
      hasStepSnapshot: true,
      isSyncing: syncing,
    );
  }

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
  PreviewRewards({bool claimed = false})
    : super(
        RewardsState(
          offers: [claimed ? previewOffer.asClaimed() : previewOffer],
        ),
      );
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
  double height = 980,
  double textScale = 1,
  PreviewRewards? rewards,
  bool used = false,
  bool disableAnimations = true,
  String? initialPath,
  ActivityState? activity,
  bool settle = true,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => PreviewAuth()),
        onboardingCompleteProvider.overrideWith((ref) async => true),
        activityProvider.overrideWith(
          (ref) => PreviewActivity(snapshot: activity),
        ),
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
              disableAnimations: disableAnimations,
            ),
            child: RepaintBoundary(key: captureKey, child: child!),
          ),
        ),
      ),
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  if (initialPath != null) {
    await tester.pump();
    container.read(routerProvider).go(initialPath);
  }
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 200));
  }
  return container;
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
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'Home checks native tracking recovery before controls scroll into view',
    (tester) async {
      var recoveryChecks = 0;
      const channel = MethodChannel('stepsy/step_tracking');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'ensureTracking') recoveryChecks++;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await mountPreview(tester, initialPath: '/steps', height: 600);
      expect(recoveryChecks, greaterThan(0));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Pip guides a real offer through explicit confirmation to its QR',
    (tester) async {
      final rewards = PreviewRewards();
      await mountPreview(tester, initialPath: '/rewards', rewards: rewards);
      await reveal(tester, find.text('Help me choose'));
      await tester.tap(find.text('Help me choose'));
      await tester.pumpAndSettle();
      expect(find.text(previewOffer.description!), findsOneWidget);
      expect(rewards.purchases, 0);
      await reveal(tester, find.text('Redeem for 200 points'));
      await tester.tap(find.text('Redeem for 200 points'));
      await tester.pumpAndSettle();
      expect(find.text('Make it yours.'), findsOneWidget);
      expect(
        rewards.purchases,
        0,
        reason: 'The character cannot purchase without explicit confirmation',
      );
      await reveal(tester, find.text('Confirm & redeem'));
      await tester.tap(find.text('Confirm & redeem'));
      await tester.pumpAndSettle();
      expect(rewards.purchases, 1);
      expect(find.text('My rewards'), findsOneWidget);
      expect(
        find.text(
          'Your reward is right here! Tap Show QR when you’re at the store.',
        ),
        findsOneWidget,
      );
      await reveal(tester, find.text('Show QR'));
      await tester.tap(find.text('Show QR'));
      await tester.pumpAndSettle();
      expect(find.text(previewVoucher.shortCode), findsWidgets);
      expect(
        find.text(
          'At the store? Let the team scan this code or enter it below.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('Live steps and walking continue while points sync is delayed', (
    tester,
  ) async {
    final container = await mountPreview(
      tester,
      initialPath: '/steps',
      activity: const ActivityState(
        todaySteps: 100,
        serverSteps: 100,
        pointsEarnedToday: 1,
        hasStepSnapshot: true,
        hasPermission: true,
        lastSyncTime: '10:24 AM',
      ),
    );
    final activity =
        container.read(activityProvider.notifier) as PreviewActivity;
    activity.liveSteps(101, syncing: true);
    await tester.pump();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('settled-step-count')))
          .data,
      '101',
    );
    expect(find.text('1 device steps awaiting sync'), findsOneWidget);
    expect(container.read(activityProvider).pointsEarnedToday, 1);
    final walking = find.byWidgetPredicate(
      (w) => w is Companion && w.clip == 'walk',
    );
    expect(walking, findsOneWidget);
    final event = tester.widget<Companion>(walking).event;
    await tester.pump(const Duration(seconds: 2));
    activity.liveSteps(102, syncing: false);
    await tester.pump();
    expect(
      tester.widget<Companion>(walking).event,
      event,
      reason: 'A step extends the walk without restarting its cycle',
    );
    expect(tester.widget<Companion>(walking).repeat, isTrue);
    await tester.pump(const Duration(seconds: 2));
    expect(walking, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(walking, findsNothing, reason: 'Rest after movement stops');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'Claimed offer opens its existing voucher without a second purchase',
    (tester) async {
      final rewards = PreviewRewards(claimed: true);
      final container = await mountPreview(
        tester,
        rewards: rewards,
        initialPath: '/rewards',
      );
      await reveal(tester, find.text('View voucher'));
      await tester.tap(find.text('View voucher'));
      await tester.pumpAndSettle();
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        '/wallet',
      );
      expect(
        find.byKey(const ValueKey('voucher-preview-voucher')),
        findsOneWidget,
      );
      expect(find.text(previewVoucher.shortCode), findsNothing);
      expect(rewards.purchases, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'A reward goal saves to this account and View reward reopens its details',
    (tester) async {
      final container = await mountPreview(tester, initialPath: '/steps');
      await tester.tap(find.text('View reward'));
      await tester.pumpAndSettle();
      expect(find.text('Make this my walking goal'), findsOneWidget);
      await reveal(tester, find.text('Make this my walking goal'));
      await tester.tap(find.text('Make this my walking goal'));
      await tester.pumpAndSettle();
      expect(container.read(experienceProvider).rewardId, previewOffer.id);
      container.read(routerProvider).go('/steps');
      await tester.pumpAndSettle();
      expect(find.text('Your reward goal'), findsOneWidget);
      await tester.tap(find.text('View reward'));
      await tester.pumpAndSettle();
      expect(find.text('Make this my walking goal'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('Initial loading does not invent a zero count', (tester) async {
    await mountPreview(
      tester,
      width: 390,
      height: 844,
      initialPath: '/steps',
      activity: const ActivityState(isSyncing: true),
      settle: false,
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('settled-step-count')))
          .data,
      '—',
    );
    await capture(tester, 'blueprint-home-loading');
    await tester.pumpWidget(const SizedBox.shrink());
  });
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
  for (final width in [360.0, 390.0]) {
    testWidgets('Home reward action is visible at $width by 844', (
      tester,
    ) async {
      await mountPreview(
        tester,
        width: width,
        height: 844,
        initialPath: '/steps',
      );
      final action = tester.getRect(
        find.widgetWithText(ElevatedButton, 'View reward'),
      );
      final navigation = tester.getRect(find.byType(NavigationBar));
      expect(
        action.bottom,
        lessThanOrEqualTo(navigation.top),
        reason: 'The primary reward action should not require a scroll',
      );
      await capture(tester, 'blueprint-home-${width.toInt()}');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  final states = <String, ActivityState>{
    'zero': const ActivityState(
      settledSteps: 0,
      hasPermission: true,
      lastSyncTime: '10:24 AM',
    ),
    'denied': const ActivityState(
      settledSteps: 0,
      errorMessage: 'Motion access is off. Connect activity to start tracking.',
    ),
    'offline': const ActivityState(
      settledSteps: 3120,
      serverSteps: 3120,
      pointsEarnedToday: 31,
      hasPermission: true,
      lastSyncTime: '9:20 AM',
      errorMessage: 'You are offline. Showing your last successful sync.',
    ),
  };
  for (final entry in states.entries) {
    testWidgets('Home ${entry.key} state remains useful', (tester) async {
      await mountPreview(
        tester,
        width: 390,
        height: 844,
        initialPath: '/steps',
        activity: entry.value,
      );
      expect(tester.takeException(), isNull);
      await capture(tester, 'blueprint-home-${entry.key}');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
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
    final container = await mountPreview(tester, width: 320, textScale: 2);
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
    'Fresh purchase celebrates over Wallet without blocking its QR button',
    (tester) async {
      await mountPreview(
        tester,
        disableAnimations: false,
        initialPath: '/rewards',
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('redeem-preview-offer')));
      await tester.tap(find.byKey(const ValueKey('redeem-preview-offer')));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Confirm & redeem'));
      await tester.tap(find.text('Confirm & redeem'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(find.text('My rewards'), findsOneWidget);
      expect(find.byType(RewardFireworks), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 450));
      await capture(tester, 'reward-fireworks');
      await tester.tap(find.text('Show QR'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Your little win.'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(RewardFireworks), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
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
        find.byType(RewardFireworks),
        findsNothing,
        reason: 'Reduced motion keeps the success notice without fireworks',
      );
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
      await capture(tester, 'blueprint-redemption-error');
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
