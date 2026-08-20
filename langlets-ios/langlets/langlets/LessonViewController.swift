import HotwireNative
import UIKit

/// Adds an explicit modal dismissal affordance to course lesson and review
/// lesson pages.
/// Activity navigation stays inside the same sheet, so this button is
/// intentionally a close action instead of a back action.
final class LessonViewController: HotwireWebViewController {
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
        closeButton.accessibilityLabel = "Close lesson"
        navigationItem.rightBarButtonItem = closeButton
    }
}

/// The completion screen supplies its own title and Continue action. Hiding
/// the modal navigation bar here avoids repeating both the page title and a
/// second close action above the web content.
final class LessonFinishViewController: HotwireWebViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
}
