import HotwireNative
import UIKit

/// Presents a native navigation bar with an explicit control that dismisses
/// the surrounding modal navigation controller.
final class NativeModalCloseViewController: HotwireWebViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let closeAction = UIAction { [weak self] _ in
            self?.navigationController?.dismiss(animated: true)
        }
        let closeButton = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            primaryAction: closeAction
        )
        closeButton.accessibilityLabel = "Close"
        navigationItem.rightBarButtonItem = closeButton
    }
}

/// Suppresses native navigation chrome for pages whose controls are rendered
/// entirely by the web view.
final class NavigationBarHiddenViewController: HotwireWebViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
}
