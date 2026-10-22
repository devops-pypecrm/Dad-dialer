package com.pypecrm.dialer.debug

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * Append-only ring buffer of Tier 0/sync diagnostic events, readable from
 * Dart. Ported from Dad-call-recorder's `call_recording_engine/debug/
 * EngineDebugLog.kt` (a separate repo, referenced for its proven shape
 * only — not shared code) — several OEMs suppress third-party app
 * `Log.*` output from `adb logcat` entirely (confirmed repeatedly while
 * debugging that app's own call-recording pipeline on real devices), so a
 * debug surface that doesn't depend on logcat being visible is the thing to
 * actually read when iterating against a real device.
 */
class EngineDebugLog(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun append(event: String, detail: String = "", level: String = "info") {
        Log.d(TAG, "$event: $detail")
        synchronized(this) {
            val entries = readEntries()
            entries.add(
                JSONObject().apply {
                    put("event", event)
                    put("detail", detail)
                    put("level", level)
                    put("timestampMillis", System.currentTimeMillis())
                }
            )
            while (entries.size > MAX_ENTRIES) entries.removeAt(0)
            prefs.edit().putString(KEY_ENTRIES, JSONArray(entries).toString()).apply()
        }
    }

    /** Newest-first, as a list of `{event, detail, level, timestampMillis}` maps. */
    fun readAll(): List<Map<String, Any?>> =
        readEntries().asReversed().map { entry ->
            mapOf(
                "event" to entry.optString("event"),
                "detail" to entry.optString("detail"),
                "level" to entry.optString("level", "info"),
                "timestampMillis" to entry.optLong("timestampMillis"),
            )
        }

    fun clear() {
        prefs.edit().remove(KEY_ENTRIES).apply()
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
        private const val TAG = "EngineDebugLog"
        private const val PREFS_NAME = "dialer_debug_log"
        private const val KEY_ENTRIES = "entries"
        private const val MAX_ENTRIES = 200
    }
}
