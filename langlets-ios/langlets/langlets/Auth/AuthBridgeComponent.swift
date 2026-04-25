import HotwireNative
import UIKit

/// Bridge component that intercepts OAuth sign-in button clicks in the web view
/// and routes them through ASWebAuthenticationSession instead.
/// This is needed because Google and GitHub block OAuth in embedded browsers (WKWebView).
@MainActor
final class AuthBridgeComponent: BridgeComponent {
    nonisolated override class var name: String { "auth-bridge" }

    private static let authService = AuthService()

    override func onReceive(message: Message) {
        guard message.event == "startOAuth",
              let data: MessageData = message.data() else { return }

        // Google Sign-In is now handled by GoogleAuthComponent via the Google Sign-In SDK.
        // Only proceed here for non-Google providers (e.g. GitHub).
        if data.provider == "google_oauth2" { return }

        AuthBridgeComponent.authService.startOAuth(provider: data.provider)
    }
}

private extension AuthBridgeComponent {
    struct MessageData: Decodable {
        let provider: String
    }
}