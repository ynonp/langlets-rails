import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Forwards a custom Turbo Stream's destination to the native shell. Each tab
// owns a separate webview, so JavaScript in Library cannot reload Home itself.
export default class extends BridgeComponent {
  static component = "tab-refresh"

  refresh({ detail: { tab } }) {
    if (tab) this.send("refresh", { tab })
  }

  // A normal tab-root link would push the destination into the current tab's
  // navigator. Native shells select the retained destination tab instead;
  // browsers keep the link's ordinary href fallback.
  select(event) {
    if (!this.enabled) return

    event.preventDefault()
    const tab = event.params.tab
    if (tab) this.send("select", { tab })
  }
}
