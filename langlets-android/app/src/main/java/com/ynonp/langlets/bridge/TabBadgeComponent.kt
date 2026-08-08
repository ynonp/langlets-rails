package com.ynonp.langlets.bridge

import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination

/**
 * The app screens' "this page is the authenticated app layout" signal, which is
 * what reveals the bottom navigation.
 *
 * The name is a leftover: it used to carry the Library tab's active-import badge
 * count. Nothing is badged any more — unread notifications live on the app icon
 * instead — and `count` survives only so the message keeps the shape both native
 * shells decode. Receiving it at all is the real payload: `layouts/app.html.erb`
 * renders this controller only for authenticated native screens, so its arrival
 * is proof that navigation is safe to show.
 *
 * Paired with app/javascript/controllers/bridge/tab_badge_controller.js.
 */
class TabBadgeComponent(
    name: String,
    delegate: BridgeDelegate<HotwireDestination>
) : LangletsBridgeComponent(name, delegate) {

    override fun onReceive(message: Message) {
        if (message.event != "badgeChanged") return

        activity?.setTabsVisible(true)
    }
}
