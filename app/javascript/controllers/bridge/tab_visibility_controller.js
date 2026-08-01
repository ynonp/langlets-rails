import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Tells the native shell whether its tab bar belongs on this screen. The
// onboarding layout renders it with visible=false: choosing a learning language
// is a mandatory full-screen flow, and every tab behind it just redirects back
// into onboarding anyway.
//
// The counterpart is bridge--tab-badge, which the authenticated app layout
// renders on every page and which reveals the tabs again. Both only send on
// connect, so each page asserts its own chrome and there is nothing to undo on
// the way out.
export default class extends BridgeComponent {
  static component = "tab-visibility"
  static values = { visible: Boolean }

  connect() {
    super.connect()
    this.send("visibilityChanged", { visible: this.visibleValue })
  }
}
