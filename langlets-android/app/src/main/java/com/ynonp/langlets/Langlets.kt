package com.ynonp.langlets

import android.graphics.Color
import java.net.URI

/**
 * Where the app points and what colour it paints while waiting.
 *
 * Debug builds talk to the Rails server on this Mac; release builds always talk
 * to production. Behind [BuildConfig.DEBUG] rather than a line you comment out by
 * hand, because the hand-edited version only has to be forgotten once to ship a
 * Play Store build that points at a developer's laptop. This mirrors the same
 * decision in the iOS SceneDelegate.
 *
 * The emulator does NOT share the host's network stack the way the iOS simulator
 * does — inside the emulator, `localhost` is the emulator. 10.0.2.2 is the
 * emulator's alias for the host machine's loopback, so `bin/dev` on port 3000 is
 * reachable there. A physical device needs the Mac's LAN IP instead. Plain http
 * to that address is blocked by Android's default network security policy, which
 * is what res/xml/network_security_config.xml exists to permit.
 */
object Langlets {
    val rootUrl: String = if (BuildConfig.DEBUG) {
        "http://10.0.2.2:3000"
    } else {
        "https://langlets.app"
    }

    /**
     * `--color-app-bg`. Painted on the window, the navigator hosts and the web
     * views themselves so a tab that hasn't rendered yet shows the app's dark
     * background instead of the WebView's default white.
     */
    val backgroundColor: Int = Color.parseColor("#0A1521")

    /**
     * The marker Rails uses to recognize a native shell
     * (`ApplicationController#native_app?`). It is deliberately the same string
     * the iOS app sends: every native client routes to the shared `/app` web
     * content, and there is no version- or platform-specific native routing on
     * the server.
     */
    const val USER_AGENT_PREFIX = "LangletsNative"

    /**
     * Resolve a location that may be relative against [rootUrl].
     *
     * Rails hands the native side relative paths in a few places — the language
     * bridge's `redirectUrl` is `/profile?lang=fr`, not a full URL — and every
     * navigation API here wants an absolute one. Worse, a relative string does
     * not merely fail: it has no host, so it matches neither the in-app route
     * decision handler nor the browser-tab one, falls through to system
     * navigation, and is quietly dropped as an unlaunchable Intent. The symptom
     * is a tap that does nothing at all.
     *
     * iOS resolves the same values with `URL(string:relativeTo:)`.
     */
    fun absoluteUrl(location: String): String {
        return try {
            URI(rootUrl).resolve(location).toString()
        } catch (e: IllegalArgumentException) {
            location
        }
    }
}
