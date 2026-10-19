# Blueprint implementation — 19 October 2026

This is the first native implementation of `Stepsy_Redesign_Blueprint.md`, with an original editable Blender companion. The supplied image is art direction; its sample numbers and partners are not production data. This document distinguishes completed work from remaining blueprint work.

## Implemented

- Light paper/mint/teal tokens and bundled typography; official logo retained.
- Steps: compact confirmed activity, separate pending device count, personal daily goal, companion on the accurate progress fill, confirmed points today, available balance entry point, real reward goal/suggestion, dated weekly preview, existing trends, diagnostics and leaderboard.
- Rewards: compact benefit/brand/price/restriction cards, approved store cover thumbnail, existing admin Maps destination, Within my points filter, full terms/detail, explicit redemption confirmation, claimed offer linking to its existing Wallet record.
- Wallet: Ready/History grouping with used, expired and cancelled records retained. Codes are inside voucher detail. Existing redemption recovery, single-claim rules, success navigation and themed fireworks remain connected.
- Points: available balance, walking points earned, spent and existing paginated ledger retained; walking aggregate is not mislabeled as all credits.
- You: goals/companion controls first, account information grouped, existing account/support/privacy actions retained. Onboarding welcome uses the companion.
- Personal goal, selected reward, animation/tip settings and goal celebration marker are stored separately per account **on this phone**. They are not synced to another phone or the admin panel, and do not change earning rules, inventory or reservations.

## Companion and runtime

`design/stepsy-companion/stepsy-companion.blend` is the editable source. Build/render/packing scripts, transparent 256px masters, contact sheet and rig/palette guide are included. Nine clips: rest, idle, walk, wave, point, cheer, ready, wait and reassure. Eight runtime atlases contain 24 frames each at 128px; rest is a small static image.

Playback is brief and event driven, with static fallback. Home only walks after a settled positive change on the same day and goal; opening an existing count or receiving a downward correction does not animate a day's progress. Goal celebrations use an account/day/goal marker. System reduced motion and the user's animation preference take priority. There is no continuous animation loop or additional service/network request.

Each decoded atlas is 768×512×4 = 1,572,864 bytes; static rest is 65,536 decoded bytes. Runtime PNG compression is a separate disk budget. Profile builds log clip decode time and Flutter build/raster p95 for physical-device measurement. These measurements cover the surrounding app frames during playback, not an isolated GPU benchmark.

## Route inventory

Preserved main destinations: `/steps`, `/points`, `/rewards`, `/wallet`, `/profile` (visible label You).

Preserved secondary routes: `/progress`, `/leaderboard`, `/merchant-pos`, `/v/:code`, `/splash`, `/login`, `/register`, `/verify-email`, `/forgot-password`, `/onboarding`.

Home reward links open the actual catalog detail, including repeated visits. Claimed offers locate their voucher across active/redeemed/expired/cancelled history. No new API or database migration is required for this UI pass.

## Validation

- Flutter analyzer: no issues.
- Full mobile regression suite on the final source: **114 passing**, including claimed-offer navigation and walking beyond the daily earning cap without additional earning requests.
- Layout/meter coverage: 320, 360, 390 and 430 widths; progress at 0/1/50/99/100/120 percent; up to 200% text. Five destinations, progress, confirmation and QR are exercised. Initial loading, zero activity, denied permission, offline and failed redemption have explicit fixture previews.
- Redemption tests cover success, reduced motion, fireworks without blocking QR, failure, recovered used vouchers, claimed-offer navigation without a second purchase and admin-configured Maps links.
- Preference tests cover account isolation, persisted selection, concurrent writes, invalid goals and celebration guards.
- `artifacts/redesign/` images are Flutter-rendered **fictional test fixtures**, not production screenshots or native performance proof.

Physical Redmi installation and runtime measurements are recorded below when completed. Existing app data must be preserved using `adb install -r`; never uninstall or clear storage for this review.

### Android build evidence

Profile arm64 APK built successfully from the final source (126.2-second Gradle build). Artifact: `mobile/build/app/outputs/flutter-apk/app-profile.apk`, 83,711,111 bytes, SHA-256 `BD8EBBD84DEF6189F8CFE78637C62C09174D9D305D239831C9B6CA96DD2F08BF`.

The Redmi was initially connected with motion permission granted. It disconnected during the first replacement-install attempt; subsequent ADB inventory was empty. **Installation and physical-device frame measurements are not yet confirmed.** Owner reconnection was requested. No app storage was cleared.

## Remaining blueprint work

- Character art review: dedicated front/three-quarter/left/right turnarounds, stronger expression and stance differentiation, and owner approval of the first interpretation.
- Recorded physical-phone walkthrough, longer session/battery observation and performance across more Android devices.
- Full secondary/onboarding visual pass and a separate permission-recovery review; existing auth and tracking flows are preserved in this build.
- Reasoned adjustment detail needs the API to expose an appropriate reason/reference; do not invent ledger descriptions.
- Offline voucher provenance and merchant online acceptance need an explicit product policy and connected implementation.
- Reward categories, approved launch inventory and partner content need real admin-managed metadata/approval. No production offers were deleted or replaced with sample content.
- Cross-device goals/preferences would need a server-backed account schema/API. Current local scope is stated in the UI.
- Retention improvements remain a hypothesis for user testing, not a guaranteed result.

Play Console upload remains paused at the owner's request.
