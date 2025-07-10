import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="theme"
export default class extends Controller {
  static targets = ["toggle"]

  connect() {
    // Set initial theme from localStorage or default to dark
    const savedTheme = localStorage.getItem('theme') || 'dark'
    this.setTheme(savedTheme)
    this.updateToggleState(savedTheme)
  }

  toggleTheme() {
    const currentTheme = document.documentElement.classList.contains('dark') ? 'dark' : 'light'
    const newTheme = currentTheme === 'dark' ? 'light' : 'dark'
    
    this.setTheme(newTheme)
    this.updateToggleState(newTheme)
    
    // Save to localStorage
    localStorage.setItem('theme', newTheme)
  }

  setTheme(theme) {
    if (theme === 'dark') {
      document.documentElement.classList.add('dark')
      document.body.classList.remove('bg-white')
      document.body.classList.add('bg-gray-900')
    } else {
      document.documentElement.classList.remove('dark')
      document.body.classList.remove('bg-gray-900')
      document.body.classList.add('bg-white')
    }
  }

  updateToggleState(theme) {
    if (this.hasToggleTarget) {
      const icon = this.toggleTarget.querySelector('svg')
      const text = this.toggleTarget.querySelector('.theme-text')
      
      if (theme === 'dark') {
        // Show sun icon for switching to light mode
        icon.innerHTML = `
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z"></path>
        `
        if (text) text.textContent = 'Light Mode'
      } else {
        // Show moon icon for switching to dark mode
        icon.innerHTML = `
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z"></path>
        `
        if (text) text.textContent = 'Dark Mode'
      }
    }
  }
}