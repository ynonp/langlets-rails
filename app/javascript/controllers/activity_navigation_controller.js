import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ['content'];

  connect() {
    this.prefetchNextActivity();
  }

  activityChange(event) {
    const path = this.contentTarget.dataset.activityNavigationUrl;
    history.pushState(null, '', path);
    this.prefetchNextActivity();
  }

  // Warm the browser's HTTP cache with the next activity's frame response so the
  // "Next" tap transitions instantly. Only devices without hover need this:
  // desktop already gets Turbo's built-in hover prefetch. The response is made
  // cacheable for 10 minutes in LessonsController#show (frame requests only).
  prefetchNextActivity() {
    if (window.matchMedia("(hover: hover)").matches) return;
    if (!this.hasContentTarget) return;

    const next = this.contentTarget.dataset.activityNavigationNextUrl;
    if (!next) return;

    fetch(next, {
      headers: { "Turbo-Frame": "activity", "Accept": "text/html" },
      priority: "low",
    }).catch(() => {});
  }
}
