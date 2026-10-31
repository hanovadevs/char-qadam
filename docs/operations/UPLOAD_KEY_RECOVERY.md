# Upload-key recovery for version 1.0.0+8

The owner reported that the original Play upload key is lost. A replacement upload key was generated locally; this does not reset the key registered in Play Console.

Private local files, excluded from Git:

- `mobile/android/stepsy-upload-20261101.jks`: replacement private keystore.
- `mobile/android/key.properties`: local signing configuration and passwords.

The public reset certificate is exported to `mobile/build/play-release/upload_certificate.pem`. Back up both private files securely; do not put them in GitHub, email, screenshots or the app bundle.

## Play Console action

If Stepsy uses Play App Signing, the account owner must open the app signing page and request an upload-key reset using the public PEM certificate. Wait for Google's confirmation and the new key's activation before uploading the replacement-signed AAB. Keep the existing app signing key: the upload key and app signing key serve different purposes.

For Google sign-in in Play-distributed builds, register the **Play app signing certificate's SHA-1** for Android package `com.stepsy.run` in the Google Cloud project containing Stepsy's Web OAuth client. Registering only a debug or replacement upload certificate is insufficient. The data-preserving USB test APK continues using the existing debug key.

Replacement upload certificate SHA-1:

```text
2D:6D:40:4A:84:4D:93:AB:C1:4C:43:E7:96:EE:37:E0:64:87:78:B4
```

See Google's [upload-key recovery and signing guidance](https://support.google.com/googleplay/android-developer/answer/9842756?hl=en). If Play App Signing is not enabled and the lost key was the app signing key itself, do not assume an upload-key reset can recover it.

Building or signing a bundle does not publish the app. This task does not upload a release to Play Console.
