import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="language-alignment-activity.js"
export default class extends Controller {
  static targets = ['progressBar', 'token', 'completionMessage', 'translationPhrase', 'originalPhrasesContainer'];
  
  connect() {
    this.currentPhraseIndex = 0;
    this.totalPhrases = this.translationPhraseTargets.length;
    
    // Scroll to the first phrase when the activity loads
    setTimeout(() => {
      this.scrollToOriginalPhrase(0);
    }, 100);
  }
  
  findToken(ev) {
    const token = ev.target;
    if (token.getAttribute('data-found') === 'false') {
      const phraseId = token.getAttribute('data-phrase-id');
      const tokenId = token.getAttribute('data-token-id');
      
      // Only allow finding tokens in the current phrase
      if (parseInt(phraseId) === this.currentPhraseIndex) {
        token.setAttribute('data-found', 'true');
        token.classList.add('bg-green-400', 'text-gray-900', 'font-medium', 'px-1', 'rounded');
        token.classList.add('animate-pulse');
        setTimeout(() => token.classList.remove('animate-pulse'), 1000);
        
        this.updateProgress();
      }
    }
  }

  updateProgress() {
    const currentPhraseTokens = this.tokenTargets.filter(t => 
      parseInt(t.dataset.phraseId) === this.currentPhraseIndex
    );
    
    const foundTokens = currentPhraseTokens.filter(t => t.dataset.found === "true");
    
    // Check if all tokens in the current phrase are found
    if (foundTokens.length === currentPhraseTokens.length) {
      // Move to the next phrase if available
      if (this.currentPhraseIndex < this.totalPhrases - 1) {
        setTimeout(() => {
          this.currentPhraseIndex++;
          
          // Hide current phrase, show next phrase
          this.translationPhraseTargets.forEach((phrase, index) => {
            if (index === this.currentPhraseIndex) {
              phrase.classList.remove('hidden');
              phrase.classList.add('animate-fade-in');
            } else {
              phrase.classList.add('hidden');
            }
          });

          // Scroll to the corresponding original phrase
          this.scrollToOriginalPhrase(this.currentPhraseIndex);
        }, 1000); // Short delay before showing the next phrase
      } else {
        // All phrases completed
        // Hide all translation phrases
        this.translationPhraseTargets.forEach(phrase => {
          phrase.classList.add('hidden');
        });
        
        // Show completion message
        this.completionMessageTarget.classList.remove('hidden');
        this.completionMessageTarget.classList.add('animate-fade-in');
      }
    }
    
    // Update overall progress bar
    const totalTokens = this.tokenTargets.length;
    const totalFoundTokens = this.tokenTargets.filter(t => t.dataset.found === "true").length;
    const percentage = (totalFoundTokens / totalTokens) * 100;
    this.progressBarTarget.style.width = `${percentage}%`;
  }

  scrollToOriginalPhrase(phraseIndex) {
    // Find the original phrase element with the matching phrase-id
    const originalPhrase = this.element.querySelector(`.original-phrase[data-phrase-id="${phraseIndex}"]`);
    
    if (originalPhrase && this.hasOriginalPhrasesContainerTarget) {
      // Remove highlighting from all original phrases
      this.element.querySelectorAll('.original-phrase').forEach(phrase => {
        phrase.classList.remove('ring-2', 'ring-blue-400', 'bg-gray-800');
        phrase.classList.add('bg-gray-900');
      });
            
      // Calculate the position to scroll to
      const container = this.originalPhrasesContainerTarget;
      const containerRect = container.getBoundingClientRect();
      const phraseRect = originalPhrase.getBoundingClientRect();
      const containerHeight = container.clientHeight;
      const phraseHeight = originalPhrase.offsetHeight;
      
      // Calculate the current scroll position and the phrase position relative to the container
      const currentScrollTop = container.scrollTop;
      const phraseRelativeTop = phraseRect.top - containerRect.top + currentScrollTop;
      
      // Scroll so the phrase is centered in the container
      const scrollPosition = phraseRelativeTop - (containerHeight / 2) + (phraseHeight / 2);
      
      // Smooth scroll to the position
      container.scrollTo({
        top: Math.max(0, scrollPosition),
        behavior: 'smooth'
      });
    }
  }
}

