import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Sends the selected language ISO code to the native iOS app via the bridge.
// The native LanguageSelectionBridgeComponent saves it to UserDefaults and
// navigates to the root URL with ?lang=<iso>.
//
// Usage: data-controller="bridge--language-selection" on language selection buttons
export default class extends BridgeComponent {
  static component = "language-selection"
  static values = { iso: String, redirectUrl: String }

  connect() {
    super.connect()
  }

  selectLanguage(event) {
    event.preventDefault()

    const payload = { language: this.isoValue }
    if (this.hasRedirectUrlValue) {
      payload.redirectUrl = this.redirectUrlValue
    }

    this.send("languageSelected", payload)

    // Browser fallback: navigate directly when not in native app
    if (!this.enabled && this.hasRedirectUrlValue) {
      window.location.href = this.redirectUrlValue
    }
  }
}
