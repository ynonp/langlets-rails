import HotwireNative
import WebKit

/// Handles sign-out events from the web view.
/// The "signedOut" message is sent from the page the server redirects to
/// after sign-out, so by the time it arrives the server session is already
/// destroyed — clearing local data here cannot race the sign-out request.
@MainActor
final class SignOutComponent: BridgeComponent {
    nonisolated override class var name: String { "sign-out" }

    override func onReceive(message: Message) {
        guard message.event == "signedOut" else { return }

        // Clear cookies stored at the URLSession level as well.
        HTTPCookieStorage.shared.removeCookies(since: .distantPast)

        let dataStore = WKWebsiteDataStore.default()
        dataStore.removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: Date.distantPast
        ) {
            // Touching the cookie store forces WebKit to flush the deletion
            // to disk; without it, killing the app right after sign-out can
            // resurrect the old session/remember cookies on next launch.
            dataStore.httpCookieStore.getAllCookies { _ in }
        }
    }
}
