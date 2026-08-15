class BalanceModel {
  final int balance;
  final int totalEarned;
  final int totalSpent;

  BalanceModel({
    required this.balance,
    required this.totalEarned,
    required this.totalSpent,
  });

  factory BalanceModel.fromJson(Map<String, dynamic> json) {
    return BalanceModel(
      balance: json['balance'] as int,
      totalEarned: json['total_earned'] as int,
      totalSpent: json['total_spent'] as int,
    );
  }
}

class LedgerEntryModel {
  final String id;
  final int delta;
  final String reason;
  final String? refType;
  final String? refId;
  final DateTime createdAt;

  LedgerEntryModel({
    required this.id,
    required this.delta,
    required this.reason,
    this.refType,
    this.refId,
    required this.createdAt,
  });

  factory LedgerEntryModel.fromJson(Map<String, dynamic> json) {
    return LedgerEntryModel(
      id: json['id'] as String,
      delta: json['delta'] as int,
      reason: json['reason'] as String,
      refType: json['ref_type'] as String?,
      refId: json['ref_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class LedgerPageModel {
  final int total;
  final int limit;
  final int offset;
  final List<LedgerEntryModel> entries;

  LedgerPageModel({
    required this.total,
    required this.limit,
    required this.offset,
    required this.entries,
  });

  factory LedgerPageModel.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'] as List<dynamic>? ?? [];
    return LedgerPageModel(
      total: json['total'] as int,
      limit: json['limit'] as int,
      offset: json['offset'] as int,
      entries: rawEntries
          .map((e) => LedgerEntryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
