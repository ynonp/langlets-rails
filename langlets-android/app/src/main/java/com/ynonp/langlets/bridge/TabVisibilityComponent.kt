package com.ynonp.langlets.bridge

import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.Serializable

/**
 * Lets a web layout declare whether the native tab bar belongs on screen.
 *
 * The onboarding layout sends `visible: false`: picking a learning language is a
 * mandatory, full-screen flow, and tabs under it are both meaningless (every tab
 * redirects straight back to onboarding) and an escape hatch out of it.
 *
 * This is the counterpart to [TabBadgeComponent], which the authenticated app
 * layout sends on every page load and which reveals the tabs again. Both only
 * fire on connect, so each rendered page asserts its own chrome and leaving
 * onboarding — forward or back — restores the tabs without this component having
 * to undo anything.
 *
 * Note this could not be done from the route decision handler: a proposal
 * carries the pre-redirect URL, and an in-app screen server-redirecting to
 * /onboarding/welcome after the tabs were already revealed is exactly the case
 * that motivated the component.
 */
class TabVisibilityComponent(
    name: String,
    delegate: BridgeDelegate<HotwireDestination>
) : LangletsBridgeComponent(name, delegate) {

    override fun onReceive(message: Message) {
        if (message.event != "visibilityChanged") return
        val data = message.data<MessageData>() ?: return

        activity?.setTabsVisible(data.visible)
    }

    @Serializable
    data class MessageData(val visible: Boolean)
}
