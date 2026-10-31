package com.stepsy.run

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Explicit, app-private notification control. A stop must survive UI/reboot. */
class StepTrackingControlReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == StepTrackingService.ACTION_STOP) {
            StepTrackingService.stop(context, userPaused = true)
        }
    }
}
