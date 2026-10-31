# Stepsy API

FastAPI, SQLAlchemy/asyncpg, PostgreSQL, PyJWT and bcrypt. Configuration is loaded from environment variables or `.env`; use `.env.example` as a guide and keep real secrets outside Git.

Use Python 3.12. Install `requirements.txt`, configure the database, and run `uvicorn app.main:app --reload` for development. Production uses reviewed worker/proxy settings under `deploy/`; see the [handoff](../docs/PRODUCTION-HANDOFF.md) before applying migrations or deploying.

Integration tests require an explicit `TEST_DATABASE_URL`. They create and drop their own isolated schema rather than writing test data into public application tables:

```bash
TEST_DATABASE_URL=postgresql+asyncpg://user:password@localhost/testdb python -m pytest tests -q
```

For TLS test databases, set `TEST_DB_SSL_CA_FILE` as well. Database-free security tests can run with `python -m pytest tests/unit --confcutdir=tests/unit -q`.

Support AI is disabled by default. Set `OPENAI_API_KEY` on the backend and explicitly enable bounded usage in Admin → Support. Never put the key in Flutter or Vite configuration.
