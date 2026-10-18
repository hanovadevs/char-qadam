# One reward claim per account

A customer can purchase a given offer ID once for the lifetime of their account.
Different accounts can each claim the offer, and a customer can still claim
other offers. An administrator can create a new offer for a new campaign;
editing/reactivating an existing offer does not reset its claims.

## Enforcement and existing data

- The API checks purchase history while holding its existing user and offer row
  locks. Distinct concurrent purchase IDs cannot each issue a voucher. The check
  is included in the locked offer read, without an additional database round trip.
- A successful `OFFER_SPEND` ledger entry or any existing voucher counts as a
  claim. Used, expired or cancelled vouchers still count. Deleting a voucher in
  the admin panel does not erase its purchase ledger or permit another purchase.
- The same idempotency key still recovers the original encrypted receipt before
  applying the new-purchase check. It never spends additional points or stock.
- Historical purchases are recognized immediately. Existing points, vouchers,
  inventory and duplicate historical records are not rewritten or removed.
  No schema migration is needed; existing per-user indexes support the reads.
- `/offers` includes account-specific `already_redeemed`. It loads the partner
  and claim status in the same query. Authorization stays server-side, including
  for older clients that do not understand the new display field.

## Mobile behavior

Claimed rewards say **Claimed** and cannot be purchased again. They are omitted
from **Ready for you**, while remaining visible in **Explore all** for terms and
store location. The card explains that the voucher is in **My rewards**.
Successful purchases update the current list and account-scoped disk cache
immediately. A stale catalog response cannot re-enable a known claimed reward.

New purchases navigate directly to the highlighted voucher in Wallet. Three
short staggered fireworks use the existing teal, mint and amber theme tokens.
They paint in an isolated overlay for 2.2 seconds, without network/image assets,
sound, a modal delay or blocked touches. The overlay removes itself and disposes
its animation controller. Recovery of an old purchase does not replay fireworks.
Reduced-motion users retain the textual success notice without the fireworks.

## Verification

- Full isolated API suite: **153 passed**. Flutter: **75 passed**, with clean
  analysis. These checks include the existing auth, device, tracking, admin,
  merchant and purchase-recovery regressions as well as the new cases.
- PostgreSQL regressions cover all voucher states, deleted vouchers, legacy
  voucher-only history, concurrent distinct request IDs, other accounts/offers,
  unchanged balance/stock after rejection and recovery of the original receipt.
- The short-code collision test now purchases two different offers, preserving
  its savepoint/atomicity assertion under the new business rule.
- Flutter regressions cover stale response/cache races and account isolation,
  a disabled claimed card despite sufficient points, immediate Wallet navigation,
  QR-button interaction during fireworks, overlay cleanup and reduced motion.
- The captured fixture preview is `artifacts/redesign/reward-fireworks.png`.
  It contains fictional customer/reward data, not production account details.

References: [PostgreSQL row locks](https://www.postgresql.org/docs/current/explicit-locking.html#LOCKING-ROWS),
[Flutter repaint-driven CustomPainter](https://api.flutter.dev/flutter/rendering/CustomPainter-class.html).
