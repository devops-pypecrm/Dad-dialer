package com.pypecrm.dialer.sync

import android.content.Context
import android.util.Log
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.OutOfQuotaPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.pypecrm.dialer.data.NativeAuthPrefs
import com.pypecrm.dialer.net.BackendApi
import com.pypecrm.dialer.net.BulkSyncResult
import java.util.concurrent.TimeUnit

/**
 * Uploads every locally-queued call to `POST /api/android/bulk-sync` in one
 * batch. Same design as Dad-call-recorder's `sync/CallSyncWorker.kt` (a
 * separate repo, referenced for its proven pattern only — not shared code):
 * always the whole unsynced queue in one request (never per-call, since the
 * server hard rate-limits this endpoint to 1 request/user/10min), a
 * client-side self-throttle so a device that just synced doesn't even
 * attempt a run it knows will 429, and only clearing rows the server
 * actually confirmed by `hardwareId` — a 2xx can still mean some entries
 * were legitimately skipped/errored server-side.
 */
class DialerSyncWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val authPrefs = NativeAuthPrefs(applicationContext)
        if (!authPrefs.isSignedIn()) return Result.success()

        // Local-only (no network, no rate limit) — runs on every tick
        // regardless of the bulk-sync throttle below, so a call the
        // real-time InCallService path missed gets discovered promptly
        // even while an upload is still cooling down. See
        // CallLogReconciler's doc comment.
        CallLogReconciler.reconcile(applicationContext, authPrefs)

        val prefs = applicationContext.getSharedPreferences(THROTTLE_PREFS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        val nextAllowedAt = prefs.getLong(KEY_NEXT_ALLOWED_AT, 0L)
        if (now < nextAllowedAt) {
            Log.d(TAG, "Self-throttled — next bulk-sync allowed at $nextAllowedAt")
            return Result.success()
        }

        val dbHelper = CallSyncQueueDbHelper.getInstance(applicationContext)
        val pending = dbHelper.unsyncedEvents()
        if (pending.isEmpty()) return Result.success()

        val api = BackendApi(authPrefs)
        return when (val result = api.bulkSync(pending)) {
            is BulkSyncResult.Success -> {
                // Two kinds of rows can be pending here, treated differently:
                //
                // - Rows from CallEventBridge's real-time onCallRemoved path
                //   have hardwareId = null (no CallLog `_ID` cross-reference
                //   available at that point) — there's no per-entry
                //   confirmation signal for these, so they're trusted on any
                //   2xx, same as this worker always has. The backend's
                //   unique constraint on `callSessionId` makes a duplicate
                //   resend harmless even if this over-trusts an entry the
                //   server silently skipped.
                // - Rows from CallLogReconciler DO have a real hardwareId
                //   (the CallLog row's own `_ID`), so — same as
                //   Dad-call-recorder's CallSyncWorker — they only get
                //   marked synced if the server actually confirmed them in
                //   syncedHardwareIds; anything else stays queued and is
                //   retried next time instead of silently vanishing.
                val confirmedIds = pending.filter { event ->
                    event.hardwareId.isNullOrBlank() || event.hardwareId in result.syncedHardwareIds
                }.map { it.id }
                dbHelper.markSynced(confirmedIds)
                dbHelper.pruneSynced()
                prefs.edit().putLong(KEY_NEXT_ALLOWED_AT, System.currentTimeMillis() + COOLDOWN_MS).apply()
                Log.i(TAG, "${confirmedIds.size} call(s) synced")
                Result.success()
            }
            is BulkSyncResult.RateLimited -> {
                prefs.edit()
                    .putLong(KEY_NEXT_ALLOWED_AT, System.currentTimeMillis() + result.retryAfterSeconds * 1000L)
                    .apply()
                Result.retry()
            }
            BulkSyncResult.Failed -> Result.retry()
        }
    }

    companion object {
        private const val TAG = "DialerSyncWorker"
        private const val WORK_NAME = "dialer_sync"
        private const val PERIODIC_WORK_NAME = "dialer_sync_periodic"
        private const val THROTTLE_PREFS = "dialer_sync_throttle"
        private const val KEY_NEXT_ALLOWED_AT = "next_bulk_sync_allowed_at"
        // Matches Dad-backend's androidRoutes.ts BULK_SYNC_COOLDOWN_MS —
        // keep these two in sync (this is only the client's own optimistic
        // self-throttle so it doesn't even attempt a run it knows will
        // 429; the server's own limiter is still the real enforcement, and
        // BulkSyncResult.RateLimited's retryAfterSeconds always overrides
        // this on an actual 429 regardless of what's hardcoded here).
        private const val COOLDOWN_MS = 30 * 1000L

        private fun networkConstraints() =
            Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()

        /** Fired right after a call ends with something queued.
         * `setExpedited()` — same fix as Dad-call-recorder's
         * `CallSyncWorker.scheduleNow()` — bypasses standard Doze/App
         * Standby deferral, which otherwise can delay a plain
         * OneTimeWorkRequest by hours on an idle device (root cause of the
         * "call count only updates by evening" complaint). */
        fun scheduleNow(context: Context) {
            val request = OneTimeWorkRequestBuilder<DialerSyncWorker>()
                .setConstraints(networkConstraints())
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
                .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                .build()
            WorkManager.getInstance(context)
                .enqueueUniqueWork(WORK_NAME, ExistingWorkPolicy.REPLACE, request)
        }

        /** 15-minute periodic safety net (WorkManager's minimum period) so a
         * call queued while offline is eventually swept up even with no
         * later call to trigger [scheduleNow]. */
        fun schedulePeriodic(context: Context) {
            val request = PeriodicWorkRequestBuilder<DialerSyncWorker>(15, TimeUnit.MINUTES)
                .setConstraints(networkConstraints())
                .build()
            WorkManager.getInstance(context)
                .enqueueUniquePeriodicWork(PERIODIC_WORK_NAME, ExistingPeriodicWorkPolicy.KEEP, request)
        }
    }
}
