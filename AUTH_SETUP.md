# Stepsy authentication setup

## Google Android login

The owner reported `ApiException: 10` on the Redmi. This indicates an Android
OAuth configuration problem, before the backend token exchange. The installed
local debug build now signs in successfully with the owner's new Cloud project:

| Setting | Value |
|---|---|
| Android package | `com.stepsy.run` |
| Debug certificate SHA-1 | `0F:40:FE:40:AB:FF:26:EB:EE:60:66:2D:1D:71:DD:93:2C:2F:D2:B7` |
| Debug certificate SHA-256 | `E0:23:0C:B7:03:E4:CD:B9:1E:FF:32:99:E8:26:22:C3:C4:7B:E4:A1:0A:65:37:C3:16:2C:7B:D8:D3:8A:59:D6` |
| Web/server client ID | `98556293307-3mrudhprtrgadopvjjfucclb22hoq6ls.apps.googleusercontent.com` |

In Google Cloud's Google Auth Platform -> Clients, select the project owning
that web client. Create or correct an **Android** OAuth client using the package
and SHA-1 above. Keep the **web** client ID as the mobile `serverClientId` and
backend `GOOGLE_CLIENT_ID`; an Android client ID cannot replace it. If the project
is inaccessible, its owner must grant access or supply a new web client from a
project they control, with a matching Android client.

Complete consent-screen configuration and, if testing mode applies, add the
intended test accounts. Then retry on the physical Redmi. No OAuth client secret
belongs in the APK. With explicit `serverClientId`, a Firebase project and
`google-services.json` are not required for this existing sign-in flow.

The local debug certificate is not a production signing identity. No release
keystore is configured in this checkout. Register the release certificate and
Google Play app-signing certificate before those builds are tested/distributed.
CI-generated debug APKs can have a different debug certificate; do not assume
Google login will work on them with the local certificate registration.

References: [Flutter Android sign-in configuration](https://pub.dev/packages/google_sign_in_android),
[Google Android OAuth credentials](https://developers.google.com/workspace/guides/create-credentials#android).

## Verification email

The owner selected `contact@hanovadevs.com` and confirmed Hostinger. Use these
settings in the private backend `.env`:

```dotenv
SMTP_HOST=smtp.hostinger.com
SMTP_PORT=465
SMTP_USE_SSL=true
SMTP_USERNAME=contact@hanovadevs.com
SMTP_FROM=Stepsy <contact@hanovadevs.com>
SMTP_PASSWORD=<mailbox password, kept private>
```

Use the mailbox's actual provider settings if different. The real `.env` is
ignored by Git. Never commit or print the password. Configure and test the sender
before deploying migration 0007: existing accounts have no historical mailbox
ownership proof and will need verification on their next login. Old access
tokens cannot access customer or merchant endpoints until verification.

Initial setup using `team@hanovadevs.com` was rejected. The owner corrected the
mailbox to `contact@hanovadevs.com`; authenticated SMTP over SSL now passes.
The owner also supplied the new Google web client ID shown above. The matching
APK passed analysis, all 47 Flutter tests and its debug build (39.6 seconds).
It is installed on the Redmi; saved steps remained 233 before and after the
update. The owner confirmed Google sign-in continues, the live API returned 200
for `/auth/google`, and the foreground step-tracking service is running.

The API at `https://api.stepsyapp.com` is deployed from `c01f65e` with migration
0007. A mixed-case legacy `Google_Client_ID` entry was removed: Pydantic resolves
settings case-insensitively, so retaining it alongside `GOOGLE_CLIENT_ID` selected
the old audience. Keep a single canonical key and verify the actual runtime value.

The live HTTPS registration flow delivered its verification email to the real
inbox. Unverified access, incorrect codes, resend cooldown and replay were
rejected; the correct code enabled verified sign-in. Password recovery also
delivered its mail, worked once and revoked the previous session. The temporary
test account was removed after these checks; passwords, codes and tokens were
not printed or committed. External inbox deliverability and the production Play
signing identity remain release acceptance checks.

Reference: [Hostinger mail configuration](https://support.hostinger.com/en/articles/1575756-how-to-get-email-account-configuration-details-for-hostinger-email).

## Implemented contract and rollout

- Registration returns a purpose-limited `verification_token`, email and resend
  delay, never an access token. Correct-password login to an unverified account
  returns the same challenge. The app opens the verification screen.
- The inbox receives a six-digit code, valid for 10 minutes and a single use.
  Only a keyed hash is stored. Five wrong attempts lock that code, including
  across workers/restarts. Sending is limited by a database-backed 60-second
  account cooldown and per-IP route limits.
- `/auth/verify-email` accepts the challenge and code. The challenge expires in
  30 minutes and cannot authorize protected APIs. Success records verification,
  invalidates older credentials/challenges, and issues a user access token.
- `/auth/resend-verification` returns a renewed challenge after delivery. A new
  code replaces the old one. Mail transport failure never grants access.
- Restarting during verification returns to sign-in; the app never stores a
  password or saves a verification challenge as an access token. Signing in
  again resumes verification. Expired challenges can also be restarted there.
- Google identity is bound by `sub`, not a changeable email address. Google's
  verified Gmail/Workspace mailbox proof is accepted; a first connection using
  a third-party Google email requires the Stepsy mail code. An unverified local
  password is invalidated when Google proves ownership, preventing preclaimed
  passwords from gaining access after somebody else's Google login.
- Successful emailed password recovery also proves mailbox access, records
  verification and revokes older sessions. Reset tokens bind the current email
  and credential version, so tokens sent to an old address cannot verify a new one.
- Changing a customer or merchant email in the admin portal clears old mailbox
  proof, Google binding, pending codes and existing sessions. The new address
  must be verified; editing other profile fields preserves verification.
- Migration 0007 adds ownership/challenge fields. It does not fabricate
  historical verification. It normalizes existing emails after checking for
  case collisions and refuses automatic downgrade that would erase proof.

Deploy API and mobile together after SMTP is configured. Preserve a Stepsy-only
image/config/database backup; apply Alembic 0007 and run readiness, actual inbox
delivery, wrong/expired code and verified-login smoke checks. Install the new APK
using `adb install -r`, preserving app data. Confirm Google on-device after Cloud
client configuration. Unit/mock mail tests do not establish inbox delivery or
Google OAuth acceptance.

The 2026-10-17 rollout backup is under `/root/stepsy-rollouts/20261017-auth`
(root-only). The 40,189-byte public-schema archive restored all 11 tables at 0006
in an isolated PostgreSQL 17 container before migration. Production is now at
0007 and all 11 tables retain RLS. Existing database/JWT/admin/receipt secrets
were preserved. All eight other app containers retained their IDs/start times.
CI [39045527202](https://github.com/hanovadevs/char-qadam/actions/runs/39045527202)
passed for the deployed source.

Authentication references: [Google ID token verification and mailbox authority](https://developers.google.com/identity/gsi/web/guides/verify-google-id-token),
[OWASP email verification](https://cheatsheetseries.owasp.org/cheatsheets/Email_Validation_and_Verification_Cheat_Sheet.html).
