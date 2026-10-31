# Android reminders — 31 October 2026

Stepsy uses local Android reminders for customer accounts. They work without an API connection and do not change steps, points, vouchers or device-account reservations. Merchant sessions and signed-out sessions disable these customer reminders. There is no remote push campaign service or admin broadcast tool in this implementation.

## Customer controls

Open **You → Notifications & reminders**. Preferences are saved per account on this phone. The master switch controls optional messages; individual switches control walking encouragement, tracking help, welcome-back reminders, reward updates and points confirmations. Points confirmations default off; the other categories default on. Android notification permission and the individual Android notification channels must also be allowed.

**Send a test reminder** posts an explicit preview that opens Tracking help. This manual preview bypasses quiet hours and the daily automatic-reminder limit. It never changes tracking state or automatic-reminder history.

The ongoing tracking notification remains separate. Its **Stop tracking** action continues to pause counting even when optional reminders are switched off.

## Automatic reminder rules

| Category | When it becomes eligible | Tap destination |
| --- | --- | --- |
| Walking encouragement | At or after the chosen time, default 6 pm; tracking running, below the personal goal, app used within the past three days | Steps |
| Unexpected tracking interruption | Tracking previously enabled, not deliberately paused, native service absent for at least 15 minutes | Tracking help |
| Deliberate pause | One reminder after 24 hours of that pause, when tracking-help reminders are allowed | Tracking help |
| Welcome back | At three and seven elapsed days without opening the app; no continuing stream after seven days | Steps |

All three automatic categories share a device-wide limit of **one reminder per local calendar day**, with at least **20 hours** between messages. Quiet hours are **9 pm–9 am** in the phone's local time. Reminders are suppressed while the app is open, within 30 minutes of the most recent app use, or while bike/car movement is recognized. Tracking help has priority, then welcome-back, then walking encouragement. Disabled categories do not consume the limit. A missed reminder is evaluated against current conditions rather than replayed as a backlog.

Walking copy rotates between gentle messages. Near the goal, it uses the remaining steps from the maximum available **current-day** native count and account-scoped cached server summary. Yesterday's totals are ignored; unknown progress gets generic copy. A completed goal suppresses walking encouragement. No message promises unconfirmed points or a medical outcome.

Reward/points messages are event confirmations, outside the automatic-reminder budget and quiet-hours schedule. They follow their own preferences and are suppressed while the app is foregrounded. Voucher codes are excluded from their text. The expiry helper is not a scheduled expiry campaign.

## Restart help and privacy

Tracking-help notifications open a guide with tracking status, explicit Resume/Stop controls, Physical Activity access, notification access, background battery settings and Redmi Autostart/No restrictions instructions. Opening the guide **does not override a deliberate pause**. The existing recovery path can restart previously enabled, unexpectedly interrupted tracking when the app opens. Resume keeps the existing saved baseline rules; it does not add paused movement back.

Notification destinations are allowlisted and pass through authentication. Customer destinations are discarded for merchant sessions. Logout/account changes cancel optional visible reminders and disable the worker when no customer is active. Preferences are separate for each account; the daily cooldown stays device-wide. Optional native reminders use private lock-screen visibility with generic public text; actual lock-screen display also depends on Android's settings.

## Scheduling and limits

The native WorkManager job `stepsy-gentle-reminders` checks eligibility about every 15 minutes. It is independent of `stepsy-periodic-step-sync`, so Stop tracking does not remove the later help path. It has no network requirement. Eligibility times are **not exact delivery alarms**: Android power management and Xiaomi restrictions may delay execution. Android documents the 15-minute periodic minimum and flexible execution in [work requests](https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work).

Users must allow [notification permission on Android 13+](https://developer.android.com/develop/ui/compose/notifications/notification-permission). A force-stopped app cannot reliably remind the user to reopen itself. Android's [stopped-state behavior](https://developer.android.com/about/versions/15/behavior-changes-all#enhanced-stop-states) and manufacturer restrictions take precedence. This feature does not bypass those controls or restart tracking without the existing permission and pause checks.

## Source and verification

- Native decisions: [ReminderPolicy.kt](../../mobile/android/app/src/main/kotlin/com/stepsy/run/ReminderPolicy.kt).
- Background scheduling/channels: [ReminderScheduler.kt](../../mobile/android/app/src/main/kotlin/com/stepsy/run/ReminderScheduler.kt).
- Account-scoped preferences and navigation: [notification feature](../../mobile/lib/features/notifications).
- Automated checks: [policy tests](../../mobile/android/app/src/test/kotlin/com/stepsy/run/ReminderPolicyTest.kt), [notification flow tests](../../mobile/test/notifications_test.dart) and [pause/help regression checks](../../mobile/test/idle_tracking_test.dart).

Policy tests use controlled timestamps for three/seven-day eligibility, quiet hours, cooldowns, intentional pauses, interruptions and stale-day progress. These are not physical multi-day standby observations.

Verification on 31 October 2026:

- Flutter analyzer: no issues; full Flutter suite: **150 passed**.
- Android JVM suite: **23 passed**, including seven reminder-policy tests and the existing counter, identity and vehicle-filter checks.
- Documentation checker: **99 local targets in 35 Markdown files** validated.
- Arm64 profile APK built successfully and installed on the Redmi Note 11 with `adb install -r`, preserving the saved **114 steps**, five days of native history and the existing tracking flags at installation. APK SHA-256: `d82ce954c3458267364b306c13b72ac5edc2b8dbdb35f90bdda289d0ddc21101`.
- On-device checks found the foreground tracking service running, both separate 15-minute WorkManager jobs queued, and no sampled notification-initialization or fatal runtime errors. The reminder worker had zero failed attempts at the sample.
- The owner confirmed that the explicit test reminder opened Tracking help and that walking still counted live. Actual three/seven-day standby delivery remains an observation for later use.
