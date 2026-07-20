import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Copies a session-authorized, import-only bearer token from Rails into the
// shared native Keychain used by the app and its share extension.
export default class extends BridgeComponent {
  static component = "native-token"

  connect() {
    super.connect()
    this.bootstrap()
  }

  async bootstrap() {
    const csrfToken = document.querySelector("meta[name=csrf-token]")?.content

    try {
      const response = await fetch("/app/native_token", {
        method: "POST",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": csrfToken
        }
      })
      if (!response.ok) return

      const token = await response.json()
      this.send("store", token)
    } catch (_) {
      // The next authenticated page load retries. Sharing remains unavailable
      // until a token has successfully reached the Keychain.
    }
  }
}
