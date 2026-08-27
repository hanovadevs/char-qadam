import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/merchant_provider.dart';

class MerchantPosScreen extends ConsumerStatefulWidget {
  const MerchantPosScreen({super.key});

  @override
  ConsumerState<MerchantPosScreen> createState() => _MerchantPosScreenState();
}

class _MerchantPosScreenState extends ConsumerState<MerchantPosScreen> {
  final _codeController = TextEditingController();
  final _orderRefController = TextEditingController();

  final _apiKeyController = TextEditingController();
  final _storeIdController = TextEditingController(text: 'STORE-01');

  @override
  void dispose() {
    _codeController.dispose();
    _orderRefController.dispose();
    _apiKeyController.dispose();
    _storeIdController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text!.isNotEmpty) {
      _codeController.text = data.text!.trim().toUpperCase();
      _validateCode();
    }
  }

  Future<void> _validateCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    await ref.read(merchantProvider.notifier).validateCode(code);
  }

  Future<void> _confirmRedemption() async {
    final orderRef = _orderRefController.text.trim();
    final success = await ref.read(merchantProvider.notifier).confirmRedeem(
          orderReference: orderRef.isNotEmpty ? orderRef : null,
        );

    if (success) {
      _codeController.clear();
      _orderRefController.clear();
    }
  }

  Future<void> _saveCredentials() async {
    final key = _apiKeyController.text.trim();
    final store = _storeIdController.text.trim();
    if (key.isEmpty) return;

    await ref.read(merchantProvider.notifier).setCredentials(
          apiKey: key,
          storeId: store.isNotEmpty ? store : 'STORE-01',
        );
  }

  void _useTestCredentials() {
    _apiKeyController.text = 'demo-partner-api-key';
    _storeIdController.text = 'STORE-MAIN';
    _saveCredentials();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(merchantProvider);
    final partner = state.partnerInfo;
    final validation = state.activeValidation;

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MERCHANT POS TERMINAL',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppTheme.black,
              ),
            ),
            Text(
              'VOUCHER VALIDATION & REDEMPTION',
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
          if (state.partnerApiKey != null)
            IconButton(
              icon: const Icon(Icons.logout, size: 18, color: AppTheme.black),
              tooltip: 'Disconnect Terminal',
              onPressed: () => ref.read(merchantProvider.notifier).disconnectTerminal(),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: state.partnerApiKey == null || partner == null
            ? _buildConfigView(state)
            : _buildTerminalView(state, partner, validation),
      ),
    );
  }

  Widget _buildConfigView(MerchantState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'TERMINAL SETUP',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              color: AppTheme.black,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Authenticate your POS terminal with your store partner API key.',
            style: TextStyle(color: AppTheme.grey, fontSize: 12),
          ),
          const SizedBox(height: 20),

          if (state.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppTheme.accentRed),
              ),
              child: Text(
                state.errorMessage!,
                style: const TextStyle(color: AppTheme.accentRed, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
          ],

          const Text(
            'PARTNER API KEY',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: AppTheme.grey),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _apiKeyController,
            decoration: const InputDecoration(
              hintText: 'Enter X-Partner-Key token',
            ),
          ),
          const SizedBox(height: 14),

          const Text(
            'STORE / BRANCH IDENTIFIER',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: AppTheme.grey),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _storeIdController,
            decoration: const InputDecoration(
              hintText: 'STORE-01',
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: state.isLoading ? null : _saveCredentials,
            child: state.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.white),
                    ),
                  )
                : const Text('CONNECT TERMINAL'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _useTestCredentials,
            child: const Text('AUTO-CONNECT DEMO TERMINAL'),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalView(
    MerchantState state,
    partner,
    validation,
  ) {
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
              Column(
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
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'STORE ID: ${state.storeId} • STATUS: READY',
                    style: const TextStyle(
                      fontSize: 10,
                      fontFamily: AppTheme.monoFont,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.grey,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.black,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Text(
                  'ONLINE',
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
                const Icon(Icons.error_outline, color: AppTheme.accentRed, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.errorMessage!,
                    style: const TextStyle(color: AppTheme.accentRed, fontSize: 11, fontWeight: FontWeight.w700),
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
                const Icon(Icons.check_circle_outline, color: AppTheme.black, size: 18),
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
                decoration: const InputDecoration(
                  hintText: 'SR-XXXX-XXXX',
                ),
                onFieldSubmitted: (_) => _validateCode(),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _pasteFromClipboard,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              child: const Icon(Icons.content_paste, size: 18),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.white),
                          ),
                        )
                      : const Text('CONFIRM REDEMPTION AT POS'),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => ref.read(merchantProvider.notifier).clearActiveValidation(),
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
                            : DateFormat('dd MMM, hh:mm a').format(item.redeemedAt),
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: AppTheme.monoFont,
                          color: AppTheme.grey,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
