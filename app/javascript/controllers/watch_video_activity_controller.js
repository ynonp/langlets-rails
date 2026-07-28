import { Controller } from "@hotwired/stimulus"

// How long (seconds) a word may stay highlighted past its own end timestamp
// while waiting for the next word. This bridges the small gaps between words
// (so the highlight doesn't blink off) without holding a word lit through a
// long instrumental break.
const KARAOKE_HOLD_LIMIT = 1.5;

export default class extends Controller {
  static targets = ['subtitles', 'container', 'phrasesList', 'l1Text', 'l2Text', 'showTranslation', 'showKaraoke', 'startPracticeButton'];
  static values = { wordTiming: Boolean, prefsUrl: String };

  initialize() {
    this.pausedForTranslation = false;
    this.videoPlaying = false;
  }

  handleTranslationClick(event) {
    const token = event.target.closest('[data-translation]');
    if (!token) return;

    if (this.pausedForTranslation) {
      this.pausedForTranslation = false;
      this.dispatch('resume');
      return;
    }

    if (this.videoPlaying) {
      this.pausedForTranslation = true;
      this.dispatch('pause');
    }
  }

  resumeAfterTranslation() {
    if (!this.pausedForTranslation) return;

    this.pausedForTranslation = false;
    this.dispatch('resume');
  }

  // PATCH the current toggle states to the server so they persist across visits.
  persistPrefs() {
    if (!this.hasPrefsUrlValue) return;

    const body = {};
    if (this.hasShowTranslationTarget) body.translation = this.showTranslationTarget.checked;
    if (this.hasShowKaraokeTarget) body.karaoke = this.showKaraokeTarget.checked;

    const token = document.querySelector('meta[name="csrf-token"]')?.content;
    fetch(this.prefsUrlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": token || ""
      },
      body: JSON.stringify(body)
    }).catch(() => {});
  }

  progress(ev) {
    const {at} = ev.detail
    this.updateSubtitles(at);
    if (this.wordTimingValue && this.karaokeEnabled) {
      this.updateWordHighlight(at);
    }
  }

  // Karaoke highlight is on by default; a checkbox in the header can turn it off.
  get karaokeEnabled() {
    return !this.hasShowKaraokeTarget || this.showKaraokeTarget.checked;
  }

  toggleKaraoke() {
    // Clear any active highlight when karaoke is disabled.
    if (!this.showKaraokeTarget.checked && this.karaokeTokens) {
      this.karaokeTokens.forEach(({ span }) => span.removeAttribute('data-active'));
    }
    this.persistPrefs();
  }

  // Karaoke-style highlight. Rather than lighting a word only while playback is
  // inside its own [start, end] window (which blinks off during the gap before
  // the next word), we keep the most recently started word highlighted until
  // the next word starts. The final word, and long instrumental gaps, fall back
  // to the word's own end (plus a small grace period) so nothing stays stuck.
  updateWordHighlight(currentTime) {
    if (!this.karaokeTokens) {
      this.karaokeTokens = Array.from(this.element.querySelectorAll('[data-token-start]'))
        .filter(span => span.dataset.tokenStart !== '')
        .map(span => ({
          span,
          start: Number(span.dataset.tokenStart),
          end: Number(span.dataset.tokenEnd),
        }))
        .filter(({ start, end }) => Number.isFinite(start) && Number.isFinite(end))
        .sort((a, b) => a.start - b.start);
    }

    const tokens = this.karaokeTokens;

    // The active word is the last one that has already started.
    let activeIndex = -1;
    for (let i = 0; i < tokens.length && tokens[i].start <= currentTime; i++) {
      activeIndex = i;
    }

    let active = null;
    if (activeIndex !== -1) {
      const token = tokens[activeIndex];
      const next = tokens[activeIndex + 1];
      if (next && currentTime < next.start) {
        // Hold across the inter-word gap, unless it's a long pause.
        if (currentTime - token.end <= KARAOKE_HOLD_LIMIT) active = token;
      } else if (!next && currentTime <= token.end) {
        // Final word: respect its own end so it isn't stuck lit forever.
        active = token;
      }
    }

    // Views style the active word via Tailwind data-active: variants.
    for (const token of tokens) {
      token.span.toggleAttribute('data-active', token === active);
    }
  }

  handleVideoStart() {
    this.videoPlaying = true;
    this.pausedForTranslation = false;
  }

  handleVideoPause() {
    this.videoPlaying = false;
  }

  handleVideoEnd() {
    if (this.startPracticeButtonTarget.classList.contains('hidden')) {
      // Play completion sound
      this.element.dispatchEvent(new CustomEvent('audio:complete', { bubbles: true }));

      // Award XP for watching video (10 XP for single-stage activity)
      this.awardXp(10);

      this.startPracticeButtonTarget.classList.remove('hidden');
      this.startActivityButtonTarget.classList.add('hidden');
      this.element.dispatchEvent(new CustomEvent('activity:completed', { bubbles: true }))
    }
  }

  // The toggle is a 2-state L1/L2 switch: unchecked shows L1 (clickable
  // words), checked shows L2 (plain text, not clickable). Only one language's
  // lyrics are ever visible at a time.
  toggleTranslation() {
    const showL2 = this.showTranslationTarget.checked;
    this.l1TextTargets.forEach(el => el.classList.toggle('hidden', showL2));
    this.l2TextTargets.forEach(el => el.classList.toggle('hidden', !showL2));
    this.persistPrefs();
  }

  updateSubtitles(currentTime) {
    const subtitlesLines = this.subtitlesTargets;
    const index = subtitlesLines.map(item => Number(item.dataset.timestamp)).findLastIndex(t => t < currentTime);

    if (index !== -1) {
      // Views style the active line via Tailwind data-active: variants.
      subtitlesLines[index].setAttribute('data-active', '');
      
      // Emit event when a phrase becomes active
      const event = new CustomEvent('video-player:phrase-activated', {
        detail: { phraseElement: subtitlesLines[index] }
      });
      this.element.dispatchEvent(event);
      
      const container = this.containerTarget;
      const lineHeight = subtitlesLines[index].offsetHeight;
      const containerHeight = container.clientHeight;

      // getBoundingClientRect gives accurate viewport-relative positions,
      // adding scrollTop converts to scroll-content-relative position
      const containerRect = container.getBoundingClientRect();
      const lineRect = subtitlesLines[index].getBoundingClientRect();
      const currentLineTop = lineRect.top - containerRect.top + container.scrollTop;

      // Show previous line as context if there's room; otherwise show current line at the top
      const contextOffset = Math.min(lineHeight, Math.max(0, containerHeight - lineHeight));
      const targetScrollTop = currentLineTop - contextOffset;
  
      container.scrollTo({
        top: targetScrollTop,
        behavior: 'smooth'
      });          
    }

    for (let i=0; i < subtitlesLines.length; i++) {
      if (i !== index) {
        subtitlesLines[i].removeAttribute('data-active');
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
