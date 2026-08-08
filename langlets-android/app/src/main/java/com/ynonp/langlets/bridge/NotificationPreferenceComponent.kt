package com.ynonp.langlets.bridge

import androidx.core.app.NotificationManagerCompat
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.Serializable

/**
 * Renders the Profile screen's notification control from this installation's
 * real Android notification state.
 *
 * The web controller draws nothing useful on its own — it starts with a disabled
 * placeholder and waits for the native reply to tell it whether to show the
 * "Enable" button, the on/off switch, or the "Open Settings" escape hatch for a
 * user who has permanently denied the permission. Without this component
 * registered the control would sit in that placeholder state forever, which is
 * why it is here even though the *delivery* half of push is not.
 *
 * What is missing compared to iOS: a token. The reply carries no `token` field,
 * and `notification_preference_controller.js` skips its POST to
 * `App::DeviceTokensController` when there isn't one. So this reports and
 * changes the OS-level permission honestly, and registers nothing — there is no
 * FCM sender configured for this app yet, so there would be nothing to register.
 * When Firebase is added, replying with the FCM token here is the whole change
 * on this side.
 *
 * Paired with app/javascript/controllers/bridge/notification_preference_controller.js.
 */
class NotificationPreferenceComponent(
    name: String,
    delegate: BridgeDelegate<HotwireDestination>
) : LangletsBridgeComponent(name, delegate) {

    override fun onReceive(message: Message) {
        when (message.event) {
            "status" -> replyTo("status", currentState())
            "setEnabled" -> handleSetEnabled(message)
        }
    }

    private fun handleSetEnabled(message: Message) {
        val data = message.data<SetEnabledData>() ?: return
        val activity = this.activity ?: return

        if (!data.enabled) {
            // Android has no API to revoke a granted permission from inside the
            // app, and there is no token to unregister either. Send the user to
            // the system toggle, which is the only thing that can actually turn
            // notifications off, and report the state unchanged so the switch
            // snaps back rather than lying about what happened.
            activity.openNotificationSettings()
            replyTo("setEnabled", currentState())
            return
        }

        if (activity.notificationsPermanentlyDenied()) {
            // "Enable" on a permanently denied permission cannot prompt — the
            // system stops showing the dialog after a denial — so this is the
            // one path the web side labels "Open Settings".
            activity.openNotificationSettings()
            replyTo("setEnabled", currentState())
            return
        }

        activity.requestNotificationPermission {
            replyTo("setEnabled", currentState())
        }
    }

    private fun currentState(): NotificationState {
        val activity = this.activity
        val granted = activity?.let { NotificationManagerCompat.from(it).areNotificationsEnabled() } == true

        return NotificationState(
            granted = granted,
            denied = activity?.notificationsPermanentlyDenied() == true,
            enabled = granted
        )
    }

    @Serializable
    data class SetEnabledData(val enabled: Boolean)

    @Serializable
    data class NotificationState(
        val granted: Boolean,
        val denied: Boolean,
        val enabled: Boolean
    )
}
