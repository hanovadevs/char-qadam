import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qadam/core/theme/app_theme.dart';
import 'package:qadam/data/auth/auth_state_provider.dart';
import 'package:qadam/data/leaderboard/leaderboard_repository.dart';
import 'package:qadam/data/models/leaderboard_models.dart';
import 'package:qadam/features/leaderboard/presentation/leaderboard_screen.dart';
import 'package:qadam/features/leaderboard/providers/leaderboard_provider.dart';
import 'redesign_flow_test.dart' as fixtures;

LeaderboardResponseModel board(
  String scope, {
  bool empty = false,
  bool tied = false,
}) => LeaderboardResponseModel(
  scope: scope,
  totalParticipants: empty ? 0 : 120,
  rankings: empty
      ? []
      : List.generate(
          6,
          (i) => LeaderboardEntryModel(
            rank: tied && i == 1 ? 1 : i + 1,
            userId: 'fixture-$i',
            displayName: i == 3
                ? 'A very long fictional walking member name'
                : ['Ayesha', 'Hamza', 'Sara', 'Zain', 'Mina', 'Ali'][i],
            totalSteps: tied && i == 1 ? 29000 : 29000 - i * 2000,
            pointsEarned: 290 - i * 20,
            country: 'PK',
            isCurrentUser: i == 2,
          ),
        ),
  userRanking: empty
      ? null
      : const UserRankingModel(
          rank: 3,
          totalSteps: 25000,
          pointsEarned: 250,
          totalParticipants: 120,
          percentile: 2.5,
        ),
);

class BoardRepository implements LeaderboardRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  bool empty = false, tied = false, fail = false;
  final pending = <String, Completer<LeaderboardResponseModel>>{};
  final calls = <String>[];
  @override
  Future<LeaderboardResponseModel> getLeaderboard({
    String scope = 'week',
    int limit = 50,
  }) async {
    calls.add(scope);
    if (pending.containsKey(scope)) return pending[scope]!.future;
    if (fail) throw StateError('Fixture unavailable');
    return board(scope, empty: empty, tied: tied);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
    await (FontLoader(
      'Nunito',
    )..addFont(rootBundle.load('assets/fonts/Nunito.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  final captureKey = GlobalKey();
  Future<ProviderContainer> mount(
    WidgetTester tester,
    BoardRepository repo, {
    double width = 390,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => fixtures.PreviewAuth()),
          leaderboardRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: MediaQueryData(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: RepaintBoundary(
              key: captureKey,
              child: const LeaderboardScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(LeaderboardScreen)),
    );
  }

  testWidgets(
    'Achievement page uses real ranks, honest progress and an accessible scoring explanation',
    (tester) async {
      await mount(tester, BoardRepository());
      expect(find.text('#3'), findsOneWidget);
      expect(find.text('2,001 more synced steps to pass #2'), findsOneWidget);
      expect(find.text('The walking podium'), findsOneWidget);
      if (const bool.fromEnvironment('CAPTURE_UI')) {
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/companion/portraits/wave.png'),
            captureKey.currentContext!,
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary =
              captureKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1.5);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/ux-previews/leaderboard.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.byTooltip('How rankings work'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Tied step totals can share a rank.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'A tied podium preserves shared server ranks instead of inventing second place',
    (tester) async {
      await mount(tester, BoardRepository()..tied = true);
      expect(find.text('1'), findsNWidgets(2));
      expect(find.text('2'), findsNothing);
      expect(find.textContaining('more synced steps to pass'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Changing scope hides previous results and ignores a late response',
    (tester) async {
      final repo = BoardRepository();
      final delayed = Completer<LeaderboardResponseModel>();
      repo.pending['month'] = delayed;
      final container = await mount(tester, repo);
      await tester.tap(find.text('30 days'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Ayesha'), findsNothing);
      expect(find.text('#3'), findsNothing);
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      delayed.complete(board('month'));
      await tester.pumpAndSettle();
      expect(container.read(leaderboardProvider).selectedScope, 'today');
      expect(container.read(leaderboardProvider).data?.scope, 'today');
      expect(find.text('Ayesha'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Refresh failure keeps same-period results and exposes retry', (
    tester,
  ) async {
    final repo = BoardRepository();
    await mount(tester, repo);
    repo.fail = true;
    await tester.tap(find.byTooltip('Refresh leaderboard'));
    await tester.pumpAndSettle();
    expect(
      find.text('Couldn’t refresh. Showing the last loaded ranking.'),
      findsOneWidget,
    );
    expect(find.text('Ayesha'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(
      find.text('Couldn’t refresh. Showing the last loaded ranking.'),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Empty leaderboard invites a first walk without displaying fake achievements',
    (tester) async {
      await mount(tester, BoardRepository()..empty = true);
      expect(find.text('The trail is open.'), findsOneWidget);
      expect(
        find.text('Your place is waiting. Sync your next walk to join in.'),
        findsOneWidget,
      );
      expect(find.textContaining('Top '), findsNothing);
      expect(find.text('#1'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets('Leaderboard fits 320px at scale $scale including long names', (
      tester,
    ) async {
      await mount(tester, BoardRepository(), width: 320, scale: scale);
      await tester.scrollUntilVisible(
        find.text('A very long fictional walking member name'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
