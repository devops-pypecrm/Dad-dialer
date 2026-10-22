package com.pypecrm.dialer.telecom

import android.telecom.Call
import android.telecom.CallAudioState
import android.telecom.InCallService
import android.util.Log

/**
 * The actual mechanism that makes this app a real default-dialer app — a
 * plain `InCallService` (`BIND_INCALL_SERVICE`), NOT a self-managed
 * `ConnectionService`/`PhoneAccount`. This matches the shape the
 * `dialer-version` branch on the separate `Dad-call-recorder` repo settled
 * on after trying self-managed first and ripping it out (see this app's
 * plan doc) — a self-managed connection is significantly more work for no
 * benefit here, since the actual goal is CRM call capture/CRM lead
 * identification through the real Telecom framework, not a custom in-call
 * rendering pipeline.
 *
 * Only receives `onCallAdded`/`onCallRemoved` callbacks once this app holds
 * `RoleManager.ROLE_DIALER` — see `role/DefaultDialerRoleManager.kt`.
 */
class DialerInCallService : InCallService() {

    override fun onCallAdded(call: Call) {
        super.onCallAdded(call)
        Log.d(TAG, "onCallAdded state=${call.state}")
        // CloudRecordingBridge sees every new call first — while a bridge/
        // merge attempt is in flight, the second (bridge) leg and any
        // resulting conference Call must NEVER become CallEventBridge's
        // single tracked call (that would hijack mute/speaker/end controls
        // and the sync bookkeeping for what looks to the user like their
        // one real call). See CloudRecordingBridge's doc comment.
        CloudRecordingBridge.onCallAdded(call)
        if (!CloudRecordingBridge.shouldIgnoreForPrimaryTracking(call)) {
            CallEventBridge.onCallAdded(call)
        }
    }

    override fun onCallRemoved(call: Call) {
        super.onCallRemoved(call)
        Log.d(TAG, "onCallRemoved")
        CallEventBridge.onCallRemoved(call)
        CloudRecordingBridge.onCallRemoved(call)
    }

    override fun onCallAudioStateChanged(audioState: CallAudioState) {
        super.onCallAudioStateChanged(audioState)
        CallEventBridge.setSpeakerState(audioState.route == CallAudioState.ROUTE_SPEAKER)
        CallEventBridge.setMutedState(audioState.isMuted)
    }

    /** Called by the MethodChannel handler (via [CallEventBridge]) — only
     * this bound InCallService instance may actually change the system
     * audio route/mute state. */
    fun applySpeaker(on: Boolean) {
        setAudioRoute(if (on) CallAudioState.ROUTE_SPEAKER else CallAudioState.ROUTE_EARPIECE)
    }

    fun applyMute(muted: Boolean) {
        setMuted(muted)
    }

    companion object {
        private const val TAG = "DialerInCallService"

        /** Set/cleared in `onCreate`/`onDestroy` so the MethodChannel handler
         * can reach the live bound instance for audio-route control, the one
         * thing [CallEventBridge] can't do on its own (`setAudioRoute`/
         * `setMuted` are InCallService instance methods, not static). */
        var instance: DialerInCallService? = null
            private set
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        CallEventBridge.attach(this)
        CloudRecordingBridge.attach(this)
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        super.onDestroy()
    }
}
