# Stepsy technical context

Current implementation, audited 2026-10-17. This replaces the original scaffold notes.

| Layer | Implementation |
|---|---|
| Android app | Flutter 3.47.1 / Dart 3.13.1 in the verified local toolchain; Riverpod 2, go_router 17, Dio 5. |
| Step acquisition | Kotlin SensorManager TYPE_STEP_COUNTER owned by StepTrackingService; persistent daily snapshots and boot counter; Health Connect read-only aggregate reconciliation. |
| Background upload | Android WorkManager, best-effort periodic network sync; permission-gated background health reads and stored-snapshot fallback. |
| Auth storage | flutter_secure_storage; account-scoped SharedPreferences response caches. |
| API | FastAPI 0.118, Pydantic 2, Python 3.12 deployment requirements. Local verification used the existing Python 3.14 environment. |
| Persistence | SQLAlchemy 2 async + asyncpg; PostgreSQL; Alembic revisions 0001-0004. No MongoDB dependency in the active data path. |
| Auth/security | Signed access JWTs, password-version revocation, bcrypt_sha256 for new hashes with legacy bcrypt verification, Google tokeninfo verification, SMTP reset delivery. |
| Admin | React 18, React Router 7.18.4, Vite 8.3.4, plugin-react 6.1.2; Node 24. |
| Integrity | Append-only point ledger, user/offer row locks, conditional merchant redemption, date bounds and daily caps. These are not device attestation. |
| Tests | pytest/httpx against isolated PostgreSQL and real migrations; Flutter widget/model/state regressions; JUnit native counter tests. |
| CI | GitHub Actions API, Android/Flutter, and admin jobs on main pushes / pull requests. |

The earning defaults live in backend Settings: 100 steps/point, 20,000 eligible
steps/day, and 30-day vouchers. /admin/config and sync responses expose active
values to clients. Actual movement can exceed the eligibility cap.

The physical acceptance target is Redmi Note 11 / Android 13. iOS source remains
in the repo but is outside the initial release scope and was not built here.

Dependencies are captured in mobile/pubspec.lock, backend/requirements.txt, and
web/package-lock.json. Production deployment, TLS, real OAuth/SMTP, signed Play
artifacts, privacy/erasure, and partner economics remain separate launch gates.
See LAUNCH_AUDIT.md for evidence and unresolved limitations.
