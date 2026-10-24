# Stepsy: Google Play internal testing

Checked against the app and Google's current documentation on 2026-10-17.
Use **Internal testing**, not Internal app sharing, for the first test track.
Internal testing supports up to 100 Google-account testers and can start before
the full store setup is complete. Apps distributed exclusively through internal
testing are exempt from the Data safety form. This does not waive the need for
truthful disclosures when another track is added.
[Google's internal testing instructions](https://support.google.com/googleplay/android-developer/answer/9845334?hl=en)

## Bundle and signing

The checkout initially contained only a debug APK at
`mobile/build/app/outputs/flutter-apk/app-debug.apk`. That is the USB development
build, not the Google Play upload artifact. No release key was configured.

A release `.aab` must be signed with the app's upload key. Before generating the
first key, establish whether `com.stepsy.run` has any earlier Play uploads. If it
does, reuse its configured upload key or complete Play's upload-key reset process.
Do not replace a registered key with a newly generated one and expect it to match.

Once signing is configured, build from `mobile/`:

    flutter build appbundle --release

Use the actual `.aab` reported by Flutter under
`mobile/build/app/outputs/bundle/release/`. A preflight unsigned bundle must not
be uploaded or described as upload-ready. Keep keystores/password properties out
of Git and maintain a separate private backup.
[Flutter release/signing guide](https://docs.flutter.dev/deployment/android),
[Google Play signing](https://support.google.com/googleplay/android-developer/answer/9842756?hl=en).

The current Redmi uses the debug certificate. A Play-signed build cannot update
that differently signed installation in place. Preserve the debug installation
and its local step data; use another test device initially or plan the transition
before any uninstall. Creating an AAB does not require clearing the Redmi.

## First app / test release fields

| Field | Value |
| --- | --- |
| App name | Stepsy |
| Default language | English (United States), en-US |
| App or game | App |
| Free or paid | Free, for the current free-to-download product |
| Package | com.stepsy.run — comes from the bundle |
| Category, if requested | Health & Fitness |
| Support / testing feedback email | contact@hanovadevs.com |
| Internal tester list name | Stepsy internal testers |
| Testers | The actual Google-account email addresses of your testers |
| Release name | 1.0.0 – Internal test 1, if this is the first release |
| Version code | Must be higher than every previously uploaded code; first upload can use 1 |

Create app → Test and release → Testing → Internal testing → Testers → create
the email list, select it and save. Under Releases, create a release, enroll in
Google-managed Play App Signing when prompted, upload the signed AAB and fill
the release notes. Review errors, then choose the internal-testing rollout only.
Copy the opt-in link from the Testers tab; testers must join using the same
Google account that was added to the list.

Release notes to paste:

    <en-US>
    First Stepsy internal test.
    • Daily step tracking and an animated walking buddy.
    • Google sign-in and verified email accounts.
    • Partner rewards, Google Maps links and QR vouchers.
    • One active account per phone.
    Please report step accuracy, background tracking and reward issues to contact@hanovadevs.com.
    </en-US>

## Google login on the Play-installed build

After uploading, open Play's app-signing page (currently Protected with Play →
Play Store distribution → Go to Play app signing; some Console layouts expose
this under App integrity). Copy the **app signing certificate SHA-1**, not merely
the upload certificate. In the Google Cloud project containing web client
`98556293307-3mrudhprtrgadopvjjfucclb22hoq6ls.apps.googleusercontent.com`, create an
Android OAuth client for `com.stepsy.run` and that SHA-1. Register each relevant
Play app-signing fingerprint if multiple signing keys are shown. Retain the
existing web/server client ID. Missing this registration can cause error 10 again.
[Google's API-provider registration instructions](https://support.google.com/googleplay/android-developer/answer/9842756?hl=en).

## Copy for the store listing, when requested

Short description:

> Walk, track your steps and turn everyday movement into partner rewards.

Full description draft:

> Make more of your everyday movement with Stepsy.
>
> Track your daily steps, follow your progress and build a walking streak. Your
> walking buddy moves along a milestone path as your step total grows.
>
> Sync your activity to earn points, explore available partner offers and redeem
> points for vouchers. Open a partner's saved location in Google Maps, then find
> your voucher in My rewards and show its QR code at the store.
>
> Sign in with Google or a verified email account. Stepsy links one active
> account to each app-scoped Android device to help prevent repeated rewards
> from the same steps.
>
> Motion permission is used for step tracking. With permission, Health Connect
> step totals can help reconcile your activity. Stepsy syncs daily totals to
> calculate points; it does not track your GPS route.
>
> Partner availability, point costs and voucher validity depend on each offer's
> terms. Distance and energy figures are estimates.
>
> Questions or feedback: contact@hanovadevs.com

This is product copy, not proof of nationwide partner coverage. Do not add
unconfirmed brand names, cash payouts, guaranteed earnings or accuracy claims.
[Listing field requirements](https://support.google.com/googleplay/android-developer/answer/9859152).

## App content forms, if Console asks

- **Health apps:** Activity and Fitness. The app tracks steps; do not declare
  that it has no health-related features.
  [Health declaration](https://support.google.com/googleplay/android-developer/answer/14738291?hl=en).
- **Financial features:** the declaration includes **Rewards, points, frequent
  flier miles, and other incentives**. That matches Stepsy's points/voucher
  feature. Do not select lending, banking, cash transfer or cryptocurrency.
  [Google's declaration choices](https://developers.google.com/android-publisher/app-store-review/policy-declarations).
- **App access:** some/all functionality requires login. Supply a dedicated,
  verified customer test account with a reusable password and instructions;
  do not give reviewers your personal Google password. The one-account/device
  rule applies; the same customer account can use multiple devices. Merchant
  review, if required, needs a separate provisioned test account/device.
  [Review access requirements](https://support.google.com/googleplay/android-developer/answer/15748846).
- **Ads:** no ad-network SDK was found. Confirm whether any partner placements
  are paid/sponsored advertisements before selecting No; lack of an ad SDK alone
  does not establish the business answer.
- **Target audience:** select the intended age groups as a product decision.
  The walking character does not establish a children-directed audience.
- **Content rating:** answer the actual questionnaire; Google assigns the rating.
- **Foreground service:** the implemented tracking service is type `health`.
  Explain user-authorized background step counting with a persistent notification.
  If requested, supply a real demonstration video showing permission/activation,
  the ongoing notification, walking, and the updated total. Do not invent a URL.
  The current dependency-merged manifest also includes service types that must be
  reviewed before the final declaration; do not claim GPS tracking to justify an
  unused location service.
  [Foreground-service declaration](https://support.google.com/googleplay/android-developer/answer/13392821?hl=en).

## Data safety / privacy: confirmed facts and unfinished items

Do not mark “no data collected.” Daily step totals, account identifiers/email and
an app-scoped device identifier are sent to the HTTPS API. Reward transaction
records and vouchers are retained. Health/fitness totals, personal identifiers,
device identifiers and reward purchase/activity records need accurate disclosure
when the Data safety form applies. Google sign-in SDK/token handling, leaderboard
display and service-provider transfers must be included in the final assessment;
do not blanket-answer “no sharing” without reviewing those flows.

The app reads only steps from Health Connect, not heart rate, medical records or
GPS routes. It does not currently implement cash payouts, bank/card collection,
loan applications or cryptocurrency.

Profile **Deactivate account** currently revokes access and retains activity and
reward rows. It is not full data erasure. A complete deletion/retention process
and a real public deletion page remain unfinished. A public privacy-policy URL
also needs to be published/verified; owning stepsyapp.com does not make a guessed
`/privacy` or `/delete-account` URL work. Do not enter fictional URLs or attest to
features not implemented. Internal-only testing does not require completing the
Data safety form, so do not confuse these later-track requirements with the
minimal internal-track upload.
[Data safety scope and internal-track exemption](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en).

For new personal accounts, a later production-access application normally needs
a **closed** test with at least 12 opted-in testers for 14 continuous days.
Internal testing does not replace that closed-test requirement. Account type and
creation date must be checked before applying this rule.
[Personal-account testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465).
