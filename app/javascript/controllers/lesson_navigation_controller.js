import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    lessonId: Number
  }

  async markLessonCompleted(event) {
    event.preventDefault()
    if (!this.hasLessonIdValue || !this.lessonIdValue) return

    const payload = JSON.stringify({ lesson_id: this.lessonIdValue })

    try {
      await fetch("/progress", {
        method: "POST",
        body: payload,
        headers: { "Content-Type": "application/json" }
      })
    } catch (error) {
      console.error("Failed to mark lesson completed:", error)
    }

    const href = this.element.getAttribute("href")
    if (typeof Turbo !== "undefined") {
      Turbo.visit(href, { action: "replace" })
    } else {
      window.location.href = href
    }
  }
}
