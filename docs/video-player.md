# Video Players

Langlets is built around YouTube videos: every course is created from a YouTube
URL, and most activities replay short segments of that video. Because of this,
the app contains **several different video players**, each tuned for a different
use case. They share a common engine but differ in layout, visibility, and
interaction.

> **Important:** When you add or change a feature that touches video playback,
> you must consider **all four** player types below. They all run through the
> same `main-video-player` Stimulus controller, so a change to the controller
> (or to the events it dispatches) can affect any of them. A change that "works"
> in the full player may silently break the hidden audio player used by
> activities, and vice versa.

## The shared engine

The single source of truth is the
[`main-video-player`](../app/javascript/controllers/main_video_player_controller.js)
Stimulus controller. It wraps the [`youtube-player`](https://www.npmjs.com/package/youtube-player)
library and is responsible for:

- Lazily creating the YouTube iframe (on first `playSegment`, or eagerly when
  `preloadPlayer` is set).
- Playing a **segment** of the video (`segmentStart` → `segmentEnd`) rather than
  the whole thing.
- Monitoring playback every 100ms and dispatching `video:*` events
  (`play`, `stop`, `progress`, `end`) to any element marked as a
  `videoListener` target.
- Driving a progress bar / scrubber and handling seek-on-click.

Everything else listed here is a **consumer** of this engine — a different DOM
layout and a different set of listeners wired to the same controller. The four
players differ in *how the iframe is shown* and *who listens to its events*,
not in the underlying playback logic.

The four configurations are:

1. Main (full) video player
2. Watch-video activity (mini player)
3. Hidden audio-only player (most activities)
4. "Mini" layout player (e.g. order-phrases)

---

## 1. Main video player — the full course video

**Where:** [`app/views/full_player/show.html.erb`](../app/views/full_player/show.html.erb)

This is the large hero player a learner sees when they open a course and watch
the complete video. It is the most "video-like" of the players:

- A full-width `aspect-video` iframe preloaded with YouTube's native controls.
- No custom click overlay, play button, time display, or scrubber is placed over
  the iframe, so all native YouTube interactions remain available.
- Course navigation sits below the iframe rather than obscuring its controls.
- Below the video, a synchronized, scrollable word-by-word transcript that
  highlights the current line as the video plays (driven by the
  [`watch-video-activity`](../app/javascript/controllers/watch_video_activity_controller.js)
  controller listening to `video:progress`).

> **Karaoke word highlighting.** When the song's token translations carry
> per-word timestamps (the word-timing pipeline), the transcript additionally
> highlights the single word currently being sung (`.s-token-active`). This is
> gated by the `word-timing` Stimulus value, which Rails sets from
> `word_timing_enabled?(phrases)` — true only when at least one token has a
> `start_timestamp`. Older songs (tokens without timestamps) keep line-only
> highlighting. Each token span exposes `data-token-start` / `data-token-end`
> (seconds); `updateWordHighlight` toggles the active class on the span whose
> window contains the current time.

It plays the whole video as one big segment (`segment-start` → `segment-end`
spanning the full course). The shared controller still observes native player
state changes and emits the `video:*` events used by the transcript.

The full-course segment ends at the latest persisted phrase-token end timestamp,
so the final spoken word is not cut off. Courses without word timing fall back
to the final phrase's start timestamp, preserving legacy behavior. At that
boundary, the shared controller pauses and seeks back to the segment start; the
native play control then replays the full video.

---

## 2. Watch-video activity — its own mini player

**Where:** [`app/views/activities/_watch_video_activity.html.erb`](../app/views/activities/_watch_video_activity.html.erb)
and [`watch-video-activity`](../app/javascript/controllers/watch_video_activity_controller.js)

This is an activity inside a lesson where the learner watches a **segment** of
the course video before practicing. Visually it reuses the same hero player as
the main player (the iframe lives in the shared lesson layout —
[`app/views/lessons/show.html.erb`](../app/views/lessons/show.html.erb) —
under the `#main-player` container), but:

- It is scoped to the activity's `segmentStart`/`segmentEnd`, not the full video.
- It preloads an interactive iframe and uses YouTube's native controls. The
  shared lesson layout does not render its custom click overlay, play button,
  time display, or progress bar for this activity.
- If the native play control starts playback before the activity's first
  phrase, its `video:play` listener immediately seeks to the segment start.
  Playback already within the segment is left unchanged so pause/resume and
  transcript seeks continue from the selected time.
- When the segment finishes, the player pauses and rewinds to its start so the
  next press of YouTube's play control replays the lesson.
- It shows the synchronized transcript, a translation toggle, and a
  "Start practice" button that appears once the segment finishes
  (`handleVideoEnd` reveals it and awards XP).

The player container is shown for this activity because the lesson layout
renders `#main-player` visibly when `activity_params[:video_player]` is set.

---

## 3. Hidden video player — audio for activities

**Where:** the `#main-player` container in
[`app/views/lessons/show.html.erb`](../app/views/lessons/show.html.erb), rendered
with the `hidden` class when the activity does **not** request a visible player.

Most practice activities (listen, audio-to-translation, match-phrases, etc.)
don't show any video at all — they only need the **audio** of a phrase. For
these, the same `main-video-player` controller creates the YouTube iframe but the
container is kept hidden via CSS:

```erb
class="<%= activity_params[:video_player] ? 'order-2 flex-shrink-0' : 'hidden' %>"
```

The activity then plays a short segment to make the learner *hear* a phrase,
while the iframe itself stays off-screen. The activity controllers listen for
`video:progress` / `video:end` to drive their UI (highlighting words, advancing,
checking answers) and call `main-video-player#playSegment` / `#stopPlayback` to
control audio. From the learner's perspective there is "no video" — just sound.

This is the easiest player to forget: a change to the controller's iframe
creation, autoplay handling, or event dispatching directly affects the audio
that every non-video activity depends on.

---

## 4. "Mini" layout player — for activities like order-phrases

**Where:** the
[`_mini_video_player`](../app/views/activities/_mini_video_player.html.erb)
partial and the
[`mini-player`](../app/javascript/controllers/mini_player_controller.js)
controller; used inline by activities such as
[`_word_order_activity`](../app/views/activities/_word_order_activity.html.erb)
and [`_listen_activity`](../app/views/activities/_listen_activity.html.erb).

Some activities need an inline, compact playback control rather than a full video
or pure hidden audio. The mini layout is a small horizontal bar (or an inline
speaker button) with:

- A play/pause button wired to `main-video-player#playSegment` /
  `#stopPlayback` with per-segment `segment-start`/`segment-end` params.
- A thin progress bar (`progressBar` target) that fills as the segment plays.

The lightweight `mini-player` controller only toggles the play/pause button
visuals in response to `video:play` / `video:stop`. The order-phrases activity
embeds an even smaller variant — a single round speaker button on each phrase
card that triggers `playSegment` for that phrase's timestamps.

---

## Common characteristics & differences

All four players:

- Run through the **same `main-video-player` controller** and the same
  `youtube-player` library.
- Play **segments** (`segmentStart` → `segmentEnd`), not arbitrary playback.
- Communicate via the **`video:*` custom events** (`play`, `stop`, `progress`,
  `end`) dispatched to `videoListener` targets.
- Share progress-bar conventions (`progressBar` target, `seekToPosition`).

They differ in:

| Player | Visible? | Layout | Primary purpose |
|---|---|---|---|
| Main video player | Yes (large hero) | `full_player/show` | Watch the full course video |
| Watch-video activity | Yes (hero) | `_watch_video_activity` | Watch a segment, then practice |
| Hidden audio player | No (`hidden`) | `lessons/show` `#main-player` | Audio-only for practice activities |
| Mini layout player | Yes (compact bar/button) | `_mini_video_player`, order-phrases | Inline replay control |

### When building new features

Because all of these share one controller and one event contract, **any change
to video playback must be checked against every player type**:

1. Will it work when the player is **hidden** (audio-only activities)?
2. Will it work for the **full hero** layout and its scrubber/transcript?
3. Will it work for the **compact mini** layout and the inline speaker buttons?
4. Does it preserve the **`video:*` event contract** that activity controllers
   rely on?

If you add a new event, value, or target to `main-video-player`, audit each of
the views listed above and update them as needed.
