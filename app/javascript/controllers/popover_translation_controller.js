import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ['translationPopup', 'translationText', 'aiButton', 'saveButton', 'saveIcon', 'saveText'];
  static values = { l1Language: String, savedIds: Array };

  initialize() {
    this.currentAudio = null;
    this.currentOriginalText = null;
    this.currentTranslation = null;
    this.currentTokenId = null;
  }

  hidePopup() {
    this.translationPopupTarget.classList.add('hidden');
    if (this.currentAudio) {
      this.currentAudio.pause();
      this.currentAudio.currentTime = 0;
    }
  }

  showPopup(ev) {
    const tokenEl = ev.target.closest('[data-translation]');
    if (!tokenEl) {
      this.hidePopup();
      return;
    }

    const translation = tokenEl.dataset.translation;
    const originalText = tokenEl.textContent.trim();
    const tokenId = tokenEl.dataset.tokenId ? parseInt(tokenEl.dataset.tokenId) : null;

    this.currentOriginalText = originalText;
    this.currentTranslation = translation;
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

    const audioUrl = tokenEl.dataset.audioUrl;
    if (audioUrl) {
      this.playAudio(audioUrl);
    }

    ev.stopPropagation();
  }

  _updateSaveButton() {
    if (!this.hasSaveButtonTarget) return;

    const isSaved = this.currentTokenId && this.savedIdsValue.includes(this.currentTokenId);
    if (isSaved) {
      this.saveIconTarget.textContent = '✓';
      this.saveTextTarget.textContent = 'Saved';
      this.saveButtonTarget.classList.add('bg-emerald-100', 'dark:bg-emerald-900/40', 'border-emerald-300', 'dark:border-emerald-700');
      this.saveButtonTarget.classList.remove('bg-gray-100', 'dark:bg-gray-700', 'border-gray-200', 'dark:border-gray-600');
    } else {
      this.saveIconTarget.textContent = '🔖';
      this.saveTextTarget.textContent = 'Save';
      this.saveButtonTarget.classList.add('bg-gray-100', 'dark:bg-gray-700', 'border-gray-200', 'dark:border-gray-600');
      this.saveButtonTarget.classList.remove('bg-emerald-100', 'dark:bg-emerald-900/40', 'border-emerald-300', 'dark:border-emerald-700');
    }

    // Hide save button if no token id (not a saveable token or no session)
    this.saveButtonTarget.style.display = this.currentTokenId ? '' : 'none';
  }

  async toggleSave(ev) {
    ev.stopPropagation();
    if (!this.currentTokenId) return;

    const isSaved = this.savedIdsValue.includes(this.currentTokenId);

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

  openChatGPT() {
    if (!this.currentOriginalText || !this.currentTranslation || !this.l1LanguageValue) {
      return;
    }
    const prompt = this.getChatgptPrompt(this.l1LanguageValue, this.currentOriginalText, this.currentTranslation);
    const encodedPrompt = encodeURIComponent(prompt);
    const chatgptUrl = `https://chat.openai.com/?q=${encodedPrompt}`;
    window.open(chatgptUrl, '_blank');
  }

  getChatgptPrompt(language, text, translation) {
    if (text.split(/\s+/).length === 1) {
      return `Act as a professional ${language} teacher.

Explain the following SINGLE WORD from ${language} for a learner.
IMPORTANT:
- Write the explanation in English.
- The provided meaning reflects how the word is used in context and may be idiomatic, metaphorical, or derived from a larger expression.
- Do NOT assume the literal dictionary meaning is the intended one.

Word: "${text}"
Intended meaning: "${translation}"

Tasks:
1. Identify the word's base form (infinitive / singular / lemma) and part of speech.
2. Explain the word's literal meaning and its etymology (brief).
3. Explain how this word can acquire the intended meaning:
   - through idiomatic usage
   - metaphorical extension
   - ellipsis of a longer common expression
   - or semantic shift
4. If the word typically appears as part of a fixed phrase, reconstruct the most common full expression and explain it.
5. Provide:
   - one example sentence showing the literal meaning (if applicable)
   - one example sentence showing the intended/contextual meaning
6. Add relevant usage notes (register, frequency, formality, regional usage).      
`
    } else {
      return `Act as a professional ${language} teacher.

Explain the following ${language} text for a learner.
IMPORTANT:
- Write the explanation in English.
- The provided meaning may be contextual or idiomatic, not literal.
- If the text is a fragment, infer the most likely full construction.

Text: "${text}"
Intended meaning: "${translation}"

Tasks:
1. Identify whether the meaning is literal or idiomatic.
2. Break the text into words or morphemes and explain each:
   - base form / infinitive
   - etymology (brief)
   - literal meaning
   - example sentence
3. Explain how the words combine to produce the intended meaning.
4. If the meaning relies on an implied or common expression, explain the missing parts.
5. Add relevant grammar or usage notes (register, frequency, formality, dialect, region).
`
    }
  }

  playAudio(audioUrl) {
    if (this.currentAudio) {
      this.currentAudio.pause();
      this.currentAudio.currentTime = 0;
    }
    this.currentAudio = new Audio(audioUrl);
    this.currentAudio.volume = 0.7;
    this.currentAudio.onerror = () => {
      console.warn('Failed to load audio:', audioUrl);
    };
    this.currentAudio.play().catch(error => {
      console.warn('Failed to play audio:', error);
    });
  }
}
