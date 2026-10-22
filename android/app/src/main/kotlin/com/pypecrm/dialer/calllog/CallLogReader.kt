package com.pypecrm.dialer.calllog

import android.content.Context
import android.provider.CallLog
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager

/**
 * Reads Android's real `CallLog.Calls` content provider directly — the
 * SINGLE source of truth for the Recents screen. Deliberately does NOT
 * maintain any local shadow copy: the `dialer-version` reference branch's
 * first pass kept a separate local JSON file the dialer code appended to
 * itself, which its own code comments admitted was never reconciled with
 * the real system CallLog — two independent histories describing the same
 * calls. Since this app legitimately holds `READ_CALL_LOG` (it's the
 * default dialer), there's no reason to keep a second copy at all.
 */
object CallLogReader {
    private val PROJECTION = arrayOf(
        CallLog.Calls._ID,
        CallLog.Calls.NUMBER,
        CallLog.Calls.CACHED_NAME,
        CallLog.Calls.TYPE,
        CallLog.Calls.DATE,
        CallLog.Calls.DURATION,
        CallLog.Calls.PHONE_ACCOUNT_ID,
    )

    fun readRecent(context: Context, limit: Int = 200): List<Map<String, Any?>> {
        val results = mutableListOf<Map<String, Any?>>()
        val sortOrder = "${CallLog.Calls.DATE} DESC"

        // Real per-SIM label/slot, sourced from the Telecom framework itself
        // (the same accounts Android's own SIM picker shows) rather than
        // guessed from PHONE_ACCOUNT_ID's raw string — that column's format
        // varies by OEM and isn't meant to be parsed directly. Single-SIM
        // devices (or any id this doesn't recognize) get no SIM info at
        // all, rather than a fabricated "SIM 1" label.
        val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
        val accounts: List<PhoneAccountHandle> = try {
            telecomManager?.callCapablePhoneAccounts ?: emptyList()
        } catch (e: SecurityException) {
            emptyList()
        }
        val slotIndexById = accounts.withIndex().associate { (index, handle) -> handle.id to index }
        val labelById = accounts.associate { handle ->
            handle.id to try {
                telecomManager?.getPhoneAccount(handle)?.label?.toString()
            } catch (e: SecurityException) {
                null
            }
        }
        // Only meaningful on an actual multi-SIM device — a single-account
        // phone showing a "SIM 1" badge on every row would be noise, not
        // real information.
        val showSimInfo = accounts.size > 1

        context.contentResolver.query(CallLog.Calls.CONTENT_URI, PROJECTION, null, null, sortOrder)
            ?.use { cursor ->
                val idCol = cursor.getColumnIndexOrThrow(CallLog.Calls._ID)
                val numberCol = cursor.getColumnIndexOrThrow(CallLog.Calls.NUMBER)
                val nameCol = cursor.getColumnIndexOrThrow(CallLog.Calls.CACHED_NAME)
                val typeCol = cursor.getColumnIndexOrThrow(CallLog.Calls.TYPE)
                val dateCol = cursor.getColumnIndexOrThrow(CallLog.Calls.DATE)
                val durationCol = cursor.getColumnIndexOrThrow(CallLog.Calls.DURATION)
                val phoneAccountIdCol = cursor.getColumnIndexOrThrow(CallLog.Calls.PHONE_ACCOUNT_ID)

                while (cursor.moveToNext() && results.size < limit) {
                    val phoneAccountId = if (showSimInfo) cursor.getString(phoneAccountIdCol) else null
                    results.add(
                        mapOf(
                            "id" to cursor.getLong(idCol).toString(),
                            "number" to cursor.getString(numberCol),
                            "cachedName" to cursor.getString(nameCol),
                            "type" to typeName(cursor.getInt(typeCol)),
                            "dateMillis" to cursor.getLong(dateCol),
                            "durationSeconds" to cursor.getInt(durationCol),
                            "simSlot" to phoneAccountId?.let { slotIndexById[it] },
                            "simLabel" to phoneAccountId?.let { labelById[it] },
                        )
                    )
                }
            }
        return results
    }

    private fun typeName(type: Int): String = when (type) {
        CallLog.Calls.INCOMING_TYPE -> "INCOMING"
        CallLog.Calls.OUTGOING_TYPE -> "OUTGOING"
        CallLog.Calls.MISSED_TYPE -> "MISSED"
        CallLog.Calls.REJECTED_TYPE -> "REJECTED"
        CallLog.Calls.BLOCKED_TYPE -> "BLOCKED"
        else -> "UNKNOWN"
    }
}
