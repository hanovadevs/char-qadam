import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/haptics_service.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/activity_provider.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _syncAnimController;

  @override
  void initState() {
    super.initState();
    _syncAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _syncAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activityState = ref.watch(activityProvider);

    if (activityState.isSyncing) {
      if (!_syncAnimController.isAnimating) {
        _syncAnimController.repeat();
      }
    } else {
      if (_syncAnimController.isAnimating) {
        _syncAnimController.stop();
        _syncAnimController.reset();
      }
    }

    final displaySteps = activityState.todaySteps > 0
        ? activityState.todaySteps
        : activityState.serverSteps;
    final cap = activityState.dailyCap > 0 ? activityState.dailyCap : 20000;
    final progress = (displaySteps / cap).clamp(0.0, 1.0);
    final percentInt = (progress * 100).toInt();
    final remainingSteps = (cap - displaySteps).clamp(0, cap);

    // Metric estimates
    final km = (displaySteps * 0.00076).toStringAsFixed(2);
    final kcal = (displaySteps * 0.04).toStringAsFixed(0);

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DAILY MOVEMENT',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppTheme.black,
              ),
            ),
            Text(
              DateFormat('EEEE, MMM d, yyyy').format(DateTime.now()).toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.grey,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        actions: [
          RotationTransition(
            turns: _syncAnimController,
            child: IconButton(
              icon: const Icon(Icons.refresh, size: 20, color: AppTheme.black),
              onPressed: activityState.isSyncing
                  ? null
                  : () => ref.read(activityProvider.notifier).initAndSync(),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.black,
        backgroundColor: AppTheme.white,
        onRefresh: () => ref.read(activityProvider.notifier).initAndSync(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          children: [
            // Quick Points Bar (Instant link between steps & balance)
            InkWell(
              onTap: () => context.go('/points'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.offWhite,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.toll, size: 14, color: AppTheme.black),
                        const SizedBox(width: 6),
                        Text(
                          'EARNED TODAY: +${activityState.pointsEarnedToday} PTS',
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: AppTheme.monoFont,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.black,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'BALANCE: ${activityState.userBalance} PTS',
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: AppTheme.monoFont,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.grey,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios, size: 9, color: AppTheme.grey),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Daily Walking Streak Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department, size: 15, color: AppTheme.black),
                      const SizedBox(width: 6),
                      Text(
                        'STREAK: ${activityState.currentStreakDays} ${activityState.currentStreakDays == 1 ? 'DAY' : 'DAYS'}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: AppTheme.monoFont,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.black,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    activityState.currentStreakDays > 0 ? '🔥 ACTIVE WALKER' : '1,000+ STEPS/DAY GOAL',
                    style: const TextStyle(
                      fontSize: 9,
                      fontFamily: AppTheme.monoFont,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Community Leaderboard Strip
            InkWell(
              onTap: () {
                HapticsService.light();
                context.push('/leaderboard');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.leaderboard_outlined, size: 14, color: AppTheme.black),
                        SizedBox(width: 6),
                        Text(
                          'COMMUNITY LEADERBOARD',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppTheme.black,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'VIEW TOP WALKERS',
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: AppTheme.monoFont,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.grey,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios, size: 9, color: AppTheme.grey),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Hero Movement Card (Swiss Beige Surface #F5F1E8)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.beige,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppTheme.borderDark, width: 1),
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'STEP PROGRESS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.grey,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.white,
                          border: Border.all(color: AppTheme.borderDark),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Text(
                          '$percentInt% COMPLETED',
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: AppTheme.monoFont,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.black,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Large Step Count Display
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        NumberFormat('#,###').format(displaySteps),
                        style: const TextStyle(
                          fontFamily: AppTheme.monoFont,
                          fontSize: 44,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.black,
                          letterSpacing: -1.5,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'STEPS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.grey,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Linear Progress Bar (Clean Black on Beige)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusNone),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: AppTheme.borderDark,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.black),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '0',
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: AppTheme.monoFont,
                          color: AppTheme.grey,
                        ),
                      ),
                      Text(
                        'CAP ${NumberFormat('#,###').format(cap)}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: AppTheme.monoFont,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppTheme.borderDark, height: 1),
                  const SizedBox(height: 14),

                  // 3-Column Metrics Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile('DISTANCE', '$km KM'),
                      ),
                      Container(width: 1, height: 30, color: AppTheme.borderDark),
                      Expanded(
                        child: _buildMetricTile('CALORIES', '$kcal KCAL'),
                      ),
                      Container(width: 1, height: 30, color: AppTheme.borderDark),
                      Expanded(
                        child: _buildMetricTile(
                          'REMAINING',
                          NumberFormat('#,###').format(remainingSteps),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Ingestion Sandbox & Conversion Rule
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'STEP INGESTION & CONVERSION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: AppTheme.grey,
                        ),
                      ),
                      Text(
                        '100 STEPS = 1 PT',
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: AppTheme.monoFont,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 34,
                          child: OutlinedButton(
                            onPressed: () {
                              HapticsService.medium();
                              ref.read(activityProvider.notifier).syncManualSteps(
                                    steps: displaySteps + 1000,
                                  );
                            },
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                            child: const Text('+1,000 STEPS'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 34,
                          child: OutlinedButton(
                            onPressed: () {
                              HapticsService.medium();
                              ref.read(activityProvider.notifier).syncManualSteps(
                                    steps: displaySteps + 5000,
                                  );
                            },
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                            child: const Text('+5,000 STEPS'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // History Section Header & Filter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ACTIVITY LOG',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppTheme.black,
                  ),
                ),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'today', label: Text('TODAY')),
                    ButtonSegment(value: 'week', label: Text('7D')),
                    ButtonSegment(value: 'month', label: Text('30D')),
                  ],
                  selected: {activityState.selectedRange},
                  onSelectionChanged: (Set<String> selection) {
                    HapticsService.selection();
                    ref.read(activityProvider.notifier).loadHistory(selection.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            // History List
            if (activityState.history != null && activityState.history!.days.isNotEmpty)
              ...activityState.history!.days.map((day) {
                final dateFormatted = _formatDate(day.date);
                final stepsFmt = NumberFormat('#,###').format(day.eligibleSteps);
                final pts = day.eligibleSteps ~/ 100;
                final dayProgress = (day.eligibleSteps / cap).clamp(0.0, 1.0);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.offWhite,
                          border: Border.all(color: AppTheme.border),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: const Icon(
                          Icons.directions_walk,
                          color: AppTheme.black,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dateFormatted.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: dayProgress,
                              minHeight: 3,
                              backgroundColor: AppTheme.border,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.black),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$stepsFmt STEPS',
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: AppTheme.monoFont,
                                color: AppTheme.grey,
                              ),
                            ),
                            if (day.source != null) ...[
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: day.source == 'manual_debug'
                                      ? AppTheme.beige
                                      : AppTheme.offWhite,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Text(
                                  day.sourceLabel,
                                  style: const TextStyle(
                                    fontSize: 8,
                                    fontFamily: AppTheme.monoFont,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.grey,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.offWhite,
                          border: Border.all(color: AppTheme.border),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Text(
                          '+$pts PTS',
                          style: const TextStyle(
                            color: AppTheme.black,
                            fontFamily: AppTheme.monoFont,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              })
            else
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Text(
                  'NO STEP RECORDS FOR THIS PERIOD',
                  style: TextStyle(
                    color: AppTheme.grey,
                    fontSize: 11,
                    fontFamily: AppTheme.monoFont,
                    letterSpacing: 1.0,
                  ),
                ),
              ),

            const SizedBox(height: 14),

            // Privacy Guarantee Note (Swiss Minimalist Light)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.offWhite,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: AppTheme.grey, size: 16),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'ZERO GPS TRACKING — Steps are computed locally on your device sensor. Location data is never collected or transmitted.',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.grey,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AppTheme.grey,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontFamily: AppTheme.monoFont,
            fontWeight: FontWeight.w700,
            color: AppTheme.black,
          ),
        ),
      ],
    );
  }

  String _formatDate(String isoDate) {
    try {
      final parsed = DateTime.parse(isoDate);
      return DateFormat('EEE, MMM d').format(parsed);
    } catch (_) {
      return isoDate;
    }
  }
}
