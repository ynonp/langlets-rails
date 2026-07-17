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

    const select = event.currentTarget instanceof HTMLSelectElement ? event.currentTarget : null
    const selectedOption = select?.selectedOptions[0]
    const language = select?.value || this.isoValue
    const redirectUrl = selectedOption?.dataset.redirectUrl ||
      (this.hasRedirectUrlValue ? this.redirectUrlValue : null)

    // Outside the native app there is no bridge to send to — navigate directly.
    if (!this.enabled) {
      if (redirectUrl) window.location.href = redirectUrl
      return
    }

    const payload = { language }
    if (redirectUrl) {
      payload.redirectUrl = redirectUrl
    }

    this.send("languageSelected", payload)
  }
}
