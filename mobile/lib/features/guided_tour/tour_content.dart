class TourStop {
  final int tab;
  final String? target;
  final String chapter, title, message, clip;
  const TourStop(
    this.tab,
    this.target,
    this.chapter,
    this.title,
    this.message, {
    this.clip = 'point',
  });
}

/// Product explanations, never simulated purchases or permission prompts.
const tourStops = [
  TourStop(
    0,
    null,
    'Make yourself at home',
    'Shall we take a little tour?',
    'I’m your Stepsy walking companion! I’ll show you how your walks become eligible points, how to choose a partner discount, and how to use your voucher in store. I’ll light up each section as we go. Take your time, go back whenever you like, or skip and replay this tour from You.',
    clip: 'wave',
  ),
  TourStop(
    0,
    'navigation',
    'Finding your way',
    'Five little places to know.',
    'Steps is your daily walk, Points is your balance, Rewards is where you discover offers, Wallet keeps your vouchers, and You holds your preferences and account controls. I’ll move between these pages for you during our tour. The highlighted controls are for looking at; Next takes us onward.',
  ),
  TourStop(
    0,
    'steps.total',
    'Your daily walk',
    'Your steps, as you walk.',
    'This is today’s step total. Your phone’s motion sensor updates it live, so you don’t need to refresh after every step. Keep your phone with you when walking. Motion detection helps exclude bike and car movement, though accuracy depends on your phone and permissions.',
  ),
  TourStop(
    0,
    'steps.goal',
    'Your daily walk',
    'Choose a goal that feels like you.',
    'This ring shows how close you are to your personal daily step goal. Tap it after the tour to choose a comfortable target and manage my animations and tips. A personal goal is for your progress; changing it doesn’t change the rules or daily cap for earning points.',
  ),
  TourStop(
    0,
    'steps.trail',
    'Your daily walk',
    'A little company on the trail.',
    'I walk along this trail when your phone detects recent steps, then rest when you stop. The bar and remaining-step label show your progress toward today’s goal. You can tap me for a little reaction! Reduced motion and my animation preferences are respected throughout the app.',
    clip: 'love',
  ),
  TourStop(
    0,
    'steps.sync',
    'Your daily walk',
    'Live steps and confirmed points.',
    'Steps can appear before points do. Syncing sends eligible activity to Stepsy so your points can be confirmed. This line shows sync progress or a problem that needs attention. Pull down on Steps, or tap this sync line when available, to try again. An offline count is not a promise of credited points.',
  ),
  TourStop(
    0,
    'steps.reward',
    'Your daily walk',
    'Keep a little win in sight.',
    'This card brings a partner offer into your daily walk. In an offer’s details, choose Make this my walking goal to pin it here and watch your points progress. Choosing a goal does not spend points or reserve stock, price or availability. View reward opens the current details when you are ready.',
  ),
  TourStop(
    0,
    'steps.week',
    'Your daily walk',
    'See the bigger picture.',
    'Your week gives you a gentle view of recent activity. View trends opens more progress history. Activity details holds your synced history and estimates. The sync info icon explains the earning conversion and cap; walking beyond that cap still counts toward your personal goal.',
  ),
  TourStop(
    0,
    'steps.tracking',
    'Your daily walk',
    'Keep counting. Stay in control.',
    'These controls show whether tracking is running or paused. Allow physical activity and background access if you want counting with the screen locked. On Redmi, also allow Autostart and No restrictions. Stop tracking is available here and in the ongoing notification. A deliberate pause stays paused until you choose Resume; paused movement is not added back.',
  ),
  TourStop(
    1,
    'points.balance',
    'Understanding points',
    'Your points, ready to enjoy.',
    'This is your confirmed available balance. Eligible synced walking adds points under the current earning rules; claiming a reward spends its displayed price. A missing balance means it is still loading or unavailable, rather than zero. Explore rewards takes you to the offers you can work toward.',
  ),
  TourStop(
    1,
    'points.ledger',
    'Understanding points',
    'Every change has a story.',
    'Your activity lists points earned, rewards claimed and any balance adjustments, with their dates. Positive entries add to your balance and negative entries show spending. If something seems unfamiliar, check this history and your sync status before trying again. Refreshing this page does not create extra points.',
  ),
  TourStop(
    2,
    'rewards.filters',
    'Choosing a reward',
    'Find your next little win.',
    'Search by reward, brand or location, then choose Explore all or Within my points. The second filter helps you find affordable offers. If no offers are available yet, this area will say so; you can return later. I never add sample offers or spend your points during this tour.',
    clip: 'peek',
  ),
  TourStop(
    2,
    'rewards.offer',
    'Choosing a reward',
    'Look at the details first.',
    'An offer card shows the partner, discount and points price. Open View reward or View details to read the offer’s conditions, expiry, minimum spend and availability where supplied. The Maps icon opens the partner’s configured branch location when one is available. Check the branch and terms before making plans to visit.',
  ),
  TourStop(
    2,
    'rewards.offer',
    'Choosing a reward',
    'One careful tap before it’s yours.',
    'Claiming a reward requires your explicit confirmation and enough confirmed points. Each offer can be claimed once per account; a claimed offer is marked Claimed. After a successful claim, I’ll celebrate and take you straight to Wallet. If a purchase is interrupted, use Recover purchase when shown instead of trying to pay twice.',
    clip: 'gift',
  ),
  TourStop(
    3,
    'wallet.filters',
    'Using your voucher',
    'Your rewards live here.',
    'Ready contains vouchers you can still use. History lets you review Used, Expired and Cancelled vouchers. Claiming an offer puts a voucher here; it does not mean you have already used the discount at the store. Check the voucher’s status and validity before your visit.',
    clip: 'letter',
  ),
  TourStop(
    3,
    'wallet.voucher',
    'Using your voucher',
    'Show it when you’re at the store.',
    'Open Show voucher on a ready voucher to display its QR code and short code. Let the partner’s merchant scan or enter it and confirm redemption. Each voucher is single use. Keep the code private until you use it with the partner. If your Wallet is empty, your first claimed reward will appear here.',
  ),
  TourStop(
    4,
    'you.goal',
    'Your space',
    'Make Stepsy comfortable for you.',
    'Daily goal & companion lets you choose your step target and control my animations and tips. Progress & activity opens your history. Activity connection helps you check motion access. These preferences don’t replace Android’s own permission and battery settings, so check Tracking help if counting is interrupted.',
  ),
  TourStop(
    4,
    'you.notifications',
    'Your space',
    'Encouragement, on your terms.',
    'Notifications & reminders lets you choose gentle walking prompts, tracking help, welcome-back messages and reward updates. You can choose a walking reminder time, turn categories off, and send a test reminder. Automatic reminders share a daily limit and stay quiet from 9 pm to 9 am. Android can delay or block delivery.',
  ),
  TourStop(
    4,
    'you.privacy',
    'Your space',
    'Your account and your choices.',
    'Privacy & support explains how Stepsy handles your information. Account details shows your email and preferences. One phone can have one active customer account and one merchant account; swapping customer accounts cannot earn the same device rewards again. Sign out asks for confirmation. Deactivation has separate consequences explained before you confirm it.',
  ),
  TourStop(
    4,
    'you.tour',
    'Ready whenever you are',
    'You know your way now.',
    'You can replay this guided tour here whenever you want. Your steps, points, vouchers and settings have stayed yours throughout; this tour hasn’t claimed a reward or changed your tracking choices. Start with a comfortable little walk, let your eligible steps sync, and choose a reward when you’re ready. I’ll be here with you.',
    clip: 'celebrate',
  ),
];
