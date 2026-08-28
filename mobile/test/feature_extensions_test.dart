import 'package:flutter_test/flutter_test.dart';
import 'package:qadam/data/models/activity_models.dart';
import 'package:qadam/features/onboarding/presentation/onboarding_screen.dart';
import 'package:qadam/features/points/providers/points_provider.dart';

void main() {
  group('Step Source Attribution Tests', () {
    test('ActivityPeriodModel parses source and returns appropriate label', () {
      final healthItem = ActivityPeriodModel.fromJson({
        'date': '2026-08-28',
        'eligible_steps': 7500,
        'source': 'health',
      });
      expect(healthItem.source, equals('health'));
      expect(healthItem.sourceLabel, equals('HEALTH'));

      final manualItem = ActivityPeriodModel.fromJson({
        'date': '2026-08-27',
        'eligible_steps': 5000,
        'source': 'manual_debug',
      });
      expect(manualItem.source, equals('manual_debug'));
      expect(manualItem.sourceLabel, equals('MANUAL'));

      final bgItem = ActivityPeriodModel.fromJson({
        'date': '2026-08-26',
        'eligible_steps': 3000,
        'source': 'background_workmanager',
      });
      expect(bgItem.source, equals('background_workmanager'));
      expect(bgItem.sourceLabel, equals('BG SYNC'));

      final defaultItem = ActivityPeriodModel.fromJson({
        'date': '2026-08-25',
        'eligible_steps': 1000,
      });
      expect(defaultItem.source, isNull);
      expect(defaultItem.sourceLabel, equals('DEVICE'));
    });
  });

  group('Pagination State Tests', () {
    test('PointsState initializes with default pagination parameters', () {
      const state = PointsState();
      expect(state.offset, equals(0));
      expect(state.total, equals(0));
      expect(state.hasMore, isTrue);
      expect(state.isLoadingMore, isFalse);
      expect(PointsState.pageSize, equals(20));
    });

    test('PointsState copyWith updates pagination fields accurately', () {
      const state = PointsState();
      final updated = state.copyWith(
        offset: 20,
        total: 45,
        hasMore: true,
        isLoadingMore: true,
      );

      expect(updated.offset, equals(20));
      expect(updated.total, equals(45));
      expect(updated.hasMore, isTrue);
      expect(updated.isLoadingMore, isTrue);
    });
  });

  group('Onboarding & Deep Link Tests', () {
    test('Onboarding storage key is defined correctly', () {
      expect(onboardingCompleteKey, equals('qadam_onboarding_complete'));
    });
  });
}
