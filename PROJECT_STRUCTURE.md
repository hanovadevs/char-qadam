# Stepsy project structure

Updated 2026-10-17. Package name `qadam` and GitHub repository `char-qadam` are
legacy identifiers; the product is Stepsy by Hanova Devs.

```text
mobile/
  lib/
    core/                 environment, theme, cache, notifications, background upload
    data/                 API/auth and feature repositories, health reconciliation, DTOs
    features/             onboarding, auth, activity/progress, points, rewards,
                          wallet, leaderboard, profile, merchant POS
    routing/              stable GoRouter and onboarding/auth redirects
  android/app/src/main/kotlin/com/stepsy/run/
    MainActivity.kt       Flutter platform/event channels
    DailyStepCounter.kt   counter/reboot/rollover arithmetic
    StepTrackingService.kt persistent foreground sensor lifecycle
    StepBootReceiver.kt   authorized boot resumption
  android/app/src/test/   native counter regressions
  test/                   Flutter state, model, cache, session and widget regressions
backend/
  app/
    routers/              auth, users, activity, points, offers, vouchers,
                          leaderboard, partner POS, protected admin and health
    services/             reward/activity/security/email business logic
    db/                   SQLAlchemy models and async sessions
    schemas/              API request and response contracts
    middleware/           request logging and auth rate limits
  alembic/versions/        versioned schema through credential revocation (0004)
  tests/                  isolated PostgreSQL integration and security tests
web/
  src/pages/              admin login, overview, stores, deals, vouchers, users,
                          ledger, audit and server-backed settings
  src/services/api.js     same-origin or VITE_API_URL API client
.github/workflows/        repeatable checks for main and pull requests
REQUIREMENTS.md           current Android-first acceptance requirements
LAUNCH_AUDIT.md           verified fixes, known release gates, Redmi testing protocol
```

Generated mobile/build, mobile/android/build, web/dist, virtual environments,
local databases, environment files and signing material are not source artifacts.
