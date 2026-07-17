import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Registers the device for "your course is ready" pushes.
//
// The native side owns the APNs token but has no session; the web side has the
// session but no token. So: ask native to register, it replies with the token,
// and we POST it here with the session cookie.
//
// Permission is requested only when the element says so (data-bridge-push-ask-value),
// which Home sets after the user's first successful import — asking at launch,
// before the app has done anything for them, roughly halves opt-in.
export default class extends BridgeComponent {
  static component = "push"
  static values = {
    ask: { type: Boolean, default: false },
    endpoint: String
  }

  connect() {
    super.connect()

    this.send("register", { ask: this.askValue }, (message) => {
      this.registerToken(message.data)
    })
  }

  async registerToken(data) {
    if (!data?.token) return

    try {
      await fetch(this.endpointValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
        },
        body: JSON.stringify({
          token: data.token,
          environment: data.environment,
          app_version: data.appVersion
        })
      })
    } catch (error) {
      // Not worth bothering the user about: the completion email still goes out,
      // and the next app launch tries again.
      console.warn("Could not register for push", error)
    }
  }
}
