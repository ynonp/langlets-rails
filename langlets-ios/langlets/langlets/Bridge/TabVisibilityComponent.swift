import HotwireNative
import UIKit

/// Lets a web layout declare whether the native tab bar belongs on screen.
///
/// The onboarding layout sends `visible: false`: picking a learning language is
/// a mandatory, full-screen flow, and tabs under it are both meaningless (every
/// tab redirects straight back to onboarding) and an escape hatch out of it.
///
/// This is the counterpart to TabBadgeComponent, which the authenticated app
/// layout sends on every page load and which reveals the tabs again. Both only
/// fire on connect, so each rendered page asserts its own chrome and leaving
/// onboarding restores the tabs without this component having to undo anything.
///
/// A notification rather than a view-controller walk, matching TabBadgeComponent:
/// the sending page may be presented modally, and a modal's view controller has
/// no tabBarController to reach.
@MainActor
final class TabVisibilityComponent: BridgeComponent {
    nonisolated override class var name: String { "tab-visibility" }

    override func onReceive(message: Message) {
        guard message.event == "visibilityChanged",
              let data: MessageData = message.data() else { return }

        NotificationCenter.default.post(
            name: .tabVisibilityDidChange,
            object: nil,
            userInfo: ["visible": data.visible]
        )
    }
}

private extension TabVisibilityComponent {
    struct MessageData: Decodable {
        let visible: Bool
    }
}

extension Notification.Name {
    static let tabVisibilityDidChange = Notification.Name("tabVisibilityDidChange")
}
