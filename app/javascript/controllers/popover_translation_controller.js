import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ['translationPopup', 'translationText', 'aiButton'];
  static values = { l1Language: String };

  initialize() {
    this.hidePopup = this.hidePopup.bind(this);
    this.showPopup = this.showPopup.bind(this);
    this.currentAudio = null; // Track currently playing audio
    this.currentOriginalText = null;
    this.currentTranslation = null;
  }

  connect() {
    this.element.addEventListener('click', this.showPopup);
    document.addEventListener('click', this.hidePopup);
    // Hide popup on scroll to prevent it from floating disconnected from its token
    document.addEventListener('scroll', this.hidePopup, { passive: true });
    // Also listen for scroll on the phrases container
    const phrasesContainer = document.getElementById('phrases-container');
    if (phrasesContainer) {
      phrasesContainer.addEventListener('scroll', this.hidePopup, { passive: true });
    }
  }

  disconnect() {
    this.element.removeEventListener('click', this.showPopup);
    document.removeEventListener('click', this.hidePopup);
    document.removeEventListener('scroll', this.hidePopup);
    const phrasesContainer = document.getElementById('phrases-container');
    if (phrasesContainer) {
      phrasesContainer.removeEventListener('scroll', this.hidePopup);
    }
  }

  hidePopup() {
    this.translationPopupTarget.classList.add('hidden');
    // Stop any currently playing audio when hiding popup
    if (this.currentAudio) {
      this.currentAudio.pause();
      this.currentAudio.currentTime = 0;
    }
  }

  showPopup(ev) {
    if (ev.target.dataset.translation) {
      const {translation} = ev.target.dataset;
      const originalText = ev.target.textContent.trim();

      // Store current token data for ChatGPT prompt
      this.currentOriginalText = originalText;
      this.currentTranslation = translation;

      this.translationTextTarget.textContent = translation;
      
      // Get the bounding rectangle of the clicked element (viewport coordinates)
      const rect = ev.target.getBoundingClientRect();
      
      // Position relative to viewport for fixed positioning
      const left = rect.left + (rect.width / 2);
      const top = rect.bottom + 5;
      
      this.translationPopupTarget.style.left = `${left}px`;
      this.translationPopupTarget.style.top = `${top}px`;
      this.translationPopupTarget.classList.remove('hidden');

      const audio = ev.currentTarget.parentElement.querySelector('audio');
      if (audio) {
        audio.play();
      }
            
      ev.stopPropagation();      
    } else {
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
      return `Act like my ${language} teacher.
Explain word "${text}" (meaning ${translation}). Write its root/infinitive, etymology and provide example sentence`
    } else {
      return `Act like my ${language} teacher.
Explain the text "${text}" (meaning ${translation}):
1. Break to words and explain each
2. Explain the root or infinitive of each word
3. Provide example sentences using this text`
    }
  }

  playAudio(audioUrl) {
    // Stop any currently playing audio
    if (this.currentAudio) {
      this.currentAudio.pause();
      this.currentAudio.currentTime = 0;
    }

    // Create new audio element and play
    this.currentAudio = new Audio(audioUrl);
    this.currentAudio.volume = 0.7; // Set a reasonable volume
    
    // Handle audio errors gracefully
    this.currentAudio.onerror = () => {
      console.warn('Failed to load audio:', audioUrl);
    };
    
    // Play the audio
    this.currentAudio.play().catch(error => {
      console.warn('Failed to play audio:', error);
    });
  }
}

