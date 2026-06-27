import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ['subtitles', 'container', 'phrasesList', 'translation', 'showTranslation', 'showKaraoke', 'startPracticeButton'];
  static classes = ['currentTextLine'];
  static values = { wordTiming: Boolean, prefsUrl: String };

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
    if (!this.showKaraokeTarget.checked && this.tokenSpans) {
      this.tokenSpans.forEach(span => span.classList.remove('s-token-active'));
    }
    this.persistPrefs();
  }

  // Karaoke-style highlight: mark the single token whose [start, end] window
  // contains the current playback time. Tokens without timing data (older songs)
  // have no data-token-start attribute and are ignored.
  updateWordHighlight(currentTime) {
    if (!this.tokenSpans) {
      this.tokenSpans = Array.from(this.element.querySelectorAll('[data-token-start]'));
    }

    for (const span of this.tokenSpans) {
      const start = Number(span.dataset.tokenStart);
      const end = Number(span.dataset.tokenEnd);
      span.classList.toggle('s-token-active', currentTime >= start && currentTime <= end);
    }
  }

  handleVideoStart() {
  }

  handleVideoPause() {
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

  toggleTranslation() {
    const showTranslations = this.showTranslationTarget.checked;
    this.translationTargets.forEach(translation => {
      if (showTranslations) {
        translation.classList.remove('hidden');
      } else {
        translation.classList.add('hidden');
      }
    });
    this.persistPrefs();
  }

  updateSubtitles(currentTime) {
    const subtitlesLines = this.subtitlesTargets;
    const index = subtitlesLines.map(item => Number(item.dataset.timestamp)).findLastIndex(t => t < currentTime);

    if (index !== -1) {
      subtitlesLines[index].classList.add(this.currentTextLineClass);
      
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
        subtitlesLines[i].classList.remove(this.currentTextLineClass);
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
