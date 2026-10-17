package com.stepsy.run

import org.junit.Assert.assertEquals
import org.junit.Test

class DailyStepCounterTest {
    private val day = "2026-10-17"
    @Test fun firstSampleDoesNotClaimStepsSinceBoot() {
        val c = DailyStepCounter()
        assertEquals(0, c.record(50000, day, 1, 1000))
        assertEquals(100, c.record(50100, day, 1, 2000))
    }
    @Test fun rebootPreservesStepsAndAddsNewBootSteps() {
        val c = DailyStepCounter(day, 6000, 51000, 1, 1000)
        assertEquals(6030, c.record(30, day, 2, 2000))
        assertEquals(6080, c.record(80, day, 2, 3000))
    }
    @Test fun detectsRebootEvenIfRawCounterHasCaughtUp() {
        val c = DailyStepCounter(day, 100, 200, 1, 1000)
        assertEquals(400, c.record(300, day, 2, 2000))
    }
    @Test fun staleAndDuplicateEventsDoNotAddSteps() {
        val c = DailyStepCounter(day, 100, 5000, 1, 1000)
        assertEquals(100, c.record(5000, day, 1, 1000))
        assertEquals(100, c.record(4000, day, 1, 999))
    }
    @Test fun midnightResetsTotalAndLongGapsDoNotClaimYesterday() {
        val c = DailyStepCounter(day, 6000, 51000, 1, 1000)
        assertEquals(1, c.record(51001, "2026-10-18", 1, 2000))
        assertEquals(0, c.record(70000, "2026-10-19", 1, 90000000))
    }
    @Test fun overlappingHealthSourcesNeverSumOrDecrease() {
        val c = DailyStepCounter(day, 100, 5000, 1, 1000)
        c.mergeHealth(3000, day)
        assertEquals(3001, c.record(5001, day, 1, 2000))
        c.mergeHealth(2000, day)
        assertEquals(3001, c.steps)
    }
    @Test fun asyncHealthReadPreservesOnlySubsequentSensorSteps() {
        val c = DailyStepCounter(day, 110, 5010, 1, 2000)
        c.mergeHealth(3000, day, 5000, 1)
        assertEquals(3010, c.steps)
        c.mergeHealth(3000, day, 5000, 1)
        assertEquals(3010, c.steps)
    }
}
