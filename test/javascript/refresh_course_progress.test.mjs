import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import { test } from "node:test"

const source = await readFile(new URL("../../app/javascript/utils/refresh_course_progress.js", import.meta.url), "utf8")
const { refreshCourseProgress } = await import(`data:text/javascript;base64,${Buffer.from(source).toString("base64")}`)

test("refreshes progress regions without navigating or replacing the course player", async () => {
  const replaced = []
  const replacements = [{ id: "course-lesson-progress" }, { id: "course-completion-control" }]
  globalThis.fetch = async (url, options) => {
    assert.equal(url, "/courses/song")
    assert.equal(options.cache, "no-store")
    return { ok: true, redirected: false, text: async () => "<html></html>" }
  }
  globalThis.DOMParser = class {
    parseFromString() {
      return { querySelectorAll: selector => {
        assert.equal(selector, "[data-course-progress-part]")
        return replacements
      } }
    }
  }
  globalThis.document = { getElementById: id => ({ replaceWith: node => replaced.push([id, node]) }) }
  await refreshCourseProgress({ dataset: { progressUrl: "/courses/song" }, isConnected: true })
  assert.deepEqual(replaced, replacements.map(node => [node.id, node]))
})

test("ignores redirected responses and pages left during the fetch", async () => {
  globalThis.DOMParser = class { constructor() { assert.fail("must not parse stale or redirected pages") } }
  for (const [redirected, isConnected] of [[true, true], [false, false]]) {
    globalThis.fetch = async () => ({ ok: true, redirected })
    await refreshCourseProgress({ dataset: { progressUrl: "/courses/song" }, isConnected })
  }
})
