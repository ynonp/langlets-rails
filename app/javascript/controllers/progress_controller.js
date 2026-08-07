import { Controller } from "@hotwired/stimulus"

// The single progress controller for the lesson nav bar's segmented track.
// It never talks to any activity directly: every activity controller
// reports its own progress by dispatching bubbling `activity:progress`
// (detail: { ratio }) and `activity:completed` events from its own element
// (see app/javascript/utils/activity_progress.js), and this controller only
// listens (wired via data-action on document, since the events bubble up
// from deep inside the turbo-frame) and fills the current activity's
// segment. Completed/upcoming segments are rendered server-side and never
// change client-side.
export default class extends Controller {
  static targets = ["fill", "dot"]

  setRatio(event) {
    if (!this.hasFillTarget) return

    const ratio = event.detail?.ratio ?? 0
    const clamped = Math.max(0, Math.min(1, ratio))
    this.paint(clamped * 100)
  }

  complete() {
    if (!this.hasFillTarget) return
    this.paint(100)
  }

  // The dot rides the fill's leading edge (same percentage, independently
  // positioned so it's never clipped by the fill track's overflow-hidden),
  // so the current activity reads as "you are here" even at 0% or 100%.
  paint(percent) {
    this.fillTarget.style.width = `${percent}%`
    this.fillTarget.closest('[role="progressbar"]')?.setAttribute('aria-valuenow', Math.round(percent))
    if (this.hasDotTarget) this.dotTarget.style.left = `${percent}%`
  }
}
