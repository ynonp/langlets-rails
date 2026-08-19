package com.ynonp.langlets.bridge

import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.Serializable

/** Reloads a retained tab after another tab changes state it displays. */
class TabRefreshComponent(
    name: String,
    delegate: BridgeDelegate<HotwireDestination>
) : LangletsBridgeComponent(name, delegate) {

    override fun onReceive(message: Message) {
        if (message.event != "refresh") return
        val data = message.data<MessageData>() ?: return

        activity?.refreshTab(data.tab)
    }

    @Serializable
    data class MessageData(val tab: String)
}
