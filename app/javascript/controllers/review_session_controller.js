import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { closeUrl: String }

  beforeVisit(event) {
    const path = new URL(event.detail.url, window.location.href).pathname
    // Activity navigation and the finish page belong to this session.
    if (path === "/review_lessons" || path === "/review_lessons/finish") {
      this.internalNavigation = true
      return
    }
    this.close()
  }

  close(event) {
    if (event?.type === "pagehide" && this.internalNavigation) return
    if (this.sent) return
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    if (!token) return

    const data = new FormData()
    data.append("authenticity_token", token)
    data.append("background", "true")
    // Queue the request even when the document is being unloaded. The X button
    // also submits a regular POST for environments without a pagehide event.
    this.sent = navigator.sendBeacon(this.closeUrlValue, data)
  }
}
