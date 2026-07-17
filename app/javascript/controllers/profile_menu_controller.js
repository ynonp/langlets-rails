import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle"]

  close(event) {
    if (this.element.contains(event.target)) return

    if (this.hasToggleTarget) {
      this.toggleTarget.checked = false
    } else {
      this.element.removeAttribute("open")
    }
  }
}
