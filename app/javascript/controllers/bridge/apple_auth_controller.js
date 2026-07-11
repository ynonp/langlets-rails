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
      this.showError(data.error || "Could not authenticate using Apple, please try another way.")
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
          this.showError("Apple authentication failed, please try another way.")
        }
      })
      .catch(() => {
        this.showError("Apple authentication failed, please try another way.")
      })
  }

  // Never use alert() here: replies from the native component can arrive
  // while the Apple sheet is still dismissing, and a JS alert at that moment
  // can't be presented natively — WebKit then crashes the app because the
  // alert panel's completion handler is never called.
  showError(message) {
    const el = document.querySelector("[data-native-auth-error]")
    if (el) {
      el.textContent = message
      el.hidden = false
    } else {
      console.error(message)
    }
  }
}
