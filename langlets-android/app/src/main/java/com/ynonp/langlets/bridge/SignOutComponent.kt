package com.ynonp.langlets.bridge

import android.webkit.CookieManager
import android.webkit.WebStorage
import com.ynonp.langlets.LanguageStore
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination

/**
 * Wipes local session state after a sign-out.
 *
 * The `signedOut` message is sent from the page the server redirects to after
 * sign-out (`layouts/application`, when `?signed_out=1` is present), so by the
 * time it arrives the server session is already destroyed — clearing local data
 * here cannot race the sign-out request itself.
 *
 * Two things are cleared beyond the cookies:
 *
 * - The stored language. It is what makes the app append `?lang=` to every URL,
 *   so leaving it behind would let the next account (possibly a different
 *   person on a shared device) skip onboarding into someone else's setting.
 *
 * - The tabs. Not for privacy but for correctness: the page that fired this
 *   bridge was rendered under the pre-wipe session, so its forms carry a dead
 *   CSRF token. Reloading is deferred until after the cookie flush completes,
 *   because a reload racing the wipe would lose its fresh session cookie.
 */
class SignOutComponent(
    name: String,
    delegate: BridgeDelegate<HotwireDestination>
) : LangletsBridgeComponent(name, delegate) {

    override fun onReceive(message: Message) {
        if (message.event != "signedOut") return

        LanguageStore.reset()
        WebStorage.getInstance().deleteAllData()

        val activity = this.activity
        activity?.setTabsVisible(false)

        CookieManager.getInstance().removeAllCookies {
            // flush() forces WebKit to write the deletion through to disk.
            // Without it, killing the app right after signing out can resurrect
            // the session and remember-me cookies on the next launch.
            CookieManager.getInstance().flush()
            activity?.runOnUiThread { activity.reloadTabs() }
        }
    }
}
