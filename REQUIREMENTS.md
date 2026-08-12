# REQUIREMENTS.md

Functional requirements for the Qadam MVP — a "run to earn" app for Pakistan.
Users track runs via GPS, earn points, and redeem points for discount
coupons / cashback sourced from affiliate networks (Awin, etc.).

This is the single source of truth to build against. Non-functional notes are
at the bottom.

_Last updated: 2026-08-13 (initial scaffold — nothing implemented yet)_

---

## 1. Authentication (JWT)
- FR-1.1 Users can register with email + password.
- FR-1.2 Users can log in and receive a JWT access token.
- FR-1.3 Authenticated requests are validated via the JWT.
- FR-1.4 Passwords are stored hashed (bcrypt); never in plaintext.
- FR-1.5 Auth is designed to be extendable later (social login, OTP).

## 2. GPS Run Tracking
- FR-2.1 Start / pause / stop a run session.
- FR-2.2 Capture GPS route, distance, duration, and pace.
- FR-2.3 Count steps via the device pedometer during a run.
- FR-2.4 Persist completed runs to the backend per user.
- FR-2.5 View run history and per-run detail.

## 3. Points Engine
- FR-3.1 Award points based on run metrics (e.g. distance/steps) using defined rules.
- FR-3.2 Maintain a per-user points balance (ledger of earn/spend entries).
- FR-3.3 Prevent double-counting / fraud (basic validation of run data).
- FR-3.4 Show current balance and points history in the app.

## 4. Rewards & Redemption (Affiliate)
- FR-4.1 Browse a catalog of discount coupons / cashback rewards.
- FR-4.2 Redeem points for a reward (deducts from balance).
- FR-4.3 Rewards/links are sourced from affiliate networks (Awin) — *future phase*.
- FR-4.4 Track redemption history per user.

## 5. Leaderboard
- FR-5.1 Rank users by points (and/or distance) over a period.
- FR-5.2 Show the current user's rank and nearby competitors.
- FR-5.3 Support scopes such as global and time-bounded (weekly/monthly).

## 6. User Profile
- FR-6.1 View/edit basic profile (name, avatar).
- FR-6.2 View lifetime stats (total distance, runs, points).

---

## Non-functional / constraints
- Target market: Pakistan (consider connectivity, low-end devices, localization later).
- Backend is async (FastAPI + Motor/MongoDB).
- Mobile is Flutter (Android + iOS) with Riverpod + go_router.
- Secrets/config via environment variables; no secrets in source.
- API documented via FastAPI's auto-generated OpenAPI (`/docs`).

## Out of scope for MVP
- Payments / payouts, real cashback settlement.
- Social feed, chat, in-app messaging.
- Web/desktop clients.
