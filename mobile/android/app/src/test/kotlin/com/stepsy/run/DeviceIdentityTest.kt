package com.stepsy.run

import org.junit.Assert.*
import org.junit.Test

class DeviceIdentityTest {
    @Test fun stableAcrossSessionsAndCase() {
        val id = DeviceIdentity.fingerprint("0123456789abcdef")!!
        assertEquals(64, id.length)
        assertEquals(id, DeviceIdentity.fingerprint("0123456789ABCDEF"))
        assertNotEquals("0123456789abcdef", id)
    }
    @Test fun differentAndroidIdsStaySeparate() {
        assertNotEquals(DeviceIdentity.fingerprint("1234"), DeviceIdentity.fingerprint("5678"))
    }
    @Test fun missingOrInvalidIdentityFailsClosed() {
        for (id in listOf(null, "", "0000000000000000", "not-an-id", "12345678901234567")) {
            assertNull(DeviceIdentity.fingerprint(id))
        }
    }
}
