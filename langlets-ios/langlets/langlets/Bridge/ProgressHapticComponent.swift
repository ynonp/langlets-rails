import HotwireNative
import UIKit

/// Provides haptic feedback when the user completes an activity.
/// Triggered by the progress-haptic bridge controller on the web side.
@MainActor
final class ProgressHapticComponent: BridgeComponent {
    nonisolated override class var name: String { "progress-haptic" }

    override func onReceive(message: Message) {
        guard message.event == "activityCompleted" else { return }

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}