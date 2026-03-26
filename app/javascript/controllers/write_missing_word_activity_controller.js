import { Controller } from "@hotwired/stimulus"
import { stopPracticingHtml } from "../utils/stop_practicing_html"

export default class extends Controller {
  static targets = ["card", "completion", "progress", "translation", "sentence", "answer", "feedback", "checkButton", "stopPracticingContainer"]
  static values = { cards: Array, l1Rtl: Boolean, isReviewLesson: Boolean }

  connect() {
    this.currentIndex = 0
    this.totalXp = 0
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

    if (this.isReviewLessonValue && this.hasStopPracticingContainerTarget) {
      this.stopPracticingContainerTarget.innerHTML = stopPracticingHtml(card.id)
    }

    if (card.audio_url) {
      this.currentAudio = new Audio(card.audio_url)
    } else {
      this.currentAudio = null
    }

    // Focus the input
    setTimeout(() => this.answerTarget.focus(), 50)
  }

  checkAnswer() {
    const card = this.cardsValue[this.currentIndex]
    if (!card) return

    const userAnswer = this.answerTarget.value.trim()
    if (!userAnswer) return

    const correct = userAnswer.toLowerCase() === card.answer.toLowerCase()

    this.checkButtonTarget.disabled = true
    this.checkButtonTarget.classList.add("opacity-50")
    this.feedbackTarget.classList.remove("hidden")

    if (correct) {
      this.feedbackTarget.textContent = `✓ Correct! "${card.answer}"`
      this.feedbackTarget.className = "text-lg font-semibold mt-2 text-green-400"
      this.totalXp += 2
      this.dispatch("xp", { detail: { xp: 2 } })
      if (this.currentAudio) {
        this.currentAudio.play().catch(() => {})
      }
      setTimeout(() => this.nextCard(), 1200)
    } else {
      this.feedbackTarget.textContent = `✗ The answer is "${card.answer}". Try to remember it!`
      this.feedbackTarget.className = "text-lg font-semibold mt-2 text-red-400"
      setTimeout(() => this.nextCard(), 2000)
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
