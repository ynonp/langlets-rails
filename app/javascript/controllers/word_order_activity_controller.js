import { Controller } from "@hotwired/stimulus"
import { animate } from "motion/mini"

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
    this.touchStartTime = null
    this.touchStartPosition = null
    this.isDragging = false
  }

  // All drag/touch/click actions are bound once on the controller root and
  // delegated here via closest(), instead of one listener set per tile/slot.

  findWordItem(event) {
    return event.target.closest('[data-word-order-activity-target="wordItem"]')
  }

  findDropTarget(event) {
    return event.target.closest('[data-word-order-activity-target="tokenSlot"], [data-word-order-activity-target="wordBank"]')
  }

  handleDragStart(event) {
    const wordItem = this.findWordItem(event)
    if (!wordItem) return

    this.draggedElement = wordItem
    wordItem.classList.add('dragging')
    event.dataTransfer.effectAllowed = 'move'
    event.dataTransfer.setData('text/html', wordItem.outerHTML)
  }

  handleDragEnd(event) {
    const wordItem = this.findWordItem(event)
    if (wordItem) {
      wordItem.classList.remove('dragging')
    }
    this.draggedElement = null
  }

  handleDragOver(event) {
    const dropTarget = this.findDropTarget(event)
    if (!dropTarget) return

    event.preventDefault()
    event.dataTransfer.dropEffect = 'move'
    dropTarget.classList.add('drag-over')
  }

  handleDragLeave(event) {
    const dropTarget = this.findDropTarget(event)
    if (dropTarget) {
      dropTarget.classList.remove('drag-over')
    }
  }

  handleDrop(event) {
    const dropTarget = this.findDropTarget(event)
    if (!dropTarget) return

    event.preventDefault()
    dropTarget.classList.remove('drag-over')

    if (!this.draggedElement) return

    const draggedElement = this.draggedElement

    // Dropping on a token slot
    if (dropTarget.dataset.wordOrderActivityTarget === 'tokenSlot') {
      this.dropWordOnSlot(dropTarget, draggedElement)
      return
    }

    // Dropping on the word bank - free the slot the word came from, if any
    this.releaseFromSlot(draggedElement)

    // Find the insertion point based on drop position
    const insertionPoint = this.findInsertionPoint(dropTarget, event.clientX, event.clientY)
    if (insertionPoint) {
      dropTarget.insertBefore(draggedElement, insertionPoint)
    } else {
      dropTarget.appendChild(draggedElement)
    }
  }

  // Place a dragged word into a slot. If the slot is taken, the two words swap
  // places when the dragged word came from another slot; a word dragged from
  // the bank sends the occupant back to the bank instead.
  dropWordOnSlot(slot, draggedElement) {
    if (slot.contains(draggedElement)) return // dropped back on its own slot

    const occupant = slot.querySelector('[data-word-order-activity-target="wordItem"]')
    const originSlot = draggedElement.classList.contains('in-slot')
      ? draggedElement.closest('[data-word-order-activity-target="tokenSlot"]')
      : null

    if (occupant) {
      if (originSlot) {
        // Swap: the occupant takes the dragged word's slot, which stays filled
        originSlot.appendChild(occupant)
      } else {
        occupant.classList.remove('in-slot')
        const wordBank = this.getWordBankForPhrase(this.getCurrentPhraseIndex())
        wordBank.appendChild(occupant)
      }
    } else if (originSlot) {
      originSlot.classList.remove('filled')
    }

    slot.appendChild(draggedElement)
    slot.classList.add('filled')
    draggedElement.classList.add('in-slot')
  }

  // Detach a word from the slot it currently occupies (if any) so that slot
  // becomes available again. Must be called before moving the word elsewhere,
  // while it is still a child of its origin slot.
  releaseFromSlot(wordItem) {
    if (!wordItem.classList.contains('in-slot')) return
    const currentSlot = wordItem.closest('[data-word-order-activity-target="tokenSlot"]')
    if (currentSlot) {
      currentSlot.classList.remove('filled')
    }
    wordItem.classList.remove('in-slot')
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
    const wordItem = this.findWordItem(event)
    if (!wordItem) return

    this.touchStartTime = Date.now()
    this.touchStartPosition = {
      x: event.touches[0].clientX,
      y: event.touches[0].clientY
    }
    this.isDragging = false

    // Don't prevent default immediately - let it potentially become a click
    this.draggedElement = wordItem

    const touch = event.touches[0]
    const rect = wordItem.getBoundingClientRect()
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
    
    // If it was a quick tap (less than 200ms) and no dragging occurred, place
    // the word here instead of deferring to the synthesized click event. On
    // iOS that click can arrive 1-2s later (or be suppressed), which made the
    // tile feel slow to move. preventDefault stops the ghost click from firing
    // afterwards and toggling the word back out of its slot.
    if (touchDuration < 200 && !this.isDragging) {
      event.preventDefault()
      const wordItem = this.draggedElement.closest('[data-word-order-activity-target="wordItem"]')
      this.draggedElement.classList.remove('dragging')
      this.draggedElement = null
      this.isDragging = false
      if (wordItem) {
        this.placeOrReturnWord(wordItem)
      }
      return
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
        
        if (tokenSlot) {
          this.dropWordOnSlot(tokenSlot, this.draggedElement)
        } else if (wordBank) {
          // Return to word bank - free the slot the word came from, if any
          this.releaseFromSlot(this.draggedElement)

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

    this.placeOrReturnWord(wordItem)
  }

  // Shared tap/click placement logic. Toggles a word between the bank and the
  // first available slot. Called from both the click handler (desktop) and the
  // touchend quick-tap branch (mobile) so iOS doesn't have to wait for the
  // synthesized click event before the tile moves.
  placeOrReturnWord(wordItem) {
    const phraseIndex = this.getCurrentPhraseIndex()
    const wordBank = this.getWordBankForPhrase(phraseIndex)

    if (wordItem.classList.contains('in-slot')) {
      // Token is in a slot, move it back to word bank
      this.releaseFromSlot(wordItem)
      wordBank.appendChild(wordItem)
    } else {
      // Token is in word bank, try to place it in the first available slot
      const tokenSlot = this.findFirstAvailableSlot(phraseIndex)
      if (tokenSlot) {
        this.clearTokenSlot(tokenSlot)
        tokenSlot.appendChild(wordItem)
        tokenSlot.classList.add('filled')
        wordItem.classList.add('in-slot')
      }
      this.playWordItemAudio(wordItem)
    }
  }

  // Play a word tile's audio without depending on an event target, so it can be
  // triggered from touchend as well as click.
  playWordItemAudio(wordItem) {
    const audioUrl = wordItem.dataset.audioUrl
    if (!audioUrl) return
    this.element.dispatchEvent(new CustomEvent('audio-cache:play', {
      bubbles: true,
      detail: { url: audioUrl }
    }))
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
    const button = event.currentTarget
    const phraseIndex = parseInt(button.dataset.phraseIndex)
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
      return token && token.dataset.wordText === slot.dataset.expectedText
    })

    if (allCorrect) {
      // Prevent a double-click from scheduling moveToNextPhrase twice
      button.disabled = true
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
        if (!token || token.dataset.wordText !== slot.dataset.expectedText) {
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
    // Award XP for correct answer (5 XP per correct phrase)
    this.awardXp(5);
    
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
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.width = `${progress}%`
    }
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
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.width = '100%'
    }
    this.completionMessageTarget.classList.remove('hidden')
    
    animate(this.completionMessageTarget, 
      { opacity: [0, 1], scale: [0.8, 1] }, 
      { duration: 0.3, easing: 'easeOut' }
    );

    this.element.dispatchEvent(new CustomEvent('activity:completed', { bubbles: true }))
  }

  // Award XP by calling the progress tracker controller
  awardXp(amount) {
    // Find the progress tracker controller on the gamification bar
    const gamificationBar = document.getElementById('gamification-bar');
    if (gamificationBar && gamificationBar.dataset.controller) {
      const controller = this.application.getControllerForElementAndIdentifier(gamificationBar, 'progress-tracker');
      if (controller) {
        controller.awardXp(amount);
      }
    }
  }
}
