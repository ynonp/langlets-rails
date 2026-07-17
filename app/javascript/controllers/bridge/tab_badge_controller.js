import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Mirrors the Queue badge onto the native tab bar item. The app layout renders
// this once per page for the 2.x builds with the current active-import count;
// the native TabBadgeComponent picks it up and sets the UITabBarItem badge.
export default class extends BridgeComponent {
  static component = "tab-badge"
  static values = { count: Number }

  connect() {
    super.connect()
    this.send("badgeChanged", { count: this.countValue })
  }
}
