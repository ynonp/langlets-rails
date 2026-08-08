import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Hands an OAuth sign-in to the native shell so it can run the whole flow in the
// device browser, rather than letting it start in the web view.
//
// This is the Android counterpart of `auth-bridge` (GitHub) and `apple-auth`
// (Apple), and it is a third component rather than a reuse of either because
// what the native side does with the message is completely different. On iOS
// those two open ASWebAuthenticationSession and Apple's own sheet, both of which
// end with a credential in the app's hands; Android has neither, and opens a
// Chrome Custom Tab instead.
//
// The three coexist on the same buttons, and only ever one is live: a
// BridgeComponent is `enabled` only when the shell it is running in registered
// that component's name, so iOS answers to `auth-bridge`/`apple-auth`, Android
// answers to `web-auth`, and a plain browser answers to none of them and simply
// submits the form.
//
// Usage: add data-controller="bridge--web-auth" alongside the platform's own
// auth controller, with data-bridge--web-auth-provider-value="github" or
// "apple".
export default class extends BridgeComponent {
  static component = "web-auth"
  static values = { provider: String }

  startOAuth(event) {
    if (!this.enabled) return // Let the form submit normally in the browser

    event.preventDefault()
    this.send("startOAuth", { provider: this.providerValue })
  }
}
