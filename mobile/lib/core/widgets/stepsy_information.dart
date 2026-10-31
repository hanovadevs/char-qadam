import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// In-app operational information; kept accessible without an authenticated API.
void showStepsyInformation(
  BuildContext context, {
  bool privacy = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            privacy ? 'Privacy & support' : 'Using Stepsy',
            style: AppTheme.largeTitleStyle,
          ),
          const SizedBox(height: 16),
          Text(
            privacy
                ? 'Stepsy uses your account details, device account reservation, eligible activity totals and reward records to operate your account and prevent duplicate rewards. Motion recognition helps exclude vehicle movement. Walking does not require a GPS route. Camera access is used when a merchant chooses to scan a voucher.\n\nYour personal points and vouchers remain with your customer account. A merchant account has its own store access. You can manage activity permissions in device settings, pause tracking from the notification, and request account deactivation in You.\n\nFor account, privacy or reward support: contact@hanovadevs.com.'
                : 'Use one customer account per phone. The same phone may also use one separate merchant account. Previously rewarded activity cannot earn points again through another account.\n\nPoints are confirmed by the server after eligible steps sync. Offers depend on partner availability, inventory and the displayed terms. Check the branch, minimum spend and expiry before redeeming. Each offer can be claimed once per account, and a store can use each voucher once.\n\nReview the confirmation before spending points. Your voucher is saved in Wallet. For a problem with an account or reward, contact contact@hanovadevs.com.',
            style: AppTheme.bodyStyle,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    ),
  ),
);
