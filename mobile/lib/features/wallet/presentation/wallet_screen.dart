import 'package:flutter/cupertino.dart';
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
    final link = 'https://stepsy.app/v/${voucher.shortCode}';
    final shareText = 'Redeem my ${voucher.offerTitle} voucher on Stepsy!\nCode: ${voucher.shortCode}\nLink: $link';

    try {
      if (!kIsWeb) {
        await Share.share(shareText, subject: 'Stepsy Voucher: ${voucher.offerTitle}');
      } else {
        await Clipboard.setData(ClipboardData(text: link));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Voucher link copied to clipboard'),
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
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.hairline,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Voucher pass',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.inkSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                voucher.offerTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.inkPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 20),

              // QR Code Container
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(color: AppTheme.hairline),
                  ),
                  child: QrImageView(
                    data: voucher.shortCode,
                    version: QrVersions.auto,
                    size: 190.0,
                    backgroundColor: Colors.transparent,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppTheme.inkPrimary,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppTheme.inkPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Short Code Box
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: voucher.shortCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Voucher code copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.hairline),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        voucher.shortCode,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                          color: AppTheme.inkPrimary,
                        ),
                      ),
                      const Icon(CupertinoIcons.doc_on_doc, size: 18, color: AppTheme.inkSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Present at checkout',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.inkSecondary,
                    ),
                  ),
                  Text(
                    'Expires ${DateFormat('MMM d, yyyy').format(voucher.expiresAt.toLocal())}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.inkSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _shareVoucher(context, voucher),
                  icon: const Icon(CupertinoIcons.share, size: 16),
                  label: const Text('Share voucher'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
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
      backgroundColor: AppTheme.surfaceMuted,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Wallet',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: AppTheme.inkPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: walletState.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentSolid),
                    ),
                  )
                : const Icon(CupertinoIcons.arrow_2_circlepath, size: 20, color: AppTheme.inkPrimary),
            onPressed: () => ref.read(walletProvider.notifier).refresh(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.accentSolid,
        backgroundColor: AppTheme.surface,
        onRefresh: () => ref.read(walletProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            // Status Tab Filter (Pill segmented control)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                border: Border.all(color: AppTheme.hairline),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildStatusSegment('active', 'Active', walletState.selectedStatus, ref),
                  _buildStatusSegment('redeemed', 'Used', walletState.selectedStatus, ref),
                  _buildStatusSegment('expired', 'Expired', walletState.selectedStatus, ref),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Voucher List
            if (vouchers.isNotEmpty)
              ...vouchers.map((v) {
                final isIssued = v.status == 'ISSUED';
                final isRedeemed = v.status == 'REDEEMED';
                final dateLabel = isRedeemed
                    ? 'Used: ${DateFormat('MMM d, yyyy').format(v.redeemedAt?.toLocal() ?? DateTime.now())}'
                    : 'Expires: ${DateFormat('MMM d, yyyy').format(v.expiresAt.toLocal())}';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(color: AppTheme.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentBright.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                                  ),
                                  child: Text(
                                    _discountLabel(v.offerDiscountType, v.offerDiscountValue),
                                    style: const TextStyle(
                                      color: AppTheme.accentSolid,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isIssued
                                        ? AppTheme.accentBright.withValues(alpha: 0.12)
                                        : AppTheme.surfaceMuted,
                                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                                  ),
                                  child: Text(
                                    v.status,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isIssued ? AppTheme.accentSolid : AppTheme.inkSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              v.offerTitle,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                                color: AppTheme.inkPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.inkSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Divider(color: AppTheme.hairline, height: 1),

                      // Code & Action Row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              v.shortCode,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: AppTheme.inkPrimary,
                              ),
                            ),
                            if (isIssued)
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () => _shareVoucher(context, v),
                                    icon: const Icon(CupertinoIcons.share, size: 18, color: AppTheme.inkSecondary),
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Share',
                                  ),
                                  const SizedBox(width: 4),
                                  SizedBox(
                                    height: 34,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _showVoucherQrModal(context, v),
                                      icon: const Icon(CupertinoIcons.qrcode, size: 15),
                                      label: const Text('Show QR'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
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
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentSolid),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.hairline),
                ),
                child: Text(
                  'No ${walletState.selectedStatus} vouchers',
                  style: const TextStyle(
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

  Widget _buildStatusSegment(String value, String label, String currentStatus, WidgetRef ref) {
    final isSelected = currentStatus == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticsService.selection();
          ref.read(walletProvider.notifier).fetchVouchers(value);
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
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? AppTheme.surface : AppTheme.inkSecondary,
            ),
          ),
        ),
      ),
    );
  }

  String _discountLabel(String type, double value) {
    switch (type) {
      case 'PERCENT':
        return '${value.toInt()}% OFF';
      case 'FIXED':
        return 'PKR ${value.toInt()} OFF';
      case 'FREE_ITEM':
        return 'FREE ITEM';
      default:
        return 'OFFER';
    }
  }
}
