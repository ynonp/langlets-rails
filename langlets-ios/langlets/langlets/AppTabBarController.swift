import HotwireNative
import UIKit
import WebKit

/// The native tab bar hosting the three app screens. Each tab owns its own
/// Navigator, so switching is instant and every tab keeps its webview — scroll
/// position and page state survive.
///
/// Tabs route lazily, on first selection, not up front. A signed-out cold
/// launch would otherwise fire three parallel visits that all redirect to the
/// sign-in modal, and only the visible tab can actually present it — the other
/// two would be left stranded mid-redirect.
@MainActor
final class AppTabBarController: UITabBarController {
    private static let pendingOnboardingURLKey = "pendingOnboardingURL"

    /// The onboarding flow's pages, which are the ones worth checkpointing for
    /// the next cold launch. (Hiding the tab bar over them is not keyed on this
    /// list — the onboarding layout declares it through the tab-visibility
    /// bridge, because a proposal only ever carries the pre-redirect URL.)
    private static let onboardingPaths = ["/onboarding/welcome", "/onboarding/language"]

    private static func isOnboardingURL(_ url: URL) -> Bool {
        onboardingPaths.contains(url.path)
    }

    struct Tab {
        let title: String
        let path: String
        let image: String
        let selectedImage: String
    }

    static let tabs: [Tab] = [
        Tab(title: "Home", path: "/app", image: "house", selectedImage: "house.fill"),
        Tab(title: "Library", path: "/app/library", image: "square.grid.2x2", selectedImage: "square.grid.2x2.fill"),
        Tab(title: "Create", path: "/app/import_requests", image: "plus.circle", selectedImage: "plus.circle.fill")
    ]

    static let homeTabIndex = 0

    private var navigators: [Navigator] = []
    private var needsRoute: [Bool]

    init(navigatorDelegate: NavigatorDelegate) {
        needsRoute = Array(repeating: true, count: Self.tabs.count)
        super.init(nibName: nil, bundle: nil)

        navigators = Self.tabs.map { tab in
            Navigator(configuration: .init(name: tab.title, startLocation: Self.url(for: tab)),
                      delegate: navigatorDelegate)
        }

        viewControllers = zip(Self.tabs, navigators).map { tab, navigator in
            navigator.rootViewController.view.backgroundColor = appBackgroundColor
            navigator.rootViewController.tabBarItem = UITabBarItem(
                title: tab.title,
                image: UIImage(systemName: tab.image),
                selectedImage: UIImage(systemName: tab.selectedImage)
            )
            return navigator.rootViewController
        }

        // Authentication is established by the first rendered /app page.
        // Keep the navigation controls out of the signed-out experience until
        // SceneDelegate receives that page's tab-badge bridge message.
        tabBar.isHidden = true
        view.backgroundColor = appBackgroundColor
        delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Use init(navigatorDelegate:) instead.")
    }

    /// Routes the initially selected tab. Call once path configuration and
    /// bridge components are registered.
    func start() {
        routeTabIfNeeded(at: selectedIndex)
    }

    var activeNavigator: Navigator {
        navigators[selectedIndex]
    }

    /// Re-routes the visible tab to its root and queues a fresh load for the
    /// others. Called whenever the server-side session changed under the
    /// webviews — sign-in, sign-out, language switch — since every tab's
    /// content is stale from that moment.
    func reloadAllTabs() {
        needsRoute = Array(repeating: true, count: Self.tabs.count)
        routeTabIfNeeded(at: selectedIndex)
    }

    /// Queues a fresh load for every tab except the one `navigator` belongs
    /// to. Used when one tab is heading into the auth flow: whatever the
    /// others show predates it either way, and re-routing them also clears any
    /// sign-in modal a background tab tried (and failed) to present.
    func reloadOtherTabs(than navigator: Navigator) {
        for index in navigators.indices where navigators[index] !== navigator {
            needsRoute[index] = true
        }
        routeTabIfNeeded(at: selectedIndex)
    }

    func selectTab(at index: Int) {
        closeProfileMenus(except: index)
        selectedIndex = index
        routeTabIfNeeded(at: index)
    }


    /// Land on Home with a freshly imported course as the hero — where a tapped
    /// "your course is ready" notification goes. HomeController reads
    /// `just_imported` and puts that course at the top with the JUST IMPORTED
    /// badge; an unknown slug just falls back to the ordinary Home.
    func showJustImported(courseSlug: String) {
        let index = Self.homeTabIndex
        closeProfileMenus(except: index)
        selectedIndex = index

        // The tab is now routed; don't let routeTabIfNeeded overwrite this with
        // the plain start URL afterwards.
        needsRoute[index] = false

        var url = Self.url(for: Self.tabs[index])
        url = url.appending(queryItems: [URLQueryItem(name: "just_imported", value: courseSlug)])

        // replace_root, matching routeTabIfNeeded: arriving from a notification
        // should reset the tab's stack and dismiss anything modal on it, not push
        // onto whatever the user happened to leave open.
        let proposal = VisitProposal(
            url: url,
            options: VisitOptions(action: .replace),
            properties: ["presentation": "replace_root", "animated": false]
        )
        navigators[index].route(proposal)
    }

    /// No tab carries a badge. The Library tab used to show imports still in
    /// flight, which competed with the app icon badge for the same attention
    /// while meaning something else entirely — the icon badge is unread
    /// notifications, and the Queue is a screen the user goes to on purpose.
    func setTabsVisible(_ visible: Bool) {
        tabBar.isHidden = !visible
    }

    /// Checkpoint an unfinished onboarding page before Hotwire follows it.
    /// The web navigation stack is lost when iOS terminates the app, while
    /// UserDefaults survives and lets the next cold launch resume this URL.
    static func rememberPendingOnboardingURL(_ url: URL) {
        guard UserDefaults.standard.string(forKey: "selectedLanguage") == nil,
              isOnboardingURL(url) else { return }

        guard let source = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return }

        var components = URLComponents()
        components.percentEncodedPath = source.percentEncodedPath
        // Preserve the query's existing escaping. Assigning `url.query` to
        // `query` encodes its percent signs again (`%2F` -> `%252F`).
        components.percentEncodedQuery = source.percentEncodedQuery
        UserDefaults.standard.set(components.string, forKey: pendingOnboardingURLKey)
    }

    static func clearPendingOnboardingURL() {
        UserDefaults.standard.removeObject(forKey: pendingOnboardingURLKey)
    }

    /// Restore the authenticated account's server-side language preference.
    /// Rails sends it as `ios_lang` after login so a prior sign-out can safely
    /// clear device state without forcing a returning user through onboarding.
    static func restoreLanguageSelection(from url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let language = components.queryItems?.first(where: { $0.name == "ios_lang" })?.value,
              !language.isEmpty else { return }

        UserDefaults.standard.set(language, forKey: "selectedLanguage")
        UserDefaults(suiteName: NativeShareStore.appGroup)?.set(language, forKey: "selectedLanguage")
        clearPendingOnboardingURL()
    }

    /// Reset every account-specific language checkpoint. Called both by the
    /// sign-out bridge and when the navigator sees the server's signed-out
    /// redirect, so account deletion does not depend on JavaScript mounting a
    /// bridge component before the user signs in again.
    static func resetLanguageSelection() {
        UserDefaults.standard.removeObject(forKey: "selectedLanguage")
        UserDefaults(suiteName: NativeShareStore.appGroup)?.removeObject(forKey: "selectedLanguage")
        clearPendingOnboardingURL()
    }

    /// Force-route the Home tab to its root URL, regardless of whether it
    /// has already been routed. Used by returnHome to recover from a stuck
    /// page (e.g. /profile) that clearAll alone won't replace.
    func routeHomeTab() {
        needsRoute[Self.homeTabIndex] = true
        routeTabIfNeeded(at: Self.homeTabIndex)
    }

    // MARK: - Private

    private func routeTabIfNeeded(at index: Int) {
        guard needsRoute[index] else { return }
        needsRoute[index] = false

        // replace_root rather than a plain route: a re-route after an auth or
        // language change must reset the tab's stack (and dismiss any modal
        // sitting on it), not push its root onto whatever is already there.
        let proposal = VisitProposal(
            url: Self.url(for: Self.tabs[index]),
            options: VisitOptions(action: .replace),
            properties: ["presentation": "replace_root", "animated": false]
        )
        navigators[index].route(proposal)
    }

    /// Each tab retains its webview, including the open state of HTML details
    /// elements. Close profile menus before their tab moves to the background
    /// so they are not still open when the user returns.
    private func closeProfileMenus(except selectedIndex: Int) {
        for index in navigators.indices where index != selectedIndex {
            webViews(in: navigators[index].rootViewController.view).forEach { webView in
                webView.evaluateJavaScript(
                    "document.querySelectorAll('[data-testid=app-profile-menu][open]').forEach((menu) => menu.removeAttribute('open'))"
                )
            }
        }
    }

    private func webViews(in view: UIView) -> [WKWebView] {
        var matches = view.subviews.compactMap { $0 as? WKWebView }
        matches.append(contentsOf: view.subviews.flatMap { webViews(in: $0) })
        return matches
    }

    /// The tab's start URL, carrying the language picked during onboarding —
    /// the same UserDefaults key SceneDelegate used for the single-navigator
    /// start location. Without it, a cold launch's first request has no `lang`
    /// and the server bounces to language onboarding.
    private static func url(for tab: Tab) -> URL {
        var url = rootURL.appending(path: tab.path)
        if let lang = UserDefaults.standard.string(forKey: "selectedLanguage") {
            url = url.appending(queryItems: [URLQueryItem(name: "lang", value: lang)])
        } else if let pendingURL = pendingOnboardingURL() {
            url = pendingURL
        }
        return url
    }

    /// Rebuild the checkpoint from decoded query items. Besides validating the
    /// path, this repairs `%252F` values written by the first implementation.
    private static func pendingOnboardingURL() -> URL? {
        guard let pendingPath = UserDefaults.standard.string(forKey: pendingOnboardingURLKey),
              let pendingURL = URL(string: pendingPath, relativeTo: rootURL)?.absoluteURL,
              isOnboardingURL(pendingURL),
              var components = URLComponents(url: pendingURL, resolvingAgainstBaseURL: true) else { return nil }

        components.queryItems = components.queryItems?.map { item in
            guard item.name == "returnto" else { return item }
            return URLQueryItem(name: item.name, value: item.value?.removingPercentEncoding ?? item.value)
        }
        return components.url
    }
}

// MARK: - UITabBarControllerDelegate

extension AppTabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        closeProfileMenus(except: selectedIndex)
        routeTabIfNeeded(at: selectedIndex)
    }
}
