import { Controller } from "@hotwired/stimulus"

// Controls tab switching for the standalone player page
export default class extends Controller {
  static targets = ["tabButton", "tabContent"]

  connect() {
    // Initialize with the first tab active
    this.activateTab("lyrics")
  }

  switchTab(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const tabName = event.currentTarget.dataset.tab
    this.activateTab(tabName)
  }

  activateTab(tabName) {
    // Update button styles
    this.tabButtonTargets.forEach(button => {
      const isActive = button.dataset.tab === tabName
      
      if (isActive) {
        button.classList.remove("text-gray-400", "border-transparent", "hover:border-gray-600")
        button.classList.add("text-white", "border-blue-500", "bg-gray-800")
      } else {
        button.classList.remove("text-white", "border-blue-500", "bg-gray-800")
        button.classList.add("text-gray-400", "border-transparent", "hover:border-gray-600")
      }
    })

    // Show/hide content
    this.tabContentTargets.forEach(content => {
      const isActive = content.dataset.tab === tabName
      
      if (isActive) {
        content.classList.remove("hidden")
      } else {
        content.classList.add("hidden")
      }
    })
  }
}
