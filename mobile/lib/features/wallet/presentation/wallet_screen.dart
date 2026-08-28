import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/services/haptics_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/voucher_models.dart';
import '../providers/wallet_provider.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  Future<void> _shareVoucher(BuildContext context, VoucherModel voucher) async {
    HapticsService.light();
    final link = 'https://walknsave.app/v/${voucher.shortCode}';
    final shareText = 'Redeem my ${voucher.offerTitle} voucher on Walk n Save!\nCode: ${voucher.shortCode}\nLink: $link';

    try {
      if (!kIsWeb) {
        await Share.share(shareText, subject: 'Walk n Save Voucher: ${voucher.offerTitle}');
      } else {
        await Clipboard.setData(ClipboardData(text: link));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Voucher link copied to clipboard!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: link));
    }
  }

  void _showVoucherQrModal(BuildContext context, VoucherModel voucher) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusMd)),
        side: BorderSide(color: AppTheme.borderDark, width: 1),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppTheme.borderDark,
                    borderRadius: BorderRadius.circular(AppTheme.radiusNone),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'VOUCHER PASS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: AppTheme.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                voucher.offerTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.black,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 18),

              // QR Code High Contrast Box (Swiss Sharp Square Light)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.beige,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: AppTheme.borderDark, width: 1),
                  ),
                  child: QrImageView(
                    data: voucher.shortCode,
                    version: QrVersions.auto,
                    size: 180.0,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Short Code Copy Box
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: voucher.shortCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Voucher short code copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.offWhite,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        voucher.shortCode,
                        style: const TextStyle(
                          fontSize: 18,
                          fontFamily: AppTheme.monoFont,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                          color: AppTheme.black,
                        ),
                      ),
                      const Icon(Icons.copy, size: 16, color: AppTheme.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'PRESENT QR AT POS CHECKOUT',
                    style: TextStyle(
                      fontSize: 9,
                      fontFamily: AppTheme.monoFont,
                      color: AppTheme.grey,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'EXP: ${DateFormat('yyyy-MM-dd').format(voucher.expiresAt.toLocal())}',
                    style: const TextStyle(
                      fontSize: 9,
                      fontFamily: AppTheme.monoFont,
                      color: AppTheme.grey,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _shareVoucher(context, voucher),
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text('SHARE VOUCHER PASS LINK'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletState = ref.watch(walletProvider);
    final vouchers = walletState.vouchers;

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MY WALLET',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppTheme.black,
              ),
            ),
            Text(
              'REDEEMED PROMOS & PASSES',
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
            icon: walletState.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.black),
                    ),
                  )
                : const Icon(Icons.refresh, size: 20, color: AppTheme.black),
            onPressed: () => ref.read(walletProvider.notifier).refresh(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.black,
        backgroundColor: AppTheme.white,
        onRefresh: () => ref.read(walletProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          children: [
            // Status Tab Filter (Swiss Segmented Button)
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'active', label: Text('ACTIVE')),
                ButtonSegment(value: 'redeemed', label: Text('USED')),
                ButtonSegment(value: 'expired', label: Text('EXPIRED')),
              ],
              selected: {walletState.selectedStatus},
              onSelectionChanged: (Set<String> selection) {
                ref.read(walletProvider.notifier).fetchVouchers(selection.first);
              },
            ),
            const SizedBox(height: 14),

            // Voucher List
            if (vouchers.isNotEmpty)
              ...vouchers.map((v) {
                final isIssued = v.status == 'ISSUED';
                final isRedeemed = v.status == 'REDEEMED';
                final dateLabel = isRedeemed
                    ? 'USED: ${DateFormat('yyyy-MM-dd HH:mm').format(v.redeemedAt?.toLocal() ?? DateTime.now())}'
                    : 'EXPIRES: ${DateFormat('yyyy-MM-dd').format(v.expiresAt.toLocal())}';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.black,
                                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                  ),
                                  child: Text(
                                    _discountLabel(v.offerDiscountType, v.offerDiscountValue),
                                    style: const TextStyle(
                                      color: AppTheme.white,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: AppTheme.monoFont,
                                      fontSize: 10,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                Text(
                                  v.status,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontFamily: AppTheme.monoFont,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.grey,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              v.offerTitle,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                color: AppTheme.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateLabel,
                              style: const TextStyle(
                                fontSize: 10,
                                fontFamily: AppTheme.monoFont,
                                color: AppTheme.grey,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Divider(color: AppTheme.border, height: 1),

                      // Action Row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              v.shortCode,
                              style: const TextStyle(
                                fontSize: 14,
                                fontFamily: AppTheme.monoFont,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: AppTheme.black,
                              ),
                            ),
                            if (isIssued)
                              Row(
                                children: [
                                  SizedBox(
                                    height: 32,
                                    width: 36,
                                    child: OutlinedButton(
                                      onPressed: () => _shareVoucher(context, v),
                                      style: OutlinedButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                      ),
                                      child: const Icon(Icons.share, size: 14),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  SizedBox(
                                    height: 32,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _showVoucherQrModal(context, v),
                                      icon: const Icon(Icons.qr_code, size: 14),
                                      label: const Text('SHOW QR'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        textStyle: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              })
            else if (walletState.isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.black),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(vertical: 28),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  'NO ${walletState.selectedStatus.toUpperCase()} PASSES FOUND',
                  style: const TextStyle(
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

  String _discountLabel(String type, double value) {
    switch (type) {
      case 'PERCENT':
        return '${value.toInt()}% OFF';
      case 'FIXED':
        return 'Rs. ${value.toInt()} OFF';
      case 'FREE_ITEM':
        return 'FREE ITEM';
      default:
        return 'OFFER';
    }
  }
}
