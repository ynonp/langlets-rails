import { Controller } from "@hotwired/stimulus"

// The toast under the Vocabulary tab.
//
// Plain confirmations fade out on their own. A toast carrying Undo passes
// timeout 0 and stays put: it is the only route back from a delete, and a
// countdown the user cannot see is a bad thing to hang that on. It goes away
// on the next navigation like any other flash.
export default class extends Controller {
  static values = { timeout: { type: Number, default: 4000 } }

  connect() {
    if (this.timeoutValue <= 0) return

    this.timer = setTimeout(() => this.dismiss(), this.timeoutValue)
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  dismiss() {
    this.element.remove()
  }
}
