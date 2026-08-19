import Foundation
import HotwireNative

/// Reloads a retained tab after another webview changes state it displays.
/// The tab bar controller owns the navigators, so bridge pages communicate with
/// it through NotificationCenter just like the other tab-level components.
@MainActor
final class TabRefreshComponent: BridgeComponent {
    nonisolated override class var name: String { "tab-refresh" }

    override func onReceive(message: Message) {
        guard message.event == "refresh",
              let data: MessageData = message.data() else { return }

        NotificationCenter.default.post(
            name: .nativeTabNeedsRefresh,
            object: nil,
            userInfo: ["tab": data.tab]
        )
    }
}

private extension TabRefreshComponent {
    struct MessageData: Decodable {
        let tab: String
    }
}

extension Notification.Name {
    static let nativeTabNeedsRefresh = Notification.Name("nativeTabNeedsRefresh")
}
