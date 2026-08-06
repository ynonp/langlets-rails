import { Controller } from "@hotwired/stimulus"
import { t } from "../utils/i18n"
import { animate } from "motion/mini"

// Connects to data-controller="tokens-chain-activity"
export default class extends Controller {
  static targets = ['page', 'startButton', 'completionMessage', 'progressBar', 'progressText', 'stopPracticingContainer'];
  static values = {
    tokens: Array,
    totalTokens: Number,
    pageSize: Number,
    l1IsoName: String
  };

  connect() {
    this.currentIndex = 0; // Start at first token (already displayed in top-left)
    this.tokensArray = this.tokensValue || [];
    this.currentPageIndex = 0; // Track which page is currently visible
    this.currentL1Element = this.startButtonTargets[0]; // Track which element shows current L1

    // Mark initial L1 as current
    this.startButtonTargets[0].classList.add('current-l1');

    // Warm the shared audio cache for the start of the chain
    this.preloadUpcomingAudio();
  }

  playL1Audio(event) {
    // The square showing the current L1 word carries its own audio URL
    this.playAudioUrl(event.currentTarget.dataset.audioUrl);
  }

  playAudioUrl(url) {
    this.element.dispatchEvent(new CustomEvent('audio-cache:play', { bubbles: true, detail: { url } }));
  }

  // Preload the current token's audio and the next couple in the chain
  preloadUpcomingAudio() {
    const urls = this.tokensArray
      .slice(this.currentIndex, this.currentIndex + 3)
      .map(token => token.audio_url);
    this.element.dispatchEvent(new CustomEvent('audio-cache:preload', { bubbles: true, detail: { urls } }));
  }

  selectSquare(event) {
    // Don't allow selection if all tokens matched or if square is already matched
    if (this.currentIndex >= this.tokensArray.length) return;
    
    const clickedElement = event.currentTarget;
    const clickedText = clickedElement.textContent;
    
    // Don't allow selection of squares that are currently animating or showing L1
    if (clickedElement.classList.contains('flash-success') || 
        clickedElement.classList.contains('flash-error') ||
        clickedElement.classList.contains('showing-l1')) {
      return;
    }

    const currentToken = this.tokensArray[this.currentIndex];

    // Text-only match: the clicked square shows the L2 translation, so compare
    // it to the current token's L2 text (ignoring punctuation/whitespace).
    if (this.normalizeText(currentToken.l2_text) === this.normalizeText(clickedText)) {
      this.handleCorrectMatch(clickedElement);
    } else {
      this.handleWrongMatch(clickedElement);
    }
  }

  // Strip dash punctuation (Unicode \p{Pd}: hyphen, en/em dash, etc.),
  // whitespace, commas and periods so that "uh-huh", "uh huh", "uh, huh."
  // and "uhhuh" all compare as equal.
  // We deliberately keep other punctuation (e.g. apostrophes) so "it's" != "its".
  normalizeText(text) {
    return (text || '').replace(/[\p{Pd}\s,.]/gu, '');
  }

  handleCorrectMatch(element) {
    // Play correct sound
    this.element.dispatchEvent(new CustomEvent('audio:correct', { bubbles: true }));
    
    // Flash green
    element.classList.add('flash-success');
    
    // Award XP (2 XP per correct match)
    this.awardXp(2);
    
    // Move to next token
    this.currentIndex++;
    this.updateProgress();
    this.preloadUpcomingAudio();

    if (this.currentIndex >= this.tokensArray.length) {
      // All tokens matched across every page
      setTimeout(() => {
        this.showCompletion();
      }, 600);
      return;
    }

    // A page is complete once we've matched pageSizeValue tokens on it
    const crossingPageBoundary = this.currentIndex % this.pageSizeValue === 0;

    if (crossingPageBoundary) {
      // Reveal the next page instead of flipping the current square
      setTimeout(() => {
        const currentToken = this.tokensArray[this.currentIndex];
        this.advanceToNextPage(currentToken);
      }, 600);
      return;
    }

    // Flip the matched square to show next L1 word
    setTimeout(() => {
      const currentToken = this.tokensArray[this.currentIndex];
      const textElement = element.querySelector('.token-text');
      if (textElement) {
        textElement.textContent = currentToken.l1_text;
        // The square now shows an L1 word, so hyphenation must follow L1 rules
        textElement.lang = this.l1IsoNameValue;
      }
      // Remove current highlight from previous L1
      if (this.currentL1Element) {
        this.currentL1Element.classList.remove('current-l1');
        this.currentL1Element.classList.add('found-translation');
      }
      // Update styling to show it's now displaying L1
      element.classList.remove('flash-success', 'bg-white', 'dark:bg-gray-900', 'hover:bg-gray-100', 'dark:hover:bg-gray-800');
      element.classList.remove('found-translation');
      element.classList.add('showing-l1', 'bg-gray-100', 'dark:bg-gray-800', 'cursor-pointer', 'current-l1');
      // Store the audio URL so tapping the square replays its word
      element.dataset.audioUrl = currentToken.audio_url || '';
      // Add click handler for L1 audio playback
      element.setAttribute('data-action', 'click->tokens-chain-activity#playL1Audio');
      // Remove token ID since it now shows L1
      element.removeAttribute('data-token-id');
      // Update current L1 element reference
      this.currentL1Element = element;

      // Play the next token's word
      this.playAudioUrl(currentToken.audio_url);
    }, 600);
  }

  // Hide the finished page and reveal the next one, highlighting its
  // (already rendered) L1 start square instead of flipping a square.
  advanceToNextPage(currentToken) {
    const previousPage = this.pageTargets[this.currentPageIndex];
    this.currentPageIndex++;
    const nextPage = this.pageTargets[this.currentPageIndex];

    // Strip the glow/scale styling (transform + box-shadow) before hiding
    // the page it lives on, and force a reflow so the change is committed
    // first. Safari can otherwise leave a ghost of a GPU-composited element
    // on screen when its ancestor is set to display:none mid-transition.
    if (this.currentL1Element) {
      this.currentL1Element.classList.remove('current-l1');
      this.currentL1Element.classList.add('found-translation');
    }
    void previousPage.offsetHeight;

    previousPage.classList.add('hidden');
    nextPage.classList.remove('hidden');

    const nextStartButton = this.startButtonTargets[this.currentPageIndex];
    nextStartButton.classList.add('current-l1');
    this.currentL1Element = nextStartButton;

    this.playAudioUrl(currentToken.audio_url);
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
    const matchedCount = this.currentIndex;
    const percentage = (matchedCount / this.totalTokensValue) * 100;
    this.progressTextTarget.textContent = t("tokens_chain.matched", { current: matchedCount, total: this.totalTokensValue });
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

    // Same Safari ghosting concern as advanceToNextPage: strip the glow
    // styling and force a reflow before hiding the page it lives on.
    const lastPage = this.pageTargets[this.currentPageIndex];
    if (this.currentL1Element) {
      this.currentL1Element.classList.remove('current-l1');
    }
    void lastPage.offsetHeight;
    lastPage.classList.add('hidden');
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
