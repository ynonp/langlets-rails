import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Intercepts OAuth sign-in button clicks in the native app and routes them
// through ASWebAuthenticationSession instead of the WKWebView.
// This is needed because Google and GitHub block OAuth in embedded browsers.
//
// When running in a regular browser, this controller does nothing —
// the form submits normally. When running in the native app (this.enabled
// is true), it prevents default form submission and sends a message to the
// native AuthBridgeComponent, which starts ASWebAuthenticationSession.
//
// Usage: Add data-controller="bridge--auth-bridge" to OAuth sign-in buttons
// along with data-bridge--auth-bridge-provider-value="google_oauth2" or "github".
export default class extends BridgeComponent {
  static component = "auth-bridge"
  static values = { provider: String }

  connect() {
    super.connect()
  }

  // Called when the user submits an OAuth sign-in form.
  // Only intercepts in the native app — in a regular browser, the form
  // submits normally.
  startOAuth(event) {
    if (!this.enabled) return // Let the form submit normally in the browser
    event.preventDefault()
    this.send("startOAuth", { provider: this.providerValue })
  }
}