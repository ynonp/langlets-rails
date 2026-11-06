import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import { test } from "node:test"

const source = await readFile(new URL("../../app/javascript/controllers/review_session_controller.js", import.meta.url), "utf8")
const { default: ReviewSession } = await import(`data:text/javascript;base64,${Buffer.from("class Controller {}\n" + source.replace(/^import .*$/gm, "")).toString("base64")}`)

test("leaving sends one authenticated close beacon, while activity and finish visits stay open", () => {
  globalThis.window = { location: { href: "https://langlets.app/review_lessons?language_code=en" } }
  globalThis.document = { querySelector: () => ({ content: "csrf-test" }) }
  const calls = []
  Object.defineProperty(globalThis, "navigator", { configurable: true, value: {
    sendBeacon(url, data) { calls.push({ url, data }); return true }
  } })
  const session = () => Object.assign(Object.create(ReviewSession.prototype), { closeUrlValue: "/review_lessons/close?lesson_id=42" })
  try {
    for (const path of ["/review_lessons?a=2", "/review_lessons/finish?language_code=en"]) {
      const controller = session()
      controller.beforeVisit({ detail: { url: path } })
      controller.close({ type: "pagehide" })
      assert.equal(calls.length, 0)
    }
    const controller = session()
    controller.beforeVisit({ detail: { url: "/app" } })
    controller.close({ type: "pagehide" })
    assert.equal(calls.length, 1)
    assert.equal(calls[0].url, controller.closeUrlValue)
    assert.equal(calls[0].data.get("authenticity_token"), "csrf-test")
    assert.equal(calls[0].data.get("background"), "true")

    session().close({ type: "pagehide" })
    assert.equal(calls.length, 2)
  } finally {
    delete globalThis.window
    delete globalThis.document
    delete globalThis.navigator
  }
})
