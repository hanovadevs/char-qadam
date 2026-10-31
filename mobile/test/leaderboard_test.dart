import 'package:flutter_test/flutter_test.dart';
import 'package:qadam/data/models/leaderboard_models.dart';

void main() {
  group('Leaderboard Models Tests', () {
    test('LeaderboardResponseModel.fromJson parses complete payload correctly', () {
      final json = {
        'scope': 'week',
        'total_participants': 120,
        'rankings': [
          {
            'rank': 1,
            'user_id': 'user-uuid-1',
            'display_name': 'ath****@gmail.com',
            'total_steps': 85000,
            'points_earned': 850,
            'country': 'PK',
            'is_current_user': false,
          },
          {
            'rank': 2,
            'user_id': 'user-uuid-2',
            'display_name': 'run****@gmail.com',
            'total_steps': 72000,
            'points_earned': 720,
            'country': 'PK',
            'is_current_user': true,
          },
        ],
        'user_ranking': {
          'rank': 2,
          'total_steps': 72000,
          'points_earned': 720,
          'total_participants': 120,
          'percentile': 1.7,
        },
      };

      final response = LeaderboardResponseModel.fromJson(json);

      expect(response.scope, equals('week'));
      expect(response.totalParticipants, equals(120));
      expect(response.rankings.length, equals(2));

      final first = response.rankings[0];
      expect(first.rank, equals(1));
      expect(first.displayName, equals('ath****@gmail.com'));
      expect(first.totalSteps, equals(85000));
      expect(first.isCurrentUser, isFalse);

      final second = response.rankings[1];
      expect(second.rank, equals(2));
      expect(second.isCurrentUser, isTrue);

      final userRanking = response.userRanking;
      expect(userRanking, isNotNull);
      expect(userRanking!.rank, equals(2));
      expect(userRanking.percentile, equals(1.7));
    });
  });
}
