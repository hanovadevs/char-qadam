import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/stepsy_ui.dart';
import '../../../data/activity/activity_repository.dart';
import '../../../data/models/activity_models.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});
  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  List<ActivityPeriodModel> _days = [];
  String _range = 'weeks';
  int? _selected;
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref
          .read(activityRepositoryProvider)
          .getActivityHistory(range: '6months');
      if (mounted) {
        setState(() {
          _days = data.days;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Your walking history couldn’t be loaded.';
          _loading = false;
        });
      }
    }
  }

  List<_Period> _periods() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final records = {for (final day in _days) day.date: day.eligibleSteps};
    return List.generate(_range == 'weeks' ? 8 : 6, (index) {
      final offset = (_range == 'weeks' ? 7 : 5) - index;
      final start = _range == 'weeks'
          ? monday.subtract(Duration(days: offset * 7))
          : DateTime(now.year, now.month - offset, 1);
      final end = _range == 'weeks'
          ? start.add(const Duration(days: 6))
          : DateTime(start.year, start.month + 1, 0);
      final values = <int>[];
      for (
        var date = start;
        !date.isAfter(end) && !date.isAfter(today);
        date = DateTime(date.year, date.month, date.day + 1)
      ) {
        final steps = records[DateFormat('yyyy-MM-dd').format(date)];
        if (steps != null) values.add(steps);
      }
      return _Period(
        label: _range == 'weeks'
            ? DateFormat('d/M').format(start)
            : DateFormat('MMM').format(start),
        fullLabel: _range == 'weeks'
            ? '${DateFormat('d MMM').format(start)} – ${DateFormat('d MMM').format(end)}'
            : DateFormat('MMMM yyyy').format(start),
        steps: values.fold(0, (a, b) => a + b),
        recordedDays: values.length,
        activeDays: values.where((v) => v > 0).length,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final periods = _periods();
    final index = (_selected ?? periods.length - 1).clamp(
      0,
      periods.length - 1,
    );
    final selected = periods[index];
    final hasData = selected.recordedDays > 0;
    final number = NumberFormat('#,###');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress & trends'),
        actions: [
          IconButton(
            tooltip: 'Refresh progress',
            onPressed: _loading ? null : _fetch,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            const Text(
              'Look how far\nyou’ve come.',
              style: AppTheme.largeTitleStyle,
            ),
            const SizedBox(height: 12),
            const Text(
              'A bigger picture of your everyday movement.',
              style: AppTheme.captionStyle,
            ),
            const SizedBox(height: 24),
            FilterPills(
              options: const {'weeks': 'Weeks', 'months': 'Months'},
              selected: _range,
              onSelected: (value) => setState(() {
                _range = value;
                _selected = null;
              }),
            ),
            const SizedBox(height: 20),
            if (_error != null) StatusNotice(_error!, onRetry: _fetch),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(selected.fullLabel, style: AppTheme.captionStyle),
                  const SizedBox(height: 10),
                  Text(
                    hasData ? number.format(selected.steps) : '—',
                    style: AppTheme.heroNumeralStyle.copyWith(
                      color: AppTheme.accentDeep,
                    ),
                  ),
                  Text(
                    hasData
                        ? 'synced steps'
                        : 'No synced records for this period',
                    style: AppTheme.captionStyle,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 210,
                    child: _HistoryBars(
                      periods: periods,
                      selected: index,
                      onSelect: (value) => setState(() => _selected = value),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Scale: 0–${number.format(periods.map((p) => p.steps).fold(0, math.max))} steps',
                    style: AppTheme.captionStyle,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap a period to explore. A dash means no synced records.',
                    style: AppTheme.captionStyle,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SurfaceCard(
              color: AppTheme.mintWash,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth < 300
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 24) / 2;
                  return Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    children: [
                      _metric(
                        'Daily average',
                        hasData
                            ? number.format(
                                selected.steps ~/ selected.recordedDays,
                              )
                            : '—',
                        width,
                      ),
                      _metric(
                        'Active days',
                        hasData ? '${selected.activeDays}' : '—',
                        width,
                      ),
                      _metric(
                        'Estimated distance',
                        hasData
                            ? '${(selected.steps * 0.0007).toStringAsFixed(1)} km'
                            : '—',
                        width,
                      ),
                      _metric(
                        'Estimated energy',
                        hasData
                            ? '${number.format((selected.steps * 0.04).round())} kcal'
                            : '—',
                        width,
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Daily averages use days with synced records. Missing syncs aren’t treated as zero-step days. Distance and energy are estimates.',
              style: AppTheme.captionStyle,
            ),
            SectionHeading(
              _range == 'weeks' ? 'Weekly breakdown' : 'Monthly breakdown',
            ),
            SurfaceCard(
              child: Column(
                children: periods.reversed
                    .map(
                      (p) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                p.fullLabel,
                                style: AppTheme.captionStyle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              p.recordedDays == 0
                                  ? '—'
                                  : number.format(p.steps),
                              style: AppTheme.headlineStyle.copyWith(
                                fontFeatures: AppTheme.tabular,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value, double width) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTheme.titleStyle.copyWith(fontFeatures: AppTheme.tabular),
        ),
        const SizedBox(height: 6),
        Text(label, style: AppTheme.captionStyle),
      ],
    ),
  );
}

class _Period {
  final String label, fullLabel;
  final int steps, recordedDays, activeDays;
  const _Period({
    required this.label,
    required this.fullLabel,
    required this.steps,
    required this.recordedDays,
    required this.activeDays,
  });
}

class _HistoryBars extends StatelessWidget {
  final List<_Period> periods;
  final int selected;
  final ValueChanged<int> onSelect;
  const _HistoryBars({
    required this.periods,
    required this.selected,
    required this.onSelect,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final max = periods.map((p) => p.steps).fold<int>(1, math.max);
      final width = math.max(constraints.maxWidth, periods.length * 48.0);
      final labelHeight = 20 * MediaQuery.textScalerOf(context).scale(1) + 10;
      final plotHeight = math.max(
        0.0,
        constraints.maxHeight - labelHeight - 16,
      );
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(periods.length, (index) {
              final p = periods[index];
              final active = index == selected;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: active,
                  label:
                      '${p.fullLabel}: ${p.recordedDays == 0 ? 'no synced records' : '${p.steps} steps'}',
                  child: Tooltip(
                    message:
                        '${p.fullLabel}: ${p.recordedDays == 0 ? 'No synced records' : '${NumberFormat('#,###').format(p.steps)} steps'}',
                    child: InkWell(
                      onTap: () => onSelect(index),
                      borderRadius: BorderRadius.circular(8),
                      child: ExcludeSemantics(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 7),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              SizedBox(
                                height: plotHeight,
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: p.steps == 0
                                      ? Text(
                                          p.recordedDays == 0 ? '—' : '0',
                                          style: AppTheme.captionStyle,
                                        )
                                      : Container(
                                          height: plotHeight * p.steps / max,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: active
                                                ? AppTheme.accentDeep
                                                : AppTheme.mintWash,
                                            border: Border.all(
                                              color: active
                                                  ? AppTheme.accentDeep
                                                  : AppTheme.accentSolid,
                                            ),
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  top: Radius.circular(8),
                                                ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: labelHeight,
                                child: Text(
                                  p.label,
                                  maxLines: 1,
                                  style: AppTheme.captionStyle.copyWith(
                                    fontSize: 12,
                                    color: AppTheme.inkPrimary,
                                    fontWeight: active
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    decoration: active
                                        ? TextDecoration.underline
                                        : TextDecoration.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      );
    },
  );
}
