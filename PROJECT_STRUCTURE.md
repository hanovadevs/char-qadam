# PROJECT_STRUCTURE.md

Folder/file layout for the Qadam project. Two top-level apps: `/mobile`
(Flutter) and `/backend` (FastAPI).

> **Rule:** Keep this current as folders/files are added.

_Last updated: 2026-08-14 (Phase B0 — Postgres swap)_

---

## Repository root

```
Qadam/
├── mobile/               # Flutter mobile app
├── backend/              # FastAPI backend
├── MVP_PLAN.md           # Authoritative build plan (phases B0–B5, M0–M4)
├── MVP_req.md            # Product requirements document (PRD)
├── TECH_STACK.md         # All tech + versions + rationale
├── PROJECT_STRUCTURE.md  # This file
├── REQUIREMENTS.md       # Legacy requirements (superseded by MVP_req.md)
├── MODULES.md            # Module/feature status checklist
└── .gitignore            # Flutter + Python ignore rules
```

---

## `/backend` — FastAPI

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py           # App factory, lifespan (Postgres engine warm-up/dispose), CORS, /health, /
│   ├── config.py         # Settings via pydantic-settings (DATABASE_URL, JWT, points engine rules)
│   ├── db/
│   │   ├── __init__.py
│   │   ├── base.py        # SQLAlchemy DeclarativeBase (shared by all models)
│   │   ├── models.py      # All 9 ORM tables: users, devices, activity_daily, points_ledger,
│   │   │                  #   partners, offers, vouchers, redemptions, audit_log
│   │   └── postgres.py    # Async engine + session factory + get_session() FastAPI dependency
│   ├── routers/
│   │   ├── __init__.py
│   │   └── health.py      # GET /health (functional endpoint)
│   ├── models/            # Pydantic v2 request/response schemas (populated per phase)
│   └── services/          # Business logic (populated per phase)
├── alembic/
│   ├── env.py             # Async Alembic environment (reads DATABASE_URL from app.config)
│   ├── script.py.mako     # Migration file template
│   └── versions/
│       └── 0001_initial_schema.py  # Creates all 9 tables + indexes
├── seeds/
│   └── seed.py            # Demo partner + 3 offers (idempotent, run with python -m seeds.seed)
├── alembic.ini            # Alembic config (script_location = alembic)
├── requirements.txt       # Pinned Python dependencies
├── .env.example           # Sample env config (copy to .env)
├── .venv/                 # Local virtualenv (git-ignored)
└── README.md              # Backend setup/run instructions
```

**Setup:**
```bash
cd backend
cp .env.example .env          # fill in DATABASE_URL
pip install -r requirements.txt
alembic upgrade head           # create all tables
python -m seeds.seed           # (optional) seed demo data
uvicorn app.main:app --reload  # → http://127.0.0.1:8000
```

---

## `/mobile` — Flutter

```
mobile/
├── lib/
│   ├── main.dart         # App entry (default Flutter counter screen for now)
│   ├── core/             # Theme, constants, shared utils (scaffold — Phase M0)
│   ├── routing/          # go_router config (scaffold — Phase M0)
│   ├── data/             # API clients (Dio), repositories, secure storage (scaffold — Phase M0)
│   └── features/         # Feature modules (scaffold — Phases M1–M4)
│       ├── auth/
│       ├── activity/
│       ├── points/
│       ├── rewards/
│       ├── wallet/
│       └── profile/
├── android/              # Android platform project
├── ios/                  # iOS platform project
├── test/                 # Widget/unit tests
├── pubspec.yaml          # Flutter dependencies
└── pubspec.lock          # Locked dependency versions (git-ignored)
```

**Run:** `cd mobile && flutter run`.
