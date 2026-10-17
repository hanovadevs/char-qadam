package com.stepsy.run

import java.security.MessageDigest

object DeviceIdentity {
    fun fingerprint(androidId: String?): String? {
        val value = androidId?.lowercase() ?: return null
        if (!value.matches(Regex("[0-9a-f]{1,16}")) || value.all { it == '0' }) return null
        return MessageDigest.getInstance("SHA-256")
            .digest("stepsy:android:v1:$value".toByteArray(Charsets.UTF_8))
            .joinToString("") { (it.toInt() and 0xff).toString(16).padStart(2, '0') }
    }
}
