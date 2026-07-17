import Foundation
import UIKit
import UserNotifications

/// Owns everything APNs: permission, the device token, and where a tapped
/// notification should land.
///
/// The token and the session live on opposite sides of the bridge — AppDelegate
/// gets the token with no session, the web view has the session with no token —
/// so this holds the token until `PushComponent` asks for it.
@MainActor
final class PushNotifications: NSObject {
    static let shared = PushNotifications()

    /// Posted when a notification is tapped. `userInfo` carries "course_slug".
    static let didTapNotification = Notification.Name("PushNotifications.didTapNotification")

    /// Set once APNs answers. Nil until then — registration is asynchronous, and
    /// the web view usually finishes loading first.
    private(set) var deviceToken: String?

    /// Called when the token arrives after someone already asked for it.
    private var pendingTokenHandler: ((String) -> Void)?

    /// A notification tapped before the web view was ready. Replayed on connect.
    private var pendingCourseSlug: String?

    var environment: String {
        // A debug build talks to APNs sandbox; TestFlight and App Store builds
        // talk to production. The tokens are not interchangeable, so the server
        // stores which one this is.
        #if DEBUG
            return "sandbox"
        #else
            return "production"
        #endif
    }

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    func configure() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// Registers for remote notifications, asking permission only if `ask` is true.
    ///
    /// When `ask` is false this still registers if permission was granted
    /// previously, so an existing user's token refreshes on every launch without
    /// ever seeing a prompt.
    func register(ask: Bool, completion: @escaping (String) -> Void) {
        if let token = deviceToken {
            completion(token)
            return
        }
        pendingTokenHandler = completion

        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                guard let self else { return }

                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    UIApplication.shared.registerForRemoteNotifications()
                case .notDetermined where ask:
                    self.requestAuthorization()
                default:
                    // Denied, or not yet worth asking. Nothing to send.
                    break
                }
            }
        }
    }

    private func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error {
                print("Push authorization failed: \(error)")
            }
            guard granted else { return }

            Task { @MainActor in
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    // MARK: - Called by AppDelegate

    func didRegister(deviceToken data: Data) {
        let token = data.map { String(format: "%02x", $0) }.joined()
        self.deviceToken = token

        pendingTokenHandler?(token)
        pendingTokenHandler = nil
    }

    func didFailToRegister(error: Error) {
        print("Push registration failed: \(error)")
        pendingTokenHandler = nil
    }

    // MARK: - Deep linking

    /// The cold-launch path. On a cold start the tap arrives here, in
    /// `scene(_:willConnectTo:)`'s connectionOptions — *not* in the
    /// UNUserNotificationCenterDelegate callback. Miss this and the deep link
    /// silently drops for exactly the users who weren't already in the app.
    func handleLaunch(options connectionOptions: UIScene.ConnectionOptions) {
        guard let response = connectionOptions.notificationResponse else { return }

        pendingCourseSlug = courseSlug(from: response)
    }

    /// A slug from a tap that arrived before the navigator was ready.
    func consumePendingCourseSlug() -> String? {
        defer { pendingCourseSlug = nil }
        return pendingCourseSlug
    }

    private func courseSlug(from response: UNNotificationResponse) -> String? {
        response.notification.request.content.userInfo["course_slug"] as? String
    }
}

extension PushNotifications: UNUserNotificationCenterDelegate {
    /// The warm path: the app was already running when the user tapped.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let slug = response.notification.request.content.userInfo["course_slug"] as? String

        Task { @MainActor in
            if let slug {
                NotificationCenter.default.post(
                    name: PushNotifications.didTapNotification,
                    object: nil,
                    userInfo: ["course_slug": slug]
                )
            }
            completionHandler()
        }
    }

    /// Show the banner even with the app foregrounded — the user may be reading a
    /// lesson while another import finishes.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
}
