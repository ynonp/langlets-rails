import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { progressData: Object }
  
  connect() {
    console.log("Progress tracker connected with data:", this.progressDataValue)
  }  
  
  sendProgressUpdate() {
    console.log("Sending progress update:", this.progressDataValue)
    
    const payload = JSON.stringify(this.progressDataValue)
    
    navigator.sendBeacon('/progress', new Blob([payload], {
      type: 'application/json'
    }))
  }
}
