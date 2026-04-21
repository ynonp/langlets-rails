import HotwireNative
import UIKit

let rootURL = URL(string: "https://langlets.app")!

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private lazy var navigator = Navigator(
        configuration: .init(name: "main", startLocation: rootURL),
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
            AuthBridgeComponent.self
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

        navigator.start()
    }

    // Handle deep links (OAuth callbacks via custom URL scheme)
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url,
              url.scheme == "langlets" else { return }

        if url.host == "auth-success" {
            // OAuth completed — navigate to homepage
            navigator.route(rootURL)
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
        navigator.route(rootURL)
    }
}

