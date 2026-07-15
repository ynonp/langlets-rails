import { Controller } from "@hotwired/stimulus"
import { animate } from "motion/mini"

// Connects to data-controller="audio-to-translation-activity"
export default class extends Controller {
  static targets = ['progressBar', 'counter', 'waveform', 'completionMessage', 'grid'];
  static values = {
    totalPhrases: Number
  };

  connect() {
    this.matchedPhrases = 0;
    this.selectedPhrase = null;
    this.renderWaveforms();
    this.updateProgress();
  }

  // Draw a deterministic waveform "fingerprint" for each audio card, seeded from
  // its phrase text so the same text always produces the same bars.
  renderWaveforms() {
    this.waveformTargets.forEach((el) => {
      if (el.childElementCount > 0) return;
      const amps = this.seededWave(el.dataset.text || '', 26);
      const frag = document.createDocumentFragment();
      amps.forEach((a) => {
        const bar = document.createElement('span');
        // `wf-bar` is a JS-only hook; the rest are Tailwind utilities. Height is
        // data-driven, so it stays an inline style.
        bar.className = 'wf-bar w-[3px] rounded-[2px] shrink-0 bg-gray-300 dark:bg-gray-600 transition-colors duration-100';
        bar.style.height = `${Math.max(2, Math.round(a * 28))}px`;
        frag.appendChild(bar);
      });
      el.appendChild(frag);
    });
  }

  // FNV-1a hash: turn text into a stable 32-bit seed.
  textToSeed(text) {
    let h = 2166136261;
    for (let i = 0; i < text.length; i++) {
      h = (h ^ text.charCodeAt(i)) * 16777619 >>> 0;
    }
    return h;
  }

  // Seeded pseudo-random amplitudes (0.1–0.95) shaped as a few soft bumps,
  // so the waveform looks organic but is fully determined by the text.
  seededWave(text, bars = 26) {
    let s = this.textToSeed(text);
    const rnd = () => (s = (s * 1103515245 + 12345) >>> 0) / 4294967296;
    const bumps = 2 + Math.floor(rnd() * 3); // 2–4 bumps, unrelated to word count
    const centers = Array.from({ length: bumps }, () => rnd() * bars);
    return Array.from({ length: bars }, (_, i) => {
      let a = 0.1;
      for (const c of centers) a += 0.8 * Math.exp(-((i - c) ** 2) / (2 + rnd() * 6));
      return Math.min(a, 0.95);
    });
  }

  // Progressively "play" the waveform: fill bars left-to-right over the length of
  // the audio segment, mirroring the playback illustration.
  paintWaveform(card) {
    if (this.wfRaf) cancelAnimationFrame(this.wfRaf);
    // Clear any previously painted (but not matched) bars so only the active card fills
    this.element.querySelectorAll('.wf-bar.is-played').forEach((b) => this.setBarPlayed(b, false));

    const wf = card.querySelector('.wf');
    if (!wf) return;
    const bars = Array.from(wf.querySelectorAll('.wf-bar'));
    if (!bars.length) return;

    const start = parseFloat(card.dataset.mainVideoPlayerSegmentStartParam);
    const end = parseFloat(card.dataset.mainVideoPlayerSegmentEndParam);
    let durationMs = (end - start) * 1000;
    if (!isFinite(durationMs) || durationMs <= 0) durationMs = 1500;

    const t0 = performance.now();
    const step = (now) => {
      const progress = Math.min((now - t0) / durationMs, 1);
      const painted = Math.round(progress * bars.length);
      bars.forEach((bar, i) => this.setBarPlayed(bar, i < painted));
      if (progress < 1) {
        this.wfRaf = requestAnimationFrame(step);
      } else {
        this.wfRaf = null;
      }
    };
    this.wfRaf = requestAnimationFrame(step);
  }

  // Toggle a waveform bar between its idle (gray) and played (emerald) colors.
  // Swapping the classes keeps a single background utility active per bar, so no
  // !important is needed to win over the base gray.
  setBarPlayed(bar, on) {
    bar.classList.toggle('is-played', on);
    if (on) {
      bar.classList.remove('bg-gray-300', 'dark:bg-gray-600');
      bar.classList.add('bg-emerald-500');
    } else {
      bar.classList.remove('bg-emerald-500');
      bar.classList.add('bg-gray-300', 'dark:bg-gray-600');
    }
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
    
    // Don't allow selection of phrases that are already done or currently animating
    if (clickedElement.dataset.state === 'matched' ||
        clickedElement.classList.contains('animate-flash-success') ||
        clickedElement.classList.contains('animate-flash-error')) {
      return;
    }

    // Clicking an audio card (re)plays its segment, so paint its waveform in sync
    if (column === 'l1') {
      this.paintWaveform(clickedElement);
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
    this.attemptMatch(clickedElement);
  }

  selectNewPhrase(element, phraseId, column) {
    this.selectedPhrase = { element, phraseId, column };
    element.dataset.state = 'selected';
  }

  clearSelection() {
    if (this.selectedPhrase) {
      delete this.selectedPhrase.element.dataset.state;
      this.selectedPhrase = null;
    }
  }

  attemptMatch(clickedElement) {
    const selectedElement = this.selectedPhrase.element;

    // Text-only match: the L1 cell is an audio play button with no visible text,
    // so both cells carry the pair's L1 and L2 text. They match when both agree
    // (ignoring punctuation/whitespace).
    const samePair =
      this.normalizeText(selectedElement.dataset.textL1) === this.normalizeText(clickedElement.dataset.textL1) &&
      this.normalizeText(selectedElement.dataset.textL2) === this.normalizeText(clickedElement.dataset.textL2);

    if (samePair) {
      // Successful match
      this.handleSuccessfulMatch(this.selectedPhrase.element, clickedElement);
    } else {
      // Failed match
      this.handleFailedMatch(this.selectedPhrase.element, clickedElement);
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
    element1.classList.add('animate-flash-success');
    element2.classList.add('animate-flash-success');

    // Clear selection immediately to allow new selections
    this.clearSelection();

    // Award XP for correct match (2 XP per correct answer)
    this.awardXp(2);
    
    setTimeout(() => {
      // Mark both cells as done in-place (keep them visible instead of hiding)
      this.markDone(element1);
      this.markDone(element2);

      this.matchedPhrases++;
      this.updateProgress();

      // Check if all phrases are matched
      if (this.matchedPhrases === this.totalPhrasesValue) {
        this.showCompletion();
      }
    }, 600);
  }

  // Mark a correctly-matched cell "done": the data-state variants dim it, hide the
  // waveform, and reveal the phrase text + ✓ (all pre-rendered in the template),
  // so the learner keeps seeing solved pairs instead of them disappearing.
  markDone(element) {
    element.classList.remove('animate-flash-success', 'animate-flash-error');
    element.dataset.state = 'matched';
    // Stop it from triggering audio playback or further selection
    element.removeAttribute('data-action');
    if (element.tagName === 'BUTTON') element.disabled = true;
  }

  handleFailedMatch(element1, element2) {
    // Play incorrect sound
    this.element.dispatchEvent(new CustomEvent('audio:incorrect', { bubbles: true }));
    
    // Flash red
    element1.classList.add('animate-flash-error');
    element2.classList.add('animate-flash-error');

    // Clear selection immediately to allow new selections
    this.clearSelection();

    setTimeout(() => {
      element1.classList.remove('animate-flash-error');
      element2.classList.remove('animate-flash-error');
    }, 600);
  }

  updateProgress() {
    const percentage = (this.matchedPhrases / this.totalPhrasesValue) * 100;
    this.progressBarTarget.style.width = `${percentage}%`;
    if (this.hasCounterTarget) {
      this.counterTarget.textContent = `${this.matchedPhrases} / ${this.totalPhrasesValue} matched`;
    }
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

