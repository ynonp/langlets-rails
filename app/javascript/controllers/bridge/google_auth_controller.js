import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Intercepts Google sign-in button clicks in the native app and routes them
// through the Google Sign-In SDK instead of the WKWebView.
//
// When running in a regular browser, this controller does nothing —
// the form submits normally. When running in the native app (this.enabled
// is true), it prevents default form submission, sends a message to the
// native GoogleAuthComponent, and POSTs the returned code to the backend.
//
// Usage: Add data-controller="bridge--google-auth" to the Google sign-in button.
export default class extends BridgeComponent {
  static component = "google-auth"

  connect() {
    super.connect()
  }

  // Called when the user submits the Google sign-in form.
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
    if (!data.code) {
      this.showError(data.error || "Could not authenticate using Google, please try another way.")
      return
    }

    const formData = new FormData()
    formData.append("code", data.code)
    formData.append("redirect_uri", "")

    fetch("/users/auth/native_google", {
      method: "POST",
      body: formData
    })
      .then((response) => {
        if (response.redirected) {
          window.location.href = response.url
        } else {
          this.showError("Google authentication failed, please try another way.")
        }
      })
      .catch(() => {
        this.showError("Google authentication failed, please try another way.")
      })
  }

  // Never use alert() here: replies from the native component can arrive
  // while the Google sheet is still dismissing, and a JS alert at that moment
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
