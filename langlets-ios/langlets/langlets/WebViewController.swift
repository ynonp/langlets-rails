import HotwireNative
import UIKit

/// The default view controller for every web page that isn't a lesson.
///
/// Its job beyond the stock `HotwireWebViewController` is deciding whether this
/// screen gets a native navigation bar. The app's web layout draws its own
/// header — the wordmark, the profile menu — and `body` already pads
/// `env(safe-area-inset-top)` so it can sit under the system bar. Stacking a
/// native navigation bar on top of that gives two headers and a title the
/// design never asked for. Pushed screens are the opposite case: they need
/// somewhere for the back arrow to live, so they keep the bar.
///
/// The Android counterpart is `WebFragment`, which does the same thing through
/// `showsAppBar`.
final class WebViewController: HotwireWebViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let isRoot = navigationController?.viewControllers.first == self
        navigationController?.setNavigationBarHidden(isRoot, animated: animated)
    }
}
