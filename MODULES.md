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
| **B5 — Profile + housekeeping** | ✅ Done     | 2026-08-15 — PATCH /users/me (country/timezone/password re-hash, partial update), DELETE /users/me (soft-delete, JWT auto-invalidated). Seed script generates + prints real partner API key. 11/11 tests passing. Full suite: **52/52 passed**. |
| **M0 — App shell**                | ✅ Done     | 2026-08-15 — Riverpod + go_router + Dio client with JWT interceptor & 401 handler, TokenStorage (secure_storage), AppTheme (emerald dark/light), health + qr_flutter packages added. Flutter analyze clean, test passing. |
| **M1 — Auth (Flutter)**           | ✅ Done     | 2026-08-15 — Full Login & Register forms with RFC email validation, min-8 password rules, error banners, AuthRepository calling POST /auth/login, POST /auth/register, GET /auth/me. JWT persisted in secure_storage, auto-redirect to /steps. All Flutter tests passing. |
| **M2 — Steps + dashboard**        | ✅ Done     | 2026-08-15 — HealthService (health package step ingestion + graceful fallback), ActivityRepository (POST /activity/sync & GET /activity), ActivityNotifier with UUID v4 idempotency keys, hero Step Progress Ring (20k daily cap), history range filter (Today/7 Days/30 Days), Privacy Notice, & Manual Dev Step Ingestion Sandbox for emulator testing. 5/5 Flutter tests passing. |
| **M3 — Points, rewards, wallet**  | ✅ Done     | 2026-08-15 — PointsScreen (balance, lifetime earned/spent, ledger timeline), RewardsScreen (offers catalog, points cost tags, inventory limits, atomic redeem modal), WalletScreen (Active/Redeemed/Expired status tabs, QR Code viewer via qr_flutter & copyable short code), ProfileScreen (edit country/timezone, sign out, & soft-delete account action). 10/10 Flutter tests passing. |
| **M4 — Wire-up & E2E**            | ✅ Done     | 2026-08-15 — Automated 12-step E2E lifecycle test (test_e2e_flow.py) passing: Register → Ingest Steps → Points Ledger → Browse Catalog → Redeem Offer → QR Voucher Wallet → Merchant POS Validate & Redeem → Double Redeem Rejection → Soft-delete Account. All 53 backend tests + 10 mobile Flutter tests passing. |
