package com.ynonp.langlets

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.View
import android.webkit.CookieManager
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.SystemBarStyle
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.browser.customtabs.CustomTabColorSchemeParams
import androidx.browser.customtabs.CustomTabsIntent
import androidx.core.app.NotificationManagerCompat
import androidx.core.net.toUri
import com.google.android.material.bottomnavigation.BottomNavigationView
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.NavigatorConfiguration
import dev.hotwire.navigation.tabs.HotwireBottomNavigationController
import dev.hotwire.navigation.tabs.HotwireBottomTab
import dev.hotwire.navigation.tabs.navigatorConfigurations
import dev.hotwire.navigation.util.applyDefaultImeWindowInsets
import java.net.URLEncoder

/**
 * The native shell: four bottom tabs, each owning its own NavigatorHost and
 * therefore its own web view and back stack, so switching tabs is instant and
 * every tab keeps its scroll position and page state.
 *
 * The Android counterpart of iOS's `AppTabBarController` plus the parts of
 * `SceneDelegate` that respond to bridge messages.
 */
class MainActivity : HotwireActivity() {
    private lateinit var bottomNavigationController: HotwireBottomNavigationController

    private var notificationPermissionCallback: (() -> Unit)? = null
    private val notificationPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) {
        notificationPermissionCallback?.invoke()
        notificationPermissionCallback = null
    }

    /**
     * Tab definitions. Recomputed when NavigatorHost rebuilds its graph.
     */
    private val tabs: List<HotwireBottomTab>
        get() = listOf(
            HotwireBottomTab(
                title = getString(R.string.tab_home),
                iconResId = R.drawable.ic_tab_home,
                configuration = NavigatorConfiguration(
                    name = "home",
                    navigatorHostId = R.id.home_navigator_host,
                    startLocation = Langlets.rootUrl + "/app"
                )
            ),
            HotwireBottomTab(
                title = getString(R.string.tab_library),
                iconResId = R.drawable.ic_tab_library,
                configuration = NavigatorConfiguration(
                    name = "library",
                    navigatorHostId = R.id.library_navigator_host,
                    startLocation = Langlets.rootUrl + "/app/library"
                )
            ),
            // Vocabulary sits third, next to Create rather than next to Home: it
            // is where the words the other two tabs produce end up.
            HotwireBottomTab(
                title = getString(R.string.tab_vocabulary),
                iconResId = R.drawable.ic_tab_vocabulary,
                configuration = NavigatorConfiguration(
                    name = "vocabulary",
                    navigatorHostId = R.id.vocabulary_navigator_host,
                    startLocation = Langlets.rootUrl + "/app/vocabulary"
                )
            ),
            // The Create tab's root is the Add-a-video form itself, not a bare
            // /app/import_requests — that collection path only answers POST.
            HotwireBottomTab(
                title = getString(R.string.tab_create),
                iconResId = R.drawable.ic_tab_create,
                configuration = NavigatorConfiguration(
                    name = "create",
                    navigatorHostId = R.id.create_navigator_host,
                    startLocation = Langlets.rootUrl + "/app/import_requests/new"
                )
            )
        )

    override fun navigatorConfigurations() = tabs.navigatorConfigurations

    override fun onCreate(savedInstanceState: Bundle?) {
        // Both bars forced to the dark style, which is what decides the colour of
        // the clock and the battery icon: `dark` means "a dark background is
        // behind me, draw light icons".
        //
        // The bare enableEdgeToEdge() default is `SystemBarStyle.auto(...)`, which
        // follows the *system's* light/dark setting — so on a phone in light mode
        // it draws dark icons over this app's near-black background and the status
        // bar becomes unreadable. The app layout hard-codes data-theme="dark"
        // regardless of the user's preference, so the system bars have to be
        // pinned the same way rather than left to follow it.
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(Color.TRANSPARENT)
        )
        super.onCreate(savedInstanceState)

        setContentView(R.layout.activity_main)
        findViewById<View>(R.id.root).applyDefaultImeWindowInsets()

        initializeBottomTabs()
        handleDeepLink(intent)
        handleShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleDeepLink(intent)
        handleShareIntent(intent)
    }

    /**
     * Opens a YouTube or TikTok share in the Create tab's existing Add Video
     * flow. Provider apps put a URL in EXTRA_TEXT, sometimes surrounded by a
     * title or invitation; [SharedVideoLink] finds and validates that URL.
     *
     * The Create navigator may not exist yet because tabs load lazily. Select it
     * first, then retry briefly until its host is ready before resetting it to a
     * clean Add Video stack with the shared URL prefilled.
     */
    private fun handleShareIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_SEND || intent.type != "text/plain") return

        val videoUrl = SharedVideoLink.firstSupportedUrl(intent.getCharSequenceExtra(Intent.EXTRA_TEXT))
        consumeShareIntent(intent)
        if (videoUrl == null) return

        val encodedUrl = URLEncoder.encode(videoUrl, Charsets.UTF_8.name())
        val location = "${Langlets.rootUrl}/app/import_requests/new?url=$encodedUrl"

        bottomNavigationController.selectTab(CREATE_TAB_INDEX)
        routeSharedVideoWhenReady(location)
    }

    private fun consumeShareIntent(intent: Intent) {
        // MainActivity is singleTask. Clear the payload so recreation cannot
        // replay a share and discard whatever the user did afterwards.
        intent.action = null
        intent.removeExtra(Intent.EXTRA_TEXT)
    }

    private fun routeSharedVideoWhenReady(location: String, attempt: Int = 0) {
        val hostId = tabs[CREATE_TAB_INDEX].configuration.navigatorHostId
        val host = delegate.findNavigatorHost(hostId)

        if (host?.isReady() == true) {
            host.navigator.reset { host.navigator.route(location) }
            return
        }

        if (attempt < SHARE_NAVIGATION_MAX_ATTEMPTS) {
            findViewById<View>(R.id.root).postDelayed(
                { routeSharedVideoWhenReady(location, attempt + 1) },
                SHARE_NAVIGATION_RETRY_MILLIS
            )
        }
    }

    private fun initializeBottomTabs() {
        bottomNavigationController = HotwireBottomNavigationController(
            activity = this,
            view = findViewById<BottomNavigationView>(R.id.bottom_nav),
            // Authentication is established by the first rendered /app page. Keep
            // the navigation out of the signed-out experience until the app
            // layout's tab-badge bridge message says an authenticated screen
            // rendered. Same reason the iOS tab bar starts hidden.
            initialVisibility = HotwireBottomNavigationController.Visibility.HIDDEN,
            // A signed-out cold launch would otherwise fire three parallel visits
            // that all redirect to the sign-in screen, and only the visible tab
            // can actually present it.
            lazyLoadTabs = true
        )
        bottomNavigationController.load(tabs)
    }

    // ------------------------------------------------------------------------
    // Called by the bridge components
    // ------------------------------------------------------------------------

    /**
     * Show or hide the bottom navigation. `tab-badge` (rendered by every
     * authenticated app screen) reveals it; `tab-visibility` from the onboarding
     * layout hides it, because choosing a learning language is mandatory and
     * every tab behind it just redirects back into the flow.
     */
    fun setTabsVisible(visible: Boolean) {
        bottomNavigationController.visibility = if (visible) {
            HotwireBottomNavigationController.Visibility.DEFAULT
        } else {
            HotwireBottomNavigationController.Visibility.HIDDEN
        }
    }

    /**
     * Rebuild every tab that has already loaded, and optionally send the visible
     * one somewhere specific afterwards.
     *
     * Called whenever the server-side session changed underneath the web views —
     * sign-in or sign-out — since from that moment every tab's
     * content is stale and, worse, carries a CSRF token from a session that no
     * longer exists.
     *
     * Tabs that have never been selected are skipped rather than reloaded: they
     * have no graph yet, and when they are first selected they will build one
     * from a freshly computed [tabs], which already has the new `?lang=`. That is
     * the same laziness the iOS `needsRoute` flags provide.
     */
    fun reloadTabs(redirectUrl: String? = null) {
        val currentHostId = bottomNavigationController.currentTab.configuration.navigatorHostId

        tabs.forEach { tab ->
            val hostId = tab.configuration.navigatorHostId
            val host = delegate.findNavigatorHost(hostId) ?: return@forEach
            if (!host.isReady()) return@forEach

            host.navigator.reset {
                if (hostId == currentHostId && redirectUrl != null) {
                    host.navigator.route(redirectUrl)
                }
            }
        }
    }

    /**
     * Reload a retained tab after another tab changes state it displays. An
     * unvisited tab has no navigator yet and will fetch fresh content naturally
     * when first selected.
     */
    fun refreshTab(tab: String) {
        val configuration = tabs
            .map { it.configuration }
            .firstOrNull { it.name.equals(tab, ignoreCase = true) }
            ?: return

        delegate.findNavigatorHost(configuration.navigatorHostId)
            ?.takeIf { it.isReady() }
            ?.navigator
            ?.reset()
    }

    /**
     * OAuth finished. Rails answers a native sign-in with a redirect to
     * `langlets://auth-success`, which the library's non-http route handler turns
     * into an Intent back into this Activity.
     *
     * Two shapes arrive here, and the difference is which cookie jar the session
     * ended up in:
     *
     * - **With a `handoff` token** — GitHub and Apple, which ran their whole
     *   flow in a Chrome Custom Tab and are therefore signed in *there*. The
     *   token has to be spent before anything is reloaded, or every tab would
     *   just re-render the signed-out pages it already had. See [AuthHandoff].
     *
     * - **Without one** — Google, whose credential was obtained natively and
     *   posted from the web view itself, so the session cookie is already where
     *   it needs to be and only the stale pages remain.
     */
    private fun handleDeepLink(intent: Intent?) {
        val uri = intent?.data ?: return
        if (uri.scheme != "langlets") return

        when (uri.host) {
            "auth-success" -> {
                val token = uri.getQueryParameter("handoff")
                val verifier = if (token != null) AuthHandoff.takeVerifier() else null

                if (token != null && verifier != null) {
                    redeemHandoff(token, verifier)
                } else {
                    reloadTabs()
                }
            }
            // langlets://auth-failure — the sign-in screen is still on screen
            // behind this and already shows the server's flash message. Drop any
            // verifier the abandoned flow left behind so it cannot be spent by a
            // deep link that arrives afterwards.
            "auth-failure" -> AuthHandoff.forget()
            else -> Unit
        }

        // Don't replay it if the Activity is recreated (rotation, process death).
        intent.data = null
    }

    /**
     * Open a provider's sign-in in a Chrome Custom Tab. Called by
     * [com.ynonp.langlets.bridge.WebAuthComponent] when the user taps GitHub or
     * Apple; [AuthHandoff] explains why the browser rather than the web view.
     *
     * Launched from this Activity, and therefore into this Activity's task,
     * which is what lets the server's closing `langlets://auth-success` redirect
     * come back to a `singleTask` MainActivity and clear the Custom Tab off the
     * top on its way in. Launch it from the application context instead and the
     * tab ends up in a task of its own, left behind in the recents list after
     * sign-in finishes.
     */
    fun startBrowserSignIn(provider: String) {
        val colors = CustomTabColorSchemeParams.Builder()
            .setToolbarColor(Langlets.backgroundColor)
            .setNavigationBarColor(Langlets.backgroundColor)
            .build()

        val intent = CustomTabsIntent.Builder()
            .setShowTitle(true)
            // Nothing on a sign-in page is worth sharing, and the entry it adds
            // to the overflow menu is one more way out of a flow that should go
            // forward or be dismissed.
            .setShareState(CustomTabsIntent.SHARE_STATE_OFF)
            .setUrlBarHidingEnabled(false)
            .setDefaultColorSchemeParams(colors)
            .build()

        try {
            intent.launchUrl(this, AuthHandoff.begin(provider).toUri())
        } catch (e: ActivityNotFoundException) {
            // No browser at all on the device. `launchUrl` already falls back to
            // a plain VIEW intent when the browser simply lacks Custom Tabs
            // support, so reaching here means there is nothing to fall back to
            // and the flow cannot start. Drop the verifier rather than leave it
            // for a deep link that will never come.
            Log.w(TAG, "No browser available to sign in with $provider", e)
            AuthHandoff.forget()
        }
    }

    /**
     * Spend a handoff token, which is the moment the session finally exists in
     * this app's cookie jar, and only then rebuild the tabs.
     *
     * **Why a throwaway WebView.** Android's [CookieManager] is process-global:
     * cookies stored by any WebView in this process are the tab WebViews'
     * cookies. So the cheapest correct way to move a session in is to let a
     * WebView make the request and handle `Set-Cookie` itself — no parsing of
     * headers, no guessing at attributes, no second implementation of cookie
     * semantics to keep in step with the first.
     *
     * **Why not just navigate a tab there.** Because the answer is a bare
     * acknowledgement page, and a Turbo visit that lands on one would leave it
     * on screen in place of the sign-in root. The tabs need a full reset regardless
     * — every page they hold was rendered for a signed-out visitor and carries a
     * CSRF token from a session that no longer exists — so the request is better
     * made somewhere invisible with the reset sequenced explicitly after it.
     *
     * The reset runs on any outcome, including failure. A spent-or-rejected
     * token leaves the user signed out, and reloading then simply re-renders the
     * sign-in screen, which is the correct place for them to be; hanging on to
     * stale pages instead would not be.
     */
    private fun redeemHandoff(token: String, verifier: String) {
        val webView = WebView(this)
        var settled = false

        // A plain Handler, not `webView.post*`. A View that was never added to a
        // window has no AttachInfo, so View.post queues the work until it is
        // attached — which for this WebView is never, and the watchdog below
        // would simply not exist.
        val handler = Handler(Looper.getMainLooper())

        // Named for what it does rather than `finish()`, which on an Activity
        // already means something rather different.
        fun completeHandoff() {
            if (settled) return
            settled = true

            CookieManager.getInstance().flush()
            handler.removeCallbacksAndMessages(null)

            // Callers are WebView callbacks, and tearing a WebView down from
            // inside one of its own callbacks is how you get a native crash.
            // Posting lets the call stack unwind first. `stopLoading` matters on
            // the watchdog path, where the request this is abandoning is still
            // in flight.
            handler.post {
                webView.stopLoading()
                webView.destroy()
            }

            reloadTabs()
        }

        // A watchdog, because every other path out of here depends on the
        // network answering. Without it a request that never completes leaves
        // the user looking at a sign-in form they already signed in on.
        handler.postDelayed({
            Log.w(TAG, "Sign-in handoff timed out")
            completeHandoff()
        }, HANDOFF_TIMEOUT_MILLIS)

        webView.settings.javaScriptEnabled = false
        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView, url: String) {
                completeHandoff()
            }

            override fun onReceivedError(
                view: WebView,
                request: WebResourceRequest,
                error: WebResourceError
            ) {
                if (!request.isForMainFrame) return

                Log.w(TAG, "Sign-in handoff failed: ${error.errorCode}")
                completeHandoff()
            }
        }

        CookieManager.getInstance().setAcceptCookie(true)
        webView.loadUrl(AuthHandoff.redemptionUrl(token, verifier))
    }

    /**
     * True when this visit is the moment authentication succeeded: we are on an
     * auth screen and the server is sending us somewhere else.
     *
     * The caller cancels the visit and resets the tabs instead of following it,
     * which is the only thing that works here — and the reason is a shape worth
     * understanding rather than a quirk to memorise.
     *
     * A cold launch starts the Home navigator at `/app`. The server bounces a
     * signed-out request to `/users/sign_in`, Hotwire treats that as a cold-boot
     * redirect, and a cold-boot redirect uses `REPLACE` — so the sign-in page
     * does not sit *on top of* the tab root, it **becomes** the tab root, in
     * modal context. Dismissing it afterwards is then a no-op: Navigation
     * Component will not pop a graph's start destination, so
     * `dismissModalContextWithResult` pops nothing, the visit is swallowed, and
     * a sign-in that fully succeeded leaves the user staring at the sign-in
     * form. (The tell is that the system back button quits the app from that
     * screen — there is nothing underneath.)
     *
     * Resetting sidesteps all of it by rebuilding each navigator's graph from a
     * freshly computed start URL, which is where the server was sending us
     * anyway. It also happens to be right for a second reason, the one iOS
     * resets for: every tab's content was rendered for a signed-out visitor and
     * carries a CSRF token from a session that no longer exists.
     */
    fun isLeavingAuthFlow(destination: String): Boolean {
        val current = delegate.currentNavigator?.location ?: return false

        return isAuthPath(current) && !isAuthPath(destination)
    }

    private fun isAuthPath(location: String): Boolean {
        val path = location.toUri().path.orEmpty()

        return path.startsWith("/users/auth/") ||
            path == "/users/sign_in" ||
            path == "/users/sign_up" ||
            path == "/users/password/new"
    }

    /** Keep native chrome in step with every proposed visit. */
    fun observeProposedLocation(location: String) {
        if (isAuthPath(location)) {
            setTabsVisible(false)
        }

        if (isSignedOutRedirect(location)) {
            setTabsVisible(false)
        }
    }

    // ------------------------------------------------------------------------
    // Notification permission, for NotificationPreferenceComponent
    // ------------------------------------------------------------------------

    /**
     * Ask for POST_NOTIFICATIONS and report the outcome.
     *
     * The launcher has to be registered before the Activity starts, which is why
     * this lives here rather than in the bridge component that wants it — a
     * component is constructed when its web page connects, long after that.
     *
     * On API 32 and below the permission does not exist and is granted at
     * install time, so the callback runs immediately with the current state.
     */
    fun requestNotificationPermission(onResult: () -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            onResult()
            return
        }

        notificationPermissionCallback = onResult
        notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
    }

    /**
     * Whether the system will refuse to show the permission dialog again.
     *
     * Android reports this the same way it reports "never asked": the permission
     * is not granted and no rationale should be shown. The difference is that a
     * user who has never been asked hasn't reached the Profile screen's control
     * yet, so treating the ambiguous case as "denied" only mislabels a state the
     * user cannot currently see.
     */
    fun notificationsPermanentlyDenied(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return false
        if (NotificationManagerCompat.from(this).areNotificationsEnabled()) return false

        return !shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS)
    }

    /** Opens this app's notification page in system Settings. */
    fun openNotificationSettings() {
        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        startActivity(intent)
    }

    /**
     * Land on the Home tab, reset to its root. Resetting rather than just
     * selecting matters: the tab's web view is still showing whatever page it was
     * left on, so selecting alone would return the user to, say, their profile.
     */
    fun returnHome() {
        bottomNavigationController.selectTab(HOME_TAB_INDEX)

        val hostId = tabs[HOME_TAB_INDEX].configuration.navigatorHostId
        delegate.findNavigatorHost(hostId)
            ?.takeIf { it.isReady() }
            ?.navigator
            ?.reset()
    }

    private fun isSignedOutRedirect(location: String): Boolean {
        val uri = location.toUri()
        return uri.path == "/users/sign_in" && uri.getQueryParameter("signed_out") == "1"
    }

    companion object {
        const val HOME_TAB_INDEX = 0
        const val CREATE_TAB_INDEX = 3

        private const val TAG = "MainActivity"
        private const val SHARE_NAVIGATION_MAX_ATTEMPTS = 40
        private const val SHARE_NAVIGATION_RETRY_MILLIS = 50L

        /**
         * How long to wait for the handoff request before giving up and
         * reloading anyway. One short request against an endpoint that renders
         * nothing; if it has not answered by now it is not going to.
         */
        private const val HANDOFF_TIMEOUT_MILLIS = 15_000L
    }
}
