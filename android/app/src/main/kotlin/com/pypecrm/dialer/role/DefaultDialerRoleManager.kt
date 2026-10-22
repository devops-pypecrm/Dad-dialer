package com.pypecrm.dialer.role

import android.app.Activity
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.telecom.TelecomManager
import com.pypecrm.dialer.permissions.DialerPermissions

/**
 * Owns the whole "become the default dialer" flow, with the four fixes the
 * `dialer-version` reference branch (a separate repo, `Dad-call-recorder`)
 * discovered the hard way baked in from day one rather than re-discovered
 * later:
 *
 *  1. Permissions are requested lazily — this class is ONLY invoked from an
 *     explicit user tap on "Set as default dialer," never at app startup or
 *     as any kind of base-app gate (see `DialerPermissions`'s doc comment).
 *  2. [isRequestInFlight] guards against a rapid re-tap superseding (and
 *     thus auto-denying, per Android's own behavior) the in-flight request.
 *  3. Permanently-denied permissions (user chose "Deny & don't ask again")
 *     are detected via [DialerPermissions.isPermanentlyDenied] and routed to
 *     the app's Settings screen instead of silently re-prompting forever.
 *  4. A bounded timeout ([TIMEOUT_MS]) resets [isRequestInFlight] so the UI
 *     can never get stuck waiting for a result that never comes back (e.g.
 *     the user backgrounds the app mid-flow and never returns to the role
 *     picker).
 */
class DefaultDialerRoleManager(private val activity: Activity) {
    private val prefs: SharedPreferences =
        activity.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val timeoutHandler = Handler(Looper.getMainLooper())
    private var timeoutRunnable: Runnable? = null

    var isRequestInFlight: Boolean = false
        private set

    fun isDefaultDialer(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val roleManager = activity.getSystemService(Context.ROLE_SERVICE) as? RoleManager ?: return false
        return roleManager.isRoleHeld(RoleManager.ROLE_DIALER)
    }

    /**
     * Returns a [StartResult] describing what to do next — the caller
     * (MainActivity's MethodChannel handler) is responsible for actually
     * calling `startActivityForResult`/`requestPermissions` since only an
     * Activity can do that; this class decides WHICH one is needed and
     * enforces the guard/timeout/permanently-denied rules around it.
     */
    fun startRequest(): StartResult {
        if (isRequestInFlight) return StartResult.AlreadyInFlight
        if (isDefaultDialer()) return StartResult.AlreadyDefault
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return StartResult.UnsupportedSdk

        val missing = DialerPermissions.missing(activity)
        for (permission in missing) {
            val askedBefore = prefs.getBoolean(askedKey(permission), false)
            if (DialerPermissions.isPermanentlyDenied(activity, permission, askedBefore)) {
                return StartResult.PermanentlyDenied
            }
        }

        if (missing.isNotEmpty()) {
            for (permission in missing) {
                prefs.edit().putBoolean(askedKey(permission), true).apply()
            }
            markInFlight()
            return StartResult.NeedPermissions(missing)
        }

        // Capture whichever app is the default dialer RIGHT NOW, before the
        // role actually changes — this is the one moment that package name
        // is still the phone's own native dialer, not us. Saved so the
        // in-call "Recording" flow can later open that real app directly
        // (its own built-in call-recording toggle lives inside IT, not
        // anything Dad-dialer can control — see the approved plan's
        // Play-compliance stance on why this app never captures audio
        // itself) instead of dropping the user into generic system
        // Settings with no idea which app to look in. Never overwritten
        // once saved — a later re-request (e.g. switching back to this app
        // as default after trying another) would otherwise clobber the
        // real original with our own package name.
        if (!prefs.contains(KEY_ORIGINAL_DIALER_PACKAGE)) {
            val telecomManager = activity.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
            val currentDefault = telecomManager?.defaultDialerPackage
            if (!currentDefault.isNullOrEmpty() && currentDefault != activity.packageName) {
                prefs.edit().putString(KEY_ORIGINAL_DIALER_PACKAGE, currentDefault).apply()
            }
        }

        markInFlight()
        return StartResult.NeedRoleIntent(
            (activity.getSystemService(Context.ROLE_SERVICE) as RoleManager)
                .createRequestRoleIntent(RoleManager.ROLE_DIALER)
        )
    }

    /** The phone's own native dialer package, captured the moment before
     * this app first became the default — null if that was never captured
     * (e.g. this app was already default before this code existed, or the
     * previous default couldn't be determined). */
    fun originalDialerPackage(): String? = prefs.getString(KEY_ORIGINAL_DIALER_PACKAGE, null)

    /** Call after `onRequestPermissionsResult` — if everything's granted
     * now, the caller should immediately call [startRequest] again to
     * proceed to the role intent; [isRequestInFlight] is cleared either way
     * so that follow-up call isn't itself blocked by the guard. */
    fun onPermissionsResult() {
        clearInFlight()
    }

    /** Call after `onActivityResult` for the role-request intent. */
    fun onRoleResult() {
        clearInFlight()
    }

    fun openAppSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", activity.packageName, null)
        }
        activity.startActivity(intent)
    }

    private fun markInFlight() {
        isRequestInFlight = true
        timeoutRunnable?.let { timeoutHandler.removeCallbacks(it) }
        val runnable = Runnable { clearInFlight() }
        timeoutRunnable = runnable
        timeoutHandler.postDelayed(runnable, TIMEOUT_MS)
    }

    private fun clearInFlight() {
        isRequestInFlight = false
        timeoutRunnable?.let { timeoutHandler.removeCallbacks(it) }
        timeoutRunnable = null
    }

    private fun askedKey(permission: String) = "asked_$permission"

    sealed class StartResult {
        data object AlreadyDefault : StartResult()
        data object AlreadyInFlight : StartResult()
        data object UnsupportedSdk : StartResult()
        data object PermanentlyDenied : StartResult()
        data class NeedPermissions(val permissions: Array<String>) : StartResult()
        data class NeedRoleIntent(val intent: Intent) : StartResult()
    }

    companion object {
        private const val PREFS_NAME = "dialer_role_prefs"
        private const val KEY_ORIGINAL_DIALER_PACKAGE = "original_dialer_package"
        private const val TIMEOUT_MS = 30_000L
        const val PERMISSION_REQUEST_CODE = 5101
        const val ROLE_REQUEST_CODE = 5102
    }
}
