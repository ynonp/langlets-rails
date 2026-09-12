import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { poll: Boolean }

  connect() {
    if (this.pollValue) {
      this.timer = setTimeout(() => window.location.reload(), 4000)
    } else if (this.element instanceof HTMLFormElement) {
      this.element.requestSubmit()
    }
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
