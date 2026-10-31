# Production and Play Store handoff

Implemented October 31, 2026. These repository changes have not been deployed to the VPS. A Play Store upload bundle has not been built on this machine: the Linux Android SDK currently has platform-tools only and no JDK/platform/build-tools toolchain.

## Completed

- Cleared the confirmed Supabase demo database in a single transaction. All 13 application tables were verified empty at reset time. Later new app-test activity was preserved. Schema and migration history were preserved. Removed the demo-seeding implementation and prefilled admin credentials/example form text.
- Batched admin user balances (two queries rather than one extra query for each account), paginated the user directory, debounced searches, rejected stale search results, split admin pages into lazy-loaded bundles, bounded HTTP waits, and shared identical in-flight GET requests.
- Computed balance breakdowns and overview metrics with fewer round trips. Leaderboards return the visible page and caller rather than transferring all users. Added pool limits/timeouts and history/leaderboard indexes.
- Added live system/rewards settings, operational attention counts, audited voucher-expiry maintenance, accurate all-time ledger totals, working reason filters, audit search/pagination, and page CSV exports with formula-injection protection.
- Added in-app FAQs, optional OpenAI help, private support tickets and replies, and an admin support inbox. AI starts disabled and requires a server-only key plus explicit admin enablement.
- AI controls: five requests per user/day, 300 across the application/day, 200,000 charged/reserved tokens/day by default; 60-second user cooldown; 600-character question limit; 240 output tokens; fixed model allowlist; no uploads, tools, history, or account actions. Quota reservations use PostgreSQL transaction locks across all workers. Exact FAQs and off-topic refusals do not call OpenAI. Failed attempts retain their token reservation. User consent is required before sending a question.
- Added opt-in playful or neutral notifications, progress privacy controls, personal goals, quiet hours (22:00–09:00), at most two updates/day with a three-hour gap, milestone/points/voucher reminders, and tap navigation. Removed the permanent tracking notification and unnecessary sensor/battery-exemption permissions. Live sensors pause when the app backgrounds; WorkManager syncing remains best effort.
- Hardened admin authorization, JWT token-purpose checks and password-change revocation, merchant voucher ownership, admin redemption concurrency, first-day step-sync concurrency, adjustment validation/nonnegative balances, password byte limits, account-scoped caches, and request races. Blocking bcrypt runs in a thread pool. Replaced vulnerable JWT dependencies with PyJWT and removed Passlib. Production mock Google sign-in is rejected; OAuth audience and verified email are checked.
- Production password recovery is intentionally unavailable until verified email delivery is configured. It never returns account-takeover tokens to production callers.
- Account deletion now erases identifiers, synced activity, device records and support conversations, cancels issued vouchers, and retains anonymized transaction links. Cached private API responses clear on sign-out. Release builds require configured HTTPS endpoints and publisher/privacy details.
- Added health-data disclosure before permissions, in-app privacy information, a Health Connect rationale activity, API 36 targeting, guarded release signing, a static public policy/deletion-page generator, and a manual signed Android release workflow.
- Installed official Android platform-tools, corrected Flutter's SDK path to `/home/faizan/Android/Sdk`, and verified the Pixel 8 is authorized and visible (`38261FDJH00KR5`). The Linux secure-storage Clang warning is fixed for that plugin only; Linux debug build passes.

## Validation

See `backend/loadtests/local-baseline.json`: 1,000 synthetic accounts, 30,000 activity rows, 30,000 ledger rows, 1,000 requests at concurrency 25, 100% HTTP 200; about 106 requests/s, p95 374 ms, p99 478 ms. This is a local ASGI/PostgreSQL baseline, not a VPS capacity guarantee. Synthetic test schemas are disposable and separate from the cleared application tables.

The final checks include 89 passing backend suite tests plus one passing targeted analytics/system-settings check (including updated anonymizing-deletion expectations), 25 Flutter tests, clean Flutter analysis, and an admin production build plus client/CSV tests. Dependency audits reported no known vulnerabilities after upgrades. This is not a guarantee that every possible vulnerability has been eliminated.

## Required before production / Play review

1. Provide VPS CPU/RAM, SSH access and the running backend directory/service configuration. The live migration revision is `0011`, while this checkout originally contained only `0001`/`0002`. Reconcile deployed code and migration history before rollout: the live database contains `device_bindings`, `device_activity_daily`, `redemption_requests`, and `merchant_ledgers`, which are not modeled by this repository. Do not overwrite newer deployed functionality or blindly stamp/upgrade migrations.
2. Rotate the database password previously embedded in the legacy migration script, plus production JWT/admin secrets. Update the VPS configuration together so rotation does not strand the running service. Removed source secrets remain in old Git history.
3. Configure a real HTTPS API hostname and certificate, explicit CORS origins, `ENVIRONMENT=production`, a unique `ADMIN_PASSWORD` of at least 16 characters, `JWT_SECRET` of at least 32 random characters, Google OAuth client IDs, and the Supabase CA (`DB_SSL_CA_FILE=certs/supabase-ca.crt`). Existing Vercel rewrite files still point to an HTTP upstream; replace that upstream with the verified HTTPS API before using them for authenticated production traffic.
4. Review migrations 0003/0004 against the real deployed migration chain, back up the database, then apply the reconciled schema once before deploying. Do not run migrations independently in each web worker. New support features need their tables before use.
5. Use `deploy/qadam.service` and `deploy/nginx.conf` as reviewed templates. They require real paths/domain/certificates. Start with two workers, each with a pool of five plus five overflow connections (20 maximum total); measure before increasing. Nginx provides shared auth limits, TLS, gzip and static-asset caching. Keep port 8000 private. Confirm readiness and automated backups/restore on the VPS.
6. Supply the real publisher/business name, public support email, public policy/deletion domain and HTTPS API URL. Generate the static pages with `PUBLISHER_NAME` and `PUBLIC_SUPPORT_EMAIL` set, using `npm run build:release` in `web`. Publish `privacy.html` and `delete-account.html`, test them while signed out, and ensure the deletion-request email is monitored. No publisher identity/contact was invented.
7. Install a Linux JDK and full Android SDK, or run `.github/workflows/android-release.yml` after configuring its variables and upload-signing secrets. The existing local upload keystore was left private and unchanged. Set `PUBLIC_PRIVACY_URL` for the native Health Connect rationale and provide Dart defines `API_BASE_URL`, `PRIVACY_POLICY_URL`, `ACCOUNT_DELETION_URL`, `SUPPORT_EMAIL`, `PUBLISHER_NAME`. Generate the signed AAB and verify its signing, API target, merged permissions and native 16 KB page-size compatibility in Play Console/internal testing.
8. Test on the Pixel: sign-in/registration/Google OAuth, denied/granted step permissions, day rollover and background resume, notifications denied/enabled, quiet hours, points/wallet, one-time merchant redemption, support tickets/admin replies, AI limits and fallback, account deletion and reinstall. Physical-device behavior and a signed release bundle are not verified by unit tests.
9. Complete Play Console Data safety, health permissions/declaration, content rating, app access/reviewer credentials and any account-specific testing requirement. Disclose account email, step/fitness totals, transaction records and support messages accurately, including optional OpenAI processing. Do not describe the app as medical, guaranteed background tracking, or universally verified anti-cheat. Plain client step counts are not hardware attestation; device-integrity controls require reconciliation with the deployed device-binding implementation.
10. Run `backend/loadtests/traffic.js` against staging with 1,000 isolated accounts. Test 25, 100 and higher simultaneous users as appropriate, track p95/p99/error rates, database CPU/connections, worker CPU/RAM and slow queries. A total registered user count is different from simultaneous traffic. Do not load-test the public production database with real users.

## Optional AI activation

Set `OPENAI_API_KEY` only in the server environment, set project spending/rate limits in OpenAI, restart the backend, and enable AI in Admin → Support. No live paid OpenAI request was made during development. FAQs and tickets work while AI is disabled. `store=false` avoids response storage for later retrieval; it does not promise zero provider safety retention.

## Official references

- [OpenAI text generation](https://developers.openai.com/api/docs/guides/text)
- [OpenAI data controls](https://developers.openai.com/api/docs/guides/your-data)
- [Google Play target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878)
- [Account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111)
- [Publishing Health Connect apps](https://developer.android.com/health-and-fitness/health-connect/publish)
- [Supabase SSL enforcement](https://supabase.com/docs/guides/platform/ssl-enforcement)
- [FastAPI workers](https://fastapi.tiangolo.com/deployment/server-workers/)
- [SQLAlchemy connection pooling](https://docs.sqlalchemy.org/en/20/core/pooling.html)


## Fix Java / aapt on this Linux machine

The Pixel is authorized; this error is local build tooling, not USB debugging.

```bash
sudo apt update
sudo apt install openjdk-17-jdk
cd /mnt/e-drive/Qadam/mobile
bash scripts/setup_android_linux.sh
flutter run -d 38261FDJH00KR5
```

The setup script downloads official Google command-line tools, verifies their published checksum, installs API 36/build-tools, lets you review the SDK licenses, and configures Flutter's Linux SDK/JDK paths. System Java installation could not be completed automatically because sudo requires your password. The Flutter/Gradle build may also download its required NDK and Gradle components on the first Android build.
