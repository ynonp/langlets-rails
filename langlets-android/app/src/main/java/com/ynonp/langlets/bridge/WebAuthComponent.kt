package com.ynonp.langlets.bridge

import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.Serializable

/**
 * Takes a GitHub or Apple sign-in out of the web view and runs it in the device
 * browser, then brings the resulting session back across. The mechanism, and why
 * it cannot simply happen in the web view, is documented in
 * [com.ynonp.langlets.AuthHandoff].
 *
 * This is the Android stand-in for iOS's `auth-bridge` and `apple-auth`, which
 * are deliberately *not* registered here — see the note in
 * [com.ynonp.langlets.LangletsApplication]. Both platforms' components sit on
 * the same two buttons in `devise/shared/_social_buttons`; only the one whose
 * name the running shell registered is `enabled`, so exactly one fires.
 *
 * Google is not handled here and must not be: it refuses to serve its consent
 * screen to a browser it can tell was launched by an app, which is what
 * [GoogleAuthComponent] and Credential Manager exist for.
 *
 * Paired with app/javascript/controllers/bridge/web_auth_controller.js.
 */
class WebAuthComponent(
    name: String,
    private val delegate: BridgeDelegate<HotwireDestination>
) : LangletsBridgeComponent(name, delegate) {

    override fun onReceive(message: Message) {
        if (message.event != "startOAuth") return

        val data = message.data<MessageData>() ?: return
        // Null only while the fragment is detached, which cannot be the case
        // here: the message came from a tap on a page this fragment is showing.
        val activity = this.activity ?: return

        activity.startBrowserSignIn(data.provider)
    }

    @Serializable
    data class MessageData(val provider: String)
}
