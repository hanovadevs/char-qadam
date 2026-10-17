# Docker rollout for the audited API

The audited rollout on 2026-10-17 used `/root/qadam/char-qadam/backend`, Compose
service `qadam-backend`, container `qadam_backend`, and migrations through `0004`.
Only this container was replaced; all other apps retained their IDs/start times.
The checked application source was commit `ccfe58c`.

Rollback assets and a successfully restored public-schema backup are under
`/root/stepsy-rollouts/20261017-audit` (restricted to root). The admin credential and
signing key were rotated in the private backend `.env`; do not copy them into chat
or Git. The database credential still requires provider-side revocation. The API
remains on HTTP while DNS/TLS for the owner's selected `api.stepsyapp.com` are
pending; SMTP is not configured. DNS currently uses Namecheap BasicDNS and the
`api` hostname does not resolve. Add an A record with host `api`, value
`72.62.250.191`, and TTL `Automatic` in the domain's Advanced DNS Host Records.
After verifying DNS, configure only Stepsy's Nginx hostname/certificate, verify
public HTTPS, then update the mobile/admin API URLs and rebuild.

These instructions describe this repository's `backend/docker-compose.yml`.
Recheck the server's current state before a later rollout.

## Before replacing the running service

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
   admin proxy must target it for release. Do not publish the debug HTTP-default APK.

## Rollout using the repository Compose service

From the **confirmed backend checkout on the VPS**, after updating the checkout
to the checked main commit and completing the steps above:

```sh
docker compose build qadam-backend
docker compose run --rm --no-deps qadam-backend alembic current
```

Check the existing database revision before starting the new app. The checked
chain is `0001 -> 0002 -> 0003 -> 0004`. If the database has existing tables but no
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
