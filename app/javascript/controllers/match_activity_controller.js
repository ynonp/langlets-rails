import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="match-activity-controller.js"
export default class extends Controller {
  static targets = ['phraseItem', 'progressBar', 'completionMessage'];
  static values = ['l1'];

  initialize() {
    this.selectPhrase = this.selectPhrase.bind(this);
  }

  connect() {
    this.element.addEventListener('click', this.selectPhrase);
  }

  disconnect() {
    this.element.removeEventListener('click', this.selectPhrase);
  }

  selectPhrase(ev) {
    const clickedItem = ev.target;
    if (clickedItem.dataset.id == null) return;
    if (clickedItem.dataset.matched) return;

    const previouslySelectedItem = this.element.querySelector('.selected');

    if (clickedItem.dataset.side === 'orig') {
      this.say(clickedItem.innerText.trim(), this.l1Value);
    }

    if (!previouslySelectedItem) {
      this.selectFirstItem(clickedItem);
    } else if (previouslySelectedItem.dataset.side === clickedItem.dataset.side) {
      this.clearSelection();
      this.selectFirstItem(clickedItem);
    } else if (previouslySelectedItem.dataset.id === clickedItem.dataset.id) {
      this.markMatch(previouslySelectedItem, clickedItem);
      this.updateProgress();
    } else {
      this.clearSelection();
      this.markFailedMatch(previouslySelectedItem, clickedItem);
    }
  }

  selectFirstItem(item) {
    item.classList.add('selected');
  }

  clearSelection() {
    this.element.querySelectorAll('.selected').forEach(e => e.classList.remove('selected'));
  }

  markMatch(item1, item2) {
    this.clearSelection();
    [item1, item2].forEach(i => {
      i.classList.remove('text-white');
      i.classList.add('bg-green-200', 'border-green-600', 'text-gray-800');
      i.classList.add('animate-pulse');
      i.dataset.matched = true;
      i.disabled = true;
      setTimeout(() => i.classList.remove('animate-pulse'), 1000);
    });
  }

  markFailedMatch(item1, item2) {
    [item1, item2].forEach(i => {
      i.classList.add('animate-shake');
    });
    setTimeout(() => {
      item1.classList.remove('animate-shake');
      item2.classList.remove('animate-shake');
    }, 500);
  }

  say(text, lang) {
    if ('speechSynthesis' in window) {
      const utterance = new SpeechSynthesisUtterance(text);
      utterance.lang = lang;
      const voices = speechSynthesis.getVoices();
      const voice = voices.find(v => v.lang === lang);
      if (voice) utterance.voice = voice;
      speechSynthesis.speak(utterance);
    }
  }

  updateProgress() {
    const matchedPairs = this.phraseItemTargets.filter(el => el.dataset.matched).length;
    const totalPairs = this.phraseItemTargets.length;
    const percentage = (matchedPairs / totalPairs) * 100;
    this.progressBarTarget.style.width = `${percentage}%`;

    if (matchedPairs === totalPairs) {
      this.completionMessageTarget.classList.remove('hidden');
      this.completionMessageTarget.classList.add('animate-fade-in');
    }
  }
}
