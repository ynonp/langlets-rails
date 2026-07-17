import HotwireNative
import UIKit

/// Hands the APNs device token to the web side, which has the session needed to
/// register it. Paired with app/javascript/controllers/bridge/push_controller.js.
@MainActor
final class PushComponent: BridgeComponent {
    nonisolated override class var name: String { "push" }

    private struct RegisterMessage: Decodable {
        /// Home sets this only after the user's first successful import — asking
        /// at launch, before the app has done anything for them, roughly halves
        /// opt-in.
        let ask: Bool
    }

    override func onReceive(message: Message) {
        guard message.event == "register" else { return }
        guard let data: RegisterMessage = message.data() else { return }

        PushNotifications.shared.register(ask: data.ask) { [weak self] token in
            guard let self else { return }

            self.reply(to: "register", with: [
                "token": token,
                "environment": PushNotifications.shared.environment,
                "appVersion": PushNotifications.shared.appVersion
            ])
        }
    }
}
