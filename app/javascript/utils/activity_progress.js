// Shared event contract every activity controller uses to report progress to
// the lesson nav bar's `progress` Stimulus controller, instead of each
// activity rendering its own progress bar. `ratio` is 0..1 within the
// current activity; full completion is reported separately via the existing
// `activity:completed` event.
export function reportActivityProgress(element, ratio) {
  element.dispatchEvent(new CustomEvent('activity:progress', {
    bubbles: true,
    detail: { ratio }
  }))
}
