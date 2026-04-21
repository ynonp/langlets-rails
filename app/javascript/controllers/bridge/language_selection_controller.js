import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Sends the selected language ISO code to the native iOS app via the bridge.
// The native LanguageSelectionBridgeComponent saves it to UserDefaults and
// navigates to the root URL with ?lang=<iso>.
//
// Usage: data-controller="bridge--language-selection" on language selection buttons
export default class extends BridgeComponent {
  static component = "language-selection"
  static values = { iso: String }

  connect() {
    super.connect()
  }

  selectLanguage(event) {
    if (!this.enabled) return // Let normal click behavior work in browser
    event.preventDefault()
    this.send("languageSelected", { language: this.isoValue })
  }
}
