import { Controller } from "@hotwired/stimulus"

// Keeps the paywall's CTA in step with the selected plan.
//
// Deliberately does *not* style the cards — that is `:has(:checked)` in the
// markup, so the selection is right before this controller connects and keeps
// working if it never does. All that is left is the one thing CSS cannot do:
// carry the chosen product id and its price onto the button that
// bridge--apple-purchase reads.
export default class extends Controller {
  static targets = ["option", "cta"]

  choose(event) {
    const option = event.currentTarget
    this.ctaTarget.dataset.productId = option.dataset.productId
    this.ctaTarget.textContent = option.dataset.ctaLabel
  }
}
