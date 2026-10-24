package com.stepsy.run

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.ActivityRecognitionResult
import com.google.android.gms.location.DetectedActivity
import java.time.LocalDate

object VehicleRecognition {
    private fun prefs(context: Context) = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    private fun callback(context: Context): PendingIntent = PendingIntent.getBroadcast(context, 2,
        Intent(context, VehicleRecognitionReceiver::class.java).setAction("com.stepsy.run.MOTION_ACTIVITY"),
        PendingIntent.FLAG_UPDATE_CURRENT or if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0)
    private fun gate(context: Context) = VehicleMotionGate(
        prefs(context).getString("stepsy_motion_mode", "UNKNOWN") ?: "UNKNOWN",
        prefs(context).getLong("stepsy_motion_at", -1))
    fun blocked(context: Context): Boolean = gate(context).blocks(SystemClock.elapsedRealtime())
    fun state(context: Context): String = prefs(context).getString("stepsy_motion_status", "STARTING") ?: "STARTING"
    fun start(context: Context) {
        prefs(context).edit().putString("stepsy_motion_status", "STARTING").apply()
        try {
            ActivityRecognition.getClient(context).requestActivityUpdates(5_000, callback(context))
                .addOnSuccessListener {
                    if (!StepTrackingService.enabled(context) || StepTrackingService.paused(context)) { stop(context); return@addOnSuccessListener }
                    prefs(context).edit().putString("stepsy_motion_status", "ACTIVE").apply()
                    StepTrackingService.publishState(context)
                }.addOnFailureListener {
                    prefs(context).edit().putString("stepsy_motion_status", "UNAVAILABLE").apply()
                    StepTrackingService.publishState(context)
                }
        } catch (_: Exception) {
            prefs(context).edit().putString("stepsy_motion_status", "UNAVAILABLE").apply()
            StepTrackingService.publishState(context)
        }
    }
    fun stop(context: Context) {
        try { ActivityRecognition.getClient(context).removeActivityUpdates(callback(context)) } catch (_: Exception) { }
        prefs(context).edit().putString("stepsy_motion_status", "STOPPED").apply()
    }
    fun resetOnResume(context: Context) { prefs(context).edit().remove("stepsy_motion_mode").remove("stepsy_motion_at").apply() }
    fun record(context: Context, result: ActivityRecognitionResult) {
        if (!StepTrackingService.enabled(context) || StepTrackingService.paused(context)) return
        val gate = gate(context)
        val previous = gate.mode
        gate.observe(result.getActivityConfidence(DetectedActivity.IN_VEHICLE),
            result.getActivityConfidence(DetectedActivity.ON_BICYCLE),
            maxOf(result.getActivityConfidence(DetectedActivity.ON_FOOT), result.getActivityConfidence(DetectedActivity.WALKING), result.getActivityConfidence(DetectedActivity.RUNNING)),
            result.elapsedRealtimeMillis, SystemClock.elapsedRealtime())
        val editor = prefs(context).edit().putString("stepsy_motion_mode", gate.mode).putLong("stepsy_motion_at", gate.observedAt)
        // Never re-import rejected vehicle deltas from another app's daily total.
        if (gate.blocks(SystemClock.elapsedRealtime())) editor.putString(StepTrackingService.HEALTH_EXCLUDED_KEY, LocalDate.now().toString())
        editor.apply()
        if (previous != gate.mode) StepTrackingService.publishState(context)
    }
}
