import { Controller } from "@hotwired/stimulus"
import { animate } from "motion/mini"

// Connects to data-controller="tokens-chain-activity"
export default class extends Controller {
  static targets = ['grid', 'startButton', 'completionMessage', 'progressBar'];
  static values = { 
    tokens: Array,
    totalTokens: Number
  };

  connect() {
    this.currentIndex = 0; // Start at first token (already displayed in top-left)
    this.matchedTokenIds = new Set();
    this.tokensArray = this.tokensValue || [];
    this.currentL1Element = this.startButtonTarget; // Track which element shows current L1
    this.currentAudio = null; // Track currently playing audio
    
    // Mark initial L1 as current
    this.startButtonTarget.classList.add('current-l1');
  }

  playL1Audio(event) {
    // Stop any currently playing audio
    if (this.currentAudio) {
      this.currentAudio.pause();
      this.currentAudio.currentTime = 0;
    }
    
    // Find the token ID for this square
    const square = event.currentTarget;
    const tokenId = square.getAttribute('data-l1-token-id') || square.getAttribute('data-token-id');
    if (!tokenId) return;
    
    // Find the square that has this token's audio element
    const squareWithAudio = this.gridTarget.querySelector(`[data-token-id="${tokenId}"]`);
    if (!squareWithAudio) return;
    
    const audioElement = squareWithAudio.querySelector('audio[data-token-audio]');
    if (!audioElement) return;
    
    // Play the audio element
    this.currentAudio = audioElement;
    audioElement.currentTime = 0;
    audioElement.volume = 0.7;
    audioElement.play().catch(error => {
      console.warn('Audio playback failed:', error);
    });
  }

  selectSquare(event) {
    // Don't allow selection if all tokens matched or if square is already matched
    if (this.currentIndex >= this.tokensArray.length) return;
    
    const clickedElement = event.currentTarget;
    const tokenId = parseInt(clickedElement.dataset.tokenId);
    
    if (!tokenId || this.matchedTokenIds.has(tokenId)) {
      return; // Invalid or already matched
    }

    // Don't allow selection of squares that are currently animating or showing L1
    if (clickedElement.classList.contains('flash-success') || 
        clickedElement.classList.contains('flash-error') ||
        clickedElement.classList.contains('showing-l1')) {
      return;
    }

    const currentToken = this.tokensArray[this.currentIndex];
    
    // Check if this is the correct match
    if (tokenId === currentToken.id) {
      this.handleCorrectMatch(clickedElement);
    } else {
      this.handleWrongMatch(clickedElement);
    }
  }

  handleCorrectMatch(element) {
    // Play correct sound
    this.element.dispatchEvent(new CustomEvent('audio:correct', { bubbles: true }));
    
    // Flash green
    element.classList.add('flash-success');
    
    // Award XP (2 XP per correct match)
    this.awardXp(2);
    
    // Mark as matched
    this.matchedTokenIds.add(this.tokensArray[this.currentIndex].id);
    
    // Move to next token
    this.currentIndex++;
    this.updateProgress();
    
    if (this.currentIndex >= this.tokensArray.length) {
      // All tokens matched
      setTimeout(() => {
        this.showCompletion();
      }, 600);
    } else {
      // Flip the matched square to show next L1 word
      setTimeout(() => {
        const currentToken = this.tokensArray[this.currentIndex];
        const textElement = element.querySelector('.token-text');
        if (textElement) {
          textElement.textContent = currentToken.l1_text;
        }
        // Remove current highlight from previous L1
        if (this.currentL1Element) {
          this.currentL1Element.classList.remove('current-l1');
        }
        // Update styling to show it's now displaying L1
        element.classList.remove('flash-success', 'bg-gray-900', 'hover:bg-gray-800');
        element.classList.add('showing-l1', 'bg-gray-700', 'cursor-pointer', 'current-l1');
        // Store the token ID so we can find its audio element later
        element.setAttribute('data-l1-token-id', currentToken.id);
        // Add click handler for L1 audio playback
        element.setAttribute('data-action', 'click->tokens-chain-activity#playL1Audio');
        // Remove token ID since it now shows L1
        element.removeAttribute('data-token-id');
        // Update current L1 element reference
        this.currentL1Element = element;
        
        // Find and play the audio element for the next token
        const squareWithNextTokenAudio = this.gridTarget.querySelector(`[data-token-id="${currentToken.id}"]`);
        if (squareWithNextTokenAudio) {
          const audioElement = squareWithNextTokenAudio.querySelector('audio[data-token-audio]');
          if (audioElement) {
            this.playAudioForElement(audioElement);
          }
        }
      }, 600);
    }
  }

  handleWrongMatch(element) {
    // Play incorrect sound
    this.element.dispatchEvent(new CustomEvent('audio:incorrect', { bubbles: true }));
    
    // Flash red
    element.classList.add('flash-error');
    
    setTimeout(() => {
      element.classList.remove('flash-error');
    }, 600);
  }


  updateProgress() {
    const percentage = (this.matchedTokenIds.size / this.totalTokensValue) * 100;
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
    this.element.dispatchEvent(new CustomEvent('activity:completed', { bubbles: true }));
    this.gridTarget.classList.add('hidden');
  }

  playAudioForElement(audioElement) {
    // Stop any currently playing audio
    if (this.currentAudio) {
      this.currentAudio.pause();
      this.currentAudio.currentTime = 0;
    }
    
    if (!audioElement) return;
    
    // Play the audio element
    this.currentAudio = audioElement;
    audioElement.currentTime = 0;
    audioElement.volume = 0.7;
    audioElement.play().catch(error => {
      console.warn('Audio playback failed:', error);
    });
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

