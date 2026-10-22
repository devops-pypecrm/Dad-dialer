package com.pypecrm.dialer.telecom

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.pypecrm.dialer.MainActivity

/**
 * The actual mechanism that gets Dad-dialer's incoming-call UI on screen
 * when the app ISN'T already running/foregrounded. Before this existed,
 * nothing did: [CallEventBridge] only ever reacted to a ringing call by
 * playing the ringtone/vibrating — the Flutter-side `InCallScreen` push
 * (`app.dart`'s `ref.listen(activeCallProvider, ...)`) only fires if the
 * Flutter engine/Activity is already alive to receive the EventChannel
 * message in the first place. A call arriving while the app is closed had
 * literally nothing bring it to the foreground, which is exactly why
 * another caller-ID app's own independent overlay/notification (Truecaller,
 * in the reported case) was the only thing visibly reacting — it has its
 * own always-on mechanism for that, unrelated to which app holds
 * `ROLE_DIALER`.
 *
 * This posts a high-priority, full-screen-intent `Notification` the moment
 * a call starts ringing — the standard Android pattern every real dialer
 * app uses (this app already declared `USE_FULL_SCREEN_INTENT` in its
 * manifest from day one, just never actually used it until now). Android
 * launches the full-screen intent's target Activity automatically,
 * including over the lock screen and on top of whatever else is running,
 * the same way Truecaller's own incoming-call UI does it.
 */
object IncomingCallNotifier {
    private const val CHANNEL_ID = "incoming_calls"
    private const val NOTIFICATION_ID = 7001

    /** Read by [MainActivity] to decide whether to show itself over the
     * lock screen / turn the screen on — only when launched FOR an
     * incoming call, never on a normal manual app open. */
    const val EXTRA_INCOMING_CALL = "com.pypecrm.dialer.EXTRA_INCOMING_CALL"

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Incoming calls",
            // HIGH (not MAX — that's not a real importance level; HIGH is
            // the highest one that actually exists) is what makes this a
            // heads-up notification eligible for a full-screen intent.
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Shows the incoming-call screen when Pype Dialer isn't already open"
            setBypassDnd(true)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
    }

    fun showIncomingCall(context: Context, callerDisplay: String) {
        try {
            ensureChannel(context)
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra(EXTRA_INCOMING_CALL, true)
            }
            val fullScreenPendingIntent = PendingIntent.getActivity(
                context,
                NOTIFICATION_ID,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            val notification = Notification.Builder(context, CHANNEL_ID).apply {
                setContentTitle("Incoming call")
                setContentText(callerDisplay)
                setCategory(Notification.CATEGORY_CALL)
                setOngoing(true)
                setAutoCancel(false)
                setFullScreenIntent(fullScreenPendingIntent, true)
                setContentIntent(fullScreenPendingIntent)
                setSmallIcon(context.applicationInfo.icon)
            }.build()

            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(NOTIFICATION_ID, notification)
        } catch (e: Exception) {
            // Missing POST_NOTIFICATIONS grant (Android 13+) or any other
            // notification-service hiccup must never crash call handling —
            // the ringtone (CallEventBridge.startRinging) still plays
            // either way, this is purely an additional "bring the UI up"
            // mechanism, not the only signal a call is happening.
        }
    }

    fun cancel(context: Context) {
        try {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancel(NOTIFICATION_ID)
        } catch (e: Exception) {
            // Best-effort — a stuck notification is a minor annoyance, not
            // worth crashing anything over.
        }
    }
}
