import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ['phrase', 'translation', 'wordSelection', 'wordOption', 'showTranslation', 'phrasesContainer']
  
  connect() {
    this.currentTokenIndex = 0;
    this.allTokens = this.getAllTokens();
    this.setupPhraseObserver();
  }
  
  setupPhraseObserver() {
    // Instead of modifying the video player controller directly,
    // we'll use a MutationObserver to watch for active phrases with blanks
    this.phraseObserver = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.type === 'attributes' && 
            mutation.attributeName === 'class' && 
            mutation.target.classList.contains('bg-gray-700')) {
          
          // Check for unfilled blanks in the active phrase
          const blankLines = mutation.target.querySelectorAll('.blank-line');
          const unfilledBlanks = Array.from(blankLines).filter(blank => 
            blank.textContent === '________' || blank.classList.contains('text-gray-400')
          );
          
          if (unfilledBlanks.length > 0) {
            // Dispatch event to pause the video
            const event = new CustomEvent('listen-activity:pause-video');
            this.element.dispatchEvent(event);
          }
        }
      });
    });
    
    // Observe all phrases for class changes
    this.phraseTargets.forEach(phrase => {
      this.phraseObserver.observe(phrase, { attributes: true });
    });
  }
  
  getAllTokens() {
    const tokens = [];
    this.phraseTargets.forEach(phraseElement => {
      const phraseId = phraseElement.dataset.phraseId;
      const blanks = phraseElement.querySelectorAll('.blank-line');
      
      blanks.forEach(blank => {
        const tokenData = JSON.parse(blank.dataset.token);
        tokens.push({
          phraseId,
          blank,
          tokenData,
          filled: false
        });
      });
    });
    
    return tokens;
  }
  
  toggleTranslation() {
    const showTranslations = this.showTranslationTarget.checked;
    this.translationTargets.forEach(translation => {
      if (showTranslations) {
        translation.classList.remove('hidden');
      } else {
        translation.classList.add('hidden');
      }
    });
  }
  
  selectWord(event) {
    const wordButton = event.currentTarget;
    const word = wordButton.dataset.word;
    const isCorrect = wordButton.dataset.correct === 'true';
    
    if (isCorrect) {
      // Dispatch event to play the video instead of direct call
      const playEvent = new CustomEvent('listen-activity:play-video');
      this.element.dispatchEvent(playEvent);
    }

    if (isCorrect && this.currentTokenIndex < this.allTokens.length) {
      const currentToken = this.allTokens[this.currentTokenIndex];
      currentToken.blank.textContent = word;
      currentToken.blank.classList.remove('text-gray-400');
      currentToken.blank.classList.remove('blank-line');
      currentToken.blank.classList.add('text-white');
      currentToken.filled = true;
      
      // Move to next token
      this.currentTokenIndex++;
      
      // Update word selection if we have more tokens
      if (this.currentTokenIndex < this.allTokens.length) {
        this.updateWordSelection();
      } else {
        // All tokens filled, show completion button
        this.wordSelectionTarget.innerHTML = `
          <button class="w-full px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-lg transition-colors duration-200 text-center">
            Continue
          </button>
        `;
      }
    }
  }
  
  updateWordSelection() {
    if (this.currentTokenIndex < this.allTokens.length) {
      const token = this.allTokens[this.currentTokenIndex];
      const phraseElement = this.phraseTargets.find(p => p.dataset.phraseId === token.phraseId);
      
      // Get token data from data attribute
      const tokenData = token.tokenData;
      const correctWord = tokenData.original_text;
      const similarWord = tokenData.similar_sound || "alternative";
      
      // Randomly arrange correct and incorrect words
      const words = [
        { word: correctWord, correct: true },
        { word: similarWord, correct: false }
      ].sort(() => Math.random() - 0.5);
      
      // Update word selection buttons
      this.wordSelectionTarget.innerHTML = words.map(word => `
        <button data-listen-activity-target="wordOption" 
                data-word="${word.word}" 
                data-correct="${word.correct}" 
                data-action="click->listen-activity#selectWord"
                class="px-6 py-3 bg-gray-700 hover:bg-gray-600 text-white font-medium rounded-lg transition-colors duration-200 text-center word-option-button">
          ${word.word}
        </button>
      `).join('');
    }
  }
  
  disconnect() {
    if (this.phraseObserver) {
      this.phraseObserver.disconnect();
    }
  }
} 