package com.ynonp.langlets

import android.content.Context
import android.util.AttributeSet
import dev.hotwire.core.turbo.webview.HotwireWebView

/**
 * The app's WebView. Two departures from the stock [HotwireWebView], both of
 * which the iOS app makes as well in `Hotwire.config.makeCustomWebView`:
 *
 * 1. It paints `--color-app-bg` rather than white. A WebView shows its own
 *    background between being attached and painting its first frame, and a white
 *    flash into a hard-coded-dark app layout is very visible.
 *
 * 2. Media may start without a user gesture. Every lesson activity plays
 *    sentence and token audio in response to the page's own logic, and the
 *    default policy — which counts only a tap on the media element itself as a
 *    gesture — blocks all of it. This is the counterpart of
 *    `mediaTypesRequiringUserActionForPlayback = []` on iOS.
 */
class LangletsWebView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null
) : HotwireWebView(context, attrs) {
    init {
        setBackgroundColor(Langlets.backgroundColor)
        settings.mediaPlaybackRequiresUserGesture = false
    }
}
