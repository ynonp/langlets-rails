import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ['container', 'pauseButton', 'playButton'];

  handleVideoStart() {  
    this.pauseButtonTarget.classList.remove('hidden');
    this.playButtonTarget.classList.add('hidden');
  }

  handleVideoPause() {
    this.pauseButtonTarget.classList.add('hidden');
    this.playButtonTarget.classList.remove('hidden');
  }
}