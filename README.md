# Qadam — Run to Earn 🏃

A "run to earn" mobile app for Pakistan. Users track runs via GPS, earn points,
and redeem them for discount coupons / cashback sourced from affiliate networks
(Awin, later phase).

> **Status:** Initial scaffold only. No features implemented yet.

## Repository

| Path | What |
|------|------|
| [`/mobile`](./mobile) | Flutter app (Android + iOS) — Riverpod, go_router, geolocator, pedometer. |
| [`/backend`](./backend) | FastAPI (async) + MongoDB via Motor. |

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
uvicorn app.main:app --reload        # http://127.0.0.1:8000/health
```

**Mobile**
```bash
cd mobile
flutter pub get
flutter run
```
