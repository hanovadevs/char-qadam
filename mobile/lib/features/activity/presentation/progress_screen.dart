import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/haptics_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/activity/activity_repository.dart';
import '../../../data/models/activity_models.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  // 0: Weeks, 1: Months
  int _selectedTabIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;

  List<ActivityPeriodModel> _rawDays = [];
  int? _selectedBarIndex;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(activityRepositoryProvider);
      // Fetch 6 months of historical activity records
      final data = await repo.getActivityHistory(range: '6months');
      if (!mounted) return;
      setState(() {
        _rawDays = data.days;
        _isLoading = false;
        _selectedBarIndex = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  /// Groups raw days into the last 8 calendar weeks (Monday–Sunday)
  List<_PeriodMetric> _computeWeeklyData() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Find current week's Monday
    final currentMonday = today.subtract(Duration(days: today.weekday - 1));

    final Map<String, int> dailyStepsMap = {};
    for (final d in _rawDays) {
      dailyStepsMap[d.date] = d.eligibleSteps;
    }

    final List<_PeriodMetric> weeks = [];
    final dfMonthDay = DateFormat('MMM d');
    final dfShort = DateFormat('d');

    for (int i = 7; i >= 0; i--) {
      final weekStart = currentMonday.subtract(Duration(days: i * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));

      int totalSteps = 0;
      int daysActive = 0;
      int bestDaySteps = 0;
      String? bestDayDate;

      for (int d = 0; d < 7; d++) {
        final dayDate = weekStart.add(Duration(days: d));
        if (dayDate.isAfter(today)) continue;

        final key = DateFormat('yyyy-MM-dd').format(dayDate);
        final steps = dailyStepsMap[key] ?? 0;
        totalSteps += steps;
        if (steps > 0) {
          daysActive++;
          if (steps > bestDaySteps) {
            bestDaySteps = steps;
            bestDayDate = key;
          }
        }
      }

      final isCurrentWeek = i == 0;
      final label = isCurrentWeek
          ? 'This Wk'
          : 'W${8 - i}';

      final fullLabel = weekStart.month == weekEnd.month
          ? '${dfMonthDay.format(weekStart)}–${dfShort.format(weekEnd)}'
          : '${dfMonthDay.format(weekStart)}–${dfMonthDay.format(weekEnd)}';

      final daysCounted = isCurrentWeek ? today.weekday : 7;
      final dailyAvg = daysCounted > 0 ? totalSteps ~/ daysCounted : 0;

      weeks.add(_PeriodMetric(
        label: label,
        fullLabel: fullLabel,
        totalSteps: totalSteps,
        dailyAverage: dailyAvg,
        daysActive: daysActive,
        totalDays: daysCounted,
        bestDaySteps: bestDaySteps,
        bestDayDate: bestDayDate,
        startDate: weekStart,
        endDate: weekEnd,
      ));
    }

    return weeks;
  }

  /// Groups raw days into the last 6 calendar months
  List<_PeriodMetric> _computeMonthlyData() {
    final now = DateTime.now();
    final Map<String, int> dailyStepsMap = {};
    for (final d in _rawDays) {
      dailyStepsMap[d.date] = d.eligibleSteps;
    }

    final List<_PeriodMetric> months = [];
    final dfMonth = DateFormat('MMM');
    final dfFullMonth = DateFormat('MMMM yyyy');

    for (int i = 5; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final nextMonth = DateTime(monthDate.year, monthDate.month + 1, 1);
      final daysInMonth = nextMonth.difference(monthDate).inDays;

      int totalSteps = 0;
      int daysActive = 0;
      int bestDaySteps = 0;
      String? bestDayDate;

      final isCurrentMonth = i == 0;
      final limitDay = isCurrentMonth ? now.day : daysInMonth;

      for (int d = 1; d <= limitDay; d++) {
        final day = DateTime(monthDate.year, monthDate.month, d);
        final key = DateFormat('yyyy-MM-dd').format(day);
        final steps = dailyStepsMap[key] ?? 0;
        totalSteps += steps;
        if (steps > 0) {
          daysActive++;
          if (steps > bestDaySteps) {
            bestDaySteps = steps;
            bestDayDate = key;
          }
        }
      }

      final dailyAvg = limitDay > 0 ? totalSteps ~/ limitDay : 0;

      months.add(_PeriodMetric(
        label: dfMonth.format(monthDate),
        fullLabel: dfFullMonth.format(monthDate),
        totalSteps: totalSteps,
        dailyAverage: dailyAvg,
        daysActive: daysActive,
        totalDays: limitDay,
        bestDaySteps: bestDaySteps,
        bestDayDate: bestDayDate,
        startDate: monthDate,
        endDate: nextMonth.subtract(const Duration(days: 1)),
      ));
    }

    return months;
  }

  @override
  Widget build(BuildContext context) {
    final periods = _selectedTabIndex == 0 ? _computeWeeklyData() : _computeMonthlyData();

    // Default to the last period if none selected
    final selectedIndex = (_selectedBarIndex != null && _selectedBarIndex! < periods.length)
        ? _selectedBarIndex!
        : (periods.isNotEmpty ? periods.length - 1 : 0);

    final selectedPeriod = periods.isNotEmpty ? periods[selectedIndex] : null;

    // Aggregate period statistics
    final allPeriodSteps = periods.fold<int>(0, (sum, p) => sum + p.totalSteps);
    final allDaysCounted = periods.fold<int>(0, (sum, p) => sum + p.totalDays);
    final overallDailyAvg = allDaysCounted > 0 ? allPeriodSteps ~/ allDaysCounted : 0;

    final km = selectedPeriod != null
        ? (selectedPeriod.totalSteps * 0.00076).toStringAsFixed(1)
        : '0.0';
    final kcal = selectedPeriod != null
        ? (selectedPeriod.totalSteps * 0.04).toStringAsFixed(0)
        : '0';

    return Scaffold(
      backgroundColor: AppTheme.surfaceMuted,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_back, size: 22, color: AppTheme.inkPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Progress & trends',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.inkPrimary,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentSolid),
                    ),
                  )
                : const Icon(CupertinoIcons.arrow_2_circlepath, size: 20, color: AppTheme.inkPrimary),
            onPressed: _isLoading ? null : _fetchHistory,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.accentSolid,
        backgroundColor: AppTheme.surface,
        onRefresh: _fetchHistory,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            // Apple-style Segmented Control (Weeks vs Months)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                border: Border.all(color: AppTheme.hairline),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSegmentButton(
                      label: 'Weeks',
                      isSelected: _selectedTabIndex == 0,
                      onTap: () {
                        if (_selectedTabIndex != 0) {
                          HapticsService.selection();
                          setState(() {
                            _selectedTabIndex = 0;
                            _selectedBarIndex = null;
                          });
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: _buildSegmentButton(
                      label: 'Months',
                      isSelected: _selectedTabIndex == 1,
                      onTap: () {
                        if (_selectedTabIndex != 1) {
                          HapticsService.selection();
                          setState(() {
                            _selectedTabIndex = 1;
                            _selectedBarIndex = null;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.destructive.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 13, color: AppTheme.destructive),
                ),
              ),

            // Hero Chart Card
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppTheme.hairline),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Period Header & Selected Detail
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedPeriod?.fullLabel ?? (_selectedTabIndex == 0 ? 'Last 8 weeks' : 'Last 6 months'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.inkSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                NumberFormat('#,###').format(selectedPeriod?.totalSteps ?? 0),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.inkPrimary,
                                  letterSpacing: -1.0,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'steps',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.inkSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (selectedPeriod != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.accentBright.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                          ),
                          child: Text(
                            'Avg ${NumberFormat('#,###').format(selectedPeriod.dailyAverage)} / day',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accentSolid,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // The Interactive Bar Chart
                  SizedBox(
                    height: 160,
                    child: _InteractiveBarChart(
                      periods: periods,
                      selectedIndex: selectedIndex,
                      onSelectIndex: (index) {
                        HapticsService.light();
                        setState(() {
                          _selectedBarIndex = index;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: AppTheme.hairline, height: 1),
                  const SizedBox(height: 14),

                  // Bottom mini summary in chart card
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Period daily average: ${NumberFormat('#,###').format(overallDailyAvg)} steps',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.inkSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const Text(
                        'Tap a bar to inspect',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.inkTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Inset Summary Stats Grid (Grouped 2x2 cards)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppTheme.hairline),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricBlock(
                          label: 'Daily average',
                          value: '${NumberFormat('#,###').format(selectedPeriod?.dailyAverage ?? 0)} steps',
                        ),
                      ),
                      Container(width: 1, height: 38, color: AppTheme.hairline),
                      Expanded(
                        child: _buildMetricBlock(
                          label: 'Estimated distance',
                          value: '$km km',
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(color: AppTheme.hairline, height: 1),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricBlock(
                          label: 'Active days',
                          value: '${selectedPeriod?.daysActive ?? 0} of ${selectedPeriod?.totalDays ?? 0}',
                        ),
                      ),
                      Container(width: 1, height: 38, color: AppTheme.hairline),
                      Expanded(
                        child: _buildMetricBlock(
                          label: 'Estimated energy',
                          value: '$kcal kcal',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Period Breakdown Header
            Text(
              _selectedTabIndex == 0 ? 'Weekly breakdown' : 'Monthly breakdown',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                color: AppTheme.inkPrimary,
              ),
            ),
            const SizedBox(height: 10),

            // Grouped Inset History Breakdown List
            if (periods.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.hairline),
                ),
                child: const Center(
                  child: Text(
                    'No historical step records found for this period.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.inkSecondary,
                    ),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.hairline),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: periods.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, color: AppTheme.hairline),
                  itemBuilder: (context, index) {
                    // Show reverse chronological (newest first)
                    final item = periods[periods.length - 1 - index];
                    final isSelected = (periods.length - 1 - index) == selectedIndex;
                    final maxPeriodSteps = periods.map((p) => p.totalSteps).fold<int>(1, math.max);
                    final ratio = (item.totalSteps / maxPeriodSteps).clamp(0.0, 1.0);
                    final ptsEarned = item.totalSteps ~/ 100;

                    return InkWell(
                      onTap: () {
                        HapticsService.light();
                        setState(() {
                          _selectedBarIndex = periods.length - 1 - index;
                        });
                      },
                      child: Container(
                        color: isSelected ? AppTheme.accentBright.withValues(alpha: 0.08) : Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.fullLabel,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                    color: isSelected ? AppTheme.accentSolid : AppTheme.inkPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                Text(
                                  '${NumberFormat('#,###').format(item.totalSteps)} steps',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.inkPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Mini Proportional Bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                              child: Container(
                                height: 6,
                                width: double.infinity,
                                color: AppTheme.surfaceMuted,
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: ratio,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppTheme.accentSolid : AppTheme.accentBright.withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Avg ${NumberFormat('#,###').format(item.dailyAverage)} / day  •  ${item.daysActive} days active',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.inkTertiary,
                                  ),
                                ),
                                Text(
                                  '+${NumberFormat('#,###').format(ptsEarned)} pts',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.accentSolid,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.inkPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppTheme.surface : AppTheme.inkSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricBlock({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppTheme.inkSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.inkPrimary,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Data container for a computed period (week or month)
class _PeriodMetric {
  final String label;
  final String fullLabel;
  final int totalSteps;
  final int dailyAverage;
  final int daysActive;
  final int totalDays;
  final int bestDaySteps;
  final String? bestDayDate;
  final DateTime startDate;
  final DateTime endDate;

  _PeriodMetric({
    required this.label,
    required this.fullLabel,
    required this.totalSteps,
    required this.dailyAverage,
    required this.daysActive,
    required this.totalDays,
    required this.bestDaySteps,
    this.bestDayDate,
    required this.startDate,
    required this.endDate,
  });
}

/// Custom-painted interactive bar chart with rounded bars and smooth highlights
class _InteractiveBarChart extends StatelessWidget {
  final List<_PeriodMetric> periods;
  final int selectedIndex;
  final ValueChanged<int> onSelectIndex;

  const _InteractiveBarChart({
    required this.periods,
    required this.selectedIndex,
    required this.onSelectIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (periods.isEmpty) {
      return const Center(
        child: Text(
          'No activity recorded',
          style: TextStyle(fontSize: 12, color: AppTheme.inkTertiary),
        ),
      );
    }

    final maxSteps = periods.map((p) => p.totalSteps).fold<int>(1, math.max);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final totalHeight = constraints.maxHeight;
        final count = periods.length;
        final barGap = 8.0;
        final barWidth = math.max(14.0, (totalWidth - (barGap * (count - 1))) / count);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(count, (index) {
            final period = periods[index];
            final ratio = maxSteps > 0 ? (period.totalSteps / maxSteps).clamp(0.04, 1.0) : 0.04;
            final isSelected = index == selectedIndex;
            final barHeight = (totalHeight - 24) * ratio;

            return GestureDetector(
              onTap: () => onSelectIndex(index),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: barWidth,
                height: totalHeight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // The Bar Column
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      height: barHeight,
                      width: barWidth,
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(
                                colors: [AppTheme.accentBright, AppTheme.accentDeep],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              )
                            : null,
                        color: isSelected
                            ? null
                            : (period.totalSteps > 0
                                ? AppTheme.accentBright.withValues(alpha: 0.35)
                                : AppTheme.surfaceMuted),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: isSelected
                            ? Border.all(color: AppTheme.accentSolid, width: 1.5)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Label below bar
                    Text(
                      period.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? AppTheme.inkPrimary : AppTheme.inkTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
