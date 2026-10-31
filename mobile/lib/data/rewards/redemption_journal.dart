import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Save the purchase ID before sending; retain it until the result is displayed.
class PendingPurchase {
  final String requestKey;
  final int expectedPointsCost;
  const PendingPurchase(this.requestKey, this.expectedPointsCost);
  Map<String, dynamic> toJson() => {
    'key': requestKey,
    'cost': expectedPointsCost,
  };
}

class RedemptionJournal {
  final String? userId;
  RedemptionJournal({required this.userId});
  static Future<void> _writes = Future.value();
  String get _key => 'stepsy_reward_requests_$userId';

  Future<T> _locked<T>(Future<T> Function() action) {
    final result = _writes.then((_) => action());
    _writes = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  Map<String, PendingPurchase> _read(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    dynamic data;
    try {
      data = jsonDecode(raw);
    } on FormatException {
      throw StateError(
        'Saved purchase recovery is unavailable. Check your wallet before buying again.',
      );
    }
    if (data is! Map ||
        data.entries.any(
          (e) =>
              e.key is! String ||
              e.value is! Map ||
              e.value['key'] is! String ||
              (e.value['key'] as String).isEmpty ||
              e.value['cost'] is! int ||
              (e.value['cost'] as int) < 0,
        )) {
      throw StateError(
        'Saved purchase recovery is unavailable. Check your wallet before buying again.',
      );
    }
    return data.map(
      (key, value) => MapEntry(
        key as String,
        PendingPurchase(value['key'] as String, value['cost'] as int),
      ),
    );
  }

  Future<Map<String, PendingPurchase>> pending() => _locked(() async {
    if (userId == null) return {};
    return _read(await SharedPreferences.getInstance());
  });

  Future<PendingPurchase> getOrCreate(
    String offerId, {
    int? expectedPointsCost,
  }) => _locked(() async {
    if (userId == null) throw StateError('Sign in before redeeming a reward.');
    final prefs = await SharedPreferences.getInstance();
    final data = _read(prefs);
    if (data.containsKey(offerId)) return data[offerId]!;
    if (expectedPointsCost == null || expectedPointsCost < 0) {
      throw StateError('Open the offer and confirm its points cost first.');
    }
    final requestId = PendingPurchase(const Uuid().v4(), expectedPointsCost);
    data[offerId] = requestId;
    if (!await prefs.setString(_key, jsonEncode(data))) {
      throw StateError(
        'Could not save this purchase safely. Please try again.',
      );
    }
    return requestId;
  });

  Future<void> acknowledge(
    String offerId,
    String requestId,
  ) => _locked(() async {
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final data = _read(prefs);
    if (data[offerId]?.requestKey != requestId) return;
    data.remove(offerId);
    if (!await prefs.setString(_key, jsonEncode(data))) {
      throw StateError(
        'Purchase recovery could not be cleared. Your voucher is in your wallet.',
      );
    }
  });
}
