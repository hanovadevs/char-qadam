# Repository organization — 24 October 2026

The root README is now the project entry point, with local setup, architecture, feature scope and labeled UI previews. Documentation is grouped under `docs/setup`, `product`, `architecture`, `tracking`, `operations`, `design` and `history`; 20 documents were moved and their relative links rebased. Historical plans and rollout evidence were retained.

Removed confirmed disposable content:

- 30 ignored root-level test/build/audit reports (176,593 bytes); current evidence stays in tracked guides and ignored module build output.
- The unused `mobile/assets/icon/app_icon.png`, byte-identical to the retained official `Stepsy_Icon1.png` (1,177,861 bytes). Launcher configuration and runtime references use the retained file.
- The obsolete Swiss-style root icon generator, which wrote the unused filename.
- Two redundant `.gitkeep` files in nonempty backend package directories.

Environment files, signing material, local database data, installed dependencies, current APKs, editable Blender art, transparent masters, font licenses and migrations were preserved. The pre-existing uncommitted companion-settings edit was left untouched and excluded from commits.

Local admin development now proxies to localhost by default, with `VITE_PROXY_TARGET` for an explicit override. A real ephemeral HTTP proxy test checks the override without contacting production. The backend template includes a local `PUBLIC_API_URL` so development cover images do not point at the live server; production operators must supply their actual HTTPS domain.

Run `python tools/check_docs.py` from the repository root to check local Markdown links and HTML image targets without fetching remote URLs. It uses Python's standard library and skips generated/dependency directories.

Validation is recorded alongside each implementation: Flutter analysis/tests, native counter/vehicle tests, admin tests/build and the local documentation link check. A fresh PostgreSQL setup smoke was not executed during this cleanup because Docker Desktop was stopped; the database instructions were checked against the current environment template, migration configuration and test isolation guard.
