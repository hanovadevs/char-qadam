# Cozy redesign — 31 October 2026

The supplied five-screen and authentication boards are the current mobile design references. They supersede the mint-character sections of the earlier blueprint; historical implementation documents remain dated records.

## Implemented surfaces

| Surface | Layout and live behavior |
| --- | --- |
| Welcome | Illustrated walking scene, Google access, email access and account creation |
| Sign in | Shy companion header, email/password, visibility control, recovery, Google and device-policy information |
| Create account | Waving companion, one password field, validation, account information and existing email verification |
| Recovery | Envelope companion, request/error state, emailed-token form and password confirmation |
| Steps | Shared brand header, real balance, goal ring, movement-driven companion and park, live steps, next reward and weekly history |
| Points | Seated companion on sage card, real balance, today/spent totals and paginated ledger |
| Rewards | Illustrated header, search, affordability filters, admin cover/Maps, terms, one-claim state and explicit purchase confirmation |
| Wallet | Envelope header, Ready/History, ticket edges, actual store cover when present in the catalog, expiry, sharing and QR access |
| You | Waving header, identity, grouped goal/activity/preferences/privacy/account rows and confirmed sign-out/deactivation |

Colors use cream `#FEF8EC`, warm surface `#FFFBF3`, sage wash `#EBEEDD`, peach `#F5DFC5`, moss actions `#4F6A4D`, forest emphasis `#264A3A` and brown ink `#3F352C`. Nunito replaces the prior geometric display type. Secondary text was darkened after contrast validation. Main and secondary text pairs, including the peach surface, pass the tested 4.5:1 threshold.

## Important behavior retained

- Sensor counting, vehicle filtering, notification Stop/Resume and background recovery remain in the existing native/services implementation.
- A device still has one customer slot and one merchant slot. Session, verification and store permissions remain server-enforced. The customer settings contain no merchant shortcut.
- Rewards still require terms/confirmation. A successful purchase opens Wallet, highlights the voucher and plays bounded theme-colored fireworks. Claimed offers cannot be purchased again.
- Covers and Maps come from admin-managed store data. Missing/failed images keep a usable fallback. Wallet resolves cover/name from the catalog when available; historical vouchers remain usable if the offer disappears.
- Recovery deliberately says **“Send reset instructions”** because the existing email service sends a token. The functional token/password step is retained; the UI does not promise a reset link that the server does not issue.
- The displayed Terms/Privacy sheets describe current operation; the release audit still governs launch readiness and publication remains paused.

## Source and validation

See the [character guide](../../design/cozy-companion/character-guide.md) for editable source, render commands, prompt provenance, runtime memory and motion rules. [Current screenshots](../../artifacts/cozy-release/README.md) use fictional fixture accounts/offers; real inventory is fetched from the API.

Flutter analysis passed and the full suite passed **141 tests**, including responsive screens, 2× text, keyboard access, verification routing, failed/successful recovery, confirmation, one-claim behavior, QR, Maps, live-step motion and session isolation. The art packer checks complete frame counts, dimensions and non-clipped alpha bounds before replacing runtime atlases. Device installation and owner acceptance are recorded separately below; automated screenshots are not a claim of visual identity to an artist’s original mesh or of device frame rate.

### Device evidence

The arm64 profile APK was built and installed on the Redmi Note 11 using `adb install -r`: **Success**. Android accepted `com.stepsy.run/.MainActivity` startup. No uninstall, data clear or permission reset was performed. The saved native snapshot immediately before installation was 0 steps for 31 October, with tracking enabled and not paused.

Artifact: `mobile/build/app/outputs/flutter-apk/app-profile.apk` (ignored build output). SHA256: `5C26315A8835F337E7EB178859E9448E9B908CFC920A5259A525F3CE3CB747D8`.

The phone disconnected after installation, before a post-install snapshot, APK hash comparison and playback timings could be collected. The owner confirmed all five tabs, tap reactions, live walking and account data were working, then requested smoother clothing, longer reactions and an improved walking posture. Those art refinements are the next change. Do not interpret the successful automated checks or installation as completed physical-device performance acceptance.


### Character refinement after owner acceptance

The owner accepted the first cozy UI build, then requested softer/wavier clothes, smoother and longer reactions, and a walk that follows the track. The revision replaces separate elbow/knee primitives with continuous armature-skinned clothing, adds gentle fabric sway, expands each clip to 60 frames, holds one-shot poses for 2.5 seconds and uses a right-facing, foot-planted walk on a clear horizontal trail. Live step counting, server sync, account rules and reward actions remain in their existing services.

The art check passed for all stance samples and four connected garment meshes. All **141 Flutter tests** passed again with the revised assets; Flutter analysis reported no issues. Five selected visual-flow checks also passed and refreshed the primary previews. Packing validated all 721 rendered masters (one rest image plus twelve 60-frame clips), with runtime PNG assets totaling 9,336,276 bytes and 8,847,360 decoded bytes per active atlas.

The revised profile APK was installed with `adb install -r`: **Success**. Local and on-phone APK SHA256 both equal `ccca927e8b6f6629dea706631235b13f2235cd9e6d826690eafea88ad01a6a9b`. The process started (PID 3813 during the check), motion and notification permissions remained granted, and no fatal startup record appeared in the inspected buffer. Native data before/after remained **39 steps for 31 October**, **five local history days**, tracking enabled and not paused. Owner visual acceptance and actual playback metrics for this second build are pending; the phone was not in Stepsy’s foreground during the initial diagnostic check.
