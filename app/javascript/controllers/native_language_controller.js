import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "submit"]
  static values = { initial: String }

  change() {
    this.submitTarget.disabled = this.selectTarget.value === this.initialValue
  }
}
