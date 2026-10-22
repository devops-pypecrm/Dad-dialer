package com.pypecrm.dialer.telecom

import android.content.Context
import android.net.Uri
import android.telecom.TelecomManager

/**
 * Wraps `TelecomManager.placeCall()` for outgoing calls — no
 * `PhoneAccountHandle` is registered by this app (see
 * `DialerInCallService`'s doc comment on why), so this routes through
 * whichever SIM/account the system considers default, same as any other
 * normal dialer app that isn't itself a `ConnectionService` provider.
 */
object CallPlacer {
    fun placeCall(context: Context, number: String) {
        val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
        telecomManager.placeCall(Uri.fromParts("tel", number, null), null)
    }
}
