package com.stepsy.run

/** Counts sensor deltas, preserving today's total across process/device restarts. */
class DailyStepCounter(
    var date: String = "",
    var steps: Int = 0,
    var lastRaw: Int? = null,
    var boot: Int = -1,
    var lastAt: Long = 0,
) {
    fun record(raw: Int, day: String, bootCount: Int, at: Long): Int {
        if (raw < 0 || (boot == bootCount && at < lastAt)) return steps
        val previous = lastRaw
        val sameDay = date == day
        val rebooted = boot != -1 && boot != bootCount
        // Do not attribute an unknown multi-day gap to today's steps.
        val nearMidnight = at >= lastAt && at - lastAt <= 120_000
        if (!sameDay) steps = 0
        if (previous != null && (sameDay || nearMidnight)) {
            val delta = if (rebooted || raw < previous) raw else raw - previous
            steps += delta.coerceAtLeast(0)
        }
        date = day
        lastRaw = raw
        boot = bootCount
        lastAt = at
        return steps
    }

    fun mergeHealth(total: Int, day: String, rawAtRead: Int? = null, bootAtRead: Int = boot) {
        if (date != day) {
            date = day
            steps = 0
            lastRaw = null
        }
        // Sources overlap. Summing them double-counts the same walk.
        // Health was queried only up to the sensor sample captured before the
        // async read. Preserve later sensor deltas without counting them twice.
        val afterRead = if (rawAtRead != null && lastRaw != null && boot == bootAtRead && lastRaw!! >= rawAtRead)
            lastRaw!! - rawAtRead else 0
        steps = maxOf(steps, total + afterRead)
    }
}
