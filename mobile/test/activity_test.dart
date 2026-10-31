import 'package:flutter_test/flutter_test.dart';
import 'package:qadam/data/models/activity_models.dart';

void main() {
  group('Activity Models Tests', () {
    test('SyncResponse.fromJson parses POST /activity/sync payload correctly', () {
      final json = {
        'local_date': '2026-08-15',
        'eligible_steps': 10000,
        'points_awarded': 100,
        'balance': 250,
        'is_replay': false,
      };

      final response = SyncResponse.fromJson(json);

      expect(response.localDate, equals('2026-08-15'));
      expect(response.eligibleSteps, equals(10000));
      expect(response.pointsAwarded, equals(100));
      expect(response.balance, equals(250));
      expect(response.isReplay, isFalse);
    });

    test('ActivityRangeModel.fromJson parses GET /activity payload correctly', () {
      final json = {
        'range': 'week',
        'total_steps': 25000,
        'days': [
          {'date': '2026-08-14', 'eligible_steps': 10000},
          {'date': '2026-08-15', 'eligible_steps': 15000},
        ],
      };

      final rangeModel = ActivityRangeModel.fromJson(json);

      expect(rangeModel.range, equals('week'));
      expect(rangeModel.totalSteps, equals(25000));
      expect(rangeModel.days.length, equals(2));
      expect(rangeModel.days[0].date, equals('2026-08-14'));
      expect(rangeModel.days[0].eligibleSteps, equals(10000));
    });

    test('ActivityRangeModel.fromJson parses extended ranges (month, 3months, year)', () {
      for (final r in ['month', '3months', '6months', 'year', 'all']) {
        final json = {
          'range': r,
          'total_steps': 120000,
          'days': [
            {'date': '2026-07-01', 'eligible_steps': 8000},
            {'date': '2026-07-02', 'eligible_steps': 9500},
          ],
        };

        final rangeModel = ActivityRangeModel.fromJson(json);
        expect(rangeModel.range, equals(r));
        expect(rangeModel.totalSteps, equals(120000));
        expect(rangeModel.days.length, equals(2));
      }
    });
  });
}
