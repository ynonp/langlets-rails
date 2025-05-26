import { Controller } from "@hotwired/stimulus"
import Sortable from 'sortablejs';


// Connects to data-controller="sort-phrases-activity"
export default class extends Controller {
  static targets = ['phraseItem', 'phrasesContainer', 'checkButton', 'completionMessage', 'resultMessage'];
  static values = { correctOrder: Array }

  initialize() {
    this.checkOrder = this.checkOrder.bind(this);
  }

  connect() {
    this.sortable = Sortable.create(this.phrasesContainerTarget, {
      animation: 150,
      ghostClass: 'sortable-ghost',
    });
  }

  checkOrder() {
    const currentOrder = Array.from(this.phraseItemTargets)
      .map(item => parseInt(item.dataset.id));
    
    const isCorrect = arraysEqual(currentOrder, this.correctOrderValue);
    
    if (isCorrect) {
      this.checkCorrect();
    } else {
      this.checkIncorrect();
    }
  }

  checkCorrect() {
    this.completionMessageTarget.classList.remove('hidden');
    this.completionMessageTarget.classList.add('animate-fade-in');

    // Disable the check button
    this.checkButtonTarget.disabled = true;
    this.checkButtonTarget.classList.add('hidden');
  }

  checkIncorrect() {
    this.resultMessageTarget.classList.remove('hidden');

    // Shuffle the phrases again
    setTimeout(() => {
      this.resultMessageTarget.classList.add('hidden');
    }, 2000);
  }

}

function arraysEqual(a, b) {
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i++) {
    if (a[i] !== b[i]) return false;
  }
  return true;
}
