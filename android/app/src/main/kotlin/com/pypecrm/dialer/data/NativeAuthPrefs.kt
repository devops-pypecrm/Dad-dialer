package com.pypecrm.dialer.data

import android.content.Context

/**
 * JWT + API base URL, duplicated here from Dart's `flutter_secure_storage`
 * so [com.pypecrm.dialer.sync.DialerSyncWorker] (which must keep working
 * with the Flutter engine fully suspended) can authenticate without
 * decrypting flutter_secure_storage's own encrypted store from native code.
 * Exact same pattern as Dad-call-recorder's
 * `data/NativeAuthPrefs.kt` (a separate repo, referenced for its proven
 * shape only — not shared code). Written by `MainActivity`'s
 * `saveAuthForNative`/`clearAuthForNative` MethodChannel handlers, called
 * from `SessionController` right after login/logout.
 */
class NativeAuthPrefs(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun save(token: String, apiBaseUrl: String) {
        prefs.edit()
            .putString(KEY_TOKEN, token)
            .putString(KEY_API_BASE, apiBaseUrl.trimEnd('/'))
            .apply()
    }

    fun clear() {
        prefs.edit().clear().apply()
    }

    val token: String? get() = prefs.getString(KEY_TOKEN, null)
    val apiBaseUrl: String? get() = prefs.getString(KEY_API_BASE, null)

    fun isSignedIn(): Boolean = !token.isNullOrEmpty() && !apiBaseUrl.isNullOrEmpty()

    companion object {
        private const val PREFS_NAME = "dialer_native_auth"
        private const val KEY_TOKEN = "jwt_token"
        private const val KEY_API_BASE = "api_base_url"
    }
}
