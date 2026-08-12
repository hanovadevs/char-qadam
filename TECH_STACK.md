# TECH_STACK.md

Every technology, library, and package used in the Qadam "run-to-earn" project,
with versions and a one-line reason for each choice.

> **Rule:** Update this file whenever a dependency is added, removed, or upgraded.

_Last updated: 2026-08-13 (initial scaffold)_

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
| geolocator | ^14.0.3 | GPS location for run tracking. |
| pedometer | ^4.2.0 | Step counting for run tracking. |
| dio | ^5.11.0 | HTTP client for talking to the FastAPI backend. |
| flutter_secure_storage | ^11.0.0 | Secure on-device storage for JWT tokens. |
| cupertino_icons | ^1.0.8 | iOS-style icon set (Flutter default). |

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
| motor | 3.7.1 | Async MongoDB driver. |
| python-jose[cryptography] | 3.5.0 | JWT encode/decode for auth (future phase). |
| passlib[bcrypt] | 1.7.4 | Password hashing for auth (future phase). |
| python-multipart | 0.0.20 | Form/multipart parsing (login forms, uploads). |
| email-validator | 2.2.0 | Email validation for Pydantic models. |
| httpx | 0.28.1 | Async HTTP client (tests + future Awin calls). |
| pytest | 8.4.2 | Test runner. |

---

## Database

| Tech | Version | Reason |
|------|---------|--------|
| MongoDB | (server, external) | Document store for users, runs, points, rewards. Accessed async via Motor. |

---

## Planned / future phase (not yet added)

| Tech | Reason |
|------|--------|
| Awin API | Affiliate network for discount coupons / cashback rewards. |
