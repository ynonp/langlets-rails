import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    window.scrollTo(0, 0)
    this.boundPopState = this.handlePopState.bind(this)
    window.addEventListener('popstate', this.boundPopState)
  }

  disconnect() {
    window.removeEventListener('popstate', this.boundPopState)
  }

  handlePopState() {
    const currentPath = window.location.pathname
    if (!currentPath.includes('/full-player')) {
      const frame = document.getElementById('course-content')
      if (frame) {
        frame.src = window.location.href
      }
    }
  }
}
