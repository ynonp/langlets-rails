import HotwireNative
import UIKit

/// The app screens' "this page is the authenticated app layout" signal, which
/// SceneDelegate uses to reveal the tab bar. It was the Library tab's badge
/// count; no tab is badged any more (unread notifications live on the app icon
/// badge instead), and `count` is retained only so the message keeps its shape.
///
/// A notification rather than a view-controller walk because the sending page
/// may be a modal sheet, whose view controller has no tabBarController.
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
