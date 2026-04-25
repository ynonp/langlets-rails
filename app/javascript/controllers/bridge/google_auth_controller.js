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
      alert(data.error || "Could not authenticate using Google, please try another way.")
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
          alert("Google authentication failed, please try another way.")
        }
      })
      .catch(() => {
        alert("Google authentication failed, please try another way.")
      })
  }
}
