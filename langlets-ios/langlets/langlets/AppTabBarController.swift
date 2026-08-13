import HotwireNative
import UIKit
import WebKit

/// The native tab bar hosting the three app screens. Each tab owns its own
/// Navigator, so switching is instant and every tab keeps its webview — scroll
/// position and page state survive.
///
/// Tabs route lazily, on first selection, not up front. A signed-out cold
/// launch would otherwise fire three parallel visits that all redirect to the
/// sign-in root, doing redundant work and leaving three independent copies of
/// the authentication flow alive.
@MainActor
final class AppTabBarController: UITabBarController {
    struct Tab {
        let title: String
        let path: String
        let image: String
        let selectedImage: String
    }

    static let tabs: [Tab] = [
        Tab(title: "Home", path: "/app", image: "house", selectedImage: "house.fill"),
        Tab(title: "Library", path: "/app/library", image: "square.grid.2x2", selectedImage: "square.grid.2x2.fill"),
        Tab(title: "Create", path: "/app/import_requests/new", image: "plus.circle", selectedImage: "plus.circle.fill")
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
    /// webviews — sign-in or sign-out — since every tab's
    /// content is stale from that moment.
    func reloadAllTabs() {
        needsRoute = Array(repeating: true, count: Self.tabs.count)
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

    private static func url(for tab: Tab) -> URL {
        rootURL.appending(path: tab.path)
    }
}

// MARK: - UITabBarControllerDelegate

extension AppTabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        closeProfileMenus(except: selectedIndex)
        routeTabIfNeeded(at: selectedIndex)
    }
}
