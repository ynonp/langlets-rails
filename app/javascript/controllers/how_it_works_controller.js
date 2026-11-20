import { Controller } from "@hotwired/stimulus"

// Plays the four "How Langlets works" illustrations on the homepage.
//
// The server renders every stage in its finished state. On connect each stage
// is reset to its starting state and then replays its timeline in a loop
// while it is on screen; leaving the viewport cancels the run. Visitors who
// prefer reduced motion keep the static finished state.
const CANCELLED = Symbol("cancelled")
const HOLD_AT_END = 2800

export default class extends Controller {
  static targets = ["stage"]

  connect() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return
    if (!("IntersectionObserver" in window)) return

    this.runs = new Map()
    this.stageTargets.forEach((stage) => {
      prepareTyping(stage)
      stage.classList.add("is-animated")
      SCENES[stage.dataset.scene]?.reset(stage)
    })
    this.observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => entry.isIntersecting ? this.start(entry.target) : this.stop(entry.target))
    }, { threshold: 0.4 })
    this.stageTargets.forEach((stage) => this.observer.observe(stage))
  }

  disconnect() {
    this.observer?.disconnect()
    this.runs?.forEach((run) => { run.cancelled = true })
    this.runs?.clear()
  }

  start(stage) {
    const scene = SCENES[stage.dataset.scene]
    if (!scene || this.runs.has(stage)) return

    const run = { cancelled: false }
    this.runs.set(stage, run)
    this.loop(stage, scene, run)
  }

  stop(stage) {
    const run = this.runs.get(stage)
    if (!run) return
    run.cancelled = true
    this.runs.delete(stage)
  }

  async loop(stage, scene, run) {
    const wait = (ms) => new Promise((resolve, reject) => {
      setTimeout(() => (run.cancelled ? reject(CANCELLED) : resolve()), ms)
    })

    try {
      while (!run.cancelled) {
        scene.reset(stage)
        await wait(500)
        await scene.play(stage, wait)
        await wait(HOLD_AT_END)
      }
    } catch (error) {
      if (error !== CANCELLED) throw error
    }
  }
}

// ── Scenes ──────────────────────────────────────────────────────────────────

const SCENES = {
  // Step 1: the video plays on one side while each line is written out, the
  // original first and then its translation.
  transcribe: {
    reset(stage) {
      stage.classList.remove("is-playing")
      setProgress(stage, 0, false)
      stage.querySelector(".hiw-panel").scrollTop = 0
      stage.querySelectorAll(".hiw-phrase").forEach((phrase) => {
        phrase.classList.remove("is-active")
        phrase.classList.add("is-hidden")
      })
      stage.querySelectorAll("[data-type]").forEach(clearTyping)
    },
    // Two passes, like the pipeline: the whole video is transcribed while it
    // plays, then the finished transcript is translated line by line.
    async play(stage, wait) {
      const phrases = [...stage.querySelectorAll(".hiw-phrase")]

      stage.classList.add("is-playing")
      for (const [index, phrase] of phrases.entries()) {
        phrase.classList.remove("is-hidden")
        phrase.classList.add("is-active")
        keepInView(phrase)
        setProgress(stage, (index + 1) / phrases.length)
        await type(phrase.querySelector(".hiw-l1"), wait, 32)
        await wait(300)
        phrase.classList.remove("is-active")
      }
      stage.classList.remove("is-playing")
      await wait(700)

      for (const phrase of phrases) {
        phrase.classList.add("is-active")
        keepInView(phrase)
        await type(phrase.querySelector(".hiw-l2"), wait, 38)
        await wait(350)
        phrase.classList.remove("is-active")
      }
    }
  },

  // Step 2, following the addLessons pipeline step: the transcript arrives as
  // one continuous run of text, breaks into short lines, the lines are grouped
  // into lessons (cutting the video timeline to match), each lesson gets a
  // title, and the groups settle into the course page's lesson rows.
  split: {
    reset(stage) {
      stage.getAnimations({ subtree: true }).forEach((animation) => animation.cancel())
      stage.classList.remove("is-lines", "is-rows")
      stage.querySelectorAll(".hiw-block, .hiw-seg").forEach((element) => element.classList.remove("is-on"))
      stage.querySelectorAll("[data-type]").forEach(clearTyping)
    },
    async play(stage, wait) {
      await wait(1100)

      flip([...stage.querySelectorAll(".hiw-line")], () => stage.classList.add("is-lines"))
      await wait(1300)

      const blocks = [...stage.querySelectorAll(".hiw-block")]
      const segments = [...stage.querySelectorAll(".hiw-seg")]
      for (const [index, block] of blocks.entries()) {
        block.classList.add("is-on")
        segments[index].classList.add("is-on")
        await wait(750)
      }

      for (const block of blocks) {
        await type(block.querySelector("[data-type]"), wait, 45)
        await wait(150)
      }
      await wait(1000)

      stage.classList.add("is-rows")
    }
  },

  // Step 3: word by word, the token lights up and its translation is typed
  // underneath.
  words: {
    reset(stage) {
      stage.querySelectorAll(".hiw-tok").forEach((tok) => tok.classList.remove("is-active", "is-done"))
      stage.querySelectorAll("[data-type]").forEach(clearTyping)
    },
    async play(stage, wait) {
      for (const tok of stage.querySelectorAll(".hiw-tok")) {
        tok.classList.add("is-active")
        await wait(220)
        await type(tok.querySelector("[data-type]"), wait, 70)
        await wait(260)
        tok.classList.replace("is-active", "is-done")
      }
    }
  },

  // Step 4: lesson view (video beside text) collapses to the exercise layout —
  // video on top, one phrase below — then a word drops out and becomes a
  // fill-in-the-blank that gets answered.
  practice: {
    reset(stage) {
      stage.getAnimations({ subtree: true }).forEach((animation) => animation.cancel())
      stage.classList.remove("is-practice", "is-fading", "is-vanishing", "is-blank", "is-solved")
      stage.classList.remove("is-playing")
      stage.querySelector(".hiw-input").classList.remove("has-value")
      stage.querySelector(".hiw-btn-check").classList.remove("is-pressed")
      stage.querySelectorAll("[data-type]").forEach(clearTyping)
      setProgress(stage, 0, false)
    },
    async play(stage, wait) {
      stage.classList.add("is-playing")
      setProgress(stage, 0.55)
      await wait(1800)

      // Everything but the chosen phrase fades away…
      stage.classList.add("is-fading")
      await wait(450)

      // …and the layout morphs into the exercise.
      const video = stage.querySelector(".hiw-video")
      const focus = stage.querySelector(".hiw-focus")
      flip([video, focus], () => stage.classList.add("is-practice"))
      setProgress(stage, 0.3, false)
      await wait(1100)

      // One word disappears and becomes the blank.
      stage.classList.add("is-vanishing")
      await wait(400)
      stage.classList.add("is-blank")
      await wait(1400)

      // The learner answers it.
      const input = stage.querySelector(".hiw-input")
      input.classList.add("has-value")
      await type(input.querySelector("[data-type]"), wait, 110)
      await wait(350)
      const check = stage.querySelector(".hiw-btn-check")
      check.classList.add("is-pressed")
      await wait(160)
      check.classList.remove("is-pressed")
      stage.classList.remove("is-vanishing")
      stage.classList.add("is-solved")
      setProgress(stage, 0.75)
      await wait(1200)
      stage.classList.remove("is-playing")
    }
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

function setProgress(stage, fraction, animate = true) {
  const bar = stage.querySelector(".hiw-video-progress")
  if (!bar) return
  bar.style.transition = animate ? "" : "none"
  bar.style.transform = `scaleX(${fraction})`
}

// On narrow stages the transcript is taller than its panel; scroll it the
// way the real transcript follows playback.
function keepInView(phrase) {
  const panel = phrase.closest(".hiw-panel")
  const overflow = phrase.offsetTop + phrase.offsetHeight - (panel.scrollTop + panel.clientHeight)
  if (overflow > 0) panel.scrollTo({ top: panel.scrollTop + overflow + 12, behavior: "smooth" })
  else if (phrase.offsetTop < panel.scrollTop) panel.scrollTo({ top: Math.max(0, phrase.offsetTop - 40), behavior: "smooth" })
}

// Split each typed element into a visible part and a transparent remainder, so
// the text keeps its final size and nothing reflows while it is typed.
function prepareTyping(stage) {
  stage.querySelectorAll("[data-type]").forEach((element) => {
    const text = element.textContent.trim()
    const typed = document.createElement("span")
    typed.className = "hiw-typed"
    const ghost = document.createElement("span")
    ghost.className = "hiw-ghost"
    element.dataset.type = text
    element.replaceChildren(typed, ghost)
  })
}

function clearTyping(element) {
  const [typed, ghost] = element.children
  element.classList.remove("is-typing")
  typed.textContent = ""
  ghost.textContent = element.dataset.type
}

async function type(element, wait, speed) {
  const chars = Array.from(element.dataset.type)
  const [typed, ghost] = element.children
  element.classList.add("is-typing")
  for (let i = 1; i <= chars.length; i++) {
    typed.textContent = chars.slice(0, i).join("")
    ghost.textContent = chars.slice(i).join("")
    await wait(speed)
  }
  element.classList.remove("is-typing")
}

// FLIP: measure, change the layout, then animate each element from where it
// was to where it now is.
function flip(elements, mutate) {
  const before = elements.map((element) => element.getBoundingClientRect())
  mutate()
  elements.forEach((element, index) => {
    const from = before[index]
    const to = element.getBoundingClientRect()
    if (!to.width || !to.height) return
    const dx = from.left - to.left
    const dy = from.top - to.top
    const sx = from.width / to.width
    const sy = from.height / to.height
    const scale = element.classList.contains("hiw-video") ? ` scale(${sx}, ${sy})` : ""
    element.animate([
      { transformOrigin: "top left", transform: `translate(${dx}px, ${dy}px)${scale}` },
      { transformOrigin: "top left", transform: "none" }
    ], { duration: 750, easing: "cubic-bezier(.2,.8,.2,1)" })
  })
}
