import { Controller } from "@hotwired/stimulus"

// Client-side language filter for the homepage "Jump right in" grid. Each card
// carries a data-lang; each chip a lang param ("all" shows everything). No
// server round-trip, so the grid filters instantly.
//
// Picking a chip rewrites ?lang= in the address bar. The server reads the same
// param (ApplicationController#current_language_code), so the URL keeps telling
// the truth: it survives a reload, and it is shareable.
export default class extends Controller {
  static targets = ["chip", "card"]
  static classes = ["active"]
  static values = { initialLang: String }

  connect() {
    const requested = this.hasInitialLangValue ? this.initialLangValue : "all"
    const available = this.chipTargets.some((chip) =>
      String(chip.dataset.homepageFilterLangParam) === requested
    )

    this.apply(available ? requested : "all")
  }

  filter(event) {
    const lang = String(event.params.lang)
    this.apply(lang)
    this.syncUrl(lang)
  }

  // Only user-driven picks touch the URL — connect() just reflects what the
  // address bar already says.
  syncUrl(lang) {
    const url = new URL(window.location)
    if (lang === "all") {
      url.searchParams.delete("lang")
    } else {
      url.searchParams.set("lang", lang)
    }
    history.replaceState(history.state, "", url)
  }

  apply(lang) {
    let visibleCount = 0

    this.cardTargets.forEach((card) => {
      const matches = lang === "all" || card.dataset.lang === lang
      const show = matches && visibleCount < 8
      card.hidden = !show
      if (show) visibleCount += 1
    })
    this.chipTargets.forEach((chip) => {
      const isActive = String(chip.dataset.homepageFilterLangParam) === lang
      chip.classList.toggle("is-active", isActive)
    })
  }
}
