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
