import { BridgeComponent } from "@hotwired/hotwire-native-bridge"
import { t } from "../../utils/i18n"

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

  // The two platforms' Google SDKs return different credentials, and this is
  // where that difference stops: Android's Credential Manager gives an ID token,
  // the iOS Sign-In SDK gives a serverAuthCode, and native_google accepts either.
  // Both are posted under the name the server expects; nothing else differs.
  handleAuthorization(data) {
    // Backing out of the account sheet is a choice, not a failure. Android says
    // so explicitly; without this the user gets told Google couldn't
    // authenticate them, which is both wrong and slightly alarming.
    if (data.cancelled) return

    const credential = data.idToken
      ? { id_token: data.idToken }
      : data.code
        ? { code: data.code, redirect_uri: "" }
        : null

    if (!credential) {
      this.showError(data.error || t("bridge.google.could_not_authenticate"))
      return
    }

    const formData = new FormData()
    Object.entries(credential).forEach(([key, value]) => formData.append(key, value))

    fetch("/users/auth/native_google", {
      method: "POST",
      body: formData
    })
      .then((response) => {
        if (response.redirected) {
          window.location.href = response.url
        } else {
          this.showError(t("bridge.google.authentication_failed"))
        }
      })
      .catch(() => {
        this.showError(t("bridge.google.authentication_failed"))
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
