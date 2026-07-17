import { Controller } from "@hotwired/stimulus"

// Refreshes the Queue while imports are in flight.
//
// Polling rather than Action Cable: this app has no channels at all, a WKWebView
// socket dies whenever iOS backgrounds the app, and the pipeline only reports at
// LLM step boundaries — tens of seconds apart — so sub-second delivery buys
// nothing. The signal that matters when an import finishes is the push.
//
// Stops as soon as nothing is active, so an idle Queue costs zero requests.
export default class extends Controller {
  static values = {
    interval: { type: Number, default: 3000 },
    active: { type: Boolean, default: false }
  }

  connect() {
    this.start()
    // No point polling a screen nobody is looking at, and iOS freezes timers in
    // background tabs anyway — refresh once on return instead.
    this.visibilityHandler = () => {
      if (document.visibilityState === "visible") {
        this.refresh()
        this.start()
      } else {
        this.stop()
      }
    }
    document.addEventListener("visibilitychange", this.visibilityHandler)
  }

  disconnect() {
    this.stop()
    document.removeEventListener("visibilitychange", this.visibilityHandler)
  }

  start() {
    this.stop()
    if (!this.activeValue) return

    this.timer = setInterval(() => this.refresh(), this.intervalValue)
  }

  stop() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }

  refresh() {
    // Turbo replaces the body and re-renders this element with a fresh
    // data-poll-active-value, so the loop ends by itself once every import has
    // finished.
    if (window.Turbo) {
      window.Turbo.visit(window.location.href, { action: "replace" })
    } else {
      window.location.reload()
    }
  }
}
