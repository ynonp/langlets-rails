import { Controller } from "@hotwired/stimulus"
import { stopPracticingHtml } from "../utils/stop_practicing_html"

export default class extends Controller {
  static targets = ["card", "completion", "progress"]
  static values = { cards: Array, l1Rtl: Boolean, isReviewLesson: Boolean }

  connect() {
    this.index = 0
    this.correctAnswerAudio = null
    this.correctAnswerAudioUrl = null
    this.updateProgress()
    this.renderCard()
  }

  disconnect() {
    this.correctAnswerAudio?.pause()
    this.correctAnswerAudio = null
    this.correctAnswerAudioUrl = null
  }

  updateProgress() {
    if (!this.hasProgressTarget) return
    if (this.index >= this.cardsValue.length) {
      this.progressTarget.textContent = ''
    } else {
      this.progressTarget.textContent = `Question ${this.index + 1} of ${this.cardsValue.length}`
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
        <button data-action="click->flashcard-activity#selectOption" data-option-index="${idx}" class="option-button text-lg md:text-xl flex items-center justify-center px-6 py-4 bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-gray-50 rounded h-20">${opt}</button>
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
      `<span class="flashcard-answer-slot" data-flashcard-correct-answer aria-live="polite">________</span>`
    )

    this.cardTarget.innerHTML = `
      <div class="mb-3 text-gray-500 dark:text-gray-400 text-lg md:text-xl">${card.translation}</div>
      <div dir="${phraseDir}" class="mb-6 text-gray-900 dark:text-gray-50 font-semibold text-2xl md:text-3xl ${phraseAlignClass}">${displayedPhrase}</div>
      <div class="mt-6 grid grid-cols-2 gap-4">${optionsHtml}</div>
      ${this.isReviewLessonValue ? stopPracticingHtml(card.id) : ''}
    `
  }

  selectOption(e) {
    const selected = e.currentTarget
    const card = this.cardsValue[this.index]

    const buttons = Array.from(this.cardTarget.querySelectorAll('.option-button'))
    buttons.forEach(btn => btn.disabled = true)

    if (selected.textContent.trim() === card.correct) {
      selected.classList.add('correct')
      this.awardXp(2)
      this.playAudio(this.correctAnswerAudio).then(() => {
        this.revealCorrectAnswer(card.correct)
        setTimeout(() => this.nextCard(), 1400)
      })
    } else {
      selected.classList.add('incorrect')
      setTimeout(() => buttons.forEach(btn => btn.disabled = false), 800)
    }
  }

  revealCorrectAnswer(answer) {
    const answerSlot = this.cardTarget.querySelector('[data-flashcard-correct-answer]')
    if (!answerSlot) return

    answerSlot.textContent = answer
    answerSlot.classList.add('flashcard-answer-reveal')
  }

  preloadCorrectAudio(card) {
    const audioUrl = card?.audio_url
    if (!audioUrl || this.correctAnswerAudioUrl === audioUrl) return

    this.correctAnswerAudio?.pause()

    const audio = new Audio()
    audio.preload = 'auto'
    audio.src = audioUrl
    audio.load()
    this.correctAnswerAudio = audio
    this.correctAnswerAudioUrl = audioUrl
  }

  nextCard() {
    this.index += 1
    this.renderCard()
  }

  playAudio(audioElement) {
    if (!audioElement) return Promise.resolve()

    try {
      audioElement.currentTime = 0
      const playPromise = audioElement.play()
      if (playPromise && typeof playPromise.catch === 'function') {
        return playPromise.catch(err => console.warn('Failed to play flashcard audio', err))
      }
    } catch (err) {
      console.warn('Failed to play flashcard audio', err)
    }

    return Promise.resolve()
  }

  showCompletion() {
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
