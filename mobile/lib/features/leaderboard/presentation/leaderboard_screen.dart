import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/haptics_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/leaderboard_models.dart';
import '../providers/leaderboard_provider.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(leaderboardProvider);
    final data = state.data;
    final rankings = data?.rankings ?? [];
    final userRanking = data?.userRanking;

    final topThree = rankings.take(3).toList();
    final remaining = rankings.skip(3).toList();

    return Scaffold(
      backgroundColor: AppTheme.surfaceMuted,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Leaderboard',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: AppTheme.inkPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: state.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentSolid),
                    ),
                  )
                : const Icon(CupertinoIcons.arrow_2_circlepath, size: 20, color: AppTheme.inkPrimary),
            onPressed: () => ref.read(leaderboardProvider.notifier).refresh(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.accentSolid,
        backgroundColor: AppTheme.surface,
        onRefresh: () => ref.read(leaderboardProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            // Scope Segmented Control (Apple Pill Style)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                border: Border.all(color: AppTheme.hairline),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildScopeSegment('today', 'Today', state.selectedScope, ref),
                  _buildScopeSegment('week', '7D', state.selectedScope, ref),
                  _buildScopeSegment('month', '30D', state.selectedScope, ref),
                  _buildScopeSegment('all_time', 'All time', state.selectedScope, ref),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Sticky/Pinned Current User Status
            if (userRanking != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.hairline),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentSolid,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Text(
                        '#${userRanking.rank}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.surface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your rank',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: AppTheme.inkSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${NumberFormat('#,###').format(userRanking.totalSteps)} steps  •  +${userRanking.pointsEarned} pts',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.inkPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentBright.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      ),
                      child: Text(
                        'Top ${userRanking.percentile}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentSolid,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Top 3 Podium
            if (topThree.isNotEmpty) ...[
              const Text(
                'Top walkers',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: AppTheme.inkPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // #2 Second Place
                  if (topThree.length > 1)
                    Expanded(
                      child: _buildPodiumTile(topThree[1], 2, height: 115),
                    )
                  else
                    const Spacer(),
                  const SizedBox(width: 10),

                  // #1 First Place
                  if (topThree.isNotEmpty)
                    Expanded(
                      child: _buildPodiumTile(topThree[0], 1, height: 135),
                    ),
                  const SizedBox(width: 10),

                  // #3 Third Place
                  if (topThree.length > 2)
                    Expanded(
                      child: _buildPodiumTile(topThree[2], 3, height: 100),
                    )
                  else
                    const Spacer(),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // Full Leaderboard List
            if (remaining.isNotEmpty) ...[
              const Text(
                'Rankings',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: AppTheme.inkPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.hairline),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: remaining.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, color: AppTheme.hairline),
                  itemBuilder: (context, index) => _buildRankRow(remaining[index]),
                ),
              ),
            ] else if (rankings.isEmpty && !state.isLoading)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.hairline),
                ),
                child: const Text(
                  'No activity recorded for this period',
                  style: TextStyle(
                    color: AppTheme.inkSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeSegment(String value, String label, String currentScope, WidgetRef ref) {
    final isSelected = currentScope == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticsService.selection();
          ref.read(leaderboardProvider.notifier).fetchLeaderboard(value);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accentSolid : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? AppTheme.surface : AppTheme.inkSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPodiumTile(LeaderboardEntryModel entry, int rank, {required double height}) {
    final rankLabel = rank == 1 ? '1st' : rank == 2 ? '2nd' : '3rd';
    final isFirst = rank == 1;

    return Container(
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: isFirst ? AppTheme.accentBright : AppTheme.hairline,
          width: isFirst ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isFirst
                      ? AppTheme.accentBright.withValues(alpha: 0.15)
                      : AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Text(
                  rankLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isFirst ? AppTheme.accentSolid : AppTheme.inkSecondary,
                  ),
                ),
              ),
              if (entry.isCurrentUser)
                const Text(
                  'You',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentSolid,
                  ),
                ),
            ],
          ),
          Column(
            children: [
              Text(
                entry.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.inkPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                NumberFormat('#,###').format(entry.totalSteps),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.inkPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                '+${entry.pointsEarned} pts',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.accentSolid,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRankRow(LeaderboardEntryModel entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#${entry.rank}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: entry.isCurrentUser ? AppTheme.accentSolid : AppTheme.inkSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Text(
                  entry.displayName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: entry.isCurrentUser ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: -0.2,
                    color: AppTheme.inkPrimary,
                  ),
                ),
                if (entry.isCurrentUser) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentBright.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    child: const Text(
                      'You',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentSolid,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '${NumberFormat('#,###').format(entry.totalSteps)} steps',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: AppTheme.inkPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
