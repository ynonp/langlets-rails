import { Controller } from "@hotwired/stimulus"

// The delete confirmation on a saved word. Deleting drops the phrase and the
// translation with the word, so it asks once — and offers the reversible
// alternative in the same breath.
export default class extends Controller {
  static targets = [ "dialog" ]

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }
}
