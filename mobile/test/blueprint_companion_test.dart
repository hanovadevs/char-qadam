import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qadam/core/theme/app_theme.dart';
import 'package:qadam/features/companion/experience_provider.dart';
import 'package:qadam/features/companion/companion.dart';
import 'package:qadam/features/activity/presentation/companion_goal_meter.dart';
import 'package:qadam/features/rewards/reward_goal.dart';
import 'package:qadam/data/models/offer_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'Walking playback survives rebuilds and stops when its slot is hidden',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          experienceProvider.overrideWith((ref) => ExperienceNotifier(null)),
        ],
      );
      addTearDown(container.dispose);
      Future<void> show({double scale = 1, bool visible = true}) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: TickerMode(
                  enabled: visible,
                  child: const Companion(clip: 'walk', repeat: true, event: 1),
                ),
              ),
            ),
          ),
        );
      }

      await show();
      final animated = find.descendant(
        of: find.byType(Companion),
        matching: find.byType(AnimatedBuilder),
      );
      for (var i = 0; i < 30 && animated.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(animated, findsOneWidget);
      final controller =
          tester.widget<AnimatedBuilder>(animated).animation
              as AnimationController;
      await tester.pump(const Duration(milliseconds: 400));
      final before = controller.value;
      await show(scale: 1.1);
      expect(
        controller.value,
        closeTo(before, .001),
        reason: 'An inherited widget rebuild must not restart the clip',
      );
      await tester.pump(const Duration(seconds: 2));
      expect(controller.isAnimating, isTrue);
      await show(visible: false);
      expect(controller.isAnimating, isFalse);
      expect(animated, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Opening, corrections and goal changes never replay a completion',
    (tester) async {
      final prefs = ExperienceNotifier('completion-user');
      await prefs.ready;
      final container = ProviderContainer(
        overrides: [experienceProvider.overrideWith((ref) => prefs)],
      );
      addTearDown(container.dispose);
      Future<void> show(
        int steps, {
        bool known = true,
        int goal = 8000,
        String day = '2026-10-19',
      }) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(disableAnimations: true),
                child: Scaffold(
                  body: CompanionGoalMeter(
                    steps: steps,
                    goal: goal,
                    day: day,
                    known: known,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(0, known: false);
      await show(8000);
      expect(tester.widget<Companion>(find.byType(Companion)).clip, 'rest');
      await show(7900);
      await show(8000);
      expect(tester.widget<Companion>(find.byType(Companion)).clip, 'cheer');
      expect(prefs.state.celebratedEvent, '2026-10-19:8000');
      await show(7900);
      await show(8000);
      expect(tester.widget<Companion>(find.byType(Companion)).clip, 'walk');
      await show(8000, goal: 7000);
      expect(tester.widget<Companion>(find.byType(Companion)).clip, 'rest');
      await show(0, day: '2026-10-20');
      await show(8000, day: '2026-10-20');
      expect(prefs.state.celebratedEvent, '2026-10-20:8000');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test(
    'Goals, companion controls and reward selection persist separately for each account',
    () async {
      final first = ExperienceNotifier('account-one');
      await first.ready;
      await Future.wait([
        first.update(goal: 10000),
        first.update(animations: false),
        first.update(rewardId: 'reward-one'),
      ]);
      final second = ExperienceNotifier('account-two');
      await second.ready;
      expect(second.state.goal, 8000);
      expect(second.state.rewardId, isNull);
      final restored = ExperienceNotifier('account-one');
      await restored.ready;
      expect(restored.state.goal, 10000);
      expect(restored.state.animations, isFalse);
      expect(restored.state.rewardId, 'reward-one');
      await restored.update(goal: 0);
      expect(restored.state.goal, 10000);
      first.dispose();
      second.dispose();
      restored.dispose();
    },
  );
  test(
    'Unavailable, claimed and expired rewards cannot become walking goals',
    () {
      OfferModel offer({
        bool claimed = false,
        int inventory = 1,
        DateTime? end,
      }) => OfferModel(
        id: 'o',
        partnerId: 'p',
        title: 'Fixture',
        discountType: 'PERCENT',
        discountValue: 20,
        pointsCost: 100,
        status: 'ACTIVE',
        alreadyRedeemed: claimed,
        inventory: inventory,
        endsAt: end,
      );
      expect(eligibleReward(offer()), isTrue);
      expect(eligibleReward(offer(claimed: true)), isFalse);
      expect(eligibleReward(offer(inventory: 0)), isFalse);
      expect(eligibleReward(offer(end: DateTime(2020))), isFalse);
      expect(suggestedReward([offer(inventory: 0)], 50), isNull);
    },
  );
  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    for (final steps in [0, 80, 4000, 7920, 8000, 9600]) {
      testWidgets(
        'Accurate meter and visible companion at $steps steps / $width width',
        (tester) async {
          tester.view.physicalSize = Size(width, 850);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                experienceProvider.overrideWith(
                  (ref) => ExperienceNotifier(null),
                ),
              ],
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 850),
                    disableAnimations: true,
                    textScaler: TextScaler.linear(2),
                  ),
                  child: Scaffold(
                    body: Padding(
                      padding: const EdgeInsets.all(20),
                      child: CompanionGoalMeter(
                        steps: steps,
                        goal: 8000,
                        day: '2026-10-19',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<LinearProgressIndicator>(
                  find.byKey(const ValueKey('daily-goal-fill')),
                )
                .value,
            (steps / 8000).clamp(0.0, 1.0),
          );
          final bounds = tester.getRect(find.byType(Companion));
          expect(bounds.left, greaterThanOrEqualTo(20));
          expect(bounds.right, lessThanOrEqualTo(width - 20));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
