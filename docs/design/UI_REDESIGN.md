# Stepsy UI refresh

The direction is an everyday walking club: mint, deep teal, warm white and navy,
with a walking buddy on a milestone path and rewards that look like collectible tickets.
Existing routes, account ownership, step tracking and reward accounting stay in
their current modules. Existing production routes and business services are preserved.

## What changed

- Today places an original 2D walking buddy on a curved milestone path. Its
  position follows actual steps; the decorative arm/leg walk cycle runs only
  while the screen is visible, the app is foregrounded and motion is allowed.
  Reduced motion or disabled tracking holds an idle pose. The number updates
  directly with tabular figures. Milestones never change the configured earning cap.
- Points connects the available balance to rewards, retaining transaction
  history, pagination, loading and retry states. Unknown balances display a dash.
- Rewards uses ticket cards, real discount terms, point costs, progress to
  unlock, a search field and an affordability filter. Brand initials stand in
  for absent artwork; no partner photos, logos, urgency or commercial claims
  were invented.
- The Maps button is on the card and works independently of affordability.
  It uses the admin's branch link, or a Google Maps search for the saved name
  and address. No GPS permission, geocoding service or paid Maps API is needed.
- Confirming a successful redemption navigates directly to My rewards and
  highlights its voucher. The initial filter resets to Ready to use. Recovered
  purchases are looked up across Ready, Used and Expired. Failed/uncertain
  purchases retain the existing recovery journal and do not navigate as success.
- My rewards has ticket passes, status filters, accessible QR sheets, code copy
  and sharing. Sharing sends the usable code instead of the previously unverified
  public deep link. Old status results cannot overwrite newer requests or show
  under a different status while loading.
- Profile, login and navigation adopt the same surfaces/type. Account switching,
  verification and deactivation behavior remain intact.
- History charts encode recorded step totals by bar length. Missing records use
  a dash, real zeroes use 0; averages use recorded days. Touch/keyboard selection,
  tooltips and semantic labels expose values without relying only on color.
  The chart opens at its newest period, so the selected bar is visible on narrow phones.

## Admin location setup

In **Stores → Edit store**, set the branch's address and paste its **Google Maps
place link** (Google Maps → Share → Copy link). Save, then refresh Rewards in the
app. Every offer belonging to that store receives its updated branch data.
Clearing the link now removes it; retaining an address enables a Maps search.
Clear both fields to remove the location action entirely. An omitted patch field
preserves the previous value. Unsupported/unsafe destinations are rejected by
the API and have no clickable external action in the app/admin.

## Design system and supplied skills

The user supplied six standalone skill documents as guidance for this redesign.
Their web-specific recipes are adapted to native Flutter widgets rather than
adding a WebView, D3 runtime or an unused CSS layer.

| Guidance | Application |
| --- | --- |
| sleek-design-mobile-apps | Coordinated screen/navigation design and rendered screenshot review. Its hosted generation API was not used: no SLEEK_API_KEY was configured. |
| frontend-design | A deliberate walking-club direction, contrasting display/body type and distinctive ticket surfaces inside existing implementation boundaries. |
| d3-visualization | Correct native bar scales, missing versus zero data, direct labels, interactive selection and semantic alternatives. |
| improve-animations | Audited the motion surface; the implementation plan is in plans/001-native-motion.md. |
| better-typography | Bundled Space Grotesk display + Manrope body fonts, tabular counters, useful hierarchy, wrapping and larger-text checks. |
| hallmark | Existing-brand preflight, shared native tokens, restrained decoration, honest copy, states and responsive review. |

The supplied files did not include their linked reference files. No full
Hallmark 58-gate certification or hosted Sleek design is claimed.

The executable token source is `mobile/lib/core/theme/app_theme.dart`: existing
mint #2FE0C4, teal #0F8A78, deep teal #0B4A47, navy #16213A, white #FFFFFF and
canvas #F3F6F5; mint wash #E5F6F0 adds a quiet supporting surface. Deep teal is
used for primary button text/background contrast (white/deep teal: 10.07:1).
Body/secondary text is 15/13 sp; navigation labels are 12 sp. Corners use 10/14/24
dp with 4-point spacing. Flutter retains native focus, semantics and touch feedback.

Fonts are bundled for offline use with their OFL licenses. Sources:
[Manrope](https://github.com/google/fonts/tree/main/ofl/manrope),
[Space Grotesk](https://github.com/google/fonts/tree/main/ofl/spacegrotesk).
Maps use [Google's cross-platform URLs](https://developers.google.com/maps/documentation/urls/get-started).

## Verification

The design/flow suite uses the actual router and screens with fictional preview
fixtures. It covers 320/375/414/768 dp, 1.6× text at 320 dp, large-text redemption
and QR sheets, successful/failed redemption, used-voucher recovery and Maps
actions without spending real account points. Images in `artifacts/redesign/`
are previews, not live partner offers or customer activity.

Recreate preview images with:

    cd mobile
    flutter test test/redesign_flow_test.dart --no-pub --dart-define=CAPTURE_UI=true

Final local/CI/device/deployment results are recorded in `LAUNCH_AUDIT.md`.
