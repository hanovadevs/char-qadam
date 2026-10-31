# Admin responsiveness and rollout checks

The inspected Nginx errors for the Users page were upstream connection refusals/resets while the API was unavailable. Changing the frontend error banner cannot repair an unavailable API. Build and verify the replacement before switching traffic; keep the previous image and private configuration for rollback.

The VPS connects to the existing remote PostgreSQL session pooler. A controlled read-only probe measured repeated simple reads at about 1.9–2.2 seconds with explicit transactions versus about 0.64–0.96 seconds with autocommit. These are samples from this route, not a capacity guarantee.

Reviewed SELECT-only admin routes and readiness now use a separate autocommit pool, which avoids unnecessary BEGIN/ROLLBACK network round trips. Customer authentication and every mutating route retain the transactional pool. Do not move a write or a SELECT FOR UPDATE to `get_read_session()`.

Default connection budgets per worker are five transactional connections plus five overflow, and two read connections with no overflow. Two workers therefore allow at most 24 application connections. Both pools warm before startup completes and have bounded connection/command/pool waits. Recheck the database's connection allowance before increasing these values or worker counts.

Users load 50 rows per page plus one next-page sentinel. The API caps a request at 200 records and aggregates activity/points for the selected page only. Search/status changes reset to the first page; stale-response and session cache protection remain in place. Admin requests have a 15-second overall deadline. A gateway failure retries a GET once; writes never automatically repeat, and network errors do not sign the administrator out.

The Docker healthcheck and `/health/ready` verify the database. The admin host proxies `/health/ready` to the API instead of returning the SPA with a misleading 200 response.

## Verified locally

- 212 backend tests on an isolated loopback database, including customer/merchant/admin reward consistency, pagination and transaction isolation.
- 32 admin tests and production build, including pagination controls, gateway retry, stalled-request timeout and write non-repetition.
- 174 Flutter tests and clean analysis, including offline support guidance, preserved drafts, private conversations and larger-text layouts.

The production rollout preserved all 11 unrelated running containers and their start times. Post-rollout authenticated reads on the admin host returned 200 in sampled ranges of approximately 0.67–1.04 seconds (Users: 0.74–1.01 seconds), compared with about two seconds before. The API was healthy with zero restarts at verification. The VPS uses explicit per-worker budgets of three write connections plus two overflow and two read connections, or 14 maximum across two workers. Timing samples are not a future uptime or load guarantee.

## Production rollout

Preserve the server's private `.env`, receipt keys, uploads and all existing account/reward data. Record container IDs/start times before/after to ensure unrelated applications are unchanged. Back up the database and media; validate restoration in an isolated container, never over the live database.

Use the checked main commit. Where a standby is used, run it with a small pool and one worker, wait for database readiness, then change only Stepsy's Nginx upstream. Keep that standby available while replacing the Compose service, and switch back only after it passes readiness and authenticated reads. A graceful Nginx reload must pass `nginx -t` first. Do not run `docker compose down`, delete named volumes, or restart unrelated containers.

After rollout, check direct and admin-proxied login, Users, overview, stores and support reads. Confirm anonymous admin access remains denied, media URLs load, the new logo is served, the migration revision remains correct, and the new container stays healthy. Record actual timings separately from these local results.
