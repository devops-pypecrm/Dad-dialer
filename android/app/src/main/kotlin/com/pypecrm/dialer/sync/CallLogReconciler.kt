package com.pypecrm.dialer.sync

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.provider.CallLog
import android.util.Log
import androidx.core.content.ContextCompat
import com.pypecrm.dialer.data.CallSettingsCache
import com.pypecrm.dialer.data.NativeAuthPrefs
import com.pypecrm.dialer.data.QueuedCallEvent
import com.pypecrm.dialer.debug.EngineDebugLog
import com.pypecrm.dialer.net.BackendApi
import com.pypecrm.dialer.recording.NativeRecordingScanner

/**
 * Catches up on calls [com.pypecrm.dialer.telecom.CallEventBridge]'s
 * real-time `onCallRemoved` path never saw — a process death between
 * `onCallAdded`/`onCallRemoved` (crash, OS kill), or a call that started
 * before this InCallService instance was even bound. InCallService is a
 * privileged, Telecom-bound service (much harder for an OEM battery
 * manager to kill mid-call than Dad-call-recorder's plain
 * BroadcastReceiver-based approach), so this is a smaller safety net than
 * its equivalent in that app, not the primary capture path.
 *
 * Reads the system CallLog directly (the OS's own record, written
 * regardless of whether this app's process was even alive) for everything
 * since the last reconciliation, using the CallLog row's own stable `_ID`
 * as `hardwareId` — unlike [com.pypecrm.dialer.telecom.CallEventBridge]'s
 * `onCallRemoved` path (which has no CallLog cross-reference and sends
 * `hardwareId = null`), a backfilled row here has a real one, letting
 * [DialerSyncWorker] give it proper per-entry sync confirmation instead of
 * that path's "trust the whole 2xx batch" fallback.
 *
 * Also attempts Tier 0 (native-recording) recovery for each backfilled
 * call, gated on the same org consent [CallSettingsCache] enforces for the
 * real-time path — a call this reconciler is backfilling means Tier 0 was
 * never even attempted for it either.
 */
object CallLogReconciler {
    private const val TAG = "CallLogReconciler"

    // A CallLog row this fresh might still be mid-write on some OEMs —
    // skipped for THIS pass only (watermark not advanced past it), so the
    // next periodic tick picks it up once it's settled.
    private const val RACE_WINDOW_MS = 15_000L

    fun reconcile(context: Context, authPrefs: NativeAuthPrefs) {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CALL_LOG)
            != PackageManager.PERMISSION_GRANTED
        ) {
            Log.w(TAG, "READ_CALL_LOG not granted — skipping reconciliation")
            return
        }

        val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val since = prefs.getLong(KEY_LAST_RECONCILED, System.currentTimeMillis() - INITIAL_LOOKBACK_MS)
        val dbHelper = CallSyncQueueDbHelper.getInstance(context)
        val api = BackendApi(authPrefs)
        val settingsCache = CallSettingsCache(context)
        settingsCache.refreshIfStale(api)
        val debugLog = EngineDebugLog(context)

        var queued = 0
        var tier0Recovered = 0
        var newestSeen = since
        val now = System.currentTimeMillis()

        try {
            context.contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                arrayOf(
                    CallLog.Calls.NUMBER,
                    CallLog.Calls.DURATION,
                    CallLog.Calls.TYPE,
                    CallLog.Calls.DATE,
                    CallLog.Calls._ID,
                ),
                "${CallLog.Calls.DATE} > ?",
                arrayOf(since.toString()),
                "${CallLog.Calls.DATE} ASC",
            )?.use { cursor ->
                val numberCol = cursor.getColumnIndexOrThrow(CallLog.Calls.NUMBER)
                val durationCol = cursor.getColumnIndexOrThrow(CallLog.Calls.DURATION)
                val typeCol = cursor.getColumnIndexOrThrow(CallLog.Calls.TYPE)
                val dateCol = cursor.getColumnIndexOrThrow(CallLog.Calls.DATE)
                val idCol = cursor.getColumnIndexOrThrow(CallLog.Calls._ID)

                while (cursor.moveToNext()) {
                    val date = cursor.getLong(dateCol)
                    if (date > now - RACE_WINDOW_MS) continue

                    val rowId = cursor.getLong(idCol)
                    val typeInt = cursor.getInt(typeCol)
                    val typeStr = typeToString(typeInt)
                    val durationSecs = cursor.getInt(durationCol)
                    val phoneNumber = cursor.getString(numberCol) ?: ""
                    // The silent recording-bridge leg is infrastructure, not
                    // a customer call — never sync it as a CRM interaction.
                    if (settingsCache.isBridgeNumber(phoneNumber)) {
                        newestSeen = maxOf(newestSeen, date)
                        continue
                    }

                    val hardwareId = rowId.toString()
                    val callSessionId: String? = null

                    val directionAllowed = when (typeStr) {
                        "OUTGOING" -> settingsCache.isDirectionAllowed(true)
                        "INCOMING" -> settingsCache.isDirectionAllowed(false)
                        else -> settingsCache.isDirectionAllowed(true) && settingsCache.isDirectionAllowed(false)
                    }
                    val canAttemptTier0 = durationSecs > 0 && phoneNumber.isNotBlank() && directionAllowed

                    var recoveredAudio = false
                    if (canAttemptTier0) {
                        val file = NativeRecordingScanner.scanOnce(context, phoneNumber, date)
                        if (file != null) {
                            val event = QueuedCallEvent(
                                id = -1, phoneNumber = phoneNumber, durationSeconds = durationSecs,
                                callType = typeStr, timestampMillis = date, hardwareId = hardwareId,
                                callSessionId = callSessionId,
                            )
                            recoveredAudio = try {
                                api.uploadRecording(event, file)
                            } catch (e: Exception) {
                                Log.w(TAG, "Tier 0 recovery upload failed for reconciled call", e)
                                false
                            } finally {
                                file.delete()
                            }
                            if (recoveredAudio) {
                                tier0Recovered++
                                debugLog.append("TIER0_MATCH_FOUND", "reconciled call rowId=$rowId")
                            }
                        }
                    }

                    if (!recoveredAudio) {
                        dbHelper.enqueue(
                            phoneNumber = phoneNumber,
                            durationSeconds = durationSecs,
                            callType = typeStr,
                            timestampMillis = date,
                            hardwareId = hardwareId,
                            callSessionId = callSessionId,
                        )
                    }
                    queued++
                    if (date > newestSeen) newestSeen = date
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "CallLog reconciliation query failed", e)
            return
        }

        if (newestSeen > since) {
            prefs.edit().putLong(KEY_LAST_RECONCILED, newestSeen).apply()
        }
        if (queued > 0) {
            Log.i(TAG, "Reconciled $queued call(s) not previously captured ($tier0Recovered with recovered audio)")
            debugLog.append(
                "CALL_LOG_RECONCILED",
                "queued $queued call(s) not seen by the real-time path ($tier0Recovered recovered with audio)",
            )
        }
    }

    private fun typeToString(typeInt: Int): String = when (typeInt) {
        CallLog.Calls.INCOMING_TYPE -> "INCOMING"
        CallLog.Calls.OUTGOING_TYPE -> "OUTGOING"
        CallLog.Calls.MISSED_TYPE -> "MISSED"
        CallLog.Calls.VOICEMAIL_TYPE -> "MISSED"
        CallLog.Calls.REJECTED_TYPE -> "REJECTED"
        CallLog.Calls.BLOCKED_TYPE -> "BLOCKED"
        CallLog.Calls.ANSWERED_EXTERNALLY_TYPE -> "INCOMING"
        else -> "UNKNOWN"
    }

    private const val PREFS_NAME = "dialer_call_log_reconcile"
    private const val KEY_LAST_RECONCILED = "last_reconciled_at_millis"
    // First-ever run (fresh install) only looks back this far, not to the
    // dawn of the device's CallLog — avoids a huge one-time backfill sync.
    private const val INITIAL_LOOKBACK_MS = 24 * 60 * 60 * 1000L
}
