import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/services/haptics_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/stepsy_ui.dart';
import '../../../data/models/voucher_models.dart';
import '../../rewards/presentation/reward_card.dart';
import '../../companion/companion_buddy.dart';
import '../providers/wallet_provider.dart';

class WalletScreen extends ConsumerStatefulWidget {
  final String? highlightId;
  final String? offerId;
  final bool recovered;
  const WalletScreen({
    super.key,
    this.highlightId,
    this.offerId,
    this.recovered = false,
  });
  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen>
    with WidgetsBindingObserver {
  int _locateRequest = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _locateHighlight();
    });
  }

  @override
  void didUpdateWidget(covariant WalletScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlightId != widget.highlightId ||
        oldWidget.offerId != widget.offerId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _locateHighlight();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(walletProvider.notifier).refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _locateHighlight() async {
    final id = widget.highlightId;
    if (id == null && widget.offerId == null) return;
    final request = ++_locateRequest;
    // A recovered purchase might already have been used or expired.
    for (final status in ['active', 'redeemed', 'expired', 'cancelled']) {
      await ref.read(walletProvider.notifier).fetchVouchers(status);
      if (!mounted || request != _locateRequest) return;
      final state = ref.read(walletProvider);
      if (state.errorMessage != null ||
          state.vouchers.any(
            (v) => v.id == id || v.offerId == widget.offerId,
          )) {
        return;
      }
    }
    if (mounted && request == _locateRequest) {
      await ref.read(walletProvider.notifier).fetchVouchers('active');
    }
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    HapticsService.selection();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Voucher code copied')));
    }
  }

  Future<void> _share(VoucherModel voucher) async {
    try {
      await Share.share(
        '${voucher.offerTitle}\nStepsy voucher: ${voucher.shortCode}\nPresent at the partner store before ${DateFormat('d MMM yyyy').format(voucher.expiresAt.toLocal())}.',
      );
    } catch (_) {
      if (mounted) await _copy(voucher.shortCode);
    }
  }

  void _showQr(VoucherModel voucher) {
    HapticsService.light();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Your little win.', style: AppTheme.largeTitleStyle),
              const CompanionGuide(
                clip: 'point',
                message:
                    'At the store? Let the team scan this code or enter it below.',
              ),
              const SizedBox(height: 8),
              Text(
                voucher.offerTitle,
                style: AppTheme.headlineStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.hairline),
                ),
                child: Semantics(
                  label:
                      'Voucher QR code. You can also give the store the code below.',
                  child: QrImageView(
                    data: voucher.shortCode,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: AppTheme.surface,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => _copy(voucher.shortCode),
                icon: const Icon(CupertinoIcons.doc_on_doc, size: 18),
                label: Text(
                  voucher.shortCode,
                  style: const TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontFeatures: AppTheme.tabular,
                    fontSize: 20,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Show this at checkout. The store confirms and uses your voucher once.',
                textAlign: TextAlign.center,
                style: AppTheme.captionStyle,
              ),
              const SizedBox(height: 8),
              Text(
                'Expires ${DateFormat('d MMM yyyy, h:mm a').format(voucher.expiresAt.toLocal())}',
                style: AppTheme.captionStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walletProvider);
    final vouchers = [...state.vouchers]
      ..sort((a, b) {
        if (a.id == widget.highlightId || a.offerId == widget.offerId) {
          return -1;
        }
        if (b.id == widget.highlightId || b.offerId == widget.offerId) return 1;
        return b.issuedAt.compareTo(a.issuedAt);
      });
    final highlighted = vouchers.any((v) => v.id == widget.highlightId);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My rewards'),
        actions: [
          IconButton(
            tooltip: 'Refresh my rewards',
            onPressed: state.isLoading
                ? null
                : () => ref.read(walletProvider.notifier).refresh(),
            icon: const Icon(CupertinoIcons.arrow_2_circlepath),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(walletProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Row(
              children: [
                CompanionBuddy(
                  size: 56,
                  clip: highlighted && !widget.recovered ? 'gift' : 'rest',
                  event: widget.highlightId.hashCode,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Your vouchers, ready when you are.',
                    style: AppTheme.headlineStyle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilterPills(
              options: const {'active': 'Ready', 'history': 'History'},
              selected: state.selectedStatus == 'active' ? 'active' : 'history',
              onSelected: (status) {
                _locateRequest++;
                ref
                    .read(walletProvider.notifier)
                    .fetchVouchers(status == 'active' ? 'active' : 'redeemed');
              },
            ),
            if (state.selectedStatus != 'active') ...[
              const SizedBox(height: 8),
              FilterPills(
                options: const {
                  'redeemed': 'Used',
                  'expired': 'Expired',
                  'cancelled': 'Cancelled',
                },
                selected: state.selectedStatus,
                onSelected: (status) {
                  _locateRequest++;
                  HapticsService.selection();
                  ref.read(walletProvider.notifier).fetchVouchers(status);
                },
              ),
            ],
            const SizedBox(height: 20),
            if (highlighted)
              StatusNotice(
                widget.recovered
                    ? 'Purchase recovered. No extra points spent.'
                    : 'Reward unlocked. It’s right here.',
              ),
            if (highlighted && state.selectedStatus == 'active')
              const CompanionGuide(
                clip: 'point',
                message:
                    'Your reward is right here! Tap Show QR when you’re at the store.',
              ),
            if (state.errorMessage != null)
              StatusNotice(
                state.errorMessage!,
                onRetry: () => ref.read(walletProvider.notifier).refresh(),
              ),
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ...vouchers.map((v) {
              final ready =
                  v.status == 'ISSUED' && v.expiresAt.isAfter(DateTime.now());
              final used = v.status == 'REDEEMED';
              final cancelled = v.status == 'CANCELLED';
              final selected = v.id == widget.highlightId;
              return Container(
                key: ValueKey('voucher-${v.id}'),
                margin: const EdgeInsets.only(bottom: 18),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(
                    color: selected ? AppTheme.accentSolid : AppTheme.hairline,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                discountLabel(
                                  v.offerDiscountType,
                                  v.offerDiscountValue,
                                ),
                                style: AppTheme.largeTitleStyle.copyWith(
                                  color: ready
                                      ? AppTheme.accentDeep
                                      : AppTheme.inkSecondary,
                                  fontSize: 30,
                                ),
                              ),
                              Chip(
                                label: Text(
                                  ready
                                      ? 'Ready to use'
                                      : used
                                      ? 'Used'
                                      : cancelled
                                      ? 'Cancelled'
                                      : 'Expired',
                                ),
                                backgroundColor: ready
                                    ? AppTheme.mintWash
                                    : AppTheme.surfaceMuted,
                                side: BorderSide.none,
                                labelStyle: AppTheme.captionStyle.copyWith(
                                  color: AppTheme.accentDeep,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(v.offerTitle, style: AppTheme.headlineStyle),
                          const SizedBox(height: 8),
                          Text(
                            cancelled
                                ? 'Cancelled. Contact support if you need help with this reward.'
                                : used
                                ? v.redeemedAt == null
                                      ? 'Used in store'
                                      : 'Used ${DateFormat('d MMM yyyy').format(v.redeemedAt!.toLocal())}'
                                : 'Expires ${DateFormat('d MMM yyyy').format(v.expiresAt.toLocal())}',
                            style: AppTheme.captionStyle,
                          ),
                        ],
                      ),
                    ),
                    const TicketDivider(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            ready
                                ? 'Ready to use'
                                : cancelled
                                ? 'Cancelled'
                                : used
                                ? 'Used'
                                : 'Expired',
                            style: AppTheme.captionStyle,
                          ),
                          if (ready)
                            Wrap(
                              spacing: 4,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                IconButton(
                                  tooltip: 'Share voucher',
                                  onPressed: () => _share(v),
                                  icon: const Icon(
                                    CupertinoIcons.share,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                ElevatedButton.icon(
                                  onPressed: () => _showQr(v),
                                  icon: const Icon(
                                    CupertinoIcons.qrcode,
                                    size: 18,
                                  ),
                                  label: const Text('Show QR'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (!state.isLoading &&
                vouchers.isEmpty &&
                state.errorMessage == null)
              EmptyState(
                title: state.selectedStatus == 'active'
                    ? 'A space for your next win.'
                    : 'Nothing here yet.',
                message: state.selectedStatus == 'active'
                    ? 'Turn your points into something you’ll enjoy. Your vouchers will be waiting here.'
                    : state.selectedStatus == 'redeemed'
                    ? 'Rewards you use in store will appear here.'
                    : state.selectedStatus == 'cancelled'
                    ? 'Cancelled rewards stay here for your records.'
                    : 'Expired rewards will appear here.',
                action: 'Explore rewards',
                onAction: () => context.go('/rewards'),
              ),
          ],
        ),
      ),
    );
  }
}
