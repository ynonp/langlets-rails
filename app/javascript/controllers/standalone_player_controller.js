import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="standalone-player"
export default class extends Controller {
  static targets = ["lyricsTab", "vocabularyTab", "lyricsContent", "vocabularyContent"]

  connect() {
    // Default to lyrics tab
    this.showLyrics()
  }

  showLyrics() {
    // Update tab styles
    this.lyricsTabTarget.classList.add("bg-slate-700/50", "text-white", "border-b-2", "border-blue-500")
    this.lyricsTabTarget.classList.remove("text-slate-400")
    
    this.vocabularyTabTarget.classList.remove("bg-slate-700/50", "text-white", "border-b-2", "border-blue-500")
    this.vocabularyTabTarget.classList.add("text-slate-400")
    
    // Show/hide content
    this.lyricsContentTarget.classList.remove("hidden")
    this.vocabularyContentTarget.classList.add("hidden")
  }

  showVocabulary() {
    // Update tab styles
    this.vocabularyTabTarget.classList.add("bg-slate-700/50", "text-white", "border-b-2", "border-blue-500")
    this.vocabularyTabTarget.classList.remove("text-slate-400")
    
    this.lyricsTabTarget.classList.remove("bg-slate-700/50", "text-white", "border-b-2", "border-blue-500")
    this.lyricsTabTarget.classList.add("text-slate-400")
    
    // Show/hide content
    this.vocabularyContentTarget.classList.remove("hidden")
    this.lyricsContentTarget.classList.add("hidden")
  }
}
