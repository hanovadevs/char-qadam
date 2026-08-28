class SyncResponse {
  final String localDate;
  final int eligibleSteps;
  final int pointsAwarded;
  final int balance;
  final bool isReplay;

  SyncResponse({
    required this.localDate,
    required this.eligibleSteps,
    required this.pointsAwarded,
    required this.balance,
    required this.isReplay,
  });

  factory SyncResponse.fromJson(Map<String, dynamic> json) {
    return SyncResponse(
      localDate: json['local_date'] as String,
      eligibleSteps: json['eligible_steps'] as int,
      pointsAwarded: json['points_awarded'] as int,
      balance: json['balance'] as int,
      isReplay: json['is_replay'] as bool,
    );
  }
}

class ActivityPeriodModel {
  final String date;
  final int eligibleSteps;
  final String? source;

  ActivityPeriodModel({
    required this.date,
    required this.eligibleSteps,
    this.source,
  });

  factory ActivityPeriodModel.fromJson(Map<String, dynamic> json) {
    return ActivityPeriodModel(
      date: json['date'] as String,
      eligibleSteps: json['eligible_steps'] as int,
      source: json['source'] as String?,
    );
  }

  /// Human-readable label for the step data source
  String get sourceLabel {
    switch (source) {
      case 'health':
        return 'HEALTH';
      case 'manual_debug':
        return 'MANUAL';
      case 'background_workmanager':
        return 'BG SYNC';
      default:
        return source?.toUpperCase() ?? 'DEVICE';
    }
  }
}

class ActivityRangeModel {
  final String range;
  final int totalSteps;
  final List<ActivityPeriodModel> days;

  ActivityRangeModel({
    required this.range,
    required this.totalSteps,
    required this.days,
  });

  factory ActivityRangeModel.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'] as List<dynamic>? ?? [];
    return ActivityRangeModel(
      range: json['range'] as String,
      totalSteps: json['total_steps'] as int,
      days: rawDays
          .map((e) => ActivityPeriodModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
