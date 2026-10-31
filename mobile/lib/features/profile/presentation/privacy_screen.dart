import 'package:flutter/material.dart';
import '../../../core/config/env_config.dart';
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Privacy & your data')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      Text('Stepsy', style: Theme.of(context).textTheme.headlineSmall),
      if (EnvConfig.publisherName.isNotEmpty) Text('Operated by ${EnvConfig.publisherName}'),
      const SizedBox(height: 16),
      const Text('Step data', style: TextStyle(fontWeight: FontWeight.bold)),
      const Text('With your permission, Stepsy reads steps from your phone sensor, Health Connect or Apple Health. Daily step totals, dates and their source are sent to our backend to calculate rewards, show history and rankings, and prevent misuse. Background syncing is best effort. We do not collect GPS routes or sell health data. Health Connect data is used only for the app features you choose.'),
      const SizedBox(height: 16),
      const Text('Account and support', style: TextStyle(fontWeight: FontWeight.bold)),
      const Text('We store your account email, country, timezone, points and voucher transactions, and support messages. Google provides optional sign-in. Our hosting provider runs the backend, and Supabase stores application data.'),
      const SizedBox(height: 16),
      const Text('Optional AI and notifications', style: TextStyle(fontWeight: FontWeight.bold)),
      const Text('If you choose AI help, your question and app FAQ context are sent to OpenAI. Your step history, account profile and voucher codes are not automatically sent. Provider processing and safety retention may apply. Do not include passwords or sensitive health details. Notifications are optional, limited, and quiet overnight; progress numbers are hidden by default.'),
      const SizedBox(height: 16),
      const Text('Delete and control your data', style: TextStyle(fontWeight: FontWeight.bold)),
      const Text('You can revoke health and notification permissions in device settings. Profile → Delete account erases profile identifiers, synced step history and support conversations, cancels active vouchers, and revokes access. Anonymized transaction and security records may remain for accounting and abuse prevention. Health records held by your phone are managed through Health Connect or Apple Health. Device caches are cleared on sign-out.'),
      const SizedBox(height: 16),
      if (EnvConfig.supportEmail.isNotEmpty) SelectableText('Privacy and deletion contact: ${EnvConfig.supportEmail}'),
      if (EnvConfig.privacyPolicyUrl.isNotEmpty) SelectableText('Full privacy policy: ${EnvConfig.privacyPolicyUrl}'),
      if (EnvConfig.accountDeletionUrl.isNotEmpty) SelectableText('Web deletion requests: ${EnvConfig.accountDeletionUrl}'),
      const SizedBox(height: 16), const Text('Stepsy is a walking rewards app, not a medical service.'),
    ]));
}
