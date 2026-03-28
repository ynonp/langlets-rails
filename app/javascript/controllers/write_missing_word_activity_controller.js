import { Controller } from "@hotwired/stimulus"
import { stopPracticingHtml } from "../utils/stop_practicing_html"

function normalizeText(text) {
  if (!text) return ""

  let result = text

  // Arabic-specific normalization
  result = result
    .replace(/[\u064B-\u065F\u0670]/g, "")  // Arabic diacritics
    .replace(/[أإآ]/g, "ا")                  // alef variants
    .replace(/ة/g, "ه")                      // taa marbuta
    .replace(/ى/g, "ي")                      // alef maqsura
    .replace(/ـ/g, "")                        // tatweel (stretching)

  // NFD decompose to isolate combining characters (handles Latin, Greek, Hebrew, etc.)
  result = result.normalize("NFD")
    .replace(/[\u0300-\u036F\u1DC0-\u1DFF\u20D0-\u20FF]/g, "")

  // Remove punctuation and symbols (Unicode-aware)
  result = result.replace(/[\p{P}\p{S}]/gu, "")

  return result.replace(/\s+/g, " ").trim().toLowerCase()
}

export default class extends Controller {
  static targets = ["card", "completion", "progress", "translation", "sentence", "answer", "feedback", "checkButton", "stopPracticingContainer", "writeInterface", "hintOptions", "hintButton"]
  static values = { cards: Array, l1Rtl: Boolean, isReviewLesson: Boolean }

  connect() {
    this.currentIndex = 0
    this.totalXp = 0
    this.awaitingContinue = false
    if (this.hasCardsValue && this.cardsValue.length > 0) {
      this.renderCard()
    } else {
      this.showCompletion()
    }
  }

  renderCard() {
    const card = this.cardsValue[this.currentIndex]
    if (!card) {
      this.showCompletion()
      return
    }

    this.progressTarget.textContent = `Question ${this.currentIndex + 1} of ${this.cardsValue.length}`
    this.translationTarget.textContent = `"${card.translation}"`
    this.sentenceTarget.textContent = card.phrase_with_blank
    this.answerTarget.value = ""
    this.feedbackTarget.classList.add("hidden")
    this.feedbackTarget.textContent = ""
    this.checkButtonTarget.disabled = false
    this.checkButtonTarget.classList.remove("opacity-50")
    this.checkButtonTarget.textContent = "Check"
    this.awaitingContinue = false

    // Reset to write mode
    this.writeInterfaceTarget.classList.remove("hidden")
    this.hintOptionsTarget.classList.add("hidden")
    this.hintOptionsTarget.innerHTML = ""

    // Show hint button only when there are multiple choice options available
    if (card.options && card.options.length >= 2) {
      this.hintButtonTarget.classList.remove("hidden")
    } else {
      this.hintButtonTarget.classList.add("hidden")
    }

    if (this.isReviewLessonValue && this.hasStopPracticingContainerTarget) {
      this.stopPracticingContainerTarget.innerHTML = stopPracticingHtml(card.id)
    }

    if (card.audio_url) {
      this.currentAudio = new Audio(card.audio_url)
    } else {
      this.currentAudio = null
    }

    setTimeout(() => this.answerTarget.focus(), 50)
  }

  showHint() {
    const card = this.cardsValue[this.currentIndex]
    if (!card || !card.options) return

    this.writeInterfaceTarget.classList.add("hidden")

    this.hintOptionsTarget.innerHTML = card.options.map(opt => `
      <button
        data-action="click->write-missing-word-activity#selectHintOption"
        data-option="${opt}"
        class="hint-option px-4 py-4 bg-gray-800 hover:bg-gray-700 border-2 border-gray-600 rounded-lg text-white text-base sm:text-lg font-medium transition-colors duration-200 text-center">
        ${opt}
      </button>
    `).join("")

    this.hintOptionsTarget.classList.remove("hidden")
  }

  selectHintOption(event) {
    const card = this.cardsValue[this.currentIndex]
    if (!card) return

    const selected = event.currentTarget
    const allOptions = this.hintOptionsTarget.querySelectorAll(".hint-option")
    allOptions.forEach(btn => btn.disabled = true)

    const isCorrect = normalizeText(selected.dataset.option) === normalizeText(card.answer)

    this.feedbackTarget.classList.remove("hidden")

    if (isCorrect) {
      selected.classList.add("border-green-500", "bg-green-900")
      this.feedbackTarget.textContent = `✓ Correct! "${card.answer}"`
      this.feedbackTarget.className = "text-base sm:text-lg font-semibold mt-2 text-green-400"
      this.totalXp += 1
      this.dispatch("xp", { detail: { xp: 1 } })
      if (this.currentAudio) this.currentAudio.play().catch(() => {})
      setTimeout(() => this.nextCard(), 1000)
    } else {
      selected.classList.add("border-red-500", "bg-red-900")
      // Re-enable the other options so the user can try again
      allOptions.forEach(btn => {
        if (btn !== selected) btn.disabled = false
      })
      this.feedbackTarget.textContent = `✗ Wrong — try again!`
      this.feedbackTarget.className = "text-base sm:text-lg font-semibold mt-2 text-red-400"
    }
  }

  checkAnswer() {
    if (this.awaitingContinue) {
      this.awaitingContinue = false
      this.nextCard()
      return
    }

    const card = this.cardsValue[this.currentIndex]
    if (!card) return

    const userAnswer = this.answerTarget.value.trim()
    if (!userAnswer) return

    const correct = normalizeText(userAnswer) === normalizeText(card.answer)

    this.checkButtonTarget.disabled = true
    this.checkButtonTarget.classList.add("opacity-50")
    this.feedbackTarget.classList.remove("hidden")

    if (correct) {
      this.feedbackTarget.textContent = `✓ Correct! "${card.answer}"`
      this.feedbackTarget.className = "text-base sm:text-lg font-semibold mt-2 text-green-400"
      this.totalXp += 2
      this.dispatch("xp", { detail: { xp: 2 } })
      if (this.currentAudio) {
        this.currentAudio.play().catch(() => {})
      }
      setTimeout(() => this.nextCard(), 1200)
    } else {
      this.feedbackTarget.textContent = `✗ The answer is "${card.answer}". Try to remember it!`
      this.feedbackTarget.className = "text-base sm:text-lg font-semibold mt-2 text-red-400"
      this.awaitingContinue = true
      this.checkButtonTarget.textContent = "Continue →"
      this.checkButtonTarget.disabled = false
      this.checkButtonTarget.classList.remove("opacity-50")
    }
  }

  nextCard() {
    this.currentIndex++
    if (this.currentIndex >= this.cardsValue.length) {
      this.showCompletion()
    } else {
      this.renderCard()
    }
  }

  showCompletion() {
    this.cardTarget.classList.add("hidden")
    this.completionTarget.classList.remove("hidden")
    this.dispatch("completed", { detail: { xp: this.totalXp }, bubbles: true })
  }
}

