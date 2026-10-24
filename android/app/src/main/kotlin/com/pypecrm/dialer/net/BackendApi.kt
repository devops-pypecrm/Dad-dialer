package com.pypecrm.dialer.net

import android.util.Log
import com.pypecrm.dialer.data.NativeAuthPrefs
import com.pypecrm.dialer.data.QueuedCallEvent
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.TimeUnit

sealed class BulkSyncResult {
    /** [syncedHardwareIds]: exactly which of the events sent are now
     * actually represented server-side — a 2xx does NOT mean the whole
     * batch succeeded, the server can legitimately skip/error individual
     * entries while returning 200 overall. */
    data class Success(val syncedHardwareIds: Set<String>) : BulkSyncResult()
    data class RateLimited(val retryAfterSeconds: Int) : BulkSyncResult()
    data object Failed : BulkSyncResult()
}

data class OrgCallSettings(
    val autoRecordInbound: Boolean,
    val autoRecordOutbound: Boolean,
    // Server-number/conference-bridge cloud recording — see
    // Dad-dialer/CALL_RECORDING_SERVER_METHOD_PLAN.md. Distinct from
    // Tier 0 (autoRecord*/OEM file detection) above; both come back from
    // the same GET /api/call-settings response (see
    // callSettingsController.ts's getCallSettings), no separate endpoint.
    val cloudRecordingEnabled: Boolean = false,
    val cloudRecordingBridgeNumber: String? = null,
)

/**
 * Talks to Dad-backend's `/api/android/bulk-sync` directly via OkHttp (not
 * Dio) — runs from [com.pypecrm.dialer.sync.DialerSyncWorker], which must
 * function with the Flutter engine fully suspended. Contract confirmed
 * directly against Dad-backend/src/routes/androidRoutes.ts,
 * controllers/androidController.ts — this endpoint is already live and
 * unmodified for this app; see the approved plan's backend-gap section for
 * what's genuinely new vs. reused as-is.
 */
class BackendApi(private val authPrefs: NativeAuthPrefs) {
    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(2, TimeUnit.MINUTES)
        .writeTimeout(60, TimeUnit.SECONDS)
        .build()

    private fun authOrNull(): Pair<String, String>? {
        val token = authPrefs.token ?: return null
        val base = authPrefs.apiBaseUrl ?: return null
        return token to base
    }

    /** Batches every unsynced [events] into ONE call — the server hard
     * rate-limits this endpoint to 1 request/user/10min, so callers must
     * never call this per-event (see DialerSyncWorker's self-throttle). */
    fun bulkSync(events: List<QueuedCallEvent>): BulkSyncResult {
        val (token, base) = authOrNull() ?: return BulkSyncResult.Failed
        val callsJson = JSONArray()
        for (event in events) {
            callsJson.put(
                JSONObject().apply {
                    put("phoneNumber", event.phoneNumber)
                    put("duration", event.durationSeconds)
                    put("callType", event.callType)
                    put("timestamp", event.timestampMillis)
                    put("hardwareId", event.hardwareId ?: "")
                    if (event.callSessionId != null) put("callSessionId", event.callSessionId)
                }
            )
        }
        val payload = JSONObject().apply { put("calls", callsJson) }
        val request = Request.Builder()
            .url("$base/android/bulk-sync")
            .header("Authorization", "Bearer $token")
            .post(payload.toString().toRequestBody("application/json".toMediaTypeOrNull()))
            .build()
        return try {
            client.newCall(request).execute().use { response ->
                when {
                    response.code == 429 -> {
                        val body = response.body?.string().orEmpty()
                        val retryAfter = runCatching { JSONObject(body).optInt("retryAfterSeconds", 600) }
                            .getOrDefault(600)
                        BulkSyncResult.RateLimited(retryAfter)
                    }
                    response.isSuccessful -> {
                        val body = response.body?.string().orEmpty()
                        val syncedIds = runCatching {
                            val arr = JSONObject(body).optJSONArray("syncedHardwareIds")
                            (0 until (arr?.length() ?: 0)).mapNotNull { arr?.optString(it) }.toSet()
                        }.getOrDefault(emptySet())
                        BulkSyncResult.Success(syncedIds)
                    }
                    else -> {
                        Log.w(TAG, "bulkSync failed: ${response.code}")
                        BulkSyncResult.Failed
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "bulkSync network error", e)
            BulkSyncResult.Failed
        }
    }

    /** `GET /api/call-settings` — org consent for Tier 0 upload direction
     * gating (see [com.pypecrm.dialer.data.CallSettingsCache]). */
    fun fetchCallSettings(): OrgCallSettings? {
        val (token, base) = authOrNull() ?: return null
        val request = Request.Builder()
            .url("$base/call-settings")
            .header("Authorization", "Bearer $token")
            .get()
            .build()
        return try {
            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) {
                    Log.w(TAG, "fetchCallSettings failed: ${response.code}")
                    return null
                }
                val body = response.body?.string() ?: return null
                val json = JSONObject(body)
                OrgCallSettings(
                    autoRecordInbound = json.optBoolean("autoRecordInbound", false),
                    autoRecordOutbound = json.optBoolean("autoRecordOutbound", false),
                    cloudRecordingEnabled = json.optBoolean("cloudRecordingEnabled", false),
                    cloudRecordingBridgeNumber = json.optString("cloudRecordingBridgeNumber", "").ifBlank { null },
                )
            }
        } catch (e: Exception) {
            Log.w(TAG, "fetchCallSettings network error", e)
            null
        }
    }

    /** `POST /api/telephony/bridge/outcome` — fire-and-forget result of one
     * cloud-recording attempt (merged / not answered / merge refused), with
     * the SIM label and phone model. This is how real carrier coverage gets
     * measured from live traffic instead of from a hand-tested demo SIM. */
    fun reportBridgeOutcome(outcome: String, simLabel: String?): Boolean {
        val (token, base) = authOrNull() ?: return false
        val json = JSONObject()
            .put("outcome", outcome)
            .put("simLabel", simLabel ?: JSONObject.NULL)
            .put("device", "${android.os.Build.MANUFACTURER} ${android.os.Build.MODEL}")
            .put("androidSdk", android.os.Build.VERSION.SDK_INT)
        val request = Request.Builder()
            .url("$base/telephony/bridge/outcome")
            .header("Authorization", "Bearer $token")
            .post(json.toString().toRequestBody("application/json".toMediaTypeOrNull()))
            .build()
        return try {
            client.newCall(request).execute().use { it.isSuccessful }
        } catch (e: Exception) {
            Log.w(TAG, "reportBridgeOutcome network error", e)
            false
        }
    }

    /** Tier 0 path: a real OEM-recorded file was found and this call's
     * direction is allowed — `POST /api/android/recordings`, multipart,
     * file field `audio`. `hardwareId` is sent un-namespaced; the server
     * prefixes it with `${userId}_` itself. */
    fun uploadRecording(event: QueuedCallEvent, audioFile: File): Boolean {
        val (token, base) = authOrNull() ?: return false
        val mediaType = "audio/*".toMediaTypeOrNull()
        val body = MultipartBody.Builder().setType(MultipartBody.FORM)
            .addFormDataPart("phoneNumber", event.phoneNumber)
            .addFormDataPart("duration", event.durationSeconds.toString())
            .addFormDataPart("callType", event.callType)
            .addFormDataPart("timestamp", event.timestampMillis.toString())
            .addFormDataPart("hardwareId", event.hardwareId ?: "")
            .addFormDataPart("callSessionId", event.callSessionId ?: "")
            .addFormDataPart("audio", audioFile.name, audioFile.asRequestBody(mediaType))
            .build()
        val request = Request.Builder()
            .url("$base/android/recordings")
            .header("Authorization", "Bearer $token")
            .post(body)
            .build()
        return try {
            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) {
                    Log.w(TAG, "uploadRecording failed: ${response.code} ${response.body?.string()}")
                }
                response.isSuccessful
            }
        } catch (e: Exception) {
            Log.w(TAG, "uploadRecording network error", e)
            false
        }
    }

    companion object {
        private const val TAG = "BackendApi"
    }
}
