import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Notifies the native app that the user signed out, so it can clear
// its WKWebView cookie store and cache.
//
// Rendered on the page the server redirects to after sign-out
// (layouts/application, when ?signed_out=1 is present). Firing here —
// rather than on the sign-out link click — guarantees the cookie wipe
// happens only after DELETE /users/sign_out completed on the server,
// so the request can't lose its session cookie mid-flight.
export default class extends BridgeComponent {
  static component = "sign-out"

  connect() {
    super.connect()
    if (this.enabled) {
      this.send("signedOut")
    }
  }
}
