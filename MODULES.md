# MODULES.md

Tracked checklist of every module/feature and its status.

> **Rule:** When a module is completed, update its row here with status, date,
> and a short note on what was implemented — without being asked.

**Status legend:** ✅ Done · 🚧 In Progress · ⏳ Pending

_Last updated: 2026-08-13_

| Module               | Status     | Notes |
|----------------------|------------|-------|
| Project scaffolding  | ✅ Done     | 2026-08-13 — Flutter app in `/mobile` (Riverpod, go_router, geolocator, pedometer, dio, secure_storage) + FastAPI backend in `/backend` (app/main, config, db/mongo, routers/health). Both verified running; tracking docs created. |
| Auth (JWT)           | ⏳ Pending  | Deps present (python-jose, passlib); no logic yet. |
| GPS run tracking     | ⏳ Pending  | geolocator + pedometer installed; no tracking logic yet. |
| Points engine        | ⏳ Pending  | Not started. |
| Rewards & redemption | ⏳ Pending  | Not started. |
| Leaderboard          | ⏳ Pending  | Not started. |
| User profile         | ⏳ Pending  | Not started. |
| Awin integration     | ⏳ Pending  | Future phase — no Awin calls yet. |
