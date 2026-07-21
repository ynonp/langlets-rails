import { Controller } from "@hotwired/stimulus"

// Refreshes the Queue while imports are in flight.
//
// Polling rather than Action Cable: this app has no channels at all, a WKWebView
// socket dies whenever iOS backgrounds the app, and the pipeline only reports at
// LLM step boundaries — tens of seconds apart — so sub-second delivery buys
// nothing. The signal that matters when an import finishes is the push.
//
// Stops as soon as nothing is active, so an idle Queue costs zero requests.
//
// To avoid thumbnail flashes, each card is split into a static #thumb area and a
// replaceable #body area. The poll sends the set of known card IDs so the server
// can add/remove cards and replace only the body (or the thumb when a queued
// item's clock placeholder needs to become a real thumbnail).
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
    if (window.Turbo) {
      const url = new URL(window.location.href)
      url.searchParams.set("known", this.#knownIds())

      fetch(url, {
        headers: { Accept: "text/vnd.turbo-stream.html" },
        credentials: "same-origin"
      })
        .then(response => response.ok ? response.text() : Promise.reject(response.status))
        .then(html => {
          window.Turbo.renderStreamMessage(html)
          this.#afterRefresh()
        })
        .catch(() => {}) // transient network hiccup; the next tick tries again
    } else {
      window.location.reload()
    }
  }

  // After the Turbo Stream is applied, update visibility and check whether to
  // keep polling.
  #afterRefresh() {
    const hasItems = this.#cardCount() > 0
    const emptyEl = document.getElementById("queue-empty")
    const listEl = document.getElementById("queue-list")

    if (emptyEl) emptyEl.classList.toggle("hidden", hasItems)
    if (listEl) listEl.classList.toggle("hidden", !hasItems)

    if (!this.#hasActiveItems()) {
      this.stop()
    }
  }

  // Collects the IDs (and statuses) of every import-request card currently in
  // the DOM so the server knows which ones to update in-place and which are new
  // or gone.  Format: "id1:status1,id2:status2"
  #knownIds() {
    const cards = this.element.querySelectorAll("[data-import-request-status]")
    return Array.from(cards)
      .map(card => `${card.id}:${card.dataset.importRequestStatus}`)
      .join(",")
  }

  #cardCount() {
    return this.element.querySelectorAll("[data-import-request-status]").length
  }

  // True when at least one card in the queue is still queued or importing.
  #hasActiveItems() {
    return this.element.querySelectorAll(
      "[data-import-request-status=\"queued\"], [data-import-request-status=\"importing\"]"
    ).length > 0
  }
}
