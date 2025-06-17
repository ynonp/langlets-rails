import { Controller } from "@hotwired/stimulus"
import { animate } from "motion/mini"



// Connects to data-controller="sort-phrases-activity"
export default class extends Controller {
  static targets = ['phraseItem', 'phrasesContainer', 'checkButton', 'completionMessage', 'resultMessage'];
  static values = { correctOrder: Array }

  initialize() {
    this.checkOrder = this.checkOrder.bind(this);
  }

  async connect() {
    const Sortable = (await import('https://esm.run/sortablejs@1.15.6')).default;
    this.sortable = Sortable.create(this.phrasesContainerTarget, {
      animation: 150,
      ghostClass: 'sortable-ghost',
    });
  }

  checkOrder() {    
    const currentOrder = this.phraseItemTargets.map(item => item.textContent.trim())    
    
    const isCorrect = arraysEqual(currentOrder, this.correctOrderValue);
    
    if (isCorrect) {
      this.checkCorrect();
    } else {
      this.checkIncorrect();
    }
  }

  checkCorrect() {
    this.completionMessageTarget.classList.remove('hidden');
    animate(this.completionMessageTarget, 
      { opacity: [0, 1], scale: [0.8, 1] }, 
      { duration: 0.3, easing: 'easeOut' }
    );
    this.element.dispatchEvent(new CustomEvent('activity:completed', { bubbles: true }))


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
