import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["star", "count"]
  static values = { courseId: String, liked: Boolean, count: Number }

  connect() {
    this.updateDisplay()
  }

  async toggle(event) {
    // Prevent the click from bubbling to the course link
    event.stopPropagation()
    event.preventDefault()
    
    // Prevent multiple clicks while processing
    if (this.starTarget.disabled) return
    this.starTarget.disabled = true

    try {
      const response = await fetch(`/courses/${this.courseIdValue}/toggle_like`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })

      if (response.ok) {
        const data = await response.json()
        this.likedValue = data.liked
        this.countValue = data.likes_count
        this.updateDisplay()
      } else {
        console.error('Failed to toggle like')
      }
    } catch (error) {
      console.error('Error toggling like:', error)
    } finally {
      this.starTarget.disabled = false
    }
  }

  updateDisplay() {
    // Update star appearance
    if (this.likedValue) {
      this.starTarget.classList.remove('text-slate-400')
      this.starTarget.classList.add('text-yellow-400')
      this.starTarget.innerHTML = this.filledStarSvg()
    } else {
      this.starTarget.classList.remove('text-yellow-400')
      this.starTarget.classList.add('text-slate-400')
      this.starTarget.innerHTML = this.outlineStarSvg()
    }

    // Update count
    if (this.hasCountTarget) {
      this.countTarget.textContent = this.countValue
    }
  }

  filledStarSvg() {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-5 h-5">
      <path fill-rule="evenodd" d="M10.788 3.21c.448-1.077 1.976-1.077 2.424 0l2.082 5.006 5.404.434c1.164.093 1.636 1.545.749 2.305l-4.117 3.527 1.257 5.273c.271 1.136-.964 2.033-1.96 1.425L12 18.354 7.373 21.18c-.996.608-2.231-.29-1.96-1.425l1.257-5.273-4.117-3.527c-.887-.76-.415-2.212.749-2.305l5.404-.434 2.082-5.005Z" clip-rule="evenodd" />
    </svg>`
  }

  outlineStarSvg() {
    return `<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
      <path stroke-linecap="round" stroke-linejoin="round" d="M11.48 3.499a.562.562 0 0 1 1.04 0l2.125 5.111a.563.563 0 0 0 .475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 0 0-.182.557l1.285 5.385a.562.562 0 0 1-.84.61l-4.725-2.885a.562.562 0 0 0-.586 0L6.982 20.54a.562.562 0 0 1-.84-.61l1.285-5.386a.563.563 0 0 0-.182-.557l-4.204-3.602a.562.562 0 0 1 .321-.988l5.518-.442a.563.563 0 0 0 .475-.345L11.48 3.5Z" />
    </svg>`
  }
}