# PROJECT_STRUCTURE.md

Folder/file layout for the Qadam project. Two top-level apps: `/mobile`
(Flutter) and `/backend` (FastAPI).

> **Rule:** Keep this current as folders/files are added.

_Last updated: 2026-08-13 (initial scaffold)_

---

## Repository root

```
Qadam/
├── mobile/               # Flutter mobile app
├── backend/              # FastAPI backend
├── TECH_STACK.md         # All tech + versions + rationale
├── PROJECT_STRUCTURE.md  # This file
├── REQUIREMENTS.md       # MVP functional requirements
├── MODULES.md            # Module/feature status checklist
└── .gitignore            # Flutter + Python ignore rules
```

---

## `/backend` — FastAPI

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py           # App factory, lifespan (Mongo connect/close), CORS, /health, /
│   ├── config.py         # Settings via pydantic-settings (env-driven)
│   ├── db/
│   │   ├── __init__.py
│   │   └── mongo.py       # Motor client lifecycle + get_db() accessor
│   ├── routers/
│   │   ├── __init__.py
│   │   └── health.py      # GET /health (only functional endpoint so far)
│   ├── models/           # Pydantic v2 models (empty scaffold — .gitkeep)
│   └── services/         # Business logic (empty scaffold — .gitkeep)
├── requirements.txt      # Pinned Python dependencies
├── .env.example          # Sample env config (copy to .env)
├── .venv/                # Local virtualenv (git-ignored)
└── README.md             # Backend setup/run instructions
```

**Run:** `uvicorn app.main:app --reload` → http://127.0.0.1:8000
(`/health`, `/docs`).

---

## `/mobile` — Flutter

```
mobile/
├── lib/
│   ├── main.dart         # App entry (default Flutter counter screen for now)
│   ├── core/             # Theme, constants, shared utils (empty scaffold)
│   ├── routing/          # go_router config (empty scaffold)
│   ├── data/             # API clients (Dio), repositories, secure storage (empty scaffold)
│   └── features/         # Feature modules: auth, run_tracking, points, rewards, leaderboard (empty scaffold)
├── android/              # Android platform project
├── ios/                  # iOS platform project
├── test/                 # Widget/unit tests (default widget_test.dart)
├── pubspec.yaml          # Flutter dependencies
└── pubspec.lock          # Locked dependency versions (git-ignored)
```

**Run:** `cd mobile && flutter run`.

> The `lib/` sub-folders are structural placeholders (`.gitkeep`); no feature
> code exists yet. `main.dart` remains the default Flutter starter screen.
