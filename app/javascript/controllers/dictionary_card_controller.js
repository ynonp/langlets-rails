import { Controller } from "@hotwired/stimulus"

// The Dictionary card (app/views/app/dictionary_lookups/_card.html.erb).
//
// While the card is still being written or illustrated the server renders this
// element with `pending`, and we reload the surrounding turbo-frame from
// `url`. The reload replaces this element too, so the next render decides
// whether polling continues — the last render without `pending` ends it.
// Polling rather than Action Cable for the same reason as poll_controller.js:
// the app has no channels, and a WKWebView socket dies when iOS backgrounds it.
export default class extends Controller {
  static targets = ["audio"]
  static values = {
    url: String,
    pending: Boolean,
    interval: { type: Number, default: 1500 }
  }

  connect() {
    if (this.pendingValue) this.schedule()
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  schedule() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.reload(), this.intervalValue)
  }

  reload() {
    const frame = this.element.closest("turbo-frame")
    if (!frame) return

    // The frame is rendered without a src so the first paint costs nothing
    // extra; setting it starts the first load, reload() repeats it.
    if (frame.getAttribute("src")) {
      frame.reload()
    } else {
      frame.src = this.urlValue
    }
  }

  play() {
    if (!this.hasAudioTarget) return

    this.audioTarget.currentTime = 0
    this.audioTarget.play().catch(() => {})
  }
}
