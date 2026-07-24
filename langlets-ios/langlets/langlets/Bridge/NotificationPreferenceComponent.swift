import HotwireNative
import UIKit
import UserNotifications

/// Exposes this installation's notification state to the native Profile page.
/// iOS does not let an app revoke system permission, so disabling is a local
/// opt-out; enabling after a system denial takes the user to Settings.
@MainActor
final class NotificationPreferenceComponent: BridgeComponent {
    nonisolated override class var name: String { "notification-preference" }

    override func onReceive(message: Message) {
        switch message.event {
        case "status":
            replyWithStatus(to: message.event)
        case "setEnabled":
            guard let data: EnabledMessage = message.data() else { return }
            setEnabled(data.enabled)
        default:
            break
        }
    }

    private func setEnabled(_ enabled: Bool) {
        guard enabled else {
            if let token = PushNotifications.shared.deviceToken {
                disable(token: token)
            } else {
                // Registration can still be in flight when Profile renders.
                // Obtain the installation token before setting the local opt-out
                // so Rails can remove the exact row it previously registered.
                PushNotifications.shared.register(ask: false) { [weak self] token in
                    self?.disable(token: token)
                }
            }
            return
        }

        PushNotifications.shared.isEnabled = true
        PushNotifications.shared.authorizationStatus { [weak self] status in
            guard let self else { return }

            if status == .denied {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                self.replyWithStatus(to: "setEnabled")
            } else if status == .notDetermined {
                PushNotifications.shared.requestAuthorization { [weak self] granted in
                    guard let self else { return }
                    guard granted else {
                        self.replyWithStatus(to: "setEnabled")
                        return
                    }
                    PushNotifications.shared.register(ask: false) { [weak self] token in
                        guard let self else { return }
                        self.reply(to: "setEnabled", with: self.payload(granted: true, token: token))
                    }
                }
            } else {
                PushNotifications.shared.register(ask: false) { [weak self] token in
                    guard let self else { return }
                    self.reply(to: "setEnabled", with: self.payload(granted: true, token: token))
                }
            }
        }
    }

    private func disable(token: String) {
        PushNotifications.shared.isEnabled = false
        reply(
            to: "setEnabled",
            with: PreferenceResponse(
                granted: true,
                denied: false,
                enabled: false,
                token: token,
                environment: PushNotifications.shared.environment,
                appVersion: PushNotifications.shared.appVersion
            )
        )
    }

    private func replyWithStatus(to event: String) {
        PushNotifications.shared.authorizationStatus { [weak self] status in
            guard let self else { return }
            self.reply(
                to: event,
                with: self.payload(
                    granted: [.authorized, .provisional, .ephemeral].contains(status),
                    denied: status == .denied,
                    token: PushNotifications.shared.deviceToken
                )
            )
        }
    }

    private func payload(granted: Bool, denied: Bool = false, token: String?) -> PreferenceResponse {
        PreferenceResponse(
            granted: granted,
            denied: denied,
            enabled: granted && PushNotifications.shared.isEnabled,
            token: token,
            environment: PushNotifications.shared.environment,
            appVersion: PushNotifications.shared.appVersion
        )
    }

    private struct EnabledMessage: Decodable {
        let enabled: Bool
    }

    private struct PreferenceResponse: Encodable {
        let granted: Bool
        let denied: Bool
        let enabled: Bool
        let token: String?
        let environment: String
        let appVersion: String
    }
}
