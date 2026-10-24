package com.pypecrm.dialer.telecom

import android.content.Context
import android.media.AudioManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.telecom.Call
import android.telecom.VideoProfile
import android.util.Log
import com.pypecrm.dialer.data.CallSettingsCache
import com.pypecrm.dialer.data.NativeAuthPrefs
import com.pypecrm.dialer.data.QueuedCallEvent
import com.pypecrm.dialer.data.RecordingStatusStore
import com.pypecrm.dialer.debug.EngineDebugLog
import com.pypecrm.dialer.net.BackendApi
import com.pypecrm.dialer.recording.NativeRecordingScanner
import com.pypecrm.dialer.sync.CallSyncQueueDbHelper
import com.pypecrm.dialer.sync.DialerSyncWorker
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.UUID

/**
 * Singleton bridge between [DialerInCallService] (which only ever runs when
 * the system Telecom framework binds it — may outlive or start before any
 * particular Flutter engine instance) and the Flutter side's EventChannel
 * listener. Also the single place that knows how to drive the currently
 * tracked [Call] (answer/reject/end/mute/speaker/hold/dtmf) — MainActivity's
 * MethodChannel handlers all delegate here rather than duplicating
 * Call-control logic.
 */
object CallEventBridge : EventChannel.StreamHandler {
    private const val TAG = "CallEventBridge"

    private var eventSink: EventChannel.EventSink? = null
    private var trackedCall: Call? = null
    private var audioSpeakerOn = false
    private var audioMuted = false

    // Tier 0 (native-recording recovery) does MediaStore I/O and a network
    // upload — InCallService's own callbacks (onCallAdded/onCallRemoved/
    // onStateChanged) all run on the main thread, so this must never run
    // inline there (same NetworkOnMainThreadException class of bug already
    // hit and fixed in Dad-call-recorder's equivalent path).
    private val ioScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    // ~2s apart for ~16-18s total, matching Dad-call-recorder's
    // CallMonitorService poll window.
    private const val TIER0_POLL_ATTEMPTS = 9
    private const val TIER0_POLL_INTERVAL_MS = 2000L

    // ---- Call-sync bookkeeping (queues to CallSyncQueueDbHelper on call end) ----
    private var appContext: Context? = null
    private var currentCallStartedAtMillis: Long = 0L
    // Set once, on the FIRST transition to ACTIVE (answered) — this is what
    // duration must be measured from, not currentCallStartedAtMillis (which
    // is call-CREATED time, i.e. includes dial/ring time on the caller's
    // side). Not reset on a later hold/resume ACTIVE transition, so a call
    // that goes ACTIVE -> HOLDING -> ACTIVE still reports duration from the
    // original answer, not from when it came off hold.
    private var currentCallActiveAtMillis: Long = 0L
    private var currentCallWasActive = false
    private var currentCallSessionId: String? = null

    // ---- Incoming-call ringtone ----
    // Not relying solely on Telecom's own system Ringer here -- several OEM
    // skins (observed on ColorOS specifically, this app's actual test
    // device) have shipped bugs where switching the default dialer app
    // stops the system ringer from sounding for the new app's incoming
    // calls. Playing the device's own default ringtone ourselves guarantees
    // consistent behavior regardless of that OEM quirk, while still
    // respecting the user's ringer mode (silent = no sound, vibrate =
    // vibrate only, same as the system's own behavior would).
    private var ringtone: Ringtone? = null
    private var vibrator: Vibrator? = null

    private fun startRinging(context: Context) {
        // Independent of the ringtone logic below — this is what actually
        // brings the incoming-call UI on screen when the app isn't already
        // open (see IncomingCallNotifier's doc comment). Always attempted,
        // even if the ringtone itself is skipped for RINGER_MODE_SILENT —
        // a silent-mode call still needs its UI to appear, same as the
        // system's own dialer would.
        IncomingCallNotifier.showIncomingCall(context, trackedCall?.let { numberOf(it) } ?: "Unknown number")

        if (ringtone?.isPlaying == true) return
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        when (audioManager?.ringerMode) {
            AudioManager.RINGER_MODE_SILENT -> return
            AudioManager.RINGER_MODE_VIBRATE -> {
                val vib = context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                vibrator = vib
                vib?.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 500, 500), 0))
            }
            else -> {
                try {
                    val uri = RingtoneManager.getActualDefaultRingtoneUri(context, RingtoneManager.TYPE_RINGTONE)
                        ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                    val tone = RingtoneManager.getRingtone(context, uri)
                    ringtone = tone
                    tone?.play()
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to play ringtone", e)
                }
            }
        }
    }

    private fun stopRinging() {
        try {
            ringtone?.let { if (it.isPlaying) it.stop() }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to stop ringtone", e)
        }
        ringtone = null
        vibrator?.cancel()
        vibrator = null
        appContext?.let { IncomingCallNotifier.cancel(it) }
    }

    /** Called once by [DialerInCallService.onCreate] — needed so
     * [onCallRemoved] can enqueue the finished call for sync; InCallService
     * itself is a fine place to hold this, but keeping the actual queuing
     * logic here (alongside the Call.Callback that observes state) avoids
     * splitting call-lifecycle knowledge across two classes. */
    fun attach(context: Context) {
        appContext = context.applicationContext
    }

    private val callCallback = object : Call.Callback() {
        override fun onStateChanged(call: Call, state: Int) {
            if (state == Call.STATE_ACTIVE && !currentCallWasActive) {
                currentCallWasActive = true
                currentCallActiveAtMillis = System.currentTimeMillis()
                maybeStartCloudRecordingBridge(call)
            }
            if (state == Call.STATE_RINGING) {
                appContext?.let { startRinging(it) }
            } else {
                stopRinging()
            }
            emitCallState(call, state)
        }

        override fun onDetailsChanged(call: Call, details: Call.Details) {
            emitCallState(call, call.state)
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        // A call may already be in progress if InCallService started before
        // Flutter's engine attached (e.g. app launched by an incoming call)
        // — replay current state immediately so Dart doesn't miss it.
        trackedCall?.let { emitCallState(it, it.state) }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    /** Called by [DialerInCallService.onCallAdded]. Only tracks ONE call at
     * a time for Phase 1 — multi-call/conference/call-waiting UI is
     * explicitly out of scope for this pass (see the approved plan). */
    fun onCallAdded(call: Call) {
        trackedCall?.unregisterCallback(callCallback)
        trackedCall = call
        currentCallStartedAtMillis = System.currentTimeMillis()
        currentCallActiveAtMillis = 0L
        currentCallWasActive = false
        currentCallSessionId = UUID.randomUUID().toString()
        call.registerCallback(callCallback)
        // A call can already be in RINGING state the moment it's added
        // (the normal case for an incoming call) -- onStateChanged only
        // fires on a *transition*, so this won't otherwise get a chance to
        // start ringing for it.
        if (call.state == Call.STATE_RINGING) {
            appContext?.let { startRinging(it) }
        }
        emitCallState(call, call.state)
    }

    fun onCallRemoved(call: Call) {
        if (trackedCall == call) {
            call.unregisterCallback(callCallback)
            trackedCall = null
            stopRinging()
            enqueueForSync(call)
            eventSink?.success(
                mapOf(
                    "event" to "CALL_REMOVED",
                    "number" to numberOf(call),
                )
            )
        }
    }

    /** Queues this finished call for CRM sync via `POST /api/android/bulk-sync`
     * (metadata only — no audio, this app never records calls, see the
     * approved plan's Play-compliance rationale). `callType` mirrors the
     * vocabulary that endpoint already accepts, same as the reference
     * `CallSyncWorker`/`androidController.ts` contract. */
    private fun enqueueForSync(call: Call) {
        val context = appContext ?: return
        val number = numberOf(call) ?: return
        val isIncoming = call.details.callDirection == Call.Details.DIRECTION_INCOMING
        // Measured from when the call was actually ANSWERED (currentCallActiveAtMillis),
        // not from currentCallStartedAtMillis (call-created/dial time) — the
        // latter double-counts ring/dial-out time on the caller's side,
        // which is why this previously ran a few seconds ahead of what the
        // other party's own phone showed for the same call.
        val durationSeconds = if (currentCallWasActive) {
            ((System.currentTimeMillis() - currentCallActiveAtMillis) / 1000).toInt()
        } else {
            0
        }
        val callType = when {
            currentCallWasActive -> if (isIncoming) "INCOMING" else "OUTGOING"
            isIncoming -> "MISSED"
            else -> "OUTGOING" // dialed but never connected (no answer/failed) — still an attempt worth logging
        }
        CallSyncQueueDbHelper.getInstance(context).enqueue(
            phoneNumber = number,
            durationSeconds = durationSeconds,
            callType = callType,
            timestampMillis = currentCallStartedAtMillis,
            hardwareId = null, // this app's own InCallService lifecycle IS the source of truth; no separate CallLog _ID cross-reference needed
            callSessionId = currentCallSessionId,
        )
        DialerSyncWorker.scheduleNow(context)

        // Tier 0: look for a file the phone's own native call-recorder
        // already produced — this app never records calls itself (see the
        // approved plan's Play-compliance rationale), it only ever recovers
        // what the OEM's own privileged recorder wrote. Uses the same
        // callSessionId as the metadata enqueue above, so the backend heals
        // the Interaction the bulk-sync call creates rather than duplicating
        // it (same dedup convention as the metadata path).
        attemptTier0Recovery(context, number, callType, durationSeconds, currentCallStartedAtMillis, currentCallSessionId)
    }

    /** Polls MediaStore a few times after call-end — several OEMs finalize
     * their own recording file a few seconds late, not instantly (same
     * reasoning as Dad-call-recorder's `CallMonitorService.pollTier0`).
     * Never attempted for a call that was never actually connected
     * (durationSeconds <= 0) — there's no call audio for the OEM recorder
     * to have captured in the first place. */
    private fun attemptTier0Recovery(
        context: Context,
        phoneNumber: String,
        callType: String,
        durationSeconds: Int,
        callEndMillis: Long,
        callSessionId: String?,
    ) {
        if (durationSeconds <= 0) return
        ioScope.launch {
            val authPrefs = NativeAuthPrefs(context)
            if (!authPrefs.isSignedIn()) return@launch
            val api = BackendApi(authPrefs)
            val settingsCache = CallSettingsCache(context)
            settingsCache.refreshIfStale(api)
            val isOutgoing = callType == "OUTGOING"
            if (!settingsCache.isDirectionAllowed(isOutgoing)) return@launch

            val debugLog = EngineDebugLog(context)
            repeat(TIER0_POLL_ATTEMPTS) { attempt ->
                val file = NativeRecordingScanner.scanOnce(context, phoneNumber, callEndMillis)
                if (file != null) {
                    val event = QueuedCallEvent(
                        id = -1,
                        phoneNumber = phoneNumber,
                        durationSeconds = durationSeconds,
                        callType = callType,
                        timestampMillis = callEndMillis,
                        hardwareId = null,
                        callSessionId = callSessionId,
                    )
                    val uploaded = try {
                        api.uploadRecording(event, file)
                    } catch (e: Exception) {
                        false
                    } finally {
                        file.delete()
                    }
                    if (uploaded) {
                        debugLog.append("TIER0_MATCH_FOUND", "live call recovery, attempt=$attempt")
                        RecordingStatusStore(context).markRecordingFound(phoneNumber, callEndMillis)
                        return@launch
                    }
                }
                if (attempt < TIER0_POLL_ATTEMPTS - 1) delay(TIER0_POLL_INTERVAL_MS)
            }
            debugLog.append("TIER0_NO_MATCH", "phone=$phoneNumber callEndMillis=$callEndMillis")
        }
    }

    /** Fires once per call, right as it goes ACTIVE — the earliest safe
     * moment to start the server-number/conference-bridge attempt (see
     * Dad-dialer/CALL_RECORDING_SERVER_METHOD_PLAN.md). Fails closed: no
     * network fetch success yet, or the org hasn't opted in with a
     * configured bridge number, and this is simply a no-op — never a
     * fallback default-on. */
    private fun maybeStartCloudRecordingBridge(call: Call) {
        val context = appContext ?: return
        ioScope.launch {
            val authPrefs = NativeAuthPrefs(context)
            if (!authPrefs.isSignedIn()) return@launch
            val api = BackendApi(authPrefs)
            val settingsCache = CallSettingsCache(context)
            settingsCache.refreshIfStale(api)
            val bridgeNumber = settingsCache.cloudRecordingBridgeNumberOrNull() ?: return@launch
            // Same per-direction consent switch Tier 0 honors — cloud
            // recording is still recording, so an org that hasn't turned on
            // recording for this direction must never get a bridge leg.
            val isOutgoing = call.details.callDirection != Call.Details.DIRECTION_INCOMING
            if (!settingsCache.isDirectionAllowed(isOutgoing)) return@launch
            // Call.conference()/registerCallback and TelecomManager.placeCall
            // are InCallService/Telecom APIs this app otherwise only ever
            // drives from the main thread (matching the manual-test entry
            // point, invoked directly from MainActivity's method channel
            // handler) — hop back rather than call them from ioScope's IO
            // dispatcher.
            withContext(Dispatchers.Main) {
                CloudRecordingBridge.startAuto(context, call, bridgeNumber)
            }
        }
    }

    private fun emitCallState(call: Call, state: Int) {
        eventSink?.success(
            mapOf(
                "event" to "STATE_CHANGED",
                "state" to stateName(state),
                "number" to numberOf(call),
                "isIncoming" to (call.details.callDirection == Call.Details.DIRECTION_INCOMING),
            )
        )
    }

    private fun numberOf(call: Call): String? = call.details.handle?.schemeSpecificPart

    private fun stateName(state: Int): String = when (state) {
        Call.STATE_NEW -> "NEW"
        Call.STATE_DIALING -> "DIALING"
        Call.STATE_RINGING -> "RINGING"
        Call.STATE_HOLDING -> "HOLDING"
        Call.STATE_ACTIVE -> "ACTIVE"
        Call.STATE_DISCONNECTED -> "DISCONNECTED"
        Call.STATE_CONNECTING -> "CONNECTING"
        Call.STATE_DISCONNECTING -> "DISCONNECTING"
        Call.STATE_SELECT_PHONE_ACCOUNT -> "SELECT_PHONE_ACCOUNT"
        else -> "UNKNOWN"
    }

    // ---- Call control, invoked from MainActivity's MethodChannel handler ----

    fun answer(): Boolean {
        val call = trackedCall ?: return false
        call.answer(VideoProfile.STATE_AUDIO_ONLY)
        return true
    }

    fun reject(): Boolean {
        val call = trackedCall ?: return false
        call.reject(false, null)
        return true
    }

    fun endCall(): Boolean {
        val call = trackedCall ?: return false
        call.disconnect()
        return true
    }

    fun holdCall(): Boolean {
        val call = trackedCall ?: return false
        call.hold()
        return true
    }

    fun resumeCall(): Boolean {
        val call = trackedCall ?: return false
        call.unhold()
        return true
    }

    fun sendDtmf(digit: Char): Boolean {
        val call = trackedCall ?: return false
        call.playDtmfTone(digit)
        call.stopDtmfTone()
        return true
    }

    /** Speakerphone/mute aren't per-Call — they're set via
     * [DialerInCallService.setAudioRoute]/`setMuted`, called by the service
     * itself since only it (the bound InCallService) may call those. This
     * object just remembers the last-requested state so a fresh EventChannel
     * listener (e.g. after a hot restart) can query it. */
    fun setSpeakerState(on: Boolean) {
        audioSpeakerOn = on
    }

    fun isSpeakerOn(): Boolean = audioSpeakerOn

    fun setMutedState(muted: Boolean) {
        audioMuted = muted
    }

    fun isMuted(): Boolean = audioMuted

    fun hasActiveCall(): Boolean = trackedCall != null

    /** Used only by [CloudRecordingBridge]'s manual-test entry point — the
     * primary leg a merge spike attaches to must already be `ACTIVE`. */
    fun currentActiveCallOrNull(): Call? =
        trackedCall?.takeIf { it.state == Call.STATE_ACTIVE }
}
