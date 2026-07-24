import { Controller } from "@hotwired/stimulus"

// The Add Video sheet's link input.
//
// It does not decide what the input *is* — the server does that, in
// ImportRequestsController#resolve, and this just reloads the frame and lets the
// answer come back. The one thing classified here is timing: a complete link
// should resolve instantly, while a half-typed one shouldn't be called a mistake
// before the user has finished making it. So the regex below only ever chooses
// between "now" and "once they stop typing" (plus the green tick, which is
// cosmetic). Making this the authority on what a video id is would be a second
// definition to keep in step with VideoSource, and they would drift.
//
// TikTok share links (vt./vm.tiktok.com) count as complete here even though no
// id can be read out of them — only oEmbed can resolve one, server-side. That
// is exactly the point: this decides "has the user finished typing", not "is
// this importable".
const VIDEO_PATTERN =
  /(?:youtube\.com\/(?:[^/]+\/.+\/|(?:v|e(?:mbed)?)\/|shorts\/|.*[?&]v=)|youtu\.be\/)([^"&?/\s]{11})|^[A-Za-z0-9_-]{11}$|(?:[/.])tiktok\.com\/(?:@[\w.-]+\/(?:video|photo)\/\d{6,}|t\/[\w-]{5,})|(?:[/.])(?:vt|vm)\.tiktok\.com\/[\w-]{5,}/

// Long enough that typing a link by hand doesn't flash "that's not a link" on
// the way to one.
const SETTLE_MS = 500

export default class extends Controller {
  static targets = ["input", "field", "clear", "hint", "recognized", "clipboardChip", "language"]
  static values = { resolveUrl: String }

  connect() {
    this.offerClipboard()

    // Arriving with ?url= — from the share extension, or bounced back from the
    // credits screen. Resolve it straight away rather than making them tap.
    if (this.inputTarget.value.trim()) this.inputChanged()
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  inputChanged() {
    clearTimeout(this.timer)

    const value = this.inputTarget.value.trim()
    const isVideo = VIDEO_PATTERN.test(value)

    this.updateChrome(value, isVideo)

    // A finished link resolves immediately; so does clearing the box, which
    // should leave the sheet looking freshly opened. Everything in between waits
    // until the typing stops.
    if (isVideo || value === "") return this.reloadFrame()

    this.timer = setTimeout(() => this.reloadFrame(), SETTLE_MS)
  }

  languageChanged() {
    // Dedupe and price both depend on the language, so a change re-resolves.
    this.reloadFrame()
  }

  clearInput() {
    this.inputTarget.value = ""
    this.inputTarget.focus()
    this.inputChanged()
  }

  useClipboard() {
    if (!this.clipboardText) return

    this.inputTarget.value = this.clipboardText
    this.clipboardChipTarget.classList.add("hidden")
    this.inputChanged()
  }

  // Reloading the frame rather than fetching by hand: Turbo handles the request,
  // the swap and — importantly — cancelling whatever earlier request is still in
  // flight, so a slow resolve can't land on top of a newer one.
  reloadFrame() {
    const frame = document.getElementById("add_video_result")
    if (!frame) return

    const url = new URL(this.resolveUrlValue, window.location.origin)
    url.searchParams.set("q", this.inputTarget.value.trim())
    if (this.hasLanguageTarget) {
      url.searchParams.set("clip_language", this.languageTarget.value)
    }

    frame.src = url.toString()
  }

  updateChrome(value, isVideo) {
    this.clearTarget.classList.toggle("hidden", value === "")

    // The green confirmation replaces the hint rather than joining it, so the
    // line below the input never changes height.
    this.hintTarget.classList.toggle("hidden", isVideo)
    this.recognizedTarget.classList.toggle("hidden", !isVideo)
    this.recognizedTarget.classList.toggle("flex", isVideo)

    // Added on top of the hairline, not instead of it — see the utility's
    // definition in application.tailwind.css.
    this.fieldTarget.classList.toggle("app-inset-recognized", isVideo)
  }

  // Best-effort. iOS only hands the pasteboard to a web view after a user
  // gesture and shows a system prompt when it does, so on device this usually
  // rejects and the chip simply never appears — which is why it's an
  // enhancement and not the way anyone is expected to paste. Reading it without
  // the prompt would need a native bridge component around UIPasteboard.
  async offerClipboard() {
    if (!navigator.clipboard?.readText) return

    try {
      const text = (await navigator.clipboard.readText()).trim()
      if (!text || !VIDEO_PATTERN.test(text)) return

      this.clipboardText = text
      this.clipboardChipTarget.classList.remove("hidden")
      this.clipboardChipTarget.classList.add("flex")
    } catch {
      // Denied, or no permission without a gesture. Nothing to offer.
    }
  }
}
