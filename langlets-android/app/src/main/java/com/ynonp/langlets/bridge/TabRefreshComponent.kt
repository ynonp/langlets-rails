package com.ynonp.langlets.bridge

import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.Serializable

/** Reloads or selects a retained tab at another webview's request. */
class TabRefreshComponent(
    name: String,
    delegate: BridgeDelegate<HotwireDestination>
) : LangletsBridgeComponent(name, delegate) {

    override fun onReceive(message: Message) {
        val data = message.data<MessageData>() ?: return

        when (message.event) {
            "refresh" -> activity?.refreshTab(data.tab)
            "select" -> activity?.selectTab(data.tab)
        }
    }

    @Serializable
    data class MessageData(val tab: String)
}
