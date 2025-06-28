import { Controller } from "@hotwired/stimulus"
import { animate } from "motion/mini"

// Connects to data-controller="match-tokens-activity"
export default class extends Controller {
  static targets = ['progressBar', 'l1Column', 'l2Column', 'completionMessage', 'grid'];
  static values = { 
    tokens: Array,
    totalTokens: Number
  };

  connect() {
    this.currentTokens = [...this.tokensValue]; // All tokens
    this.displayedTokens = []; // Currently displayed tokens (max 5)
    this.matchedTokens = 0;
    this.selectedToken = null;
    this.currentAudio = null;
    this.preloadedAudio = new Map(); // Cache for preloaded audio
    
    this.preloadAllAudio();
    this.initializeGrid();
  }

  preloadAllAudio() {
    // Get all unique audio URLs from tokens
    const audioUrls = [...new Set(
      this.tokensValue
        .map(token => token.audio_url)
        .filter(url => url && url !== 'null' && url !== '')
    )];
    
    // Preload each audio file
    audioUrls.forEach(audioUrl => {
      const audio = new Audio(audioUrl);
      audio.volume = 0.7;
      audio.preload = 'auto';
      
      // Handle preload completion
      audio.addEventListener('canplaythrough', () => {
        this.preloadedAudio.set(audioUrl, audio);
      });
      
      // Handle preload errors gracefully
      audio.addEventListener('error', () => {
        console.warn('Failed to preload audio:', audioUrl);
      });
      
      // Start preloading
      audio.load();
    });
  }

  initializeGrid() {
    // Show first 5 tokens (or all if less than 5)
    const tokensToShow = this.currentTokens.splice(0, 5);
    this.displayedTokens = tokensToShow;
    
    // Shuffle each column separately
    const shuffledL1 = [...tokensToShow].sort(() => Math.random() - 0.5);
    const shuffledL2 = [...tokensToShow].sort(() => Math.random() - 0.5);
    
    // Clear columns
    this.l1ColumnTarget.innerHTML = '';
    this.l2ColumnTarget.innerHTML = '';
    
    // Populate L1 column
    shuffledL1.forEach(token => {
      this.l1ColumnTarget.appendChild(this.createTokenElement(token, 'l1'));
    });
    
    // Populate L2 column
    shuffledL2.forEach(token => {
      this.l2ColumnTarget.appendChild(this.createTokenElement(token, 'l2'));
    });
  }

  createTokenElement(token, column) {
    const element = document.createElement('div');
    element.className = 'token-word px-4 py-3 border-2 border-gray-600 rounded-lg bg-gray-900 hover:bg-gray-800 text-white text-center transition-all duration-200';
    element.dataset.tokenId = token.id;
    element.dataset.column = column;
    element.dataset.action = 'click->match-tokens-activity#selectToken';
    
    if (column === 'l1') {
      element.textContent = token.l1_word;
      element.dataset.audioUrl = token.audio_url;
    } else {
      element.textContent = token.l2_translation;
    }
    
    return element;
  }

  selectToken(event) {
    const clickedToken = event.target;
    const tokenId = parseInt(clickedToken.dataset.tokenId);
    const column = clickedToken.dataset.column;
    
    // Don't allow selection of tokens that are currently animating or matched
    if (clickedToken.classList.contains('flash-success') || 
        clickedToken.classList.contains('flash-error') || 
        clickedToken.classList.contains('matched')) {
      return;
    }
    
    // If clicking the same token, deselect it
    if (this.selectedToken && this.selectedToken.element === clickedToken) {
      this.clearSelection();
      return;
    }
    
    // If no token is selected, select this one
    if (!this.selectedToken) {
      this.selectNewToken(clickedToken, tokenId, column);
      return;
    }
    
    // If clicking a token from the same column, switch selection
    if (this.selectedToken.column === column) {
      this.clearSelection();
      this.selectNewToken(clickedToken, tokenId, column);
      return;
    }
    
    // If clicking a token from the opposite column, attempt match
    this.attemptMatch(clickedToken, tokenId);
  }

  selectNewToken(element, tokenId, column) {
    this.selectedToken = { element, tokenId, column };
    element.classList.add('selected');
    
    // Play audio if it's an L1 token
    if (column === 'l1') {
      this.playTokenAudio(element);
    }
  }

  clearSelection() {
    if (this.selectedToken) {
      this.selectedToken.element.classList.remove('selected');
      this.selectedToken = null;
    }
  }

  attemptMatch(clickedElement, clickedTokenId) {
    const selectedTokenId = this.selectedToken.tokenId;
    
    // Check if they match
    if (selectedTokenId === clickedTokenId) {
      // Successful match
      this.handleSuccessfulMatch(this.selectedToken.element, clickedElement);
    } else {
      // Failed match
      this.handleFailedMatch(this.selectedToken.element, clickedElement);
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
      // Mark as matched and hide
      element1.classList.add('matched');
      element2.classList.add('matched');
      
      this.matchedTokens++;
      this.updateProgress();
      
      // Add new tokens if available
      setTimeout(() => {
        this.addNewTokens();
      }, 300);
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

  addNewTokens() {
    if (this.currentTokens.length === 0) {
      // No more tokens, check if all are matched
      if (this.matchedTokens === this.totalTokensValue) {
        this.showCompletion();
      } else {
        this.compactGrid();
      }
      return;
    }
    
    // Remove matched tokens from display
    const matchedElements = this.element.querySelectorAll('.token-word.matched');
    matchedElements.forEach(el => el.remove());
    
    // Add new tokens to fill empty spots (up to 5 total visible)
    const visibleTokens = this.element.querySelectorAll('.token-word:not(.matched)').length / 2; // Divide by 2 because each token appears in both columns
    const tokensNeeded = Math.min(5 - visibleTokens, this.currentTokens.length);

    if (tokensNeeded > 0) {
      const newTokens = this.currentTokens.splice(0, tokensNeeded);
      
      newTokens.forEach(token => {
        // Find random positions in each column
        const l1Position = Math.floor(Math.random() * 5);
        const l2Position = Math.floor(Math.random() * 5);
        
        // Insert L1 token
        const l1Element = this.createTokenElement(token, 'l1');
        this.insertAtPosition(this.l1ColumnTarget, l1Element, l1Position);
        
        // Insert L2 token
        const l2Element = this.createTokenElement(token, 'l2');
        this.insertAtPosition(this.l2ColumnTarget, l2Element, l2Position);
      });
    }
  }

  insertAtPosition(container, element, position) {
    const children = Array.from(container.children);
    if (position >= children.length) {
      container.appendChild(element);
    } else {
      container.insertBefore(element, children[position]);
    }
  }

  updateProgress() {
    const percentage = (this.matchedTokens / this.totalTokensValue) * 100;
    this.progressBarTarget.style.width = `${percentage}%`;
  }

  compactGrid() {
    // Get all remaining unmatched tokens from both columns
    const l1Tokens = Array.from(this.l1ColumnTarget.querySelectorAll('.token-word:not(.matched)'));
    const l2Tokens = Array.from(this.l2ColumnTarget.querySelectorAll('.token-word:not(.matched)'));
    
    // Clear the columns
    this.l1ColumnTarget.innerHTML = '';
    this.l2ColumnTarget.innerHTML = '';
    
    // Re-add tokens in their original order, compacted to the top
    l1Tokens.forEach(token => {
      this.l1ColumnTarget.appendChild(token);
    });
    
    l2Tokens.forEach(token => {
      this.l2ColumnTarget.appendChild(token);
    });
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

  playTokenAudio(element) {
    const audioUrl = element.dataset.audioUrl;
    
    if (audioUrl && audioUrl !== 'null' && audioUrl !== '') {
      // Stop any currently playing audio
      if (this.currentAudio) {
        this.currentAudio.pause();
        this.currentAudio.currentTime = 0;
      }
      
      // Try to use preloaded audio first
      const preloadedAudio = this.preloadedAudio.get(audioUrl);
      if (preloadedAudio) {
        // Reset audio to beginning and play
        preloadedAudio.currentTime = 0;
        this.currentAudio = preloadedAudio;
        
        // Play the preloaded audio
        this.currentAudio.play().catch(error => {
          console.warn('Preloaded audio playback failed:', error);
        });
      } else {
        // Fallback to creating new Audio object if preloading failed
        this.currentAudio = new Audio(audioUrl);
        this.currentAudio.volume = 0.7;
        
        // Handle audio playback errors gracefully
        this.currentAudio.onerror = () => {
          console.warn('Failed to play audio for token:', element.textContent);
        };
        
        // Play the audio
        this.currentAudio.play().catch(error => {
          console.warn('Audio playback failed:', error);
        });
      }
    }
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
