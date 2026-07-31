import { Controller } from "@hotwired/stimulus"

// The course page "..." action sheet: Add to Playlist (delegated to the
// course-paths controller on the same element) or Delete, which opens its own
// confirmation sheet rather than window.confirm — unsupported in the Hotwire
// Native app.
export default class extends Controller {
  static targets = ["menuOverlay", "menuPanel", "deleteOverlay"]

  openMenu() {
    this.menuOverlayTarget.classList.remove("hidden")
    this.menuPanelTarget.classList.remove("hidden")
  }

  closeMenu() {
    this.menuOverlayTarget.classList.add("hidden")
    this.menuPanelTarget.classList.add("hidden")
  }

  openDelete() {
    this.closeMenu()
    this.deleteOverlayTarget.classList.remove("hidden")
  }

  closeDelete() {
    this.deleteOverlayTarget.classList.add("hidden")
  }
}
