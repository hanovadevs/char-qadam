# Bike and car exclusion

The owner confirmed on 24 October 2026 that riding/driving movement should **not** count as walking steps. There was no GPS speed limit in the previous implementation.

## Implementation

Android now requests low-power Google Play services Activity Recognition updates while the native tracking service is enabled. It uses Physical Activity permission and an explicit private receiver; it does not request GPS location or estimate km/h. Recognition is removed on Stop, logout and service destruction. The app shows unavailable recognition instead of claiming that a filter is active.

`VehicleMotionGate` excludes steps when vehicle/bicycle confidence is at least 75 and on-foot confidence is below 50. Confident on-foot activity (walking or running) clears the block at 60 or above when it is the strongest signal. Unknown or ambiguous signals do not start a block. Stored context expires after two minutes without a fresh signal; old/out-of-order/future or previous-boot results cannot freeze walking indefinitely.

The hardware baseline advances even while raw deltas are rejected, so those deltas cannot be re-added on walking or reopening. An explicit Resume clears old motion context. Recognizing vehicle movement suppresses whole-day Health Connect import for that date, preventing a second unfiltered source from restoring the rejected steps. Native walking continues; this can reduce Health Connect gap recovery for that day.

## Limits and testing

Activity recognition is probabilistic and can arrive late, especially under system power restrictions. The requested update interval is five seconds, not a delivery guarantee. Movement recorded before vehicle recognition is not retrospectively removed from server-awarded points. No guarantee is made that every motorbike, car vibration or cycling interval is classified immediately. A strict numeric speed limit would require a separate location-permission, privacy and accuracy design; it is not implemented here.

Native tests cover confident vehicle/bicycle blocking, uncertain signals, immediate on-foot recovery, stale/previous-boot context and preserving the filtered baseline across reopening. Actual walking, riding as a passenger and bicycle testing are separate physical checks. Do not operate the phone while driving/riding; test safely as a passenger or inspect a completed ride.

References: [Activity Recognition client](https://developers.google.com/android/reference/com/google/android/gms/location/ActivityRecognitionClient), [confidence/type definitions](https://developers.google.com/android/reference/com/google/android/gms/location/DetectedActivity), [activity recognition overview](https://developers.google.com/location-context/activity-recognition).

## Build and validation — 24 October 2026

Feature/setup/organization source: `6133e56`. Flutter analysis is clean; 122 mobile tests, 16 native tests and 23 admin tests pass. The admin production build and a real ephemeral local dev-proxy HTTP check pass. The documentation checker validates 74 local targets. Fresh PostgreSQL setup was not smoke-tested in this session because Docker Desktop was stopped; backend changes are setup templates and documentation references.

The final profile arm64 build succeeded in 111.0 seconds. APK SHA-256: `DD51224A1504EF4462CEBF949E362A83FCDC6D1ECA3CB4397551F31974704E78`. Replacement installation on the Redmi succeeded at 2026-10-24 18:42:23, preserving storage and with Physical Activity permissions granted. APK inspection confirmed the native classifier is bundled and the removed duplicate icon is absent. Normal walking/Stop regression feedback and a real passenger/cycling classification check were requested; physical vehicle exclusion remains unverified until that trip is observed.

Owner follow-up, 24 October 2026: “All good” was reported for the walking and Stop/Resume check on this build. No before/after passenger or cycling counts were supplied; real-trip vehicle exclusion remains pending.
