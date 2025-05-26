import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ['translationPopup', 'translationText'];

  initialize() {
    this.hidePopup = this.hidePopup.bind(this);
    this.showPopup = this.showPopup.bind(this);
  }

  connect() {
    this.element.addEventListener('click', this.showPopup);
    document.addEventListener('click', this.hidePopup);
  }

  disconnect() {
    this.element.removeEventListener('click', this.showPopup);
    document.removeEventListener('click', this.hidePopup);
  }

  hidePopup() {
    this.translationPopupTarget.classList.add('hidden');
  }

  showPopup(ev) {
    console.log(ev)
    if (ev.target.dataset.translation) {
      console.log(ev.target.dataset.translation)
      const {translation} = ev.target.dataset;

      this.translationTextTarget.textContent = translation;
      this.translationPopupTarget.style.left = `${ev.pageX}px`;
      this.translationPopupTarget.style.top = `${ev.pageY + 20}px`;
      this.translationPopupTarget.classList.remove('hidden');
      ev.stopPropagation();
    } else {
      console.log(ev.target);
    }
  }
}

