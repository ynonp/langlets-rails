import HotwireNative
import GoogleSignIn
import UIKit
import WebKit

// Debug builds talk to the Rails server on this Mac; release builds always talk
// to production. Behind #if DEBUG rather than a line you comment out by hand,
// because the hand-edited version only has to be forgotten once to ship an App
// Store build that points at localhost.
//
// The simulator shares the Mac's network stack, so localhost is `bin/rails
// server` directly. On a physical device this needs the Mac's LAN IP instead —
// the phone's own localhost is the phone. Plain http to a loopback address is
// blocked by App Transport Security without NSAllowsLocalNetworking in
// Info.plist, which is set for exactly this reason.
let rootURL = URL(string: "https://langlets.app")!
let appBackgroundColor = UIColor(red: 10 / 255, green: 21 / 255, blue: 33 / 255, alpha: 1)

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    // The tab bar controller owns one Navigator per tab. Created lazily so
    // Hotwire.config is fully set up in scene(_:willConnectTo:) before any
    // Navigator (and its webview) exists.
    private lazy var tabBarController = AppTabBarController(navigatorDelegate: self)

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        Hotwire.config.makeCustomWebView = { config in
            config.allowsInlineMediaPlayback = true
            config.mediaTypesRequiringUserActionForPlayback = []
            let webView = WKWebView(frame: .zero, configuration: config)
            webView.isOpaque = false
            webView.backgroundColor = appBackgroundColor
            webView.scrollView.backgroundColor = appBackgroundColor
            return webView
        }

        // Configure Hotwire Native. Rails uses this stable marker to route all
        // iOS shells to the shared /app web content.
        Hotwire.config.applicationUserAgentPrefix = "LangletsNative"

        // Match path configuration rules against the path alone. This defaults
        // to TRUE in Hotwire Native, which means rules are matched against
        // "/app/import_requests/new?lang=es", not "/app/import_requests/new" —
        // so every `$`-anchored pattern in ios_path_configuration.json silently
        // fails the moment a link carries a query string. Nearly all of ours do:
        // the app appends ?lang= to keep the learning language in the URL, which
        // quietly demoted Add a video and the Credits sheet (since deleted along
        // with credit purchases) from medium-detent sheets to plain pushes inside
        // the tab, tab bar overlapping the content and all.
        //
        // Turned off globally rather than patching each pattern with `(\?.*)?$`:
        // that boilerplate is easy to forget on the next rule, and the failure is
        // invisible — you get a screen that works, just presented wrongly.
        Hotwire.config.pathConfiguration.matchQueryStrings = false

        // Course lessons and review lessons are modal flows. Give them an
        // explicit close control while keeping ordinary pages on Hotwire's
        // default controller. Their finish pages use the web screen's single
        // Continue action, so they omit the native navigation bar entirely.
        Hotwire.config.defaultViewController = { url in
            if Self.isLessonFinishURL(url) {
                return LessonFinishViewController(url: url)
            }
            if Self.isLessonURL(url) {
                return LessonViewController(url: url)
            }
            return WebViewController(url: url)
        }

        #if DEBUG
        Hotwire.config.debugLoggingEnabled = true
        #endif

        // Configure Google Sign-In with iOS client ID and web server client ID.
        // The iOS client ID must be created in Google Cloud Console (type: iOS,
        // bundle ID: com.ynonp.langlets). The web client ID is the same one
        // used by the Rails OmniAuth backend.
        let googleConfig = GIDConfiguration(
            clientID: "570385807243-546k3gm681na7d6ds3ft3eqg9hupboc0.apps.googleusercontent.com",
            serverClientID: "570385807243-a77uce7m9eu2i7d8tsbveal8ejpit5d3.apps.googleusercontent.com"
        )
        GIDSignIn.sharedInstance.configuration = googleConfig

        // Register bridge components (must happen before the first navigator starts)
        Hotwire.registerBridgeComponents([
            ProgressHapticComponent.self,
            AudioFeedbackComponent.self,
            SignOutComponent.self,
            AuthBridgeComponent.self,
            GoogleAuthComponent.self,
            AppleAuthComponent.self,
            TabBadgeComponent.self,
            TabRefreshComponent.self,
            TabVisibilityComponent.self,
            PushComponent.self,
            NotificationPreferenceComponent.self,
            NativeTokenComponent.self,
            ApplePurchaseComponent.self
        ])

        // A notification tapped while the app was NOT running arrives here, in
        // connectionOptions — not in the UNUserNotificationCenterDelegate
        // callback. Handling only the delegate drops the deep link for exactly
        // the users who weren't already in the app. Captured now, replayed below
        // once the tab bar exists.
        PushNotifications.shared.handleLaunch(options: connectionOptions)

        // Load path configuration. The bundled file is the offline fallback and
        // seeds the very first launch; the server copy wins once it arrives, so
        // routing rules can change without shipping a new build.
        var pathConfigurationSources: [PathConfiguration.Source] = []
        if let pathConfigURL = Bundle.main.url(forResource: "path_configuration", withExtension: "json") {
            pathConfigurationSources.append(.file(pathConfigURL))
        }
        pathConfigurationSources.append(.server(rootURL.appending(path: "/configurations/ios_v1.json")))
        Hotwire.loadPathConfiguration(from: pathConfigurationSources)

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = tabBarController
        window?.makeKeyAndVisible()

        // Listen for OAuth success notification from AuthService
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(oauthDidSucceed),
            name: .oauthDidSucceed,
            object: nil
        )

        // Listen for queue badge counts reported by the app screens
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queueBadgeDidChange(_:)),
            name: .queueBadgeDidChange,
            object: nil
        )

        // Listen for layouts that hide the tab bar (onboarding)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(tabVisibilityDidChange(_:)),
            name: .tabVisibilityDidChange,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(nativeTabNeedsRefresh(_:)),
            name: .nativeTabNeedsRefresh,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDidSignOut),
            name: .userDidSignOut,
            object: nil
        )

        // Listen for a tapped "your course is ready" notification while running
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(notificationDidTap(_:)),
            name: PushNotifications.didTapNotification,
            object: nil
        )

        tabBarController.start()

        // Replay a notification that launched the app cold, now that the tab bar
        // is up and can be routed.
        if let slug = PushNotifications.shared.consumePendingCourseSlug() {
            tabBarController.showJustImported(courseSlug: slug)
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        PushNotifications.shared.clearAppIconBadge()
    }

    /// Course lesson URLs (`/courses/:course/lessons/:lesson`, plus their
    /// activity and finish variants) and review lesson URLs
    /// (`/review_lessons`, including its activity query and finish variant) —
    /// everything that path configuration presents as a modal
    /// sheet and that should therefore get the native close X.
    private static func isLessonURL(_ url: URL) -> Bool {
        let components = url.path.split(separator: "/")
        guard let first = components.first else { return false }

        if first == "courses" {
            return components.count >= 4 && components[2] == "lessons"
        }

        return first == "review_lessons"
    }

    private static func isLessonFinishURL(_ url: URL) -> Bool {
        isLessonURL(url) && url.path.split(separator: "/").last == "finish"
    }

    // Handle deep links (OAuth callbacks via custom URL scheme)
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }

        // Handle Google Sign-In callback
        if GIDSignIn.sharedInstance.handle(url) {
            return
        }

        if url.scheme == "langlets" && url.host == "auth-success" {
            // OAuth completed — every tab's content predates the session
            oauthDidSucceed()
        }
    }
}

// MARK: - NavigatorDelegate

extension SceneDelegate: NavigatorDelegate {
    func handle(proposal: VisitProposal, from navigator: Navigator) -> ProposalResult {
        if Self.isAuthenticationURL(proposal.url) {
            tabBarController.setTabsVisible(false)
        }

        if proposal.url.path == "/" {
            returnHome(from: navigator)
            return .reject
        }

        return .accept
    }

    private func returnHome(from sourceNavigator: Navigator) {
        let homeIndex = 0
        sourceNavigator.clearAll(animated: false)
        tabBarController.selectedIndex = homeIndex
        tabBarController.activeNavigator.clearAll(animated: false)

        // clearAll only wipes the history stack — the webview still shows
        // whatever page it was on (e.g. /profile). Route to /app so the
        // user actually lands on the home screen.
        tabBarController.routeHomeTab()
    }

    private static func isAuthenticationURL(_ url: URL) -> Bool {
        url.path.hasPrefix("/users/auth/") ||
            url.path == "/users/sign_in" ||
            url.path == "/users/sign_up" ||
            url.path == "/users/password/new"
    }
    
    @objc private func oauthDidSucceed() {
        // OAuth completed via ASWebAuthenticationSession. Re-route every tab to
        // pick up the session cookie that was set in Safari's cookie store
        // (shared with WKWebsiteDataStore.default()) — re-routing the visible
        // tab also replaces its authentication root.
        tabBarController.reloadAllTabs()
    }

    @objc private func queueBadgeDidChange(_ notification: Notification) {
        // Nothing is badged any more — the Library badge is gone, and unread
        // notifications live on the app icon instead. The message is kept
        // because this bridge exists only in the authenticated app layout, so
        // receipt is the native shell's confirmation that tabs are safe to
        // reveal.
        tabBarController.setTabsVisible(true)
    }

    @objc private func tabVisibilityDidChange(_ notification: Notification) {
        guard let visible = notification.userInfo?["visible"] as? Bool else { return }

        tabBarController.setTabsVisible(visible)
    }

    @objc private func nativeTabNeedsRefresh(_ notification: Notification) {
        guard let tab = notification.userInfo?["tab"] as? String else { return }

        tabBarController.refreshTab(named: tab)
    }

    @objc private func userDidSignOut() {
        tabBarController.setTabsVisible(false)

        // The local wipe just finished. The visible page predates it — its
        // form carries a CSRF token from the deleted session — so route every
        // tab back to its (now language-free) root, which lands on a fresh
        // sign-in page with a live session.
        tabBarController.reloadAllTabs()
    }

    /// The warm path: a notification tapped while the app was already running.
    /// The cold path is handled in scene(_:willConnectTo:) via connectionOptions.
    @objc private func notificationDidTap(_ notification: Notification) {
        guard let slug = notification.userInfo?["course_slug"] as? String else { return }

        tabBarController.showJustImported(courseSlug: slug)
    }
}
