import { Controller } from "@hotwired/stimulus"
import { t } from "../utils/i18n"

// The course page "..." action sheet: Add to Playlist (delegated to the
// course-paths controller on the same element), Share to a public URL
// (toggles to Stop sharing once shared), or Delete, which opens its own
// confirmation sheet rather than window.confirm — unsupported in the Hotwire
// Native app.
export default class extends Controller {
  static targets = ["menuOverlay", "menuPanel", "deleteOverlay", "shareButton", "shareLabel", "toast"]

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

  async toggleShare() {
    this.closeMenu()
    const button = this.shareButtonTarget
    const shared = button.dataset.shared === "true"
    const path = shared ? button.dataset.unsharePath : button.dataset.sharePath

    try {
      const response = await fetch(path, { method: "POST", headers: this.headers() })
      if (!response.ok) throw new Error("share toggle failed")
      const data = await response.json()

      if (data.shared) {
        await navigator.clipboard.writeText(data.public_url).catch(() => {})
        button.dataset.shared = "true"
        this.shareLabelTarget.textContent = t("course_menu.stop_sharing")
        this.showToast(t("course_menu.shared_message"))
      } else {
        button.dataset.shared = "false"
        this.shareLabelTarget.textContent = t("course_menu.share_to_public_url")
        this.showToast(t("course_menu.unshared_message"))
      }
    } catch (e) {
      console.error(e)
    }
  }

  showToast(message) {
    this.toastTarget.textContent = message
    this.toastTarget.classList.remove("hidden")
    clearTimeout(this.toastTimeout)
    this.toastTimeout = setTimeout(() => this.toastTarget.classList.add("hidden"), 2500)
  }

  headers() {
    return {
      "X-CSRF-Token": document.querySelector('[name="csrf-token"]').content,
      Accept: "application/json"
    }
  }
}
