import { Controller } from "@hotwired/stimulus"
import { animate } from "motion/mini"

// Connects to data-controller="match-tokens-activity"
export default class extends Controller {
  static targets = ['progressBar', 'l1Column', 'l2Column', 'completionMessage', 'grid'];
  static values = { 
    tokens: Array,
    totalTokens: Number,
    isReviewLesson: Boolean
  };

  connect() {
    this.currentTokens = [...this.tokensValue]; // All tokens
    this.displayedTokens = []; // Currently displayed tokens (max 5)
    this.matchedTokens = 0;
    this.selectedToken = null;
    this.activeTouches = new Map(); // Track multi-touch points by identifier

    this.preloadAllAudio();
    this.initializeGrid();
  }

  // Record each touch point on touchstart so we can match pairs on touchend.
  // touchend fires per-finger, so changedTouches.length is always 1 — we can't
  // detect multi-touch from touchend alone.
  handleTouchStart(event) {
    for (const t of event.changedTouches) {
      const el = document.elementFromPoint(t.clientX, t.clientY)?.closest('.token-word');
      if (el) {
        this.activeTouches.set(t.identifier, { element: el, column: el.dataset.column });
      }
    }
  }

  // On touchend, check whether we have two tracked touches from opposite
  // columns.  If so, perform the match.  Single-finger taps are left alone so
  // the synthesized `click` runs the normal sequential flow.
  handleTouchEnd(event) {
    // Snapshot before removing the lifting finger — touchend fires per-finger,
    // so we must check the full set while both touches are still recorded.
    const tracked = Array.from(this.activeTouches.values());

    // Remove the lifting finger(s).
    for (const t of event.changedTouches) {
      this.activeTouches.delete(t.identifier);
    }

    // Need at least two touches from opposite columns.
    if (tracked.length < 2) return;
    const l1Touch = tracked.find(t => t.column === 'l1');
    const l2Touch = tracked.find(t => t.column === 'l2');
    if (!l1Touch || !l2Touch) return;

    // Skip tokens that are animating, already matched, or the same element.
    const isBusy = el =>
      el.classList.contains('flash-success') ||
      el.classList.contains('flash-error') ||
      el.classList.contains('matched');
    if (l1Touch.element === l2Touch.element || isBusy(l1Touch.element) || isBusy(l2Touch.element)) return;

    // We're fully handling this gesture — stop synthesized clicks.
    event.preventDefault();
    this.activeTouches.clear();

    // Reuse the existing state machine.
    this.clearSelection();
    this.selectNewToken(l1Touch.element, parseInt(l1Touch.element.dataset.tokenId), l1Touch.element.dataset.column);
    this.attemptMatch(l2Touch.element);
  }

  preloadAllAudio() {
    // Get all unique audio URLs from tokens
    const audioUrls = [...new Set(
      this.tokensValue
        .map(token => token.audio_url)
        .filter(url => url && url !== 'null' && url !== '')
    )];

    // Warm the shared audio cache (it caps how many it keeps)
    this.element.dispatchEvent(new CustomEvent('audio-cache:preload', {
      bubbles: true,
      detail: { urls: audioUrls }
    }));
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
    element.className = 'token-word touch-manipulation px-4 py-3 border-2 border-gray-200 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-900 hover:bg-gray-100 dark:hover:bg-gray-800 text-gray-900 dark:text-gray-50 text-center transition-all duration-200';
    element.dataset.tokenId = token.id;
    element.dataset.column = column;
    // Carry both sides of the pair so matching can be done by text, not id.
    element.dataset.l1Text = token.l1_word;
    element.dataset.l2Text = token.l2_translation;
    element.dataset.action = 'click->match-tokens-activity#selectToken';
    
    if (column === 'l1') {
      element.dataset.audioUrl = token.audio_url;
      element.textContent = token.l1_word;
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
    this.attemptMatch(clickedToken);
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

  attemptMatch(clickedElement) {
    const selectedElement = this.selectedToken.element;

    // Text-only match: two cells belong to the same pair when both their L1 and
    // L2 texts agree (ignoring punctuation/whitespace).
    const samePair =
      this.normalizeText(selectedElement.dataset.l1Text) === this.normalizeText(clickedElement.dataset.l1Text) &&
      this.normalizeText(selectedElement.dataset.l2Text) === this.normalizeText(clickedElement.dataset.l2Text);

    if (samePair) {
      // Successful match
      this.handleSuccessfulMatch(this.selectedToken.element, clickedElement);
    } else {
      // Failed match
      this.handleFailedMatch(this.selectedToken.element, clickedElement);
    }
  }

  // Strip dash punctuation (Unicode \p{Pd}: hyphen, en/em dash, etc.),
  // whitespace, commas and periods so that "uh-huh", "uh huh", "uh, huh."
  // and "uhhuh" all compare as equal.
  // We deliberately keep other punctuation (e.g. apostrophes) so "it's" != "its".
  normalizeText(text) {
    return (text || '').replace(/[\p{Pd}\s,.]/gu, '');
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
      this.element.dispatchEvent(new CustomEvent('audio-cache:play', {
        bubbles: true,
        detail: { url: audioUrl }
      }));
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
