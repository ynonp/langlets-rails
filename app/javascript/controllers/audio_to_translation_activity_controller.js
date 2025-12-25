import { Controller } from "@hotwired/stimulus"
import { animate } from "motion/mini"

// Connects to data-controller="audio-to-translation-activity"
export default class extends Controller {
  static targets = ['progressBar', 'l1Column', 'l2Column', 'completionMessage', 'grid'];
  static values = { 
    totalPhrases: Number
  };

  connect() {
    this.matchedPhrases = 0;
    this.selectedPhrase = null;
  }

  selectPhrase(event) {
    // Find the phrase element (button or div) that has data-phrase-id
    // event.currentTarget should be the button with the data-action attribute
    const clickedElement = event.currentTarget.closest('[data-phrase-id]') || event.currentTarget;
    
    // Safety check - use dataset which Stimulus uses
    if (!clickedElement || !clickedElement.dataset || !clickedElement.dataset.phraseId) {
      console.warn('selectPhrase: Could not find element with data-phrase-id', {
        currentTarget: event.currentTarget,
        clickedElement: clickedElement,
        dataset: clickedElement?.dataset
      });
      return;
    }
    
    const phraseId = parseInt(clickedElement.dataset.phraseId);
    const column = clickedElement.dataset.column;
    
    if (!phraseId || !column) {
      console.warn('selectPhrase: Missing phraseId or column', { 
        phraseId, 
        column, 
        element: clickedElement,
        dataset: clickedElement.dataset
      });
      return;
    }
    
    // Don't allow selection of phrases that are currently animating
    if (clickedElement.classList.contains('flash-success') || 
        clickedElement.classList.contains('flash-error')) {
      return;
    }
    
    // If no phrase is selected, select this one
    if (!this.selectedPhrase) {
      this.selectNewPhrase(clickedElement, phraseId, column);
      return;
    }
    
    // If clicking a phrase from the same column, switch selection
    if (this.selectedPhrase.column === column) {
      this.clearSelection();
      this.selectNewPhrase(clickedElement, phraseId, column);
      return;
    }
    
    // If clicking a phrase from the opposite column, attempt match
    this.attemptMatch(clickedElement, phraseId);
  }

  selectNewPhrase(element, phraseId, column) {
    this.selectedPhrase = { element, phraseId, column };
    element.classList.add('selected');
  }

  clearSelection() {
    if (this.selectedPhrase) {
      this.selectedPhrase.element.classList.remove('selected');
      this.selectedPhrase = null;
    }
  }

  attemptMatch(clickedElement, clickedPhraseId) {
    const selectedPhraseId = this.selectedPhrase.phraseId;
    
    // Check if they match
    if (selectedPhraseId === clickedPhraseId) {
      // Successful match
      this.handleSuccessfulMatch(this.selectedPhrase.element, clickedElement);
    } else {
      // Failed match
      this.handleFailedMatch(this.selectedPhrase.element, clickedElement);
    }
  }

  handleSuccessfulMatch(element1, element2) {
    // Play correct sound
    this.element.dispatchEvent(new CustomEvent('audio:correct', { bubbles: true }));
    
    // Flash green
    element1.classList.add('flash-success');
    element2.classList.add('flash-success');
    
    // Clear selection immediately to allow new selections
    this.clearSelection();
    
    // Award XP for correct match (2 XP per correct answer)
    this.awardXp(2);
    
    setTimeout(() => {
      // Remove from DOM after flash animation completes
      element1.remove();
      element2.remove();
      
      this.matchedPhrases++;
      this.updateProgress();
      
      // Check if all phrases are matched
      if (this.matchedPhrases === this.totalPhrasesValue) {
        this.showCompletion();
      }
    }, 600);
  }

  handleFailedMatch(element1, element2) {
    // Play incorrect sound
    this.element.dispatchEvent(new CustomEvent('audio:incorrect', { bubbles: true }));
    
    // Flash red
    element1.classList.add('flash-error');
    element2.classList.add('flash-error');
    
    // Clear selection immediately to allow new selections
    this.clearSelection();
    
    setTimeout(() => {
      element1.classList.remove('flash-error');
      element2.classList.remove('flash-error');
    }, 600);
  }

  updateProgress() {
    const percentage = (this.matchedPhrases / this.totalPhrasesValue) * 100;
    this.progressBarTarget.style.width = `${percentage}%`;
  }

  showCompletion() {
    // Play completion sound
    this.element.dispatchEvent(new CustomEvent('audio:complete', { bubbles: true }));
    
    this.completionMessageTarget.classList.remove('hidden');
    animate(this.completionMessageTarget, 
      { opacity: [0, 1], scale: [0.8, 1] }, 
      { duration: 0.3, easing: 'easeOut' }
    );
    this.element.dispatchEvent(new CustomEvent('activity:completed', { bubbles: true }))
    this.gridTarget.classList.add('hidden');
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

