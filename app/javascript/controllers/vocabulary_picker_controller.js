import { Controller } from "@hotwired/stimulus"

// The Vocabulary tab's "Add a word" screen.
//
// A saved word is a span inside a phrase, so this controller's whole job is to
// turn the sentence the user typed into tappable words and record which of them
// they picked. A pick is a *range*, because plenty of vocabulary is more than
// one word — "me souviens", "darse prisa", "No time left". The indexes it
// reports are whitespace-token indexes into the sentence, and the server
// re-splits the same way — see PhraseTokenUser.create_custom!, which also normalises
// the whitespace so the two sides agree on what "token 3" means.
//
// There are two ways to grow a pick, because one of them has to work on a
// phone and one of them has to work without a pointer at all:
//
//   * Tap a word next to the current pick and it extends to include it. This is
//     the discoverable path, it is what people try first, and it is the only
//     one reachable from a keyboard (the words are real buttons, so Tab + Enter
//     drives it).
//   * Press and drag across several words. Faster with a mouse, and the thing
//     the copy used to promise on its own.
export default class extends Controller {
  static targets = [
    "composer", "sentence", "savePhraseButton", "editButton",
    "picker", "tokens", "hint", "pickedWord",
    "translation", "translationField",
    "tokenStart", "tokenEnd", "wordField", "submitButton"
  ]

  // The word buttons are built here rather than server-rendered, so their
  // styling has to come in from the view. Values rather than constants because
  // the native and web surfaces draw the same picker in two palettes.
  static values = { tokenClass: String, tokenActiveClass: String }

  connect() {
    this.words = []
    this.start = null
    this.end = null
    this.dragging = false
    this.moved = false
    this.pointerId = null
    this.sentenceChanged()
    // A re-render after a failed save arrives with the sentence already filled
    // in; go straight back to the picker rather than making them save it again.
    // Same threshold as savePhrase, so the two never disagree about whether a
    // given sentence is pickable.
    if (this.tokenize().length >= 1) this.savePhrase()
  }

  sentenceChanged() {
    this.savePhraseButtonTarget.disabled = this.tokenize().length < 1
  }

  tokenize() {
    return this.sentenceTarget.value.trim().split(/\s+/).filter(Boolean)
  }

  savePhrase() {
    this.words = this.tokenize()
    if (this.words.length < 1) return

    // Normalise here too, so what the user picks from is exactly the text the
    // server will store and index into.
    this.sentenceTarget.value = this.words.join(" ")
    this.composerTarget.classList.add("hidden")
    this.pickerTarget.classList.remove("hidden")
    this.editButtonTarget.classList.remove("hidden")
    this.renderTokens()
    this.refresh()
  }

  editPhrase() {
    this.composerTarget.classList.remove("hidden")
    this.pickerTarget.classList.add("hidden")
    this.editButtonTarget.classList.add("hidden")
    this.clearPick()
    this.refresh()
  }

  renderTokens() {
    this.tokensTarget.replaceChildren(...this.words.map((word, index) => {
      const button = document.createElement("button")
      button.type = "button"
      button.textContent = word
      button.dataset.index = String(index)
      // No pointerenter here: for touch input the pointer is implicitly
      // captured by whichever element received pointerdown, so enter/leave
      // never fire on the words a finger drags over. Dragging is hit-tested
      // from pointermove instead — see dragOver.
      button.dataset.action = [
        "pointerdown->vocabulary-picker#startDrag",
        "click->vocabulary-picker#pick"
      ].join(" ")
      return button
    }))
    this.paintTokens()
  }

  // pointerdown only *arms* a drag. It deliberately does not change the pick,
  // so that a plain tap still reaches `pick` below with the previous selection
  // intact — which is what makes tapping an adjacent word extend rather than
  // replace.
  startDrag(event) {
    this.dragging = true
    this.moved = false
    this.pointerId = event.pointerId
    this.anchor = this.indexOf(event)
    // Touch captures the pointer to this button; release it so the hit-testing
    // in dragOver sees the words underneath the finger.
    event.currentTarget.releasePointerCapture?.(event.pointerId)
  }

  dragOver(event) {
    if (!this.dragging || event.pointerId !== this.pointerId) return

    const index = this.indexAtPoint(event.clientX, event.clientY)
    if (index === null || (this.moved && index === this.end)) return
    // Only once the pointer has actually reached another word is this a drag
    // rather than a tap; below that threshold `pick` still owns the gesture.
    if (!this.moved && index === this.anchor) return

    this.moved = true
    this.start = this.anchor
    this.end = index
    this.paintTokens()
    this.refresh()
  }

  endDrag() {
    this.dragging = false
    this.pointerId = null
  }

  indexAtPoint(x, y) {
    const element = document.elementFromPoint(x, y)?.closest("[data-index]")
    if (!element || !this.tokensTarget.contains(element)) return null

    return Number(element.dataset.index)
  }

  // A tap, or Enter/Space on a focused word. Grows the pick when the word sits
  // next to it, collapses a compound when the word is inside it, and otherwise
  // starts a new pick — so "wrong word" costs one tap, not an undo.
  pick(event) {
    if (this.moved) return

    const index = this.indexOf(event)
    const range = this.range

    if (range === null || index < range[0] - 1 || index > range[1] + 1) {
      this.start = this.end = index
    } else if (index >= range[0] && index <= range[1]) {
      this.start = this.end = index
    } else if (index === range[0] - 1) {
      this.start = index
      this.end = range[1]
    } else {
      this.start = range[0]
      this.end = index
    }

    this.paintTokens()
    this.refresh()
  }

  indexOf(event) {
    return Number(event.currentTarget.dataset.index)
  }

  clearPick() {
    this.start = this.end = null
    this.paintTokens()
  }

  get range() {
    if (this.start === null || this.end === null) return null
    return [ Math.min(this.start, this.end), Math.max(this.start, this.end) ]
  }

  paintTokens() {
    const range = this.range
    this.tokensTarget.querySelectorAll("button").forEach((button, index) => {
      const active = range !== null && index >= range[0] && index <= range[1]
      button.className = active ? this.tokenActiveClassValue : this.tokenClassValue
      button.setAttribute("aria-pressed", String(active))
    })
  }

  // The picked span with surrounding punctuation trimmed — "quick," saves as
  // "quick". Kept in step with PhraseTokenUser.create_custom!, which trims the same
  // way on the authoritative side.
  get pickedText() {
    const range = this.range
    if (range === null) return ""
    return this.words.slice(range[0], range[1] + 1).join(" ")
      .replace(/^[^\p{L}\p{N}]+/u, "").replace(/[^\p{L}\p{N}]+$/u, "")
  }

  refresh() {
    const range = this.range
    const word = this.pickedText

    this.tokenStartTarget.value = range === null ? "" : String(range[0])
    this.tokenEndTarget.value = range === null ? "" : String(range[1])
    this.wordFieldTarget.value = word

    this.translationTarget.classList.toggle("hidden", word === "")
    this.pickedWordTarget.textContent = word
    this.hintTarget.textContent = range === null
      ? this.hintTarget.dataset.emptyHint || this.hintTarget.textContent
      : this.hintTarget.dataset.pickedHint || this.hintTarget.textContent

    this.submitButtonTarget.disabled = word === "" || this.translationFieldTarget.value.trim() === ""
  }
}
