import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "card"]

  select(event) {
    const selected = event.currentTarget

    this.inputTarget.value = selected.dataset.videoUrl
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.cardTargets.forEach((card) => card.setAttribute("aria-pressed", card === selected ? "true" : "false"))
    this.inputTarget.focus({ preventScroll: true })
    this.inputTarget.scrollIntoView({ behavior: "smooth", block: "center" })
  }
}
