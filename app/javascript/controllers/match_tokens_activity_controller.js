import { Controller } from "@hotwired/stimulus"
import { t } from "../utils/i18n"
import { animate } from "motion/mini"

// Connects to data-controller="match-tokens-activity"
//
// Each page (rendered server-side) shows up to `pageSize` pairs in a 2-column
// grid. Cells start in a normal state and are marked `data-state="matched"`
// after a correct pair, mirroring the audio-to-translation activity: the
// cell stays in place but is dimmed so the learner keeps a visual record
// of the solved pairs. Once every pair on a page is matched, the page is
// hidden and the next page is revealed. Tapping an L1 cell always plays
// the L1 audio for that pair (whether it's tapped first, second, or used
// to switch selection); tapping an L2 cell is silent.
export default class extends Controller {
  static targets = ['page', 'progressBar', 'progressText', 'completionMessage'];
  static values = {
    tokens: Array,
    totalTokens: Number,
    pageSize: Number,
    isReviewLesson: Boolean
  };

  connect() {
    this.matchedTokens = 0;
    this.selectedToken = null;
    this.currentPageIndex = 0;
    this.activeTouches = new Map();

    this.preloadAllAudio();
  }

  // Record each touch point on touchstart so we can match pairs on touchend.
  // touchend fires per-finger, so changedTouches.length is always 1 — we can't
  // detect multi-touch from touchend alone.
  handleTouchStart(event) {
    for (const t of event.changedTouches) {
      const el = document.elementFromPoint(t.clientX, t.clientY)?.closest('[data-token-id]');
      if (el) {
        this.activeTouches.set(t.identifier, { element: el, column: el.dataset.column });
      }
    }
  }

  // On touchend, check whether we have two tracked touches from opposite
  // columns.  If so, perform the match.  Single-finger taps are left alone so
  // the synthesized `click` runs the normal sequential flow.
  handleTouchEnd(event) {
    const tracked = Array.from(this.activeTouches.values());

    for (const t of event.changedTouches) {
      this.activeTouches.delete(t.identifier);
    }

    if (tracked.length < 2) return;
    const l1Touch = tracked.find(t => t.column === 'l1');
    const l2Touch = tracked.find(t => t.column === 'l2');
    if (!l1Touch || !l2Touch) return;

    const isBusy = el =>
      el.dataset.state === 'matched' ||
      el.dataset.state === 'selected' ||
      el.classList.contains('animate-flash-success') ||
      el.classList.contains('animate-flash-error');
    if (l1Touch.element === l2Touch.element || isBusy(l1Touch.element) || isBusy(l2Touch.element)) return;

    event.preventDefault();
    this.activeTouches.clear();

    this.clearSelection();
    this.selectNewToken(l1Touch.element);
    // The L1 audio belongs to the L1 word — play it on the multi-touch path
    // too, mirroring the single-click behavior in selectToken().
    this.playTokenAudio(l1Touch.element);
    this.attemptMatch(l2Touch.element);
  }

  preloadAllAudio() {
    const audioUrls = [...new Set(
      this.tokensValue
        .map(token => token.audio_url)
        .filter(url => url && url !== 'null' && url !== '')
    )];

    this.element.dispatchEvent(new CustomEvent('audio-cache:preload', {
      bubbles: true,
      detail: { urls: audioUrls }
    }));
  }

  selectToken(event) {
    const clickedToken = event.currentTarget;

    if (clickedToken.dataset.state === 'matched' ||
        clickedToken.dataset.state === 'selected' ||
        clickedToken.classList.contains('animate-flash-success') ||
        clickedToken.classList.contains('animate-flash-error')) {
      return;
    }

    // The L1 audio belongs to the L1 word. Play it on every L1 tap, whether
    // it's the first cell tapped, the second (to complete a match), or a
    // switch from another L1 cell. Tapping an L2 cell never plays audio.
    if (clickedToken.dataset.column === 'l1') {
      this.playTokenAudio(clickedToken);
    }

    // If clicking the same cell, deselect it
    if (this.selectedToken && this.selectedToken.element === clickedToken) {
      this.clearSelection();
      return;
    }

    // If no cell is selected, select this one
    if (!this.selectedToken) {
      this.selectNewToken(clickedToken);
      return;
    }

    // If clicking a cell from the same column, switch selection
    if (this.selectedToken.column === clickedToken.dataset.column) {
      this.clearSelection();
      this.selectNewToken(clickedToken);
      return;
    }

    // If clicking a cell from the opposite column, attempt match
    this.attemptMatch(clickedToken);
  }

  selectNewToken(element) {
    this.selectedToken = { element, column: element.dataset.column };
    element.dataset.state = 'selected';
  }

  clearSelection() {
    if (this.selectedToken) {
      delete this.selectedToken.element.dataset.state;
      this.selectedToken = null;
    }
  }

  attemptMatch(clickedElement) {
    const selectedElement = this.selectedToken.element;

    // Two cells belong to the same pair when they share the same token id.
    // (Both texts are also carried on the cell for parity with the previous
    // text-only match, in case we ever need to fall back to it.)
    const samePair = selectedElement.dataset.tokenId === clickedElement.dataset.tokenId;

    if (samePair) {
      this.handleSuccessfulMatch(selectedElement, clickedElement);
    } else {
      this.handleFailedMatch(selectedElement, clickedElement);
    }
  }

  handleSuccessfulMatch(element1, element2) {
    this.element.dispatchEvent(new CustomEvent('audio:correct', { bubbles: true }));

    element1.classList.add('animate-flash-success');
    element2.classList.add('animate-flash-success');

    this.clearSelection();
    this.awardXp(2);

    setTimeout(() => {
      this.markDone(element1);
      this.markDone(element2);

      this.matchedTokens++;
      this.updateProgress();

      // If we've completed the current page, advance to the next one.
      this.maybeAdvancePage();
    }, 600);
  }

  // Mark a correctly-matched cell "done": the data-state variants dim it and
  // reveal the pre-rendered ✓, so the learner keeps seeing solved pairs
  // instead of them disappearing.
  markDone(element) {
    element.classList.remove('animate-flash-success', 'animate-flash-error');
    element.dataset.state = 'matched';
  }

  // Hide the finished page and reveal the next one. Mirrors the pattern used
  // by tokens-chain-activity, including forcing a reflow before hiding to
  // avoid Safari ghosting of a GPU-composited element.
  maybeAdvancePage() {
    const currentPage = this.pageTargets[this.currentPageIndex];
    if (!currentPage) return;

    // All pairs on the page are matched when no cell on it is still active.
    const stillActive = currentPage.querySelector('[data-token-id]:not([data-state="matched"])');
    if (stillActive) return;

    const nextPage = this.pageTargets[this.currentPageIndex + 1];
    if (!nextPage) {
      // No more pages: check for overall completion
      if (this.matchedTokens === this.totalTokensValue) {
        this.showCompletion();
      }
      return;
    }

    void currentPage.offsetHeight;
    currentPage.classList.add('hidden');
    nextPage.classList.remove('hidden');
    this.currentPageIndex++;

    // Play the L1 audio of the first pair on the new page so the user hears
    // the next word to match.
    const firstL1 = nextPage.querySelector('[data-column="l1"]');
    if (firstL1) this.playTokenAudio(firstL1);
  }

  handleFailedMatch(element1, element2) {
    this.element.dispatchEvent(new CustomEvent('audio:incorrect', { bubbles: true }));

    element1.classList.add('animate-flash-error');
    element2.classList.add('animate-flash-error');

    this.clearSelection();

    setTimeout(() => {
      element1.classList.remove('animate-flash-error');
      element2.classList.remove('animate-flash-error');
    }, 600);
  }

  updateProgress() {
    const percentage = (this.matchedTokens / this.totalTokensValue) * 100;
    this.progressBarTarget.style.width = `${percentage}%`;
    if (this.hasProgressTextTarget) {
      this.progressTextTarget.textContent = t("match_tokens.matched", { current: this.matchedTokens, total: this.totalTokensValue });
    }
  }

  showCompletion() {
    this.element.dispatchEvent(new CustomEvent('audio:complete', { bubbles: true }));

    this.completionMessageTarget.classList.remove('hidden');
    animate(this.completionMessageTarget,
      { opacity: [0, 1], scale: [0.8, 1] },
      { duration: 0.3, easing: 'easeOut' }
    );
    this.element.dispatchEvent(new CustomEvent('activity:completed', { bubbles: true }));

    // Hide the last page (same Safari ghosting concern as maybeAdvancePage).
    const lastPage = this.pageTargets[this.currentPageIndex];
    if (lastPage) {
      void lastPage.offsetHeight;
      lastPage.classList.add('hidden');
    }
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
    const gamificationBar = document.getElementById('gamification-bar');
    if (gamificationBar && gamificationBar.dataset.controller) {
      const controller = this.application.getControllerForElementAndIdentifier(gamificationBar, 'progress-tracker');
      if (controller) {
        controller.awardXp(amount);
      }
    }
  }
}
