import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  close(event) {
    if (this.element.contains(event.target)) return

    this.element.removeAttribute("open")
  }
}
