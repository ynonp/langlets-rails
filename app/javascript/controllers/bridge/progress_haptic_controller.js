import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Sends haptic feedback to the native app when an activity is completed.
// The native ProgressHapticComponent receives the "activityCompleted" message
// and triggers a UIImpactFeedbackGenerator.
export default class extends BridgeComponent {
  static component = "progress-haptic"

  connect() {
    super.connect()
    this.handleComplete = this.handleComplete.bind(this)
    this.element.addEventListener("activity:completed", this.handleComplete)
  }

  disconnect() {
    this.element.removeEventListener("activity:completed", this.handleComplete)
  }

  handleComplete(event) {
    const xp = event.detail?.xp || 0
    this.send("activityCompleted", { xp: xp })
  }
}