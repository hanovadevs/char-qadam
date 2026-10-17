# Stepsy launch audit - 2026-10-17

## Product and launch assessment

Stepsy is a walking-rewards marketplace with three working code surfaces: a
Flutter consumer/merchant app, a FastAPI/PostgreSQL API, and a React admin portal.
It is significantly beyond a scaffold, but the old completion checklist overstated
release readiness. Android-first Pakistan launch and Redmi Note 11 acceptance
were confirmed by the product owner in this session.

The business proposition depends on reliable tracking and real partner value.
Points are an internal reward currency, not cash. The earning rule, voucher cost,
redemption limits, partner discount funding, and support/refund handling must be
commercially sustainable; confirmed partner inventory was not supplied.

## Fixed in this audit

- Removed fabricated Google-token login and frontend fallback; require real token
  verification, the configured audience, trusted issuer, and verified email.
- Protected all admin endpoints except login; separated access and password-reset
  token types. The auth limiter's public bypass header now works only in tests.
- Replaced public password-reset credentials with SMTP delivery, one-use tokens,
  and credential-version checks that revoke older user/merchant sessions.
- Removed an embedded database credential and unsafe guessed-account backfill
  from the deprecated migration script. Added versioned merchant/session migrations.
- Serialized first daily sync on the existing user row to avoid the missing-row
  race between foreground and background requests. Returned daily earned points
  and reward rules instead of treating the last sync's award as today's total.
- Used user-local dates with an Asia/Karachi default rather than the API host date.
- Replaced the notification-only Android tracking approach with a native health
  foreground service owning the hardware sensor, persistent counter snapshots,
  reboot detection, boot resumption when enabled, and logout shutdown.
- Kept overlapping Health Connect/sensor counts monotonic and aligned health
  queries to a captured sensor timestamp to avoid async overlap inflation.
- Removed body-sensor permission requests unrelated to a step counter. Requested
  step-read access, notification permission, and supported background health reads.
- Fixed live-count replacement by late/capped sync responses, debounce starvation
  during continuous walking, old-day responses, and missing-day streaks.
- Kept the router stable during profile refreshes; waited for onboarding storage;
  invalidated onboarding completion after saving it.
- Scoped offline caches to account IDs, guarded disposed async notifiers and
  out-of-order tab responses, and prevented an old 401 from logging out a new session.
- Refreshed wallet/points after offer issuance and guarded repeated redeem taps.
- Restricted merchant voucher validation/redemption to the issuing partner,
  blocked new rewards from inactive stores, and locked admin voucher redemption.
- Validated nonnegative costs/stock, percentage terms and timezone-aware offer
  dates. Made zero stock and explicit unlimited stock behave distinctly.
- Loaded admin reward rules/environment from `/admin/config`; removed invented
  production/cap values. Corrected deactivation copy to match retained records.
- Updated vulnerable admin router/build dependencies, committed the Flutter lock
  file, and stopped tracking generated HTML/JS/build reports.
- Corrected the optional API-hosted admin portal's repository path and covered
  both bundled portal/assets and API-only deployments with route checks.

Physical sensor acceptance still needs the longer trials below. Production
deployment checks are recorded separately from local test results.

## Checks and evidence

- Backend: **90 tests passed** on isolated PostgreSQL with migrations 0001-0004;
  includes reset replay/session revocation, concurrent first syncs, cross-store
  rejection, inactive-store issuance, and inventory validation.
- Flutter: **34 tests passed** and **analysis reported no issues** after final
  tracking, session, onboarding, and deactivation-copy changes.
- Android: debug APK build passed; **7 native counter tests passed** (zero
  failures/errors), covering reboot, midnight, overlap, and stale/duplicate events.
  The final incremental APK rebuild also passed (37.4 seconds).
- Admin: Vite 8.3.4 production build passed; npm audit reported zero vulnerabilities.
- Fresh migration 0001-0004 provisioning is exercised by the full backend suite;
  migrations rather than ORM create_all now define the test schema.
- Initial live checks found the old API: the sync schema lacked daily points,
  `/admin/config` returned 404, and anonymous `/admin/auth/me` returned 200.
  After the owner supplied SSH access, deployed checked commit `ccfe58c` to
  **only** `qadam_backend` from `/root/qadam/char-qadam/backend`.
- Deployment: preserved the prior image/config, backed up all 10 Stepsy public
  tables (including Alembic), and successfully restored the archive in an isolated
  PostgreSQL 17 container. Removed that temporary container. Production migrations
  advanced from 0002 through 0004; the replacement container is healthy.
- Verified public `/health` and database `/health/ready` return 200; anonymous
  `/admin/auth/me` and `/admin/config` now return 401. The public sync schema
  includes daily earned points, conversion and cap. Real admin login/config return
  200; a token signed with the previous JWT key returns 401 after key rotation.
- Compared every other running container's ID and start time with the pre-rollout
  baseline: none changed or restarted. No other app or Nginx site was modified.
- Stepsy's new admin credential and signing key are stored only in the server's
  private backend `.env`. Google audience now matches the mobile client ID;
  genuine device OAuth still needs acceptance. SMTP remains unconfigured.
- HTTPS follow-up `1fc687b`: owner added the domain's A record. Verified a trusted
  certificate on `https://api.stepsyapp.com`, HTTP-to-HTTPS redirects, HTTPS-only
  slash normalization, health/readiness 200 and authenticated admin login/config
  200. Anonymous admin access stays 401. Certificate renewal dry run and deploy
  hook succeeded; its timer is enabled/active. Certificate expires 2027-01-15.
- Restricted Stepsy's Docker port to loopback; trusted only the inspected host
  proxy gateway. Added a separate domain site; hashes of every preexisting Nginx
  file and other containers' IDs/start times remained unchanged.
- Updated Android/default API and all root/web Vercel/dev proxy configurations.
  Vercel deployed `1fc687b` to production (READY); the admin portal returns 200
  and its protected API proxy returns 401 anonymously. No Vercel env override
  exists. The legacy IP route remains for previously installed test APKs.
- HTTPS APK rebuild passed (59.6 seconds), Flutter analysis had no issues and all
  34 Flutter tests passed. Admin production rebuild/audit passed with zero
  vulnerabilities. Installed this APK on the reconnected Redmi with `adb install
  -r`; installation succeeded and the saved 194 steps remained intact.
- HTTPS APK device startup: the app process stayed alive, the captured error-level
  log contained no errors, motion permission remained granted, and the native
  `StepTrackingService` was confirmed foreground (`isForeground=true`). The owner
  confirmed the Steps screen is ready. Health Connect is absent on this phone;
  its handled availability/read diagnostics do not prevent hardware tracking.
  The owner subsequently confirmed the short walk and refresh check was all good;
  the exact final count was not supplied, so no percentage accuracy is claimed.
- Follow-up CI [39040085789](https://github.com/hanovadevs/char-qadam/actions/runs/39040085789):
  all three jobs passed, including Android analysis, Flutter tests, hosted APK
  build and native counter tests.
- Reward recovery follow-up `769eff0`: **101 backend tests** passed with migrations
  through 0006; **42 Flutter tests** and analysis passed; debug APK build passed
  (37.9 seconds). Added a persisted per-account purchase journal, encrypted server
  receipts, same-voucher retry recovery, confirmed-price checks, a Recover purchase
  control for offers no longer in the catalog, and safe short-code collision retries.
- Deployed `769eff0` to Stepsy only after a fresh public-schema backup restored
  successfully in an isolated PostgreSQL container. Configured a dedicated recovery
  key privately without rotating the existing session/signing key. Production
  migrations reached 0006; HTTPS admin login/config/readiness all return 200;
  the live API exposes the idempotency header and replay field. Recovery key
  encryption/decryption was verified inside the actual production image.
- The database security audit found all 10 existing public tables lacked RLS.
  Migration 0006 now protects all 11 tables, including receipts, with no client
  policies. The owning FastAPI connection retains access. Direct checks as both
  Supabase `anon` and `authenticated` roles returned zero visible user rows.
  A restricted-role regression also proves receipt inserts are rejected.
  The Supabase advisor connector could not access this project; these checks used
  the owner's authorized server connection and isolated PostgreSQL tests instead.
- Verified other running app container IDs/start times stayed unchanged during
  the recovery rollout. Its APK is ready but not installed: the Redmi disconnected
  after the prior successful HTTPS walk/refresh test.
- Recovery CI [39042790366](https://github.com/hanovadevs/char-qadam/actions/runs/39042790366):
  backend and admin passed; Android analysis/Flutter tests passed and its hosted
  APK build was still running at this update. The local APK build passed.
- Browser UI automation could not run: no browsers were exposed by the session.
- CI now runs API migrations/tests, Flutter analysis/tests, Android build/native
  tests, and admin build/audit on main pushes and pull requests. The workflow is
  newly added. On run 39030447871, backend and admin jobs passed; Android
  analysis/tests passed, but the APK build exhausted the hosted runner's disk.
  The workflow now removes unused hosted .NET/Haskell/CodeQL toolchains before
  building. Corrected run [39031262328](https://github.com/hanovadevs/char-qadam/actions/runs/39031262328)
  passed all three jobs, including the Android APK and native counter tests.
- Redmi Note 11 (2201117TG, Android 13 / API 33): APK installed successfully after
  MIUI approval/reconnection. The app process remained alive, 42 frames were
  recorded, and the captured error-level startup log contained no fatal error.
- Product-owner physical smoke: **63 steps recorded; no step increments while
  still**. This is one user-reported sanity check, not the full accuracy benchmark.
  The owner also reported that the locked-screen walk counted very well; exact
  before/after values and a reload-stability result were not supplied.
  Restart/midnight/battery trials and real OAuth/email checks remain open. The
  phone was initially disconnected for manual testing and later reconnected for
  the successful HTTPS APK update above.

## Release gates and unfinished capabilities

| Priority | Gate | Concrete remaining work |
|---|---|---|
| P0 | Rotate exposed database credential | The API signing key/admin password have been rotated, and old JWT rejection is verified. The historically exposed database credential still requires provider-side revocation; Git history contains it. Never paste replacements into source. |
| P0 | Physical Redmi accuracy | Idle and locked-screen smoke tests passed by owner report. Complete counted 500-step/restart/midnight trials. If raw sensor readings rise while stationary, diagnose those readings; no arbitrary step multiplier was introduced. |
| P0 | Real auth/recovery configuration | Server Google audience is configured; verify real device OAuth and signing fingerprints. Configure SMTP and verify delivery and reset with a real test inbox. Recovery currently reports unavailable. |
| P0 | Real partner rewards | Confirm contracts, coverage, stock, discount terms, funding, return/refund/cancellation handling and merchant training before claiming nationwide redemption availability. |
| P0 | Abuse resistance | The API still accepts client-reported step totals. Caps, monotonic updates and permission checks are not device attestation; assess Play Integrity, provenance checks, replay/audit controls and rollout limits. |
| P0 | Erasure and privacy | Deactivation revokes access but retains rows. Implement a reviewed erasure/anonymization and retention process, publish the policy and account-deletion route, and complete Play disclosures before release. |
| P1 | Checkout terms and savings | POS does not yet capture/enforce basket minimums. Percentage/free-item values are not actual PKR savings; add basket-aware rules before using savings totals as financial facts. |
| P1 | Reward recovery rollout | Install the recovery APK and verify issuance/recovery with test merchant inventory. Older clients without a saved purchase ID retain legacy retry behavior. |
| P1 | Offline history | Current-day snapshots recover counts; automatic seven-day backfill and explicit stale/offline labels remain incomplete. Long gaps spanning midnight cannot be reconstructed from a cumulative counter alone. |
| P1 | Voucher links | Confirm the owned public domain, deploy Android assetlinks for the signing certificate, preserve post-login destinations, and replace the code-only deep-link screen with a wallet lookup. |
| P1 | Notifications | Notification payload navigation, scheduled reminders, and a complete expiry-delivery lifecycle are unfinished despite older module labels. |
| P1 | Operations/scale | One Stepsy public-schema backup/restore was verified. Automate retention/off-host backups; test multiworker rate limiting, load/latency, job observability, support/audit workflows and deployment rollback under representative load. |
| P2 | Profile/localization | Persist name/avatar beyond the locally cached Google profile; decide Urdu/localization and accessibility acceptance. iOS remains outside the initial launch. |

## Redmi Note 11 test protocol

1. Connect USB, enable USB debugging, and accept the computer's authorization prompt.
   Confirm the device appears in `adb devices` / `flutter devices`. Do not uninstall
   an existing differently signed app automatically; preserve its local data.
2. Install/run the debug build, sign in with a test account, grant motion tracking,
   and check that Steps -> Tracking diagnostics shows the service/sensor available.
3. Record displayed, saved, raw-sensor, server, and health-store readings. Leave
   the phone still on a table for five minutes, then check the readings again.
   Distinguish delayed health backfill from fresh raw-sensor increments.
4. Walk 100 steps, then 500 steps at normal pace, counting manually. Repeat 500
   steps three times, including a pocket/locked-screen trial. Record error for
   each trial; provisional target <=5%, subject to product acceptance.
5. Refresh repeatedly while walking. Counts must not move backward; the eligible
   server count can stop at the daily cap while actual steps keep increasing.
6. Walk with the screen locked for 5-10 minutes, reopen, dismiss/reopen the app,
   reboot and reopen, and verify continuity. OS force-stop and OEM battery rules
   can stop services; do not advertise guaranteed execution after force-stop.
7. Test airplane-mode walking then reconnect. Test local midnight separately;
   do not change the clock on an account with real rewards to fabricate history.
8. Earn a test reward, view it in the already-open wallet, validate at its own
   store, redeem once, reject replay and another store, then refresh the wallet.
9. Log out and sign into another account. The previous wallet/balance/history
   must not appear and tracking must stop at logout until enabled again.

For local USB development: run API on port 8000, run
`adb reverse tcp:8000 tcp:8000`, then from `mobile/` run
`flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000`.
Use the isolated test database and development accounts for full redemption tests.

## Implementation references

- [Android sensor/service guidance](https://developer.android.com/health-and-fitness/fitness/basic-app/read-step-count-data)
- [Android health foreground-service prerequisites](https://developer.android.com/develop/background-work/services/fgs/service-types#health)
- [Pinned health package behavior](https://pub.dev/packages/health/versions/13.3.1)
- [Vite migration guidance](https://vite.dev/guide/migration)
- [Certbot webroot renewal and deploy hooks](https://eff-certbot.readthedocs.io/en/stable/using.html)
- [Uvicorn trusted proxy settings](https://www.uvicorn.org/settings/)
- [Fernet receipt encryption and key rotation](https://cryptography.io/en/stable/fernet/)
- [Supabase Data API access controls](https://supabase.com/docs/guides/api/securing-your-api)


## Pushed batches

- `93df98e`: initial API authentication/admin boundaries and step-sync integrity.
- `828adff`: partner voucher isolation, reward validation, session revocation,
  and real-migration regression coverage.
- `35b5ac9`: Android foreground tracking, source reconciliation, stable counters,
  diagnostics, cache/session/onboarding fixes and Flutter/native regressions.
- `bda0e89`: admin configuration/stock fixes, dependency security updates and
  generated-output cleanup.
- `d747810`: current product requirements, launch audit, and verification CI.
- `ccfe58c`: optional admin portal path/regressions, phone test evidence, and
  hosted Android build disk cleanup. See [backend/DEPLOYMENT.md](backend/DEPLOYMENT.md)
  for the Docker rollout sequence and public deployment checks.
- `1fc687b`: verified HTTPS API, private Docker ingress/trusted proxy, updated
  mobile/admin defaults, reproducible Nginx config and successful APK rebuild.
- `769eff0`: retry-safe reward issuance/recovery, confirmed-price protection,
  encrypted receipts, safe collision retries and private Data API tables.

The debug testing artifact is `mobile/build/app/outputs/flutter-apk/app-debug.apk`.
It now defaults to `https://api.stepsyapp.com` unless overridden by API_BASE_URL.
Do not publish this debug artifact as the Play release.
