# Device account and reward policy

The owner selected one active account per Android device after reproducing the
same physical step total in two accounts with separate points and vouchers.

## Behavior

- The first successful verified sign-in after this update claims the phone.
  Existing records are preserved. There is no guessed historical ownership and
  no merging of different accounts' points, vouchers or identities.
- Email/password and Google sign-in enforce the same server-side binding.
  Registration on an already-owned phone is rejected before sending mail.
  Email verification challenges also belong to the requesting device.
- Logout retains ownership. The same account can sign back in; another account
  receives a clear conflict message. Google sign-in opens the account chooser
  so a rejected account does not trap the user in repeated automatic sign-in.
- Profile deactivation releases the account's device bindings and revokes its
  sessions. A replacement account can then sign in. Suspension retains the
  reservation so a suspended account cannot use switching to evade the hold.
- Points and vouchers remain with the original account. The replacement starts
  with its own balance and wallet. Previously consumed daily device steps cannot
  earn points again, including after repeated deactivation/account replacement.
- Example: A earns 10 points at 1,000 steps. After A deactivates, B earns zero
  from those same 1,000 steps and one new point at 1,100. A's old wallet is never
  exposed to B. The device's daily cap and fractional steps survive transfer.
- One account can use multiple devices. User-level cumulative limits continue
  alongside device consumption limits; logging into another phone does not mint
  the same user-day total again.

## Implementation and compatibility

Android returns a SHA-256 pseudonym of its app-scoped `ANDROID_ID` through the
native method channel. Raw Android IDs, IMEIs, phone numbers and advertising IDs
are not sent. Foreground requests use `X-Device-ID`; a secure cached copy lets
WorkManager use the same identity. Foreground startup rechecks Android's value
rather than trusting a restored cache. Logout does not delete this identity.

Migration 0008 creates `device_bindings` and `device_activity_daily`, both with
RLS and no direct client policies. Device keys are unique; first claims and
transfers lock the binding. Access tokens bind device ID and ownership generation
in addition to the user's credential version. Protected APIs reject missing,
mismatched or stale device credentials. Merchant API keys remain available for
server-to-server POS integrations; mobile merchant sessions follow the policy.

Account deactivation, step earning and voucher issuance serialize on the user
row. Deactivation invalidates sessions and releases ownership in one transaction.
The consumption watermark is independent of account ownership and remains after
deactivation or account deletion. Legacy account activity within the accepted
sync window seeds consumed steps on first binding; this grants no new points.
It cannot identify or reverse duplicate rewards issued before device identity
was recorded. Historical financial records are not automatically changed.

API compatibility is deliberately enforced: old APKs without the device header
receive 426; legacy user tokens require a fresh sign-in. Deploy migration/API and
install the matching APK together. The user should choose the account they intend
to keep at the first sign-in. Do not clear app data or uninstall to update.

## Limits and launch checks

This enforces normal app use, not cryptographic proof of a physical device or
a real walk. Android scopes its ID by signing key, Android user/profile and
device; factory reset or a signing-key change can change it. A modified client
can forge a supplied identifier or step count. Cloned apps/profiles and stronger
device recognition require a Play Integrity/attestation design before making
fraud-proof reward claims. See [Android's identifier documentation](https://developer.android.com/reference/android/provider/Settings.Secure#ANDROID_ID).

Device identifiers and retained consumption history must be covered by the
published privacy/retention policy and Play disclosures. Login/registration and
onboarding explain the account/device rule; deactivation explains that rewarded
steps do not reset.

Acceptance covers competing first sign-ins and verifications, blocked email and
Google switching, missing/legacy credentials, copied tokens, deactivation races,
retained wallets, old-credit seeding, daily caps and same-step replay after
transfer. The physical Redmi check signs into the intended account, logs out,
rejects a different account, and successfully returns to the intended account.
Use disposable development accounts for deactivation tests, preserving real
customer accounts and vouchers.

## Verified rollout, 2026-10-17

Deployed `440f981` and migration 0008 to the Stepsy container only after a
successful isolated restore of its pre-migration backup. All 12 application
tables retain RLS. Live HTTPS probes with disposable accounts verified blocked
switching, session/device checks, release on deactivation, retained original
credits, and zero points for the replacement account's first 1,000 already
rewarded steps followed by one point at 1,100. Real mailbox verification also
passed with the device binding. Temporary records were removed.

The matching APK was installed on the Redmi Note 11 with 233 saved steps
preserved. The owner confirmed primary sign-in, rejection of another Google
account after logout, and return to the original account with its points and
vouchers intact. Real account deactivation was not needed for this phone test.
Backend, admin and Android checks passed in
[GitHub Actions](https://github.com/hanovadevs/char-qadam/actions/runs/39048543060).
