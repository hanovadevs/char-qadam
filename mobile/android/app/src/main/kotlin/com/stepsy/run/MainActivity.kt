package com.stepsy.run

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorManager
import java.time.LocalDate

// Must extend FlutterFragmentActivity (not FlutterActivity) so the `health`
// plugin can register its Health Connect permission ActivityResultLauncher.
// With a plain FlutterActivity the plugin logs "Permission launcher not found"
// and requestAuthorization() always returns false, which leaves the user stuck
// on the onboarding "Enable Step Tracking" screen.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "stepsy/step_tracking").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "start" -> result.success(StepTrackingService.start(this))
                    "stop" -> { StepTrackingService.stop(this); result.success(null) }
                    "snapshot" -> result.success(StepTrackingService.snapshot(this)
                        .put("service_running", StepTrackingService.running)
                        .put("sensor_available", (getSystemService(Context.SENSOR_SERVICE) as SensorManager).getDefaultSensor(Sensor.TYPE_STEP_COUNTER) != null)
                        .toString())
                    "mergeHealth" -> result.success(StepTrackingService.update(this) {
                        it.mergeHealth(call.argument<Int>("steps") ?: 0, LocalDate.now().toString(),
                            call.argument<Int>("raw"), call.argument<Int>("boot") ?: it.boot)
                    }.toString())
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
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        StepTrackingService.onSteps = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
