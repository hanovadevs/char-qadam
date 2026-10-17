# Docker rollout for the audited API

Latest API source: `4a183d4`, deployed for the native UI/admin Maps refresh on
2026-10-17. Migration 0008 is unchanged. The Stepsy-only Compose build/recreate
completed successfully and the container is healthy. HTTPS readiness and
non-mutating authenticated Maps validation probes passed. Private environment
contents and all eight other app containers' IDs/start times remained unchanged.
Root-only evidence/config backup is `/root/stepsy-rollouts/20261017-ui`; the
previous image is `stepsy-backend:before-ui-20261017`. No schema/data migration or
live store edits were needed. The matching admin auto-deployment is READY at
`https://admin.stepsyapp.com`; its hosted asset includes the new Maps instructions.
The subsequent walking-character follow-up changes the mobile presentation only.

The audited rollout on 2026-10-17 used `/root/qadam/char-qadam/backend`, Compose
service `qadam-backend`, container `qadam_backend`, and migrations through `0004`.
Only this container was replaced; all other apps retained their IDs/start times.
The initial checked application source was commit `ccfe58c`. Follow-up commit
`1fc687b` added HTTPS defaults, the Nginx site and private Docker ingress.
Reward recovery follow-up `769eff0` is also deployed, with migrations through
`0006`; its fresh backup/restore evidence and private key backup are under
`/root/stepsy-rollouts/20261017-redemption`.

Auth rollout: `c01f65e` was deployed with migration `0007`, the owner's new
Google project and Hostinger sender `contact@hanovadevs.com`. The matching APK is
installed on the Redmi and saved steps remained 233. The owner confirmed Google
sign-in and the live API returned 200. Actual verification and password-reset
emails reached the test inbox; code/replay/session controls passed. The temporary
test account was removed. The foreground tracking service is running.

Its root-only backup/config/previous image evidence is under
`/root/stepsy-rollouts/20261017-auth`. The public archive (40,189 bytes) restored
all 11 tables at 0006 in an isolated PostgreSQL 17 container before migration.
All 11 production tables retain RLS. The existing database/JWT/admin/receipt
secrets were preserved; all eight other app containers retained their IDs and
start times. The prior image is `stepsy-backend:before-auth-20261017`.

Rollback assets and a successfully restored public-schema backup are under
`/root/stepsy-rollouts/20261017-audit` (restricted to root). The admin credential and
signing key were rotated in the private backend `.env`; do not copy them into chat
or Git. The historically exposed database credential still requires provider-side
revocation. SMTP authentication and real inbox delivery now pass.

Mandatory email verification is enforced. Existing accounts need mailbox
ownership proof before receiving API access; old unverified sessions are rejected.
Do not roll back to older code that grants unverified access, or erase ownership
records by downgrading the schema.

Device-account rollout: `440f981` was deployed with migration `0008` and
the matching APK installed on the Redmi without clearing data (233 saved steps
preserved). The owner confirmed primary login, rejection of a different Google
account after logout, and return to the original account with rewards intact.
It requires the device header and device-bound user tokens, so older clients
need the update and existing users sign in again to choose their phone's account.
No account balances or vouchers are merged or deleted. Device consumption
history survives deactivation. See [DEVICE_POLICY.md](../DEVICE_POLICY.md).

Root-only rollout evidence is under `/root/stepsy-rollouts/20261017-device`.
The 41,230-byte pre-migration public-schema archive restored successfully at
0007 in an isolated PostgreSQL 17 container before activation. The rollback image
is `stepsy-backend:before-device-20261017`; private environment contents were
preserved and all eight other app containers retained their IDs/start times.
Post-rollout checks confirmed 0008 and RLS on all 12 application tables (excluding
the migration bookkeeping table). Live disposable-account probes passed device
conflicts, deactivation/transfer, zero points for replayed 1,000 steps, one point
for the next 100, retained original credits, legacy/copied-token rejection and
actual email verification. All temporary test users were removed. Backend,
admin and Android CI passed in
[39048543060](https://github.com/hanovadevs/char-qadam/actions/runs/39048543060).
See [AUTH_SETUP.md](../AUTH_SETUP.md) for the coordinated API/APK rollout and
Google error-10 package/signing-certificate configuration.

The owner added `api` A -> `72.62.250.191` in Namecheap BasicDNS. The API is now
live at `https://api.stepsyapp.com`. Its separate Nginx site is tracked in
[`deploy/nginx/stepsy-api.conf`](../deploy/nginx/stepsy-api.conf) and installed at
`/etc/nginx/sites-available/stepsy-api`. The legacy IP site was preserved for older
test installations. No preexisting Nginx config file was modified.

The certificate expires 2027-01-15; `certbot.timer` is enabled/active. A successful
renewal dry run included the deploy hook (`nginx -t` followed by a graceful reload).
Renewal uses webroot `/var/www/stepsy-acme`; preserve its HTTP challenge route when
changing redirects. Evidence is in `/root/stepsy-rollouts/20261017-https`.

Compose now publishes only `127.0.0.1:8001`. The server's private `.env` sets
`FORWARDED_ALLOW_IPS=127.0.0.1,172.16.4.1` for its inspected host proxy gateway.
If the Docker network changes, inspect the actual gateway and update this allowlist.
Do not use a wildcard. This ensures slash-normalization redirects retain HTTPS.
All other app containers retained their IDs/start times during the update.

These instructions describe this repository's `backend/docker-compose.yml`.
Recheck the server's current state before a later rollout.

## Before replacing the running service

For reward recovery (migrations 0005-0006), configure `REDEMPTION_RECEIPT_KEYS`
before installing the updated mobile build. Generate a dedicated Fernet key;
never reuse the JWT key or regenerate this key on each deploy. It encrypts the
saved voucher response inside the same transaction as the point deduction.
Back it up privately with the database backup. For rotation, prepend the new key
and retain older keys in the comma-separated list until existing receipts have
been re-encrypted. Keep the keyring and receipt rows through application rollbacks.
Missing/unreadable receipt keys fail without spending points again; the original
voucher remains available in Wallet.

The mobile client persists the request ID and confirmed points cost per account,
and clears it only after displaying the result (or a definitive rejected request).
The Recover purchase control remains available when the offer leaves the catalog.
Older clients without an Idempotency-Key retain their legacy behavior; distribute
the new APK for purchase recovery. Do not roll back to an API that ignores these
keys while the updated client is in use.

The schema uses FastAPI's own authentication and an owning PostgreSQL connection.
Migration 0006 enables RLS without client policies on all backend tables, denying
direct Data API access to anon/authenticated roles while preserving the backend
owner connection. It does not FORCE RLS on the owner. New direct Data API use
requires an explicit access-model review; do not add blanket public policies.

1. Record the current Git commit and container image ID. Keep the previous image
   available. Check disk space and take a database backup through the existing
   database operator; verify its restoration procedure.
2. Rotate the database credential that was committed historically. Update the
   server's private environment and other consumers, and revoke the old credential.
   Deleting a source line does not revoke access.
3. Set a newly generated `JWT_SECRET` on the server. The old API allowed fabricated
   Google login; retaining its signing key could keep previously issued sessions
   valid. Key rotation signs out existing users and administrators.
4. Set `ENVIRONMENT=production`, a unique `ADMIN_PASSWORD` of at least 12 characters,
   the real Google client audience, SMTP delivery settings and explicit admin CORS
   origins. Use `.env.example` only as a variable reference; preserve real server
   configuration and keep credentials out of Git, terminal transcripts and images.
5. Confirm the owned HTTPS API domain and reverse proxy. The mobile API URL and
   admin proxy must target it for release. Do not publish a debug APK as a release.

## Rollout using the repository Compose service

From the **confirmed backend checkout on the VPS**, after updating the checkout
to the checked main commit and completing the steps above:

```sh
docker compose build qadam-backend
docker compose run --rm --no-deps qadam-backend alembic current
```

Check the existing database revision before starting the new app. The checked
chain is `0001 -> 0002 -> 0003 -> 0004 -> 0005 -> 0006 -> 0007 -> 0008`. If the database has existing tables but no
Alembic revision, inspect its schema before establishing a baseline. Do not stamp
`head` or delete tables to silence a migration failure. Migration 0003 accommodates
the older manually added merchant columns; it does not invent merchant identities.

```sh
docker compose run --rm --no-deps qadam-backend alembic upgrade head
docker compose up -d --no-deps qadam-backend
docker compose ps qadam-backend
docker compose exec -T qadam-backend alembic current
```

The Compose startup command also applies migrations. Run only one rollout/migration
process at a time. The default host port is 8001; preserve the server's actual
`HOST_PORT` and proxy mapping rather than assuming the public API uses that port.

## Verify the public deployment

- `/health` returns 200 with the expected environment and `/health/ready` returns
  200 with a connected database. Liveness alone does not verify the database.
- Anonymous `/admin/auth/me` and `/admin/config` must return 401. The old live API
  returned 200 for the former and 404 for the latter.
- OpenAPI `SyncOut` includes `points_earned_today`, `steps_per_point` and
  `daily_step_cap`. Verify an authenticated sync's actual values with a test account.
- Sign in again after key rotation. Test real Google login, inbox password reset,
  refreshed balances, own-store voucher validation and single redemption, plus
  rejection at another store. Use development reward inventory for these checks.
- Repeat the Redmi tracking/refresh checks against the deployed API and check
  container health/errors without publishing tokens or customer data.

If application rollback is necessary, preserve the migrated data and review the
old image's schema compatibility first. Migration 0003 deliberately refuses a
destructive automatic downgrade; do not force a downgrade or restore over newer
customer activity without an explicit recovery plan.
