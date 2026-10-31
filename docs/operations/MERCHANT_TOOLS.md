# Merchant accounts, scanning and PDF ledgers

## Phone accounts

A phone may reserve one customer identity and one merchant identity. A second
customer or second merchant is rejected; signing out does not release either
reservation. Deactivation releases only its own slot. Account data is never
merged, copied or reset when switching. Personal points/vouchers remain with
their customer identity. Merchants use the customer account to earn points and
claim discounts. See [device policy](../product/DEVICE_POLICY.md).

User-initiated sign-out and merchant-to-customer switching show a confirmation
dialog. Cancel/dismiss keeps the current session; Confirm clears it and requires
sign-in again. An old dialog cannot clear a replacement session. Expired or
revoked sessions still clear immediately through the API error handler. Customer
settings show the regular Sign out action without a merchant-switch shortcut.

## Checkout

**Scan customer QR** opens the camera and requests camera permission on first
use. Scanning only fills and validates the voucher; the cashier still reviews
the benefit and confirms redemption explicitly. Manual code entry/paste remains
available when camera permission is denied. The scanner accepts Stepsy voucher
codes, opaque tokens and recognized Stepsy voucher links; it never opens a
scanned URL. The API still checks store ownership, expiry and single-use status.

## Ledgers and downloads

The PDF icon in the terminal opens **Merchant ledgers**. Choose a calendar week
(Monday-Sunday) or calendar month and a date within it. All boundaries and report
times use **Asia/Karachi**. Current periods are partial snapshots through their
generation time. Reports contain redeemed vouchers, not pending/cancelled
vouchers, customer email addresses, raw QR secrets, sales totals or profit.

Fixed discounts are totaled as PKR. Percentage offers retain their percentage
unit, and free items are labeled separately; these are not added into a monetary
total. Transaction timestamps, reward title/benefit, voucher code, terminal and
optional order reference are included. Headers repeat over multiple pages and
footers identify the store, period and report.

**Generate & save PDF** records an immutable snapshot, then opens Android's
document chooser. Choose Downloads or another destination. Canceling Save does
not delete the report: it remains in generation history with **Download PDF**.
Downloading again returns the same saved bytes, even after new transactions or
reward edits. Uncertain generation retries reuse a request ID rather than
creating another history entry. History is server-side and survives sign-out
and app reinstall. The first page shows 20 entries; Load more retrieves older
generations. A report is limited to 10,000 redemptions, with at most 100 new
generations per store/day. Oversized periods fail explicitly rather than
silently dropping rows; choose a week or contact support.

PDF files are private: `/partner/v1/ledgers/{id}/pdf` authorizes the current store
and verifies the saved file hash. Customer/other-store tokens cannot access
them. Responses disable shared caching. Android saves with the Storage Access
Framework; broad storage access is not requested.

## Deployment and retention

Apply **0010** (device slots) and **0011** (report history) before installing the
new APK. Back up and restore-test the Stepsy database first. Stop/recreate only
the Stepsy service when applying 0010: old code must not keep serving merchant
requests after their bindings move. The Compose startup migration then runs
with the new code. Preserve existing JWT/receipt keys and runtime environment.

PDFs live under `MEDIA_DIRECTORY/merchant-ledgers` in the existing persistent
`backend_stepsy_media` volume. This directory is not exposed by the public cover
route. Back up the database **and** media volume together. A generated ledger
protects its store from permanent deletion, including an empty report. Keep
stores archived to retain history. No automatic report pruning or destructive
schema downgrade is implemented. Rolling back to code that only understands a
single device slot is unsafe once both reservations are in use.

## Verification

- Isolated PostgreSQL: 192 backend tests passed, including both device slots,
  independent deactivation, store-scoped PDF access, period boundaries, immutable
  downloads, idempotent generation, and direct-data RLS denial.
- A fresh `0009 -> 0011` migration retained a real legacy-format merchant token,
  its generation and the physical step-consumption watermark.
- Flutter: 132 tests passed after the final sign-out UI changes. Analysis is
  clean. Profile APK and Android JVM tests passed.
- A 180-row synthetic PDF rendered to 16 pages; first/last pages were visually
  inspected for wrapping, repeated headings, units, footers and clipping.
- Physical camera, Android save chooser and two-account acceptance are recorded
  separately after installation; unit tests do not establish phone acceptance.

References: [mobile_scanner](https://pub.dev/packages/mobile_scanner),
[Android document storage](https://developer.android.com/training/data-storage/shared/documents-files),
[ReportLab](https://docs.reportlab.com/reportlab/userguide/ch7_tables/).

## Live rollout — 30 October 2026

Implementation `684b3d1` is live on the Stepsy API at schema **0011**. A private
48,713-byte public-schema archive restored successfully in an isolated
PostgreSQL 17 container; the new image then migrated that restored data to 0011
while retaining its 24 users and 8 device-day rows. The existing media volume
was also archived and retained. Temporary restore containers/network were
removed after the drill. All 11 other app containers retained their IDs and
start times during the Stepsy-only rollout.

An actual HTTPS smoke used disposable accounts to sign in a customer and a
merchant with the same device key, rejected second accounts of either type,
and verified both original sessions. It generated a private empty ledger,
checked retry idempotency and identical PDF downloads, and rejected customer
and other-store access. All disposable records, empty reports and files were
removed; operator audit entries remain. No real account or reward was changed
by the smoke test.

The owner confirmed on the Redmi that both account types work with personal
data intact, and accepted the camera, PDF saving/opening and generation history.
A completed in-store QR redemption was not part of that phone check.

The owner then requested confirmation before sign-out/account changes and the
removal of the customer settings merchant shortcut. Four new dialog tests cover
Cancel, Confirm, dismissal and replacement-session protection. Login/signup
help text now describes the two role reservations. Forced authentication
revocation still signs out immediately.

The final arm64 profile APK was installed using `adb install -r`, preserving
app data and the camera/motion permissions. Its SHA-256 is
`ECE8B32E57F0B16C45D4D78B4E8C3897FDBB7EC5E0E1AE1E8ABE863BC8597CEE`;
the installed APK hash was checked against the local build. The app starts
without a recorded startup exception. The 16 Android JVM tests passed on the
unchanged native implementation. No Play Console upload was performed.

Restricted backups, image reference and rollout logs:
`/root/stepsy-rollouts/20261030-merchant-tools/`.
