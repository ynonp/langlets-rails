import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tabButton", "tabPanel"]

  connect() {
    const defaultTab = this.element.dataset.coursePlayerDefaultTab || "lyrics"
    this.showTab(defaultTab)
  }

  switch(event) {
    event.preventDefault()
    this.showTab(event.currentTarget.dataset.tab)
  }

  showTab(tabName) {
    this.tabButtonTargets.forEach((button) => {
      const isActive = button.dataset.tab === tabName
      button.dataset.active = isActive
      button.setAttribute("aria-selected", isActive)
    })

    this.tabPanelTargets.forEach((panel) => {
      panel.classList.toggle("hidden", panel.dataset.tab !== tabName)
    })
  }
}
