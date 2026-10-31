<p align="center">
  <img src="mobile/assets/icon/Stepsy_Icon1.png" width="88" alt="Stepsy logo" />
</p>
<h1 align="center">Stepsy</h1>
<p align="center"><strong>Every step, closer.</strong><br />A walking companion and partner-rewards app for Pakistan, by Hanova Devs.</p>
<p align="center">
  <a href="#getting-started">Get started</a> ·
  <a href="docs/README.md">Documentation</a> ·
  <a href="docs/tracking/ANDROID_TRACKING_RELIABILITY.md">Android tracking</a> ·
  <a href="docs/operations/LAUNCH_AUDIT.md">Launch readiness</a>
</p>
<p align="center">
  <img alt="Android first" src="https://img.shields.io/badge/Android-first-087F72?style=flat-square" />
  <img alt="Flutter 3.47.1" src="https://img.shields.io/badge/Flutter-3.47.1-102B32?style=flat-square" />
  <img alt="FastAPI and PostgreSQL" src="https://img.shields.io/badge/FastAPI-PostgreSQL-087F72?style=flat-square" />
  <a href="https://github.com/hanovadevs/char-qadam/actions/workflows/checks.yml"><img alt="Stepsy checks" src="https://img.shields.io/badge/CI-Stepsy_checks-102B32?style=flat-square" /></a>
</p>

---

## A little walk. A real reward.

Stepsy connects daily movement to useful partner offers. See live steps, work toward a personal goal, earn server-calculated points and redeem an offer into a single-use voucher. The cozy walking companion, adds small moments of encouragement and helps users find their way from an offer to its QR code.

<table>
  <tr>
    <td align="center"><img src="artifacts/ux-refinement/steps.png" width="230" alt="Steps preview with the companion and a reward goal" /><br /><strong>Every little step</strong></td>
    <td align="center"><img src="artifacts/cozy-release/rewards.png" width="230" alt="Rewards preview with point prices and branch Maps" /><br /><strong>Find your little win</strong></td>
    <td align="center"><img src="artifacts/cozy-release/wallet.png" width="230" alt="Wallet preview with a voucher and Show QR" /><br /><strong>Keep it in Wallet</strong></td>
  </tr>
</table>
<sub>Design previews use fictional accounts, figures and offers. They are not claims of confirmed commercial partnerships or live reward availability.</sub>

## What is here

| Experience | Implementation |
| --- | --- |
| **Steps** | Live hardware counts, personal goals, weekly history and diagnostics. Android uses a foreground service, wake-up sensor preference and a wake-lock fallback. |
| **Companion & theme** | Editable 3D character, 13 pre-rendered clips, illustrated sage/cream screens, tap reactions, live walking and reduced-motion controls. |
| **Guided first visit** | A replayable 20-stop character tour with thought clouds, real section highlights and saved progress across the five customer tabs. |
| **Achievements** | A server-ranked leaderboard with a medal podium, personal place, period controls and scoring guidance. |
| **Points & rewards** | Server-calculated earnings, ledger history, one claim per account per offer, explicit confirmation and purchase recovery. |
| **Wallet & merchant POS** | Ready/history vouchers, camera QR validation, explicit redemption, and weekly/monthly PDF ledgers with generation history. |
| **Account** | Google sign-in, verified email access and separate one-customer/one-merchant device reservations. |
| **Reminders** | Optional walking encouragement, tracking recovery help and welcome-back reminders, with account preferences, quiet hours and a shared daily limit. |
| **Admin** | Stores, cover uploads, Maps destinations, deals, users, vouchers, ledger and guarded archival. |

**Status:** Android-first pre-launch hardening. Other Flutter platform scaffolds are retained but are not validated release targets. Play Console publishing is paused. The [launch audit](docs/operations/LAUNCH_AUDIT.md) records outstanding gates; passing tests or pushing `main` does not establish deployment or public release.

## How it fits together

```mermaid
flowchart LR
    Sensors[Android sensors] --> Mobile[Flutter app + companion]
    Mobile --> API[FastAPI]
    Admin[React admin] --> API
    Merchant[Merchant POS] --> API
    API --> DB[(PostgreSQL)]
    API --> Media[Persistent store covers]
    API --> Mail[Verification email]
```

```text
Stepsy/
├── mobile/       Flutter app, Android tracking, tests and runtime assets
├── backend/      FastAPI, PostgreSQL models, Alembic migrations and tests
├── web/          React/Vite administration portal
├── design/       Editable Blender companion, scripts and transparent masters
├── artifacts/    Clearly labeled UI test previews
├── deploy/       Host deployment configuration
├── docs/         Setup, product, architecture, operations and design guides
└── .github/      CI checks
```

The Dart package and some historical/container identifiers still use `qadam`; the Android application ID is **`com.stepsy.run`**. These identifiers are retained for compatibility.

## Getting started

### Requirements

| Tool | Project baseline |
| --- | --- |
| Flutter | **3.47.1**, matching CI; use its bundled Dart SDK |
| Android | Android Studio/SDK and a compatible JDK (CI uses Java 17); Android 8+ physical device for sensor checks |
| Python | **3.12** and a virtual environment |
| Node.js | **24.x**, with npm |
| PostgreSQL | **16+**; Docker is convenient for local development |

Commands below use **PowerShell**. Run each section from the indicated directory. Keep existing `.env` and signing files; do not replace them with templates.

```powershell
git clone https://github.com/hanovadevs/char-qadam.git Stepsy
cd Stepsy
```

### 1 · Start a local database

Use an existing development PostgreSQL instance, or create a project-specific Docker database:

```powershell
docker run --name stepsy-dev-db -e POSTGRES_USER=stepsy_dev -e POSTGRES_PASSWORD=local-dev-only -e POSTGRES_DB=stepsy_dev -p 127.0.0.1:35432:5432 -v stepsy-dev-postgres:/var/lib/postgresql/data -d postgres:16-alpine
```

On later runs, use `docker start stepsy-dev-db`. The named volume preserves data. The password above is only an example for an isolated loopback development database.

### 2 · Run the API

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
if (!(Test-Path .env)) { Copy-Item .env.example .env }
```

Edit `backend/.env` before starting:

| Setting | Local setup |
| --- | --- |
| `DATABASE_URL` | `postgresql+asyncpg://stepsy_dev:local-dev-only@127.0.0.1:35432/stepsy_dev` for the example database |
| `PUBLIC_API_URL` | `http://127.0.0.1:8000` for local store-cover images |
| `JWT_SECRET` | Your own random secret; keep it private |
| `REDEMPTION_RECEIPT_KEYS` | A stable Fernet key for purchase recovery; generation command in `.env.example` |
| `ADMIN_EMAIL`, `ADMIN_PASSWORD` | Your local admin credentials; do not use production credentials |
| `GOOGLE_CLIENT_ID` | Your Web OAuth client ID, matching the mobile build; [Google setup](docs/setup/AUTH_SETUP.md) |
| `SMTP_*` | A working sender for customer verification and password-reset email; admin-issued `@stepsyapp.com` store logins use their password without an email code ([policy](docs/setup/AUTH_SETUP.md#admin-issued-merchant-login-ids)) |

```powershell
.\.venv\Scripts\python.exe -m alembic upgrade head
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

Check [health](http://127.0.0.1:8000/health), [database readiness](http://127.0.0.1:8000/health/ready) and [API documentation](http://127.0.0.1:8000/docs). Use demo seeds only against an isolated development database.

<details>
<summary>macOS / Linux virtual environment commands</summary>

```bash
cd backend
python3.12 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
cp -n .env.example .env
# Configure .env as above.
.venv/bin/python -m alembic upgrade head
.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

</details>

### 3 · Run the admin portal

In another terminal, from the repository root:

```powershell
cd web
npm.cmd ci
if (!(Test-Path .env.local)) { Copy-Item .env.example .env.local }
npm.cmd run dev
```

Open [localhost:3000](http://localhost:3000) and use the local API's admin credentials. The Vite `/admin` proxy defaults to **localhost:8000**; set `VITE_PROXY_TARGET` to override it. Keep `VITE_API_URL` empty for this same-origin proxy. A direct browser API URL needs matching CORS settings. Production hosting uses the separate HTTPS proxy in `vercel.json`.

### 4 · Run on an Android phone

Enable USB debugging and confirm the device is visible:

```powershell
adb devices
adb reverse tcp:8000 tcp:8000
cd mobile
flutter pub get --enforce-lockfile
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000 --dart-define=GOOGLE_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

Without `API_BASE_URL`, mobile defaults to `https://api.stepsyapp.com`. Always pass the local override when developing. An Android emulator can use `http://10.0.2.2:8000` instead of USB reverse.

Google sign-in also needs an Android OAuth client for `com.stepsy.run` and the build signing certificate's SHA-1. Follow [auth setup](docs/setup/AUTH_SETUP.md); a Web client ID alone is insufficient.

Allow Physical Activity and notifications. Steps exposes **Allow background activity**, **Stop tracking** and **Resume tracking**; the ongoing notification also has Stop. On Redmi, allow Autostart and No restrictions. A physical phone is required to validate sensor accuracy, locked-screen behavior and battery controls.

## Step integrity and privacy

- The hardware counter supplies movement; the API calculates points from cumulative daily totals. Configurable defaults are **100 eligible steps per point** and **20,000 eligible steps/day**. A personal goal does not change those rules.
- Recognized bike/car activity excludes raw sensor deltas while preserving the baseline. Walking and running remain eligible. This is **motion-based filtering**, not a GPS speed limit or a guarantee of immediate vehicle classification.
- The filter does not request GPS location. It requires Google Play services Activity Recognition and Physical Activity permission; unavailable detection is shown in the app. See [vehicle filtering](docs/tracking/VEHICLE_FILTERING.md) for thresholds and limits.
- Stop persists across refresh/reopening and boot recovery. Resume is explicit; paused movement is not backfilled. Goals and companion preferences belong to the account **on that phone**, not to a cross-device settings service.

## Development checks

Run from the repository root with dependencies installed:

```powershell
python tools/check_docs.py
Push-Location mobile
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
Push-Location android
.\gradlew.bat :app:testDebugUnitTest '-Ptarget=lib/main.dart' --max-workers=2
Pop-Location
Pop-Location

Push-Location web
npm.cmd test
npm.cmd run build
Pop-Location
```

Backend tests need a **separate loopback database whose name ends in `_test`**. The suite migrates and clears test data. Do not point it at development data or a shared database:

```powershell
cd backend
$env:TEST_DATABASE_URL='postgresql+asyncpg://TEST_USER:TEST_PASSWORD@127.0.0.1:TEST_PORT/stepsy_test'
.\.venv\Scripts\python.exe -m pytest tests -q
```

CI runs backend, Android and admin checks through [Stepsy checks](.github/workflows/checks.yml). Automated tests, device acceptance and live deployment are separate pieces of evidence.

## Design & documentation

| Start here | Purpose |
| --- | --- |
| [Documentation index](docs/README.md) | Complete guide map |
| [Architecture](docs/architecture/PROJECT_STRUCTURE.md) | App boundaries and repository layout |
| [Product requirements](docs/product/REQUIREMENTS.md) | Requirements and acceptance criteria |
| [Admin guide](docs/operations/ADMIN_PANEL_GUIDE.md) | Stores, covers, rewards, archival and account operations |
| [Android tracking](docs/tracking/ANDROID_TRACKING_RELIABILITY.md) | Idle recovery, battery controls and persistent Stop/Resume |
| [Cozy design implementation](docs/design/COZY_REDESIGN.md) | Current five-tab and authentication design, palette and validation |
| [Companion guide](design/cozy-companion/character-guide.md) | Editable Blender source, rendering and runtime budget |
| [Deployment](backend/DEPLOYMENT.md) | Docker rollout, persistent media and rollback |
| [Play Console](docs/operations/PLAY_CONSOLE.md) | Signing, versioning and the paused release process |

Keep `.env` files, upload keys, database files and customer media out of Git. Generated output belongs in ignored build folders. Source art, [font licenses](mobile/assets/fonts), migrations and verification history are retained in the repository.

---
<p align="center"><strong>Made by Hanova Devs · Built for everyday movement in Pakistan.</strong></p>

## Support and production handoff

See [the integration handoff](docs/PRODUCTION-HANDOFF.md) for the support/AI additions and local validation history.
