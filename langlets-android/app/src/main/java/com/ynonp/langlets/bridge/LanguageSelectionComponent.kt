package com.ynonp.langlets.bridge

import com.ynonp.langlets.Langlets
import com.ynonp.langlets.LanguageStore
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.Serializable

/**
 * Receives the learning language chosen on the onboarding screen (or changed
 * from the native profile), stores it, and rebuilds the tabs so every start URL
 * carries the new `?lang=`.
 *
 * `redirectUrl` is how a language change from somewhere other than onboarding
 * gets the user back where they were, rather than dropping them on Home: the
 * profile's language select sends the current page's URL with the new parameter
 * already applied.
 *
 * Paired with app/javascript/controllers/bridge/language_selection_controller.js.
 */
class LanguageSelectionComponent(
    name: String,
    delegate: BridgeDelegate<HotwireDestination>
) : LangletsBridgeComponent(name, delegate) {

    override fun onReceive(message: Message) {
        if (message.event != "languageSelected") return
        val data = message.data<MessageData>() ?: return

        LanguageStore.language = data.language
        LanguageStore.clearPendingOnboardingUrl()

        // The web side sends a path, not a URL. See Langlets.absoluteUrl for why
        // passing it through unresolved silently does nothing at all.
        activity?.reloadTabs(redirectUrl = data.redirectUrl?.let { Langlets.absoluteUrl(it) })
    }

    @Serializable
    data class MessageData(
        val language: String,
        val redirectUrl: String? = null
    )
}
