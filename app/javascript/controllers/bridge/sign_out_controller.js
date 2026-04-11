import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Notifies the native app when the user signs out, so it can clear
// any native state (cookies, cache, etc.).
//
// This controller is placed on sign-out links. When the native app is
// present, it sends a "signedOut" message so the app can clear its
// WKWebView data store.
export default class extends BridgeComponent {
  static component = "sign-out"

  connect() {
    super.connect()
  }

  // Called when the sign-out link is clicked in the native app.
  // Only sends the message when running in the native app.
  // The native SignOutComponent clears WKWebView website data.
  notifySignOut(event) {
    if (!this.enabled) return // Only in native app
    this.send("signedOut")
  }
}