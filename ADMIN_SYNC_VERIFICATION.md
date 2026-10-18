# Admin responsiveness and shared-data verification - 2026-10-18

## User story

An administrator configures a store, its Maps destination and an offer. A customer
syncs steps, earns points and purchases a voucher once. The merchant validates and
redeems it once. Customer, merchant and admin views must agree on those records.

## Changes

- User-directory balances and steps are separate grouped subqueries joined into
  one read. This avoids one balance query per user and avoids multiplying ledger
  totals by activity rows.
- Seven dashboard metric reads are now one SQL statement. Store aggregates and
  merchant email are returned in one read. Offers, vouchers, redemptions and
  ledger entries load their parent records using joins instead of extra queries.
- Voucher search now accepts the UI's `search` parameter, including code/email;
  partner and offer filters are applied too. The dashboard requests only eight
  recent redemptions, rather than downloading the full history to slice it.
- Primary admin pages render session-local cached data on return and refresh in
  the background. Visible pages refresh every 30 seconds and revalidate stale
  data on focus; hidden pages do not poll. Successful writes invalidate related
  snapshots. Filter changes cannot be overwritten by older responses.
- Search input is debounced by 250 ms. Concurrent identical reads share a request.
  The cache holds at most 100 filtered results, stays in memory, and clears when
  the login changes. A late response/401 from an old session cannot expose old
  data or log out its replacement. Temporary network errors preserve valid login.
- Dashboard metrics render independently of slower charts/history. Empty saved
  results are cached too, and background refresh retains visible rows.
- Mobile pages check for updates on returning to a stale tab or resuming the app;
  the visible tab also refreshes once a minute while resumed. Pull-to-refresh
  remains available. This lets admin changes reach already-open customer screens
  without discarding their state. Sync/profile paths support an older API during
  rollback; a missing summary endpoint falls back to the existing sync operation.

These are refresh-based views of the same API/database, not instantaneous push
notifications. The API remains authoritative for price, stock, points, device
ownership and voucher use; cached display data cannot authorize transactions.

## Baseline on the live API

Single samples from inside the API container, before these admin query changes:

| Read | Before | After deployment |
| --- | ---: | ---: |
| Overview | 4,746 ms | 1,494 ms |
| Users, 36 records | 10,931 ms | 1,499 ms |
| Stores | 3,226 ms | 1,501 ms |
| Offers | 2,236 ms | 1,494 ms |
| Vouchers | 3,234 ms | 1,507 ms |
| Redemptions | 3,454 ms | 1,507 ms |
| Charts | 2,489 ms | 2,491 ms |

These exclude browser/proxy latency and are not load-test percentiles. The API's
Sydney database region still adds network latency, as recorded in PERFORMANCE.md.
The charts query was not rewritten; its timing remained effectively unchanged.

## Rollout

Implementation commit `9c9e3adcf2cd935259dfd991ca8d648958a1f245` is pushed to
main and deployed to the healthy `qadam_backend` container. All eight other
containers retain their original IDs/start times; Stepsy's environment hash is
unchanged. No schema migration or production lifecycle mutation was needed.
The SSH client timed out after the successful rollout; a new connection verified
the source commit, completed build and healthy replacement before timing reads.

Vercel production deployment `dpl_8j52MMYtKskYjfiZ7kTLBfuQAJGG` is READY for that
exact commit and aliases `admin.stepsyapp.com`. Its hosted JavaScript contains
the session race guard, background revalidation and recent-redemption limit.
The public API health probe passed. The final profile APK was installed in place
on the Redmi, launched successfully and has a running foreground tracking service.
The signing certificate matches the existing app; there was no uninstall/data
clear. Owner verification of the final account totals remains separate evidence.

## Regression evidence

- **145 API tests passed** on isolated loopback PostgreSQL, including the full
  shared lifecycle in `backend/tests/test_admin_consistency.py`:
  - Admin price/Maps edits appear in the customer catalog.
  - 1,000 steps yield 10 points, a six-point purchase leaves four, and replay
    returns the same voucher without another debit or stock decrement.
  - Merchant nonce validation/redemption succeeds once; replay is rejected.
  - Admin voucher search and the customer's used wallet show the same status.
  - A two-point admin adjustment yields six in the directory, balance and today
    summary. Overview totals change by the expected steps/redemption.
  - Seven key admin reads execute exactly one SELECT each, including the user
    directory; this assertion guards against reintroducing per-record queries.
- **15 web tests passed**, including real React hook rendering with delayed and
  reordered responses, cached re-entry, shared reads, mutation refresh and visible
  versus hidden polling. Production Vite build passed.
- **72 Flutter tests passed**; analysis passed. New coverage includes compatibility
  with an API that lacks the read-only summary endpoint. The owner accepted the
  earlier optimized build's page speed, syncing and preserved steps on the Redmi.

## Operational limits

The tests exercise current contracts and concurrency controls; they cannot
guarantee that every future change is correct or establish nationwide capacity.
CI automatically runs the backend, admin and Android checks on main/PR changes.
A representative staged load test and a database/API placement plan are still
needed before extrapolating to a large launch.

Browser-control inventory initially had no browser connected. React render/API
tests passed; live browser click-through evidence must be recorded separately.
All lifecycle mutations above ran against the isolated test database, not live
customer accounts. Production timing checks only read live admin data.
