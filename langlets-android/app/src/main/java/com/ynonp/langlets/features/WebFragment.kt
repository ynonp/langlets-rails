package com.ynonp.langlets.features

import android.os.Bundle
import android.view.View
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.doOnAttach
import androidx.core.view.isVisible
import com.ynonp.langlets.Langlets
import dev.hotwire.navigation.destinations.HotwireDestinationDeepLink
import dev.hotwire.navigation.fragments.HotwireWebFragment

/**
 * The default destination for every web page.
 *
 * Its whole job beyond the stock [HotwireWebFragment] is deciding whether this
 * screen gets a native app bar, and paying the system-bar insets the WebView
 * never hears about.
 *
 * **Why a tab root has no app bar.** The app's web layout draws its own header —
 * the wordmark, the profile menu — and `body` already pads
 * `env(safe-area-inset-top)` so it can sit under the system bar. Stacking a
 * native toolbar on top of that gives two headers and a title the design never
 * asked for. Pushed screens are the opposite case: they need somewhere for the
 * back arrow to live, so they keep the bar.
 *
 * **Why the insets have to be paid natively.** On iOS the web view's safe-area
 * insets include the nav bar and the home indicator, so the page's own
 * `env(safe-area-inset-*)` rules do all the work. Android's WebView only reports
 * *display cutout* insets through those CSS variables — never the status bar,
 * never the gesture bar — so on a device without a notch every one of them is 0
 * and content renders behind the clock at the top and the gesture pill at the
 * bottom. Feeding the real window insets in as padding puts them back, and
 * because the CSS values stay 0 there is nothing to double up with.
 *
 * Each edge is paid only where nothing else already covers it, which is why the
 * conditions differ per side; see [applyWindowInsets].
 */
@HotwireDestinationDeepLink(uri = "hotwire://fragment/web")
open class WebFragment : HotwireWebFragment() {
    /**
     * Whether this screen shows the native app bar. A tab root does not; anything
     * pushed on top of one does, because that is where the back arrow lives.
     * [LessonFragment] overrides this to keep a bar for its close control even
     * though it is the first screen in its modal context.
     */
    open val showsAppBar: Boolean
        get() = !navigator.isAtStartDestination()

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        view.setBackgroundColor(Langlets.backgroundColor)
        // The library's own id, not this app's — `android.nonTransitiveRClass` keeps
        // the two R classes separate, and hotwire_fragment_web.xml is where the
        // AppBarLayout is declared.
        view.findViewById<View>(dev.hotwire.navigation.R.id.app_bar)?.isVisible = showsAppBar

        applyWindowInsets(view)
    }

    /**
     * Inset the page by whatever the system bars cover and nothing else has
     * already accounted for.
     *
     * - **Top**, only without an app bar. The AppBarLayout in
     *   `hotwire_fragment_web.xml` declares `fitsSystemWindows`, so when it is on
     *   screen it pays the status bar itself and padding here as well would
     *   double it.
     * - **Bottom**, only in a modal context. Everywhere else the bottom
     *   navigation is on screen, drawn over the web view and already padded for
     *   the gesture bar, and the page's own `app-scroll-pad` reserves room for
     *   the whole thing. A modal hides that bar, which leaves the page's own
     *   bottom-pinned action row (a lesson's Next button and its caption) sitting
     *   on the gesture pill.
     * - **Left and right**, always. Zero in portrait; in landscape on a device
     *   with a cutout they are what keeps content out of it.
     */
    private fun applyWindowInsets(view: View) {
        val payTop = !showsAppBar
        val payBottom = isModal

        ViewCompat.setOnApplyWindowInsetsListener(view) { v, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            v.setPadding(
                bars.left,
                if (payTop) bars.top else 0,
                bars.right,
                if (payBottom) bars.bottom else 0
            )
            insets
        }

        // The window's first inset dispatch has usually already happened by the
        // time a fragment reaches onViewCreated, and requesting a new one on a
        // view that is not attached yet is a no-op — so a listener registered
        // here alone never fires and the page renders under the status bar.
        // Waiting for attach is what makes the request land.
        view.doOnAttach { ViewCompat.requestApplyInsets(it) }
    }

    /**
     * Leave the toolbar title empty.
     *
     * The library's default mirrors the page's `document.title` into it, and
     * every page here carries the same site-wide title ("Langlets - Learn
     * Languages Through…"), so the bar would read the same on every screen while
     * saying nothing about the one you are on. The pages already name themselves
     * in their own headers, which is the whole reason a tab root hides this bar;
     * on a pushed screen the bar exists for the back arrow, and a back arrow
     * alone over the dark page is closer to the web design than a truncated
     * brand string.
     */
    override fun shouldObserveTitleChanges(): Boolean = false
}
