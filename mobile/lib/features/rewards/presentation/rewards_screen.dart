import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../points/providers/points_provider.dart';
import '../providers/rewards_provider.dart';

class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  void _confirmRedeem(BuildContext context, WidgetRef ref, String offerId, String title, int cost) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Redeem Reward?'),
        content: Text(
          'Are you sure you want to spend $cost points on "$title"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await ref.read(rewardsProvider.notifier).redeem(offerId);
              if (result != null && context.mounted) {
                // Refresh points balance provider
                ref.read(pointsProvider.notifier).refresh();
                _showSuccessDialog(context, result);
              } else if (context.mounted) {
                final error = ref.read(rewardsProvider).errorMessage ?? 'Redemption failed';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Confirm Redeem'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, dynamic result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 48),
        title: const Text('Voucher Issued!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your voucher has been created and added to your wallet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981)),
              ),
              child: SelectableText(
                result.shortCode,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Color(0xFF10B981),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Spent: ${result.pointsSpent} pts • Balance: ${result.balance} pts',
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/wallet');
            },
            child: const Text('View in Wallet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewardsState = ref.watch(rewardsProvider);
    final pointsState = ref.watch(pointsProvider);

    final userBalance = pointsState.balanceData?.balance ?? 0;
    final offers = rewardsState.offers;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.local_offer, color: Color(0xFF6366F1)),
            SizedBox(width: 8),
            Text('Rewards Catalog'),
          ],
        ),
        actions: [
          IconButton(
            icon: rewardsState.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: () => ref.read(rewardsProvider.notifier).fetchOffers(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(rewardsProvider.notifier).fetchOffers(),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Balance Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.stars, color: Color(0xFFF59E0B)),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'YOUR BALANCE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        '${NumberFormat('#,###').format(userBalance)} Points',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Available Offers',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            if (offers.isNotEmpty)
              ...offers.map((offer) {
                final canAfford = userBalance >= offer.pointsCost;
                final inStock = offer.inventory == null || offer.inventory! > 0;
                final isAvailable = canAfford && inStock;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Discount Tag
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                _discountLabel(offer.discountType, offer.discountValue),
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    offer.title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (offer.description != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      offer.description!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Color(0xFF334155)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.stars,
                                    color: Color(0xFFF59E0B), size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  '${offer.pointsCost} Points',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFF59E0B),
                                  ),
                                ),
                                if (offer.inventory != null) ...[
                                  const SizedBox(width: 12),
                                  Text(
                                    '${offer.inventory} left',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            ElevatedButton(
                              onPressed: isAvailable && !rewardsState.isRedeeming
                                  ? () => _confirmRedeem(
                                        context,
                                        ref,
                                        offer.id,
                                        offer.title,
                                        offer.pointsCost,
                                      )
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.black,
                                minimumSize: const Size(110, 44),
                              ),
                              child: Text(
                                !inStock
                                    ? 'Out of Stock'
                                    : !canAfford
                                        ? 'Need Points'
                                        : 'Redeem',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              })
            else if (rewardsState.isLoading)
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
                    'No offers available in catalog right now.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _discountLabel(String type, double value) {
    switch (type) {
      case 'PERCENT':
        return '${value.toInt()}% OFF';
      case 'FIXED':
        return '\$${value.toStringAsFixed(0)} OFF';
      case 'FREE_ITEM':
        return 'FREE ITEM';
      default:
        return 'SPECIAL';
    }
  }
}
