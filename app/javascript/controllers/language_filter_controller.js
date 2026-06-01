import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { currentLang: String }

  connect() {
    if (this.currentLangValue) {
      localStorage.setItem("langlets_learning_lang", this.currentLangValue)
    }
  }

  select(event) {
    const language = event.currentTarget.dataset.lang

    if (language) {
      localStorage.setItem("langlets_learning_lang", language)
    } else {
      localStorage.removeItem("langlets_learning_lang")
    }
  }
}
