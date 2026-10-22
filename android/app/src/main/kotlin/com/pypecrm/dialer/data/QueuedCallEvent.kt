package com.pypecrm.dialer.data

/** One row of [com.pypecrm.dialer.sync.CallSyncQueueDbHelper] — matches
 * the exact fields `POST /api/android/bulk-sync` expects. */
data class QueuedCallEvent(
    val id: Long,
    val phoneNumber: String,
    val durationSeconds: Int,
    val callType: String,
    val timestampMillis: Long,
    val hardwareId: String?,
    val callSessionId: String?,
)
