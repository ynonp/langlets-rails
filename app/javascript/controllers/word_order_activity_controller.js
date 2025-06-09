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
    "completionMessage",
    "tokenSlot"
  ]
  
  static values = {
    l1: String,
    totalPhrases: Number
  }

  connect() {
    this.currentPhraseIndex = 0
    this.draggedElement = null
    this.touchOffset = { x: 0, y: 0 }
    this.audioElement = null
    this.touchStartTime = null
    this.touchStartPosition = null
    this.isDragging = false
  }

  // Audio playback for tokens
  playTokenAudio(event) {
    event.stopPropagation() // Prevent triggering word click
    const audioUrl = event.currentTarget.dataset.audioUrl
    if (audioUrl) {
      if (this.audioElement) {
        this.audioElement.pause()
      }
      this.audioElement = new Audio(audioUrl)
      this.audioElement.play().catch(error => {
        console.warn('Audio playback failed:', error)
      })
    }
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

    // Check if dropping on word bank
    if (dropTarget.dataset.wordOrderActivityTarget === 'wordBank') {
      // Remove from slot if it was in one
      if (draggedElement.classList.contains('in-slot')) {
        const currentSlot = draggedElement.closest('[data-word-order-activity-target="tokenSlot"]')
        if (currentSlot) {
          currentSlot.classList.remove('filled')
        }
        draggedElement.classList.remove('in-slot')
      }
      
      // Find the insertion point based on drop position
      const insertionPoint = this.findInsertionPoint(dropTarget, event.clientX, event.clientY)
      if (insertionPoint) {
        dropTarget.insertBefore(draggedElement, insertionPoint)
      } else {
        dropTarget.appendChild(draggedElement)
      }
    }
    // Note: Token slot drops are handled by handleSlotDrop
  }
  handleSlotDragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = 'move'
    event.currentTarget.classList.add('drag-over')
  }

  handleSlotDragLeave(event) {
    event.currentTarget.classList.remove('drag-over')
  }

  handleSlotDrop(event) {
    event.preventDefault()
    event.currentTarget.classList.remove('drag-over')
    
    if (!this.draggedElement) return

    const tokenSlot = event.currentTarget
    const draggedElement = this.draggedElement

    // Allow dropping in any available slot
    if (!tokenSlot.classList.contains('filled')) {
      // Clear the slot first
      this.clearTokenSlot(tokenSlot)
      
      // Move the token to the slot
      tokenSlot.appendChild(draggedElement)
      tokenSlot.classList.add('filled')
      
      // Update word item styling for being in a slot
      draggedElement.classList.add('in-slot')
    } else {
      // Slot is filled - return to word bank
      const phraseIndex = this.getCurrentPhraseIndex()
      const wordBank = this.getWordBankForPhrase(phraseIndex)
      wordBank.appendChild(draggedElement)
    }
  }

  clearTokenSlot(tokenSlot) {
    // If slot already has a token, move it back to word bank
    const existingToken = tokenSlot.querySelector('[data-word-order-activity-target="wordItem"]')
    if (existingToken) {
      const phraseIndex = this.getCurrentPhraseIndex()
      const wordBank = this.getWordBankForPhrase(phraseIndex)
      existingToken.classList.remove('in-slot')
      wordBank.appendChild(existingToken)
    }
    tokenSlot.classList.remove('filled')
  }

  // Touch event handlers for mobile support
  handleTouchStart(event) {
    this.touchStartTime = Date.now()
    this.touchStartPosition = {
      x: event.touches[0].clientX,
      y: event.touches[0].clientY
    }
    this.isDragging = false
    
    // Don't prevent default immediately - let it potentially become a click
    this.draggedElement = event.target
    
    const touch = event.touches[0]
    const rect = event.target.getBoundingClientRect()
    this.touchOffset = {
      x: touch.clientX - rect.left,
      y: touch.clientY - rect.top
    }
  }

  handleTouchMove(event) {
    if (!this.draggedElement) return
    
    const touch = event.touches[0]
    const currentPosition = {
      x: touch.clientX,
      y: touch.clientY
    }
    
    // Calculate distance moved
    const deltaX = Math.abs(currentPosition.x - this.touchStartPosition.x)
    const deltaY = Math.abs(currentPosition.y - this.touchStartPosition.y)
    const distance = Math.sqrt(deltaX * deltaX + deltaY * deltaY)
    
    // If moved more than 10px, start dragging
    if (distance > 10 && !this.isDragging) {
      this.isDragging = true
      this.draggedElement.classList.add('dragging')
      event.preventDefault() // Now prevent default since we're dragging
    }
    
    if (this.isDragging) {
      event.preventDefault()
      
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
      this.tokenSlotTargets.forEach(slot => slot.classList.remove('drag-over'))
      
      // Add drag-over class to valid drop target
      if (elementBelow) {
        const dropTarget = elementBelow.closest('[data-word-order-activity-target="tokenSlot"], [data-word-order-activity-target="wordBank"]')
        if (dropTarget) {
          dropTarget.classList.add('drag-over')
        }
      }
    }
  }

  handleTouchEnd(event) {
    if (!this.draggedElement) return
    
    const touchDuration = Date.now() - this.touchStartTime
    
    // If it was a quick tap (less than 200ms) and no dragging occurred, let click event fire
    if (touchDuration < 200 && !this.isDragging) {
      // Reset and let the click event handle it
      this.draggedElement.classList.remove('dragging')
      this.draggedElement = null
      this.isDragging = false
      return // Don't prevent default, allow click
    }
    
    event.preventDefault()
    
    // Handle drag end
    if (this.isDragging) {
      const touch = event.changedTouches[0]
      const elementBelow = document.elementFromPoint(touch.clientX, touch.clientY)
      
      // Reset element styles
      this.draggedElement.style.position = ''
      this.draggedElement.style.left = ''
      this.draggedElement.style.top = ''
      this.draggedElement.style.zIndex = ''
      this.draggedElement.style.pointerEvents = ''
      
      // Remove drag-over class from all targets
      this.resultLineTargets.forEach(line => line.classList.remove('drag-over'))
      this.wordBankTargets.forEach(bank => bank.classList.remove('drag-over'))
      this.tokenSlotTargets.forEach(slot => slot.classList.remove('drag-over'))
      
      // Find drop target and move element
      if (elementBelow) {
        const tokenSlot = elementBelow.closest('[data-word-order-activity-target="tokenSlot"]')
        const wordBank = elementBelow.closest('[data-word-order-activity-target="wordBank"]')
        
        if (tokenSlot && !tokenSlot.classList.contains('filled')) {
          // Valid token slot that is available
          this.clearTokenSlot(tokenSlot)
          tokenSlot.appendChild(this.draggedElement)
          tokenSlot.classList.add('filled')
          this.draggedElement.classList.add('in-slot')
        } else if (wordBank) {
          // Return to word bank
          if (this.draggedElement.classList.contains('in-slot')) {
            const currentSlot = this.draggedElement.closest('[data-word-order-activity-target="tokenSlot"]')
            if (currentSlot) {
              currentSlot.classList.remove('filled')
            }
            this.draggedElement.classList.remove('in-slot')
          }
          
          // Find the insertion point based on touch position
          const insertionPoint = this.findInsertionPoint(wordBank, touch.clientX, touch.clientY)
          if (insertionPoint) {
            wordBank.insertBefore(this.draggedElement, insertionPoint)
          } else {
            wordBank.appendChild(this.draggedElement)
          }
        }
      }
    }
    
    this.draggedElement.classList.remove('dragging')
    this.draggedElement = null
    this.isDragging = false
  }

  handleWordClick(event) {
    const wordItem = event.target.closest('[data-word-order-activity-target="wordItem"]')
    if (!wordItem) return
    
    const phraseIndex = this.getCurrentPhraseIndex()
    const wordBank = this.getWordBankForPhrase(phraseIndex)

    if (wordItem.classList.contains('in-slot')) {
      // Token is in a slot, move it back to word bank
      wordItem.classList.remove('in-slot')
      const tokenSlot = wordItem.closest('[data-word-order-activity-target="tokenSlot"]')
      if (tokenSlot) {
        tokenSlot.classList.remove('filled')
      }
      wordBank.appendChild(wordItem)
    } else {
      // Token is in word bank, try to place it in the first available slot
      this.playTokenAudio(event);
      const tokenSlot = this.findFirstAvailableSlot(phraseIndex)
      if (tokenSlot) {
        this.clearTokenSlot(tokenSlot)
        tokenSlot.appendChild(wordItem)
        tokenSlot.classList.add('filled')
        wordItem.classList.add('in-slot')
      }
    }
  }

  findTokenSlot(phraseIndex, tokenId) {
    return this.tokenSlotTargets.find(slot => 
      slot.closest('[data-index]')?.dataset.index == phraseIndex && 
      slot.dataset.tokenId === tokenId
    )
  }

  findFirstAvailableSlot(phraseIndex) {
    return this.tokenSlotTargets.find(slot => 
      slot.closest('[data-index]')?.dataset.index == phraseIndex && 
      !slot.classList.contains('filled')
    )
  }

  findInsertionPoint(wordBank, clientX, clientY) {
    const wordItems = Array.from(wordBank.querySelectorAll('[data-word-order-activity-target="wordItem"]'))
    
    for (let item of wordItems) {
      if (item === this.draggedElement) continue
      
      const rect = item.getBoundingClientRect()
      const itemCenterX = rect.left + rect.width / 2
      const itemCenterY = rect.top + rect.height / 2
      
      // Check if drop position is before this item
      if (clientX < itemCenterX || (clientX === itemCenterX && clientY < itemCenterY)) {
        return item
      }
    }
    
    return null // Insert at end
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
    
    // Check if all token slots are filled correctly
    const tokenSlots = this.getTokenSlotsForPhrase(phraseIndex)
    const allSlotsFilled = tokenSlots.every(slot => slot.classList.contains('filled'))
    
    if (!allSlotsFilled) {
      this.showIncorrectFeedback("Please fill in all the words!")
      return
    }
    
    // Validate each token is in the correct slot
    const allCorrect = tokenSlots.every(slot => {
      const token = slot.querySelector('[data-word-order-activity-target="wordItem"]')
      return token && token.dataset.tokenId === slot.dataset.tokenId
    })

    if (allCorrect) {
      // Mark slots as correct
      tokenSlots.forEach(slot => slot.classList.add('correct'))
      this.showCorrectFeedback()
      setTimeout(() => {
        this.moveToNextPhrase()
      }, 1500)
    } else {
      // Mark incorrect slots
      tokenSlots.forEach(slot => {
        const token = slot.querySelector('[data-word-order-activity-target="wordItem"]')
        if (!token || token.dataset.tokenId !== slot.dataset.tokenId) {
          slot.classList.add('incorrect')
        }
      })
      this.showIncorrectFeedback()
      setTimeout(() => {
        this.resetTokensToBank(phraseIndex)
      }, 2000)
    }
  }

  getTokenSlotsForPhrase(phraseIndex) {
    return this.tokenSlotTargets.filter(slot => 
      slot.closest('[data-index]')?.dataset.index == phraseIndex
    )
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

  showIncorrectFeedback(message = "Not quite right. Try again!") {
    const feedbackMessage = this.feedbackMessageTarget
    feedbackMessage.textContent = message
    feedbackMessage.className = "mt-4 p-3 rounded-lg text-center text-lg font-medium incorrect-feedback"
    feedbackMessage.classList.remove('hidden')
    feedbackMessage.classList.add('animate-shake')
    
    setTimeout(() => {
      feedbackMessage.classList.add('hidden')
      feedbackMessage.classList.remove('animate-shake')
    }, 2000)
  }

  resetTokensToBank(phraseIndex) {
    const tokenSlots = this.getTokenSlotsForPhrase(phraseIndex)
    const wordBank = this.getWordBankForPhrase(phraseIndex)
    
    // Move all tokens from slots back to word bank and clear visual states
    tokenSlots.forEach(slot => {
      const token = slot.querySelector('[data-word-order-activity-target="wordItem"]')
      if (token) {
        token.classList.remove('in-slot')
        wordBank.appendChild(token)
      }
      slot.classList.remove('filled', 'correct', 'incorrect')
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
