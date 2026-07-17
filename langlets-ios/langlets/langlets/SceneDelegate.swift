import HotwireNative
import GoogleSignIn
import UIKit
import WebKit

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

        // Configure Hotwire Native. The /2.0 marks builds with the native tab
        // bar: the server only routes those into the /app screens — 1.x builds
        // keep the web UI (ApplicationController#native_tabs_app?).
        Hotwire.config.applicationUserAgentPrefix = "LangletsNative/2.0"

        // Course lessons are modal flows. Give them an explicit close control
        // while keeping ordinary pages on Hotwire's default controller.
        Hotwire.config.defaultViewController = { url in
            if Self.isCourseLessonURL(url) {
                return LessonViewController(url: url)
            }
            return HotwireWebViewController(url: url)
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
            LanguageSelectionBridgeComponent.self,
            GoogleAuthComponent.self,
            AppleAuthComponent.self,
            TabBadgeComponent.self,
            PushComponent.self
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

        // Listen for language selection from onboarding page
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidSelect(_:)),
            name: .languageDidSelect,
            object: nil
        )

        // Listen for queue badge counts reported by the app screens
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queueBadgeDidChange(_:)),
            name: .queueBadgeDidChange,
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

    private static func isCourseLessonURL(_ url: URL) -> Bool {
        let components = url.path.split(separator: "/")
        return components.count >= 4 &&
            components[0] == "courses" &&
            components[2] == "lessons"
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
        // A link to another tab's root switches tabs instead of pushing that
        // screen onto the current stack — Home's "See all" lands on the real
        // Library tab, and the post-import redirect lands on the real Queue.
        if let index = tabBarController.tabIndex(forPath: proposal.url.path),
           tabBarController.navigator(forTabAt: index) !== navigator {
            // If the proposal came out of a modal (the new-import sheet
            // redirecting to the Queue), the modal stays presented on the
            // source tab because the rejected proposal never dismisses it.
            navigator.rootViewController.presentedViewController?.dismiss(animated: true)
            tabBarController.selectTab(at: index)
            return .reject
        }

        // A visit heading into the auth flow means the session is gone;
        // whatever the other tabs show predates it.
        if proposal.url.path.hasPrefix("/users/") {
            tabBarController.setTabsVisible(false)
            tabBarController.reloadOtherTabs(than: navigator)
        }

        return .accept
    }

    @objc private func oauthDidSucceed() {
        // OAuth completed via ASWebAuthenticationSession. Re-route every tab to
        // pick up the session cookie that was set in Safari's cookie store
        // (shared with WKWebsiteDataStore.default()) — re-routing the visible
        // tab also dismisses its sign-in modal.
        tabBarController.reloadAllTabs()
    }

    @objc private func languageDidSelect(_ notification: Notification) {
        // The bridge component already stored the language in UserDefaults, so
        // the tab URLs pick it up. When onboarding was interrupted on its way
        // somewhere specific, honor that redirect in the visible tab.
        if let redirectUrlString = notification.userInfo?["redirectUrl"] as? String,
           let redirectUrl = URL(string: redirectUrlString, relativeTo: rootURL)?.absoluteURL {
            tabBarController.reloadOtherTabs(than: tabBarController.activeNavigator)
            let properties: PathProperties = ["presentation": "replace_root"]
            let proposal = VisitProposal(url: redirectUrl, options: VisitOptions(action: .replace), properties: properties)
            tabBarController.activeNavigator.route(proposal)
        } else {
            tabBarController.reloadAllTabs()
        }
    }

    @objc private func queueBadgeDidChange(_ notification: Notification) {
        guard let count = notification.userInfo?["count"] as? Int else { return }

        // This bridge exists only in the authenticated app layout, so receipt
        // is the native shell's confirmation that tabs are safe to reveal.
        tabBarController.setTabsVisible(true)
        tabBarController.setQueueBadge(count)
    }

    @objc private func userDidSignOut() {
        tabBarController.setTabsVisible(false)
    }

    /// The warm path: a notification tapped while the app was already running.
    /// The cold path is handled in scene(_:willConnectTo:) via connectionOptions.
    @objc private func notificationDidTap(_ notification: Notification) {
        guard let slug = notification.userInfo?["course_slug"] as? String else { return }

        tabBarController.showJustImported(courseSlug: slug)
    }
}
