# MODULES.md

> Historical implementation checklist. Done labels below do not mean launch-verified.
> Current acceptance and known gaps: [REQUIREMENTS.md](REQUIREMENTS.md) and
> [LAUNCH_AUDIT.md](../operations/LAUNCH_AUDIT.md), updated 2026-10-17.

Tracked checklist of every module/feature and its status.

> **Rule:** When a module is completed, update its row here with status, date,
> and a short note on what was implemented — without being asked.

**Status legend:** ✅ Done · 🚧 In Progress · ⏳ Pending

_Last updated: 2026-08-28_

| Module | Status | Notes |
|---|---|---|
| Project scaffolding | ✅ Done | 2026-08-13 — Flutter app in `/mobile` + FastAPI backend in `/backend`. Both verified running. |
| **B0 — Postgres foundation** | ✅ Done | 2026-08-14 — Swapped Motor/MongoDB for SQLAlchemy 2.0 async + asyncpg + Alembic. 9 ORM tables, initial migration, seed script. `DATABASE_URL` env var replaces `MONGO_*`. |
| **B1 — Auth (JWT + OAuth + Recovery)** | ✅ Done | 2026-08-27 — POST /auth/register, POST /auth/login, POST /auth/google, POST /auth/forgot-password, POST /auth/reset-password, GET /auth/me. 14/14 tests passing. |
| **B2 — Activity + points engine** | ✅ Done | 2026-08-15 — POST /activity/sync (idempotent, delta-only, capped), GET /activity?range=, GET /points/balance, GET /points/history. 9/9 tests passing. |
| **B3 — Offers + voucher issuance** | ✅ Done | 2026-08-15 — GET /offers (active catalog), POST /offers/{id}/redeem (atomic lock, OFFER_SPEND ledger, short_code + SHA-256 token), GET /vouchers (wallet + lazy expiry). 12/12 tests passing. |
| **B4 — Merchant validate/redeem** | ✅ Done | 2026-08-15 — POST /partner/v1/vouchers/validate (token→nonce), POST /partner/v1/vouchers/redeem (conditional UPDATE double-redeem guard). X-Partner-Key auth (SHA-256 hashed). |
| **B5 — Profile + housekeeping** | ✅ Done | 2026-08-15 — PATCH /users/me, DELETE /users/me (soft-delete). |
| **B6 — Admin & Operations** | ✅ Done | 2026-08-27 — POST /admin/partners, POST /admin/vouchers/sweep-expired, GET /admin/fraud/flags, POST /admin/users/{id}/status. CLI partner provisioning. |
| **B7 — Infra & Security** | ✅ Done | 2026-08-27 — Deep readiness probe (/health/ready), structured JSON request logging with header redaction, sliding-window auth rate limiter. |
| **B8 — Anti-Fraud & Integrity** | ✅ Done | 2026-08-27 — Sync date range bounding (future & >7d rejection), risk scoring, monotonic client step guard. |
| **M0 — App shell** | ✅ Done | 2026-08-15 — Riverpod + go_router + Dio client with JWT interceptor & 401 handler, TokenStorage, Swiss Light AppTheme. |
| **M1 — Auth (Flutter)** | ✅ Done | 2026-08-27 — Full Login, Register, Forgot Password & Google OAuth sign-in flows with Swiss Light UX. |
| **M2 — Steps + dashboard** | ✅ Done | 2026-08-28 — Step Progress Ring, range filters, Dev Step Sandbox, Source Attribution Badges (Health, Manual, BG Sync). |
| **M3 — Points, rewards, wallet** | ✅ Done | 2026-08-28 — PointsScreen with Infinite Scroll Pagination, RewardsScreen with atomic redeem modal, WalletScreen with QR viewer, Short Code copy & Share Links. |
| **M4 — Wire-up & E2E** | ✅ Done | 2026-08-28 — Automated E2E lifecycle test suite passing (70/70 backend tests passing). |
| **M5 — Merchant POS Scanner** | ✅ Done | 2026-08-27 — In-app store cashier POS terminal: partner API key setup, voucher validation preview, POS confirmation, and live audit history. |
| **M6 — Onboarding Flow** | ✅ Done | 2026-08-28 — 3-step Swiss styled onboarding (Welcome, Data Privacy Guarantee, Step Tracking Permission request) with persistent state. |
| **M7 — Offline Caching Layer** | ✅ Done | 2026-08-28 — `CacheService` with SharedPreferences cache-aside fallback across balance, ledger, offers, vouchers, and activity history. |
| **M8 — Push & Local Notifications** | ✅ Done | 2026-08-28 — `NotificationService` handling step goal reminders, voucher mint celebrations, expiring voucher alerts, and test triggers. |
| **M9 — Deep Links & Share Links** | ✅ Done | 2026-08-28 — GoRouter `/v/:code` voucher lookup screen, `Share.share` native share sheet and clipboard link copy. |
| **M10 — App Icon & Branding** | ✅ Done | 2026-08-28 — 1024x1024 Swiss Style vector app icon generated across Android adaptive icons, iOS, Web, and Windows launcher assets. |
