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
import android.os.PowerManager
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import org.json.JSONObject
import java.time.LocalDate
import java.time.Instant
import java.time.ZoneId
import androidx.work.WorkManager

/** Owns the sensor independently of Flutter's UI isolate, including when locked. */
class StepTrackingService : Service(), SensorEventListener {
    private lateinit var sensors: SensorManager
    private var notifiedSteps = -1
    private var wakeLock: PowerManager.WakeLock? = null
    private var registered = false
    private var wakeUpSensor = false
    private var lastVehicleBlocked = false
    private val handler = Handler(Looper.getMainLooper())
    private val renewWakeLock = object : Runnable {
        override fun run() {
            if (running && enabled(this@StepTrackingService) && !paused(this@StepTrackingService)) {
                wakeLock?.acquire(10 * 60_000L)
                handler.postDelayed(this, 5 * 60_000L)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel(CHANNEL, "Step tracking", NotificationManager.IMPORTANCE_LOW))
        val notification = notification(snapshot(this).optInt("steps"))
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIFICATION, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH)
        } else {
            startForeground(NOTIFICATION, notification)
        }
        sensors = getSystemService(Context.SENSOR_SERVICE) as SensorManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!enabled(this) || paused(this)) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }
        if (!registered) {
            val sensor = sensors.getDefaultSensor(Sensor.TYPE_STEP_COUNTER, true)
                ?: sensors.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
            registered = sensor != null && sensors.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL, 0)
            if (!registered) {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            wakeUpSensor = sensor!!.isWakeUpSensor
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            if (prefs.getBoolean("stepsy_wakeup_counter", false) != wakeUpSensor) {
                // Variants need not share the same raw counter origin.
                update(this) { it.pause() }
                prefs.edit().putBoolean("stepsy_wakeup_counter", wakeUpSensor).commit()
            }
            running = true
            VehicleRecognition.start(this)
            if (!wakeUpSensor) {
                wakeLock = (getSystemService(Context.POWER_SERVICE) as PowerManager)
                    .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Stepsy:StepTracking")
                    .apply { setReferenceCounted(false) }
                renewWakeLock.run()
            }
        }
        publishState(this)
        ReminderScheduler.trackingChanged(this)
        return START_STICKY
    }
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onDestroy() {
        running = false
        handler.removeCallbacksAndMessages(null)
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        if (::sensors.isInitialized) sensors.unregisterListener(this)
        registered = false
        VehicleRecognition.stop(this)
        publishState(this)
        ReminderScheduler.trackingChanged(this)
        super.onDestroy()
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (!enabled(this) || paused(this)) return
        val vehicleBlocked = VehicleRecognition.blocked(this)
        if (vehicleBlocked != lastVehicleBlocked) {
            lastVehicleBlocked = vehicleBlocked
            publishState(this)
        }
        // Use the sensor event's timestamp: batched callbacks may arrive later.
        val at = System.currentTimeMillis() - (SystemClock.elapsedRealtimeNanos() - event.timestamp) / 1_000_000
        val day = Instant.ofEpochMilli(at).atZone(ZoneId.systemDefault()).toLocalDate().toString()
        val result = update(this) { counter ->
            counter.record(event.values[0].toInt(), day,
                Settings.Global.getInt(contentResolver, Settings.Global.BOOT_COUNT, 0), at,
                countMovement = !vehicleBlocked)
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
        val stop = PendingIntent.getBroadcast(this, 1,
            Intent(this, StepTrackingControlReceiver::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        return Notification.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_step_tracking)
            .setContentTitle("Stepsy step tracking")
            .setContentText("$steps steps today")
            .setContentIntent(intent).setOngoing(true).setOnlyAlertOnce(true)
            .addAction(Notification.Action.Builder(null, "Stop tracking", stop).build())
            .setCategory(Notification.CATEGORY_SERVICE).build()
    }

    companion object {
        const val PREF_KEY = "flutter.stepsy_native_steps_v1"
        const val PAUSED_KEY = "flutter.stepsy_tracking_paused"
        const val HEALTH_EXCLUDED_KEY = "flutter.stepsy_health_excluded_date"
        const val ACTION_STOP = "com.stepsy.run.STOP_TRACKING"
        private const val CHANNEL = "stepsy_sensor_service"
        private const val NOTIFICATION = 9998
        var onSteps: ((Int) -> Unit)? = null
        var running = false
        var onStateChanged: ((String) -> Unit)? = null

        fun enabled(context: Context) = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getBoolean("stepsy_tracking_enabled", false)
        fun paused(context: Context) = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getBoolean(PAUSED_KEY, false)
        fun healthAllowed(context: Context) = !paused(context) && context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString(HEALTH_EXCLUDED_KEY, "") != LocalDate.now().toString()
        fun status(context: Context): JSONObject {
            val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            return JSONObject().put("paused", paused(context)).put("running", running)
                .put("enabled", enabled(context)).put("unrestricted", power.isIgnoringBatteryOptimizations(context.packageName))
                .put("health_allowed", healthAllowed(context))
                .put("vehicle_filter", VehicleRecognition.state(context))
                .put("vehicle_blocked", VehicleRecognition.blocked(context))
                .put("wake_up_sensor", context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    .getBoolean("stepsy_wakeup_counter", false))
        }
        fun publishState(context: Context) { onStateChanged?.invoke(status(context).toString()) }

        fun start(context: Context, resume: Boolean = false): Boolean {
            if (paused(context) && !resume) return false
            if (Build.VERSION.SDK_INT >= 29 && context.checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) != PackageManager.PERMISSION_GRANTED) return false
            val manager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
            if (manager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER, true) == null && manager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER) == null) return false
            val wasPaused = paused(context)
            if (wasPaused) VehicleRecognition.resetOnResume(context)
            val editor = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).edit()
                .putBoolean("stepsy_tracking_enabled", true).putBoolean(PAUSED_KEY, false)
            if (wasPaused) editor.putString(HEALTH_EXCLUDED_KEY, LocalDate.now().toString())
            editor.commit()
            ReminderScheduler.trackingChanged(context)
            context.startForegroundService(Intent(context, StepTrackingService::class.java))
            return true
        }

        fun stop(context: Context, userPaused: Boolean = false) {
            val editor = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).edit()
                .putBoolean("stepsy_tracking_enabled", false).putBoolean(PAUSED_KEY, userPaused)
            if (userPaused) editor.putString(HEALTH_EXCLUDED_KEY, LocalDate.now().toString())
            editor.commit()
            ReminderScheduler.trackingChanged(context)
            if (userPaused) update(context) { it.pause() }
            VehicleRecognition.stop(context)
            try { WorkManager.getInstance(context).cancelUniqueWork("stepsy-periodic-step-sync") }
            catch (e: IllegalStateException) { android.util.Log.w("Stepsy", "Background sync cancellation unavailable; pause gate remains active", e) }
            context.stopService(Intent(context, StepTrackingService::class.java))
            context.getSystemService(NotificationManager::class.java).cancel(NOTIFICATION)
            publishState(context)
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
