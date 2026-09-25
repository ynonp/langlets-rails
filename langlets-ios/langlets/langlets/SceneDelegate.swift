import UIKit
import SwiftUI
import GoogleSignIn

let rootURL = URL(string: "https://langlets.app")!
let appBackgroundColor = UIColor(red: 10 / 255, green: 21 / 255, blue: 33 / 255, alpha: 1)

// Rails HTML is no longer the iOS navigation surface. Legacy bridge sources stay
// available as migration references, excluded from the native build.
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: "570385807243-546k3gm681na7d6ds3ft3eqg9hupboc0.apps.googleusercontent.com",
            serverClientID: "570385807243-a77uce7m9eu2i7d8tsbveal8ejpit5d3.apps.googleusercontent.com")
        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = UIHostingController(rootView: NativeRoot())
        window?.makeKeyAndVisible()
        PushNotifications.shared.handleLaunch(options: options)
        NotificationCenter.default.addObserver(self, selector: #selector(notificationTapped(_:)), name: PushNotifications.didTapNotification, object: nil)
        if let slug = PushNotifications.shared.consumePendingCourseSlug() { NativeStore.shared.courseRoute = slug }
        if let path = PushNotifications.shared.consumePendingChallengePath(), let url = URL(string: path, relativeTo: rootURL) { NativeStore.shared.route(url) }
        if let url = options.urlContexts.first?.url { handle(url) }
        if let url = options.userActivities.first?.webpageURL { handle(url) }
    }
    func scene(_ scene: UIScene, openURLContexts contexts: Set<UIOpenURLContext>) {
        if let url = contexts.first?.url { handle(url) }
    }
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        if let url = userActivity.webpageURL { handle(url) }
    }
    func sceneDidBecomeActive(_ scene: UIScene) { PushNotifications.shared.clearAppIconBadge() }
    private func handle(_ url: URL) {
        if GIDSignIn.sharedInstance.handle(url) { return }
        NativeStore.shared.route(url)
    }
    @objc private func notificationTapped(_ notification: Notification) {
        if let slug = notification.userInfo?["course_slug"] as? String { NativeStore.shared.courseRoute = slug }
        else if let path = notification.userInfo?["url"] as? String, let url = URL(string: path, relativeTo: rootURL) { NativeStore.shared.route(url) }
    }
}
