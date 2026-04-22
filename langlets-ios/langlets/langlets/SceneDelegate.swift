import HotwireNative
import UIKit

let rootURL = URL(string: "https://langlets.app")!

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private var startLocation: URL {
        var url = rootURL
        if let lang = UserDefaults.standard.string(forKey: "selectedLanguage") {
            url = url.appending(queryItems: [URLQueryItem(name: "lang", value: lang)])
        }
        return url
    }

    private lazy var navigator = Navigator(
        configuration: .init(name: "main", startLocation: startLocation),
        delegate: self
    )

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // Configure Hotwire Native
        Hotwire.config.applicationUserAgentPrefix = "LangletsNative/1.0"

        #if DEBUG
        Hotwire.config.debugLoggingEnabled = true
        #endif

        // Register bridge components (must happen before navigator.start())
        Hotwire.registerBridgeComponents([
            ProgressHapticComponent.self,
            AudioFeedbackComponent.self,
            SignOutComponent.self,
            AuthBridgeComponent.self,
            LanguageSelectionBridgeComponent.self
        ])

        // Load path configuration
        if let pathConfigURL = Bundle.main.url(forResource: "path_configuration", withExtension: "json") {
            Hotwire.loadPathConfiguration(from: [.file(pathConfigURL)])
        }

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = navigator.rootViewController
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

        navigator.start()
    }

    // Handle deep links (OAuth callbacks via custom URL scheme)
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url,
              url.scheme == "langlets" else { return }

        if url.host == "auth-success" {
            // OAuth completed — navigate to homepage
            navigator.route(startLocation)
        }
    }
}

// MARK: - NavigatorDelegate

extension SceneDelegate: NavigatorDelegate {
    func handle(proposal: VisitProposal) -> UIViewController? {
        // No native screens in v1 — all routes render in web view
        return nil
    }

    @objc private func oauthDidSucceed() {
        // OAuth completed via ASWebAuthenticationSession.
        // The session cookie is now in Safari's cookie store,
        // which is shared with WKWebsiteDataStore.default().
        navigator.route(startLocation)
    }

    @objc private func languageDidSelect(_ notification: Notification) {
        guard let language = notification.userInfo?["language"] as? String else { return }

        if let redirectUrlString = notification.userInfo?["redirectUrl"] as? String,
           let redirectUrl = URL(string: redirectUrlString) {
            navigator.route(redirectUrl)
        } else {
            var url = rootURL
            url = url.appending(queryItems: [URLQueryItem(name: "lang", value: language)])
            navigator.route(url)
        }
    }
}

