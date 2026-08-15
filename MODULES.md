# MODULES.md

Tracked checklist of every module/feature and its status.

> **Rule:** When a module is completed, update its row here with status, date,
> and a short note on what was implemented — without being asked.

**Status legend:** ✅ Done · 🚧 In Progress · ⏳ Pending

_Last updated: 2026-08-15 (Phase B2)_

| Module                        | Status        | Notes |
|-------------------------------|---------------|-------|
| Project scaffolding           | ✅ Done        | 2026-08-13 — Flutter app in `/mobile` + FastAPI backend in `/backend`. Both verified running. |
| **B0 — Postgres foundation**  | ✅ Done        | 2026-08-14 — Swapped Motor/MongoDB for SQLAlchemy 2.0 async + asyncpg + Alembic. 9 ORM tables, initial migration, seed script. `DATABASE_URL` env var replaces `MONGO_*`. |
| **B1 — Auth (JWT)**              | ✅ Done        | 2026-08-14 — POST /auth/register, POST /auth/login, GET /auth/me. bcrypt password hashing (passlib), HS256 JWT (python-jose), get_current_user dep, 10/10 tests passing. |
| **B2 — Activity + points engine** | ✅ Done     | 2026-08-15 — POST /activity/sync (idempotent, delta-only, capped), GET /activity?range=, GET /points/balance, GET /points/history. 9/9 tests passing incl. replay no-double-award acceptance criterion. |
| **B3 — Offers + voucher issuance** | ✅ Done     | 2026-08-15 — GET /offers (active catalog), POST /offers/{id}/redeem (atomic lock, OFFER_SPEND ledger, short_code + SHA-256 token), GET /vouchers (wallet + lazy expiry). 12/12 tests passing. |
| **B4 — Merchant validate/redeem** | ✅ Done     | 2026-08-15 — POST /partner/v1/vouchers/validate (token→nonce), POST /partner/v1/vouchers/redeem (conditional UPDATE double-redeem guard). X-Partner-Key auth (SHA-256 hashed). Migration 0002 applied. 10/10 tests passing incl. concurrent redeem acceptance criterion. |
| B5 — Profile + housekeeping   | ⏳ Pending     | PATCH profile, DELETE account, seed script. |
| M0 — App shell                | ⏳ Pending     | Riverpod + go_router wired; `health` + `qr_flutter` added to pubspec. |
| M1 — Auth (Flutter)           | ⏳ Pending     | Login/register screens, JWT stored in secure_storage. |
| M2 — Steps + dashboard        | ⏳ Pending     | health integration, manual dev entry, sync. |
| M3 — Points, rewards, wallet  | ⏳ Pending     | Catalog, redeem, QR voucher view. |
| M4 — Wire-up & E2E            | ⏳ Pending     | Full loop test: register → steps → points → redeem → validate. |
