import { Controller } from "@hotwired/stimulus"

const ACTIVE_CLASSES = ["bg-slate-100", "text-slate-900"]
const INACTIVE_CLASSES = ["bg-slate-800", "text-slate-300", "hover:bg-slate-700", "hover:text-slate-100"]

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { defaultTab: String }

  connect() {
    const initialTabId = this.defaultTabValue || this.tabTargets[0]?.dataset.tabsTabId
    if (initialTabId) this.activate(initialTabId)
  }

  select(event) {
    event.preventDefault()
    this.activate(event.currentTarget.dataset.tabsTabId)
  }

  onKeydown(event) {
    const currentIndex = this.tabTargets.indexOf(event.currentTarget)
    if (currentIndex < 0) return

    switch (event.key) {
    case "ArrowRight":
      event.preventDefault()
      this.focusTabByIndex((currentIndex + 1) % this.tabTargets.length)
      break
    case "ArrowLeft":
      event.preventDefault()
      this.focusTabByIndex((currentIndex - 1 + this.tabTargets.length) % this.tabTargets.length)
      break
    case "Home":
      event.preventDefault()
      this.focusTabByIndex(0)
      break
    case "End":
      event.preventDefault()
      this.focusTabByIndex(this.tabTargets.length - 1)
      break
    case "Enter":
    case " ":
      event.preventDefault()
      this.activate(event.currentTarget.dataset.tabsTabId)
      break
    }
  }

  activate(tabId) {
    this.tabTargets.forEach((tab) => {
      const isActive = tab.dataset.tabsTabId === tabId
      tab.setAttribute("aria-selected", isActive.toString())
      tab.setAttribute("tabindex", isActive ? "0" : "-1")
      tab.classList.toggle("font-semibold", isActive)
      ACTIVE_CLASSES.forEach((className) => tab.classList.toggle(className, isActive))
      INACTIVE_CLASSES.forEach((className) => tab.classList.toggle(className, !isActive))
    })

    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.dataset.tabsTabId !== tabId
    })
  }

  focusTabByIndex(index) {
    this.tabTargets[index].focus()
  }
}
