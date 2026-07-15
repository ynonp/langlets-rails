import { Controller } from "@hotwired/stimulus"

// Central playback + LRU cache for word pronunciation clips.
// Attached to <main> in the layout, above the activity turbo-frame, so the
// cache survives navigation between activities and at most `size` media
// elements exist at any time (media elements hold native player resources
// in mobile webviews, so we keep the count bounded).
//
// Playback triggers:
//  - clicks on elements marked data-audio-click (URL in data-audio-url),
//    handled in the capture phase so inner handlers that stopPropagation
//    (e.g. popover-translation) can't swallow them
//  - "audio-cache:play"    detail: { url }
//  - "audio-cache:preload" detail: { urls: [...] }
//  - "audio-cache:stop"
export default class extends Controller {
  static values = { size: { type: Number, default: 8 } }

  connect() {
    this.cache = new Map() // url -> HTMLAudioElement; insertion order = recency
    this.currentAudio = null
  }

  disconnect() {
    this.stop()
    this.cache.forEach((audio) => this.releaseAudio(audio))
    this.cache.clear()
  }

  handleClick(event) {
    const el = event.target.closest("[data-audio-click]")
    if (!el) return
    this.play(el.dataset.audioUrl)
  }

  playEvent(event) {
    this.play(event.detail?.url)
  }

  preloadEvent(event) {
    const urls = event.detail?.urls || []
    // A batch larger than the cache would evict itself; keep the head.
    urls.filter((url) => this.validUrl(url))
      .slice(0, this.sizeValue)
      .forEach((url) => this.fetchAudio(url))
  }

  stop() {
    if (this.currentAudio) {
      this.currentAudio.pause()
      this.currentAudio = null
    }
  }

  play(url) {
    if (!this.validUrl(url)) return
    this.stop()
    const audio = this.fetchAudio(url)
    if (audio.readyState > 0) audio.currentTime = 0
    audio.volume = 0.7
    this.currentAudio = audio
    audio.play().catch((error) => {
      console.warn("Audio playback failed:", error)
    })
  }

  validUrl(url) {
    return url && url !== "null"
  }

  fetchAudio(url) {
    if (this.cache.has(url)) {
      const audio = this.cache.get(url)
      // Re-insert to mark as most recently used
      this.cache.delete(url)
      this.cache.set(url, audio)
      return audio
    }

    const audio = new Audio()
    audio.preload = "auto"
    audio.src = url
    audio.load()
    this.cache.set(url, audio)
    this.evictOverflow()
    return audio
  }

  evictOverflow() {
    for (const [url, audio] of this.cache) {
      if (this.cache.size <= this.sizeValue) break
      if (audio === this.currentAudio && !audio.paused) continue
      this.cache.delete(url)
      this.releaseAudio(audio)
    }
  }

  // Detach the media resource so webviews free the native player, not just
  // the JS wrapper.
  releaseAudio(audio) {
    audio.pause()
    audio.removeAttribute("src")
    audio.load()
  }
}
