# Admin cover and record lifecycle rollout — 19 October 2026

Implementation: `b85ffa5a28fb82cada9b23f4e2a736476d0a1c1a` on `main`.

## Verification

- Local isolated PostgreSQL: **172 passed, zero failures/errors** on a fresh test database. The interrupted earlier run left fixtures behind; that contaminated database was not used for the final result.
- Admin: **22 tests passed**, production build passed, dependency audit found zero vulnerabilities.
- Android: **79 Flutter tests passed**, analysis clean, arm64 profile APK built and `adb install -r` succeeded on the Redmi Note 11. Installation retained app data; a new owner walkthrough of the cover is pending.
- Actual browser against a separate local database: signed in, selected a file, clicked Save cover, observed confirmation and a server image URL, then refreshed and confirmed the 1280×720 image remained loaded. The later archive-confirmation check was blocked by the browser-control dialog handler, so no successful browser archive/restore walkthrough is claimed. API and component tests cover those operations.
- Live production admin proxy: uploaded a synthetic **3.3 MB PNG** to a disposable inactive store, received a public HTTPS WebP, checked the saved store URL and the image's dimensions/cache headers.
- Recreated only the Stepsy API container, then verified the store URL and SHA-256 of its image bytes were unchanged. Removed the disposable store and unused merchant account afterward. Real customer records were not changed by this smoke test.

## Production

- API: `https://api.stepsyapp.com`, migration **0009**, healthy.
- Admin: `https://admin.stepsyapp.com`, implementation deployment `dpl_8YyRCnRstx9epY2g6RfTh7UJFXR1`, production READY with the matching commit.
- Admin asset: `/assets/index-C8u3Lycj.js`; verified the cover form is present and the old HTTP IP target is absent.
- Local ignored `web/.env` also had a stale HTTP IP target. It now leaves `VITE_API_URL` empty so the configured proxy is used.
- Actual Docker volume: **`backend_stepsy_media`**, mounted at `/app/uploads`.
- Only `/etc/nginx/sites-available/stepsy-api` changed, adding the upload allowance. Nginx validation passed before graceful reload.
- The eight other running containers retained their exact IDs and start times. Stepsy's runtime environment hash was unchanged.

Restricted server evidence and backups: `/root/stepsy-rollouts/20261019-admin-media/`. This includes the pre-migration database dump, media backup, previous Stepsy Nginx configuration, source bundle, build/activation logs and container-integrity result. Do not publish backups or runtime environment files.

Rollback image: `stepsy-backend:before-admin-media-20261019`. Retain migration 0009's additive columns and the media volume if restoring code. The old application does not understand archive state or covers; consider those behavior differences before rolling back. Do not drop schema columns or remove the media volume to roll back a container.

See [ADMIN_PANEL_GUIDE.md](ADMIN_PANEL_GUIDE.md) for editing rules, upload instructions and remaining admin priorities. No Play Console upload was performed.
