import { Controller } from "@hotwired/stimulus"
import { stopPracticingHtml } from "../utils/stop_practicing_html"
import { t } from "../utils/i18n"

export default class extends Controller {
  static targets = ["activityContent", "card", "completion", "progress", "progressBar", "progressTrack"]
  static values = { cards: Array, l1Rtl: Boolean, isReviewLesson: Boolean }

  connect() {
    this.index = 0
    this.updateProgress()
    this.renderCard()
  }

  updateProgress() {
    if (!this.hasProgressTarget) return
    if (this.index >= this.cardsValue.length) {
      this.progressTarget.textContent = ''
      if (this.hasProgressBarTarget) this.progressBarTarget.style.width = '100%'
    } else {
      this.progressTarget.textContent = t("flashcard.question_of", { current: this.index + 1, total: this.cardsValue.length })
      if (this.hasProgressBarTarget) {
        this.progressBarTarget.style.width = `${(this.index + 1) / this.cardsValue.length * 100}%`
      }
      if (this.hasProgressTrackTarget) {
        this.progressTrackTarget.setAttribute('aria-valuenow', this.index + 1)
      }
    }
  }

  renderCard() {
    this.updateProgress()

    if (this.index >= this.cardsValue.length) {
      this.showCompletion()
      return
    }

    const card = this.cardsValue[this.index]
    this.preloadCorrectAudio(card)

    const optionsHtml = card.options.map((opt, idx) => {
      return `
        <button data-action="click->flashcard-activity#selectOption" data-option-index="${idx}" class="option-button w-full min-h-[58px] flex items-center justify-center px-2 py-3.5 bg-white dark:bg-gray-800 border border-gray-200 dark:border-white/10 text-gray-900 dark:text-gray-100 rounded-lg text-sm sm:text-base font-medium transition-colors cursor-pointer disabled:cursor-default">${opt}</button>
      `
    }).join('')

    const containsLatin = /[A-Za-z]/.test(card.phrase_html)
    const phraseDir = containsLatin ? 'ltr' : (this.l1RtlValue ? 'rtl' : 'ltr')
    const phraseAlignClass = phraseDir === 'rtl' ? 'text-right' : 'text-left'

    this.cardTarget.setAttribute('dir', phraseDir)
    this.cardTarget.classList.remove('text-left', 'text-right')
    this.cardTarget.classList.add(phraseAlignClass)

    const displayedPhrase = card.phrase_html.replace(
      "________",
      `<span class="inline-flex flex-col items-center align-top leading-tight">
        <span class="block min-w-24 border-b-[3px] border-gray-500 dark:border-gray-400 leading-tight text-transparent" data-flashcard-correct-answer aria-live="polite">________</span>
        <span class="mt-2 text-gray-500 dark:text-gray-400 text-sm italic font-normal leading-5 [direction:auto]">${card.translation}</span>
      </span>`
    )

    this.cardTarget.innerHTML = `
      <div class="flex min-h-[180px] items-center justify-center py-8 text-center">
        <div>
          <div dir="${phraseDir}" class="text-gray-900 dark:text-gray-50 font-medium text-2xl sm:text-[28px] leading-relaxed ${phraseAlignClass}">${displayedPhrase}</div>
        </div>
      </div>
      <div class="grid grid-cols-2 gap-2.5">${optionsHtml}</div>
      ${this.isReviewLessonValue ? stopPracticingHtml(card.id) : ''}
    `
  }

  selectOption(e) {
    const selected = e.currentTarget
    const card = this.cardsValue[this.index]

    const buttons = Array.from(this.cardTarget.querySelectorAll('.option-button'))
    buttons.forEach(btn => btn.disabled = true)

    if (selected.textContent.trim() === card.correct) {
      selected.classList.add('bg-emerald-500/15', 'border-emerald-500', 'text-emerald-600', 'dark:text-emerald-300')
      this.awardXp(2)
      this.playCardAudio(card)
      this.revealCorrectAnswer(card.correct)
      setTimeout(() => this.nextCard(), 1400)
    } else {
      selected.classList.add('bg-red-500/10', 'border-red-500', 'text-red-600', 'dark:text-red-300')
      setTimeout(() => buttons.forEach(btn => btn.disabled = false), 800)
    }
  }

  revealCorrectAnswer(answer) {
    const answerSlot = this.cardTarget.querySelector('[data-flashcard-correct-answer]')
    if (!answerSlot) return

    answerSlot.textContent = answer
    answerSlot.classList.remove('text-transparent', 'border-gray-500', 'dark:border-gray-400')
    answerSlot.classList.add('text-emerald-600', 'dark:text-emerald-300', 'border-transparent', 'flashcard-answer-reveal')
  }

  preloadCorrectAudio(card) {
    const audioUrl = card?.audio_url
    if (!audioUrl) return

    this.element.dispatchEvent(new CustomEvent('audio-cache:preload', {
      bubbles: true,
      detail: { urls: [audioUrl] }
    }))
  }

  playCardAudio(card) {
    const audioUrl = card?.audio_url
    if (!audioUrl) return

    this.element.dispatchEvent(new CustomEvent('audio-cache:play', {
      bubbles: true,
      detail: { url: audioUrl }
    }))
  }

  nextCard() {
    this.index += 1
    this.renderCard()
  }

  showCompletion() {
    this.activityContentTarget.classList.add('hidden')
    this.completionTarget.classList.remove('hidden')
    this.element.dispatchEvent(new CustomEvent('audio:complete', { bubbles: true }))
    this.element.dispatchEvent(new CustomEvent('activity:completed', { bubbles: true }))
  }

  awardXp(amount) {
    const gamificationBar = document.getElementById('gamification-bar');
    if (gamificationBar && gamificationBar.dataset.controller) {
      const controller = this.application.getControllerForElementAndIdentifier(gamificationBar, 'progress-tracker');
      if (controller) {
        controller.awardXp(amount);
      }
    }
  }
}
