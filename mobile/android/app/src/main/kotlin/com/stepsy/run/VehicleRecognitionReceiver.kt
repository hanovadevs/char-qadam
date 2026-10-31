package com.stepsy.run

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.ActivityRecognitionResult

class VehicleRecognitionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        ActivityRecognitionResult.extractResult(intent)?.let { VehicleRecognition.record(context, it) }
    }
}
