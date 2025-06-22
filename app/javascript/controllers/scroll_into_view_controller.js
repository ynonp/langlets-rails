import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["element"]

  connect() {
    if (this.hasElementTarget) {
      this.elementTarget.scrollIntoView({ 
        behavior: "smooth", 
        block: "center" 
      })
    }
  }
}
