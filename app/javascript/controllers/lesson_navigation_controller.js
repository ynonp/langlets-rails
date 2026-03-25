import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    lessonId: Number
  }

  markLessonCompleted() {
    if (!this.hasLessonIdValue || !this.lessonIdValue) return

    const payload = JSON.stringify({ lesson_id: this.lessonIdValue })

    navigator.sendBeacon("/progress", new Blob([payload], {
      type: "application/json"
    }))
  }
}
