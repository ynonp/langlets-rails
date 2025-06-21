import { Controller } from "@hotwired/stimulus"
import { animate } from "motion/mini"

export default class extends Controller {
  static targets = ['subtitles', 'phrase', 'translation', 'wordSelection', 'wordOption', 'showTranslation', 'phrasesContainer', 'completion']
  
  connect() {
    this.currentTokenIndex = 0;
    this.allTokens = this.getAllTokens();
  }

  progress({detail: {at}}) {
    const currentTime = at;
    const subtitlesLines = this.subtitlesTargets;
    const index = subtitlesLines.map(item => Number(item.dataset.timestamp)).findLastIndex(t => t < currentTime);

    if (index !== -1) {
      subtitlesLines[index].classList.add(this.currentTextLineClass);
      this.handlePhraseActivated(subtitlesLines[index]);
    }
  }
  
  handlePhraseActivated(currentPhraseElement) {
    const currentPhraseId = parseInt(currentPhraseElement.dataset.phraseId);
    
    // Find the previous phrase
    const previousPhraseId = currentPhraseId - 1;
    if (previousPhraseId >= 0) {
      const previousPhraseElement = this.phraseTargets.find(p => 
        parseInt(p.dataset.phraseId) === previousPhraseId
      );
      
      if (previousPhraseElement) {
        // Check for unfilled blanks in the previous phrase
        const blankLines = previousPhraseElement.querySelectorAll('.blank-line');
        const unfilledBlanks = Array.from(blankLines).filter(blank => 
          blank.textContent === '________' || blank.classList.contains('text-gray-400')
        );
        
        if (unfilledBlanks.length > 0) {
          // Dispatch event to pause the video
          const event = new CustomEvent('listen-activity:pause-video');
          this.element.dispatchEvent(event);
        }
      }
    }
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

  selectWord(event) {
    const wordButton = event.currentTarget;
    const word = wordButton.dataset.word;
    const isCorrect = wordButton.dataset.correct === 'true';
    
    // Add visual feedback animation
    if (isCorrect) {
      wordButton.classList.add('correct-animation');
    } else {
      wordButton.classList.add('incorrect-animation');
    }
    
    // Remove animation class after animation completes
    setTimeout(() => {
      wordButton.classList.remove('correct-animation', 'incorrect-animation');
    }, 600);
    
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
      
      // Delay updating word selection to allow animation to be visible
      setTimeout(() => {
        // Update word selection if we have more tokens
        if (this.currentTokenIndex < this.allTokens.length) {
          this.updateWordSelection();
        } else {
          // All tokens filled, show completion message
          this.wordSelectionTarget.classList.add('hidden');
          this.completionTarget.classList.remove('hidden');
          animate(this.completionTarget, 
            { opacity: [0, 1], scale: [0.8, 1] }, 
            { duration: 0.3, easing: 'easeOut' }
          );
          this.element.dispatchEvent(new CustomEvent('activity:completed', { bubbles: true }))
        }
      }, 650); // Slightly longer than animation duration
    }
  }
  
  updateWordSelection() {
    if (this.currentTokenIndex < this.allTokens.length) {
      const token = this.allTokens[this.currentTokenIndex];
      
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
}