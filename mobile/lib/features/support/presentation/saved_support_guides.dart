/// Useful without a network connection; server answers replace these when loaded.
const savedSupportGuides = <Map<String, String>>[
  {
    'id': 'missing_steps',
    'question': 'My steps have stopped. What should I check?',
    'answer':
        'Open Steps and check whether tracking is paused. Choose Resume tracking if needed. Allow Physical Activity permission and open Tracking help for your phone’s background settings. On Redmi, check Autostart and No restrictions. Keep the phone with you while walking.',
  },
  {
    'id': 'earning',
    'question': 'Why have my points not changed yet?',
    'answer':
        'Steps appear live, while the server confirms points after syncing. Connect to the internet and refresh Steps. Check the earning rules shown in the app; only eligible activity within the daily cap earns points.',
  },
  {
    'id': 'redeem',
    'question': 'How do I claim and use a reward?',
    'answer':
        'Open Rewards, check the brand, branch, terms and points cost, then confirm the claim. Your voucher appears in Wallet. Show it to the participating store. Each offer can be claimed once per account, and each voucher can be used once.',
  },
  {
    'id': 'expiry',
    'question': 'Where can I check a voucher’s expiry?',
    'answer':
        'Open Wallet and select the voucher. Use the expiry and status shown there. A used or expired voucher cannot be used again. If something looks wrong, send the team a message before claiming another offer.',
  },
  {
    'id': 'sync',
    'question': 'What works without internet?',
    'answer':
        'These saved guides are available offline. Some previously loaded activity and rewards may also remain visible. Connect to confirm points, claim a reward or send a support message. Check your current tracking status on Steps.',
  },
  {
    'id': 'account',
    'question': 'Can I use a customer and merchant account?',
    'answer':
        'A phone can be linked to one active customer account and one separate merchant account. Your customer points and vouchers belong to the customer account. Sign out deliberately before changing accounts; never share your password or voucher QR code.',
  },
];

String supportGuideCategory(String id) => switch (id) {
  'missing_steps' || 'paused' || 'vehicle' => 'Steps',
  'earning' || 'sync' => 'Points',
  'redeem' || 'expiry' || 'claim_once' => 'Rewards',
  'account' || 'delete' || 'merchant_account' => 'Account',
  _ => 'All',
};
