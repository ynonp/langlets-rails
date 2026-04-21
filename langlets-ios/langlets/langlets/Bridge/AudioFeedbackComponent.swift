import HotwireNative
import AVFoundation

/// Plays native sound effects for correct/incorrect/completion feedback
/// instead of using Web Audio API in the WKWebView.
@MainActor
final class AudioFeedbackComponent: BridgeComponent {
    nonisolated override class var name: String { "native-audio-feedback" }

    private var audioPlayer: AVAudioPlayer?

    override func onReceive(message: Message) {
        guard message.event == "playSound",
              let data: MessageData = message.data() else { return }
        playSound(named: data.sound)
    }

    private func playSound(named name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "sounds") else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Audio playback error: \(error)")
        }
    }
}

private extension AudioFeedbackComponent {
    struct MessageData: Decodable {
        let sound: String
    }
}
