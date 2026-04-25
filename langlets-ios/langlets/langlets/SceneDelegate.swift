import HotwireNative
import GoogleSignIn
import UIKit

let rootURL = URL(string: "https://a8e3-46-120-112-245.ngrok-free.app")!

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

        // Configure Google Sign-In with iOS client ID and web server client ID.
        // The iOS client ID must be created in Google Cloud Console (type: iOS,
        // bundle ID: com.ynonp.langlets). The web client ID is the same one
        // used by the Rails OmniAuth backend.
        let googleConfig = GIDConfiguration(
            clientID: "570385807243-546k3gm681na7d6ds3ft3eqg9hupboc0.apps.googleusercontent.com",
            serverClientID: "570385807243-a77uce7m9eu2i7d8tsbveal8ejpit5d3.apps.googleusercontent.com"
        )
        GIDSignIn.sharedInstance.configuration = googleConfig

        // Register bridge components (must happen before navigator.start())
        Hotwire.registerBridgeComponents([
            ProgressHapticComponent.self,
            AudioFeedbackComponent.self,
            SignOutComponent.self,
            AuthBridgeComponent.self,
            LanguageSelectionBridgeComponent.self,
            GoogleAuthComponent.self
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
        guard let url = URLContexts.first?.url else { return }

        // Handle Google Sign-In callback
        if GIDSignIn.sharedInstance.handle(url) {
            return
        }

        if url.scheme == "langlets" && url.host == "auth-success" {
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
        // Reload the current page to pick up the session cookie
        // that was set in Safari's cookie store (shared with WKWebsiteDataStore.default())
        navigator.reload()
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

