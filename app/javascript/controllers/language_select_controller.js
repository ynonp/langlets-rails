import { Controller } from "@hotwired/stimulus"

// Navigates to the selected option's URL. Used by the web language picker,
// where each option carries a ?lang=<iso> URL (or ?lang=all to clear it).
//
// Usage: data-controller="language-select" data-action="change->language-select#navigate"
export default class extends Controller {
  navigate(event) {
    const url = event.target.value
    if (url) window.location.href = url
  }
}
