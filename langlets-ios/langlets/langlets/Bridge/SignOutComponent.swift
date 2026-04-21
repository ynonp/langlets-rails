import HotwireNative
import WebKit

/// Handles sign-out events from the web view.
/// Clears WKWebView data when the user signs out so the next
/// session starts clean.
@MainActor
final class SignOutComponent: BridgeComponent {
    nonisolated override class var name: String { "sign-out" }

    override func onReceive(message: Message) {
        guard message.event == "signedOut" else { return }

        // Clear WKWebView cookies and website data
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: Date.distantPast
        ) {}

        // The web view will redirect to the homepage via the Devise sign-out flow
    }
}