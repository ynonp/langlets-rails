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
        UserDefaults(suiteName: NativeShareStore.appGroup)?.set(data.language, forKey: "selectedLanguage")
        AppTabBarController.clearPendingOnboardingURL()

        DispatchQueue.main.async {
            var userInfo: [String: Any] = ["language": data.language]
            if let redirectUrl = data.redirectUrl {
                userInfo["redirectUrl"] = redirectUrl
            }
            NotificationCenter.default.post(
                name: .languageDidSelect,
                object: nil,
                userInfo: userInfo
            )
        }
    }
}

private extension LanguageSelectionBridgeComponent {
    struct MessageData: Decodable {
        let language: String
        let redirectUrl: String?
    }
}

extension Notification.Name {
    static let languageDidSelect = Notification.Name("languageDidSelect")
}
