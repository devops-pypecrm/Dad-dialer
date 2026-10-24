package com.pypecrm.dialer.telecom

import android.content.Context
import android.telecom.Call
import com.pypecrm.dialer.debug.EngineDebugLog

/**
 * Server-number/conference-bridge call recording — see
 * `Dad-dialer/CALL_RECORDING_SERVER_METHOD_PLAN.md`. Two entry points into
 * the same mechanism:
 *  - [startManualTest] — the debug-only diagnostic (Settings / in-call
 *    "Merge test" button), any number, logged under `MERGE_SPIKE_*`.
 *  - [startAuto] — the real production path, called from
 *    [CallEventBridge] when a call goes `ACTIVE` and the org has cloud
 *    recording enabled with a configured bridge number, logged under
 *    `CLOUD_BRIDGE_*`.
 * Both place a second, silent call to a bridge number and attempt
 * `Call.conference()` once it answers — whether the carrier actually
 * merges the audio is still unconfirmed on real devices as of this write
 * (that confirmation IS the manual test's purpose), so [startAuto] should
 * stay behind its org-level toggle (default off) until that's validated.
 *
 * Deliberately does not touch [CallEventBridge]'s single-tracked-call
 * model by itself — [CallEventBridge] asks [shouldIgnoreForPrimaryTracking]
 * before tracking any newly-added call, so the bridge leg (and the
 * conference Call the framework creates if a merge succeeds) never
 * overwrites the real call's tracked state, mute/speaker/end controls, or
 * sync bookkeeping.
 */
object CloudRecordingBridge {
    private var debugLog: EngineDebugLog? = null
    private var primaryCall: Call? = null
    private var bridgeCall: Call? = null
    private var mergeAttempted = false
    private var logPrefix = "MERGE_SPIKE"

    private val bridgeCallCallback = object : Call.Callback() {
        override fun onStateChanged(call: Call, state: Int) {
            log("BRIDGE_CALL_STATE", stateName(state))
            if (state == Call.STATE_ACTIVE && !mergeAttempted) attemptMerge()
            if (state == Call.STATE_DISCONNECTED) cleanup()
        }

        override fun onParentChanged(call: Call, parent: Call?) {
            log("BRIDGE_PARENT_CHANGED", "hasParent=${parent != null}")
        }
    }

    private val primaryCallCallback = object : Call.Callback() {
        override fun onConferenceableCallsChanged(call: Call, conferenceableCalls: MutableList<Call>) {
            log("PRIMARY_CONFERENCEABLE_CHANGED", "count=${conferenceableCalls.size}")
        }

        override fun onParentChanged(call: Call, parent: Call?) {
            log("PRIMARY_PARENT_CHANGED", "hasParent=${parent != null}")
        }

        override fun onStateChanged(call: Call, state: Int) {
            // The real call ending (hangup on either side) while a
            // bridge/merge attempt is still in flight — don't leave the
            // bridge leg as an orphaned call the user has to hang up
            // manually.
            if (state == Call.STATE_DISCONNECTED || state == Call.STATE_DISCONNECTING) {
                bridgeCall?.takeIf { it.state != Call.STATE_DISCONNECTED && it.state != Call.STATE_DISCONNECTING }
                    ?.disconnect()
            }
        }
    }

    fun attach(context: Context) {
        debugLog = EngineDebugLog(context.applicationContext)
    }

    /** True while a bridge/merge attempt is in flight and [call] isn't the
     * primary leg — [CallEventBridge] must never adopt such a call as its
     * single tracked call. Also true for any conference `Call` the Telecom
     * framework creates on a successful merge, which likewise isn't
     * something the existing single-call UI model can represent. */
    fun shouldIgnoreForPrimaryTracking(call: Call): Boolean {
        if (call.details.hasProperty(Call.Details.PROPERTY_CONFERENCE)) return true
        return primaryCall != null && call !== primaryCall
    }

    /** Called from every [DialerInCallService.onCallAdded]. A no-op unless
     * a bridge attempt is actually in flight (started via [startManualTest]
     * or [startAuto]). */
    fun onCallAdded(call: Call) {
        if (call.details.hasProperty(Call.Details.PROPERTY_CONFERENCE)) {
            // The actual feasibility/success signal: the framework
            // surfacing a real conference Call at all, with our two legs
            // as children, means the carrier/network really merged the
            // audio.
            val childCount = try { call.children.size } catch (e: Exception) { -1 }
            log("CONFERENCE_CALL_APPEARED", "childCount=$childCount")
            return
        }
        if (primaryCall == null) return // no bridge attempt in flight — ignore, this is a normal call
        if (bridgeCall == null && call !== primaryCall) {
            bridgeCall = call
            call.registerCallback(bridgeCallCallback)
            log("BRIDGE_CALL_ADDED", "state=${stateName(call.state)}")
        }
    }

    fun onCallRemoved(call: Call) {
        if (call === bridgeCall) {
            bridgeCall?.unregisterCallback(bridgeCallCallback)
            log("BRIDGE_CALL_REMOVED", "")
            cleanup()
        }
    }

    /** Debug entry point (Settings / in-call "Merge test" button) — any
     * number, typically a second phone the tester can personally answer. */
    fun startManualTest(context: Context, primary: Call, bridgeNumber: String): Boolean =
        start(context, primary, bridgeNumber, prefix = "MERGE_SPIKE")

    /** Production entry point — called by [CallEventBridge] once a real
     * call goes `ACTIVE`, only when [com.pypecrm.dialer.data.CallSettingsCache]
     * says the org has this enabled and has a bridge number configured. */
    fun startAuto(context: Context, primary: Call, bridgeNumber: String): Boolean =
        start(context, primary, bridgeNumber, prefix = "CLOUD_BRIDGE")

    private fun start(context: Context, primary: Call, bridgeNumber: String, prefix: String): Boolean {
        logPrefix = prefix
        if (primary.state != Call.STATE_ACTIVE) {
            log("ABORTED", "primary call not ACTIVE (state=${stateName(primary.state)})")
            return false
        }
        if (primaryCall != null) {
            log("ABORTED", "a bridge attempt is already in flight")
            return false
        }
        primaryCall = primary
        mergeAttempted = false
        primary.registerCallback(primaryCallCallback)
        logCapabilities("PRIMARY", primary)
        log("STARTED", "bridgeNumber=$bridgeNumber")
        CallPlacer.placeCall(context, bridgeNumber)
        return true
    }

    private fun attemptMerge() {
        val primary = primaryCall ?: return
        val bridge = bridgeCall ?: return
        mergeAttempted = true
        logCapabilities("PRIMARY_AT_MERGE_TIME", primary)
        logCapabilities("BRIDGE_AT_MERGE_TIME", bridge)
        log("MERGE_ATTEMPTED", "calling primary.conference(bridge)")
        try {
            primary.conference(bridge)
            log("MERGE_CALL_INVOKED", "no exception thrown — watch for CONFERENCE_CALL_APPEARED next, or its absence")
        } catch (e: Exception) {
            log("MERGE_THREW", e.message ?: e.toString())
        }
    }

    private fun logCapabilities(label: String, call: Call) {
        val caps = call.details.callCapabilities
        val flags = buildList {
            if (caps and Call.Details.CAPABILITY_MERGE_CONFERENCE != 0) add("MERGE_CONFERENCE")
            if (caps and Call.Details.CAPABILITY_SWAP_CONFERENCE != 0) add("SWAP_CONFERENCE")
            if (caps and Call.Details.CAPABILITY_MANAGE_CONFERENCE != 0) add("MANAGE_CONFERENCE")
            if (caps and Call.Details.CAPABILITY_HOLD != 0) add("HOLD")
        }
        log("${label}_CAPABILITIES", if (flags.isEmpty()) "none of the merge-relevant flags set" else flags.joinToString(","))
    }

    private fun cleanup() {
        primaryCall?.unregisterCallback(primaryCallCallback)
        primaryCall = null
        bridgeCall = null
        mergeAttempted = false
    }

    private fun log(event: String, detail: String) {
        debugLog?.append("${logPrefix}_$event", detail)
    }

    private fun stateName(state: Int): String = when (state) {
        Call.STATE_NEW -> "NEW"
        Call.STATE_DIALING -> "DIALING"
        Call.STATE_RINGING -> "RINGING"
        Call.STATE_HOLDING -> "HOLDING"
        Call.STATE_ACTIVE -> "ACTIVE"
        Call.STATE_DISCONNECTED -> "DISCONNECTED"
        Call.STATE_CONNECTING -> "CONNECTING"
        Call.STATE_DISCONNECTING -> "DISCONNECTING"
        else -> "UNKNOWN($state)"
    }
}
