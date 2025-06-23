import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { progressData: Object }
  
  connect() {
  }  
  
  sendProgressUpdate() {    
    const payload = JSON.stringify(this.progressDataValue)
    
    navigator.sendBeacon('/progress', new Blob([payload], {
      type: 'application/json'
    }))
  }
}
