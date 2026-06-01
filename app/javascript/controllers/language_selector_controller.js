import { Controller } from "@hotwired/stimulus"

// Language selector controller with localStorage persistence
export default class extends Controller {
  static values = {
    current: String
  }

  connect() {
    // On page load, check localStorage and apply saved language preference
    this.applySavedLanguage()
  }

  applySavedLanguage() {
    // Get saved language from localStorage
    const savedLang = localStorage.getItem('langlets_selected_language')

    // If there's a saved language and it's different from the current URL param
    if (savedLang !== null && savedLang !== this.currentValue) {
      // Update URL to include the saved language parameter
      const url = new URL(window.location.href)
      if (savedLang === '') {
        // Remove lang param for "All Languages"
        url.searchParams.delete('lang')
      } else {
        url.searchParams.set('lang', savedLang)
      }

      // Only redirect if the URL actually changed
      if (url.toString() !== window.location.href) {
        window.location.href = url.toString()
      }
    } else if (savedLang === null && this.currentValue) {
      // If no saved language but URL has a lang param, save it to localStorage
      localStorage.setItem('langlets_selected_language', this.currentValue)
    }
  }

  selectLanguage(event) {
    // Get the language code from the clicked element
    const langCode = event.currentTarget.dataset.lang || ''

    // Save to localStorage
    localStorage.setItem('langlets_selected_language', langCode)

    // Let the link naturally navigate (no need to prevent default)
  }
}
