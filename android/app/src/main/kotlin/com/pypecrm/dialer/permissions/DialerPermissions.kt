package com.pypecrm.dialer.permissions

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

/**
 * The dialer-specific runtime permission set — deliberately requested
 * LAZILY, only when the user explicitly taps "Set as default dialer", and
 * NEVER bundled into any base-app onboarding gate.
 *
 * This is a direct fix for a real bug found on the `dialer-version` branch
 * (a separate repo, `Dad-call-recorder`, used only as a reference for this
 * app): an earlier version lumped these into the same "required
 * permissions" list as base app access, so every already-onboarded existing
 * user got bounced back into a permission-request screen on update and got
 * stuck there, since old installs never had these granted. Since this app
 * has no unrelated base functionality gated behind these permissions in the
 * first place (it IS the dialer, there's no separate lesser mode), the fix
 * here is structural: this class is only ever invoked from the "Set as
 * default dialer" flow, never from app startup.
 */
object DialerPermissions {
    val ALL = buildList {
        add(Manifest.permission.CALL_PHONE)
        add(Manifest.permission.ANSWER_PHONE_CALLS)
        add(Manifest.permission.READ_PHONE_STATE)
        add(Manifest.permission.READ_CALL_LOG)
        add(Manifest.permission.READ_CONTACTS)
        // WRITE_CONTACTS only actually needed for the "add number to
        // contact" feature — requested up front with the rest rather than
        // a separate later prompt, since it's the same permission group as
        // READ_CONTACTS and splitting it would just mean asking twice.
        add(Manifest.permission.WRITE_CONTACTS)
        // Tier 0 native-recording recovery (see recording/NativeRecordingScanner.kt)
        // — bundled into this same lazy "Set as default dialer" request
        // rather than a separate prompt, same reasoning as WRITE_CONTACTS
        // above. Split by SDK version like call_recording_engine's own
        // requiredPermissions() does.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            add(Manifest.permission.READ_MEDIA_AUDIO)
            // Android 13+ gates ALL notifications behind a runtime grant,
            // including the full-screen-intent one IncomingCallNotifier
            // posts to actually bring the incoming-call UI up when this
            // app isn't already open — bundled here for the same reason
            // as READ_MEDIA_AUDIO/WRITE_CONTACTS above. Below API 33 no
            // such permission exists at all; the manifest declaration
            // alone is sufficient.
            add(Manifest.permission.POST_NOTIFICATIONS)
        } else {
            add(Manifest.permission.READ_EXTERNAL_STORAGE)
        }
    }.toTypedArray()

    fun check(context: Context): Map<String, Boolean> =
        ALL.associateWith {
            ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED
        }

    fun allGranted(context: Context): Boolean = check(context).values.all { it }

    fun missing(context: Context): Array<String> =
        ALL.filter { ContextCompat.checkSelfPermission(context, it) != PackageManager.PERMISSION_GRANTED }
            .toTypedArray()

    /** True only once the user has been shown the system rationale/prompt
     * before AND `shouldShowRequestPermissionRationale` has gone false again
     * — Android's own signal for "user selected Deny & don't ask again," as
     * opposed to a first-time denial (where the rationale would still show).
     * Callers must persist "has asked before" themselves (see
     * `role/DefaultDialerRoleManager.kt`) since this flag alone can't
     * distinguish "never asked" from "permanently denied" on its own. */
    fun isPermanentlyDenied(activity: Activity, permission: String, hasAskedBefore: Boolean): Boolean {
        val granted = ContextCompat.checkSelfPermission(activity, permission) == PackageManager.PERMISSION_GRANTED
        if (granted) return false
        val showRationale = ActivityCompat.shouldShowRequestPermissionRationale(activity, permission)
        return hasAskedBefore && !showRationale
    }
}
