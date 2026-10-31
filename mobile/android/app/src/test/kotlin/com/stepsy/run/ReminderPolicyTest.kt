package com.stepsy.run

import org.junit.Assert.*
import org.junit.Test
import java.time.ZonedDateTime

class ReminderPolicyTest {
    private val now = ZonedDateTime.parse("2026-10-31T18:00:00+05:00[Asia/Karachi]")
    private val at = now.toInstant().toEpochMilli()
    private val settings = ReminderPolicy.Settings()
    private fun state() = ReminderPolicy.State(true, false, at - 2 * 3_600_000L, running = true, steps = 1000)
    @Test fun `quiet hours master switch foreground and customer role gate all reminders`() {
        val dueHelp = state().copy(lastUsed = at - 2 * ReminderPolicy.DAY, running = false,
            paused = true, pausedAt = at - 2 * ReminderPolicy.DAY)
        for (hour in listOf(0, 8, 21, 23)) assertNull(ReminderPolicy.decide(now.withHour(hour), settings, dueHelp))
        assertEquals(ReminderPolicy.Kind.TRACKING, ReminderPolicy.decide(now.withHour(9), settings, dueHelp)?.kind)
        assertNull(ReminderPolicy.decide(now, settings.copy(enabled = false), state()))
        assertNull(ReminderPolicy.decide(now, settings, state().copy(activeCustomer = false)))
        assertNull(ReminderPolicy.decide(now, settings, state().copy(foreground = true)))
        assertNull(ReminderPolicy.decide(now, settings, state().copy(inVehicle = true)))
        assertNull(ReminderPolicy.decide(now, settings, state().copy(lastUsed = at - 60_000)))
    }
    @Test fun `motivation uses personal goal suppresses completed days and stale totals stay generic`() {
        assertEquals(ReminderPolicy.Kind.WALK, ReminderPolicy.decide(now, settings, state())?.kind)
        assertNull(ReminderPolicy.decide(now.minusMinutes(1), settings, state()))
        assertNull(ReminderPolicy.decide(now, settings.copy(walking = false), state()))
        assertNull(ReminderPolicy.decide(now, settings, state().copy(steps = 8000)))
        val near = ReminderPolicy.decide(now, settings, state().copy(steps = 7600))!!
        assertTrue(near.body.contains("400 steps"))
        val unknown = ReminderPolicy.decide(now, settings, state().copy(steps = null))!!
        assertFalse(unknown.body.contains("8000"))
    }
    @Test fun `daily cooldown survives clock changes and same local date`() {
        assertNull(ReminderPolicy.decide(now, settings, state().copy(lastSentDate = "2026-10-31")))
        assertNull(ReminderPolicy.decide(now, settings, state().copy(lastSent = at - 19 * 3_600_000L)))
        assertNull(ReminderPolicy.decide(now, settings, state().copy(lastSent = at + 1)))
        assertNull(ReminderPolicy.decide(now, settings, state().copy(lastUsed = at + 1)))
    }
    @Test fun `intentional stop gets one optional reminder after 24 hours and never a walking nudge`() {
        val paused = state().copy(paused = true, running = false, pausedAt = at - ReminderPolicy.DAY)
        val message = ReminderPolicy.decide(now, settings, paused)!!
        assertEquals(ReminderPolicy.Kind.TRACKING, message.kind)
        assertTrue(message.intentionalPause)
        assertEquals("/tracking-help", message.route)
        assertNull(ReminderPolicy.decide(now, settings, paused.copy(pausedAt = at - ReminderPolicy.DAY + 1)))
        assertNull(ReminderPolicy.decide(now, settings, paused.copy(pausedNotified = true)))
        assertNull(ReminderPolicy.decide(now, settings.copy(tracking = false), paused))
    }
    @Test fun `unexpected stop requires a real missing service grace period and one incident`() {
        val stopped = state().copy(expected = true, running = false, stoppedAt = at - 15 * 60_000L)
        assertEquals(ReminderPolicy.Kind.TRACKING, ReminderPolicy.decide(now, settings, stopped)?.kind)
        assertNull(ReminderPolicy.decide(now, settings, stopped.copy(stoppedAt = at - 14 * 60_000L)))
        assertNull(ReminderPolicy.decide(now, settings, stopped.copy(stoppedNotified = true)))
        assertNull(ReminderPolicy.decide(now, settings, stopped.copy(expected = false)))
        // An idle phone still has a running sensor service; no movement is not an interruption.
        assertEquals(ReminderPolicy.Kind.WALK, ReminderPolicy.decide(now, settings, stopped.copy(running = true))?.kind)
    }
    @Test fun `return stages are sent once after three and seven days with no later stream`() {
        val away = state().copy(lastUsed = at - 3 * ReminderPolicy.DAY)
        assertEquals(3, ReminderPolicy.decide(now, settings, away)?.stage)
        assertNull(ReminderPolicy.decide(now, settings, away.copy(returnStage = 3)))
        val week = away.copy(lastUsed = at - 7 * ReminderPolicy.DAY, returnStage = 3)
        assertEquals(7, ReminderPolicy.decide(now, settings, week)?.stage)
        assertNull(ReminderPolicy.decide(now, settings, week.copy(returnStage = 7)))
        assertNull(ReminderPolicy.decide(now, settings.copy(returning = false), away))
        assertEquals(7, ReminderPolicy.decide(now, settings, week.copy(returnStage = 0))?.stage)
    }
    @Test fun `daily progress takes the larger current-day snapshot and ignores other days`() {
        assertEquals(8100, ReminderPolicy.currentSteps("2026-10-31", "2026-10-31", 39, "2026-10-31", 8100))
        assertEquals(39, ReminderPolicy.currentSteps("2026-10-31", "2026-10-31", 39, "2026-10-30", 8100))
        assertNull(ReminderPolicy.currentSteps("2026-10-31", "2026-10-30", 5000, "2026-10-30", 8100))
    }
}
