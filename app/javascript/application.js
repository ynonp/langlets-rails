// Entry point for the build script in your package.json

import "@hotwired/turbo-rails"
import "./controllers"

// Review-lesson builds broadcast this after their transaction commits. Turbo's
// signed stream subscription scopes the visit to the browser waiting for that
// particular build.
window.Turbo.StreamActions.visit = function () {
  window.Turbo.visit(this.getAttribute("url"))
}
