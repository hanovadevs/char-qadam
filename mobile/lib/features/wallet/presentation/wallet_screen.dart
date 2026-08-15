import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../data/models/voucher_models.dart';
import '../providers/wallet_provider.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  void _showVoucherQrModal(BuildContext context, VoucherModel voucher) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                voucher.offerTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _discountLabel(voucher.offerDiscountType, voucher.offerDiscountValue),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(height: 24),

              // QR Code Container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: voucher.shortCode,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              // Short Code Box
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: voucher.shortCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Voucher short code copied to clipboard!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        voucher.shortCode,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.copy, size: 18, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Show this QR code or short code to cashier at checkout',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 8),
              Text(
                'Expires on ${DateFormat('MMM d, yyyy').format(voucher.expiresAt.toLocal())}',
                style: const TextStyle(fontSize: 12, color: Color(0xFFF59E0B)),
              ),
              const SizedBox(height: 20),
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
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.confirmation_number, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('My Wallet'),
          ],
        ),
        actions: [
          IconButton(
            icon: walletState.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: () => ref.read(walletProvider.notifier).refresh(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(walletProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Status Tab Filter
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'active', label: Text('Active')),
                ButtonSegment(value: 'redeemed', label: Text('Redeemed')),
                ButtonSegment(value: 'expired', label: Text('Expired')),
              ],
              selected: {walletState.selectedStatus},
              onSelectionChanged: (Set<String> selection) {
                ref.read(walletProvider.notifier).fetchVouchers(selection.first);
              },
            ),
            const SizedBox(height: 20),

            // Voucher List
            if (vouchers.isNotEmpty)
              ...vouchers.map((v) {
                final isIssued = v.status == 'ISSUED';
                final isRedeemed = v.status == 'REDEEMED';
                final dateLabel = isRedeemed
                    ? 'Redeemed ${DateFormat('MMM d, yyyy').format(v.redeemedAt?.toLocal() ?? DateTime.now())}'
                    : 'Expires ${DateFormat('MMM d, yyyy').format(v.expiresAt.toLocal())}';

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _discountLabel(v.offerDiscountType, v.offerDiscountValue),
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _statusColor(v.status).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                v.status,
                                style: TextStyle(
                                  color: _statusColor(v.status),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          v.offerTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dateLabel,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              v.shortCode,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                            if (isIssued)
                              ElevatedButton.icon(
                                onPressed: () => _showVoucherQrModal(context, v),
                                icon: const Icon(Icons.qr_code, size: 18),
                                label: const Text('Show QR'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.black,
                                  minimumSize: const Size(110, 40),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              })
            else if (walletState.isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.confirmation_number_outlined,
                          size: 48, color: Color(0xFF64748B)),
                      const SizedBox(height: 12),
                      Text(
                        'No ${walletState.selectedStatus} vouchers found.',
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                    ],
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
        return 'VOUCHER';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ISSUED':
        return const Color(0xFF10B981);
      case 'REDEEMED':
        return const Color(0xFF6366F1);
      case 'EXPIRED':
        return const Color(0xFFF87171);
      default:
        return const Color(0xFF94A3B8);
    }
  }
}
