import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  complete() {
    this.element.dispatchEvent(new CustomEvent('activity:completed', { bubbles: true }))
  }
}
