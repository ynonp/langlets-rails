import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="match-activity"
export default class extends Controller {
  static targets = [
    'phraseContainer', 
    'optionButton', 
    'progressBar', 
    'progressText',
    'feedbackMessage',
    'completionMessage',
    'speakerButton'
  ];
  
  static values = { 
    l1: String,
    totalPhrases: Number,
    currentPhrase: { type: Number, default: 0 },
    score: { type: Number, default: 0 }
  };

  connect() {
    // Audio will now be played using the video player when user clicks the speaker icon
  }

  selectOption(event) {
    const option = event.currentTarget;
    const isCorrect = option.dataset.correct === 'true';
    
    // Mark the selected option
    if (isCorrect) {
      console.log(this.element);
      // Disable all options for this phrase to prevent multiple selections
      
      event.target.closest('.phraseContainer').querySelectorAll('.optionButton').forEach(button => {
        button.disabled = true;
      });
      option.classList.add('correct-answer');
      this.incrementScore();
      this.showFeedback("Correct!", "bg-green-600");
        // Wait a moment before moving to the next phrase
      setTimeout(() => {
        this.moveToNextPhrase();
        this.element.dispatchEvent(new CustomEvent('stop-audio'));
      }, 1500);
    } else {
      option.classList.add('incorrect-answer');
      this.showFeedback("Incorrect", "bg-red-600");
      setTimeout(() => {
        option.classList.remove('incorrect-answer');
        this.feedbackMessageTarget.classList.add('hidden');
      }, 1500);
    }    
  }
  
  showFeedback(message, bgClass) {
    const feedbackEl = this.feedbackMessageTarget;
    feedbackEl.textContent = message;
    feedbackEl.classList.remove('hidden', 'bg-green-600', 'bg-red-600');
    feedbackEl.classList.add(bgClass, 'animate-fade-in');
    
    setTimeout(() => {
      feedbackEl.classList.add('hidden');
      feedbackEl.classList.remove('animate-fade-in');
    }, 1500);
  }
  
  incrementScore() {
    this.scoreValue += 1;
  }
  
  moveToNextPhrase() {
    // Hide current phrase
    const currentContainer = this.phraseContainerTargets.find(
      container => parseInt(container.dataset.index) === this.currentPhraseValue
    );
    if (currentContainer) {
      currentContainer.classList.add('hidden');
    }
    
    // Update progress
    this.updateProgress();
    
    // Move to next phrase
    this.currentPhraseValue += 1;
    
    // If we still have phrases, show the next one
    if (this.currentPhraseValue < this.totalPhrasesValue) {
      const nextContainer = this.phraseContainerTargets.find(
        container => parseInt(container.dataset.index) === this.currentPhraseValue
      );
      if (nextContainer) {
        nextContainer.classList.remove('hidden');
        // Update progress text
        this.progressTextTarget.textContent = `Question ${this.currentPhraseValue + 1} of ${this.totalPhrasesValue}`;
        // Audio will now be played only when user clicks the speaker icon
      }
    } else {
      // Show completion message
      this.completionMessageTarget.classList.remove('hidden');
      this.completionMessageTarget.classList.add('animate-fade-in');
    }
  }
  
  updateProgress() {
    const percentage = (this.currentPhraseValue + 1) / this.totalPhrasesValue * 100;
    this.progressBarTarget.style.width = `${percentage}%`;
  }
}
