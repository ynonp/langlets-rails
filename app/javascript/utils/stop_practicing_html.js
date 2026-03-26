// Returns the HTML string for a "Stop Practicing This Word" toggle button.
// Stimulus auto-connects the stop-practicing controller when injected into the DOM.
export function stopPracticingHtml(tokenId) {
  return `
    <div data-controller="stop-practicing"
         data-stop-practicing-token-id-value="${tokenId}"
         class="mt-3 text-center">
      <button data-stop-practicing-target="button"
              data-action="click->stop-practicing#toggle"
              class="text-xs text-gray-400 hover:text-red-400 py-1 px-2 rounded transition-colors duration-200">
        <span data-stop-practicing-target="label">🚫 Stop Practicing This Word</span>
      </button>
    </div>
  `
}
