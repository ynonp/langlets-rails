import AuthenticationServices
import UIKit

/// Handles OAuth authentication via ASWebAuthenticationSession.
/// Opens Safari for the OAuth flow (Google/GitHub), then returns to the app
/// via the custom URL scheme "langlets://".
class AuthService: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    /// Starts an OAuth flow by opening Safari via ASWebAuthenticationSession.
    /// - Parameter provider: The OmniAuth provider name (e.g., "google_oauth2" or "github")
    func startOAuth(provider: String) {
        guard let url = URL(string: "\(rootURL)/users/auth/\(provider)") else { return }
        let callbackURLScheme = "langlets"

        session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: callbackURLScheme
        ) { [weak self] callbackURL, error in
            if let error = error {
                print("OAuth error: \(error.localizedDescription)")
                return
            }

            if let callbackURL = callbackURL {
                self?.handleOAuthCallback(callbackURL)
            }
        }

        session?.presentationContextProvider = self
        session?.prefersEphemeralWebBrowserSession = false
        session?.start()
    }

    private func handleOAuthCallback(_ url: URL) {
        // The session cookie is now set in Safari.
        // Hotwire Native uses WKWebsiteDataStore.default() which shares
        // cookies with Safari, so the WKWebView will pick it up on reload.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .oauthDidSucceed, object: nil)
        }
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let oauthDidSucceed = Notification.Name("oauthDidSucceed")
}