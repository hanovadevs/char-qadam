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
import '../../companion/companion_buddy.dart';
import '../../companion/experience_provider.dart';
import '../reward_goal.dart';
import 'reward_fireworks.dart';

class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});
  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  String _filter = 'all';
  String _search = '';
  String? _openedOffer;
  bool _redemptionIssue = false;
  int _redemptionEvent = 0;

  Future<void> _refreshAll() => Future.wait([
    ref.read(rewardsProvider.notifier).fetchOffers(),
    ref.read(pointsProvider.notifier).refresh(),
  ]);

  Future<void> _redeem(String offerId) async {
    setState(() {
      _redemptionIssue = false;
      _redemptionEvent++;
    });
    final notifier = ref.read(rewardsProvider.notifier);
    final result = await notifier.redeem(offerId);
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _redemptionIssue = true;
        _redemptionEvent++;
      });
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
    if (mounted && !result.isReplay) showRewardFireworks(context);
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
              const Row(
                children: [
                  CompanionBuddy(clip: 'gift', size: 76),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Make it yours.',
                      style: AppTheme.largeTitleStyle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(offer.title, style: AppTheme.headlineStyle),
              if (offer.partnerName != null)
                Text(offer.partnerName!, style: AppTheme.captionStyle),
              if (offer.minBasket != null && offer.minBasket! > 0)
                Text(
                  'Minimum spend Rs ${NumberFormat.decimalPattern().format(offer.minBasket)}',
                  style: AppTheme.bodyStyle,
                ),
              if (offer.endsAt != null)
                Text(
                  'Offer ends ${DateFormat('d MMM yyyy').format(offer.endsAt!.toLocal())}',
                  style: AppTheme.captionStyle,
                ),
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
                'One per account. Your voucher will be saved in My rewards. Show its QR code at the store to use it.',
                style: AppTheme.captionStyle,
              ),
              const SizedBox(height: 24),
              const CompanionGuide(
                clip: 'point',
                message:
                    'Happy with the terms? Confirm below. I’ll meet you in Wallet.',
              ),
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

  Future<void> _details(OfferModel offer) async {
    await showModalBottomSheet<void>(
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
              Row(
                children: [
                  const CompanionBuddy(size: 64, clip: 'point'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      offer.partnerName ?? 'Stepsy partner',
                      style: AppTheme.headlineStyle,
                    ),
                  ),
                ],
              ),
              Text(
                discountLabel(offer.discountType, offer.discountValue),
                style: AppTheme.largeTitleStyle,
              ),
              const SizedBox(height: 8),
              Text(offer.title, style: AppTheme.titleStyle),
              const SizedBox(height: 12),
              Text(
                '${offer.pointsCost} points · One per account',
                style: AppTheme.headlineStyle,
              ),
              if (offer.minBasket != null && offer.minBasket! > 0)
                Text(
                  'Minimum spend Rs ${NumberFormat.decimalPattern().format(offer.minBasket)}',
                  style: AppTheme.bodyStyle,
                ),
              if (offer.partnerLocation != null)
                Text(offer.partnerLocation!, style: AppTheme.bodyStyle),
              if (offer.endsAt != null)
                Text(
                  'Offer ends ${DateFormat('d MMM yyyy, h:mm a').format(offer.endsAt!.toLocal())}',
                  style: AppTheme.bodyStyle,
                ),
              const SizedBox(height: 12),
              Text(
                offer.description?.trim().isNotEmpty == true
                    ? offer.description!
                    : 'Show your issued voucher at the participating store. Check the branch and minimum spend before redeeming.',
                style: AppTheme.bodyStyle,
              ),
              const CompanionGuide(
                message:
                    'Check the branch and minimum spend. Your little treat should fit your plans.',
                clip: 'peek',
              ),
              const SizedBox(height: 16),
              if (eligibleReward(offer))
                OutlinedButton(
                  onPressed: () async {
                    try {
                      await ref
                          .read(experienceProvider.notifier)
                          .update(rewardId: offer.id);
                      if (mounted && sheetContext.mounted) {
                        Navigator.pop(sheetContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Walking goal saved on this phone. Stock and price are not reserved.',
                            ),
                          ),
                        );
                      }
                    } catch (_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not save your walking goal. Please try again.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Make this my walking goal'),
                ),
              const SizedBox(height: 12),
              if (offer.alreadyRedeemed)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    context.go('/wallet?offer=${offer.id}');
                  },
                  child: const Text('View voucher'),
                )
              else
                ElevatedButton(
                  onPressed:
                      !eligibleReward(offer) ||
                          (ref.read(pointsProvider).balanceData?.balance ??
                                  -1) <
                              offer.pointsCost
                      ? null
                      : () {
                          Navigator.pop(sheetContext);
                          _confirm(
                            offer,
                            ref.read(pointsProvider).balanceData!.balance,
                          );
                        },
                  child: Text('Redeem for ${offer.pointsCost} points'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
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
              (!o.alreadyRedeemed &&
                  balance != null &&
                  balance >= o.pointsCost &&
                  (o.inventory == null || o.inventory! > 0)));
    }).toList();
    final candidates = offers.where((o) => eligibleReward(o)).toList();
    final affordable = candidates
        .where((o) => balance != null && o.pointsCost <= balance)
        .toList();
    final guided = affordable.firstOrNull ?? candidates.firstOrNull;
    final requested = GoRouterState.of(context).uri.queryParameters['offer'];
    final requestKey =
        '$requested:${GoRouterState.of(context).uri.queryParameters['view']}';
    final target = state.offers.where((o) => o.id == requested).firstOrNull;
    if (target != null && requestKey != _openedOffer) {
      _openedOffer = requestKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _details(target);
      });
    }
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
            Row(
              children: [
                CompanionBuddy(
                  size: 52,
                  clip: state.isRedeeming
                      ? 'wait'
                      : _redemptionIssue
                      ? 'reassure'
                      : 'rest',
                  event: _redemptionEvent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    balance == null
                        ? 'Checking your points'
                        : '${NumberFormat.decimalPattern().format(balance)} points available',
                    style: AppTheme.headlineStyle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
              options: const {
                'all': 'Explore all',
                'ready': 'Within my points',
              },
              selected: _filter,
              onSelected: (value) => setState(() => _filter = value),
            ),
            if (state.isRedeeming)
              CompanionGuide(
                clip: 'gift',
                event: _redemptionEvent,
                message: 'Saving your voucher. Just a little moment…',
              )
            else if (_redemptionIssue)
              CompanionGuide(
                clip: 'reassure',
                event: _redemptionEvent,
                message:
                    'Let’s check the message below. I’m here when you’re ready to try again.',
              )
            else if (guided != null)
              CompanionGuide(
                clip: affordable.isNotEmpty ? 'gift' : 'point',
                event: guided.id.hashCode,
                message: affordable.isNotEmpty
                    ? 'A little treat is within reach. Let’s check its terms!'
                    : 'Found something you love? We can make it your walking goal.',
                actionLabel: affordable.isNotEmpty
                    ? 'Help me choose'
                    : 'Find my next goal',
                onAction: () => _details(guided),
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
                  onDetails: () => _details(offer),
                  onClaimed: () => context.go('/wallet?offer=${offer.id}'),
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
