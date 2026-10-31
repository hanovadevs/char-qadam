package com.stepsy.run

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONObject
import java.security.MessageDigest
import java.time.ZonedDateTime
import java.util.concurrent.TimeUnit

object ReminderScheduler {
    private const val WORK = "stepsy-gentle-reminders"
    const val EXTRA_ROUTE = "stepsy_reminder_route"
    private const val PREFS = "stepsy_reminders"
    private const val TEST_ID = 7199
    private val routes = setOf("/steps", "/tracking-help", "/points", "/wallet")
    @Volatile var foreground = false
    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private fun channel(kind: ReminderPolicy.Kind) = when (kind) {
        ReminderPolicy.Kind.WALK -> "stepsy_walking_reminders"
        ReminderPolicy.Kind.TRACKING -> "stepsy_tracking_help"
        ReminderPolicy.Kind.RETURN -> "stepsy_return_reminders"
    }
    private fun id(kind: ReminderPolicy.Kind) = 7101 + kind.ordinal
    private fun settings(p: SharedPreferences) = ReminderPolicy.Settings(
        p.getBoolean("enabled", true), p.getBoolean("walking", true), p.getBoolean("tracking", true),
        p.getBoolean("returning", true), p.getInt("hour", 18), p.getInt("minute", 0))

    @Synchronized fun configure(context: Context, user: String?, customer: Boolean, data: Map<*, *>, goal: Int) {
        val p = prefs(context)
        val scope = user?.let { MessageDigest.getInstance("SHA-256").digest(it.toByteArray()).joinToString("") { b -> "%02x".format(b) } } ?: ""
        val changed = scope != p.getString("scope", "")
        val editor = p.edit().putString("scope", scope).putBoolean("active", customer && scope.isNotEmpty())
            .putString("summary_key", user?.let { "flutter.qadam_cache_${it}_activity_today" } ?: "")
            .putInt("goal", goal.coerceIn(1000, 50000))
        for (key in listOf("enabled", "walking", "tracking", "returning", "rewards")) editor.putBoolean(key, data[key] != false)
        editor.putBoolean("points", data["points"] == true)
        editor.putInt("hour", (data["hour"] as? Number)?.toInt()?.coerceIn(9, 20) ?: 18)
        editor.putInt("minute", (data["minute"] as? Number)?.toInt()?.coerceIn(0, 59) ?: 0)
        if (changed) {
            // Retain the device-wide daily cooldown across account replacement.
            editor.putLong("last_used", System.currentTimeMillis()).putInt("return_stage", 0)
                .putLong("paused_at", 0).putBoolean("paused_notified", false)
                .putLong("stopped_at", 0).putBoolean("stopped_notified", false)
            cancelVisible(context)
        }
        editor.commit()
        cancelVisible(context)
        if (customer && scope.isNotEmpty()) {
            if (foreground) markUsed(context)
            ensureScheduled(context)
        } else {
            WorkManager.getInstance(context).cancelUniqueWork(WORK)
            cancelVisible(context)
        }
    }

    @Synchronized fun markUsed(context: Context) {
        val p = prefs(context)
        if (!p.getBoolean("active", false)) return
        p.edit().putLong("last_used", System.currentTimeMillis()).putInt("return_stage", 0).commit()
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.cancel(id(ReminderPolicy.Kind.RETURN)); manager.cancel(id(ReminderPolicy.Kind.WALK))
    }
    fun ensureScheduled(context: Context) {
        val p = prefs(context)
        if (!p.getBoolean("active", false) || !settings(p).enabled) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK)
            cancelVisible(context)
            return
        }
        // Independent from step sync: Stop tracking must not cancel this help path.
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(WORK, ExistingPeriodicWorkPolicy.KEEP,
            PeriodicWorkRequestBuilder<ReminderWorker>(15, TimeUnit.MINUTES).build())
        createChannels(context)
    }
    @Synchronized fun trackingChanged(context: Context) {
        val p = prefs(context)
        if (!p.getBoolean("active", false)) return
        val e = p.edit()
        if (StepTrackingService.paused(context)) {
            if (p.getLong("paused_at", 0) == 0L) e.putLong("paused_at", System.currentTimeMillis()).putBoolean("paused_notified", false)
            e.putLong("stopped_at", 0).putBoolean("stopped_notified", false)
        } else if (StepTrackingService.running) {
            e.putLong("paused_at", 0).putBoolean("paused_notified", false)
                .putLong("stopped_at", 0).putBoolean("stopped_notified", false)
            context.getSystemService(NotificationManager::class.java).cancel(id(ReminderPolicy.Kind.TRACKING))
        } else if (StepTrackingService.enabled(context) && p.getLong("stopped_at", 0) == 0L) {
            e.putLong("stopped_at", System.currentTimeMillis())
        }
        e.commit()
    }

    @Synchronized fun evaluate(context: Context) {
        val p = prefs(context)
        if (!p.getBoolean("active", false)) return
        trackingChanged(context)
        val now = ZonedDateTime.now()
        val snapshot = StepTrackingService.snapshot(context)
        val cached = try {
            val raw = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).getString(p.getString("summary_key", "") ?: "", null)
            raw?.let { JSONObject(it) }
        } catch (_: Exception) { null }
        val state = ReminderPolicy.State(activeCustomer = true, foreground = foreground,
            lastUsed = p.getLong("last_used", 0), lastSent = p.getLong("last_sent", 0), lastSentDate = p.getString("sent_date", "") ?: "",
            paused = StepTrackingService.paused(context), pausedAt = p.getLong("paused_at", 0), pausedNotified = p.getBoolean("paused_notified", false),
            expected = StepTrackingService.enabled(context), running = StepTrackingService.running,
            stoppedAt = p.getLong("stopped_at", 0), stoppedNotified = p.getBoolean("stopped_notified", false),
            returnStage = p.getInt("return_stage", 0), goal = p.getInt("goal", 8000),
            inVehicle = VehicleRecognition.blocked(context),
            steps = ReminderPolicy.currentSteps(now.toLocalDate().toString(), snapshot.optString("date"),
                if (snapshot.has("steps")) snapshot.optInt("steps") else null, cached?.optString("local_date"),
                if (cached?.has("eligible_steps") == true) cached.optInt("eligible_steps") else null))
        val message = ReminderPolicy.decide(now, settings(p), state) ?: return
        if (!post(context, message, id(message.kind))) return
        val e = p.edit().putLong("last_sent", now.toInstant().toEpochMilli()).putString("sent_date", now.toLocalDate().toString())
        when (message.kind) {
            ReminderPolicy.Kind.RETURN -> e.putInt("return_stage", message.stage)
            ReminderPolicy.Kind.TRACKING -> if (message.intentionalPause) e.putBoolean("paused_notified", true) else e.putBoolean("stopped_notified", true)
            else -> Unit
        }
        e.commit()
    }

    private fun createChannels(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        for ((kind, name) in listOf(ReminderPolicy.Kind.WALK to "Gentle walking reminders", ReminderPolicy.Kind.TRACKING to "Tracking help", ReminderPolicy.Kind.RETURN to "Welcome-back reminders")) {
            manager.createNotificationChannel(NotificationChannel(channel(kind), name, NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "Optional Stepsy reminders; quiet between 9 pm and 9 am"
                lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            })
        }
    }
    private fun post(context: Context, message: ReminderPolicy.Message, notificationId: Int): Boolean {
        createChannels(context)
        val manager = context.getSystemService(NotificationManager::class.java)
        if (!manager.areNotificationsEnabled() || manager.getNotificationChannel(channel(message.kind))?.importance == NotificationManager.IMPORTANCE_NONE) return false
        val intent = Intent(context, MainActivity::class.java).putExtra(EXTRA_ROUTE, message.route)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val open = PendingIntent.getActivity(context, notificationId, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = Notification.Builder(context, channel(message.kind)).setSmallIcon(R.drawable.ic_step_tracking)
            .setColor(0xFF4F6A4D.toInt()).setContentTitle(message.title).setContentText(message.body)
            .setStyle(Notification.BigTextStyle().bigText(message.body)).setContentIntent(open).setAutoCancel(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE).setCategory(Notification.CATEGORY_REMINDER)
            .setPublicVersion(Notification.Builder(context, channel(message.kind)).setSmallIcon(R.drawable.ic_step_tracking)
                .setContentTitle("Stepsy").setContentText("A little reminder for you").build())
        if (message.kind == ReminderPolicy.Kind.TRACKING) notification.addAction(Notification.Action.Builder(null, "Tracking help", open).build())
        return try { manager.notify(notificationId, notification.build()); true } catch (_: SecurityException) { false }
    }
    @Synchronized fun preview(context: Context): Boolean {
        if (!prefs(context).getBoolean("active", false)) return false
        return post(context, ReminderPolicy.Message(ReminderPolicy.Kind.TRACKING, "Your Stepsy reminders are ready",
            "This is a test reminder. Tap to open the tracking guide.", "/tracking-help"), TEST_ID)
    }
    @Synchronized fun eventAllowed(context: Context, category: String): Boolean {
        val p = prefs(context)
        return p.getBoolean("active", false) && p.getBoolean("enabled", true) && !foreground &&
            p.getBoolean(category, category == "rewards")
    }
    fun validRoute(route: String?) = route?.takeIf { it in routes }
    private fun cancelVisible(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        for (kind in ReminderPolicy.Kind.entries) manager.cancel(id(kind))
        manager.cancel(TEST_ID)
    }
}

class ReminderWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result = try { ReminderScheduler.evaluate(applicationContext); Result.success() }
        catch (_: Exception) { Result.retry() }
}
