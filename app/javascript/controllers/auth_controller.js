import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  signOut(event) {
    // Clear local XP storage before sign out
    localStorage.removeItem('langlets_xp')
    
    // Allow the default sign out action to proceed
    return true
  }
}