import { Controller } from "@hotwired/stimulus"

// Toggles the site-wide light/dark theme. Flips `data-theme` on <html> for an
// instant visual change, swaps the button icon, then persists the choice to the
// server (cookie + the signed-in user's preferences).
export default class extends Controller {
  static values = { url: String }

  toggle() {
    const html = document.documentElement
    const next = html.getAttribute("data-theme") === "dark" ? "light" : "dark"

    html.setAttribute("data-theme", next)
    this.updateIcons(next)
    this.persist(next)
  }

  updateIcons(theme) {
    // Use attributes (not the `.hidden` IDL property, which SVG elements lack)
    // so the icon swap works for the inline <svg> icons.
    this.element.querySelectorAll("[data-theme-icon]").forEach((icon) => {
      if (icon.getAttribute("data-theme-icon") === theme) {
        icon.removeAttribute("hidden")
      } else {
        icon.setAttribute("hidden", "")
      }
    })
  }

  persist(theme) {
    if (!this.hasUrlValue) return

    const token = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": token || ""
      },
      body: JSON.stringify({ theme })
    }).catch(() => {})
  }
}
