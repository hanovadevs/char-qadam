# Stepsy mobile

Flutter app for step tracking, points, merchant rewards, wallet, customer support and optional notifications.

## Linux Android setup

The Pixel 8 is visible to ADB after accepting USB debugging. Java and a full Android build toolchain are also needed:

```bash
sudo apt update
sudo apt install openjdk-17-jdk
bash scripts/setup_android_linux.sh
flutter run -d 38261FDJH00KR5
```

The setup script downloads official Google SDK tools and verifies their published checksum. Review the SDK licenses when prompted. The first Android build may download Gradle and NDK components.

`flutter run -d linux` runs the desktop build. Step tracking and device integrations must be tested on Android/iOS hardware.

## Verification

```bash
flutter analyze
flutter test
```

## Release

See [the production/Play Store handoff](../docs/PRODUCTION-HANDOFF.md). Release builds require real HTTPS API/privacy/deletion URLs, publisher/support details and upload signing. The `.github/workflows/android-release.yml` workflow prepares a signed bundle once its variables and secrets are configured. Do not submit a debug build or a build using HTTP endpoints.
