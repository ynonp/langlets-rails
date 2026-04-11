import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Sends audio feedback events to the native app for playback via AVAudioPlayer.
// This replaces the Web Audio API sounds when running in the native app,
// providing lower latency and better UX.
//
// The native AudioFeedbackComponent receives "playSound" messages with
// a { sound: "correct"|"incorrect"|"complete" } payload.
export default class extends BridgeComponent {
  static component = "native-audio-feedback"

  connect() {
    super.connect()
    this.handleCorrect = this.handleCorrect.bind(this)
    this.handleIncorrect = this.handleIncorrect.bind(this)
    this.handleComplete = this.handleComplete.bind(this)

    this.element.addEventListener("audio:correct", this.handleCorrect)
    this.element.addEventListener("audio:incorrect", this.handleIncorrect)
    this.element.addEventListener("audio:complete", this.handleComplete)
  }

  disconnect() {
    this.element.removeEventListener("audio:correct", this.handleCorrect)
    this.element.removeEventListener("audio:incorrect", this.handleIncorrect)
    this.element.removeEventListener("audio:complete", this.handleComplete)
  }

  handleCorrect() {
    this.send("playSound", { sound: "correct" })
  }

  handleIncorrect() {
    this.send("playSound", { sound: "incorrect" })
  }

  handleComplete() {
    this.send("playSound", { sound: "complete" })
  }
}