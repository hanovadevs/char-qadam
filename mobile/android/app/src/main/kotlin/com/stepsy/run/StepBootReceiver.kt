package com.stepsy.run

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/** Resume only tracking the user previously enabled; logout disables this flag. */
class StepBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        val enabled = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getBoolean("stepsy_tracking_enabled", false)
        if (enabled) {
            try { StepTrackingService.start(context) }
            catch (e: Exception) { Log.w("Stepsy", "Tracking will resume when the app opens", e) }
        }
    }
}
