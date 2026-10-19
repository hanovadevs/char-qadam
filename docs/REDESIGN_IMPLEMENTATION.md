# Blueprint implementation — 19 October 2026

This is the first native implementation of `Stepsy_Redesign_Blueprint.md`, with an original editable Blender companion. The supplied image is art direction; its sample numbers and partners are not production data. This document distinguishes completed work from remaining blueprint work.

## Implemented

- Light paper/mint/teal tokens and bundled typography; official logo retained.
- Steps: compact live sensor activity, separate pending sync indication, personal daily goal, companion on the accurate progress fill, confirmed points today, available balance entry point, real reward goal/suggestion, dated weekly preview, existing trends, diagnostics and leaderboard.
- Rewards: compact benefit/brand/price/restriction cards, approved store cover thumbnail, existing admin Maps destination, Within my points filter, full terms/detail, explicit redemption confirmation, claimed offer linking to its existing Wallet record.
- Wallet: Ready/History grouping with used, expired and cancelled records retained. Codes are inside voucher detail. Existing redemption recovery, single-claim rules, success navigation and themed fireworks remain connected.
- Points: available balance, walking points earned, spent and existing paginated ledger retained; walking aggregate is not mislabeled as all credits.
- You: goals/companion controls first, account information grouped, existing account/support/privacy actions retained. Onboarding welcome uses the companion.
- Personal goal, selected reward, animation/tip settings and goal celebration marker are stored separately per account **on this phone**. They are not synced to another phone or the admin panel, and do not change earning rules, inventory or reservations.

## Companion and runtime

`design/stepsy-companion/stepsy-companion.blend` is the editable source. Build/render/packing scripts, transparent 256px masters, contact sheet and rig/palette guide are included. Thirteen clips: rest, idle, walk, wave, point, cheer, ready, wait, reassure, wiggle, love, gift and peek. Twelve runtime atlases contain 24 frames each at 128px; rest is a small static image.

Playback is event driven, with static fallback. Home walks after a live positive change on the same day and goal; opening an existing count or receiving a downward correction does not animate a day's progress. Walking cycles continue while step events arrive and stop three seconds after the last event. Goal celebrations use an account/day/goal marker. System reduced motion and the user's animation preference take priority. There is no unattended animation loop or additional service/network request.

Each decoded atlas is 768×512×4 = 1,572,864 bytes; static rest is 65,536 decoded bytes. Runtime PNG compression is a separate disk budget. Profile builds log clip decode time and Flutter build/raster p95 for physical-device measurement. These measurements cover the surrounding app frames during playback, not an isolated GPU benchmark.

## Route inventory

Preserved main destinations: `/steps`, `/points`, `/rewards`, `/wallet`, `/profile` (visible label You).

Preserved secondary routes: `/progress`, `/leaderboard`, `/merchant-pos`, `/v/:code`, `/splash`, `/login`, `/register`, `/verify-email`, `/forgot-password`, `/onboarding`.

Home reward links open the actual catalog detail, including repeated visits. Claimed offers locate their voucher across active/redeemed/expired/cancelled history. No new API or database migration is required for this UI pass.

## Validation

- Flutter analyzer: no issues.
- Full mobile regression suite after the expressive companion update: **119 passing**, including guided redemption, accessible reactions, bundled assets, delayed-sync live updates, animation continuity, claimed-offer navigation and walking beyond the daily earning cap without additional earning requests.
- Layout/meter coverage: 320, 360, 390 and 430 widths; progress at 0/1/50/99/100/120 percent; up to 200% text. Five destinations, progress, confirmation and QR are exercised. Initial loading, zero activity, denied permission, offline and failed redemption have explicit fixture previews.
- Redemption tests cover success, reduced motion, fireworks without blocking QR, failure, recovered used vouchers, claimed-offer navigation without a second purchase and admin-configured Maps links.
- Preference tests cover account isolation, persisted selection, concurrent writes, invalid goals and celebration guards.
- `artifacts/redesign/` images are Flutter-rendered **fictional test fixtures**, not production screenshots or native performance proof.

Physical Redmi installation and runtime measurements are recorded below when completed. Existing app data must be preserved using `adb install -r`; never uninstall or clear storage for this review.

### Android build evidence

Profile arm64 APK built successfully from the final source (126.2-second Gradle build). Artifact: `mobile/build/app/outputs/flutter-apk/app-profile.apk`, 83,711,111 bytes, SHA-256 `BD8EBBD84DEF6189F8CFE78637C62C09174D9D305D239831C9B6CA96DD2F08BF`.

The Redmi initially disconnected during replacement installation. After owner reconnection, `adb install -r` completed with **Success**; package update time is 2026-10-19 16:26:58 and motion permission remains granted. No app storage was cleared. Owner walkthrough and physical-device frame measurements are pending; successful installation alone does not confirm saved values or smooth playback.

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

## Live-step correction after owner walkthrough

The owner reported that steps arrived in batches and walking playback was too brief. The first blueprint implementation had incorrectly bound the main count to API settlement. This is corrected to use the existing live persisted sensor stream (with the server total as a reopening floor); point earnings and available balance still use server values. Initial activity remains unknown until an actual sensor or server snapshot is available. Pending sync refers only to eligible steps not yet acknowledged, not movement beyond the daily earning cap.

Walking now uses a three-second recent-movement window, extending the same cycle on subsequent steps. A background sync cannot replace walking with a wait clip. Inherited-widget rebuilds do not interrupt playback. Manual wave and other single clips play for 1.5 seconds. Hidden tabs and reduced motion stop rendering; profiling samples are bounded even during a long walk.

New regression checks exercise live count updates during delayed sync without awarding points, continuous movement without restarting the cycle, resting after inactivity, and real atlas playback across inherited-widget changes and hidden tabs. Physical-phone confirmation of the corrected build is tracked separately from automated checks.

Corrected source commit: `cbd10e8`. Flutter analyzer is clean; all 116 mobile tests pass. The profile arm64 APK built successfully (135.6-second Gradle build), SHA-256 `9D7988276C2FF7CCB04B5D583C5A1F9A4B198D5DA2DA946C7F3137DC8B45AE1E`. Replacement installation succeeded on the Redmi at 2026-10-19 16:38:38, with motion permission still granted and no storage reset. The phone subsequently disconnected; owner confirmation and physical playback timings remain pending.

The owner subsequently confirmed that live counting and movement-driven walking work correctly on the Redmi.

## Expressive companion and guided rewards

Added four original Blender clips: a squash-and-stretch wiggle, a shy peek, a wink with floating hearts, and a voucher hug. Editable prop controls, baked animation, transparent masters and runtime atlases are included. The contact sheet now accommodates all 13 clips. Runtime assets total 2,281,334 bytes; decoded atlas size remains 1.5 MiB per playing widget, with lazy loading and release when hidden.

Pip responds to intentional taps on all five tabs. The Home progress companion rotates through playful reactions and short tips while preserving movement-driven walking. Points, You, Rewards and Wallet use an accessible tap target of at least 48dp. Reactions are brief and obey system/in-app motion preferences.

Rewards guidance selects from actual currently eligible inventory and the current balance. Help me choose opens terms, then the existing explicit cost confirmation. A voucher-holding pose accompanies confirmation and pending saving; errors use reassurance without claiming success. Only successful redemption navigates to the real voucher, with existing fireworks, and QR guidance appears in Wallet and voucher detail. Turning off tips removes optional guidance while keeping terms, confirmation and normal reward controls available.

Validation: analyzer clean; all 119 mobile tests pass. New checks cover tap reactions with animation disabled, all four runtime assets, and the complete guide → terms → explicit confirmation → Wallet → QR flow. Existing 200% text, 320px layout, live-step, failed purchase, recovery and single-claim regressions remain passing. Fixture previews were refreshed; they are not physical-phone captures.

### Installed expressive build and physical playback sample

Source `ddcf384`; profile arm64 build succeeded in 136.6 seconds. All four new PNG atlases were extracted from the APK and verified byte-for-byte against the source assets. APK: 83,711,529 bytes; SHA-256 `FAF6ED263C913C481F64E8437BDF23A3236C169F16AFE6AC5A9270BE00682838`. `adb install -r` succeeded on the Redmi at 2026-10-19 16:52:16; motion permission remains granted, without clearing storage.

During the owner's playback from 16:52:38–16:53:01, profile logs recorded love, peek, wiggle, wave and point clips. Decode times were 7–20 ms, with 80–92 sampled app frames per playback and 1,572,864 decoded image bytes. Flutter build p95 ranged 0.899–3.486 ms and raster p95 7.069–22.782 ms across these windows. These are surrounding app frames, including navigation/modal activity; some raster samples exceed a 16.7 ms frame budget, so this does not establish a locked 60fps result or a long-session benchmark. No Flutter exception was returned by the filtered diagnostic sample. The owner's subjective review and real redemption confirmation remain separate from these measurements.
