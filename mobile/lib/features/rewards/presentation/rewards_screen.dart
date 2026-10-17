import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/haptics_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/stepsy_ui.dart';
import '../../../data/models/offer_models.dart';
import '../../points/providers/points_provider.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../providers/rewards_provider.dart';
import 'reward_card.dart';

class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});
  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  String _filter = 'all';
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshAll();
    });
  }

  Future<void> _refreshAll() => Future.wait([
    ref.read(rewardsProvider.notifier).fetchOffers(),
    ref.read(pointsProvider.notifier).refresh(),
  ]);

  Future<void> _redeem(String offerId) async {
    final notifier = ref.read(rewardsProvider.notifier);
    final result = await notifier.redeem(offerId);
    if (!mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(rewardsProvider).errorMessage ??
                'Could not get this reward. Please try again.',
          ),
        ),
      );
      return;
    }
    HapticsService.light();
    // Select active even when Wallet was previously left on Used or Expired.
    ref.read(walletProvider.notifier).fetchVouchers('active');
    context.go(
      Uri(
        path: '/wallet',
        queryParameters: {
          'highlight': result.voucherId,
          if (result.isReplay) 'recovered': 'true',
        },
      ).toString(),
    );
    await WidgetsBinding.instance.endOfFrame;
    await notifier.acknowledgePurchase(offerId, result.requestKey);
  }

  Future<void> _confirm(OfferModel offer, int balance) async {
    HapticsService.light();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                CupertinoIcons.ticket,
                size: 32,
                color: AppTheme.accentDeep,
              ),
              const SizedBox(height: 16),
              const Text('Make it yours.', style: AppTheme.largeTitleStyle),
              const SizedBox(height: 10),
              Text(offer.title, style: AppTheme.headlineStyle),
              if (offer.partnerName != null)
                Text(offer.partnerName!, style: AppTheme.captionStyle),
              const SizedBox(height: 24),
              SurfaceCard(
                color: AppTheme.mintWash,
                child: Column(
                  children: [
                    _math('Your balance', balance),
                    const SizedBox(height: 12),
                    _math('This reward', -offer.pointsCost),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(),
                    ),
                    _math('After redemption', balance - offer.pointsCost),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your voucher will be saved in My rewards. Show its QR code at the store to use it.',
                style: AppTheme.captionStyle,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: const Text('Confirm & redeem'),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  child: const Text('Not now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true && mounted) await _redeem(offer.id);
  }

  Widget _math(String label, int amount) => Row(
    children: [
      Expanded(child: Text(label, style: AppTheme.captionStyle)),
      Text(
        '${NumberFormat('#,###').format(amount)} pts',
        style: AppTheme.headlineStyle.copyWith(fontFeatures: AppTheme.tabular),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rewardsProvider);
    final points = ref.watch(pointsProvider);
    final balance = points.balanceData?.balance;
    final offers = state.offers.where((o) {
      final text =
          '${o.title} ${o.partnerName ?? ''} ${o.partnerLocation ?? ''}'
              .toLowerCase();
      return text.contains(_search.toLowerCase()) &&
          (_filter != 'ready' ||
              (balance != null &&
                  balance >= o.pointsCost &&
                  (o.inventory == null || o.inventory! > 0)));
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rewards'),
        actions: [
          IconButton(
            tooltip: 'My rewards',
            onPressed: () => context.go('/wallet'),
            icon: const Icon(CupertinoIcons.ticket),
          ),
          IconButton(
            tooltip: 'Refresh rewards',
            onPressed: state.isLoading ? null : _refreshAll,
            icon: const Icon(CupertinoIcons.arrow_2_circlepath),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            const Text(
              'Good things.\nEarned on foot.',
              style: AppTheme.largeTitleStyle,
            ),
            const SizedBox(height: 12),
            const Text(
              'Your everyday steps, a little more rewarding.',
              style: AppTheme.captionStyle,
            ),
            const SizedBox(height: 24),
            SurfaceCard(
              color: AppTheme.accentDeep,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yours to spend',
                        style: AppTheme.captionStyle.copyWith(
                          color: AppTheme.onDeep,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        balance == null
                            ? '— pts'
                            : '${NumberFormat('#,###').format(balance)} pts',
                        style: AppTheme.largeTitleStyle.copyWith(
                          color: AppTheme.surface,
                          fontFeatures: AppTheme.tabular,
                        ),
                      ),
                    ],
                  ),
                  const Icon(
                    CupertinoIcons.sparkles,
                    size: 36,
                    color: AppTheme.accentBright,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              onChanged: (value) => setState(() => _search = value),
              decoration: const InputDecoration(
                hintText: 'Find a reward or brand',
                prefixIcon: Icon(CupertinoIcons.search),
                labelText: 'Search rewards',
              ),
            ),
            const SizedBox(height: 16),
            FilterPills(
              options: const {'all': 'Explore all', 'ready': 'Ready for you'},
              selected: _filter,
              onSelected: (value) => setState(() => _filter = value),
            ),
            const SizedBox(height: 20),
            if (points.errorMessage != null)
              StatusNotice(points.errorMessage!, onRetry: _refreshAll),
            if (state.errorMessage != null)
              StatusNotice(state.errorMessage!, onRetry: _refreshAll),
            for (final entry in state.pendingPurchases.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Let’s finish that reward.',
                        style: AppTheme.headlineStyle,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'A previous purchase needs confirmation. Recover it safely without paying twice.',
                        style: AppTheme.captionStyle,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: state.isRedeeming
                            ? null
                            : () => _redeem(entry.key),
                        child: const Text('Recover purchase'),
                      ),
                    ],
                  ),
                ),
              ),
            if (state.isLoading && state.offers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (offers.isEmpty)
              EmptyState(
                title: _search.isNotEmpty
                    ? 'No matches yet'
                    : _filter == 'ready'
                    ? 'Your next reward is ahead.'
                    : 'Good things are on the way.',
                message: _filter == 'ready'
                    ? 'Keep collecting points, or explore everything you can work towards.'
                    : _search.isNotEmpty
                    ? 'Try a different brand, location or reward.'
                    : 'Partner offers will appear here when they’re available.',
              )
            else
              ...offers.map(
                (offer) => RewardCard(
                  offer: offer,
                  balance: balance,
                  busy: state.isRedeeming,
                  onRedeem: () => _confirm(offer, balance!),
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Pick a reward, check its terms, then show your voucher in store.',
              textAlign: TextAlign.center,
              style: AppTheme.captionStyle,
            ),
          ],
        ),
      ),
    );
  }
}
