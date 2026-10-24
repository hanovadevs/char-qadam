> Historical build plan. Current Android-first requirements and release gates are in [REQUIREMENTS.md](../product/REQUIREMENTS.md) and [LAUNCH_AUDIT.md](../operations/LAUNCH_AUDIT.md).

# Qadam — MVP Build Plan

Step-based rewards app: users earn **points** from verified step activity and
**spend** them on partner-brand offers, receiving a **single-use voucher** a
merchant can validate. This plan is the step-by-step build guide for a
**fully functional MVP** (function over styling — polish comes later).

_Last updated: 2026-08-14_

---

## 0. Decisions locked for this MVP

These resolve the divergence between the PRD (`MVP_req.md`) and the current
scaffold. Where they differ, the choice below wins.

| Topic | Decision | Note |
|-------|----------|------|
| Mobile | **Flutter** (keep existing scaffold) | PRD suggested React Native; we keep Flutter for speed. |
| Backend | **FastAPI** (keep existing scaffold) | PRD suggested NestJS/Go; we keep FastAPI. |
| Database | **PostgreSQL** (swap out MongoDB) | Honors PRD's transactional-correctness need for balances/vouchers. |
| Activity model | **Step-based** (not GPS) | Drop the "run to earn / GPS" framing from old `REQUIREMENTS.md`. |
| Step source | **`health` package** (HealthKit / Health Connect) **+ manual dev entry** | Manual entry keeps the full loop testable on emulators / without a device. |
| Reward model | **Spend points on catalog offers** | Redeeming an offer deducts `points_cost` from balance. |
| Redemption scope | **In-app voucher (QR + short code) + backend validate/redeem API** | Merchant tested via API/curl; no web portal in MVP. |
| Auth | **JWT** (email + password) | Deps already present. OAuth/OTP later. |
| Out of scope | Redis, queues, App Attest/Play Integrity, partner webhooks, settlement, merchant web portal, real payouts | Deferred to post-MVP hardening. |

### PRD requirements deliberately deferred (not dropped)
- Redis / async job queue / event bus → single FastAPI process for MVP.
- Device attestation & advanced fraud scoring → basic server-side caps only.
- Partner POS/ecommerce adapters (Level A/C) → MVP does **Level B** logic
  (server voucher + validate/redeem endpoints) via API only.
- Push notifications → optional stretch (§9), not core.

---

## 1. Target architecture (MVP)

```
Flutter app (Riverpod + go_router + dio + secure_storage + health)
      |  HTTPS + JWT
      v
FastAPI (single async process)
      ├── /auth        register / login / me
      ├── /activity    sync daily steps (idempotent)
      ├── /points      balance + ledger
      ├── /offers      catalog (browse)
      ├── /vouchers    redeem offer -> issue voucher; list wallet
      └── /partner     validate / redeem (merchant-facing, atomic)
      |
      v
PostgreSQL  (users, devices, activity_daily, points_ledger,
             partners, offers, vouchers, redemptions, audit_log)
```

**Core correctness invariants** (from PRD §8, §12 — these are the acceptance bar):
1. Backend is the **only** authority that mints/spends points.
2. `points_ledger` is **append-only**; balance = SUM(delta). No mutable balance
   trusted from the client.
3. Every activity sync carries an **idempotency key** → retries never double-award.
4. A voucher can be **redeemed at most once**, even under concurrent requests
   (enforced with a transactional conditional UPDATE).
5. A daily **max eligible steps** cap limits obvious abuse.

---

## 2. Data model (PostgreSQL)

Minimal but faithful subset of PRD §7. UUID PKs, `created_at` on all tables.

- **users** — `id, email (unique), password_hash, status, country, timezone, created_at`
- **devices** — `id, user_id, platform, app_version, created_at` (light; attestation later)
- **activity_daily** — `id, user_id, local_date, eligible_steps, source, sync_key (unique per user), sync_version, created_at`
  - `UNIQUE(user_id, local_date)` — one normalized row per day, upserted.
  - `sync_key` supports idempotent syncs.
- **points_ledger** — `id, user_id, delta (signed int), reason (enum: STEP_EARN|OFFER_SPEND|ADJUST), ref_type, ref_id, campaign_id, created_at`
  - Append-only. Balance derived: `SELECT COALESCE(SUM(delta),0) WHERE user_id=…`.
- **partners** — `id, name, status, created_at`
- **offers** — `id, partner_id, title, description, discount_type (PERCENT|FIXED|FREE_ITEM), discount_value, points_cost, min_basket, inventory (nullable), starts_at, ends_at, status`
- **vouchers** — `id, user_id, offer_id, short_code (unique), token_hash, status (ISSUED|REDEEMED|EXPIRED|CANCELLED), issued_at, expires_at, redeemed_at`
  - Store only a **hash** of the redeemable token; short_code is the human entry code.
- **redemptions** — `id, voucher_id, partner_id, store_id (nullable), order_reference, discount_value, redeemed_at`
- **audit_log** — `id, actor, action, object_type, object_id, created_at`

**Indexes:** `activity_daily(user_id, local_date)`, `points_ledger(user_id)`,
`vouchers(token_hash)`, `vouchers(user_id, status)`, `offers(status, starts_at, ends_at)`.

**Migrations:** manage schema with a lightweight tool (SQLModel/SQLAlchemy +
Alembic). Seed script inserts a demo partner + a few offers.

---

## 3. Backend work (`/backend`)

### Phase B0 — Swap Mongo → Postgres (foundation)
- [ ] Update `requirements.txt`: remove `motor`; add `sqlalchemy[asyncio]`,
      `asyncpg`, `alembic`, `sqlmodel` (or plain SQLAlchemy).
- [ ] Replace `app/db/mongo.py` with `app/db/postgres.py`: async engine +
      `async_sessionmaker` + `get_session()` dependency; wire into `main.py`
      lifespan (dispose engine on shutdown).
- [ ] Update `config.py` / `.env.example`: replace `MONGO_*` with
      `DATABASE_URL=postgresql+asyncpg://…`. Keep JWT settings.
- [ ] Init Alembic; first migration creates all tables in §2.
- [ ] Update `PROJECT_STRUCTURE.md`, `TECH_STACK.md` to reflect Postgres.

### Phase B1 — Auth (JWT)  ⟶ FR Auth
- [ ] `models/user.py`, `schemas/auth.py` (RegisterIn, LoginIn, TokenOut, UserOut).
- [ ] `services/security.py`: bcrypt hash/verify (passlib), JWT encode/decode (python-jose).
- [ ] `routers/auth.py`: `POST /auth/register`, `POST /auth/login`, `GET /auth/me`.
- [ ] `deps.py`: `get_current_user` dependency (validates Bearer JWT).
- [ ] Tests: register → login → call `/auth/me` with token.

### Phase B2 — Activity ingestion + points engine  ⟶ PRD §8
- [ ] `POST /activity/sync` — body: `{ local_date, eligible_steps, source, sync_key }`.
      - Server clamps `eligible_steps` to configurable **daily cap**.
      - Upsert `activity_daily` by `(user_id, local_date)`; if the eligible total
        for the day increases, append a `STEP_EARN` ledger entry for the **delta**
        only, using server-side earning rule (points = f(steps), rule stored in
        config/table so it can change without an app release).
      - Idempotent on `sync_key`: replaying the same key is a no-op.
- [ ] `GET /activity?range=today|week|month` — aggregated step totals for dashboard.
- [ ] `GET /points/balance` and `GET /points/history` (ledger, paginated).
- [ ] Tests: **replayed sync does not double-award** (acceptance criterion).

### Phase B3 — Offers catalog + voucher issuance  ⟶ PRD §9
- [ ] `GET /offers` — active offers (status + date window + inventory>0).
- [ ] `POST /offers/{id}/redeem` — **transaction**:
      1. Lock/read balance; verify `balance >= points_cost` and offer still valid/in-stock.
      2. Append `OFFER_SPEND` ledger entry (`-points_cost`).
      3. Decrement inventory if set.
      4. Generate `short_code` (e.g. `SR-7K4Q-92MX`) + random opaque token;
         store `token_hash`; set `expires_at`.
      5. Insert `vouchers` row (status `ISSUED`); return code + QR payload (token/URL).
      - All-or-nothing; insufficient balance → 402/409, no ledger entry.
- [ ] `GET /vouchers?status=active|redeemed|expired` — wallet lists.
- [ ] Background/lazy expiry: mark `ISSUED` vouchers past `expires_at` as `EXPIRED`
      (checked on read for MVP; scheduled job later).
- [ ] Tests: redeem deducts exactly once; insufficient points blocked.

### Phase B4 — Merchant validate/redeem API  ⟶ PRD §9, §12
- [ ] `POST /partner/v1/vouchers/validate` — `{ voucher_token, partner_id, store_id, basket_amount, order_reference }`
      → `{ valid, discount_type, discount_value, expiry, redemption_nonce }`.
      Looks up by `token_hash`; checks status ISSUED + not expired + offer rules.
- [ ] `POST /partner/v1/vouchers/redeem` — `{ voucher_token, redemption_nonce, order_reference, final_basket_amount }`
      → atomic **conditional UPDATE** `SET status='REDEEMED' WHERE id=… AND status='ISSUED'`;
      if 0 rows updated → already redeemed → **409** (this is the double-redeem guard).
      On success insert `redemptions` row + audit entry.
- [ ] Rate-limit voucher generation + partner endpoints (simple in-memory/IP for MVP).
- [ ] Tests: **two concurrent redeem calls → exactly one succeeds** (acceptance criterion).

### Phase B5 — Profile + housekeeping
- [ ] `GET/PATCH /profile` (name, country, timezone) + lifetime stats
      (total steps, total points earned/spent).
- [ ] `DELETE /account` — deletes/anonymizes user + activity/reward rows (privacy §5).
- [ ] Seed script: demo partner + 3–4 offers at different `points_cost`.

---

## 4. Mobile work (`/mobile`)

Replace the default counter app. Structure under `lib/`:

```
lib/
├── main.dart                 # ProviderScope + MaterialApp.router
├── core/                     # theme (minimal), constants, env (API base URL)
├── routing/                  # go_router: redirects on auth state
├── data/
│   ├── api/                  # dio client (JWT interceptor), endpoint clients
│   ├── auth/                 # token store (secure_storage), auth repo
│   └── models/               # DTOs mirroring backend schemas
└── features/
    ├── auth/                 # login + register screens
    ├── activity/             # step dashboard (today/week/month) + sync
    ├── points/               # balance + history
    ├── rewards/              # offers catalog + redeem flow
    ├── wallet/               # My Rewards: Active / Redeemed / Expired + QR view
    └── profile/              # profile + delete account
```

### Phase M0 — App shell
- [ ] Add `health: ^…` and `qr_flutter: ^…` to `pubspec.yaml`
      (keep dio, secure_storage, riverpod, go_router; `pedometer`/`geolocator`
      no longer core — leave installed or remove).
- [ ] `main.dart`: `ProviderScope` + router; API base URL from `--dart-define`.
- [ ] Dio client with JWT interceptor (attach token, 401 → logout).

### Phase M1 — Auth
- [ ] Login + Register screens (plain forms).
- [ ] Store JWT in secure_storage; auth-state provider; go_router redirect
      (unauth → /login, auth → /home).

### Phase M2 — Steps + dashboard
- [ ] Permission onboarding screen with a plain-language privacy note (PRD §5).
- [ ] `health` integration: read step count (aggregate/incremental) on app
      open/foreground; normalize to a daily total.
- [ ] **Manual dev entry** widget (behind a debug flag / dev screen): "add N steps
      for date D" → posts to `/activity/sync`. This is what makes the loop
      testable without a physical device.
- [ ] Dashboard: today/week/month totals + progress toward next reward.
- [ ] Sync uses a client-generated idempotency `sync_key`.

### Phase M3 — Points, rewards, wallet
- [ ] Points screen: balance + ledger history from backend.
- [ ] Rewards catalog: list offers (brand, discount, points cost, terms, expiry);
      Redeem button → `POST /offers/{id}/redeem`.
- [ ] Wallet: Active / Redeemed / Expired tabs; tap voucher → show **QR
      (qr_flutter)** + short code + expiry.
- [ ] Profile screen + delete-account action.

### Phase M4 — Wire-up & manual E2E
- [ ] Full loop on a real/dev flow: register → sync steps → see points →
      redeem offer → open voucher QR → (via curl) partner validate + redeem →
      wallet shows Redeemed.

---

## 5. Build order (dependencies)

1. **B0** Postgres swap + migrations  ← everything depends on this.
2. **B1** Auth  →  **M0/M1** app shell + login (can start in parallel once B1 API exists).
3. **B2** Activity + points  →  **M2** dashboard.
4. **B3** Offers + vouchers  →  **M3** rewards + wallet.
5. **B4** Partner validate/redeem (backend + curl tests).
6. **B5 / M4** Profile, delete-account, full manual E2E.

Merchant web portal, push notifications, Redis/queues, device attestation,
partner webhooks → **post-MVP** (PRD Phases 3–5).

---

## 6. MVP acceptance criteria (from PRD §16 — the definition of done)

- [ ] New user can sign up, grant step access, and see a correct daily total.
- [ ] Repeated/retried activity sync does **not** duplicate points.
- [ ] Points are earned per **server-configured** rule (no formula hard-coded in app).
- [ ] User can redeem an eligible offer **exactly once** and receive a code + QR.
- [ ] Merchant `validate` then `redeem` succeeds quickly under normal connectivity.
- [ ] A redeemed voucher **cannot be reused**, even under simultaneous requests.
- [ ] Partner endpoints expose **no** step/health history.
- [ ] Removing health permission stops new ingestion **without** breaking the account.
- [ ] Account deletion removes/anonymizes user data.

---

## 7. Doc upkeep (do as we go, per repo rules)

- [ ] `MODULES.md` — flip each module to 🚧/✅ with date + note as completed.
- [ ] `TECH_STACK.md` — record Postgres/SQLAlchemy/Alembic/health/qr_flutter;
      remove Motor/Mongo.
- [ ] `PROJECT_STRUCTURE.md` — update backend `db/` and mobile `lib/` trees.
- [ ] `REQUIREMENTS.md` — reconcile "run to earn / GPS" wording to the
      step-based model, or supersede it by pointing to this plan + `MVP_req.md`.
