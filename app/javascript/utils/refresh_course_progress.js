// Fetch in the receiving webview so authentication and translation language
// stay local to that page. Broadcasts contain no learner progress or HTML.
export async function refreshCourseProgress(target) {
  if (!target) return

  try {
    const response = await fetch(target.dataset.progressUrl, {
      headers: { Accept: "text/html" },
      cache: "no-store"
    })
    if (!response.ok || response.redirected || !target.isConnected) return

    const page = new DOMParser().parseFromString(await response.text(), "text/html")
    if (!target.isConnected) return
    for (const replacement of page.querySelectorAll("[data-course-progress-part]")) {
      const current = document.getElementById(replacement.id)
      if (current) current.replaceWith(replacement)
    }
  } catch (error) {
    console.error("Failed to refresh course progress:", error)
  }
}
