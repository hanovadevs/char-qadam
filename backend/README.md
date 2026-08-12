# Qadam Backend (FastAPI)

Async FastAPI + MongoDB (Motor) backend for the Qadam run-to-earn app.

## Setup

```bash
cd backend
python -m venv .venv
# Windows PowerShell:
.venv\Scripts\Activate.ps1
# macOS/Linux:
source .venv/bin/activate

pip install -r requirements.txt
cp .env.example .env   # then edit values
```

## Run

```bash
uvicorn app.main:app --reload
```

- App root: http://127.0.0.1:8000/
- Health check: http://127.0.0.1:8000/health
- Swagger docs: http://127.0.0.1:8000/docs

## Layout

```
backend/
├── app/
│   ├── main.py          # FastAPI app factory + lifespan
│   ├── config.py        # Settings (env-driven)
│   ├── db/              # MongoDB (Motor) connection
│   ├── routers/         # API routers (health.py for now)
│   ├── models/          # Pydantic v2 models (empty scaffold)
│   └── services/        # Business logic (empty scaffold)
├── requirements.txt
└── .env.example
```

> Scaffold only — no features implemented yet.
