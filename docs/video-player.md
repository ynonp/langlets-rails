# Video Players

Langlets is built around short online videos: every course is created from a
YouTube or TikTok URL, and most activities replay short segments of that video.
Because of this, the app contains **several different video players**, each tuned
for a different use case. They share a common engine but differ in layout,
visibility, and interaction.

> **Important:** When you add or change a feature that touches video playback,
> you must consider **all five** player layouts below. They all run through the
> same `main-video-player` Stimulus controller, so a change to the controller
> (or to the events it dispatches) can affect any of them. A change that "works"
> in the full player may silently break the hidden audio player used by
> activities, and vice versa.

## The shared engine

The single source of truth is the
[`main-video-player`](../app/javascript/controllers/main_video_player_controller.js)
Stimulus controller.

### Two providers, one controller

There is **one Stimulus identifier**, `main-video-player`, for both YouTube and
TikTok. The provider is chosen by a `provider` value (defaulting to `youtube`,
so any view that omits it behaves exactly as before), and the controller
delegates playback to an adapter in
[`app/javascript/players/`](../app/javascript/players/):

| | |
|---|---|
| `youtube_adapter.js` | wraps [`youtube-player`](https://www.npmjs.com/package/youtube-player) |
| `tiktok_adapter.js` | drives a `tiktok.com/player/v1/<id>` iframe over `postMessage` |

Both expose the same contract — `playVideo` / `pauseVideo` / `seekTo` /
`getCurrentTime` / `getPlayerState` / `onStateChange` / `destroy` — and normalize
state to `player_states.js` (YouTube's numbering, which TikTok happens to share).
**Everything above the adapter boundary is provider-agnostic**, which is why the
activity partials, targets, actions and `video:*` events are identical for both
and why splitting into `main-youtube-player` / `main-tiktok-video-player`
identifiers was rejected: it would have forced every
`data-main-video-player-*` attribute and every `main-video-player#action` in the
player layouts to be rewritten or duplicated per provider.

Two TikTok differences are worth knowing before you debug playback:

- **There is no `getCurrentTime()` query.** TikTok only *pushes* `onCurrentTime`
  while playing, sometimes about a second apart. The adapter interpolates the
  position with a monotonic clock between those authoritative updates, then
  resynchronizes when the next one arrives. This lets the controller's 100ms
  polling drive transcript, karaoke, progress, and segment boundaries smoothly.
  `seekTo` updates the clock immediately because the controller seeks and then
  immediately compares the position against the segment bounds.
- **Commands sent before `onPlayerReady` are dropped**, so the adapter queues and
  flushes them.

Not yet verified on device: whether TikTok's iframe keeps playing audio while its
container is `display: none` (the hidden audio-only player, #3 below). YouTube
does. If it does not, that player needs off-screen positioning instead.

The controller is responsible for:

- Lazily creating the provider's iframe (on first `playSegment`, or eagerly when
  `preloadPlayer` is set).
- Playing a **segment** of the video (`segmentStart` → `segmentEnd`) rather than
  the whole thing.
- Pausing playback and stopping segment monitoring before Turbo replaces an
  activity frame, then synchronizing the controller with the newly rendered
  activity's segment boundaries.
- Monitoring playback every 100ms and dispatching `video:*` events
  (`play`, `stop`, `progress`, `end`) to any element marked as a
  `videoListener` target.
- Driving a progress bar / scrubber and handling seek-on-click.

Everything else listed here is a **consumer** of this engine — a different DOM
layout and a different set of listeners wired to the same controller. The five
players differ in *how the iframe is shown* and *who listens to its events*,
not in the underlying playback logic.

The five configurations are:

1. Main (full) video player
2. Watch-video activity (mini player)
3. Hidden audio-only player (most activities)
4. "Mini" layout player (e.g. order-phrases)
5. Flashcard player (course and review lessons)

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

> **Shared transcript UI.** The header controls (karaoke checkbox, translate
> icon, copy icon) and the word-by-word transcript/translation-popup are the
> same partials the watch-video activity uses (#2, below) —
> [`shared/_video_transcript_header`](../app/views/shared/_video_transcript_header.html.erb)
> and
> [`shared/_video_transcript_phrases`](../app/views/shared/_video_transcript_phrases.html.erb).
> They used to be copy-pasted per view, which let them drift (e.g. this page's
> translate toggle went stale and its transcript container was missing the
> `saved-ids-url`/`saved-token-classes` values and the translation-pause
> bindings that #2 had). Change either partial and both players pick it up;
> each caller only supplies its own wrapper classes (`header_class`,
> `container_class`), an optional `leading` slot (this page's back-to-course
> button), and the `word_timing`/`wv_prefs`/`phrases`/`l1_rtl`/`l2_rtl`/
> `saved_ids_url` locals. The bottom CTA stays per-view since the two pages
> want different actions (go to the first lesson here vs. this activity's
> "Start practice").

The course page opts the "Watch full video" link out of Turbo hover prefetch.
Opening the route loads the complete phrase/token/translation/audio graph, so a
pointer resting over that link must not trigger the work during an unrelated
course-page refresh. The controller materializes that eager-loaded relation
once before reading its first/last phrase or token boundaries, and reuses the
first lesson selected for the medium when rendering the practice action.

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
- It preloads an interactive iframe and uses the provider's native controls. The
  shared lesson layout renders no chrome of its own over the iframe — see the
  note below.
- If the native play control starts playback before the activity's first
  phrase, its `video:play` listener immediately seeks to the segment start.
  Playback already within the segment is left unchanged so pause/resume and
  transcript seeks continue from the selected time.
- Clicking a transcript word pauses playback while its translation popup is
  open. The popup's existing element/document click actions keep the opening
  click local; an outside click closes the popup and resumes the segment. Word
  clicks do not seek, while clicks elsewhere on the sentence seek to its
  timestamp. The activity tracks `video:play`/`video:stop` and only records a
  translation-owned pause when playback was active, so a popup opened over an
  already paused video does not resume it later. Clicking a word while the
  popup is open closes it and resumes only when the popup initiated the pause.
- When the segment finishes, the player pauses and rewinds to its start so the
  next press of YouTube's play control replays the lesson.
- It shows the synchronized transcript, a translate icon (colored when
  translation is on) and a copy icon that copies the currently shown
  language's transcript to the clipboard — both from the shared header
  partial described under #1 above — and a "Start practice" button that
  appears once the segment finishes (`handleVideoEnd` reveals it and awards
  XP).

The player container is shown for this activity because the lesson layout
renders `#main-player` visibly when `activity_params[:video_player]` is set.

### Listen activity playback

`ListenActivity` uses this same visible, preloaded, interactive lesson player.
The provider's native Play control starts the exercise; the activity has no
separate mini-player button. A short instruction remains visible until the
shared player emits `video:play`, and that event also applies the normal segment
start guard.

Below the video, the activity keeps only the current and next lyric lines in a
two-row clipped stage. Moving to the next phrase translates both rows upward.
For new courses where every phrase token has a start timestamp, words are
revealed as `video:progress` reaches their individual timestamps. Playback
pauses immediately before an unanswered missing token, then reveals that
token's translation and two answer choices. A correct choice fills the blank
and resumes playback. If any token lacks timing, the activity uses the legacy
phrase timestamps instead: the current row is highlighted, choices appear when
its phrase starts, and an unanswered blank pauses playback at the phrase end.
This fallback deliberately requires complete word timing rather than mixing
word and phrase behavior within one exercise.

### Arriving here by Turbo-Frame navigation

The lesson layout bakes `preload_player` / `interactive_video_player` into
`#main-player` once, from whichever activity the page first loaded on. Anything
that describes the *medium* rather than the activity therefore belongs on the
controller, not in `activity_params` — `@videoid`, `@video_provider`, and
`@video_hl` are all set in `LessonsController#show`. (`video_hl` used to come
from `activity_params`, which left the player's interface language blank on any
lesson that opened on an activity without video params.) When the
watch-video activity is not the lesson's first activity — it now follows
`ReadTranslatedActivity` — the page loads with no player at all, and
`connect()` never runs again for the frame navigation into it. `handleFrameRender`
therefore unhides the container and creates the iframe on the spot.

**Do not seek or pause a player that has never played.** Calling `seekTo` on a
YouTube player that has never played drops it from `CUED` back to `UNSTARTED`,
clearing its poster image and play button and leaving a dead black rectangle the
learner cannot start. `handleFrameRender` therefore gates its reposition on
`this.hasPlayed`, which the controller sets the first time the player reports
`PlayerState.PLAYING`. A player that has never played is left cued, and the
`video:play` → `seekToSegmentStartIfBefore` listener moves it to the segment
start when the learner presses play.

> This gate must key off **playback**, not off "was the player created during
> this frame render". An earlier version checked the latter, which missed the
> common case: when the lesson opens directly on the watch-video activity,
> `preload_player` makes `connect()` build the iframe, so a learner who reads
> the lyrics without pressing play, moves to another activity, and comes back
> arrives with the player already initialized but never played — and the
> reposition killed it. Repro: open `?a=1`, wait for the poster, click `2`,
> `3`, then `1`.

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

> **The lesson layout has no custom player chrome.** It used to render a click
> overlay, a round play button, an elapsed/total time display, and a scrubber,
> all gated on `unless activity_params[:interactive_video_player]`. That gate
> could never open: `video_player` is only ever true for
> `watch_video_activity`, which also sets `interactive_video_player: true`, so
> the container was either hidden (no `video_player`) or interactive (native
> controls). The markup and its controller methods — `togglePlayPause`,
> `showPlayButton`, `hidePlayButton`, `fullPlayerStartPlayback`,
> `fullPlayerStopPlayback`, `updateTimeDisplay`, `formatTime` — plus the
> `playButton` / `pauseButton` / `timeElapsed` / `timeDuration` targets have
> been removed. The **mini** layout (#4) keeps its own play/pause buttons and
> scrubber, so `progressBar`, `updateProgressBar`, and `seekToPosition` are
> still live and must not be removed with them.

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

### Flashcard video

The cloze flashcard in both course and review lessons is another visible use of the shared
engine. It renders `shared/_video_media_box` above the exercise and sends the
current card's provider, video id, and phrase bounds to `main-video-player`.
Course flashcards use their lesson's medium;
review cards can come from different courses,
so changing cards may destroy the old adapter and initialize the card's
original source. Native play is constrained to the phrase; the ordinary
segment-end behavior pauses and rewinds it for replay.

---

## Common characteristics & differences

All five player layouts:

- Run through the **same `main-video-player` controller**, over whichever
  provider adapter the `provider` value selects.
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
| Flashcard | Yes (hero) | `lessons/show`, `review_lessons/show`, `_flashcard_activity` | Replay the cloze word's source phrase |

### Aspect ratio

The watch-video activity, full player, and flashcard render the shared
[`shared/_video_media_box`](../app/views/shared/_video_media_box.html.erb)
partial, which always reserves `clamp(160px, 30vh, 280px)` for its sticky
media area, regardless of provider. This makes the media height predictable
on iOS in both orientations and caps how much of the screen a portrait
(TikTok) video can claim — a bug fix, since the full player previously used a
provider-shaped hero (a viewport-capped `9/16` box for TikTok, `aspect-video`
for YouTube) that let portrait videos grow up to `55vh`. Native video
defaults to `object-cover` with its focal point biased upward;
`loadedmetadata` marks landscape sources so they switch to `object-contain`.
YouTube and TikTok iframes fill the same fixed box.

The course page preview ([`courses/show.html.erb`](../app/views/courses/show.html.erb),
outside these two players) remains provider-shaped: it sets `aspect-ratio`
from `video_aspect_ratio` (`9/16` for TikTok, `16/9` otherwise) and caps
TikTok's width at `280px` so the box doesn't grow tall.

### When building new features

Because all of these share one controller and one event contract, **any change
to video playback must be checked against every player type**:

1. Will it work when the player is **hidden** (audio-only activities)?
2. Will it work for the **full hero** layout and its scrubber/transcript?
3. Will it work for the **compact mini** layout and the inline speaker buttons?
4. Does it preserve the **`video:*` event contract** that activity controllers
   rely on?
5. Does it work on **both provider adapters** — not just the YouTube one?

If you add a new event, value, or target to `main-video-player`, audit each of
the views listed above and update them as needed.
