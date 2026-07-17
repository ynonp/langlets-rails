import HotwireNative
import UIKit

/// The native tab bar hosting the three app screens. Each tab owns its own
/// Navigator, so switching is instant and every tab keeps its webview — scroll
/// position and page state survive. This replaces the web tab bar the 1.x
/// builds render (`app/views/app/shared/_tab_bar.html.erb` still serves them).
///
/// Tabs route lazily, on first selection, not up front. A signed-out cold
/// launch would otherwise fire three parallel visits that all redirect to the
/// sign-in modal, and only the visible tab can actually present it — the other
/// two would be left stranded mid-redirect.
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
        Tab(title: "Queue", path: "/app/import_requests", image: "clock", selectedImage: "clock.fill")
    ]

    private static let queueTabIndex = 2

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

    /// The tab whose root path matches `path`, if any. Lets the navigator
    /// delegate turn in-page links between tab roots (Home's "See all" →
    /// Library) into a native tab switch instead of a push.
    func tabIndex(forPath path: String) -> Int? {
        Self.tabs.firstIndex { $0.path == path }
    }

    func navigator(forTabAt index: Int) -> Navigator {
        navigators[index]
    }

    func selectTab(at index: Int) {
        selectedIndex = index
        routeTabIfNeeded(at: index)
    }

    func setQueueBadge(_ count: Int) {
        viewControllers?[Self.queueTabIndex].tabBarItem.badgeValue = count > 0 ? String(count) : nil
    }

    func setTabsVisible(_ visible: Bool) {
        tabBar.isHidden = !visible
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

    /// The tab's start URL, carrying the language picked during onboarding —
    /// the same UserDefaults key SceneDelegate used for the single-navigator
    /// start location. Without it, a cold launch's first request has no `lang`
    /// and the server bounces to language onboarding.
    private static func url(for tab: Tab) -> URL {
        var url = rootURL.appending(path: tab.path)
        if let lang = UserDefaults.standard.string(forKey: "selectedLanguage") {
            url = url.appending(queryItems: [URLQueryItem(name: "lang", value: lang)])
        }
        return url
    }
}

// MARK: - UITabBarControllerDelegate

extension AppTabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        routeTabIfNeeded(at: selectedIndex)
    }
}
