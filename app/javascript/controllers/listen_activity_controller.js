import { Controller } from "@hotwired/stimulus"
import { animate } from "motion/mini"

export default class extends Controller {
  static targets = ["phrase", "phraseText", "translation", "choices", "wordSelection", "startInstruction", "completion", "stage"]
  static values = { wordTiming: Boolean }

  connect() {
    this.currentIndex = 0
    this.started = false
    this.pausedForIndex = null
    this.answered = new Set()
    this.showWindow(0, false)
  }

  start() {
    this.started = true
    this.startInstructionTarget.classList.add("invisible")
    this.showWindow(this.currentIndex, false)

    if (!this.wordTimingValue) this.presentQuestion(this.currentIndex)
  }

  progress({ detail: { at } }) {
    if (!this.started) return

    const nextIndex = this.phraseTargets.findLastIndex((phrase) => Number(phrase.dataset.start) <= at)
    if (nextIndex < 0) return

    if (!this.wordTimingValue) {
      this.progressByPhrase(nextIndex, at)
      return
    }

    if (nextIndex !== this.currentIndex) {
      this.currentIndex = nextIndex
      this.showWindow(nextIndex)
    }
    this.revealWords(this.phraseTargets[this.currentIndex], at)
  }

  progressByPhrase(nextIndex, at) {
    const current = this.phraseTargets[this.currentIndex]
    if (current && at >= Number(current.dataset.end) && this.hasUnansweredBlank(this.currentIndex)) {
      this.pauseForQuestion(this.currentIndex)
      return
    }

    if (nextIndex !== this.currentIndex) {
      this.currentIndex = nextIndex
      this.showWindow(nextIndex)
      this.presentQuestion(nextIndex)
    }
  }

  revealWords(phrase, at) {
    const missingStart = Number(phrase.dataset.missingStart)
    if (this.hasUnansweredBlank(this.currentIndex) && Number.isFinite(missingStart) && at >= missingStart) {
      this.pauseForQuestion(this.currentIndex)
    }

    let blocked = false
    phrase.querySelectorAll(".listen-word").forEach((word) => {
      const isMissing = word.dataset.missing === "true"
      if (isMissing && !this.answered.has(this.currentIndex)) blocked = true
      if (!blocked && Number(word.dataset.start) <= at) word.dataset.revealed = ""
    })
  }

  pauseForQuestion(index) {
    if (this.pausedForIndex === index) return
    this.pausedForIndex = index
    this.presentQuestion(index)
    this.element.dispatchEvent(new CustomEvent("listen-activity:pause-video"))
  }

  presentQuestion(index) {
    if (!this.hasUnansweredBlank(index)) return
    const phrase = this.phraseTargets[index]
    const translation = phrase.querySelector("[data-listen-activity-target='translation']")
    const choices = phrase.querySelector("template[data-listen-activity-target='choices']")
    if (translation) translation.classList.remove("hidden")
    if (!choices) return

    this.wordSelectionTarget.replaceChildren(choices.content.cloneNode(true))
    this.wordSelectionTarget.classList.remove("hidden")
    this.wordSelectionTarget.classList.add("flex")
  }

  selectWord(event) {
    const button = event.currentTarget
    const correct = button.dataset.correct === "true"
    button.classList.add(correct ? "is-correct" : "is-incorrect")
    setTimeout(() => button.classList.remove("is-correct", "is-incorrect"), 600)
    if (!correct) return

    const index = this.currentIndex
    const phrase = this.phraseTargets[index]
    phrase.querySelectorAll(".blank-line").forEach((blank) => {
      blank.textContent = blank.dataset.answer || button.dataset.word
      blank.classList.remove("blank-line")
      blank.dataset.revealed = ""
    })
    phrase.querySelector("[data-listen-activity-target='translation']")?.classList.add("hidden")
    this.wordSelectionTarget.classList.add("hidden")
    this.wordSelectionTarget.classList.remove("flex")
    this.answered.add(index)
    this.pausedForIndex = null
    this.awardXp(2)

    this.element.dispatchEvent(new CustomEvent("listen-activity:play-video"))
  }

  handleVideoEnd() {
    const finalIndex = this.phraseTargets.length - 1
    if (this.hasUnansweredBlank(finalIndex)) {
      this.pauseForQuestion(finalIndex)
    } else if (this.allQuestionsAnswered()) {
      this.complete()
    }
  }

  showWindow(index, animateExit = true) {
    this.phraseTargets.forEach((phrase, phraseIndex) => {
      const previousSlot = phrase.dataset.slot
      let slot = "hidden"
      if (phraseIndex === index) slot = "0"
      if (phraseIndex === index + 1) slot = "1"
      if (animateExit && phraseIndex === index - 1 && previousSlot === "0") slot = "exit"
      phrase.dataset.slot = slot
      phrase.toggleAttribute("data-active", phraseIndex === index)
      phrase.classList.toggle("bg-emerald-50", phraseIndex === index)
      phrase.classList.toggle("dark:bg-emerald-950/30", phraseIndex === index)
    })
  }

  hasUnansweredBlank(index) {
    const phrase = this.phraseTargets[index]
    return phrase?.dataset.hasMissing === "true" && !this.answered.has(index)
  }

  allQuestionsAnswered() {
    return this.phraseTargets.every((_, index) => !this.hasUnansweredBlank(index))
  }

  complete() {
    this.wordSelectionTarget.classList.add("hidden")
    this.stageTarget.classList.add("hidden")
    this.completionTarget.classList.remove("hidden")
    this.completionTarget.classList.add("flex")
    animate(this.completionTarget, { opacity: [0, 1], scale: [0.9, 1] }, { duration: 0.3, easing: "easeOut" })
    this.element.dispatchEvent(new CustomEvent("activity:completed", { bubbles: true }))
  }

  awardXp(amount) {
    const bar = document.getElementById("gamification-bar")
    const controller = bar && this.application.getControllerForElementAndIdentifier(bar, "progress-tracker")
    controller?.awardXp(amount)
  }
}
