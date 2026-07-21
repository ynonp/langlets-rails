import { Controller } from "@hotwired/stimulus"

// Swipe-left-to-delete for queue cards (failed and ready items).
//
// The card sits inside a container with a red delete button behind it. Swiping
// left translates the card to reveal the button; releasing past the threshold
// snaps the card open. Tapping the revealed delete button removes the card
// optimistically from the DOM, then sends a DELETE to the server. The server
// responds with a Turbo Stream that replaces the full queue state — normally a
// no-op since the card is already gone, but it corrects the page if the delete
// was rejected.
//
// Uses pointer events so it works for both touch and mouse/trackpad.
export default class extends Controller {
  static values = {
    threshold: { type: Number, default: 80 }
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
    this.element.addEventListener("dragstart", (e) => e.preventDefault())
  }

  disconnect() {
    // Cleanup handled by the browser when the element is removed
  }

  // Optimistic removal: take the card out of the DOM immediately, then send the
  // DELETE. The server's Turbo Stream response replaces the full queue state,
  // which corrects the page if the delete was rejected.
  remove(event) {
    event.preventDefault()
    const form = event.currentTarget.closest("form")
    if (!form) return

    const wrapper = this.element
    wrapper.remove()

    fetch(form.action, {
      method: "DELETE",
      headers: {
        Accept: "text/vnd.turbo-stream.html",
        "X-CSRF-Token": document.querySelector("[name='csrf-token']")?.content || ""
      },
      credentials: "same-origin"
    })
      .then(response => response.ok ? response.text() : Promise.reject(response.status))
      .then(html => {
        if (window.Turbo) window.Turbo.renderStreamMessage(html)
      })
      .catch(() => {}) // server will surface any real problem on next poll
  }

  #onPointerDown(event) {
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

    if (dx > 0) {
      this.#setTranslate(0)
      return
    }

    const maxTranslate = this.thresholdValue + 40
    const translate = Math.max(-maxTranslate, dx)
    this.#setTranslate(translate)
  }

  #onPointerUp() {
    if (!this.isDragging) return
    this.isDragging = false

    const dx = this.currentX - this.startX

    if (dx < -this.thresholdValue) {
      this.#setTranslate(-this.thresholdValue)
      this.isOpen = true
    } else {
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

  close() {
    if (this.isOpen) {
      this.#setTranslate(0)
      this.isOpen = false
    }
  }
}
