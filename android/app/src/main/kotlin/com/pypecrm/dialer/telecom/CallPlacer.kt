package com.pypecrm.dialer.telecom

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import androidx.core.content.ContextCompat

/**
 * Wraps `TelecomManager.placeCall()` for outgoing calls — no
 * `PhoneAccountHandle` is registered by this app (see
 * `DialerInCallService`'s doc comment on why), so by default this routes
 * through whichever SIM/account the system considers default, same as any
 * other normal dialer app that isn't itself a `ConnectionService` provider.
 *
 * On a dual-SIM phone the dial pad shows one call button per SIM (see
 * [simAccounts]); passing that button's index here pins the call to that
 * SIM via `EXTRA_PHONE_ACCOUNT_HANDLE` instead of the system default.
 */
object CallPlacer {
    fun placeCall(context: Context, number: String, simIndex: Int? = null) {
        val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
        val extras = Bundle()
        val handle = simIndex?.let { callCapableAccounts(context).getOrNull(it) }
        if (handle != null) extras.putParcelable(TelecomManager.EXTRA_PHONE_ACCOUNT_HANDLE, handle)
        telecomManager.placeCall(Uri.fromParts("tel", number, null), extras)
    }

    /**
     * One entry per call-capable SIM, in the same order [placeCall]'s
     * `simIndex` refers to. Empty when READ_PHONE_STATE isn't granted yet
     * (the dial pad then falls back to a single "use default SIM" button).
     */
    fun simAccounts(context: Context): List<Map<String, Any>> {
        val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
        return callCapableAccounts(context).mapIndexed { index, handle ->
            val label = telecomManager.getPhoneAccount(handle)?.label?.toString()?.takeIf { it.isNotBlank() }
            mapOf("index" to index, "label" to (label ?: "SIM${index + 1}"))
        }
    }

    @SuppressLint("MissingPermission")
    private fun callCapableAccounts(context: Context): List<PhoneAccountHandle> {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_PHONE_STATE) != PackageManager.PERMISSION_GRANTED) {
            return emptyList()
        }
        val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
        return try {
            telecomManager.callCapablePhoneAccounts
        } catch (e: SecurityException) {
            emptyList()
        }
    }
}
