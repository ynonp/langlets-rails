import { Controller } from "@hotwired/stimulus"

// Spotify-style popup for assigning a course to learning paths.
// Lists every learning path, lets the user toggle membership, and create new ones.
export default class extends Controller {
  static targets = ["overlay", "list", "search", "loading", "empty"]
  static values = { courseId: String }

  connect() {
    this.loaded = false
    this.paths = []
    this._onKeydown = (e) => { if (e.key === "Escape") this.close() }
  }

  open() {
    this.overlayTarget.classList.remove("hidden")
    document.addEventListener("keydown", this._onKeydown)
    if (!this.loaded) this.load()
  }

  close() {
    this.overlayTarget.classList.add("hidden")
    document.removeEventListener("keydown", this._onKeydown)
  }

  async load() {
    try {
      const res = await fetch(this.baseUrl(), { headers: { Accept: "application/json" } })
      if (!res.ok) throw new Error("Failed to load learning paths")
      const data = await res.json()
      this.paths = data.paths
      this.loaded = true
      this.render()
    } catch (e) {
      console.error(e)
      this.loadingTarget.textContent = "Could not load learning paths."
    }
  }

  render() {
    this.loadingTarget.classList.add("hidden")
    // Remove previously rendered rows (keep the loading/empty placeholders).
    this.listTarget.querySelectorAll("[data-path-id]").forEach((el) => el.remove())

    const term = (this.hasSearchTarget ? this.searchTarget.value : "").trim().toLowerCase()
    const visible = this.paths.filter((p) => p.name.toLowerCase().includes(term))

    this.emptyTarget.classList.toggle("hidden", visible.length > 0)
    visible.forEach((p) => this.listTarget.insertAdjacentHTML("beforeend", this.rowHtml(p)))
  }

  filter() {
    this.render()
  }

  rowHtml(path) {
    const count = path.courses_count === 1 ? "1 course" : `${path.courses_count} courses`
    const checked = path.member
    return `
      <button type="button" data-path-id="${path.id}" data-action="course-paths#toggle"
              class="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors text-left">
        <div class="w-11 h-11 flex-shrink-0 rounded-lg bg-gradient-to-br from-emerald-300 to-emerald-500 flex items-center justify-center text-white font-extrabold">
          ${this.escape(path.name.charAt(0).toUpperCase() || "?")}
        </div>
        <div class="flex-1 min-w-0">
          <div class="text-sm font-bold text-gray-900 dark:text-gray-50 truncate">${this.escape(path.name)}</div>
          <div class="text-xs font-semibold text-gray-400">${count}</div>
        </div>
        <span class="flex-shrink-0 w-6 h-6 rounded-full border-2 flex items-center justify-center ${checked ? "border-emerald-500 bg-emerald-500" : "border-gray-300 dark:border-gray-600"}">
          ${checked ? '<svg width="14" height="14" viewBox="0 0 24 24" fill="none"><path d="M5 13l4 4L19 7" stroke="white" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/></svg>' : ""}
        </span>
      </button>`
  }

  async toggle(event) {
    const button = event.currentTarget
    const id = Number(button.dataset.pathId)
    const path = this.paths.find((p) => p.id === id)
    if (!path) return

    button.disabled = true
    try {
      if (path.member) {
        const res = await fetch(`${this.baseUrl()}/${id}`, { method: "DELETE", headers: this.headers() })
        if (!res.ok) throw new Error("remove failed")
        path.member = false
        path.courses_count = Math.max(0, path.courses_count - 1)
      } else {
        const res = await fetch(this.baseUrl(), {
          method: "POST",
          headers: this.headers(),
          body: JSON.stringify({ learning_path_id: id })
        })
        if (!res.ok) throw new Error("add failed")
        path.member = true
        path.courses_count += 1
      }
      this.render()
    } catch (e) {
      console.error(e)
    } finally {
      button.disabled = false
    }
  }

  async createNew() {
    const name = window.prompt("Name your new learning path")
    if (!name || !name.trim()) return

    try {
      const res = await fetch(this.baseUrl(), {
        method: "POST",
        headers: this.headers(),
        body: JSON.stringify({ name: name.trim() })
      })
      if (!res.ok) throw new Error("create failed")
      const data = await res.json()
      this.paths.unshift(data.path)
      if (this.hasSearchTarget) this.searchTarget.value = ""
      this.render()
    } catch (e) {
      console.error(e)
    }
  }

  baseUrl() {
    return `/courses/${this.courseIdValue}/learning_paths`
  }

  headers() {
    return {
      "Content-Type": "application/json",
      Accept: "application/json",
      "X-CSRF-Token": document.querySelector('[name="csrf-token"]').content
    }
  }

  escape(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }
}
