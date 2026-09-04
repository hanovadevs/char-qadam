package com.stepsy.run

import io.flutter.embedding.android.FlutterFragmentActivity

// Must extend FlutterFragmentActivity (not FlutterActivity) so the `health`
// plugin can register its Health Connect permission ActivityResultLauncher.
// With a plain FlutterActivity the plugin logs "Permission launcher not found"
// and requestAuthorization() always returns false, which leaves the user stuck
// on the onboarding "Enable Step Tracking" screen.
class MainActivity : FlutterFragmentActivity()
