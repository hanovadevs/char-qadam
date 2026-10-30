import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/haptics_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/auth/auth_state_provider.dart';
import '../../auth/presentation/sign_out_confirmation.dart';
import '../../../data/models/merchant_models.dart';
import '../providers/merchant_provider.dart';

class MerchantPosScreen extends ConsumerStatefulWidget {
  const MerchantPosScreen({super.key});

  @override
  ConsumerState<MerchantPosScreen> createState() => _MerchantPosScreenState();
}

class _MerchantPosScreenState extends ConsumerState<MerchantPosScreen> {
  final _codeController = TextEditingController();
  final _orderRefController = TextEditingController();
  final _storeIdController = TextEditingController(text: 'STORE-01');

  @override
  void initState() {
    super.initState();
    final state = ref.read(merchantProvider);
    _storeIdController.text = state.storeId;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _orderRefController.dispose();
    _storeIdController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    HapticsService.light();
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text!.isNotEmpty) {
      _codeController.text = data.text!.trim();
      _validateCode();
    }
  }

  Future<void> _scanVoucher() async {
    final value = await context.push<String>('/merchant-scan');
    if (!mounted || value == null) return;
    _codeController.text = value;
    await _validateCode();
  }

  Future<void> _validateCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    HapticsService.medium();
    await ref.read(merchantProvider.notifier).validateCode(code);
  }

  Future<void> _confirmRedemption() async {
    final orderRef = _orderRefController.text.trim();
    final success = await ref
        .read(merchantProvider.notifier)
        .confirmRedeem(orderReference: orderRef.isNotEmpty ? orderRef : null);

    if (success) {
      HapticsService.heavy();
      _codeController.clear();
      _orderRefController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(merchantProvider);
    final authState = ref.watch(authStateProvider);
    final partner = state.partnerInfo;
    final validation = state.activeValidation;

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              partner?.name.toUpperCase() ?? 'MERCHANT POS TERMINAL',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppTheme.black,
              ),
            ),
            Text(
              authState.user?.email ?? 'VOUCHER VALIDATION & REDEMPTION',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
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
            tooltip: 'Merchant ledgers',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => context.push('/merchant-ledgers'),
          ),
          PopupMenuButton<String>(
            tooltip: 'Account options',
            onSelected: (value) async {
              if (value == 'customer' || value == 'signout') {
                await confirmSignOut(context, ref);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'customer',
                child: Text('Use customer account'),
              ),
              const PopupMenuItem(value: 'signout', child: Text('Sign out')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: state.isLoading && partner == null
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.black,
                        ),
                      ),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'CONNECTING TO TERMINAL...',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: AppTheme.monoFont,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: AppTheme.grey,
                      ),
                    ),
                  ],
                ),
              )
            : partner == null && state.errorMessage != null
            ? _buildErrorView(state)
            : _buildTerminalView(
                state,
                partner ??
                    PartnerInfoModel(
                      partnerId: authState.user?.partnerId ?? '',
                      name: authState.user?.partnerName ?? 'Merchant Store',
                      status: 'ACTIVE',
                    ),
                validation,
              ),
      ),
    );
  }

  Widget _buildErrorView(MerchantState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 36,
              color: AppTheme.accentRed,
            ),
            const SizedBox(height: 14),
            Text(
              state.errorMessage ?? 'Merchant terminal error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.black,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () =>
                  ref.read(merchantProvider.notifier).loadPartnerInfo(),
              child: const Text('RETRY'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => confirmSignOut(context, ref),
              child: const Text('SIGN OUT'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTerminalView(
    MerchantState state,
    PartnerInfoModel partner,
    VoucherValidationModel? validation,
  ) {
    final authState = ref.watch(authStateProvider);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Store Context Header (Swiss Beige Surface)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.beige,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: AppTheme.borderDark),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partner.name.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: AppTheme.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'TERMINAL: ${state.storeId} • ${authState.user?.email ?? "ONLINE"}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontFamily: AppTheme.monoFont,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.grey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.black,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(
                    fontSize: 9,
                    fontFamily: AppTheme.monoFont,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Error / Success Banners
        if (state.errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppTheme.accentRed, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppTheme.accentRed,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.errorMessage!,
                    style: const TextStyle(
                      color: AppTheme.accentRed,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (state.successMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.offWhite,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppTheme.black, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: AppTheme.black,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.successMessage!,
                    style: const TextStyle(
                      color: AppTheme.black,
                      fontFamily: AppTheme.monoFont,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Voucher Code Entry Section
        FilledButton.icon(
          onPressed: state.isLoading ? null : _scanVoucher,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan customer QR'),
        ),
        const SizedBox(height: 12),
        const Text(
          'SCAN OR ENTER CUSTOMER VOUCHER CODE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: AppTheme.grey,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  fontFamily: AppTheme.monoFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 1.5,
                ),
                decoration: const InputDecoration(hintText: 'SR-XXXX-XXXX'),
                onFieldSubmitted: (_) => _validateCode(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              width: 48,
              child: OutlinedButton(
                onPressed: _pasteFromClipboard,
                style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                child: const Icon(Icons.content_paste, size: 18),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        ElevatedButton(
          onPressed: state.isLoading ? null : _validateCode,
          child: state.isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.white),
                  ),
                )
              : const Text('VALIDATE VOUCHER'),
        ),
        const SizedBox(height: 16),

        // Validation Preview Card (If validated)
        if (validation != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.beige,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppTheme.borderDark, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.black,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Text(
                        validation.discountDisplay,
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: AppTheme.monoFont,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.white,
                        ),
                      ),
                    ),
                    Text(
                      'CODE: ${validation.shortCode}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: AppTheme.monoFont,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  validation.offerTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'EXPIRES: ${DateFormat('dd MMM yyyy, hh:mm a').format(validation.expiresAt)}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: AppTheme.monoFont,
                    color: AppTheme.grey,
                  ),
                ),
                const SizedBox(height: 14),

                // Order Reference Input
                const Text(
                  'STORE ORDER / RECEIPT REFERENCE (OPTIONAL)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: AppTheme.grey,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _orderRefController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. RECEIPT #84920',
                    fillColor: AppTheme.white,
                  ),
                ),
                const SizedBox(height: 14),

                ElevatedButton(
                  onPressed: state.isRedeeming ? null : _confirmRedemption,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.black,
                    foregroundColor: AppTheme.white,
                  ),
                  child: state.isRedeeming
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.white,
                            ),
                          ),
                        )
                      : const Text('CONFIRM REDEMPTION AT POS'),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => ref
                      .read(merchantProvider.notifier)
                      .clearActiveValidation(),
                  child: const Text(
                    'CANCEL VALIDATION',
                    style: TextStyle(color: AppTheme.grey, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Recent In-Store Redemptions List
        if (state.history.isNotEmpty) ...[
          const Text(
            'TODAY\'S IN-STORE REDEMPTIONS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: AppTheme.black,
            ),
          ),
          const SizedBox(height: 8),
          ...state.history.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.shortCode,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: AppTheme.monoFont,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.orderReference != null
                            ? 'REF: ${item.orderReference} • ${DateFormat('hh:mm a').format(item.redeemedAt)}'
                            : DateFormat(
                                'dd MMM, hh:mm a',
                              ).format(item.redeemedAt),
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: AppTheme.monoFont,
                          color: AppTheme.grey,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.offWhite,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Text(
                      'REDEEMED',
                      style: TextStyle(
                        fontSize: 9,
                        fontFamily: AppTheme.monoFont,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.taupe,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}
