package com.stepsy.run

/** Confidence-gated, expiring motion context. No GPS or speed estimates. */
class VehicleMotionGate(var mode: String = "UNKNOWN", var observedAt: Long = -1) {
    fun observe(vehicle: Int, bicycle: Int, onFoot: Int, at: Long, now: Long) {
        if (observedAt > now) { mode = "UNKNOWN"; observedAt = -1 }
        if (at < 0 || at > now || at < observedAt) return
        if (onFoot >= 60 && onFoot >= maxOf(vehicle, bicycle)) {
            mode = "ON_FOOT"
            observedAt = at
        } else if (maxOf(vehicle, bicycle) >= 75 && onFoot < 50) {
            mode = if (bicycle > vehicle) "ON_BICYCLE" else "IN_VEHICLE"
            observedAt = at
        }
    }
    fun blocks(now: Long): Boolean = mode in listOf("IN_VEHICLE", "ON_BICYCLE") &&
        observedAt >= 0 && now >= observedAt && now - observedAt <= 120_000
}
