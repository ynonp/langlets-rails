import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "completion", "progress"]
  static values = { cards: Array, l1Rtl: Boolean }

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
      return `<button data-action="click->flashcard-activity#selectOption" data-option-index="${idx}" data-option-audio="${audioUrl}" class="option-button text-lg md:text-xl flex items-center justify-center px-6 py-4 bg-gray-800 rounded h-20">${opt}</button>`
    }).join('')

    const containsLatin = /[A-Za-z]/.test(card.phrase_html)
    const phraseDir = containsLatin ? 'ltr' : (this.l1RtlValue ? 'rtl' : 'ltr')
    const phraseAlignClass = phraseDir === 'rtl' ? 'text-right' : 'text-left'

    this.cardTarget.setAttribute('dir', phraseDir)
    this.cardTarget.classList.remove('text-left', 'text-right')
    this.cardTarget.classList.add(phraseAlignClass)

    const displayedPhrase = card.phrase_html

    this.cardTarget.innerHTML = `
      <div class="mb-3 text-gray-300 text-lg md:text-xl">${card.translation}</div>
      <div dir="${phraseDir}" class="mb-6 text-white font-semibold text-2xl md:text-3xl ${phraseAlignClass}">${displayedPhrase}</div>
      <div class="mt-6 grid grid-cols-2 gap-4">${optionsHtml}</div>
    `
  }

  selectOption(e) {
    const idx = parseInt(e.target.dataset.optionIndex)
    const card = this.cardsValue[this.index]

    const buttons = Array.from(this.cardTarget.querySelectorAll('.option-button'))
    buttons.forEach(btn => btn.disabled = true)

    const selected = buttons[idx]
    const optionAudio = selected.dataset.optionAudio

    if (optionAudio) {
      try {
        const audio = new Audio(optionAudio)
        audio.play()
      } catch (err) {
        console.warn('Failed to play option audio', err)
      }
    }

    if (selected.textContent.trim() === card.correct) {
      selected.classList.add('correct')
      this.element.dispatchEvent(new CustomEvent('audio:correct', { bubbles: true }))
      this.awardXp(2)
      setTimeout(() => this.nextCard(), 800)
    } else {
      selected.classList.add('incorrect')
      this.element.dispatchEvent(new CustomEvent('audio:incorrect', { bubbles: true }))
      setTimeout(() => buttons.forEach(btn => btn.disabled = false), 800)
    }
  }

  nextCard() {
    this.index += 1
    this.renderCard()
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
