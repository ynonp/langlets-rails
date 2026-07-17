import HotwireNative
import UIKit

/// Receives the Queue tab's badge count from the app screens (the tab-badge
/// bridge controller in the web layout sends it on every page load) and hands
/// it to SceneDelegate, which owns the tab bar. A notification rather than a
/// view-controller walk because the sending page may be a modal sheet, whose
/// view controller has no tabBarController.
@MainActor
final class TabBadgeComponent: BridgeComponent {
    nonisolated override class var name: String { "tab-badge" }

    override func onReceive(message: Message) {
        guard message.event == "badgeChanged",
              let data: MessageData = message.data() else { return }

        NotificationCenter.default.post(
            name: .queueBadgeDidChange,
            object: nil,
            userInfo: ["count": data.count]
        )
    }
}

private extension TabBadgeComponent {
    struct MessageData: Decodable {
        let count: Int
    }
}

extension Notification.Name {
    static let queueBadgeDidChange = Notification.Name("queueBadgeDidChange")
}
