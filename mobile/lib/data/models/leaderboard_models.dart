class LeaderboardEntryModel {
  final int rank;
  final String userId;
  final String displayName;
  final int totalSteps;
  final int pointsEarned;
  final String country;
  final bool isCurrentUser;

  const LeaderboardEntryModel({
    required this.rank,
    required this.userId,
    required this.displayName,
    required this.totalSteps,
    required this.pointsEarned,
    required this.country,
    required this.isCurrentUser,
  });

  factory LeaderboardEntryModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntryModel(
      rank: json['rank'] as int? ?? 0,
      userId: json['user_id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? 'Walker',
      totalSteps: json['total_steps'] as int? ?? 0,
      pointsEarned: json['points_earned'] as int? ?? 0,
      country: json['country'] as String? ?? 'PK',
      isCurrentUser: json['is_current_user'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rank': rank,
      'user_id': userId,
      'display_name': displayName,
      'total_steps': totalSteps,
      'points_earned': pointsEarned,
      'country': country,
      'is_current_user': isCurrentUser,
    };
  }
}

class UserRankingModel {
  final int rank;
  final int totalSteps;
  final int pointsEarned;
  final int totalParticipants;
  final double percentile;

  const UserRankingModel({
    required this.rank,
    required this.totalSteps,
    required this.pointsEarned,
    required this.totalParticipants,
    required this.percentile,
  });

  factory UserRankingModel.fromJson(Map<String, dynamic> json) {
    return UserRankingModel(
      rank: json['rank'] as int? ?? 0,
      totalSteps: json['total_steps'] as int? ?? 0,
      pointsEarned: json['points_earned'] as int? ?? 0,
      totalParticipants: json['total_participants'] as int? ?? 0,
      percentile: (json['percentile'] as num?)?.toDouble() ?? 100.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rank': rank,
      'total_steps': totalSteps,
      'points_earned': pointsEarned,
      'total_participants': totalParticipants,
      'percentile': percentile,
    };
  }
}

class LeaderboardResponseModel {
  final String scope;
  final int totalParticipants;
  final List<LeaderboardEntryModel> rankings;
  final UserRankingModel? userRanking;

  const LeaderboardResponseModel({
    required this.scope,
    required this.totalParticipants,
    required this.rankings,
    this.userRanking,
  });

  factory LeaderboardResponseModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardResponseModel(
      scope: json['scope'] as String? ?? 'week',
      totalParticipants: json['total_participants'] as int? ?? 0,
      rankings: (json['rankings'] as List<dynamic>?)
              ?.map((e) => LeaderboardEntryModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      userRanking: json['user_ranking'] != null
          ? UserRankingModel.fromJson(json['user_ranking'] as Map<String, dynamic>)
          : null,
    );
  }
}
