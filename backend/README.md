# Stepsy API

FastAPI + async SQLAlchemy + PostgreSQL. Run commands below from `backend/`.

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
if (!(Test-Path .env)) { Copy-Item .env.example .env }
# Fill DATABASE_URL and secrets in .env, then:
.\.venv\Scripts\python.exe -m alembic upgrade head
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

The API exposes `/health`, `/health/ready`, and OpenAPI at `/docs`. User routes
cover auth, daily activity, points, offers, vouchers, profile, and leaderboard.
`/partner/v1` handles merchant credentials and single-use redemption. Every
`/admin` route except `/admin/auth/login` requires an admin token.

For production set `PUBLIC_API_URL` to the public HTTPS API domain for cover images,
`ENVIRONMENT=production`, a random `JWT_SECRET`, a unique
`ADMIN_PASSWORD` (12+ characters), the real `GOOGLE_CLIENT_ID`, and the SMTP
settings in `.env.example`. Recovery fails closed with 503 until email delivery
is configured. Tokens are never returned to a recovery requester. Migrations
must run before starting the updated API; revision 0004 adds session revocation.

## Isolated tests

Tests ignore the shared database configuration. `TEST_DATABASE_URL` must use a
loopback host and a database name ending in `_test`. They run real Alembic
migrations, use PostgreSQL locks, and exercise the complete API reward lifecycle.

```powershell
docker run --detach --name stepsy-tests -e POSTGRES_USER=stepsy_test -e POSTGRES_PASSWORD=local-audit-only -e POSTGRES_DB=stepsy_test -p 127.0.0.1:55432:5432 postgres:16-alpine
$env:TEST_DATABASE_URL='postgresql+asyncpg://stepsy_test:local-audit-only@127.0.0.1:55432/stepsy_test'
.\.venv\Scripts\python.exe -m pytest tests -q
```

Use only a disposable test database: tests create and clean test records.
No tests should ever target the production or shared development database.
The deprecated manual migration no longer embeds credentials, creates guessed
merchant identities, or sets common default passwords.

The React admin is independently built in `web/`. Local API serving can expose
that build under `/portal` when `web/dist` exists in the repository layout;
backend-only Docker builds use the separately hosted admin portal.

See [the launch audit](../docs/operations/LAUNCH_AUDIT.md) before a public release.

Support AI is optional. Set OPENAI_API_KEY on the backend and enable its bounded usage in Admin → Support after migration 0012.
