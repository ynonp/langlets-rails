import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Intercepts Apple sign-in button clicks in the native app and routes them
// through Apple's native AuthenticationServices sheet instead of the WKWebView.
//
// When running in a regular browser, this controller does nothing —
// the form submits normally and the omniauth-apple web flow takes over.
// When running in the native app (this.enabled is true), it prevents default
// form submission, sends a message to the native AppleAuthComponent, and
// POSTs the returned identity token to the backend.
//
// Usage: Add data-controller="bridge--apple-auth" to the Apple sign-in button.
export default class extends BridgeComponent {
  static component = "apple-auth"

  connect() {
    super.connect()
  }

  // Called when the user submits the Apple sign-in form.
  // Only intercepts in the native app — in a regular browser, the form
  // submits normally.
  authorize(event) {
    if (!this.enabled) return
    event.preventDefault()

    this.send("authorize", {}, (message) => {
      this.handleAuthorization(message.data)
    })
  }

  handleAuthorization(data) {
    if (!data.identityToken) {
      alert(data.error || "Could not authenticate using Apple, please try another way.")
      return
    }

    const formData = new FormData()
    formData.append("identity_token", data.identityToken)
    if (data.name) formData.append("name", data.name)

    fetch("/users/auth/native_apple", {
      method: "POST",
      body: formData
    })
      .then((response) => {
        if (response.redirected) {
          window.location.href = response.url
        } else {
          alert("Apple authentication failed, please try another way.")
        }
      })
      .catch(() => {
        alert("Apple authentication failed, please try another way.")
      })
  }
}
