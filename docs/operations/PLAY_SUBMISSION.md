# Stepsy Play submission — 31 October 2026

Status: **hold production submission** until the deployment and artifact checks below pass. Source fixes alone do not establish production readiness or guarantee approval.

## Copy into Console

| Task | Answer |
|---|---|
| Privacy policy | `https://api.stepsyapp.com/privacy` — deploy and restore the API first; it currently returns 502. |
| Sign-in details | Some/all functionality restricted. Supply a dedicated, verified customer email/password account, not your personal credentials. Supply a separate merchant account if that role is included in review. |
| Ads | No only if partner placements are not paid/sponsored advertisements. No ad SDK was found. |
| Content rating | Complete the questionnaire honestly; Console assigns the rating. No cash gambling, user-to-user public messaging or medical treatment is implemented. Private human/AI support exists. |
| Target audience | Recommended product choice: adults, 18+. Select this only if adults are the intended audience; do not select children merely to broaden reach. |
| Data safety | Yes, data collected. Use the table below; do not mark “No data collected.” |
| Government apps | No. |
| Financial features | **Rewards, points, frequent flier miles, and other incentives**. Points are not cash, a bank account or cryptocurrency. |
| Health | **Activity and fitness**. Explain step counting, activity history and step-based reward calculation. |
| Category/contact | App → Health & Fitness. `contact@hanovadevs.com`. Publisher: Hanova Devs, subject to matching your actual Console identity. |
| App name | Stepsy |
| Short description | Walk, track your steps and turn everyday movement into partner rewards. |
| Account-deletion URL | `https://api.stepsyapp.com/delete-account` — deploy and restore the API first; it currently returns 502. |

Reviewer instructions to adapt after provisioning and testing the accounts:

> Choose Sign in with email and use the supplied verified credentials. Allow physical activity access to test tracking; Health Connect and reminder permissions can be declined. Customer features are Steps, Progress, Rewards, My rewards, You, and Help & support. Background tracking has a persistent notification with pause controls. No payment is required. Each phone permits one account of each role; use a separate customer/merchant login for each role. You → Delete account permanently removes the profile and disables those credentials.

Provide actual working credentials in Console's private fields. Verify reward/voucher and merchant screens are accessible without waiting days to accumulate steps; any test entitlements must be isolated and disclosed. Keep the reviewer accounts available throughout review and respond if a deletion test disables one.

## Data safety detail

This is a source-based mapping, not an automatic certification. Cover every version/region you distribute, all SDKs, live hosting logs and actual provider contracts.

| Console data type | Current use | Required/optional | Purpose |
|---|---|---|---|
| Personal info → Email address; User IDs | Verified account login, Google identity, account UUID | Required for accounts | App functionality, account management, fraud prevention/security |
| Location → Approximate location | Account country/timezone, country shown in rankings; no GPS route permission | Optional when supplied | App functionality, local dates/rankings |
| Health and fitness → Fitness info | Daily steps, activity history, rankings and reward calculation | Optional with consent; required for step features | App functionality, fraud prevention/security |
| Financial info → Purchase history | Points spent, voucher issuance/redemption and merchant reward transactions | Conditional on using rewards | App functionality, fraud prevention/security |
| Messages → Other in-app messages | Support tickets/replies and opted-in AI questions | Optional | App functionality, developer communications |
| Device or other IDs | App-scoped device identity and account/device reservation | Required for account/device protection | App functionality, fraud prevention/security |
| App activity → App interactions | Reward actions and logged endpoint interactions | Collected during use | App functionality, fraud prevention/security |
| App info/performance → Diagnostics | Request timing/status/error category and operational logs | Collected during use | App functionality, fraud prevention/security |

- **Sharing:** leaderboard responses disclose a walker identifier, country, fitness totals and corresponding points to other signed-in users. Conservatively declare the relevant User IDs, Approximate location and Fitness info as shared for app functionality. Do not mark every category “not shared” just because no ad SDK exists. Merchant redemption also exposes voucher transaction information to the merchant; declare the relevant transaction sharing. Review Google's user-initiated-transfer exceptions against the actual flow before applying an exception.
- Hosting/database and OpenAI processing may qualify for the service-provider exception only where their actual contractual processing fits Google's definition. AI receives the question and FAQ context; step history is not attached automatically. Do not claim no collection for AI messages.
- Email/UUID, device reservations and transactions are retained, not ephemeral. Optional AI calls can be processed even where the app does not persist the prompt itself.
- Encryption in transit: Yes for the HTTPS app/backend/provider paths, after verifying the deployed configuration.
- Account creation: email/password and Google OAuth. Select the matching choices.
- Account deletion: Yes only after deploying and testing the new deletion handler. App path: You / Profile → Delete account. Web path: the deletion page's verified-email support request.
- Active profile identifiers, step rows, support messages/tickets, device registrations and recoverable voucher receipts are erased. Active vouchers are cancelled. De-identified reward/security records, device-level consumption and AI cost counters remain for accounting/abuse prevention. Provider backups expire separately. Confirm and publish the operator's actual retention periods; do not invent them.
- Camera scans remain on-device; do not declare photos/video uploaded solely because the merchant scanner requests camera permission. Declare any later upload feature if added.

## Health / background service wording

Health Connect step-read permission:

> With the user's permission, Stepsy reads daily step totals to show activity history and progress, reconcile overlapping phone/Health Connect totals, calculate step-based reward points, and prevent duplicate rewards. It does not read GPS routes or use health data for advertising or lending.

Background health read, if requested:

> Read permitted step totals while the app is not visible so daily activity and rewards can stay current, subject to Android background restrictions. Users can revoke access in Health Connect. This is not a medical monitoring service.

Foreground service type **health**:

> User-enabled phone-sensor step counting continues while the screen is off or the app is not visible. A persistent notification identifies tracking and allows pausing. Tracking stops on sign-out. It is the core walking feature, not a periodic promotional service.

If the merged artifact requests any additional FGS type, inspect its originating library and declare the actual use or remove the unused permission. Provide the Console-requested demonstration video showing permission disclosure, tracking, the notification and pause/resume. Do not claim exact or uninterrupted 24/7 accuracy.

## Store description

Make more of your everyday movement with Stepsy.

Track daily steps, see your progress and build a walking routine with your walking companion. With permission, Stepsy uses your phone's motion sensor and Health Connect step totals to keep activity up to date.

Earn points from eligible steps, explore available partner offers and redeem points for vouchers. View reward terms and show a voucher's QR code at the partner store. Offer availability, point costs and voucher validity vary by partner.

Manage tracking, reminders and privacy from your profile. Get help through FAQs, support tickets and optional AI assistance. Stepsy does not track GPS routes and is not a medical service. Distance and energy figures are estimates.

Questions: contact@hanovadevs.com

Use current app screenshots, a 512×512 icon, and a 1024×500 feature graphic. Do not use fictional partner offers, guaranteed earnings, cash-payout claims or images of unimplemented features. Check Console's current asset requirements before uploading. Declare AI-created promotional assets where Console asks.

## Remaining release gates

1. Restore the API: the latest live checks return Nginx **502**, including `/health` and `/health/ready`. Deploy the reviewed backend/admin and migration **0012_support** to Stepsy only. Preserve private environment, receipt keys, uploads, the database and other VPS apps. SSH access is currently unavailable to this session.
2. Fix ownership of existing `/app/uploads` volumes for UID 10001 before using the non-root image. New image directories are prepared, but an existing root-owned volume is not automatically repaired. Verify merchant cover uploads and private ledger generation.
3. Run `python3 scripts/play_release_preflight.py` after deployment. Privacy/deletion pages must load without authentication. Verify `/support/faqs` returns 401 without login and 200 with a valid account, rather than 404.
4. Rotate the database credential previously committed in Git history through the provider, coordinate all consumers and update the private VPS environment. A clean current tree does not revoke a leaked credential.
5. Wait for the existing Gradle process holding the project lock to finish. Its wrapper download has now completed; the attempted release build timed out waiting for that lock. Complete Android SDK tools/licenses. Reuse the registered upload key, set a version code higher than all prior uploads, and build a **fresh** release AAB. The current September artifact predates these fixes and must not be submitted.
6. Run `python3 scripts/play_release_preflight.py --bundle mobile/build/app/outputs/bundle/release/app-release.aab`. Additionally verify bundletool ZIP alignment is `PAGE_ALIGNMENT_16K`, the effective permissions/target SDK, and Console's certificate/version acceptance. ELF alignment alone is insufficient.
7. Register Play's **app signing certificate SHA-1** for `com.stepsy.run` in the Google OAuth project. Confirm Google sign-in and verified-email/password-reset delivery on the Play-installed build.
8. Perform physical-device acceptance: new/returning login; denied/revoked permissions; offline/retry/reconnect; pause/resume; reboot/day rollover; duplicate sync/redemption; ticket/reporting; and permanent account deletion with old-session rejection and email reuse. Keep AI disabled until its key, costs and moderation/report handling are verified.
9. Supply reviewer credentials, real offer/merchant availability, verified developer identity and any required closed-testing evidence. New personal accounts can be subject to a 12-testers/14-days requirement; Console determines applicability. Run Play's pre-launch report and fix its blocking failures.
10. Prove the intended concurrency against a representative staging environment on VPS-equivalent resources. The historical local 1000-account baseline does not establish 1000 concurrent-user production capacity.

Sources checked October 31, 2026:
[deletion](https://support.google.com/googleplay/android-developer/answer/13327111),
[declaration choices](https://developers.google.com/android-publisher/app-store-review/policy-declarations),
[review access](https://support.google.com/googleplay/android-developer/answer/15748846),
[data safety](https://support.google.com/googleplay/android-developer/answer/10787469),
[health permissions](https://support.google.com/googleplay/android-developer/answer/12991134),
[AI reporting](https://support.google.com/googleplay/android-developer/answer/13985936),
[16 KB compatibility](https://developer.android.com/guide/practices/page-sizes).

Validation evidence: 210 backend tests passed in a fresh isolated PostgreSQL database; 11 final leaderboard/support/public-page checks passed; 170 Flutter tests passed. No production deletion test, VPS deployment, fresh signed AAB, or Play-installed acceptance has been completed by this session.
