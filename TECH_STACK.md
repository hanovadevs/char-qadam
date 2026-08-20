# TECH_STACK.md

Every technology, library, and package used in the Qadam "step-to-earn" project,
with versions and a one-line reason for each choice.

> **Rule:** Update this file whenever a dependency is added, removed, or upgraded.

_Last updated: 2026-08-15 (Phase M4 — Complete MVP)_

---

## Toolchain (verified locally)

| Tool    | Version  | Reason |
|---------|----------|--------|
| Flutter | 3.44.1 (stable) | Cross-platform mobile UI framework (Android + iOS). |
| Dart    | 3.12.1   | Language powering Flutter. |
| Python  | 3.12.9   | Backend language for FastAPI. |
| pip     | 25.3     | Python package manager. |
| Git     | 2.53.0   | Version control. |

---

## Mobile app — Flutter (`/mobile`)

Package name: `qadam` · Org: `com.qadam` · Platforms: Android, iOS

### Runtime dependencies

| Package | Version | Reason |
|---------|---------|--------|
| flutter_riverpod | ^2.6.1 | State management (specified stack choice). |
| go_router | ^17.5.0 | Declarative navigation / routing. |
| dio | ^5.11.0 | HTTP client for talking to the FastAPI backend. |
| flutter_secure_storage | ^11.0.0 | Secure on-device storage for JWT tokens. |
| health | ^13.0.0 | HealthKit / Health Connect step reading. |
| qr_flutter | ^4.1.0 | QR code rendering for voucher display. |
| intl | ^0.20.2 | Date and currency formatting. |
| uuid | ^4.5.1 | Client-side UUID v4 generation for idempotency keys. |
| geolocator | ^14.0.3 | GPS (kept; attestation/fraud work deferred). |
| pedometer | ^4.2.0 | Step counting fallback. |
| cupertino_icons | ^1.0.8 | iOS-style icon set. |

### Dev dependencies

| Package | Version | Reason |
|---------|---------|--------|
| flutter_test | (SDK) | Widget/unit testing (Flutter default). |
| flutter_lints | ^6.0.0 | Recommended lint rules (Flutter default). |

---

## Backend — FastAPI (`/backend`)

Python 3.12 · pinned in `backend/requirements.txt`

| Package | Version | Reason |
|---------|---------|--------|
| fastapi | 0.118.0 | Async web framework for the REST API. |
| uvicorn[standard] | 0.37.0 | ASGI server to run FastAPI. |
| pydantic | 2.11.10 | Data validation / serialization (v2). |
| pydantic-settings | 2.7.1 | Env-driven application settings. |
| sqlalchemy[asyncio] | 2.0.41 | Async ORM for PostgreSQL; mapped_column API. |
| asyncpg | 0.30.0 | Async PostgreSQL driver (used by SQLAlchemy). |
| alembic | 1.16.2 | Schema migrations for SQLAlchemy models. |
| greenlet | 3.2.3 | Required for SQLAlchemy async support. |
| python-jose[cryptography] | 3.5.0 | JWT encode/decode for auth. |
| passlib[bcrypt] | 1.7.4 | Password hashing. |
| python-multipart | 0.0.20 | Form/multipart parsing. |
| email-validator | 2.2.0 | Email validation for Pydantic models. |
| httpx | 0.28.1 | Async HTTP client (tests). |
| pytest | 8.4.2 | Test runner. |
| pytest-asyncio | 0.24.0 | Async test support for pytest. |

### Removed

| Package | Reason removed |
|---------|----------------|
| motor 3.7.1 | MongoDB async driver — replaced by asyncpg + SQLAlchemy (Phase B0). |

---

## Database

| Tech | Version | Reason |
|------|---------|--------|
| PostgreSQL | 15+ (external) | Transactional-correct relational store for balances, vouchers, and the append-only ledger. Chosen in MVP_PLAN.md §0 for correctness over MongoDB. |

---

## Planned / future phase (not yet added)

| Tech | Reason |
|------|--------|
| Redis | Async job queue / rate-limit backing store (post-MVP). |
| App Attest / Play Integrity | Device attestation for fraud hardening (post-MVP). |
