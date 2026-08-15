import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/points_provider.dart';

class PointsScreen extends ConsumerWidget {
  const PointsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pointsState = ref.watch(pointsProvider);
    final theme = Theme.of(context);

    final balance = pointsState.balanceData?.balance ?? 0;
    final totalEarned = pointsState.balanceData?.totalEarned ?? 0;
    final totalSpent = pointsState.balanceData?.totalSpent ?? 0;
    final entries = pointsState.ledgerPage?.entries ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.stars, color: Color(0xFFF59E0B)),
            SizedBox(width: 8),
            Text('Points & Ledger'),
          ],
        ),
        actions: [
          IconButton(
            icon: pointsState.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: () => ref.read(pointsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(pointsProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Balance Hero Card
            Card(
              color: const Color(0xFF1E293B),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Text(
                      'AVAILABLE BALANCE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.stars_rounded,
                          color: Color(0xFFF59E0B),
                          size: 40,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          NumberFormat('#,###').format(balance),
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 42,
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'PTS',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: Color(0xFF334155)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn(
                          label: 'Lifetime Earned',
                          value: '+${NumberFormat('#,###').format(totalEarned)}',
                          color: const Color(0xFF10B981),
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: const Color(0xFF334155),
                        ),
                        _buildStatColumn(
                          label: 'Lifetime Spent',
                          value: '-${NumberFormat('#,###').format(totalSpent)}',
                          color: const Color(0xFF6366F1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Points Ledger History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            if (entries.isNotEmpty)
              ...entries.map((entry) {
                final isEarn = entry.delta > 0;
                final dateStr = DateFormat('MMM d, yyyy • hh:mm a')
                    .format(entry.createdAt.toLocal());
                final deltaStr = isEarn
                    ? '+${NumberFormat('#,###').format(entry.delta)} pts'
                    : '${NumberFormat('#,###').format(entry.delta)} pts';

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isEarn
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : const Color(0xFF6366F1).withValues(alpha: 0.15),
                      child: Icon(
                        isEarn ? Icons.arrow_downward : Icons.shopping_bag_outlined,
                        color: isEarn
                            ? const Color(0xFF10B981)
                            : const Color(0xFF6366F1),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      _reasonTitle(entry.reason),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      dateStr,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                    trailing: Text(
                      deltaStr,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isEarn
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF87171),
                      ),
                    ),
                  ),
                );
              })
            else if (pointsState.isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32.0),
                child: Center(
                  child: Text(
                    'No points ledger transactions yet.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _reasonTitle(String reason) {
    switch (reason) {
      case 'STEP_EARN':
        return 'Daily Steps Converted';
      case 'OFFER_SPEND':
        return 'Voucher Offer Redemption';
      case 'ADJUST':
        return 'Account Adjustment';
      default:
        return reason;
    }
  }
}
