# Stepsy launch requirements

Updated 2026-10-17. This replaces the old GPS/MongoDB scaffold requirements.

## Confirmed product scope

- Hanova Devs is preparing an Android-first launch across Pakistan.
- The primary journey is daily steps -> server-calculated points -> partner offer -> single-use voucher -> merchant redemption.
- Initial physical acceptance device: Redmi Note 11. Reported faults: fast/idle overcounting, intermittent tracking stops, and flickering totals on app reload.
- Flutter, FastAPI, PostgreSQL, and the existing React admin portal remain the implementation.
- The owner selected `api.stepsyapp.com` under their purchased `stepsyapp.com`
  domain. Its A record points to `72.62.250.191`; HTTPS is live and verified.
  Mobile defaults and admin proxies now use `https://api.stepsyapp.com`.
- Rewards are discounts/free-item vouchers. Cash payouts and affiliate settlement are not implemented launch promises.
- Partner commitments, redemption economics, final public domains, support contact, and retention policy still require business input. No partner arrangement is assumed to be confirmed.

## Acceptance requirements

| ID | Requirement | Acceptance evidence |
|---|---|---|
| TRACK-1 | Use the hardware step sensor, reconcile overlapping Health Connect totals without summing the same walk twice. | Sensor/health overlap regression plus counted walks on the Redmi. |
| TRACK-2 | Preserve today's count across refresh, backgrounding, process restart, and reboot; reset at local midnight. | Native counter tests, Flutter stale-response/midnight tests, physical restart tests. |
| TRACK-3 | Keep a real foreground tracking service while authorized; stop it and background work on logout/deactivation. | Android service build plus locked-screen and logout checks on a phone. |
| TRACK-4 | Keep syncing during continuous walking; serialize requests and retry transient failures. | Stream/timer tests and airplane-mode recovery on device. |
| TRACK-5 | Show actual steps independently from reward eligibility cap; keep totals stable during server responses. | 25,000 live steps remain visible when server eligibility is 20,000. |
| TRACK-6 | Expose source totals, raw counter, last sensor event, boot count, and tracking-service state for diagnosis. | Steps -> Tracking diagnostics on the physical phone. |
| AUTH-1 | Email/password auth, genuine Google ID tokens with audience and verified-email checks, protected admin access. | Backend authorization and token-boundary tests. |
| AUTH-2 | Recovery credentials go only to the registered inbox; reset tokens expire, work once, and revoke older sessions. | Integration regressions plus actual inbox delivery, reset, replay rejection and old-session revocation on the live API. |
| AUTH-3 | Email/password accounts must prove mailbox access before receiving API access; emailed codes expire, work once and resist guessing/resend abuse. | Verification/session/concurrency regressions, app verification screen tests and live inbox/code/gate checks passed. |
| AUTH-4 | Google sign-in must work with the actual Android package/signing certificate and bind the permanent Google identity. | New Cloud client configured; owner confirmed Redmi sign-in, live exchange returned 200. Release/Play signing registration remains required. See AUTH_SETUP.md. |
| AUTH-5 | A device has one active account until that account is deactivated; logout and suspension do not release it. Enforce this on the API for email and Google access. | Device binding, generation checks and competing-sign-in/verification regressions; see DEVICE_POLICY.md. |
| PRIV-1 | Never show one account's cached wallet, points, or history to another account. | Account-scoped cache and delayed-401 regressions. |
| PRIV-2 | Accurately explain collection, deactivation, retention, and erasure. | Product copy matches API behavior; a complete erasure/retention process is still required. |
| POINTS-1 | Only the API calculates awards, using configured conversion and cap; concurrent and repeated daily syncs cannot double-mint points. | PostgreSQL first-sync race and cumulative-award tests. |
| POINTS-2 | Daily windows follow the user's IANA timezone, defaulting to Asia/Karachi. | Test at 20:00 UTC / 01:00 Pakistan. |
| POINTS-3 | Device steps already consumed cannot earn points again after account replacement; keep wallets private and preserve historical credits. | Transfer/replay/cap/deactivation-race and legacy-credit regressions. |
| REWARD-1 | Only active, in-date, in-stock offers from active partners can be issued; balances and inventory update atomically. | Backend offer/stock/balance tests. |
| REWARD-2 | A store can validate/redeem only its own vouchers; a voucher can be consumed once. | Cross-store and concurrent redemption regressions. |
| REWARD-3 | Newly issued vouchers and updated balances appear without restarting the app. | Wallet/points providers invalidated after issuance; physical flow pending. |
| REWARD-4 | Retry a confirmed reward purchase using the same saved request ID; recover the same voucher after timeout/restart, including sold-out offers. | Concurrent-retry, encrypted-receipt, restart/journal and recovery-button regressions. |
| REWARD-5 | Charge only the points cost the customer confirmed. | Price-change rejection before spending; retries preserve the original request cost. |
| OPS-3 | Protect backend-managed tables from direct Supabase Data API access. | RLS enabled with no client policies; owning FastAPI role works, unprivileged role reads no customer rows and cannot insert receipts. |
| ADMIN-1 | Every admin operation except login requires an admin access token. | Missing/customer/reset-token rejection tests. |
| ADMIN-2 | Validate reward costs/terms; distinguish zero stock from unlimited stock and allow removing limits. | API validation and inventory-null tests; updated portal payloads. |
| ADMIN-3 | Display the live server conversion, cap, validity, and environment. | Protected /admin/config contract; no invented production status or cap. |
| OPS-1 | HTTPS API, rotated secrets, production auth configuration, migrations, backups, monitoring, and deploy smoke checks. | Live deployment verification; repository checks alone do not satisfy this. |
| OPS-2 | Reproducible checks and builds before pushing each batch to main. | Locked dependencies, test suites, APK build, admin build, migration verification. |
| UX-1 | Preserve the mint/teal theme while making progress and rewards more engaging; a 2D walking buddy follows real milestone progress without animating the displayed step number. | Responsive native renders, larger-text flows, lifecycle/off-screen/reduced-motion tests; UI_REDESIGN.md. |
| UX-2 | Reward cards expose the brand's admin-managed Google Maps location; clearing a saved link works and unsupported destinations cannot launch. | Admin-to-customer API integration, safe-link tests, hosted form verification and direct card action tests. |
| UX-3 | Successful points redemption automatically opens My rewards with the saved voucher highlighted; failed or uncertain requests retain safe recovery. | Actual-router confirmation/QR tests, failed-purchase and used-voucher recovery tests. |

The existing defaults are 100 steps per point, 20,000 eligible steps per day,
and 30-day vouchers. These are configurable operating defaults, not a finalized
commercial commitment. At those defaults a user can earn at most 200 step points/day.

## Redmi acceptance protocol

Use the detailed protocol in [LAUNCH_AUDIT.md](LAUNCH_AUDIT.md). A provisional
release target is <=5% error over each of three manually counted 500-step walks,
zero unexplained increases while the phone remains still for five minutes, no
backward flicker during refresh, and retained counts after a locked-screen walk
and restart. Diagnose raw-sensor false positives separately from app arithmetic.

## Explicit remaining work

See the prioritized launch gates in [LAUNCH_AUDIT.md](LAUNCH_AUDIT.md). In particular,
basic client-reported counts and caps are not hardware attestation or proof of a
real walk; no claim of fraud-proof rewards or guaranteed background execution is made.
