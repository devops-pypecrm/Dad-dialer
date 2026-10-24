package com.pypecrm.dialer.data

import android.content.Context
import android.util.Log
import com.pypecrm.dialer.net.BackendApi

/**
 * Caches Dad-backend's per-org CallSettings (autoRecordInbound/
 * autoRecordOutbound) so a Tier 0 recording is never uploaded for a
 * direction the org hasn't consented to — the same consent-law
 * non-negotiable Dad-call-recorder's `call_recording_engine`
 * `data/CallSettingsCache.kt` enforces (a separate repo, referenced for its
 * proven shape only — not shared code). CallSettings defaults recording OFF
 * for new orgs; that's a legal call for org admins, not something this app
 * should second-guess by uploading anyway.
 */
class CallSettingsCache(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun isDirectionAllowed(isOutgoing: Boolean): Boolean {
        val key = if (isOutgoing) KEY_AUTO_OUTBOUND else KEY_AUTO_INBOUND
        // Fail-open (true) only when we've never successfully fetched
        // settings at all — once a real fetch succeeds this reflects the
        // org's actual (default-false-for-new-orgs) setting.
        return prefs.getBoolean(key, true)
    }

    /** Server-number/conference-bridge cloud recording — see
     * Dad-dialer/CALL_RECORDING_SERVER_METHOD_PLAN.md. Unlike
     * [isDirectionAllowed] this fails CLOSED (false) when never fetched —
     * an unvalidated, per-minute-cost telephony call must never fire just
     * because settings haven't loaded yet. */
    fun cloudRecordingBridgeNumberOrNull(): String? {
        if (!prefs.getBoolean(KEY_CLOUD_RECORDING_ENABLED, false)) return null
        return prefs.getString(KEY_CLOUD_RECORDING_BRIDGE_NUMBER, null)?.takeIf { it.isNotBlank() }
    }

    /** Every bridge number this device has ever dialed — the call-log
     * backfill ([com.pypecrm.dialer.sync.CallLogReconciler]) uses it to skip
     * the bridge leg itself, which must never become a CRM call record. */
    fun rememberBridgeNumber(number: String) {
        val known = prefs.getStringSet(KEY_KNOWN_BRIDGE_NUMBERS, emptySet()).orEmpty().toMutableSet()
        if (known.add(last10(number))) prefs.edit().putStringSet(KEY_KNOWN_BRIDGE_NUMBERS, known).apply()
    }

    fun isBridgeNumber(number: String): Boolean {
        val current = prefs.getString(KEY_CLOUD_RECORDING_BRIDGE_NUMBER, null)?.let(::last10)
        val known = prefs.getStringSet(KEY_KNOWN_BRIDGE_NUMBERS, emptySet()).orEmpty()
        val n = last10(number)
        return n.length >= 6 && (n == current || n in known)
    }

    private fun last10(raw: String) = raw.filter { it.isDigit() }.takeLast(10)

    /** Raw status for UI display (the in-call "Recording" indicator) —
     * unlike [isDirectionAllowed], this never fails open/closed; it just
     * reports whether a real fetch has ever landed, so the UI can show
     * "checking…" instead of guessing at an org's actual setting. */
    fun statusForDisplay(): Map<String, Boolean> = mapOf(
        "hasFetched" to (prefs.getLong(KEY_FETCHED_AT, 0L) > 0L),
        "autoRecordInbound" to prefs.getBoolean(KEY_AUTO_INBOUND, false),
        "autoRecordOutbound" to prefs.getBoolean(KEY_AUTO_OUTBOUND, false),
    )

    fun isStale(): Boolean =
        System.currentTimeMillis() - prefs.getLong(KEY_FETCHED_AT, 0L) > TTL_MILLIS

    /** Best-effort synchronous refresh — call from a background thread only. */
    fun refreshIfStale(api: BackendApi) {
        if (!isStale()) return
        try {
            val settings = api.fetchCallSettings() ?: return
            prefs.edit()
                .putBoolean(KEY_AUTO_INBOUND, settings.autoRecordInbound)
                .putBoolean(KEY_AUTO_OUTBOUND, settings.autoRecordOutbound)
                .putBoolean(KEY_CLOUD_RECORDING_ENABLED, settings.cloudRecordingEnabled)
                .putString(KEY_CLOUD_RECORDING_BRIDGE_NUMBER, settings.cloudRecordingBridgeNumber)
                .putLong(KEY_FETCHED_AT, System.currentTimeMillis())
                .apply()
        } catch (e: Exception) {
            Log.w(TAG, "CallSettings refresh failed, keeping cached/default values", e)
        }
    }

    companion object {
        private const val TAG = "CallSettingsCache"
        private const val PREFS_NAME = "dialer_call_settings"
        private const val KEY_AUTO_INBOUND = "auto_record_inbound"
        private const val KEY_AUTO_OUTBOUND = "auto_record_outbound"
        private const val KEY_CLOUD_RECORDING_ENABLED = "cloud_recording_enabled"
        private const val KEY_CLOUD_RECORDING_BRIDGE_NUMBER = "cloud_recording_bridge_number"
        private const val KEY_KNOWN_BRIDGE_NUMBERS = "known_bridge_numbers"
        private const val KEY_FETCHED_AT = "fetched_at"
        private const val TTL_MILLIS = 15 * 60 * 1000L
    }
}
