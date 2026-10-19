# Stepsy — Complete UX/UI Redesign Blueprint

Design direction: **Every step, closer.**
Prepared 19 October 2026 · Whole mobile app · Light theme

## 1. Outcome

Make Stepsy immediately understandable as **walk → earn points → redeem an offer → use a voucher**. Give users a useful reason to return: see confirmed progress toward a reward they actually want. Make Home visually distinctive while reducing the scrolling needed to understand today's activity and the next action.

This is a redesign proposal and implementation brief. The accompanying interactive preview is a local design simulation; it does not access health data, change accounts, or redeem real rewards. Sample dates, figures, offers and partners are illustrative. The generated image is a visual direction, not a source of business rules or exact chart data.

## 2. Evidence and scope

Reviewed all nine supplied screenshots, image(2).png through image(10).png: three parts of Steps, two of Points, two of Rewards, Wallet, and Profile. These are nine captures of five main destinations, not nine independent screens. Secondary flows and live behavior cannot be verified from these screenshots.

Also reviewed the current saved Stepsy_UI_Redesign_Concept_01.md and Stepsy_UI_Redesign_Concept_03.md. This whole-app proposal supersedes their visual layout recommendations where they conflict with the user's latest request. Preserve their verified functional requirements. An app repository was not supplied; no production implementation or integration test is claimed.

### Problems visible in the screenshots

| Evidence | User consequence | Proposed change |
| --- | --- | --- |
| Home starts with a large slogan, then an almost full-screen dark step panel | A user sees 14 steps but little immediate reward context | Compact editorial step hero, confirmed points strip, chosen reward in the initial viewport |
| Rewards dedicates much of the first screen to a slogan, subtitle and large balance panel | Browsing begins late; comparing offers requires substantial scrolling | Compact header/balance, search, short filters and compact offer rows/cards |
| One reward consumes almost a full screen | Benefit, minimum spend and point price cannot be compared quickly | Benefit, merchant, point price, key restriction and action together |
| A claimed reward ends in a disabled Claimed button | The next useful action is missing | View voucher when an active voucher exists; otherwise explain eligibility/history |
| Points, Rewards and Home repeat large balance/progress surfaces | Data is repeated without improving the user's decision | Use one small available-balance entry point; keep the full ledger in Points |
| Wallet exposes codes in the list and four large wrapping filters | Browsing is heavy and presentation is less discreet | Ready/History grouping; full codes inside voucher details; preserve all statuses |
| Profile prioritizes email, country and timezone; destructive action is prominent | Frequent settings take longer to reach | Goals/activity first; preferences grouped; account actions last |
| Test Offer 09b6 appears in Wallet | Development content weakens credibility | Approved public content required for published inventory |
| Available balance is 63, lifetime earned is 3, spent is 40, with a +100 adjustment | Labels need explanation; screenshots alone do not prove an accounting bug | Separate walking-earned, adjustments and spent; every adjustment has a reason |

## 3. Research translated into design

These sources support general principles. Their application to Stepsy is a design judgment; none establishes a guaranteed retention improvement for this app.

| Primary/research source | Principle | Stepsy decision |
| --- | --- | --- |
| Apple Human Interface Guidelines, Tab bars: https://developer.apple.com/design/human-interface-guidelines/tab-bars | Stable, labeled top-level sections; preserve navigation state | Keep the familiar five destinations and visible labels |
| Material Components Android, Navigation bar: https://github.com/material-components/material-components-android/blob/master/docs/components/BottomNavigation.md | Three to five destinations represented with icons and labels | Five evenly distributed items; no extra center action pretending to be a tab |
| Nielsen Norman Group, Progressive Disclosure: https://www.nngroup.com/articles/progressive-disclosure/ | Defer secondary material while keeping essential information visible | Summarize Home; put earning rules, trends, ledger and full terms in clear drill-ins |
| Android Developers, Make apps more accessible: https://developer.android.com/guide/topics/ui/accessibility/apps | Recommend at least 48 × 48 dp touch targets | 48 dp on Android; at least 44 pt on iOS; whole-row settings targets |
| Android Developers, Grids and units: https://developer.android.com/design/ui/mobile/guides/layout-and-content/grids-and-units | Consistent spacing and text scaling | 8-unit layout rhythm; native scalable text |
| W3C WCAG 2.2 Contrast Minimum: https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html | Normal text 4.5:1, large text 3:1 | Verify foreground/background combinations; do not use pale mint for essential text |
| W3C WCAG 2.2 Target Size Minimum: https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html | 24 CSS px minimum or specified exceptions | This is a web minimum, not a substitute for the larger native mobile target recommendations |
| Self-Determination Theory: https://selfdeterminationtheory.org/the-theory/ | Autonomy, competence and relatedness inform motivation | Let users choose a reward and pace; make progress legible; keep competition optional |
| Sailer et al., How gamification motivates: https://doi.org/10.1016/j.chb.2016.12.033 | Different game elements affect motivational needs differently | Treat streaks and leaderboards as separate hypotheses, not universal engagement fixes |

## 4. Visual direction

Use a premium, fresh light interface with open sections, deliberate type, flat teal accents and a restrained organic walking-ribbon shape near the Home heading. The ribbon is decorative: it must not imply GPS routes or occupy metric space. Keep the official Stepsy logo asset unchanged; the preview uses a text wordmark until the source asset is available.

| Token | Target | Usage |
| --- | --- | --- |
| Paper | #FAFBF8 | Screen background |
| White | #FFFFFF | Navigation and selected surfaces |
| Ink | #102B32 | Headings and primary text |
| Secondary | #536B71 | Supporting text |
| Teal | #087F72 | Primary actions, earned points, selected states |
| Mint | #E8F6F2 | Reward-goal emphasis and selected surfaces |
| Soft teal | #D0EBE2 | Nonessential chart bars |
| Divider | #DDE8E3 | Subtle section separation |
| Danger | #B43837 | Errors and destructive actions |

No decorative gradients, glow, glass effects, heavy shadows, repeated huge cards, emoji navigation, or unrelated 3D graphics. Use approved partner/product images for rewards; do not publish generated partner imagery or fictitious offers. A clean placeholder is better than an invented partnership.

Typography: use the existing accessible production font if suitable; otherwise test a readable humanist family such as Nunito Sans with platform fallbacks and an appropriately licensed Urdu companion. Typical sizes: 28–30 screen heading, 56–64 primary step number, 18–20 section heading, 15–16 body, 12–13 secondary labels. Never shrink text merely to fit a fixed card height.

Use 20–24 horizontal margins, 8-unit spacing rhythm, 16–20 padding for meaningful surfaces, 18–24 surface radii, and 12–16 button radii. Reserve larger type for actual progress, not repeated slogans. Most sections should sit openly on the page.

## 5. Navigation and route inventory

Preserve existing five tabs: **Steps · Points · Rewards · Wallet · You**. You is the visible label for the existing Profile destination. Keep the existing route identifiers where possible. A stable bar with text labels is already understandable; fix hierarchy before changing navigation architecture.

| Destination | Primary job | Secondary routes |
| --- | --- | --- |
| Steps | Today's progress and chosen reward | Goal settings, weekly trends, full activity log, streak details, community leaderboard, sync explanation |
| Points | Available balance and transparent ledger | Transaction details, earning rules, adjustment explanations |
| Rewards | Find and evaluate an offer | Search/filter, reward detail, select reward goal, redemption confirmation, success |
| Wallet | Use a redeemed voucher | Voucher detail, code/QR reveal, instructions, history with used/expired/cancelled |
| You | Manage activity, preferences and account | Profile details, activity permissions, country/timezone, support, legal, sign out, account deactivation/deletion |

Keep bottom navigation visible on ordinary top-level/detail views, respecting native platform behavior. Full-screen code presentation or system permission dialogs may use a focused presentation with an obvious close/back action. Preserve tab scroll positions and nested routes where supported. Back never silently switches tabs or spends points.

## 6. Home / Steps: the priority screen

At approximately 390 × 844 logical units, aim to show brand, date, headline, steps, daily progress, points/sync strip and the chosen reward's action before scrolling. Accessibility text size may expand naturally; never crop content to meet this target.

1. Compact top row: official brand left; available points pill right. Pill opens Points. No decorative notification bell without real notification functionality.
2. Short context-sensitive heading, such as **A little walk. A real reward.** Avoid repeating this hierarchy on every tab.
3. Large steps count on the light background. A compact percentage sits beside it. Below: a precise horizontal daily-goal meter, actual goal, and remaining steps.
4. One slim strip: authoritative points earned today and last successful sync/status. Keep refresh accessible through the status/detail action and pull-to-refresh where already supported.
5. Compact real streak status. Explain its actual rule; the reference uses 1,000 steps/day. Do not substitute the user's personal goal for this rule.
6. A single distinctive pale-mint reward-goal section: approved thumbnail, benefit, partner, available balance / price, exact points remaining and View reward. Show Ready to redeem when appropriate.
7. Below the first view: small seven-day chart, trends entry, estimated distance/energy, full daily activity log entry, and optional community entry.

### Three different quantities

| Quantity | Source | Never confuse with |
| --- | --- | --- |
| Steps today / personal goal | Settled daily activity snapshot and actual user goal | Daily point-earning cap |
| Confirmed points earned today | Server earning/ledger state | Entire available balance |
| Available balance / reward price | Server balance and currently eligible offer | Today's steps or today's points alone |

Reference rule is 100 eligible steps = 1 point and a 20,000 eligible step daily earning cap. Verify actual configuration before implementation. Show no forced Claim points action if points already accrue automatically. Do not label points as cash or promise cash savings before a discount is actually used.

### Reward-goal selection: proposed enhancement

This is a new product feature, distinct from preserving the existing app. Allow a user to select one eligible reward from its detail screen. Until persistence exists, use an explicitly temporary suggestion rather than a fake saved selection. Retain a goal only while the offer remains available and eligible; explain expiry/unavailability and let the user choose again. Do not imply that choosing a goal reserves stock or fixes its terms/price. If the reward becomes redeemable, highlight it without spending points automatically.

If there is no goal, invite Choose a reward to walk toward and show a small real recommendation. If there are no offers, keep Home useful with activity and progress rather than inventing a goal.

Do not promise an exact number of extra steps to redeem unless the calculation accounts for eligible-step remainder, cap, pending reconciliation and availability. A correct 37-point gap does not necessarily imply exactly 3,700 more device steps.

## 7. Points

Use a compact screen title and a meaningful balance surface: available points, Find a reward action. Keep earned/spent summaries secondary. Do not occupy the first half of the screen with a slogan.

Ledger rows show understandable reason, date/time, status and signed amount. Group by date; paginate long histories. A transaction detail should explain balance adjustments and pending reconciliation when the data supports it. Distinguish walking-earned points, grants/adjustments and redemption costs. A total labelled Lifetime earned must state what it includes and reconcile with the ledger definition.

Show pending amounts separately from spendable balance. Confirmed redemptions refresh the balance, ledger, reward eligibility and Wallet together.

## 8. Rewards and redemption

Top: compact Rewards heading and balance pill, then search. Use category chips based on actual inventory. Keep the existing affordability filter but rename **Ready for you** to **Within my points**. That filter means affordable; it does not guarantee stock or merchant eligibility.

Each compact offer card contains image/placeholder, partner, benefit, price, city or online availability, important restriction such as minimum spend, and one clear action. On a typical phone, make at least one complete offer and a meaningful portion of the next visible. Do not force a two-column grid when text becomes cramped.

Reward detail must expose benefit, price, available balance, eligible channels/branches, minimum spend, end date, one-per-account rules, exclusions and instructions before confirmation. Terms can expand, but key purchase restrictions stay immediately visible.

| State | Action |
| --- | --- |
| Affordable and available | Redeem for N points → confirmation |
| Insufficient points | N more points needed; allow goal selection |
| Already redeemed with usable voucher | Open voucher |
| Already redeemed but no active voucher | Explain one-per-account rule; view history |
| Out of stock | Explain availability; preserve details |
| Expired | Explain expiry; suggest browsing valid inventory |
| Processing | Prevent duplicate request; keep status visible |

Confirmation shows exact point cost, remaining balance, key terms and explicit confirm/cancel. Production server revalidates balance, eligibility, stock, expiry and duplicate redemption. Use existing idempotency/reconciliation mechanisms. If a response is uncertain, check the transaction status before retrying. Never spend points twice or announce success on a timeout.

Success: **Your voucher is ready.** Primary action Open voucher; secondary Back to rewards. Do not require the user to search for it again in Wallet.

## 9. Wallet

Default to **Ready**, with count when authoritative; put Used, Expired and Cancelled in **History** with clear secondary filters. This changes the grouping without removing existing statuses.

Compact tickets show partner, benefit, important terms, expiry date and current status. Show voucher is the primary action. A previously claimed offer should deep-link to this screen/detail when possible.

Voucher details present real code/QR only from the server, appropriate contrast/quiet zone for scanning, expiry, merchant instructions and status. Keep copy/share only where currently allowed; do not introduce sharing if vouchers are nontransferable. Provide text code as a fallback only when it is accepted by the merchant. Do not generate fake QR patterns. Avoid a self-reported Mark used action unless the current business process supports it.

Expiry ordering and alerts must use real timestamps and Asia/Karachi/user timezone rules. Do not invent urgency. On offline access, label the last verified status and whether the merchant can accept it; never promise cached vouchers will work without backend/merchant support.

## 10. You / Profile

Compact identity summary, then grouped full-width rows:

- Activity & goals: daily goal, activity connection, trends/log, existing community leaderboard.
- Preferences: existing country, timezone, units or language only where supported.
- Privacy & support: data/privacy controls, legal links, help, real version.
- Account: sign out, then the existing deactivation/deletion action.

Keep full email in account details. Do not show developer/account identifiers. Do not equate deactivation with permanent deletion; preserve the actual backend behavior and explain the difference. Account actions use the current confirmation and authentication controls.

## 11. Onboarding and permission recovery

1. Welcome: one clear explanation of walking, points and partner offers, with access to real rewards or a truthful prelaunch state.
2. Activity connection: explain what data is needed and why, then open the existing platform permission flow after the user taps Connect activity.
3. Optional personal goal and reward selection after the basic value is understood. Do not block browsing with a long preference questionnaire.

Preserve existing auth and completion behavior. Offer Continue for now where supported, explain that earning needs an activity connection, and make recovery available from Home and You. Do not repeatedly reopen denied permission prompts.

Use actual installed providers and OS versions. Prior documents reference HealthKit/Health Connect; inspect the current implementation before changing integrations or naming a provider. Do not claim GPS-free or local-only behavior without checking the code and privacy policy.

## 12. Retention proposals worth testing

| Moment | Useful experience | Dependency / restraint |
| --- | --- | --- |
| First visit | See how walking connects to an available reward | Real inventory and clear conversion rules |
| During the day | Check confirmed progress and remaining goal | Correct sync and eligibility state |
| New confirmed progress | Brief progress update; small haptic if enabled | No repeated celebration on every app open |
| Reward becomes affordable | Home changes to Ready to redeem | Do not imply inventory reservation |
| Weekly return | Personal weekly comparison and consistency summary | Complete dated data; missing data is not zero |
| Optional reminder | User-chosen time and meaningful event | Notification capability, consent, quiet times and opt-out |
| Community visit | Optional existing leaderboard | Clear period/rules; do not fabricate friends or rank |

Keep existing streaks but acknowledge a return warmly after a missed day. A proposed weekly consistency goal can reduce all-or-nothing framing without silently changing the existing streak definition. A new challenge should begin as a nonmonetary achievement unless an approved backend points policy explicitly funds it. Do not add surprise point grants, daily rewards, fake scarcity, or engagement penalties through a visual redesign.

## 13. System states

| State | Required behavior |
| --- | --- |
| Initial load | Stable skeleton; no fake zero balance/steps |
| True zero activity | Show zero and a useful goal/connection explanation |
| Permission denied/limited | Specific provider/status and real recovery action |
| Provider unavailable | Explain the problem; do not claim synced |
| Refreshing | Retain last good data, small progress feedback, block duplicate sync |
| Offline/stale | Timestamp cached data; label restricted actions |
| Sync error | Preserve known data; plain-language retry |
| Earning cap reached | Separate continued step tracking from capped point earnings |
| Goal exceeded | Celebrate accurately; clamp meter; retain full count |
| Reward removed | Explain changed availability; choose a new goal |
| Empty rewards/search | Explain state; clear filters when appropriate |
| Empty Wallet/history | Relevant explanation and Explore rewards action |
| Redemption uncertain | Resolve server status before offering retry |
| Session expired | Preserve safe context and return after sign-in |

## 14. Accessibility, localization and motion

- Test 320–430 logical widths, safe areas, keyboard and Android back navigation, 200% text settings, long reward names and Urdu/RTL layout readiness.
- Use native semantic roles, meaningful accessible names and predictable focus. Announce sync/redemption results without reading every numeric animation frame.
- Give charts text summaries and dated values; distinguish missing from zero. Pair color with labels, shape or icons.
- Meet 4.5:1 normal text contrast, 3:1 large text/meaningful UI graphics where applicable. Validate real rendered pairs, including disabled states.
- Native touch targets: at least 48 dp Android, 44 pt iOS. Adjacent small icons need adequate separation; navigation labels remain visible.
- Use locale-aware numbers, PKR, dates and timezone rollover. UI text stays text, not embedded in images.
- Short 150–250 ms feedback when useful. Respect reduced motion and avoid looping decorative motion. Goal/point animations reflect confirmed values, not assumed future rewards.
- Load real reward images efficiently with cached thumbnails and stable aspect ratios; use vector/native layout for the Home ribbon, never a full-screen bitmap.

## 15. Implementation handoff for Codex

Implement inside the existing Stepsy repository. This document authorizes a UI redesign, not changes to reward economics, account policy, health collection, or fraud controls.

1. Inspect AGENTS.md, app architecture, framework, routes, theme tokens, assets, state management, auth, permissions, activity source, ledger, reward/voucher APIs and current tests.
2. Run the existing app and record a route/function inventory. Preserve every working feature, including those absent from the screenshots.
3. Establish shared tokens and components: Screen, Header, BottomTabs, StepHero, GoalMeter, SyncStatus, RewardGoal, RewardCard, VoucherTicket, TransactionRow, SettingsRow, ConfirmationSheet and state components.
4. Build Home first; compare its initial viewport at 360 and 390 logical widths against this brief. Bind real step, goal, points and sync data from a consistent snapshot.
5. Apply the same hierarchy to Points, Rewards, detail/confirm/success, Wallet/detail/history, You/settings, onboarding and secondary routes.
6. Add reward-goal persistence only with an explicit user-scoped model and current data eligibility. If that model is absent, implement an honest suggested-reward state and report the missing dependency.
7. Preserve backend validation, idempotency, eligibility and fraud controls. Keep business calculations out of visual components. Never turn preview fixtures into production defaults.
8. Test the actual walk/sync/points/redeem/voucher path in the supported test environment; use existing relevant tests and add targeted cases for changed business-sensitive behavior.
9. Run repository-required lint, type checks, tests and platform builds. Report blockers accurately; never say native flows passed based on a browser prototype.
10. Deliver changed files, behavior changes, test results and normal/zero/denied/offline/reward-ready/redemption-error screenshots.

### Production acceptance

- Home communicates steps, personal goal, earned-today points and a real reward without oversized filler.
- Goal, earning cap, available balance and point price are distinct and correctly sourced.
- All five tabs and every existing secondary feature remain reachable.
- Offer restrictions are visible before spending; duplicate/uncertain requests are safely handled.
- Wallet success, ready, used, expired and cancelled states remain intact.
- No sample merchant, fake voucher, test identifier, private email or hard-coded health metric ships.
- Small screens, large text, screen readers, safe areas, offline and permission recovery work.
- A complete native implementation is verified separately from the concept preview.

## 16. Validation and measurement

First run moderated tasks with 5–7 representative users, including someone unfamiliar with fitness/rewards apps. This is a practical early test, not a statistically representative sample. Ask users to explain how points work, identify today's goal, find an affordable valid offer, explain its conditions, redeem in the test environment, find the voucher, and recover from denied permission. Record completion, confusion, time and mistakes; do not guide them through navigation.

Then compare retention and task success across the current design and redesign with assignment at user level. Define activated users consistently (for example, activity connected and first eligible sync confirmed). Measure D1/D7 return, chosen-goal use, reward-detail-to-confirmed-redemption conversion, voucher-use completion when merchant status supports it, permission recovery and error rates. Treat notification opt-outs and redemption mistakes as guardrails. Size the experiment from actual baseline and traffic; do not invent a success percentage. More opens alone do not prove the app is more useful.

## 17. Preview boundaries

The interactive review covers five main tabs, two sample offer details, reward-goal choice, affordability/search filters, one local redemption simulation, Wallet/history, voucher detail, editable personal goal and weekly trends. Secondary settings have explanatory placeholders. It is not a complete native prototype, production app, or proof that new features already exist.

Preview accounting: opening balance 41 + confirmed walking points 62 − earlier voucher costs 40 = available 63. Redeeming the 30-point sample offer leaves 33. Preview daily steps 6,240 / goal 8,000 = 78%, with 1,760 steps remaining. The reward goal costs 100 points, so balance 63 leaves a 37-point gap. Keep these fixtures confined to previews.


## 18. Stepsy companion — 2D character and Blender implementation

### Latest user direction

The app must have a very cute, high-quality **2D character** that walks along the step-progress bar and interacts contextually with the user throughout the app. The user has authorized desktop Codex to use Blender on their computer to create it. This extends the whole-app redesign; a static walking illustration alone does not meet the requirement.

**Pip** is the working character name used in the new visual concept, not a finalized brand decision. Preserve the official Stepsy logo separately. Do not replace the logo with the mascot.

### Character art direction

Use the generated Pip character concept as a visual reference, not a production-ready rig or animation sheet. The reference shows the intended charm, silhouette and expressions; its sample chart/date layout is not authoritative data.

- Original, friendly, gender-neutral mint/teal pebble-like walking creature with a soft rounded bean silhouette.
- Expressive dark eyes, small eyebrows, tiny mouth, warm peach cheeks, short arms and legs, creamy white oversized walking sneakers with teal soles.
- A small curved head tuft gives a recognizable silhouette. Keep proportions and face placement consistent across poses.
- True 2D illustrated appearance: clean contours, a restrained flat palette, controlled line weight and clear silhouettes. Simplify shading from the concept into flat shape accents; avoid glossy 3D, heavy gradients and texture noise.
- Cute enough to become a recognizable product identity while retaining the adult, professional feel of the app.
- Recognizable at 40–64 logical units. At 24–32 units, use a simplified static head/face variant rather than an unreadable full body.
- Produce front, three-quarter and left/right walking views. Use the three-quarter view for greetings and the side/three-quarter walk for the bar.
- Create separate face variants for happy, curious, focused, celebrating, reassuring and resting. Avoid distressed, crying or disappointed reactions to low activity.

### Desktop Codex instructions

Work inside the actual Stepsy repository and the user's available desktop environment. Inspect AGENTS.md and the existing app before changing code. Locate the installed Blender executable, confirm its version, and use its supported Python/Grease Pencil APIs. The user has already authorized use of Blender for this task; do not stop at explaining that it is possible. Build, render, inspect, refine, export and integrate the character.

Do not imply that a Blender source file, rig or production sprite already exists in this design handoff. The accompanying image is concept art. If Blender or an essential integration is genuinely unavailable, report the exact missing dependency and complete independent app work rather than claiming the animation is implemented.

Use Blender's 2D Animation/Grease Pencil workflow with a fixed orthographic camera. Flat vector-like curve/plane cutouts are also acceptable if they produce the same 2D style and a more reliable scriptable rig in the installed version. Choose one maintainable approach after inspecting the version; do not copy an API example from a different Blender generation without checking compatibility.

Organize editable layers/objects for body, tuft, arms, legs, shoes, eyes, eyebrows, mouth and optional cheek accents. Use named controls, reusable colors and a root control. Parent feet/limbs appropriately, retain a stable contact baseline, and keep readable eye/face expressions at the exported app size. Keep a generous transparent safety margin for raised hands and shoe movement.

Save an editable Blender source, a reproducible generation/render script, the character palette/proportion notes, and a preview contact sheet. Keep asset paths relative to the repository. Preserve existing files and avoid destructive scene operations outside the new character scene.

### Animation inventory and suggested starting budgets

These are production targets to refine through visual review and on-device measurement, not arbitrary requirements to increase file sizes.

| Clip | Initial target | Behavior |
| --- | --- | --- |
| Idle | 24 frames at 24 fps | Small natural blink and restrained settling motion; optional infrequent playback |
| Walk | 24 frames at 24 fps | Seamless planted-foot loop with opposite arm/leg swing and gentle body bob |
| Wave | 24–36 frames at 24 fps | One warm greeting; returns to idle |
| Point / guide | 24–36 frames at 24 fps | Points toward the adjacent contextual action |
| Cheer | 24–36 frames at 24 fps | Small happy celebration after a confirmed milestone |
| Reward ready | 24–36 frames at 24 fps | Delighted reaction and gesture toward the redeemable offer |
| Think / wait | 24 frames at 24 fps | Calm waiting state while real sync is pending |
| Reassure | 24–36 frames at 24 fps | Supportive gesture for denied permission or recoverable error |
| Rest | Static pose plus optional short transition | Relaxed, welcoming neutral state for reduced motion or inactivity |

Render one polished walk cycle first, inspect its contact poses and loop seam, and correct foot sliding/proportions before rendering the full inventory. Use anticipation and settling sparingly; preserve readable action at small size. Store frame rates, names, looping flags, bounds and anchors in a machine-readable manifest.

### Export and app integration

Authoring in Blender and running inside the mobile app are separate stages. Do not embed Blender or a .blend file as the runtime renderer.

Use transparent RGBA image sequences as a portable master export, initially 256 × 256 pixels per frame with a fixed canvas and shared foot-contact anchor. Test 128/256 variants at actual display sizes before choosing production assets. Pack per-animation texture atlases only if the existing app renderer supports them; otherwise use a measured, supported image animation path. Do not assume animated WebP, SVG animation, Lottie, Rive or alpha video works across the current framework and platforms without verification. A PNG/Blender workflow does not automatically create a Lottie/Rive rig.

Minimize transparent padding after preserving the shared anchor. Use consistent crop offsets in the manifest if trimming. Avoid huge all-states atlases: 24 frames at 256 × 256 RGBA are roughly 6 MiB decoded before packing overhead, even when the download is small. Lazy-load clips, cache a small number, release inactive assets and measure texture/GPU memory on a representative lower-end Android device.

Suggested source organization (adapt to the repository):

- `design/stepsy-companion/stepsy-companion.blend`
- `design/stepsy-companion/build_character.py`
- `design/stepsy-companion/render_animations.py`
- `design/stepsy-companion/character-guide.md`
- `assets/companion/static/`
- `assets/companion/animations/`
- `assets/companion/manifest.json`

Manifest entries should include clip name, frame count, fps, loop mode, source paths, canvas dimensions, content bounds, pivot/foot anchor, crop offsets if any, and the fallback static pose. Honor the existing framework's image density and asset packaging conventions.

### Walking-bar behavior

The visual filled length must remain an accurate measure of confirmed daily steps divided by the user's actual personal goal. The avatar is decoration and must never replace the value or conceal progress.

- Place Pip's feet on the upper edge of the progress track; reserve explicit vertical room for its body.
- Use a nominal 48–64 logical-unit character on Home. Keep the actual step count and remaining steps legible beside/below it.
- Let `progress = clamp(confirmedSteps / validGoal, 0, 1)`. Keep the bar fill accurate at `progress × trackWidth`.
- Set the character's target foot-anchor position from the same progress value, then clamp only its visual anchor/bounds so hands and shoes remain within the screen. At 0% and 100%, character-center clamping must not make the track look partially complete.
- When a confirmed positive delta arrives, play a short walk and move toward the new target. Do not animate every physical step or claim live tracking while the app only has periodic aggregate sync.
- When the user opens the screen, settle to the known position with a small greeting if appropriate. Do not replay the whole day's journey or repeated celebrations on each tab switch.
- If the backend corrects a total downward, update the track honestly and reposition with a neutral transition; do not celebrate the correction.
- Handle invalid/missing goal, loading, true zero, above-goal values, earning cap, permission denied and offline/stale data. The personal goal, streak rule and earning cap remain separate quantities.
- At goal completion, play one cheer per real goal-completion event, then rest near the endpoint. Use persisted event identifiers/local-day context to prevent repeated celebrations and to handle goal changes deliberately.
- In reduced motion, use a static pose at the correct anchor with an accessible textual status.

### Contextual presence throughout the app

Pip should feel like one consistent companion across routes. Give it intentional slots in each layout rather than a draggable overlay that roams across text and controls.

| Area/event | Companion interaction | User control / data rule |
| --- | --- | --- |
| Home / fresh confirmed steps | Walks to the progress position | Accurate current snapshot; limited playback |
| Home / tap Pip | Small wave, then a short relevant tip | Accessible labeled button; no automatic spending/navigation |
| Points / new confirmed earning | Small happy nod near the earned row | Confirmed ledger event only |
| Rewards / chosen goal | Points toward its progress and View reward | Choosing does not reserve stock |
| Rewards / newly affordable goal | Reward-ready expression | Uses available balance and current eligibility |
| Redemption success | One cheer beside Open voucher | Server success only, never a pending request |
| Wallet / empty | Gently guides toward Explore rewards | No sad face, guilt, or invented offers |
| Wallet / voucher ready | Small pointing gesture by the next action | Never overlaps a code, QR or scan quiet zone |
| Onboarding / connection explanation | Friendly wave/guide pose | No repeated system permission prompts |
| Sync pending | Calm think/wait gesture | Cannot disguise a stalled request; timeout/error still visible |
| Error or denied permission | Reassuring expression next to a clear recovery action | Does not blame the user or promise fake success |
| Profile / companion preferences | Small static preview | Animation/tip controls and reduced-motion behavior |
| Return after a missed day | Warm greeting | No claims that Pip was sad, lonely, hungry or neglected |

First implementation should use deterministic event-driven reactions and approved contextual copy. An AI chat system is not required by this companion brief. Do not add network/model costs or transmit health data to create a talking character.

Speech bubbles belong in reserved layout space, expand for larger text/Urdu, and can be dismissed. Show at most one at a time. Keep tips infrequent and relevant, do not fire them on every rerender, and do not obscure headers, tab navigation, point costs, buttons, codes or charts. State essential instructions in normal UI text too. No sound by default; haptics follow existing preferences.

Suggested copy: "A little closer.", "Your reward is ready.", "Your steps will appear after sync.", "Ready whenever you are." Only use factual progress claims when current data supports them. If the character communicates helpful meaning, expose it to screen readers; mark purely decorative frames hidden so animations do not produce repeated announcements.

### Acceptance checks for desktop Codex

1. Character looks consistent and readable at 48 px, with a clear silhouette and original identity.
2. Editable Blender scene and reproducible scripts reopen and render successfully on the user's installed version.
3. Walk cycle has planted feet, no visible sliding, cropped limbs, broken transparency or loop jump.
4. Actual mobile UI uses exported animations, not the character-sheet image as a background.
5. Bar placement works at 0%, 1%, 50%, 99%, 100% and above goal on 320–430 logical widths and both safe-area layouts.
6. At 100%, the last foot/body remains visible while the true bar stays fully filled.
7. Reactions follow confirmed app state and remain stable across navigation, background/resume, retries and local-day rollover.
8. All five tabs include the specified contextual presence without blocking their main actions.
9. Reduced-motion/static mode, optional tips, large text and accessibility labels work.
10. Measure compressed asset size, decoded memory, loading and playback performance; report actual results on the available test device/emulator.
11. Existing step sync, earning cap, ledger, redemption, vouchers, privacy and account behavior still work.
12. Deliver source assets, runtime exports, manifest, integration changes, validation results, and short recorded previews of Home walking, a reward-ready reaction and redemption success.

Technical references: Blender Grease Pencil is a 2D drawing/animation system (https://developer.blender.org/docs/release_notes/2.80/grease_pencil/). Version-specific capabilities differ; inspect the installed version and current matching manual. Blender 4.5 release notes describe Grease Pencil render anti-aliasing and SVG animation changes (https://developer.blender.org/docs/release_notes/4.5/grease_pencil/); these are not evidence that the app's runtime supports SVG animation.
