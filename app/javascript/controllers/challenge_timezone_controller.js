import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select"]
  static values = { autodetect: Boolean }

  connect() {
    if (!this.autodetectValue) return
    const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone
    if (!timezone) return
    if (![...this.selectTarget.options].some(option => option.value === timezone)) {
      this.selectTarget.add(new Option(timezone, timezone))
    }
    this.selectTarget.value = timezone
  }
}
