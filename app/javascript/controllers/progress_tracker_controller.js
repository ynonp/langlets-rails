import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    progressData: Object,
    authenticated: Boolean,
    currentDailyXp: Number,
    xpAwarded: Number
  }
  static targets = ["dailyXp", "animationContainer"]
  
  connect() {
    // Initialize timer for activity tracking
    this.startTime = null
    this.activeTime = 0
    this.startTimer()
    
    // Set up visibility change listener
    this.setupVisibilityTracking()
    
    // Update local XP display for unauthenticated users
    if (!this.authenticatedValue) {
      this.updateLocalXpDisplay()
    }
    
    // If XP was awarded this request, add it to local storage for unauthenticated users
    if (!this.authenticatedValue && this.xpAwardedValue > 0) {
      this.addLocalXp(this.xpAwardedValue)
    }
  }
  
  disconnect() {
    // Clean up timer and report final progress
    this.stopTimer()
    this.reportProgress()
    
    // Remove visibility change listener
    if (this.visibilityChangeHandler) {
      document.removeEventListener('visibilitychange', this.visibilityChangeHandler)
    }
  }
  
  startTimer() {
    this.startTime = Date.now()
    this.activeTime = 0
  }
  
  stopTimer() {
    if (this.startTime) {
      this.activeTime += (Date.now() - this.startTime)
      this.startTime = null
    }
  }
  
  resetTimer() {
    this.startTime = Date.now()
    this.activeTime = 0
  }
  
  setupVisibilityTracking() {
    this.visibilityChangeHandler = () => {
      if (document.visibilityState === "hidden") {
        this.stopTimer()
        this.reportProgress()
      } else if (document.visibilityState === "visible") {
        this.startTimer()
      }
    }
    
    document.addEventListener('visibilitychange', this.visibilityChangeHandler)
  }
  
  reportProgress() {
    if (!this.authenticatedValue || this.activeTime === 0) return
    
    const analyticsData = JSON.stringify({
      active_time: Math.round(this.activeTime / 1000), // Convert to seconds
      xp_gained: 0 // No XP for time tracking alone
    })
    
    navigator.sendBeacon("/log", new Blob([analyticsData], {
      type: 'application/json'
    }))
    
    this.resetTimer()
  }  
  
  sendProgressUpdate() {    
    const payload = JSON.stringify(this.progressDataValue)
    
    // Send to server
    navigator.sendBeacon('/progress', new Blob([payload], {
      type: 'application/json'
    }))

    // Dispatch XP event for local tracking (unauthenticated users)
    const xp = this.progressDataValue.activity_xp
    if (xp) {
      this.dispatch("xpAwarded", { 
        detail: { xp: xp },
        bubbles: true 
      })
    }
  }

  // Award XP via fetch request with Turbo Stream response
  async awardXp(xpAmount) {
    // Show animation immediately for responsive feedback
    this.showXpAnimation(xpAmount)
    
    // Calculate current active time
    this.stopTimer()
    const currentActiveTime = Math.round(this.activeTime / 1000)
    
    try {
      const response = await fetch('/progress', {
        method: 'POST',
        headers: {
          'Accept': 'text/vnd.turbo-stream.html',
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ 
          xp: xpAmount,
          active_time: currentActiveTime
        })
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
      }
    } catch (error) {
      console.error('Failed to award XP:', error)
      // Fallback to local XP for unauthenticated users
      if (!this.authenticatedValue) {
        this.addLocalXp(xpAmount)
      }
    }
    
    // Reset timer after progress report
    this.resetTimer()
  }

  // Local XP management for unauthenticated users
  getLocalDailyXp() {
    const today = new Date().toDateString()
    const xpData = JSON.parse(localStorage.getItem('langlets_xp') || '{}')
    
    // Reset XP if it's a new day
    if (xpData.date !== today) {
      this.setLocalDailyXp(0)
      return 0
    }
    
    return xpData.dailyXp || 0
  }

  setLocalDailyXp(xp) {
    const today = new Date().toDateString()
    const xpData = {
      date: today,
      dailyXp: xp
    }
    localStorage.setItem('langlets_xp', JSON.stringify(xpData))
  }

  addLocalXp(xpAmount) {
    if (!this.authenticatedValue) {
      const currentXp = this.getLocalDailyXp()
      const newXp = currentXp + xpAmount
      this.setLocalDailyXp(newXp)
      this.updateLocalXpDisplay()
      this.showXpAnimation(xpAmount)
    }
  }

  updateLocalXpDisplay() {
    if (!this.authenticatedValue && this.hasDailyXpTarget) {
      const dailyXp = this.getLocalDailyXp()
      this.dailyXpTarget.textContent = `${dailyXp} XP`
    }
  }

  // Show XP gain animation
  showXpAnimation(xpAmount) {
    // Find the animation container (either via target or by finding it in the DOM)
    let animationContainer
    if (this.hasAnimationContainerTarget) {
      animationContainer = this.animationContainerTarget
    } else {
      // Fallback: find the animation container in the current element
      animationContainer = this.element.querySelector('.xp-animation-container')
    }

    if (!animationContainer) {
      console.warn('No animation container found for XP animation')
      return
    }

    // Create the animation element
    const animationElement = document.createElement('div')
    animationElement.className = 'xp-gain-animation'
    animationElement.textContent = `+${xpAmount}`
    
    // Add to container
    animationContainer.appendChild(animationElement)
    
    // Remove after animation completes
    setTimeout(() => {
      if (animationElement.parentNode) {
        animationElement.parentNode.removeChild(animationElement)
      }
    }, 1000)
  }
}
