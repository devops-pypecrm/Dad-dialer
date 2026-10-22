package com.pypecrm.dialer.util

/**
 * Ported from Dad-call-recorder's `call_recording_engine/util/PhoneNumberUtils.kt`
 * (a separate repo, referenced for its proven shape only — not shared code).
 */
object PhoneNumberUtils {
    /** Last 10 digits of [raw], stripped of everything non-numeric — matches
     * Dad-backend's own phone-matching convention (see androidController.ts's
     * `last10` normalization), so a comparison against a filename or another
     * number always uses the same convention as the server. */
    fun last10Digits(raw: String?): String {
        if (raw.isNullOrBlank()) return ""
        val digitsOnly = raw.filter { it.isDigit() }
        return if (digitsOnly.length > 10) digitsOnly.takeLast(10) else digitsOnly
    }
}
