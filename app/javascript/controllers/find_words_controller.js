import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="language-alignment-activity.js"
export default class extends Controller {
  static targets = ['progressBar', 'token', 'completionMessage'];

  findToken(ev) {
    const token = ev.target;
    if (token.getAttribute('data-found') === 'false') {
      token.setAttribute('data-found', 'true');
      token.classList.add('bg-green-400', 'text-gray-900', 'font-medium', 'px-1', 'rounded');

      token.classList.add('animate-pulse');
      setTimeout(() => token.classList.remove('animate-pulse'), 1000);

      this.updateProgress();
    }
  }

  updateProgress() {
    const totalTokens = this.tokenTargets.length;
    const foundTokens = this.tokenTargets.filter(t => t.dataset.found === "true").length;
    const percentage = (foundTokens / totalTokens) * 100;
    this.progressBarTarget.style.width = `${percentage}%`;
    console.log(foundTokens);
    console.log(totalTokens);

    if (totalTokens === foundTokens) {
      this.completionMessageTarget.classList.remove('hidden');
      this.completionMessageTarget.classList.add('animate-fade-in');
    }
  }
}

