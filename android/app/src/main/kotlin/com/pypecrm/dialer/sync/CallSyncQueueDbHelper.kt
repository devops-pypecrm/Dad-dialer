package com.pypecrm.dialer.sync

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import com.pypecrm.dialer.data.QueuedCallEvent

/**
 * Plain `SQLiteOpenHelper`-backed offline queue for calls pending upload to
 * `POST /api/android/bulk-sync` — same shape as Dad-call-recorder's
 * `data/CallEventDbHelper.kt` (a separate repo, referenced for its proven
 * pattern only). Deliberately not Room (this app family avoids it — see
 * that reference file's own history re: KSP/Kotlin-version pinning risk).
 */
class CallSyncQueueDbHelper private constructor(context: Context) :
    SQLiteOpenHelper(context.applicationContext, DB_NAME, null, DB_VERSION) {

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE $TABLE (
                $COL_ID INTEGER PRIMARY KEY AUTOINCREMENT,
                $COL_PHONE TEXT NOT NULL,
                $COL_DURATION INTEGER NOT NULL,
                $COL_TYPE TEXT NOT NULL,
                $COL_TIMESTAMP INTEGER NOT NULL,
                $COL_HARDWARE_ID TEXT,
                $COL_SESSION_ID TEXT,
                $COL_SYNCED INTEGER NOT NULL DEFAULT 0
            )
            """.trimIndent()
        )
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        db.execSQL("DROP TABLE IF EXISTS $TABLE")
        onCreate(db)
    }

    fun enqueue(
        phoneNumber: String,
        durationSeconds: Int,
        callType: String,
        timestampMillis: Long,
        hardwareId: String?,
        callSessionId: String?,
    ) {
        val values = ContentValues().apply {
            put(COL_PHONE, phoneNumber)
            put(COL_DURATION, durationSeconds)
            put(COL_TYPE, callType)
            put(COL_TIMESTAMP, timestampMillis)
            put(COL_HARDWARE_ID, hardwareId)
            put(COL_SESSION_ID, callSessionId)
            put(COL_SYNCED, 0)
        }
        writableDatabase.insert(TABLE, null, values)
    }

    fun unsyncedEvents(): List<QueuedCallEvent> {
        val results = mutableListOf<QueuedCallEvent>()
        readableDatabase.query(
            TABLE, null, "$COL_SYNCED = 0", null, null, null, "$COL_TIMESTAMP ASC",
        ).use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow(COL_ID)
            val phoneCol = cursor.getColumnIndexOrThrow(COL_PHONE)
            val durationCol = cursor.getColumnIndexOrThrow(COL_DURATION)
            val typeCol = cursor.getColumnIndexOrThrow(COL_TYPE)
            val timestampCol = cursor.getColumnIndexOrThrow(COL_TIMESTAMP)
            val hardwareIdCol = cursor.getColumnIndexOrThrow(COL_HARDWARE_ID)
            val sessionIdCol = cursor.getColumnIndexOrThrow(COL_SESSION_ID)
            while (cursor.moveToNext()) {
                results.add(
                    QueuedCallEvent(
                        id = cursor.getLong(idCol),
                        phoneNumber = cursor.getString(phoneCol),
                        durationSeconds = cursor.getInt(durationCol),
                        callType = cursor.getString(typeCol),
                        timestampMillis = cursor.getLong(timestampCol),
                        hardwareId = cursor.getString(hardwareIdCol),
                        callSessionId = cursor.getString(sessionIdCol),
                    )
                )
            }
        }
        return results
    }

    fun markSynced(ids: List<Long>) {
        if (ids.isEmpty()) return
        val placeholders = ids.joinToString(",") { "?" }
        writableDatabase.execSQL(
            "UPDATE $TABLE SET $COL_SYNCED = 1 WHERE $COL_ID IN ($placeholders)",
            ids.map { it.toString() }.toTypedArray(),
        )
    }

    /** Keeps the table from growing forever — synced rows are only useful
     * for a short debugging window after upload. */
    fun pruneSynced() {
        writableDatabase.execSQL("DELETE FROM $TABLE WHERE $COL_SYNCED = 1")
    }

    companion object {
        private const val DB_NAME = "dialer_sync_queue.db"
        private const val DB_VERSION = 1
        private const val TABLE = "queued_calls"
        private const val COL_ID = "id"
        private const val COL_PHONE = "phone_number"
        private const val COL_DURATION = "duration_seconds"
        private const val COL_TYPE = "call_type"
        private const val COL_TIMESTAMP = "timestamp_millis"
        private const val COL_HARDWARE_ID = "hardware_id"
        private const val COL_SESSION_ID = "call_session_id"
        private const val COL_SYNCED = "synced"

        @Volatile
        private var instance: CallSyncQueueDbHelper? = null

        fun getInstance(context: Context): CallSyncQueueDbHelper =
            instance ?: synchronized(this) {
                instance ?: CallSyncQueueDbHelper(context).also { instance = it }
            }
    }
}
