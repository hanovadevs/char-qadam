package com.stepsy.run

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorManager
import java.time.LocalDate
import android.provider.Settings
import android.net.Uri

// Must extend FlutterFragmentActivity (not FlutterActivity) so the `health`
// plugin can register its Health Connect permission ActivityResultLauncher.
// With a plain FlutterActivity the plugin logs "Permission launcher not found"
// and requestAuthorization() always returns false, which leaves the user stuck
// on the onboarding "Enable Step Tracking" screen.
class MainActivity : FlutterFragmentActivity() {
    private val pdfSaveHandler = PdfSaveHandler(this)
    private var reminderChannel: MethodChannel? = null
    private var reminderRoute: String? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        reminderRoute = ReminderScheduler.validRoute(intent?.getStringExtra(ReminderScheduler.EXTRA_ROUTE))
        reminderChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "stepsy/reminders").apply {
            setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "configure" -> {
                            ReminderScheduler.configure(this@MainActivity, call.argument<String>("userId"), call.argument<Boolean>("customer") == true,
                                call.argument<Map<String, Any?>>("settings") ?: emptyMap<String, Any?>(), call.argument<Int>("goal") ?: 8000)
                            result.success(null)
                        }
                        "deactivate" -> { ReminderScheduler.configure(this@MainActivity, null, false, emptyMap<String, Any?>(), 8000); result.success(null) }
                        "consumeLaunch" -> { val route = reminderRoute; reminderRoute = null; intent?.removeExtra(ReminderScheduler.EXTRA_ROUTE); result.success(route) }
                        "preview" -> result.success(ReminderScheduler.preview(this@MainActivity))
                        "eventAllowed" -> result.success(ReminderScheduler.eventAllowed(this@MainActivity, call.argument<String>("category") ?: ""))
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) { result.error("REMINDERS", "Could not update notification preferences", null) }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "stepsy/documents")
            .setMethodCallHandler { call, result -> pdfSaveHandler.handle(call, result) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "stepsy/device_identity").setMethodCallHandler { call, result ->
            if (call.method != "fingerprint") {
                result.notImplemented()
            } else {
                val id = DeviceIdentity.fingerprint(Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID))
                if (id == null) result.error("DEVICE_ID_UNAVAILABLE", "Device identity is unavailable", null)
                else result.success(id)
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "stepsy/step_tracking").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "start" -> result.success(StepTrackingService.start(this, call.argument<Boolean>("resume") == true))
                    "stop" -> { StepTrackingService.stop(this); result.success(null) }
                    "pause" -> { StepTrackingService.stop(this, userPaused = true); result.success(null) }
                    "trackingStatus" -> result.success(StepTrackingService.status(this).toString())
                    "ensureTracking" -> {
                        if (StepTrackingService.enabled(this) && !StepTrackingService.paused(this) && !StepTrackingService.running) {
                            StepTrackingService.start(this)
                        }
                        result.success(StepTrackingService.status(this).toString())
                    }
                    "batterySettings" -> {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName"))
                        try { startActivity(intent) }
                        catch (_: android.content.ActivityNotFoundException) {
                            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                        }
                        result.success(null)
                    }
                    "snapshot" -> result.success(StepTrackingService.snapshot(this)
                        .put("service_running", StepTrackingService.running)
                        .put("paused", StepTrackingService.paused(this))
                        .put("health_allowed", StepTrackingService.healthAllowed(this))
                        .put("sensor_available", (getSystemService(Context.SENSOR_SERVICE) as SensorManager).getDefaultSensor(Sensor.TYPE_STEP_COUNTER) != null)
                        .toString())
                    "mergeHealth" -> result.success(StepTrackingService.update(this) {
                        if (StepTrackingService.healthAllowed(this)) it.mergeHealth(call.argument<Int>("steps") ?: 0, LocalDate.now().toString(),
                            call.argument<Int>("raw"), call.argument<Int>("boot") ?: it.boot)
                    }.put("paused", StepTrackingService.paused(this))
                        .put("health_allowed", StepTrackingService.healthAllowed(this)).toString())
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("STEP_TRACKING", e.message, null)
            }
        }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "stepsy/step_events").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                StepTrackingService.onSteps = { steps -> runOnUiThread { events.success(steps) } }
            }
            override fun onCancel(arguments: Any?) { StepTrackingService.onSteps = null }
        })
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "stepsy/tracking_state").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                StepTrackingService.onStateChanged = { status -> runOnUiThread { events.success(status) } }
                events.success(StepTrackingService.status(this@MainActivity).toString())
            }
            override fun onCancel(arguments: Any?) { StepTrackingService.onStateChanged = null }
        })
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        ReminderScheduler.validRoute(intent.getStringExtra(ReminderScheduler.EXTRA_ROUTE))?.let {
            reminderRoute = it
            reminderChannel?.invokeMethod("open", it)
        }
    }
    override fun onResume() {
        super.onResume()
        ReminderScheduler.foreground = true
        ReminderScheduler.markUsed(this)
    }
    override fun onPause() {
        ReminderScheduler.markUsed(this)
        ReminderScheduler.foreground = false
        super.onPause()
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        StepTrackingService.onSteps = null
        StepTrackingService.onStateChanged = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
