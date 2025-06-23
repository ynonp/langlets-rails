import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["element"]

  // Action method for turbo:load event
  handleTurboLoad() {
    if (this.hasElementTarget) {
      requestAnimationFrame(() => {
        this.elementTarget.scrollIntoView({ 
          behavior: "smooth", 
          block: "center" 
        })
      })
    }
  }
}
