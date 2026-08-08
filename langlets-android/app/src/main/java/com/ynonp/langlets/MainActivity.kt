package com.ynonp.langlets

import android.Manifest
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.View
import androidx.activity.SystemBarStyle
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.app.NotificationManagerCompat
import androidx.core.net.toUri
import com.google.android.material.bottomnavigation.BottomNavigationView
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.NavigatorConfiguration
import dev.hotwire.navigation.tabs.HotwireBottomNavigationController
import dev.hotwire.navigation.tabs.HotwireBottomTab
import dev.hotwire.navigation.tabs.navigatorConfigurations
import dev.hotwire.navigation.util.applyDefaultImeWindowInsets

/**
 * The native shell: three bottom tabs, each owning its own NavigatorHost and
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
     * Tab definitions. Recomputed on every access rather than held in a `val`,
     * because [NavigatorHost] reads `navigatorConfigurations()` again each time it
     * builds its graph — which is how a tab picks up a language chosen after
     * launch. See [reloadTabs].
     */
    private val tabs: List<HotwireBottomTab>
        get() = listOf(
            HotwireBottomTab(
                title = getString(R.string.tab_home),
                iconResId = R.drawable.ic_tab_home,
                configuration = NavigatorConfiguration(
                    name = "home",
                    navigatorHostId = R.id.home_navigator_host,
                    startLocation = LanguageStore.startUrl("/app")
                )
            ),
            HotwireBottomTab(
                title = getString(R.string.tab_library),
                iconResId = R.drawable.ic_tab_library,
                configuration = NavigatorConfiguration(
                    name = "library",
                    navigatorHostId = R.id.library_navigator_host,
                    startLocation = LanguageStore.startUrl("/app/library")
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
                    startLocation = LanguageStore.startUrl("/app/import_requests/new")
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
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleDeepLink(intent)
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
     * sign-in, sign-out, a language switch — since from that moment every tab's
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
     * OAuth finished. Rails answers a native sign-in with a redirect to
     * `langlets://auth-success`, which the library's non-http route handler turns
     * into an Intent back into this Activity.
     *
     * Unlike iOS there is no browser-to-web-view cookie handoff to wait for: the
     * OAuth flow runs inside the app's own web view (see the note in
     * [LangletsApplication] about why `auth-bridge` is not registered), so the
     * session cookie is already where it needs to be. All that is left is to
     * replace the pages that were rendered before it existed.
     */
    private fun handleDeepLink(intent: Intent?) {
        val uri = intent?.data ?: return
        if (uri.scheme != "langlets") return

        when (uri.host) {
            "auth-success" -> {
                LanguageStore.restoreFrom(uri.toString())
                reloadTabs()
            }
            // langlets://auth-failure — the sign-in screen is still on screen
            // behind this and already shows the server's flash message.
            else -> Unit
        }

        // Don't replay it if the Activity is recreated (rotation, process death).
        intent.data = null
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

    /**
     * Keep device state in step with what the server just told us, then let the
     * caller decide whether that warrants a reload. Called from the navigator's
     * route decision handler, which sees every proposed visit.
     */
    fun observeProposedLocation(location: String) {
        LanguageStore.rememberPendingOnboardingUrl(location)

        if (LanguageStore.restoreFrom(location)) {
            reloadTabs()
        }

        if (isSignedOutRedirect(location)) {
            LanguageStore.reset()
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
    }
}
