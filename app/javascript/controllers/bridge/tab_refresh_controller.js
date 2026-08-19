import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Forwards a custom Turbo Stream's destination to the native shell. Each tab
// owns a separate webview, so JavaScript in Library cannot reload Home itself.
export default class extends BridgeComponent {
  static component = "tab-refresh"

  refresh({ detail: { tab } }) {
    if (tab) this.send("refresh", { tab })
  }
}
