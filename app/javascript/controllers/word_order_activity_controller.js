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
    this.setupDragAndDrop()
  }

  setupDragAndDrop() {
    // Add drag event listeners to all word items
    this.wordItemTargets.forEach(wordItem => {
      wordItem.addEventListener('dragstart', this.handleDragStart.bind(this))
      wordItem.addEventListener('dragend', this.handleDragEnd.bind(this))
    })

    // Add drop event listeners to result lines
    this.resultLineTargets.forEach(resultLine => {
      resultLine.addEventListener('dragover', this.handleDragOver.bind(this))
      resultLine.addEventListener('drop', this.handleDrop.bind(this))
      resultLine.addEventListener('dragleave', this.handleDragLeave.bind(this))
    })

    // Add drop event listeners to word banks (for returning words)
    this.wordBankTargets.forEach(wordBank => {
      wordBank.addEventListener('dragover', this.handleDragOver.bind(this))
      wordBank.addEventListener('drop', this.handleDrop.bind(this))
      wordBank.addEventListener('dragleave', this.handleDragLeave.bind(this))
    })
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
