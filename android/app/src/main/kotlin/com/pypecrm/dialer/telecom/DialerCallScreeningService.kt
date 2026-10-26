package com.pypecrm.dialer.telecom

import android.telecom.Call
import android.telecom.CallScreeningService

/**
 * Exists so Android offers this app the "Caller ID & spam app"
 * (`RoleManager.ROLE_CALL_SCREENING`) role — the system only lists apps
 * that declare a `CallScreeningService`. Holding the role also lets caller-ID
 * style information be shown for incoming calls on phones that gate that
 * behind it.
 *
 * Deliberately a pass-through: it never blocks, silences, rejects or
 * rewrites a call — every incoming call gets the default response.
 */
class DialerCallScreeningService : CallScreeningService() {
    override fun onScreenCall(callDetails: Call.Details) {
        respondToCall(callDetails, CallResponse.Builder().build())
    }
}
