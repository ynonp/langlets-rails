import { Controller } from "@hotwired/stimulus"
import { stopPracticingHtml } from "../utils/stop_practicing_html"
import { t } from "../utils/i18n"
import { reportActivityProgress } from "../utils/activity_progress"

function normalizeText(text) {
  if (!text) return ""

  return text
    .replace(/[\u064B-\u065F\u0670]/g, "")
    .replace(/[أإآ]/g, "ا")
    .replace(/ة/g, "ه")
    .replace(/ى/g, "ي")
    .replace(/ـ/g, "")
    .normalize("NFD")
    .replace(/[\u0300-\u036F\u1DC0-\u1DFF\u20D0-\u20FF]/g, "")
    .replace(/[\p{P}\p{S}]/gu, "")
    .replace(/\s+/g, " ").trim().toLowerCase()
}

export default class extends Controller {
  static targets = ["activityContent", "card", "completion", "completionTranslation", "progress", "sentence", "answer", "feedback", "checkButton", "stopPracticingContainer", "writeInterface", "hintOptions", "hintButton"]
  static values = { cards: Array, l1Rtl: Boolean, isReviewLesson: Boolean }

  connect() {
    this.currentIndex = 0
    this.renderCard()
  }

  renderCard() {
    const card = this.cardsValue[this.currentIndex]
    if (!card) {
      this.showCompletion()
      return
    }

    this.progressTarget.textContent = t("write_missing_word.question_of", { current: this.currentIndex + 1, total: this.cardsValue.length })
    reportActivityProgress(this.element, (this.currentIndex + 1) / this.cardsValue.length)
    this.configureVideo(card)
    this.renderSentence(card)
    this.preloadAudio(card)

    this.answerTarget.value = ""
    this.answerTarget.disabled = false
    this.checkButtonTarget.disabled = false
    this.checkButtonTarget.textContent = t("write_missing_word.check")
    this.feedbackTarget.classList.add("hidden")
    this.feedbackTarget.textContent = ""
    this.writeInterfaceTarget.classList.remove("hidden")
    this.hintOptionsTarget.classList.add("hidden")
    this.hintOptionsTarget.replaceChildren()
    this.hintButtonTarget.classList.toggle("hidden", !card.options || card.options.length < 2)

    if (this.hasStopPracticingContainerTarget) {
      this.stopPracticingContainerTarget.innerHTML = this.isReviewLessonValue ? stopPracticingHtml(card.id) : ""
    }
  }

  renderSentence(card) {
    const phrase = card.phrase_html || ""
    const phraseDir = /[A-Za-z]/.test(phrase) ? "ltr" : (this.l1RtlValue ? "rtl" : "ltr")
    this.cardTarget.dir = phraseDir
    this.cardTarget.classList.toggle("text-right", phraseDir === "rtl")
    this.cardTarget.classList.toggle("text-left", phraseDir !== "rtl")
    this.sentenceTarget.dir = phraseDir
    const [before, ...rest] = phrase.split("________")
    this.sentenceTarget.replaceChildren(document.createTextNode(before))
    if (rest.length === 0) return

    const wrapper = document.createElement("span")
    wrapper.className = "inline-flex flex-col items-center align-top leading-tight"
    const answer = document.createElement("span")
    answer.className = "block min-w-24 border-b-[3px] border-gray-500 dark:border-gray-400 leading-tight text-transparent"
    answer.dataset.writeMissingWordCorrectAnswer = ""
    answer.setAttribute("aria-live", "polite")
    answer.textContent = "________"
    const gloss = document.createElement("span")
    gloss.className = "mt-2 text-gray-500 dark:text-gray-400 text-sm italic font-normal leading-5 [direction:auto]"
    gloss.textContent = card.translation || ""
    wrapper.append(answer, gloss)
    this.sentenceTarget.append(wrapper, document.createTextNode(rest.join("________")))
  }

  configureVideo(card) {
    this.element.dataset.segmentStart = card.segment_start ?? ""
    this.element.dataset.segmentEnd = card.segment_end ?? ""
    this.dispatch("card-change", {
      bubbles: true,
      detail: {
        videoId: card.video_id,
        provider: card.video_provider,
        segmentStart: card.segment_start,
        segmentEnd: card.segment_end,
      }
    })
  }

  showHint() {
    const card = this.cardsValue[this.currentIndex]
    if (!card?.options || card.options.length < 2) return

    this.writeInterfaceTarget.classList.add("hidden")
    this.hintOptionsTarget.replaceChildren(...card.options.map(option => {
      const button = document.createElement("button")
      button.type = "button"
      button.dataset.action = "click->write-missing-word-activity#selectHintOption"
      button.className = "hint-option w-full min-h-[58px] flex items-center justify-center px-2 py-3.5 bg-white dark:bg-gray-800 border border-gray-200 dark:border-white/10 text-gray-900 dark:text-gray-100 rounded-lg text-sm sm:text-base font-medium"
      button.textContent = option
      return button
    }))
    this.hintOptionsTarget.classList.remove("hidden")
  }

  selectHintOption(event) {
    const card = this.cardsValue[this.currentIndex]
    if (!card) return

    const selected = event.currentTarget
    if (normalizeText(selected.textContent) === normalizeText(card.correct)) {
      this.hintOptionsTarget.querySelectorAll(".hint-option").forEach(button => button.disabled = true)
      selected.classList.add("bg-emerald-500/15", "border-emerald-500", "text-emerald-600", "dark:text-emerald-300")
      this.completeCard(card, 1)
    } else {
      selected.disabled = true
      selected.classList.add("bg-red-500/10", "border-red-500", "text-red-600", "dark:text-red-300")
      this.feedbackTarget.textContent = t("write_missing_word.wrong_try_again")
      this.feedbackTarget.className = "text-base font-semibold mt-3 text-red-600 dark:text-red-400"
    }
  }

  checkAnswer() {
    const card = this.cardsValue[this.currentIndex]
    if (!card || this.answerTarget.disabled) return

    const userAnswer = this.answerTarget.value.trim()
    if (!userAnswer) return

    this.answerTarget.disabled = true
    this.checkButtonTarget.disabled = true
    if (normalizeText(userAnswer) === normalizeText(card.correct)) {
      this.completeCard(card, 2)
    } else {
      this.feedbackTarget.textContent = t("write_missing_word.wrong_try_again")
      this.feedbackTarget.className = "text-base font-semibold mt-3 text-red-600 dark:text-red-400"
      this.answerTarget.disabled = false
      this.checkButtonTarget.disabled = false
      this.answerTarget.select()
    }
  }

  completeCard(card, xp) {
    this.feedbackTarget.classList.add("hidden")
    this.awardXp(xp)
    this.playCardAudio(card)
    this.revealCorrectAnswer(card.correct)
    this.showCardCompletion(card)
  }

  revealCorrectAnswer(answer) {
    const slot = this.sentenceTarget.querySelector("[data-write-missing-word-correct-answer]")
    if (!slot) return
    slot.textContent = answer
    slot.classList.remove("text-transparent", "border-gray-500", "dark:border-gray-400")
    slot.classList.add("text-emerald-600", "dark:text-emerald-300", "border-transparent", "flashcard-answer-reveal")
  }

  showCardCompletion(card) {
    this.completionTranslationTarget.textContent = card.phrase_l2 || ""
    this.completionTarget.classList.remove("hidden")
    if (this.currentIndex === this.cardsValue.length - 1) {
      this.element.dispatchEvent(new CustomEvent("audio:complete", { bubbles: true }))
      this.element.dispatchEvent(new CustomEvent("activity:completed", { bubbles: true }))
    }
  }

  continue(event) {
    if (this.currentIndex === this.cardsValue.length - 1) return
    event.preventDefault()
    this.completionTarget.classList.add("hidden")
    this.currentIndex += 1
    this.renderCard()
  }

  preloadAudio(card) {
    if (!card.audio_url) return
    this.element.dispatchEvent(new CustomEvent("audio-cache:preload", {
      bubbles: true, detail: { urls: [card.audio_url] }
    }))
  }

  playCardAudio(card) {
    if (!card.audio_url) return
    this.element.dispatchEvent(new CustomEvent("audio-cache:play", {
      bubbles: true, detail: { url: card.audio_url }
    }))
  }

  awardXp(amount) {
    const gamificationBar = document.getElementById("gamification-bar")
    if (!gamificationBar?.dataset.controller) return
    const controller = this.application.getControllerForElementAndIdentifier(gamificationBar, "progress-tracker")
    controller?.awardXp(amount)
  }

  showCompletion() {
    this.activityContentTarget.classList.add("hidden")
    this.completionTranslationTarget.textContent = ""
    this.completionTarget.classList.remove("hidden")
    this.element.dispatchEvent(new CustomEvent("audio:complete", { bubbles: true }))
    this.element.dispatchEvent(new CustomEvent("activity:completed", { bubbles: true }))
  }
}
