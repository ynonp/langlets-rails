import { Controller } from "@hotwired/stimulus"

// Simple tab switcher used to toggle between panels (e.g. the "Courses" and
// "Standalone Clips" grids on the homepage) without a page reload.
export default class extends Controller {
  static targets = ["tab", "panel"]

  select(event) {
    const name = event.params.name

    this.tabTargets.forEach((tab) => {
      const isActive = tab.dataset.tabsNameParam === name
      tab.classList.toggle("s-btn--soft", !isActive)
      tab.setAttribute("aria-selected", isActive)
    })

    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.dataset.tabsName !== name
    })
  }
}
