import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ['content'];

  activityChange(event) {    
    const path = this.contentTarget.dataset.activityNavigationUrl;
    history.pushState(null, '', path);
  }
}