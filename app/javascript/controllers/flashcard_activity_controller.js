import { Controller } from "@hotwired/stimulus"
import { stopPracticingHtml } from "../utils/stop_practicing_html"

export default class extends Controller {
  static targets = ["card", "completion", "progress"]
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
    const dirClass = this.l1RtlValue ? 'text-right' : 'text-left'

    const optionsHtml = card.options.map((opt, idx) => {
      const audioUrl = (card.options_audio_urls && card.options_audio_urls[idx]) ? card.options_audio_urls[idx] : ''
      const audioHtml = audioUrl
        ? `<audio preload="auto" data-option-audio-index="${idx}" src="${audioUrl}"></audio>`
        : ''

      return `
        <div class="option-item">
          <button data-action="click->flashcard-activity#selectOption" data-option-index="${idx}" class="option-button text-lg md:text-xl flex items-center justify-center px-6 py-4 bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-gray-50 rounded h-20">${opt}</button>
          ${audioHtml}
        </div>
      `
    }).join('')

    const containsLatin = /[A-Za-z]/.test(card.phrase_html)
    const phraseDir = containsLatin ? 'ltr' : (this.l1RtlValue ? 'rtl' : 'ltr')
    const phraseAlignClass = phraseDir === 'rtl' ? 'text-right' : 'text-left'

    this.cardTarget.setAttribute('dir', phraseDir)
    this.cardTarget.classList.remove('text-left', 'text-right')
    this.cardTarget.classList.add(phraseAlignClass)

    const displayedPhrase = card.phrase_html

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

    const optionAudio = selected.parentElement?.querySelector('audio')
    this.playOptionAudio(optionAudio)

    if (selected.textContent.trim() === card.correct) {
      selected.classList.add('correct')
      this.awardXp(2)
      setTimeout(() => this.nextCard(), 800)
    } else {
      selected.classList.add('incorrect')
      setTimeout(() => buttons.forEach(btn => btn.disabled = false), 800)
    }
  }

  nextCard() {
    this.index += 1
    this.renderCard()
  }

  playOptionAudio(audioElement) {
    if (!audioElement) return

    try {
      audioElement.currentTime = 0
      const playPromise = audioElement.play()
      if (playPromise && typeof playPromise.catch === 'function') {
        playPromise.catch(err => console.warn('Failed to play option audio', err))
      }
    } catch (err) {
      console.warn('Failed to play option audio', err)
    }
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
