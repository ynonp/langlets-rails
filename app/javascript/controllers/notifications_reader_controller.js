import { Controller } from "@hotwired/stimulus"

// Reports "the user entered the app", which the server treats as having read
// every pending notification.
//
// Mounted in the native app layout only. Entering the app is the moment the
// count is meant to zero — the app icon badge is the prompt to come back, and
// once they have, it has done its job (SceneDelegate clears the icon badge on
// the same event from the native side).
//
// Two triggers, because iOS has two ways in: a cold launch loads the page
// (connect), and returning from the background does not (visibilitychange).
// Ordinary Turbo navigation between tabs does re-connect this, which is
// harmless — read_all is idempotent, and a second call is a no-op UPDATE
// touching no rows.
//
// It deliberately does not rewrite the page it is on: /notifications renders
// its unread markers from a snapshot taken before this fires, so a user who
// opened the app to look at what is new still sees it.
export default class extends Controller {
  static values = { endpoint: String }

  connect() {
    this.reportRead()
    this.onVisibilityChange = () => {
      if (document.visibilityState === "visible") this.reportRead()
    }
    document.addEventListener("visibilitychange", this.onVisibilityChange)
  }

  disconnect() {
    document.removeEventListener("visibilitychange", this.onVisibilityChange)
  }

  async reportRead() {
    if (!this.endpointValue) return

    try {
      await fetch(this.endpointValue, {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
        }
      })
    } catch (error) {
      // Nothing to recover: the notifications are still there, still unread,
      // and the next launch reports again.
      console.warn("Could not report notifications as read", error)
    }
  }
}
