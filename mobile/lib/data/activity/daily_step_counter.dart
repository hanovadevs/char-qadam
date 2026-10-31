import 'dart:math';
import 'package:intl/intl.dart';

/// Persistent cumulative sensor deltas for the iOS motion fallback.
class DailyStepCounter {
  String date = '';
  int steps = 0;
  int? _raw;
  DateTime? _lastAt;

  void record(int raw, DateTime at) {
    if (raw < 0 || (_lastAt != null && at.isBefore(_lastAt!))) return;
    final day = DateFormat('yyyy-MM-dd').format(at);
    final sameDay = date == day;
    final nearMidnight =
        _lastAt != null &&
        at.difference(_lastAt!) <= const Duration(minutes: 2);
    if (!sameDay) steps = 0;
    if (_raw != null && (sameDay || nearMidnight)) {
      steps += raw < _raw! ? raw : raw - _raw!;
    }
    date = day;
    _raw = raw;
    _lastAt = at;
  }

  void mergeHealth(int total, DateTime at) {
    final day = DateFormat('yyyy-MM-dd').format(at);
    if (date != day) {
      date = day;
      steps = 0;
      _raw = null;
    }
    steps = max(steps, total);
  }

  Map<String, dynamic> toJson() => {
    'date': date,
    'steps': steps,
    'raw': _raw,
    'at': _lastAt?.toIso8601String(),
  };

  void restore(Map<String, dynamic> data) {
    date = data['date'] as String? ?? '';
    steps = max(0, data['steps'] as int? ?? 0);
    _raw = data['raw'] as int?;
    _lastAt = DateTime.tryParse(data['at'] as String? ?? '');
  }
}
