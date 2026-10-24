# Android idle tracking and notification Stop — 24 October 2026

The owner reported that counting would fail to resume after a few minutes or hours of stillness on a Redmi Note 11.

## Evidence and implementation

Before this change, the Redmi's native tracking service was absent, the CPU was Dozing and Stepsy was not in the battery-optimization exemption list. Its sensor inventory exposes both non-wake-up and wake-up Qualcomm step counters. The previous service always chose the default non-wake-up counter and did not hold a CPU wake lock. Process exit history also showed low-memory/empty-process exits; this does not establish the exact cause or time of the earlier foreground service loss.

The service now prefers a wake-up step counter, with immediate delivery requested and continuous registration while enabled. Devices with only a non-wake-up counter use a partial wake lock while the service runs: a ten-minute lease renewed every five minutes, released on destruction or Stop. A change between sensor variants resets the raw baseline while preserving saved daily steps, avoiding false deltas from different raw counter origins.

Enabled tracking is recovered when the app returns to the foreground. The existing sticky service and boot recovery remain in place; both respect a deliberate pause. Android and manufacturer restrictions still apply. The Steps screen exposes Allow background activity through Android's battery permission UI, plus Redmi Autostart/No restrictions guidance. The app does not silently change these system settings.

Android's [sensor guidance](https://source.android.com/docs/core/interaction/sensors/suspend-mode) explains non-wake-up delivery while suspended. [Wake lock guidance](https://developer.android.com/develop/background-work/background-tasks/awake/wakelock) and the [foreground service overview](https://developer.android.com/develop/background-work/services/fgs) distinguish CPU wakefulness from service lifecycle.

## User controls

- The ongoing step notification has a **Stop tracking** action using an explicit, non-exported receiver.
- Stop persists a paused state, unregisters the sensor, releases any CPU wake lock, removes the notification and cancels the periodic sync job.
- Background sync and initialization check the paused flag. Reopening, refreshing and boot recovery do not override it.
- Steps shows the tracking state and an explicit **Resume tracking** control.
- Resume keeps saved progress and re-establishes the native baseline. Paused movement is excluded; whole-day Health Connect reconciliation is suppressed for the pause/resume day so it cannot backfill the stopped interval. Native counting continues normally once resumed. This can reduce Health Connect gap recovery for that day.
- No steps are invented for a missed period. Earning caps, points, rewards, account/device rules and redemption behavior are unchanged.

## Verification

- Flutter analyzer: no issues.
- Mobile suite: 122 passing, including recovery before controls scroll into view, paused background-work gating, explicit resume, paused UI at 320px/200% text and the existing tracking/reward regressions.
- Android JVM suite: 12 passing (9 counter tests, 3 identity tests). Added tests cover three-minute/hour-long same-day idle gaps and excluding paused raw deltas without losing saved steps.
- Profile APK and physical Redmi checks are recorded below after installation. A simulated long timestamp gap in a unit test is not a physical hours-long standby test.

Physical walkthrough: grant background battery access; lock and leave still for at least three minutes; walk 30 manually counted steps before reopening. Then use notification Stop, verify that refresh/reopening stays paused and does not add walking, Resume explicitly, and verify new movement without a catch-up jump. Overnight standby and actual reboot recovery need separate observation.

The pre-existing local edit to `experience_sheet.dart` was preserved and excluded from this change's commit.

## Installed build

Source commit `422e7d6`; final profile arm64 build succeeded (132.7-second Gradle build). APK SHA-256: `436DE0EDE9FEF13F18A474DBD60ECC871398272C6BB327BF5B763E09837AF311`. Replacement installation on the Redmi succeeded at 2026-10-24 17:48:14, without clearing app storage; motion and notification permissions remain granted. The owner was asked to allow background battery access and perform the locked three-minute idle → 30-step walk, followed by notification Stop/Resume checks. Physical outcomes are pending below.

At the initial post-open sample (17:49), Android reported the service as foreground with one notification action. SensorService showed Stepsy registered on `pedometer Wakeup` (`0x010000c0`) with zero batching latency. Polling was then stopped to avoid keeping the phone awake during the owner's idle test. This verifies the new registration and foreground notification, not the still-pending idle/walking outcome.

Owner acceptance, 24 October 2026: the owner confirmed that the locked idle/walking check worked and separately confirmed that notification Stop persisted through reopening/refresh and that explicit Resume counted new movement without a catch-up jump. This is the reported Redmi walkthrough; hours-long/overnight and actual reboot behavior remain separate observations.
