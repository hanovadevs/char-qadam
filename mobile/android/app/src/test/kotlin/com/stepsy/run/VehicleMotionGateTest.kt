package com.stepsy.run

import org.junit.Assert.*
import org.junit.Test

class VehicleMotionGateTest {
    @Test fun confidentVehicleAndBicycleBlockButUncertainMotionDoesNot() {
        val g = VehicleMotionGate()
        g.observe(40, 20, 30, 1000, 1000)
        assertFalse(g.blocks(1000))
        g.observe(90, 0, 5, 2000, 2000)
        assertTrue(g.blocks(2000))
        g.observe(0, 95, 5, 3000, 3000)
        assertEquals("ON_BICYCLE", g.mode)
        assertTrue(g.blocks(3000))
    }
    @Test fun WalkingClearsVehicleImmediatelyAndRunningIsNotSpeedCapped() {
        val g = VehicleMotionGate("IN_VEHICLE", 1000)
        g.observe(5, 5, 90, 2000, 2000)
        assertFalse(g.blocks(2000))
    }
    @Test fun staleFutureOrPreviousBootSignalsCannotFreezeWalking() {
        val g = VehicleMotionGate("IN_VEHICLE", 1000)
        assertFalse(g.blocks(122000))
        g.observe(90, 0, 0, 500, 122000)
        assertFalse(g.blocks(122000))
        g.observe(90, 0, 0, 123000, 122000)
        assertFalse(g.blocks(122000))
        g.observe(0, 0, 90, 100, 200)
        assertEquals("ON_FOOT", g.mode)
        assertFalse(g.blocks(200))
    }
    @Test fun rejectedRawStepsNeverReturnOnWalkingOrReopening() {
        val c = DailyStepCounter("2026-10-24", 100, 5000, 1, 1000)
        c.record(5200, "2026-10-24", 1, 2000, countMovement = false)
        val restored = DailyStepCounter(c.date, c.steps, c.lastRaw, c.boot, c.lastAt)
        assertEquals(101, restored.record(5201, "2026-10-24", 1, 3000))
    }
}
