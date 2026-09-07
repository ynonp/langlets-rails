import Foundation
import HotwireNative

/// Reloads or selects a retained tab at another webview's request.
/// The tab bar controller owns the navigators, so bridge pages communicate with
/// it through NotificationCenter just like the other tab-level components.
@MainActor
final class TabRefreshComponent: BridgeComponent {
    nonisolated override class var name: String { "tab-refresh" }

    override func onReceive(message: Message) {
        guard let data: MessageData = message.data() else { return }

        switch message.event {
        case "refresh":
            NotificationCenter.default.post(
                name: .nativeTabNeedsRefresh,
                object: nil,
                userInfo: ["tab": data.tab]
            )
        case "select":
            NotificationCenter.default.post(
                name: .nativeTabNeedsSelection,
                object: nil,
                userInfo: ["tab": data.tab]
            )
        default:
            return
        }
    }
}

private extension TabRefreshComponent {
    struct MessageData: Decodable {
        let tab: String
    }
}

extension Notification.Name {
    static let nativeTabNeedsRefresh = Notification.Name("nativeTabNeedsRefresh")
    static let nativeTabNeedsSelection = Notification.Name("nativeTabNeedsSelection")
}
