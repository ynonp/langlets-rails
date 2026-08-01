import { BridgeComponent } from "@hotwired/hotwire-native-bridge"
import { t } from "../../utils/i18n"

// Renders the Profile notification action from the real iOS authorization
// state, then registers or removes this installation's APNs token.
export default class extends BridgeComponent {
  static component = "notification-preference"
  static targets = ["button", "switch", "switchInput", "status"]
  static values = { endpoint: String }

  connect() {
    super.connect()
    this.send("status", {}, (message) => this.render(message.data))
  }

  enable() {
    this.buttonTarget.disabled = true
    this.send("setEnabled", { enabled: true }, (message) => this.apply(message.data))
  }

  toggle(event) {
    const enabled = event.currentTarget.checked
    event.currentTarget.disabled = true
    this.send("setEnabled", { enabled }, (message) => this.apply(message.data))
  }

  async apply(data) {
    if (data?.token) {
      await fetch(this.endpointValue, {
        method: data.enabled ? "POST" : "DELETE",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
        },
        body: JSON.stringify({
          token: data.token,
          environment: data.environment,
          app_version: data.appVersion
        })
      })
    }

    this.render(data)
  }

  render(data) {
    const granted = data?.granted === true
    const denied = data?.denied === true
    const enabled = data?.enabled === true

    // Use inline display state rather than competing Tailwind `hidden` and
    // `inline-flex` utilities, whose generated order can expose both controls.
    this.buttonTarget.style.display = granted ? "none" : ""
    this.buttonTarget.textContent = t(
      denied ? "notification_preference.open_settings" : "notification_preference.enable"
    )
    this.buttonTarget.disabled = false
    this.switchTarget.style.display = granted ? "" : "none"
    this.switchInputTarget.checked = enabled
    this.switchInputTarget.disabled = false
    this.statusTarget.textContent = granted
      ? t(enabled ? "notification_preference.enabled" : "notification_preference.disabled")
      : t(denied ? "notification_preference.denied" : "notification_preference.prompt")
  }
}
