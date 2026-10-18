# Stepsy responsiveness work - 2026-10-18

The reported delays were sign-in, step syncing, and opening another page.

## Confirmed bottlenecks and changes

- Successful login previously waited for a second `/auth/me` request before
  opening the app. Login and email verification now return the same safe profile
  as `/auth/me`. The client uses it immediately, with a fallback for older APIs.
  Startup storage reads run together. Password verification runs off the API event
  loop; its security checks and hashing strength are unchanged.
- Every successful step sync used to await two sequential history requests and
  destroy/recreate Points state, even when no points changed. The sync now finishes
  after its own server response; history loads in the background, in parallel,
  at most once a minute during automatic syncing. Points refreshes only after a
  changed balance/award and retains its visible data.
- Unchanged steps now use a read-only `/activity/today` summary instead of the
  reward-writing sync transaction. An account-scoped, same-day cached baseline
  permits this shortcut after reopening too. A previous day's cache is ignored;
  mismatched phone/account dates are not applied to today's total. New steps
  still pass through the full transactional reward/device-consumption checks.
- Forced refresh no longer repeats already-granted tracking permission requests.
  The saved native counter is emitted before waiting for optional Health Connect.
  Successful health-store reads are throttled to once per 30 seconds, without
  reusing old health readings with a new hardware baseline. Sensor counting and
  the existing source reconciliation remain intact.
- Points, Rewards and Wallet display their account-scoped disk caches before the
  fresh requests finish. Primary pages warm after the first frame. The existing
  indexed navigation shell preserves screens and scroll positions.
- Balance/history requests start together, Rewards no longer launches duplicate
  initial fetches, and overlapping refreshes share pending requests. Wallet keeps
  its loaded filters and rejects responses for an old filter. Mutations wait out
  earlier reads and request fresh data afterward, so deduplication cannot swallow
  a newly earned balance or a redemption update.
- Notification setup no longer blocks the first app frame. WorkManager registers
  from authenticated tracking rather than before rendering the login screen.
- The API reads the current user and device binding in one joined query and
  calculates the three balance aggregates in one SQL statement. These checks
  still consult the database on every authenticated request: account status,
  verification, token version, device ownership and generation are not cached.
- API startup now opens and initializes its existing five-connection pool with
  zero-row typed queries before accepting traffic. Constructing an engine had
  previously left connection and enum-codec setup to the first real requests.
  The pool limit, transaction handling and stale-connection checks are unchanged.

Cached values only render the UI. Spending points, issuing vouchers and merchant
validation still require server authorization. Cache keys remain account-scoped;
no accounts, balances or voucher records are merged.

## Baseline measured on the running API

These are individual samples from inside the Stepsy container using temporary,
verified test accounts. They exclude mobile radio, Google account selection and
UI rendering, and are not percentile/load-test guarantees.

| Operation before rollout | Time |
| --- | ---: |
| Email login | 4,573 ms |
| Additional profile request required by the old client | 1,996 ms |
| Points balance | 2,753 ms |
| Points history | 2,018 ms |
| Offers | 2,013 ms |
| Active vouchers | 1,758 ms |
| All activity history | 1,744 ms |
| Zero-step sync, separate sample | 4,692 ms |

The configured database pooler is in `ap-southeast-2` (Sydney). Warm `SELECT 1`
queries within one connection measured 245-246 ms; a new connection checkout
measured 5,715 ms in one probe. The geography/connection overhead remains a limit
on uncached network operations. No database migration or relocation is included.
[Supabase region reference](https://supabase.com/docs/guides/platform/regions).

After the first deployment, samples included 4,270 ms for login (with its
embedded profile), 1,242 ms for `/auth/me`, and 1,741 ms for balance. Later cold
samples varied substantially: login reached 10,268 ms and a write sync 7,205 ms.
The new read-only refresh measured 5,878 ms on its first request and 1,739/1,740 ms
on two following requests. This variance motivated the additional startup pool
warmup. These samples do not support a blanket claim that all network operations
are fast; cached rendering and removing chained requests are separate gains.

## Verification

- 72 Flutter tests passed, including performance regressions for
  response-profile sign-in, parallel reads, cached balance display, coalesced
  catalog/wallet requests, out-of-order filters, mutation freshness and a slow
  history request that does not keep sync busy, and reopening with an unchanged
  step baseline without a write transaction, plus fallback when an older API
  lacks the summary endpoint.
- Flutter analysis passed.
- 145 API tests passed against isolated local PostgreSQL after the admin
  consistency and query-count checks. All 20 auth/device tests passed too.
  The read-only summary also passed the 12 tracking/device tests; its values
  match a real sync and repeated reads do not change activity versions.
- All four infrastructure tests passed after pool warmup, including actual
  PostgreSQL verification of five checked-in connections, no leaked checkouts,
  and no changed user count.
- 15 admin web tests and the production build passed. Admin responsiveness and
  the shared reward lifecycle are documented in ADMIN_SYNC_VERIFICATION.md.
- An optimized profile APK is the on-device test candidate; it is not a Play
  release. Its certificate must match the installed debug-signed app before an
  in-place installation. Google Play upload remains paused at the owner's request.

Use the actual Redmi and the Flutter performance tools to assess frame times;
API timings and widget tests do not establish a universal frame-rate claim.
[Flutter performance guidance](https://docs.flutter.dev/perf/best-practices).
