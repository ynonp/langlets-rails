import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    progressData: Object,
    authenticated: Boolean,
    currentDailyXp: Number,
    xpAwarded: Number
  }
  static targets = ["dailyXp"]
  
  connect() {
    // Update local XP display for unauthenticated users
    if (!this.authenticatedValue) {
      this.updateLocalXpDisplay()
    }
    
    // If XP was awarded this request, add it to local storage for unauthenticated users
    if (!this.authenticatedValue && this.xpAwardedValue > 0) {
      this.addLocalXp(this.xpAwardedValue)
    }
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
    try {
      const response = await fetch('/progress', {
        method: 'POST',
        headers: {
          'Accept': 'text/vnd.turbo-stream.html',
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ xp: xpAmount })
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
    }
  }

  updateLocalXpDisplay() {
    if (!this.authenticatedValue && this.hasDailyXpTarget) {
      const dailyXp = this.getLocalDailyXp()
      this.dailyXpTarget.textContent = `${dailyXp} XP`
    }
  }
}
