import { Controller } from "@hotwired/stimulus"
import { t } from "../utils/i18n"

// The course page "..." action sheet: Add to Playlist (delegated to the
// course-paths controller on the same element), Share to a public URL
// (toggles to Stop sharing once shared, alongside a Copy public URL item that
// re-copies the same link without changing sharing state), or Delete, which
// opens its own confirmation sheet rather than window.confirm — unsupported
// in the Hotwire Native app.
export default class extends Controller {
  static targets = ["menuOverlay", "menuPanel", "deleteOverlay", "shareButton", "shareLabel", "copyUrlButton", "toast"]

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
        // Copying must never block showing the toast/flipping the label below:
        // navigator.clipboard is undefined in some WebViews (notably the
        // Hotwire Native shells), and accessing .writeText on it throws
        // synchronously rather than rejecting, so it has to be isolated in its
        // own try/catch rather than a chained .catch().
        this.copyToClipboard(data.public_url)
        button.dataset.shared = "true"
        this.shareLabelTarget.textContent = t("course_menu.stop_sharing")
        this.copyUrlButtonTarget.classList.remove("hidden")
        this.showToast(t("course_menu.shared_message"))
      } else {
        button.dataset.shared = "false"
        this.shareLabelTarget.textContent = t("course_menu.share_to_public_url")
        this.copyUrlButtonTarget.classList.add("hidden")
        this.showToast(t("course_menu.unshared_message"))
      }
    } catch (e) {
      console.error(e)
    }
  }

  // Re-copies the already-shared course's public URL without touching sharing
  // state — for a course shared earlier in a previous visit, whose link the
  // user just wants again.
  async copyPublicUrl() {
    this.closeMenu()
    await this.copyToClipboard(this.shareButtonTarget.dataset.publicUrl)
    this.showToast(t("course_menu.shared_message"))
  }

  // Tries the modern Clipboard API, then falls back to the legacy
  // execCommand("copy") path, which needs no permission and works in WebViews
  // that don't implement navigator.clipboard at all.
  async copyToClipboard(text) {
    if (navigator.clipboard?.writeText) {
      try {
        await navigator.clipboard.writeText(text)
        return
      } catch (_e) {
        // fall through to the legacy path below
      }
    }

    const textarea = document.createElement("textarea")
    textarea.value = text
    textarea.setAttribute("readonly", "")
    textarea.style.position = "fixed"
    textarea.style.opacity = "0"
    document.body.appendChild(textarea)
    textarea.select()
    textarea.setSelectionRange(0, text.length)
    try {
      document.execCommand("copy")
    } catch (_e) {
      // No copy mechanism available; the toast still confirms the share itself.
    }
    document.body.removeChild(textarea)
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
