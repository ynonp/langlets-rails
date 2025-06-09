import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "progressText", 
    "progressBar", 
    "phraseContainer", 
    "speakerButton", 
    "resultLine", 
    "wordBank", 
    "wordItem", 
    "continueButton", 
    "feedbackMessage", 
    "completionMessage"
  ]
  
  static values = {
    l1: String,
    totalPhrases: Number
  }

  connect() {
    this.currentPhraseIndex = 0
    this.draggedElement = null
    this.touchOffset = { x: 0, y: 0 }
  }

  handleDragStart(event) {
    this.draggedElement = event.target
    event.target.classList.add('dragging')
    event.dataTransfer.effectAllowed = 'move'
    event.dataTransfer.setData('text/html', event.target.outerHTML)
  }

  handleDragEnd(event) {
    event.target.classList.remove('dragging')
    this.draggedElement = null
  }

  handleDragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = 'move'
    event.currentTarget.classList.add('drag-over')
  }

  handleDragLeave(event) {
    event.currentTarget.classList.remove('drag-over')
  }

  handleDrop(event) {
    event.preventDefault()
    event.currentTarget.classList.remove('drag-over')
    
    if (!this.draggedElement) return

    const dropTarget = event.currentTarget
    const draggedElement = this.draggedElement

    // Move the element to the drop target
    dropTarget.appendChild(draggedElement)
  }

  // Touch event handlers for mobile support
  handleTouchStart(event) {
    event.preventDefault()
    this.draggedElement = event.target
    event.target.classList.add('dragging')
    
    const touch = event.touches[0]
    const rect = event.target.getBoundingClientRect()
    this.touchOffset = {
      x: touch.clientX - rect.left,
      y: touch.clientY - rect.top
    }
  }

  handleTouchMove(event) {
    if (!this.draggedElement) return
    event.preventDefault()
    
    const touch = event.touches[0]
    
    // Move the dragged element visually
    this.draggedElement.style.position = 'fixed'
    this.draggedElement.style.left = `${touch.clientX - this.touchOffset.x}px`
    this.draggedElement.style.top = `${touch.clientY - this.touchOffset.y}px`
    this.draggedElement.style.zIndex = '1000'
    this.draggedElement.style.pointerEvents = 'none'
    
    // Find element under touch point
    const elementBelow = document.elementFromPoint(touch.clientX, touch.clientY)
    
    // Remove drag-over class from all potential drop targets
    this.resultLineTargets.forEach(line => line.classList.remove('drag-over'))
    this.wordBankTargets.forEach(bank => bank.classList.remove('drag-over'))
    
    // Add drag-over class to valid drop target
    if (elementBelow) {
      const dropTarget = elementBelow.closest('[data-word-order-activity-target="resultLine"], [data-word-order-activity-target="wordBank"]')
      if (dropTarget) {
        dropTarget.classList.add('drag-over')
      }
    }
  }

  handleTouchEnd(event) {
    if (!this.draggedElement) return
    event.preventDefault()
    
    const touch = event.changedTouches[0]
    const elementBelow = document.elementFromPoint(touch.clientX, touch.clientY)
    
    // Reset element styles
    this.draggedElement.style.position = ''
    this.draggedElement.style.left = ''
    this.draggedElement.style.top = ''
    this.draggedElement.style.zIndex = ''
    this.draggedElement.style.pointerEvents = ''
    this.draggedElement.classList.remove('dragging')
    
    // Remove drag-over class from all targets
    this.resultLineTargets.forEach(line => line.classList.remove('drag-over'))
    this.wordBankTargets.forEach(bank => bank.classList.remove('drag-over'))
    
    // Find drop target and move element
    if (elementBelow) {
      const dropTarget = elementBelow.closest('[data-word-order-activity-target="resultLine"], [data-word-order-activity-target="wordBank"]')
      if (dropTarget && dropTarget !== this.draggedElement.parentElement) {
        dropTarget.appendChild(this.draggedElement)
      }
    }
    
    this.draggedElement = null
  }

  handleWordClick(event) {
    const wordItem = event.target
    const currentContainer = wordItem.parentElement

    // Determine the current phrase index
    const phraseIndex = this.getCurrentPhraseIndex()
    const resultLine = this.getResultLineForPhrase(phraseIndex)
    const wordBank = this.getWordBankForPhrase(phraseIndex)

    if (currentContainer === resultLine) {
      // Move from result line back to word bank
      wordBank.appendChild(wordItem)
    } else if (currentContainer === wordBank) {
      // Move from word bank to result line
      resultLine.appendChild(wordItem)
    }
  }

  getCurrentPhraseIndex() {
    const visibleContainer = this.phraseContainerTargets.find(container => 
      !container.classList.contains('hidden')
    )
    return visibleContainer ? parseInt(visibleContainer.dataset.index) : 0
  }

  getResultLineForPhrase(phraseIndex) {
    return this.resultLineTargets.find(line => 
      parseInt(line.dataset.phraseIndex) === phraseIndex
    )
  }

  getWordBankForPhrase(phraseIndex) {
    return this.wordBankTargets.find(bank => 
      parseInt(bank.dataset.phraseIndex) === phraseIndex
    )
  }

  checkAnswer(event) {
    const phraseIndex = parseInt(event.target.dataset.phraseIndex)
    const phraseContainer = this.phraseContainerTargets.find(container => 
      parseInt(container.dataset.index) === phraseIndex
    )
    const correctText = phraseContainer.dataset.correctText
    const resultLine = this.getResultLineForPhrase(phraseIndex)
    
    // Get the current order of words in the result line
    const wordsInResult = Array.from(resultLine.children).map(wordItem => 
      wordItem.dataset.wordText
    )
    const userAnswer = wordsInResult.join(' ')

    if (userAnswer.trim() === correctText.trim()) {
      this.showCorrectFeedback()
      setTimeout(() => {
        this.moveToNextPhrase()
      }, 1500)
    } else {
      this.showIncorrectFeedback()
      this.resetWordsToBank(phraseIndex)
    }
  }

  showCorrectFeedback() {
    const feedbackMessage = this.feedbackMessageTarget
    feedbackMessage.textContent = "Correct! Well done!"
    feedbackMessage.className = "mt-4 p-3 rounded-lg text-center text-lg font-medium correct-feedback"
    feedbackMessage.classList.remove('hidden')
    
    setTimeout(() => {
      feedbackMessage.classList.add('hidden')
    }, 1500)
  }

  showIncorrectFeedback() {
    const feedbackMessage = this.feedbackMessageTarget
    feedbackMessage.textContent = "Not quite right. Try again!"
    feedbackMessage.className = "mt-4 p-3 rounded-lg text-center text-lg font-medium incorrect-feedback"
    feedbackMessage.classList.remove('hidden')
    feedbackMessage.classList.add('animate-shake')
    
    setTimeout(() => {
      feedbackMessage.classList.add('hidden')
      feedbackMessage.classList.remove('animate-shake')
    }, 2000)
  }

  resetWordsToBank(phraseIndex) {
    const resultLine = this.getResultLineForPhrase(phraseIndex)
    const wordBank = this.getWordBankForPhrase(phraseIndex)
    
    // Move all words from result line back to word bank
    Array.from(resultLine.children).forEach(wordItem => {
      wordBank.appendChild(wordItem)
    })
  }

  moveToNextPhrase() {
    const currentContainer = this.phraseContainerTargets[this.currentPhraseIndex]
    currentContainer.classList.add('hidden')
    
    this.currentPhraseIndex++
    
    // Update progress
    const progress = ((this.currentPhraseIndex) / this.totalPhrasesValue) * 100
    this.progressBarTarget.style.width = `${progress}%`
    this.progressTextTarget.textContent = `Question ${this.currentPhraseIndex + 1} of ${this.totalPhrasesValue}`
    
    if (this.currentPhraseIndex < this.phraseContainerTargets.length) {
      // Show next phrase
      const nextContainer = this.phraseContainerTargets[this.currentPhraseIndex]
      nextContainer.classList.remove('hidden')
      nextContainer.classList.add('animate-fade-in')
    } else {
      // All phrases completed
      this.showCompletionMessage()
    }
  }

  showCompletionMessage() {
    this.progressTextTarget.textContent = `Completed ${this.totalPhrasesValue} of ${this.totalPhrasesValue}`
    this.progressBarTarget.style.width = '100%'
    this.completionMessageTarget.classList.remove('hidden')
    this.completionMessageTarget.classList.add('animate-fade-in')
  }
}
