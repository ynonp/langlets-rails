import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    window.scrollTo(0, 0)
  }
}
