package com.stepsy.run

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import android.provider.Settings
import org.json.JSONObject
import java.time.LocalDate
import java.time.Instant
import java.time.ZoneId

/** Owns the sensor independently of Flutter's UI isolate, including when locked. */
class StepTrackingService : Service(), SensorEventListener {
    private lateinit var sensors: SensorManager
    private var notifiedSteps = -1

    override fun onCreate() {
        super.onCreate()
        running = true
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel(CHANNEL, "Step tracking", NotificationManager.IMPORTANCE_LOW))
        val notification = notification(snapshot(this).optInt("steps"))
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIFICATION, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH)
        } else {
            startForeground(NOTIFICATION, notification)
        }
        sensors = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val sensor = sensors.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        if (sensor == null || !sensors.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)) {
            stopSelf()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onDestroy() {
        running = false
        if (::sensors.isInitialized) sensors.unregisterListener(this)
        super.onDestroy()
    }

    override fun onSensorChanged(event: SensorEvent) {
        // Use the sensor event's timestamp: batched callbacks may arrive later.
        val at = System.currentTimeMillis() - (SystemClock.elapsedRealtimeNanos() - event.timestamp) / 1_000_000
        val day = Instant.ofEpochMilli(at).atZone(ZoneId.systemDefault()).toLocalDate().toString()
        val result = update(this) { counter ->
            counter.record(event.values[0].toInt(), day,
                Settings.Global.getInt(contentResolver, Settings.Global.BOOT_COUNT, 0), at)
        }
        onSteps?.invoke(result.optInt("steps"))
        val steps = result.optInt("steps")
        if (notifiedSteps < 0 || kotlin.math.abs(steps - notifiedSteps) >= 25) {
            notifiedSteps = steps
            getSystemService(NotificationManager::class.java).notify(NOTIFICATION, notification(steps))
        }
    }
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private fun notification(steps: Int): Notification {
        val intent = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        return Notification.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_step_tracking)
            .setContentTitle("Stepsy step tracking")
            .setContentText("$steps steps today")
            .setContentIntent(intent).setOngoing(true).setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_SERVICE).build()
    }

    companion object {
        const val PREF_KEY = "flutter.stepsy_native_steps_v1"
        private const val CHANNEL = "stepsy_sensor_service"
        private const val NOTIFICATION = 9998
        var onSteps: ((Int) -> Unit)? = null
        var running = false

        fun start(context: Context): Boolean {
            if (Build.VERSION.SDK_INT >= 29 && context.checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) != PackageManager.PERMISSION_GRANTED) return false
            val manager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
            if (manager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER) == null) return false
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).edit()
                .putBoolean("stepsy_tracking_enabled", true).apply()
            context.startForegroundService(Intent(context, StepTrackingService::class.java))
            return true
        }

        fun stop(context: Context) {
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).edit()
                .putBoolean("stepsy_tracking_enabled", false).apply()
            context.stopService(Intent(context, StepTrackingService::class.java))
        }

        fun snapshot(context: Context): JSONObject {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            return try { JSONObject(prefs.getString(PREF_KEY, "{}") ?: "{}") } catch (_: Exception) { JSONObject() }
        }

        @Synchronized
        fun update(context: Context, action: (DailyStepCounter) -> Unit): JSONObject {
            val old = snapshot(context)
            val today = LocalDate.now().toString()
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val legacyDate = prefs.getString("flutter.ws_pedometer_baseline_date", "")
            val legacySteps = if (legacyDate == today) prefs.getLong("flutter.ws_pedometer_last_steps_today", 0).toInt() else 0
            val counter = DailyStepCounter(
                old.optString("date", today), old.optInt("steps", legacySteps),
                if (old.has("raw")) old.optInt("raw") else null,
                old.optInt("boot", -1), old.optLong("at", 0)
            )
            val history = old.optJSONObject("days") ?: JSONObject()
            if (counter.date.isNotEmpty()) history.put(counter.date, counter.steps)
            action(counter)
            history.put(counter.date, counter.steps)
            val cutoff = LocalDate.now().minusDays(7).toString()
            history.keys().asSequence().toList().filter { it < cutoff }.forEach { history.remove(it) }
            val result = JSONObject().put("date", counter.date).put("steps", counter.steps)
                .put("boot", counter.boot).put("at", counter.lastAt).put("days", history)
            counter.lastRaw?.let { result.put("raw", it) }
            prefs.edit().putString(PREF_KEY, result.toString()).apply()
            return result
        }
    }
}
