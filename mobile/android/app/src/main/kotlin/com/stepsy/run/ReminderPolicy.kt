package com.stepsy.run

import java.time.ZonedDateTime

/** Pure decisions; no network, sensor changes or automatic tracking restarts. */
object ReminderPolicy {
    enum class Kind { WALK, TRACKING, RETURN }
    data class Settings(
        val enabled: Boolean = true, val walking: Boolean = true,
        val tracking: Boolean = true, val returning: Boolean = true,
        val hour: Int = 18, val minute: Int = 0,
    )
    data class State(
        val activeCustomer: Boolean, val foreground: Boolean,
        val lastUsed: Long, val lastSent: Long = 0, val lastSentDate: String = "",
        val paused: Boolean = false, val pausedAt: Long = 0, val pausedNotified: Boolean = false,
        val expected: Boolean = false, val running: Boolean = false,
        val stoppedAt: Long = 0, val stoppedNotified: Boolean = false,
        val returnStage: Int = 0, val steps: Int? = null, val goal: Int = 8000,
        val inVehicle: Boolean = false,
    )
    data class Message(val kind: Kind, val title: String, val body: String, val route: String,
        val stage: Int = 0, val intentionalPause: Boolean = false)
    const val DAY = 86_400_000L
    fun currentSteps(today: String, nativeDate: String?, nativeSteps: Int?, cachedDate: String?, cachedSteps: Int?): Int? =
        listOfNotNull(nativeSteps?.takeIf { nativeDate == today }, cachedSteps?.takeIf { cachedDate == today })
            .maxOrNull()?.coerceAtLeast(0)

    fun decide(now: ZonedDateTime, settings: Settings, state: State): Message? {
        val at = now.toInstant().toEpochMilli()
        if (!settings.enabled || !state.activeCustomer || state.foreground || state.inVehicle || state.lastUsed <= 0) return null
        if (now.hour < 9 || now.hour >= 21) return null
        if (state.lastSentDate == now.toLocalDate().toString() ||
            (state.lastSent > 0 && at - state.lastSent < 20 * 3_600_000L)) return null
        // A changed device clock must not generate negative-age reminders.
        if (at < state.lastUsed) return null
        if (at - state.lastUsed < 30 * 60_000L) return null
        if (settings.tracking && state.paused && state.pausedAt > 0 &&
            at - state.pausedAt >= DAY && !state.pausedNotified) {
            return Message(Kind.TRACKING, "Ready whenever you are",
                "Tracking is paused. Your saved progress is here. Open the guide when you want to count again.",
                "/tracking-help", intentionalPause = true)
        }
        if (settings.tracking && !state.paused && state.expected && !state.running &&
            state.stoppedAt > 0 && at - state.stoppedAt >= 15 * 60_000L && !state.stoppedNotified) {
            return Message(Kind.TRACKING, "Let’s get your steps counting",
                "Tracking isn’t running. Tap for help with activity access, background settings and restarting.",
                "/tracking-help")
        }
        val days = (at - state.lastUsed) / DAY
        if (settings.returning) {
            val stage = if (days >= 7) 7 else if (days >= 3) 3 else 0
            if (stage > state.returnStage) return Message(Kind.RETURN,
                if (stage == 7) "Your pace. A fresh start." else "A little hello from Stepsy",
                if (stage == 7) "Come back whenever you’re ready. A small walk can be a lovely place to begin."
                else "Your walking companion is here. Open Stepsy for your next little step.", "/steps", stage)
        }
        if (!settings.walking || days >= 3 || state.paused || !state.running) return null
        if (now.hour * 60 + now.minute < settings.hour * 60 + settings.minute) return null
        val goal = state.goal.coerceIn(1000, 50000)
        if (state.steps != null && state.steps >= goal) return null
        val remaining = state.steps?.let { goal - it }
        val near = remaining != null && remaining in 1..(goal / 5)
        val copy = listOf(
            "A little movement, at your pace. If it feels good, enjoy a gentle walk.",
            "A few small steps can brighten a busy day. Take a walking break when it suits you.",
            "No rush, no perfect pace. Your next little walk is yours to enjoy.",
            "Your companion is ready for a little wander. Move at a pace that feels comfortable.",
        )
        return Message(Kind.WALK, if (near) "A little closer to your goal" else "A little walk, just for you",
            if (near) "$remaining steps to the goal you chose. A gentle stroll counts, if you’re up for it."
            else copy[Math.floorMod(now.toLocalDate().toEpochDay(), copy.size.toLong()).toInt()], "/steps")
    }
}
