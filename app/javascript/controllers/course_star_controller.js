import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { courseId: String, starred: Boolean }
  static targets = ["count"]

  connect() {
    // Add click handler to the button within this controller element
    const button = this.element.querySelector('button')
    if (button) {
      button.addEventListener('click', (event) => {
        event.preventDefault()
        event.stopPropagation()
        this.toggle()
      })
    }
  }

  async toggle() {
    try {
      const response = await fetch(`/courses/${this.courseIdValue}/star`, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Accept': 'application/json',
          'Content-Type': 'application/json'
        }
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }

      const data = await response.json()
      
      // Update UI based on response
      this.updateStarDisplay(data.starred, data.stars_count)
      this.starredValue = data.starred

    } catch (error) {
      console.error('Error toggling star:', error)
      // You could add a toast notification here
    }
  }

  updateStarDisplay(starred, count) {
    const svg = this.element.querySelector('svg')
    const countElement = this.countTarget

    if (starred) {
      // Starred state
      svg.classList.remove('text-slate-400', 'hover:text-yellow-400')
      svg.classList.add('text-yellow-400', 'fill-current')
      svg.setAttribute('fill', 'currentColor')
    } else {
      // Unstarred state
      svg.classList.remove('text-yellow-400', 'fill-current')
      svg.classList.add('text-slate-400', 'hover:text-yellow-400')
      svg.setAttribute('fill', 'none')
    }

    // Update count
    countElement.textContent = count

    // Add a small animation effect
    svg.style.transform = 'scale(1.2)'
    setTimeout(() => {
      svg.style.transform = 'scale(1)'
    }, 150)
  }
}