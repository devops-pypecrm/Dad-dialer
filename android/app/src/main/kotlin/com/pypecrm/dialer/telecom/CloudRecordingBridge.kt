package com.pypecrm.dialer.telecom

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.telecom.Call
import com.pypecrm.dialer.debug.EngineDebugLog
import com.pypecrm.dialer.data.CallSettingsCache
import com.pypecrm.dialer.data.NativeAuthPrefs
import com.pypecrm.dialer.net.BackendApi
import kotlin.concurrent.thread

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
    private var merged = false
    private var appContext: Context? = null
    private var simLabel: String? = null
    private var outcomeReported = false
    private val mainHandler = Handler(Looper.getMainLooper())

    // The bridge leg must be answered by the provider, then the carrier must
    // accept the merge, both quickly: while this runs the REAL call is on
    // hold (Android holds the first call when a second is placed), so the
    // customer is hearing silence. If either step stalls, give up and hand
    // the call straight back rather than leave an agent talking to nobody.
    private val bridgeAnswerTimeoutMs = 20_000L
    private val mergeTimeoutMs = 6_000L
    private val answerWatchdog = Runnable { abort("BRIDGE_NOT_ANSWERED") }
    private val mergeWatchdog = Runnable { abort("MERGE_TIMED_OUT") }

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
            // The carrier can take a moment after the bridge answers before
            // it offers the merge; retry the moment it does.
            val bridge = bridgeCall
            if (bridge != null && bridge.state == Call.STATE_ACTIVE && !merged && conferenceableCalls.contains(bridge)) {
                invokeMerge()
            }
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
            merged = true
            mainHandler.removeCallbacks(mergeWatchdog)
            reportOutcome("MERGED")
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
        appContext = context.applicationContext
        simLabel = (context.getSystemService(Context.TELECOM_SERVICE) as android.telecom.TelecomManager)
            .getPhoneAccount(primary.details.accountHandle)?.label?.toString()
        outcomeReported = false
        primaryCall = primary
        mergeAttempted = false
        merged = false
        primary.registerCallback(primaryCallCallback)
        logCapabilities("PRIMARY", primary)
        log("STARTED", "bridgeNumber=$bridgeNumber")
        CallSettingsCache(context).rememberBridgeNumber(bridgeNumber)
        // Two calls can only be conferenced when they're on the SAME SIM
        // (phone account) — on a dual-SIM phone the system default may be
        // the other SIM, so pin the bridge leg to whatever the real call is
        // using.
        CallPlacer.placeCall(context, bridgeNumber, accountHandle = primary.details.accountHandle)
        mainHandler.postDelayed(answerWatchdog, bridgeAnswerTimeoutMs)
        return true
    }

    private fun attemptMerge() {
        mergeAttempted = true
        mainHandler.removeCallbacks(answerWatchdog)
        mainHandler.postDelayed(mergeWatchdog, mergeTimeoutMs)
        invokeMerge()
    }

    private fun invokeMerge() {
        val primary = primaryCall ?: return
        val bridge = bridgeCall ?: return
        logCapabilities("PRIMARY_AT_MERGE_TIME", primary)
        logCapabilities("BRIDGE_AT_MERGE_TIME", bridge)
        if (!primary.conferenceableCalls.contains(bridge)) {
            // conference() silently does nothing for a call the carrier
            // hasn't offered as mergeable — wait for
            // onConferenceableCallsChanged (or the watchdog) instead.
            log("MERGE_NOT_OFFERED_YET", "bridge not in primary.conferenceableCalls")
            return
        }
        log("MERGE_ATTEMPTED", "calling primary.conference(bridge)")
        try {
            primary.conference(bridge)
            log("MERGE_CALL_INVOKED", "no exception thrown — watch for CONFERENCE_CALL_APPEARED next, or its absence")
        } catch (e: Exception) {
            log("MERGE_THREW", e.message ?: e.toString())
        }
    }

    /** Merge failed or stalled: drop the bridge leg and take the real call
     * off hold, so the agent is back on their call within seconds and the
     * only cost is that this one call isn't recorded. */
    private fun abort(reason: String) {
        if (merged) return
        log("ABORTED_FALLBACK", reason)
        reportOutcome(reason)
        val primary = primaryCall
        val bridge = bridgeCall
        if (bridge != null && bridge.state != Call.STATE_DISCONNECTED && bridge.state != Call.STATE_DISCONNECTING) {
            bridge.disconnect()
        }
        if (primary != null && primary.state == Call.STATE_HOLDING) primary.unhold()
        cleanup()
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

    /** Production attempts only (the debug "Merge test" stays local), and at
     * most once per attempt. Off the main thread — it's a network call. */
    private fun reportOutcome(outcome: String) {
        val context = appContext ?: return
        if (logPrefix != "CLOUD_BRIDGE" || outcomeReported) return
        outcomeReported = true
        val label = simLabel
        thread(name = "bridge-outcome") {
            BackendApi(NativeAuthPrefs(context)).reportBridgeOutcome(outcome, label)
        }
    }

    private fun cleanup() {
        mainHandler.removeCallbacks(answerWatchdog)
        mainHandler.removeCallbacks(mergeWatchdog)
        primaryCall?.unregisterCallback(primaryCallCallback)
        primaryCall = null
        bridgeCall = null
        mergeAttempted = false
        merged = false
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
