import { Controller } from "@hotwired/stimulus"

// Client-side language filter for the homepage "Jump right in" grid. Each card
// carries a data-lang; each chip a lang param ("all" shows everything). No
// server round-trip, so the grid filters instantly.
export default class extends Controller {
  static targets = ["chip", "card"]
  static classes = ["active"]

  connect() {
    this.apply("all")
  }

  filter(event) {
    this.apply(String(event.params.lang))
  }

  apply(lang) {
    this.cardTargets.forEach((card) => {
      const show = lang === "all" || card.dataset.lang === lang
      card.hidden = !show
    })
    this.chipTargets.forEach((chip) => {
      const isActive = String(chip.dataset.homepageFilterLangParam) === lang
      chip.classList.toggle("is-active", isActive)
    })
  }
}
