import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="stop-practicing"
// Handles removing/restoring a token translation from user's saved vocabulary.
export default class extends Controller {
  static values = { tokenId: Number, removed: Boolean }
  static targets = ["label", "button"]

  toggle(event) {
    event.stopPropagation()

    if (this.removedValue) {
      fetch('/token_translation_users', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({ token_translation_id: this.tokenIdValue })
      })
        .then(r => r.json())
        .then(() => { this.removedValue = false })
        .catch(err => console.warn('Failed to re-add token:', err))
    } else {
      fetch(`/token_translation_users/${this.tokenIdValue}`, {
        method: 'DELETE',
        headers: { 'X-CSRF-Token': this.csrfToken }
      })
        .then(r => r.json())
        .then(() => { this.removedValue = true })
        .catch(err => console.warn('Failed to remove token:', err))
    }
  }

  removedValueChanged() {
    if (!this.hasLabelTarget) return

    if (this.removedValue) {
      this.labelTarget.innerHTML = 'Word removed from your vocab. <span class="underline">undo</span>'
      this.buttonTarget.classList.remove('text-gray-400', 'hover:text-red-400')
      this.buttonTarget.classList.add('text-yellow-400', 'hover:text-yellow-300')
      this.buttonTarget.disabled = false
      this.buttonTarget.style.cursor = ''
    } else {
      this.labelTarget.textContent = '🚫 Stop Practicing This Word'
      this.buttonTarget.classList.remove('text-yellow-400', 'hover:text-yellow-300')
      this.buttonTarget.classList.add('text-gray-400', 'hover:text-red-400')
      this.buttonTarget.disabled = false
      this.buttonTarget.style.cursor = ''
    }
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ''
  }
}
