import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Tells the native shell that an authenticated app screen has rendered, which
// is what reveals the tab bar. It used to badge the Library tab with the
// active-import count; no tab is badged any more — unread notifications go on
// the app icon badge instead — and the count is retained only so the bridge
// message keeps the shape TabBadgeComponent decodes.
export default class extends BridgeComponent {
  static component = "tab-badge"
  static values = { count: Number }

  connect() {
    super.connect()
    this.send("badgeChanged", { count: this.countValue })
  }
}
