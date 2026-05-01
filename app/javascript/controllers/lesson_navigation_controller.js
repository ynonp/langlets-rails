import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    lessonId: Number
  }

  markLessonCompleted(event) {
    event.preventDefault()
    if (!this.hasLessonIdValue || !this.lessonIdValue) return

    const payload = JSON.stringify({ lesson_id: this.lessonIdValue })
    navigator.sendBeacon("/progress", new Blob([payload], {
      type: "application/json"
    }))

    const href = this.element.getAttribute("href")
    if (typeof Turbo !== "undefined") {
      Turbo.visit(href, { action: "replace" })
    } else {
      window.location.href = href
    }
  }
}
