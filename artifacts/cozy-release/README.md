# Cozy mobile previews

These are Flutter-rendered screenshots of the current app using fictional accounts, points, offers and vouchers. They are not partner endorsements or production inventory. Device system bars and keyboard appearance may differ on Android.

The five-tab screens and four authentication views follow the user’s 31 October 2026 reference boards. The character comes from the editable 3D master in `design/cozy-companion/`. The park is bundled generated artwork. Source/provenance and rebuild commands are in the [character guide](../../design/cozy-companion/character-guide.md).

From `mobile/`, regenerate into a new directory to avoid overwriting images held open by a Windows image viewer:

```powershell
flutter test --dart-define=CAPTURE_UI=true --dart-define=CAPTURE_DIRECTORY=../artifacts/cozy-release test/redesign_flow_test.dart test/cozy_auth_test.dart
```

`steps.png`, `points.png`, `rewards.png`, `wallet.png` and `profile.png` are the main screens. `welcome.png`, `sign-in.png`, `create-account.png` and `recover-access.png` cover authentication. Additional screenshots document loading, zero, offline, denied access, redemption failure, fireworks and voucher QR states. The backend retains token-based password recovery; that control says “Send reset instructions.”

The main screens and authentication views were refreshed for the continuous-cloth/60-frame character refinement. Auxiliary offline/loading/failure/QR previews record the earlier cozy UI and its functional states. The [walk preview](../../design/cozy-companion/walk-preview.gif) demonstrates the current side-facing gait.
