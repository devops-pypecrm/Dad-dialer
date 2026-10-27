package com.pypecrm.dialer

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.core.content.ContextCompat
import com.pypecrm.dialer.calllog.CallLogReader
import com.pypecrm.dialer.data.CallSettingsCache
import com.pypecrm.dialer.data.NativeAuthPrefs
import com.pypecrm.dialer.data.RecordingStatusStore
import com.pypecrm.dialer.debug.EngineDebugLog
import com.pypecrm.dialer.permissions.DialerPermissions
import com.pypecrm.dialer.role.DefaultDialerRoleManager
import com.pypecrm.dialer.sync.DialerSyncWorker
import com.pypecrm.dialer.telecom.CallEventBridge
import com.pypecrm.dialer.telecom.CallPlacer
import com.pypecrm.dialer.telecom.DialerInCallService
import com.pypecrm.dialer.telecom.CloudRecordingBridge
import com.pypecrm.dialer.telecom.IncomingCallNotifier
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter's launcher activity. Also carries the DIAL/CALL/VIEW(tel:)
 * intent-filters in the manifest — RoleManager won't offer ROLE_DIALER to
 * an app that can't handle those, regardless of whether InCallService is
 * declared correctly.
 *
 * Since this app has no other reason to be a multi-package Flutter plugin
 * host (a single standalone app, no other consumer — see the approved
 * plan's §4 reasoning), the whole native<->Dart bridge lives directly here
 * rather than in a separate `packages/<name>` plugin the way
 * Dad-call-recorder's `call_recording_engine` does.
 */
class MainActivity : FlutterActivity() {
    private lateinit var roleManager: DefaultDialerRoleManager
    private var pendingRoleResult: MethodChannel.Result? = null
    private var pendingScreeningResult: MethodChannel.Result? = null
    private var pendingPermissionsResult: MethodChannel.Result? = null
    private var pendingRuntimePermsResult: MethodChannel.Result? = null
    private var methodChannel: MethodChannel? = null

    /** Number from a tel: link (CRM "call" button, contacts, browser) that
     * opened this activity — handed to Dart to pre-fill the keypad. */
    private var pendingDialNumber: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        roleManager = DefaultDialerRoleManager(this)
        applyIncomingCallWindowFlagsIfNeeded(intent)
        pendingDialNumber = dialNumberFrom(intent)
    }

    /** DIAL / VIEW / CALL with a tel: URI -> the number, decoded. */
    private fun dialNumberFrom(intent: android.content.Intent?): String? {
        val action = intent?.action ?: return null
        if (action != android.content.Intent.ACTION_DIAL && action != android.content.Intent.ACTION_VIEW &&
            action != android.content.Intent.ACTION_CALL
        ) return null
        val data = intent.data ?: return null
        if (data.scheme != "tel") return null
        return data.schemeSpecificPart?.takeIf { it.isNotBlank() }
    }

    // `launchMode="singleTop"` means a second launch (e.g. tapping the
    // full-screen-intent notification again, or Android redelivering it)
    // reuses THIS instance via onNewIntent rather than a fresh onCreate —
    // without handling it here too, a call that rings while the app is
    // already open in the background wouldn't get the lock-screen flags
    // applied.
    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        applyIncomingCallWindowFlagsIfNeeded(intent)
        // App already running: push the number to Dart right away.
        dialNumberFrom(intent)?.let { methodChannel?.invokeMethod("dialNumber", it) }
    }

    /** Only set when actually launched FOR an incoming call (see
     * IncomingCallNotifier.EXTRA_INCOMING_CALL) — never on a normal manual
     * app open, which must still respect the lock screen like any other
     * app. This is what makes the full-screen-intent notification actually
     * show the call UI over the lock screen / screen-off, the same way
     * Truecaller's own incoming-call screen does. */
    private fun applyIncomingCallWindowFlagsIfNeeded(intent: android.content.Intent?) {
        if (intent?.getBooleanExtra(IncomingCallNotifier.EXTRA_INCOMING_CALL, false) != true) return
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
        methodChannel!!
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumeLaunchNumber" -> {
                        result.success(pendingDialNumber)
                        pendingDialNumber = null
                    }
                    "selectPhoneAccount" ->
                        result.success(CallEventBridge.selectPhoneAccount(call.argument<Int>("simIndex") ?: 0))
                    "ensureRuntimePermissions" -> handleEnsureRuntimePermissions(result)
                    "isDefaultDialer" -> result.success(roleManager.isDefaultDialer())
                    "requestDialerRole" -> handleRequestDialerRole(result)
                    "isCallScreeningRoleHeld" -> result.success(isCallScreeningRoleHeld())
                    "requestCallScreeningRole" -> handleRequestCallScreeningRole(result)
                    "openAppSettings" -> {
                        roleManager.openAppSettings()
                        result.success(null)
                    }
                    // Real call-recording enablement lives inside the
                    // phone's own native dialer app (its built-in auto-
                    // record toggle, with the standard "this call is being
                    // recorded" announcement) — not something Dad-dialer
                    // can switch on itself without the Accessibility/
                    // RECORD_AUDIO surface this app deliberately never
                    // carries. This opens that real app directly instead
                    // of generic system Settings, using the package
                    // DefaultDialerRoleManager captured the moment before
                    // this app became default.
                    "openOriginalDialerApp" -> {
                        val originalPackage = roleManager.originalDialerPackage()
                        val launchIntent = originalPackage?.let { packageManager.getLaunchIntentForPackage(it) }
                        if (launchIntent != null) {
                            startActivity(launchIntent)
                            result.success(true)
                        } else {
                            // No captured package (or it's no longer
                            // installed) — fall back to generic system
                            // Settings rather than silently doing nothing.
                            try {
                                startActivity(android.content.Intent(android.provider.Settings.ACTION_SETTINGS))
                            } catch (e: Exception) {
                                // Ignore — result.success(false) below still
                                // tells Dart this didn't land anywhere useful.
                            }
                            result.success(false)
                        }
                    }
                    "checkDialerPermissions" -> result.success(DialerPermissions.check(this))
                    "getSimAccounts" -> result.success(CallPlacer.simAccounts(this))
                    // Dial pad's "New contact" / "Add to existing contact"
                    // rows for a typed number nobody has saved yet — hand
                    // off to the system Contacts editor, same as any stock
                    // dialer, instead of re-implementing a contact editor.
                    "openNewContact", "openAddToContact" -> {
                        val number = call.argument<String>("number").orEmpty()
                        val intent = if (call.method == "openNewContact") {
                            android.content.Intent(android.content.Intent.ACTION_INSERT, android.provider.ContactsContract.Contacts.CONTENT_URI)
                        } else {
                            android.content.Intent(android.content.Intent.ACTION_INSERT_OR_EDIT)
                                .setType(android.provider.ContactsContract.Contacts.CONTENT_ITEM_TYPE)
                        }
                        intent.putExtra(android.provider.ContactsContract.Intents.Insert.PHONE, number)
                        try {
                            startActivity(intent)
                            result.success(true)
                        } catch (e: android.content.ActivityNotFoundException) {
                            result.success(false)
                        }
                    }
                    "placeCall" -> {
                        val number = call.argument<String>("number")
                        if (number.isNullOrBlank()) {
                            result.error("bad_args", "number is required", null)
                        } else if (ContextCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE) != PackageManager.PERMISSION_GRANTED) {
                            // Same class of bug as getCallLog above: CALL_PHONE
                            // is only granted via "Set as default dialer," but
                            // Contacts/Recents' own call buttons don't gate on
                            // that (Contacts has its own, separate READ_CONTACTS
                            // request) — a tap there before completing the
                            // dialer-role flow would otherwise crash on the
                            // uncaught SecurityException from placeCall().
                            result.error("permission_denied", "CALL_PHONE not granted", null)
                        } else {
                            CallPlacer.placeCall(this, number, call.argument<Int>("simIndex"))
                            result.success(null)
                        }
                    }
                    "answerCall" -> result.success(CallEventBridge.answer())
                    "rejectCall" -> result.success(CallEventBridge.reject())
                    "endCall" -> result.success(CallEventBridge.endCall())
                    "holdCall" -> result.success(CallEventBridge.holdCall())
                    "resumeCall" -> result.success(CallEventBridge.resumeCall())
                    "sendDtmf" -> {
                        val digit = call.argument<String>("digit")
                        if (digit.isNullOrEmpty()) {
                            result.error("bad_args", "digit is required", null)
                        } else {
                            result.success(CallEventBridge.sendDtmf(digit[0]))
                        }
                    }
                    "setSpeaker" -> {
                        val on = call.argument<Boolean>("on") ?: false
                        DialerInCallService.instance?.applySpeaker(on)
                        result.success(null)
                    }
                    "setMuted" -> {
                        val muted = call.argument<Boolean>("muted") ?: false
                        DialerInCallService.instance?.applyMute(muted)
                        result.success(null)
                    }
                    "isSpeakerOn" -> result.success(CallEventBridge.isSpeakerOn())
                    "isMuted" -> result.success(CallEventBridge.isMuted())
                    "hasActiveCall" -> result.success(CallEventBridge.hasActiveCall())
                    "getCallLog" -> {
                        // READ_CALL_LOG is only ever granted via the "Set as
                        // default dialer" flow (see DialerPermissions's doc
                        // comment on why it's never requested at base app
                        // startup) — a user who hasn't done that yet WILL
                        // hit this. Return a typed error instead of letting
                        // the SecurityException cross the platform channel
                        // as an opaque PlatformException, so Dart can show
                        // a real prompt instead of raw exception text.
                        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) != PackageManager.PERMISSION_GRANTED) {
                            result.error("permission_denied", "READ_CALL_LOG not granted", null)
                        } else {
                            val limit = call.argument<Int>("limit") ?: 200
                            result.success(CallLogReader.readRecent(this, limit))
                        }
                    }
                    // Real Tier 0 recording-found signal (see
                    // RecordingStatusStore's doc comment) — bulk fetch so
                    // Dart can match it against a whole Recents list in one
                    // round trip rather than one call per row.
                    "getRecordedCallEntries" -> {
                        val entries = RecordingStatusStore(this).allEntries().map { (phone, timestamp) ->
                            mapOf("phone" to phone, "timestampMillis" to timestamp)
                        }
                        result.success(mapOf("entries" to entries, "toleranceMs" to RecordingStatusStore.TOLERANCE_MS))
                    }
                    "isNativeRecordingConfirmed" -> result.success(RecordingStatusStore(this).isNativeRecordingConfirmedOnDevice())
                    // Org's actual autoRecordInbound/autoRecordOutbound
                    // setting (admin-controlled, set in the web CRM's Call
                    // Settings page) — read from the same cache Tier 0
                    // gating already uses natively, so the in-call
                    // "Recording" indicator can show real status instead
                    // of guessing.
                    "getCallRecordingOrgSettings" -> result.success(CallSettingsCache(this).statusForDisplay())
                    // Play-safe by design — no deep link into a specific
                    // OEM recorder setting exists universally, and guessing
                    // one per-OEM package would be fragile. Opens the
                    // general system Settings app; the in-call UI's own
                    // copy tells the user what to look for there.
                    "openSystemSettings" -> {
                        try {
                            startActivity(android.content.Intent(android.provider.Settings.ACTION_SETTINGS))
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("open_settings_failed", e.message, null)
                        }
                    }
                    "saveAuthForNative" -> {
                        val token = call.argument<String>("token")
                        val apiBaseUrl = call.argument<String>("apiBaseUrl")
                        if (token.isNullOrEmpty() || apiBaseUrl.isNullOrEmpty()) {
                            result.error("bad_args", "token and apiBaseUrl are required", null)
                        } else {
                            NativeAuthPrefs(this).save(token, apiBaseUrl)
                            DialerSyncWorker.schedulePeriodic(this)
                            result.success(null)
                        }
                    }
                    "clearAuthForNative" -> {
                        NativeAuthPrefs(this).clear()
                        result.success(null)
                    }
                    // Phase 1 carrier-merge feasibility spike only — see
                    // Dad-dialer/CALL_RECORDING_SERVER_METHOD_PLAN.md. Not
                    // part of the normal call flow, gated behind a debug
                    // action in Settings.
                    "runMergeSpike" -> {
                        val bridgeNumber = call.argument<String>("bridgeNumber")
                        val primary = CallEventBridge.currentActiveCallOrNull()
                        if (bridgeNumber.isNullOrBlank()) {
                            result.error("bad_args", "bridgeNumber is required", null)
                        } else if (primary == null) {
                            result.error("no_active_call", "Need one ACTIVE call before starting the spike", null)
                        } else if (ContextCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE) != PackageManager.PERMISSION_GRANTED) {
                            result.error("permission_denied", "CALL_PHONE not granted", null)
                        } else {
                            result.success(CloudRecordingBridge.startManualTest(this, primary, bridgeNumber))
                        }
                    }
                    "getEngineDebugLog" -> result.success(EngineDebugLog(this).readAll())
                    "clearEngineDebugLog" -> {
                        EngineDebugLog(this).clear()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(CallEventBridge)

        // In-app update install flow (see pypecrm/APP_UPDATE_SYSTEM.md) —
        // a separate channel/handler, mirroring Dad-mobile/Dad-call-recorder's
        // own dedicated installer MethodChannel rather than folding this
        // into METHOD_CHANNEL above, since it's a wholly separate concern
        // (update install, not telecom) that those apps also keep split out.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALLER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Below Android 8 (API 26) there's no such per-app grant —
                    // any app can trigger an install, so this is trivially true.
                    "canRequestInstalls" -> {
                        val canInstall = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                            packageManager.canRequestPackageInstalls()
                        } else {
                            true
                        }
                        result.success(canInstall)
                    }
                    // Opens the "Install unknown apps" toggle scoped to this
                    // app specifically. Android doesn't allow granting this
                    // programmatically — the user has to flip it by hand.
                    "openInstallPermissionSettings" -> {
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                            val intent = android.content.Intent(android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = android.net.Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                        }
                        result.success(null)
                    }
                    "installApk" -> {
                        val filePath = call.argument<String>("filePath")
                        if (filePath.isNullOrEmpty()) {
                            result.error("bad_args", "filePath is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val file = java.io.File(filePath)
                            val uri = androidx.core.content.FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
                            val intent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/vnd.android.package-archive")
                                addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                                addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(intent)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("install_failed", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun handleRequestDialerRole(result: MethodChannel.Result) {
        when (val outcome = roleManager.startRequest()) {
            DefaultDialerRoleManager.StartResult.AlreadyDefault ->
                result.success(mapOf("outcome" to "ALREADY_DEFAULT"))
            DefaultDialerRoleManager.StartResult.AlreadyInFlight ->
                result.success(mapOf("outcome" to "ALREADY_IN_FLIGHT"))
            DefaultDialerRoleManager.StartResult.UnsupportedSdk ->
                result.success(mapOf("outcome" to "UNSUPPORTED_SDK"))
            DefaultDialerRoleManager.StartResult.PermanentlyDenied ->
                result.success(mapOf("outcome" to "PERMANENTLY_DENIED"))
            is DefaultDialerRoleManager.StartResult.NeedPermissions -> {
                pendingPermissionsResult = result
                requestPermissions(outcome.permissions, DefaultDialerRoleManager.PERMISSION_REQUEST_CODE)
            }
            is DefaultDialerRoleManager.StartResult.NeedRoleIntent -> {
                pendingRoleResult = result
                startActivityForResult(outcome.intent, DefaultDialerRoleManager.ROLE_REQUEST_CODE)
            }
        }
    }

    /** When the app already holds the dialer role — e.g. it was picked from
     * system Settings instead of our own "Set up" button — Android grants
     * the phone/call-log/contacts permissions with the role but NOT music &
     * audio (needed to find the phone's call recordings) or notifications
     * (needed for the incoming-call screen). Ask for whatever is missing. */
    private fun handleEnsureRuntimePermissions(result: MethodChannel.Result) {
        val missing = DialerPermissions.missing(this)
        when {
            !roleManager.isDefaultDialer() || missing.isEmpty() -> result.success(true)
            pendingRuntimePermsResult != null -> result.success(false)
            else -> {
                pendingRuntimePermsResult = result
                requestPermissions(missing, RUNTIME_PERMS_REQUEST_CODE)
            }
        }
    }

    private fun callScreeningRoleManager(): android.app.role.RoleManager? =
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q)
            getSystemService(android.content.Context.ROLE_SERVICE) as? android.app.role.RoleManager
        else null

    private fun isCallScreeningRoleHeld(): Boolean =
        callScreeningRoleManager()?.isRoleHeld(android.app.role.RoleManager.ROLE_CALL_SCREENING) ?: false

    /** "Caller ID & spam app" role — a plain one-tap system prompt, no extra
     * runtime permissions. Outcome strings reuse the dialer role's wire
     * format. */
    private fun handleRequestCallScreeningRole(result: MethodChannel.Result) {
        val manager = callScreeningRoleManager()
        when {
            manager == null || !manager.isRoleAvailable(android.app.role.RoleManager.ROLE_CALL_SCREENING) ->
                result.success(mapOf("outcome" to "UNSUPPORTED_SDK"))
            manager.isRoleHeld(android.app.role.RoleManager.ROLE_CALL_SCREENING) ->
                result.success(mapOf("outcome" to "ALREADY_DEFAULT"))
            pendingScreeningResult != null ->
                result.success(mapOf("outcome" to "ALREADY_IN_FLIGHT"))
            else -> {
                pendingScreeningResult = result
                startActivityForResult(
                    manager.createRequestRoleIntent(android.app.role.RoleManager.ROLE_CALL_SCREENING),
                    SCREENING_ROLE_REQUEST_CODE,
                )
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == RUNTIME_PERMS_REQUEST_CODE) {
            val pending = pendingRuntimePermsResult
            pendingRuntimePermsResult = null
            pending?.success(grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED })
            return
        }
        if (requestCode != DefaultDialerRoleManager.PERMISSION_REQUEST_CODE) return
        roleManager.onPermissionsResult()
        val result = pendingPermissionsResult
        pendingPermissionsResult = null

        val allGranted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        if (!allGranted) {
            result?.success(mapOf("outcome" to "PERMISSIONS_DENIED"))
            return
        }
        // Permissions are in now — immediately continue to the role intent
        // rather than making the user tap "Set as default" a second time.
        when (val outcome = roleManager.startRequest()) {
            is DefaultDialerRoleManager.StartResult.NeedRoleIntent -> {
                pendingRoleResult = result
                startActivityForResult(outcome.intent, DefaultDialerRoleManager.ROLE_REQUEST_CODE)
            }
            else -> result?.success(mapOf("outcome" to "PERMISSIONS_GRANTED"))
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == SCREENING_ROLE_REQUEST_CODE) {
            val pending = pendingScreeningResult
            pendingScreeningResult = null
            pending?.success(mapOf("outcome" to if (isCallScreeningRoleHeld()) "GRANTED" else "DENIED"))
            return
        }
        if (requestCode != DefaultDialerRoleManager.ROLE_REQUEST_CODE) return
        roleManager.onRoleResult()
        val result = pendingRoleResult
        pendingRoleResult = null
        result?.success(
            mapOf("outcome" to if (roleManager.isDefaultDialer()) "GRANTED" else "DENIED")
        )
    }

    companion object {
        private const val SCREENING_ROLE_REQUEST_CODE = 5103
        private const val RUNTIME_PERMS_REQUEST_CODE = 5104
        private const val METHOD_CHANNEL = "com.pypecrm.dialer/telecom"
        private const val EVENT_CHANNEL = "com.pypecrm.dialer/call_events"
        private const val INSTALLER_CHANNEL = "com.pypecrm.dialer/installer"
    }
}
