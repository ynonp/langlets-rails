import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "idle", "loading"]

  connect() {
    this.reset()
  }

  submit(event) {
    if (this.submitting) {
      event.preventDefault()
      return
    }

    this.submitting = true
    this.buttonTarget.disabled = true
    this.element.setAttribute("aria-busy", "true")
    this.idleTarget.hidden = true
    this.loadingTarget.hidden = false
  }

  reset() {
    this.submitting = false
    this.buttonTarget.disabled = false
    this.element.removeAttribute("aria-busy")
    this.idleTarget.hidden = false
    this.loadingTarget.hidden = true
  }
}
