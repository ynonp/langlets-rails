import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "search"]

  connect() {
    this.searchTimeout = null
  }

  disconnect() {
    clearTimeout(this.searchTimeout)
  }

  search() {
    clearTimeout(this.searchTimeout)
    this.searchTimeout = setTimeout(() => this.submit(), 300)
  }

  submit() {
    clearTimeout(this.searchTimeout)
    this.formTarget.requestSubmit()
  }

  clearSearch() {
    this.searchTarget.value = ""
    this.submit()
    this.searchTarget.focus()
  }

  updateUrl() {
    const url = new URL(this.formTarget.action, window.location.href)
    const data = new FormData(this.formTarget)

    for (const [key, value] of data.entries()) {
      if (value) url.searchParams.append(key, value)
    }

    window.history.replaceState({}, "", url)
  }
}
