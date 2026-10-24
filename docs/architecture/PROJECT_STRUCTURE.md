# Project structure

Use the [root README](../../README.md) for setup and the [documentation index](../README.md) for guides. Runtime paths and package IDs are retained; documentation has been grouped by purpose.

```text
mobile/
  lib/core/                    configuration, theme, caches, notifications, sync
  lib/data/                    API/auth repositories, DTOs and health reconciliation
  lib/features/                auth, onboarding, activity, Pip, points, rewards,
                               Wallet, leaderboard, profile and merchant POS
  lib/routing/                 GoRouter and authentication/onboarding redirects
  android/app/src/main/kotlin/com/stepsy/run/
    MainActivity.kt            native platform and event channels
    DailyStepCounter.kt        persisted delta/reboot/rollover arithmetic
    StepTrackingService.kt     foreground sensor lifecycle and notification Stop
    StepTrackingControlReceiver.kt  explicit notification control
    StepBootReceiver.kt        enabled-only boot recovery
    VehicleMotionGate.kt       expiring confidence-based travel context
    VehicleRecognition*.kt     Google activity updates and private receiver
  assets/                      bundled branding, fonts and companion atlases
  test/                        Dart state/model/widget regression checks
  android/app/src/test/        native counter, vehicle and identity regressions
backend/
  app/routers/                 auth, activity, points, offers, vouchers, users,
                               leaderboard, merchant, admin and health endpoints
  app/services/                accounting, security, email, media and reward logic
  app/db/                      SQLAlchemy models and async sessions
  app/schemas/                 request/response contracts
  alembic/versions/             schema history, including store-cover support
  tests/                       isolated PostgreSQL integration/security checks
web/
  src/pages/                   admin routes and operations
  src/services/                authenticated API client, caches and validation
  test/                        Node/React regressions
design/stepsy-companion/        editable Blender scene, render/pack scripts,
                               transparent master frames and asset guide
artifacts/redesign/             labeled fictional UI test previews
deploy/nginx/                  Stepsy API host configuration
docs/
  setup/                       auth and integration setup
  product/                     requirements, device/reward policies, inventory
  architecture/                structure and technology notes
  tracking/                    idle reliability and vehicle filtering
  operations/                  admin, rollout, performance and release records
  design/                      blueprint and implementation evidence
  history/                     superseded plans retained for reference
.github/workflows/             checks on main and pull requests
```

Generated output (`mobile/build`, `web/dist`, caches), virtual environments, dependency folders, database volumes, `.env` files and signing material are local and ignored. Keep editable art, font licenses, migrations and verification history. Avoid deleting local databases or media as part of source cleanup.
