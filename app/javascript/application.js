// Entry point for the build script in your package.json

import "@hotwired/turbo-rails"
import "./controllers"

// Review-lesson builds broadcast this after their transaction commits. Turbo's
// signed stream subscription scopes the visit to the browser waiting for that
// particular build.
//
// Supports data-visit-action="replace" so the visit can replace the current
// history entry rather than pushing a new one. This keeps the iOS app inside
// the same modal sheet instead of opening a second modal on top of the
// waiting screen.
window.Turbo.StreamActions.visit = function () {
  const action = this.dataset.visitAction || "advance"
  window.Turbo.visit(this.getAttribute("url"), { action })
}

// Native tabs retain independent webviews. A stream response in one tab can
// ask the shell to refresh another by naming it with `tab="..."`.
window.Turbo.StreamActions.refresh_native_tab = function () {
  const tab = this.getAttribute("tab")
  if (!tab) return

  window.dispatchEvent(new CustomEvent("native-tab:refresh", { detail: { tab } }))
}


// Update the retained course DOM without asking the native navigator to visit:
// a visit from the main webview while a lesson is modal can dismiss the lesson.
import { refreshCourseProgress } from "./utils/refresh_course_progress"
window.Turbo.StreamActions.refresh_course_progress = function () {
  return refreshCourseProgress(document.getElementById(this.target))
}
