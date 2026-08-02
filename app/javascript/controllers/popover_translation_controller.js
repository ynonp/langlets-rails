import { Controller } from "@hotwired/stimulus"
import { t } from "../utils/i18n"

export default class extends Controller {
  static targets = ['translationPopup', 'translationText', 'saveButton', 'saveIcon', 'saveText'];
  static values = { savedIds: Array, savedTokenClasses: String, savedIdsUrl: String };

  initialize() {
    this.currentTokenId = null;
    this.savedIdsReady = Promise.resolve();
  }

  connect() {
    if (!this.savedIdsUrlValue) return;

    this.savedIdsReady = this._refreshSavedIds();
  }

  async _refreshSavedIds() {
    try {
      const response = await fetch(this.savedIdsUrlValue, {
        headers: { 'Accept': 'application/json' },
        cache: 'no-store'
      });
      if (!response.ok) throw new Error(`Saved vocabulary request failed: ${response.status}`);

      const data = await response.json();
      this.savedIdsValue = data.token_ids;
      this._updateSaveButton();
    } catch (err) {
      console.warn('Failed to refresh saved vocabulary:', err);
    }
  }

  savedIdsValueChanged() {
    if (!this.hasSavedTokenClassesValue) return;

    const savedClasses = this.savedTokenClassesValue.split(' ');
    this.element.querySelectorAll('[data-token-id]').forEach((token) => {
      const tokenId = parseInt(token.dataset.tokenId);
      savedClasses.forEach((className) => {
        token.classList.toggle(className, this._isSaved(tokenId));
      });
    });
  }

  _isSaved(tokenId) {
    return this.savedIdsValue.includes(tokenId);
  }

  hidePopup() {
    if (this.translationPopupTarget.classList.contains('hidden')) return;
    this.translationPopupTarget.classList.add('hidden');
    // Stop the word audio that was started when the popup opened
    this.element.dispatchEvent(new CustomEvent('audio-cache:stop', { bubbles: true }));
  }

  showPopup(ev) {
    const tokenEl = ev.target.closest('[data-translation]');
    if (!tokenEl) {
      this.hidePopup();
      return;
    }

    if (!this.translationPopupTarget.classList.contains('hidden')) {
      this.hidePopup();
      ev.stopPropagation();
      return;
    }

    const translation = tokenEl.dataset.translation;
    const tokenId = tokenEl.dataset.tokenId ? parseInt(tokenEl.dataset.tokenId) : null;

    this.currentTokenId = tokenId;

    this.translationTextTarget.textContent = translation;

    // Un-hide first so the popup has a measurable width for clamping.
    this.translationPopupTarget.classList.remove('hidden');

    const rect = tokenEl.getBoundingClientRect();
    const margin = 8;
    const popupWidth = this.translationPopupTarget.offsetWidth;

    // Anchor on the token, then clamp so the popup stays fully on-screen.
    let left = rect.left + (rect.width / 2);
    const maxLeft = window.innerWidth - popupWidth - margin;
    left = Math.max(margin, Math.min(left, maxLeft));
    const top = rect.bottom + 5;

    this.translationPopupTarget.style.left = `${left}px`;
    this.translationPopupTarget.style.top = `${top}px`;

    this._updateSaveButton();

    // Word audio playback is handled by the audio-cache controller, which
    // sees the click in the capture phase (before stopPropagation below).

    ev.stopPropagation();
  }

  _updateSaveButton() {
    if (!this.hasSaveButtonTarget) return;

    const isSaved = this.currentTokenId && this._isSaved(this.currentTokenId);
    if (isSaved) {
      this.saveIconTarget.textContent = '✓';
      this.saveTextTarget.textContent = t("popover_translation.saved");
      this.saveButtonTarget.classList.add('bg-emerald-100', 'dark:bg-emerald-900/40', 'border-emerald-300', 'dark:border-emerald-700');
      this.saveButtonTarget.classList.remove('bg-gray-100', 'dark:bg-gray-700', 'border-gray-200', 'dark:border-gray-600');
    } else {
      this.saveIconTarget.textContent = '🔖';
      this.saveTextTarget.textContent = t("popover_translation.save");
      this.saveButtonTarget.classList.add('bg-gray-100', 'dark:bg-gray-700', 'border-gray-200', 'dark:border-gray-600');
      this.saveButtonTarget.classList.remove('bg-emerald-100', 'dark:bg-emerald-900/40', 'border-emerald-300', 'dark:border-emerald-700');
    }

    // Hide save button if no token id (not a saveable token or no session)
    this.saveButtonTarget.style.display = this.currentTokenId ? '' : 'none';
  }

  async toggleSave(ev) {
    ev.stopPropagation();
    if (!this.currentTokenId) return;

    await this.savedIdsReady;
    const isSaved = this._isSaved(this.currentTokenId);

    try {
      if (isSaved) {
        await fetch(`/token_translation_users/${this.currentTokenId}`, {
          method: 'DELETE',
          headers: {
            'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content,
            'Accept': 'application/json'
          }
        });
        this.savedIdsValue = this.savedIdsValue.filter(id => id !== this.currentTokenId);
      } else {
        await fetch('/token_translation_users', {
          method: 'POST',
          headers: {
            'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content,
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          },
          body: JSON.stringify({ token_translation_id: this.currentTokenId })
        });
        this.savedIdsValue = [...this.savedIdsValue, this.currentTokenId];
      }
      this._updateSaveButton();
    } catch (err) {
      console.warn('Failed to toggle save:', err);
    }
  }

}
