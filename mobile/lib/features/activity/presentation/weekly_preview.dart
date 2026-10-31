import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/activity/activity_repository.dart';
import '../../../data/auth/auth_state_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/activity_models.dart';

final weeklyActivityProvider = FutureProvider<List<ActivityPeriodModel>>((
  ref,
) async {
  final user = ref.watch(authStateProvider.select((s) => s.user?.id));
  if (user == null) return [];
  return (await ref
          .watch(activityRepositoryProvider)
          .getActivityHistory(range: 'week'))
      .days;
});

class WeeklyPreview extends StatelessWidget {
  final List<ActivityPeriodModel> days;
  const WeeklyPreview({super.key, required this.days});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dates = List.generate(
      7,
      (i) => today.subtract(Duration(days: 6 - i)),
    );
    final byDate = {for (final d in days) d.date: d.eligibleSteps};
    final maximum = math.max(
      1,
      days.fold<int>(0, (a, d) => math.max(a, d.eligibleSteps)),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: dates.map((date) {
        final value = byDate[DateFormat('yyyy-MM-dd').format(date)];
        return Expanded(
          child: Semantics(
            label:
                '${DateFormat('EEEE d MMMM').format(date)}: ${value == null ? 'no recorded data' : '$value steps'}',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value == null
                      ? '—'
                      : value >= 1000
                      ? '${(value / 1000).toStringAsFixed(1)}k'
                      : '$value',
                  style: AppTheme.captionStyle.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 64,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 24,
                      height: value == null
                          ? 2
                          : math.max(2, 64 * value / maximum),
                      decoration: BoxDecoration(
                        color: value == null
                            ? AppTheme.hairline
                            : date == today
                            ? AppTheme.accentSolid
                            : AppTheme.accentBright,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat('E').format(date),
                  style: AppTheme.captionStyle.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
