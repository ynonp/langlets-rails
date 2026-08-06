import { Controller } from "@hotwired/stimulus"
import { t } from "../utils/i18n"
import { animate } from "motion/mini"

// Connects to data-controller="match-activity"
export default class extends Controller {
  static targets = [
    'phraseContainer',
    'optionButton',
    'progressBar',
    'progressText',
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
    // Warm the shared audio cache: next phrase first, then the current one,
    // so the current phrase's words are the most recently used entries.
    this.preloadPhraseAudio(1)
    this.preloadPhraseAudio(0)
  }

  // Ask the audio-cache controller to preload the word audio of a phrase.
  preloadPhraseAudio(index) {
    const container = this.phraseContainerTargets.find(
      c => parseInt(c.dataset.index) === index
    )
    if (!container) return

    const urls = Array.from(container.querySelectorAll('[data-audio-url]'))
      .map(el => el.dataset.audioUrl)
    if (urls.length === 0) return

    this.element.dispatchEvent(new CustomEvent('audio-cache:preload', {
      bubbles: true,
      detail: { urls }
    }))
  }

  selectOption(event) {
    const option = event.currentTarget;
    const isCorrect = option.dataset.correct === 'true';
    const phraseContainer = event.target.closest('.phraseContainer');
    const feedbackEl = phraseContainer.querySelector('[data-match-activity-target="feedbackMessage"]');

    // Mark the selected option
    if (isCorrect) {
      // Play correct sound
      this.element.dispatchEvent(new CustomEvent('audio:correct', { bubbles: true }));

      // Disable all options for this phrase to prevent multiple selections
      phraseContainer.querySelectorAll('.optionButton').forEach(button => {
        button.disabled = true;
      });
      option.classList.add('correct-answer');
      this.incrementScore();
      this.showFeedback(feedbackEl, t("match.correct"), "bg-green-600");
        // Wait a moment before moving to the next phrase
      setTimeout(() => {
        this.moveToNextPhrase();
        this.element.dispatchEvent(new CustomEvent('stop-audio'));
      }, 1500);
    } else {
      // Play incorrect sound
      this.element.dispatchEvent(new CustomEvent('audio:incorrect', { bubbles: true }));

      option.classList.add('incorrect-answer');
      this.showFeedback(feedbackEl, t("match.incorrect"), "bg-red-600");
      setTimeout(() => {
        option.classList.remove('incorrect-answer');
        feedbackEl.classList.add('hidden');
      }, 1500);
    }
  }

  showFeedback(feedbackEl, message, bgClass) {
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
    // Award XP for correct answer (2 XP per correct answer)
    this.awardXp(2);
  }
  
  moveToNextPhrase() {
    // Hide current phrase
    const currentContainer = this.phraseContainerTargets.find(
      container => parseInt(container.dataset.index) === this.currentPhraseValue
    );
    if (currentContainer) {
      currentContainer.classList.add('hidden');
    }
    
    // Move to next phrase
    this.currentPhraseValue += 1;

    // Update progress for the question now being displayed
    this.updateProgress();
    
    // If we still have phrases, show the next one
    if (this.currentPhraseValue < this.totalPhrasesValue) {
      const nextContainer = this.phraseContainerTargets.find(
        container => parseInt(container.dataset.index) === this.currentPhraseValue
      );
      if (nextContainer) {
        nextContainer.classList.remove('hidden');
        // Update progress text
        this.progressTextTarget.textContent = t("match.question_of", { current: this.currentPhraseValue + 1, total: this.totalPhrasesValue });
        // Preload the next batch of word audio, then refresh the current
        // phrase's recency in the cache
        this.preloadPhraseAudio(this.currentPhraseValue + 1);
        this.preloadPhraseAudio(this.currentPhraseValue);
      }
    } else {
      // Play completion sound
      this.element.dispatchEvent(new CustomEvent('audio:complete', { bubbles: true }));
      
      // Show completion message
      this.completionMessageTarget.classList.remove('hidden');
      animate(this.completionMessageTarget, 
        { opacity: [0, 1], scale: [0.8, 1] }, 
        { duration: 0.3, easing: 'easeOut' }
      );
      this.element.dispatchEvent(new CustomEvent('activity:completed', { bubbles: true }))
    }
  }
  
  updateProgress() {
    const currentQuestion = Math.min(this.currentPhraseValue + 1, this.totalPhrasesValue);
    const percentage = currentQuestion / this.totalPhrasesValue * 100;
    this.progressBarTarget.style.width = `${percentage}%`;
    this.progressBarTarget.parentElement.setAttribute('aria-valuenow', currentQuestion);
  }

  // Award XP by calling the progress tracker controller
  awardXp(amount) {
    // Find the progress tracker controller on the gamification bar
    const gamificationBar = document.getElementById('gamification-bar');
    if (gamificationBar && gamificationBar.dataset.controller) {
      const controller = this.application.getControllerForElementAndIdentifier(gamificationBar, 'progress-tracker');
      if (controller) {
        controller.awardXp(amount);
      }
    }
  }
}
