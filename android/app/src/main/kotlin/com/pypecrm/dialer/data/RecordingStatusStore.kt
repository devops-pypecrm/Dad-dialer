package com.pypecrm.dialer.data

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Tracks which calls actually got a Tier 0 (native OEM recorder) recording
 * successfully uploaded — the one real signal the Recents screen's mic icon
 * is conditioned on (see `RecentsScreen`'s `_RecentTile`), and the one real
 * signal the in-call "Recording" indicator (`InCallScreen`) reflects.
 * Deliberately never a guess or a default-on value — only ever written at
 * the exact point `CallEventBridge.attemptTier0Recovery` confirms a Tier 0
 * upload actually succeeded for that specific call.
 *
 * Keyed by (last-10-digits, timestamp within a tolerance window) rather
 * than an exact CallLog row id — Tier 0's own matching already works this
 * way (`NativeRecordingScanner`, no `hardwareId` tracked for this app's
 * calls, see `CallEventBridge`'s doc comment on why), so this mirrors that
 * same fuzzy-match convention instead of inventing a stricter one that the
 * rest of the pipeline doesn't actually support.
 */
class RecordingStatusStore(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun markRecordingFound(phoneNumber: String, timestampMillis: Long) {
        val last10 = phoneNumber.filter { it.isDigit() }.takeLast(10)
        if (last10.length < 10) return
        synchronized(this) {
            val entries = readEntries()
            entries.add(
                JSONObject().apply {
                    put("phone", last10)
                    put("timestampMillis", timestampMillis)
                }
            )
            while (entries.size > MAX_ENTRIES) entries.removeAt(0)
            prefs.edit()
                .putString(KEY_ENTRIES, JSONArray(entries).toString())
                // This device has now proven its native recorder actually
                // works at least once — lets the in-call screen show the
                // "Recording" indicator as active for the CURRENT call too,
                // even though Tier 0's own poll for that call only runs
                // after it ends.
                .putBoolean(KEY_DEVICE_CONFIRMED, true)
                .apply()
        }
    }

    /** Device has had at least one confirmed Tier 0 match, ever. */
    fun isNativeRecordingConfirmedOnDevice(): Boolean = prefs.getBoolean(KEY_DEVICE_CONFIRMED, false)

    /** All known (phone, timestamp) matches — for bulk client-side matching
     * against a whole Recents list in one method-channel round trip instead
     * of one call per row. See [hasRecordingFor] for the same matching
     * logic, kept here so Dart doesn't have to re-implement the tolerance
     * window itself. */
    fun allEntries(): List<Pair<String, Long>> =
        readEntries().map { it.optString("phone") to it.optLong("timestampMillis") }

    /** Whether a specific CallLog row (by number + timestamp) has a
     * confirmed Tier 0 recording — a tolerance window, not exact equality,
     * since the two sides' timestamps (call-started-at vs. the system
     * CallLog's own DATE column) aren't guaranteed byte-identical. */
    fun hasRecordingFor(phoneNumber: String, timestampMillis: Long): Boolean {
        val last10 = phoneNumber.filter { it.isDigit() }.takeLast(10)
        if (last10.length < 10) return false
        return readEntries().any { entry ->
            entry.optString("phone") == last10 &&
                Math.abs(entry.optLong("timestampMillis") - timestampMillis) <= TOLERANCE_MS
        }
    }

    private fun readEntries(): MutableList<JSONObject> {
        val raw = prefs.getString(KEY_ENTRIES, null) ?: return mutableListOf()
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { arr.getJSONObject(it) }.toMutableList()
        } catch (e: Exception) {
            mutableListOf()
        }
    }

    companion object {
        private const val PREFS_NAME = "dialer_recording_status"
        private const val KEY_ENTRIES = "entries"
        private const val KEY_DEVICE_CONFIRMED = "device_confirmed"
        private const val MAX_ENTRIES = 50
        const val TOLERANCE_MS = 3 * 60_000L
    }
}
