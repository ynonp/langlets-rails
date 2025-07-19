import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="course-like"
export default class extends Controller {
  static targets = ["star", "count"]
  static values = { courseId: Number, liked: Boolean, likesCount: Number }

  connect() {
    this.updateUI()
  }

  toggle(event) {
    // Prevent the click from propagating to the parent link
    event.preventDefault()
    event.stopPropagation()
    
    // Only allow likes for authenticated users
    if (!this.element.dataset.authenticated) {
      // Could redirect to login or show a modal
      window.location.href = '/users/sign_in'
      return
    }

    // Optimistic UI update
    const wasLiked = this.likedValue
    this.likedValue = !wasLiked
    this.likesCountValue += this.likedValue ? 1 : -1
    this.updateUI()

    // Make the API call
    const url = this.likedValue 
      ? `/courses/${this.courseIdValue}/like`
      : `/courses/${this.courseIdValue}/unlike`
    
    const method = this.likedValue ? 'POST' : 'DELETE'

    fetch(url, {
      method: method,
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.error) {
        // Revert optimistic update on error
        this.likedValue = wasLiked
        this.likesCountValue = data.likes_count || (this.likesCountValue + (wasLiked ? 1 : -1))
        this.updateUI()
        console.error('Error:', data.error)
      } else {
        // Update with server response
        this.likedValue = data.liked
        this.likesCountValue = data.likes_count
        this.updateUI()
      }
    })
    .catch(error => {
      // Revert optimistic update on network error
      this.likedValue = wasLiked
      this.likesCountValue += wasLiked ? 1 : -1
      this.updateUI()
      console.error('Network error:', error)
    })
  }

  updateUI() {
    // Update star appearance
    if (this.likedValue) {
      this.starTarget.classList.remove('text-slate-400')
      this.starTarget.classList.add('text-yellow-400')
      this.starTarget.innerHTML = this.getFilledStarSVG()
    } else {
      this.starTarget.classList.remove('text-yellow-400')
      this.starTarget.classList.add('text-slate-400')
      this.starTarget.innerHTML = this.getOutlineStarSVG()
    }

    // Update count
    this.countTarget.textContent = this.likesCountValue
  }

  getFilledStarSVG() {
    return `
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-4 h-4">
        <path fill-rule="evenodd" d="M10.788 3.21c.448-1.077 1.976-1.077 2.424 0l2.082 5.006 5.404.434c1.164.093 1.636 1.545.749 2.305l-4.117 3.527 1.257 5.273c.271 1.136-.964 2.033-1.96 1.425L12 18.354 7.373 21.18c-.996.608-2.231-.29-1.96-1.425l1.257-5.273-4.117-3.527c-.887-.76-.415-2.212.749-2.305l5.404-.434 2.082-5.005Z" clip-rule="evenodd" />
      </svg>
    `
  }

  getOutlineStarSVG() {
    return `
      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4">
        <path stroke-linecap="round" stroke-linejoin="round" d="M11.48 3.499a.562.562 0 0 1 1.04 0l2.125 5.111a.563.563 0 0 0 .475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 0 0-.182.557l1.285 5.385a.562.562 0 0 1-.84.61l-4.725-2.885a.562.562 0 0 0-.586 0L6.982 20.54a.562.562 0 0 1-.84-.61l1.285-5.386a.563.563 0 0 0-.182-.557l-4.204-3.602a.562.562 0 0 1 .321-.988l5.518-.442a.563.563 0 0 0 .475-.345L11.48 3.5Z" />
      </svg>
    `
  }
}