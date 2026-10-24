# Stepsy mobile

Flutter/Riverpod app for Android-first Stepsy. The Dart package is historically named `qadam`; Android's application ID is `com.stepsy.run`.

Use [the project setup guide](../README.md#getting-started) for API, OAuth and local-device configuration. Run from this folder:

```powershell
flutter pub get --enforce-lockfile
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000 --dart-define=GOOGLE_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

For USB localhost, run `adb reverse tcp:8000 tcp:8000` first. Without an API override, the app uses the live HTTPS API.

```powershell
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
```

Physical-device checks are required for step accuracy, locked-screen/idle tracking, notification Stop/Resume and bike/car classification. See [Android reliability](../docs/tracking/ANDROID_TRACKING_RELIABILITY.md), [vehicle filtering](../docs/tracking/VEHICLE_FILTERING.md), [the companion source guide](../design/stepsy-companion/character-guide.md) and [Play Console/signing](../docs/operations/PLAY_CONSOLE.md). Publishing remains paused.
