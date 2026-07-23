import { Controller } from "@hotwired/stimulus"

// Drives the hero product screenshots on the public homepage: auto-advancing
// slideshow with prev/next arrows and clickable dots. Slides (image + caption)
// are passed in as a JSON value so the markup stays in the ERB view.
export default class extends Controller {
  static targets = ["image", "caption", "dot"]
  static values = {
    slides: Array,
    interval: { type: Number, default: 4500 },
    activeColor: { type: String, default: "#C4451C" },
    inactiveColor: { type: String, default: "#DDD3BE" }
  }

  connect() {
    this.index = 0
    this.render()
    this.start()
  }

  disconnect() {
    this.stop()
  }

  start() {
    this.stop()
    if (this.slidesValue.length > 1) {
      this.timer = setInterval(() => this.next(), this.intervalValue)
    }
  }

  stop() {
    if (this.timer) clearInterval(this.timer)
    this.timer = null
  }

  next() {
    this.go(this.index + 1)
  }

  prev() {
    this.go(this.index - 1)
  }

  // Dot / arrow clicks: jump to a slide and stop the auto-advance so the page
  // stops moving under the visitor once they take control.
  select(event) {
    this.stop()
    const i = Number(event.params.index)
    this.go(Number.isNaN(i) ? this.index : i)
  }

  arrow(event) {
    this.stop()
    this.go(this.index + Number(event.params.step))
  }

  go(i) {
    const n = this.slidesValue.length
    if (n === 0) return
    this.index = ((i % n) + n) % n
    this.render()
  }

  render() {
    const slide = this.slidesValue[this.index]
    if (!slide) return
    if (this.hasImageTarget) {
      this.imageTarget.src = slide.img
      this.imageTarget.alt = slide.caption
    }
    if (this.hasCaptionTarget) {
      this.captionTarget.textContent = slide.caption
    }
    this.dotTargets.forEach((dot, i) => {
      dot.style.background = i === this.index ? this.activeColorValue : this.inactiveColorValue
    })
  }
}
