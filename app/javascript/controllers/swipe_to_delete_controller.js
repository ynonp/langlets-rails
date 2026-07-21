import { Controller } from "@hotwired/stimulus"

// Swipe-left-to-delete for queue cards (failed and ready items).
//
// The card sits inside a container with a red delete button behind it. Swiping
// left translates the card to reveal the button; releasing past the threshold
// snaps the card open. Tapping the revealed delete button submits the form.
//
// Uses pointer events so it works for both touch and mouse/trackpad.
export default class extends Controller {
  static values = {
    threshold: { type: Number, default: 80 } // px to swipe before snap-open
  }

  connect() {
    this.startX = 0
    this.currentX = 0
    this.isDragging = false
    this.isOpen = false

    this.element.addEventListener("pointerdown", this.#onPointerDown.bind(this))
    this.element.addEventListener("pointermove", this.#onPointerMove.bind(this))
    this.element.addEventListener("pointerup", this.#onPointerUp.bind(this))
    this.element.addEventListener("pointercancel", this.#onPointerUp.bind(this))
    this.element.addEventListener("pointerleave", this.#onPointerUp.bind(this))
    // Prevent the card from being dragged as an image
    this.element.addEventListener("dragstart", (e) => e.preventDefault())
  }

  disconnect() {
    // Cleanup handled by the browser when the element is removed
  }

  #onPointerDown(event) {
    // Only handle primary button / single touch
    if (event.pointerType === "mouse" && event.button !== 0) return

    this.startX = event.clientX
    this.currentX = event.clientX
    this.isDragging = true
    this.element.setPointerCapture(event.pointerId)
  }

  #onPointerMove(event) {
    if (!this.isDragging) return

    this.currentX = event.clientX
    const dx = this.currentX - this.startX

    // Only respond to leftward swipes
    if (dx > 0) {
      this.#setTranslate(0)
      return
    }

    // Clamp the translation so the card doesn't fly off screen
    const maxTranslate = this.thresholdValue + 40
    const translate = Math.max(-maxTranslate, dx)
    this.#setTranslate(translate)
  }

  #onPointerUp() {
    if (!this.isDragging) return
    this.isDragging = false

    const dx = this.currentX - this.startX

    if (dx < -this.thresholdValue) {
      // Snap open
      this.#setTranslate(-this.thresholdValue)
      this.isOpen = true
    } else {
      // Snap closed
      this.#setTranslate(0)
      this.isOpen = false
    }
  }

  #setTranslate(px) {
    const card = this.element.querySelector("[data-swipe-target='card']")
    if (card) {
      card.style.transform = `translateX(${px}px)`
      card.style.transition = this.isDragging ? "none" : "transform 0.2s ease-out"
    }
  }

  // Close the card if the user taps on it while it's open
  close() {
    if (this.isOpen) {
      this.#setTranslate(0)
      this.isOpen = false
    }
  }
}
