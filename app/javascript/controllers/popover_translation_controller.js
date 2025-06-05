import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ['translationPopup', 'translationText'];

  initialize() {
    this.hidePopup = this.hidePopup.bind(this);
    this.showPopup = this.showPopup.bind(this);
    this.currentAudio = null; // Track currently playing audio
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
      const {translation, audioUrl} = ev.target.dataset;

      this.translationTextTarget.textContent = translation;
      
      // Get the bounding rectangle of the clicked element (viewport coordinates)
      const rect = ev.target.getBoundingClientRect();
      
      // Position relative to viewport for fixed positioning
      const left = rect.left + (rect.width / 2);
      const top = rect.bottom + 5;
      
      this.translationPopupTarget.style.left = `${left}px`;
      this.translationPopupTarget.style.top = `${top}px`;
      this.translationPopupTarget.classList.remove('hidden');
      
      // Play audio if available
      if (audioUrl && audioUrl !== 'null' && audioUrl !== '') {
        this.playAudio(audioUrl);
      }
      
      console.log('1');
      ev.stopPropagation();      
    } else {
      console.log(ev.target);
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

