import HotwireNative
import UIKit

/// Receives the selected language from the web view onboarding page,
/// saves it to UserDefaults, and notifies the app to navigate to
/// the root URL with ?lang=<iso> appended.
@MainActor
final class LanguageSelectionBridgeComponent: BridgeComponent {
    nonisolated override class var name: String { "language-selection" }

    override func onReceive(message: Message) {
        guard message.event == "languageSelected",
              let data: MessageData = message.data() else { return }

        UserDefaults.standard.set(data.language, forKey: "selectedLanguage")

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .languageDidSelect,
                object: nil,
                userInfo: ["language": data.language]
            )
        }
    }
}

private extension LanguageSelectionBridgeComponent {
    struct MessageData: Decodable {
        let language: String
    }
}

extension Notification.Name {
    static let languageDidSelect = Notification.Name("languageDidSelect")
}
