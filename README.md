# Stepsy by Hanova Devs

A step-based rewards app for Pakistan. People walk, sync daily activity, earn
server-calculated points, and exchange points for single-use partner vouchers.
Launch scope is **Android first**. Cash payouts, GPS run tracking, and affiliate
settlement are not implemented product capabilities.

> **Status:** Pre-launch hardening. Mobile, API, merchant POS, and admin flows exist.
> See [LAUNCH_AUDIT.md](LAUNCH_AUDIT.md) for verified changes, release blockers,
> and the Redmi Note 11 test protocol. A push to main is not proof of deployment.

## Repository

| Path | What |
|------|------|
| [`/mobile`](./mobile) | Flutter, Riverpod, Android foreground step service, Health Connect. |
| [`/backend`](./backend) | FastAPI, async SQLAlchemy, PostgreSQL, Alembic. |
| [`/web`](./web) | React admin portal and merchant/offer operations. |

## Tracking docs

- [TECH_STACK.md](./TECH_STACK.md) — technologies, libraries, versions, rationale.
- [PROJECT_STRUCTURE.md](./PROJECT_STRUCTURE.md) — folder/file layout.
- [REQUIREMENTS.md](./REQUIREMENTS.md) — MVP functional requirements.
- [MODULES.md](./MODULES.md) — module/feature status checklist.

## Quick start

**Backend**
```bash
cd backend
python -m venv .venv && .venv\Scripts\Activate.ps1   # Windows
pip install -r requirements.txt
# Configure a local .env and PostgreSQL database before running migrations.
alembic upgrade head
uvicorn app.main:app --reload        # http://127.0.0.1:8000/health
```


**Mobile**
```bash
cd mobile
flutter pub get
flutter run
```

For a USB-connected Android phone and local backend, use `adb reverse tcp:8000 tcp:8000`
and `flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000` from `mobile/`.
Use an isolated development database and development account for reward tests.

The production API is `https://api.stepsyapp.com`; mobile defaults and admin
proxies use it. HTTPS health, database readiness, authentication and certificate
renewal were verified. The legacy IP route remains for older test installations.
A public release still requires database credential rotation and the remaining
checks in the launch audit. Never put signing keys or environment secrets in Git.
The Docker rollout and verification sequence is in [backend/DEPLOYMENT.md](backend/DEPLOYMENT.md).

Google's Android client/signing setup and mandatory email verification rollout
are documented in [AUTH_SETUP.md](AUTH_SETUP.md).
