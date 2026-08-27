import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'COMMUNITY LEADERBOARD',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppTheme.black,
              ),
            ),
            Text(
              'VERIFIED STEP PERFORMANCE',
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.grey,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: state.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.black),
                    ),
                  )
                : const Icon(Icons.refresh, size: 20, color: AppTheme.black),
            onPressed: () => ref.read(leaderboardProvider.notifier).refresh(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.black,
        backgroundColor: AppTheme.white,
        onRefresh: () => ref.read(leaderboardProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          children: [
            // Scope Segmented Button (Swiss Light Mode)
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'today', label: Text('TODAY')),
                ButtonSegment(value: 'week', label: Text('7D')),
                ButtonSegment(value: 'month', label: Text('30D')),
                ButtonSegment(value: 'all_time', label: Text('ALL')),
              ],
              selected: {state.selectedScope},
              onSelectionChanged: (Set<String> selection) {
                ref.read(leaderboardProvider.notifier).fetchLeaderboard(selection.first);
              },
            ),
            const SizedBox(height: 14),

            // Sticky/Pinned Current User Status
            if (userRanking != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.beige,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.borderDark, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.black,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Text(
                        '#${userRanking.rank}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontFamily: AppTheme.monoFont,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'YOUR CURRENT RANKING',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              color: AppTheme.grey,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${NumberFormat('#,###').format(userRanking.totalSteps)} STEPS  •  +${userRanking.pointsEarned} PTS',
                            style: const TextStyle(
                              fontSize: 13,
                              fontFamily: AppTheme.monoFont,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.white,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(color: AppTheme.borderDark),
                      ),
                      child: Text(
                        'TOP ${userRanking.percentile}%',
                        style: const TextStyle(
                          fontSize: 9,
                          fontFamily: AppTheme.monoFont,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.taupe,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Top 3 Podium (If available)
            if (topThree.isNotEmpty) ...[
              const Text(
                'TOP PERFORMERS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: AppTheme.black,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // #2 Second Place
                  if (topThree.length > 1)
                    Expanded(
                      child: _buildPodiumTile(topThree[1], 2, height: 110),
                    )
                  else
                    const Spacer(),
                  const SizedBox(width: 8),

                  // #1 First Place
                  if (topThree.isNotEmpty)
                    Expanded(
                      child: _buildPodiumTile(topThree[0], 1, height: 130),
                    ),
                  const SizedBox(width: 8),

                  // #3 Third Place
                  if (topThree.length > 2)
                    Expanded(
                      child: _buildPodiumTile(topThree[2], 3, height: 95),
                    )
                  else
                    const Spacer(),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Full Leaderboard List
            if (remaining.isNotEmpty) ...[
              const Text(
                'ALL PARTICIPANTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: AppTheme.black,
                ),
              ),
              const SizedBox(height: 8),
              ...remaining.map((entry) => _buildRankRow(entry)),
            ] else if (rankings.isEmpty && !state.isLoading)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 36),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Text(
                  'NO LEADERBOARD DATA FOR THIS PERIOD',
                  style: TextStyle(
                    color: AppTheme.grey,
                    fontSize: 11,
                    fontFamily: AppTheme.monoFont,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodiumTile(LeaderboardEntryModel entry, int rank, {required double height}) {
    final rankLabel = rank == 1 ? '1ST' : rank == 2 ? '2ND' : '3RD';
    final badgeColor = rank == 1 ? AppTheme.black : AppTheme.grey;

    return Container(
      height: height,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: rank == 1 ? AppTheme.beige : AppTheme.offWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: rank == 1 ? AppTheme.borderDark : AppTheme.border,
          width: rank == 1 ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  rankLabel,
                  style: const TextStyle(
                    fontSize: 9,
                    fontFamily: AppTheme.monoFont,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.white,
                  ),
                ),
              ),
              if (entry.isCurrentUser)
                const Text(
                  'YOU',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.taupe,
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
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.black,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                NumberFormat('#,###').format(entry.totalSteps),
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: AppTheme.monoFont,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.black,
                ),
              ),
              Text(
                '+${entry.pointsEarned} PTS',
                style: const TextStyle(
                  fontSize: 9,
                  fontFamily: AppTheme.monoFont,
                  color: AppTheme.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRankRow(LeaderboardEntryModel entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: entry.isCurrentUser ? AppTheme.beige : AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: entry.isCurrentUser ? AppTheme.black : AppTheme.border,
          width: entry.isCurrentUser ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#${entry.rank.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontFamily: AppTheme.monoFont,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: entry.isCurrentUser ? AppTheme.black : AppTheme.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.displayName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.black,
                      ),
                    ),
                    if (entry.isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.black,
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: const Text(
                          'YOU',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${NumberFormat('#,###').format(entry.totalSteps)} STEPS',
            style: const TextStyle(
              fontSize: 12,
              fontFamily: AppTheme.monoFont,
              fontWeight: FontWeight.w700,
              color: AppTheme.black,
            ),
          ),
        ],
      ),
    );
  }
}
