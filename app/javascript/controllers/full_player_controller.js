import { Controller } from "@hotwired/stimulus"
import {
  crossedSentenceBoundary,
  nextSentenceBoundaryIndex,
  playbackJumped,
} from "../players/sentence_boundaries.mjs"

// Optional transcript controls used by the full-course player and watch-video
// lesson activities. Keeping these out of main-video-player prevents reading
// and sentence-pause modes from changing hidden-audio, compact, listen, or
// flashcard players.
export default class extends Controller {
  static targets = ["mediaBox", "sentence", "textOnlyToggle", "sentencePauseToggle"]

  connect() {
    this.lastProgressAt = null
    this.nextSentenceIndex = 0
    this.textOnlyActive = false
  }

  disconnect() {
    this.restoreMediaBox()
  }

  toggleTextOnly() {
    const textOnly = this.textOnlyToggleTarget.checked
    this.mediaBoxTarget.classList.toggle("hidden", textOnly)
    this.mediaBoxTarget.setAttribute("aria-hidden", String(textOnly))
    this.textOnlyActive = textOnly

    // Reading mode has no visible playback control, so do not leave audio
    // running invisibly when the learner switches into it.
    if (textOnly) this.dispatch("pause")
  }

  resetForFrameNavigation() {
    this.restoreMediaBox()
    this.lastProgressAt = null
    this.nextSentenceIndex = 0
  }

  toggleSentencePause() {
    this.nextSentenceIndex = nextSentenceBoundaryIndex(this.sentenceEnds, this.lastProgressAt ?? -Infinity)
  }

  progress(event) {
    const at = Number(event.detail.at)
    if (!Number.isFinite(at)) return

    if (!Number.isFinite(this.lastProgressAt)) {
      this.nextSentenceIndex = nextSentenceBoundaryIndex(this.sentenceEnds, at)
      this.lastProgressAt = at
      return
    }

    if (playbackJumped(this.lastProgressAt, at)) {
      this.nextSentenceIndex = nextSentenceBoundaryIndex(this.sentenceEnds, at)
      this.lastProgressAt = at
      return
    }

    const boundary = this.sentenceEnds[this.nextSentenceIndex]
    if (this.sentencePauseToggleTarget.checked && crossedSentenceBoundary(this.lastProgressAt, at, boundary)) {
      this.nextSentenceIndex += 1
      this.dispatch("pause")
    }

    this.lastProgressAt = at
  }

  seekedToSentence(event) {
    if (event.target.closest("[data-translation]")) return

    const sentence = event.target.closest("[data-timestamp]")
    if (!sentence) return

    const at = Number(sentence.dataset.timestamp)
    this.lastProgressAt = at
    this.nextSentenceIndex = nextSentenceBoundaryIndex(this.sentenceEnds, at)
  }

  get sentenceEnds() {
    return this.sentenceTargets
      .map((sentence) => Number(sentence.dataset.sentenceEnd))
      .filter(Number.isFinite)
  }

  restoreMediaBox() {
    if (!this.textOnlyActive || !this.hasMediaBoxTarget) return

    this.mediaBoxTarget.classList.remove("hidden")
    this.mediaBoxTarget.setAttribute("aria-hidden", "false")
    this.textOnlyActive = false
  }
}
