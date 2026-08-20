# Adding a New Video Provider

Langlets imports courses from YouTube and TikTok. This is the checklist for
adding a third, written immediately after adding TikTok — so the gotchas listed
here are the ones that actually cost time, not hypotheticals.

Read [Architecture](architecture.md) and [Video Players](video-player.md) first.

---

## The shape of the problem

A provider has to answer six questions. Everything below is a consequence of
one of them:

1. **Is this URL mine?** (`match?`)
2. **Which video is it?** (`video_id`)
3. **What is its one true spelling?** (`canonical`) — dedupe depends on this
4. **Is it real, and what is it called?** (oEmbed)
5. **What does its cover look like?**
6. **How do I play it in a browser, and how do I get a transcript with word
   timings?**

`VideoSource` (`app/services/video_source.rb`) is the only place that knows the
list of providers. **Nothing outside it should reference `Youtube::Url` or
`Tiktok::Url` directly.** If you find yourself adding `if provider == :foo`
somewhere else, that's the signal the abstraction is missing a method.

---

## The three asymmetries that will bite you

YouTube is the easy case, and the codebase was shaped around it. Each of these
was a place where "just add another provider" quietly wasn't enough. Check your
provider against all three **before** writing code.

### 1. Is the video id present in every URL?

YouTube: always. TikTok: **no** — a share link (`vt.tiktok.com/ZSXvNVQwY`)
carries a redirect token, and only the provider's oEmbed can trade it for a post
id. That single fact has consequences everywhere:

- `video_id` must be allowed to return `nil` while `match?` returns `true`. Say
  "it's a TikTok link, I don't know which one yet" rather than lying.
- **Ask `VideoSource.importable?`, never `video_id.present?`**, when the question
  is "can this be pasted". The Add Video sheet rejects the most common paste
  otherwise. Same for the iOS share extension, which checks **host only** on
  purpose.
- Anything that keys a record on a URL must canonicalize **through oEmbed** when
  the id can't be read offline. See `CreateSong::Pipeline.resolve_pipeline_url` — the web
  path gets this free from `Imports::Create`, the rake task had to do it itself,
  and not doing it produced a course with `video_id == nil`: no player, no cover,
  after a full paid pipeline run.

### 2. Is the cover derivable from the id?

YouTube: yes — `img.youtube.com/vi/ID/hqdefault.jpg` is a public static pattern,
which is the only reason a gallery of course cards costs zero network calls.
TikTok: **no** — signed CDN URLs with an expiry, returned only by oEmbed.

The resolution: `courses.thumbnail_url`, nullable, **written only for providers
whose covers can't be derived**. `Course#thumbnail_url` reads the column then
falls back to `VideoSource.derived_thumbnail_url`. That order is why the column
needed no backfill — every pre-existing YouTube row keeps working with a NULL.

If your provider's covers *are* derivable, add the pattern to its `Url` module
and leave the column NULL. If not, capture it in `Imports::Create` (which already
calls oEmbed before charging a credit, so it's free) **and** in
`ImportCourseJob#cover_attributes` for the local rake path.

> Rejected alternatives, for the record: caching oEmbed lookups at render time
> (a cold gallery fires one synchronous HTTP request per card, and covers vanish
> when the cache expires), and a placeholder (TikTok courses look second-class
> everywhere in the catalog).

### 3. Is it 16:9?

TikTok is vertical. Hardcoded `aspect-video` letterboxes it into a stripe. Use
`video_aspect_ratio(course)` / `Course#tiktok?`-style checks in:

- `app/views/lessons/show.html.erb` (`#main-player`)
- `app/views/full_player/show.html.erb`
- `app/views/courses/show.html.erb` (preview iframe)

---

## Ruby: the provider modules

Two files, mirroring `app/services/youtube/` and `app/services/tiktok/`.

### `app/services/<provider>/url.rb`

Pure string work, no network. Must implement:

```ruby
match?(url)          # does this URL belong to me?
video_id(url)        # the id, or nil if it isn't readable offline
canonical(url)       # one spelling per video; drop tracking params
loose_video_id(input)  # video_id + any bare-id form worth accepting
loose_canonical(input)
valid?(url)
thumbnail_url(id, quality)  # only if derivable; otherwise omit
```

**Anchor your host match.** `tiktok\.com/@a/video/123` matched
`nottiktok.com/@a/video/123` until a test caught it — an attacker-chosen host
would have been treated as a post. Use a lookbehind requiring `//` or a
subdomain dot:

```ruby
HOST = /(?<=[\/.])tiktok\.com/i
```

**Be conservative with `loose_video_id`.** Library search runs every query
through `video_id`. TikTok ids are long digit runs, so a loose match would turn
the search "2024" into an id lookup. TikTok's `loose_*` are therefore just the
strict parse.

### `app/services/<provider>/oembed.rb`

One HTTP call. Returns `VideoSource::Video`, raises
`VideoSource::UnavailableVideo` for anything unimportable. It does more than
fetch a title — it is the **availability check that runs before a credit moves**,
the **short-link resolver**, and the **only source of a non-derivable cover**.

Keep `http_get` as a public seam; the tests stub it rather than pulling in
webmock.

### Register it

In `VideoSource`: add to `PROVIDERS` and both `url_module` / `oembed_module`.
That's the whole registration.

**Do not create a new error class.** `VideoSource::UnavailableVideo` is the one
error; `Youtube::Oembed::UnavailableVideo` and `::Video` survive as aliases
because they appear in rescue clauses across the app, and a rescue that silently
stopped catching would fail a paid import instead of showing "video is private".

---

## The player adapter

One Stimulus identifier, `main-video-player`, for every provider. A `provider`
value picks an adapter from `app/javascript/players/`. **Do not add a second
Stimulus identifier** — targets, actions and `data-main-video-player-*`
attributes are spread across four player layouts and every activity partial, and
per-provider identifiers would mean rewriting or duplicating all of them.

Implement the contract in `app/javascript/players/<provider>_adapter.js`:

```
playVideo() pauseVideo() seekTo(s)
getCurrentTime() -> Promise<number>
getPlayerState() -> Promise<number>   // normalize to player_states.js
onStateChange(cb)
destroy()
```

Normalize state to `PlayerState` (`player_states.js`). Those are YouTube's
numbers, written as literals rather than read from the global `YT` object —
which doesn't exist on a page that never loads the YouTube API.

Things the TikTok adapter had to solve that a new iframe player probably shares:

- **No `getCurrentTime()` query.** TikTok only *pushes* `onCurrentTime`, roughly
  once a second, while the controller polls every 100ms. Returning the last
  reported value freezes transcript highlighting between events, so the adapter
  runs an `InterpolatedPlaybackClock`
  (`app/javascript/utils/interpolated_playback_clock.mjs`) that advances position
  by monotonic elapsed time while playing.
- **Seek must update the clock immediately.** The controller seeks and then
  instantly compares position against the segment bounds; a stale pre-seek
  reading ends the segment the moment it starts.
- **Commands before ready are dropped.** Queue and flush on the ready event.
- **Filter `postMessage` by origin *and* `event.source`.** Several players are
  mounted on one page (mini buttons, hidden audio) and would otherwise consume
  each other's events.

Then verify against **all four player layouts** in
[Video Players](video-player.md) — especially the hidden audio-only player,
which is the easiest to forget. *(Open question for iframe providers: whether
audio keeps playing while the container is `display: none`. YouTube does; TikTok
is unverified on device.)*

---

## The pipeline

The pipeline needs one continuous transcript of **timed words**. How you get
there is provider-specific; everything downstream of `force_alignment` is not.
Both current providers converge in `phrasesFromAlignedWords`
(`pipeline/src/alignedWords.ts`) — keep it that way.

| | YouTube | TikTok |
|---|---|---|
| `extract_lyrics` | Supadata + ElevenLabs Scribe, conservative reconciliation; Gemini transcription only if both fail | Supadata + ElevenLabs Scribe, conservative reconciliation; no Gemini URL fallback |
| `force_alignment` | normally reuses reconciled Scribe timings; Supadata-only uses downloaded audio + ElevenLabs, then Gemini, then any checkpointed Scribe timings | normally reuses reconciled Scribe timings; Supadata-only can use downloaded audio + ElevenLabs, then any checkpointed Scribe timings; never sends the post URL to Gemini |

If your provider's transcription returns timings (like Scribe), stash them under
a dedicated `data` key and let `force_alignment` consume them. **Two steps, not
one**, so a run that dies in between resumes without paying for transcription
twice. Arbitrary keys pass through the callback untouched — there's no allowlist.

Provider detection in the pipeline is by hostname (`isTiktokUrl`,
`isYoutubeUrl`), independent of the Ruby side.

Gemini's video-URL path is YouTube-specific. Never label an arbitrary provider
page as `video/mp4`: if the new provider cannot supply timed words and forced
alignment fails, upload actual media bytes to a supported API or fail the step.

If your provider's transcription API can fetch the post URL itself, expect that
to be refused sometimes and plan the audio-upload fallback — and expect the
download itself to need verifying. `downloadYoutubeAudioToTemp` walks five yt-dlp
format specs and rejects any file whose audio is missing or silent, because
TikTok's HEVC renditions download "successfully" with no audible audio.

Two transcript rules that are easy to get wrong:

- **Strip non-speech events.** Scribe returns `[cantando]`, `[Applause]` as
  `audio_event` entries. Square brackets are reserved by the app's token markup.
- **Rebuild the transcript from the words you kept**, never from the response's
  own `text` field. `add_lessons` partitions the transcript by word count against
  those very words, so the two must describe exactly the same thing.

---

## The sweep — everywhere a provider is assumed

Adding TikTok touched ~50 files. Work this list; `grep -rn "youtube" app/ lib/`
is the starting point.

**Import paths** (all four must accept the new provider)
- [ ] `Imports::Create` / `Imports::Preview` — via `VideoSource.fetch`
- [ ] `Api::V1::ImportRequestsController` — the iOS share extension's endpoint
- [ ] `App::ImportRequestsController#resolve` — use `importable?`
- [ ] `GuestImportRequestsController`
- [ ] `CreateSongProgress.run_pipeline` + `ImportCourseJob` — the local rake path, which
      canonicalizes and fetches oEmbed *itself*

**Rendering**
- [ ] every course card (`course_thumbnail_url`), gallery, home, library
- [ ] `seo_helper` — `video_embed_url`, `video_aspect_ratio`, meta images
- [ ] `_video_object.html.erb` structured data (takes `embed_url` / `content_url`,
      not a bare YouTube id)
- [ ] `sitemaps/show.xml.erb` — needs a real `thumbnail_loc` or Google drops the
      entry

**Client**
- [ ] `add_video_controller.js` `VIDEO_PATTERN` — timing only, not authority;
      a share link with no readable id still counts as "finished typing"
- [ ] `youtube_form_controller.js` — legacy admin autofill, YouTube-only

**iOS**
- [ ] `ShareViewController.isSupportedVideo` — **host-only**, deliberately
- [ ] `Info.plist` needs nothing: the activation rule is generic
      (`WebURLWithMaxCount` + text), so the app already appears in any share sheet

**Copy** — `config/locales/{en,he}.yml`: `paste_placeholder`, `url_hint`,
`url_label`, `get_started`, plus hardcoded strings in
`app/views/app/import_requests/web/new.html.erb`.

Two of these sit outside the import flow and were missed when TikTok shipped, so
grep for the provider name rather than trusting this list:
`onboarding.welcome.title` (the first screen a new native user sees) and
`courses.index.hero.lead` (the marketing root's lead paragraph). Both name the
providers explicitly and both have Hebrew counterparts.

---

## Credentials and infrastructure

Check before assuming you need something new:

- **oEmbed** — both current providers are public, no key, no quota.
- **Embed players** — public iframes, no key.
- **CSP** — `config/initializers/content_security_policy.rb` is currently the
  stock commented-out template. If a policy is ever enabled, a `frame-src`
  allowlist naming only some providers breaks the others' iframes **in
  production only**. Check this.
- **API scopes** — vendor keys are often scoped per endpoint. The existing
  `ELEVEN_LABS_KEY` was only ever used for forced alignment; speech-to-text is a
  different permission. Probe without spending money by POSTing with no
  payload — `400 validation_error` means the scope is fine, `401
  missing_permissions` means it isn't.

To measure what a run actually costs: `GET /v1/user/subscription` returns
`character_count`. Snapshot, import, diff.

---

## Testing

Mirror `test/services/video_source_test.rb` and `test/services/tiktok/url_test.rb`:

- provider routing, and that it **claims nothing else** (this is what caught the
  unanchored host regex)
- id / canonical for every URL form, including tracking params
- `importable?` true for a share link whose `video_id` is nil
- `derived_thumbnail_url` nil when covers aren't derivable
- oEmbed with `http_get` stubbed — resolution, cover, and failure modes
- `Course#thumbnail_url` both branches (stored vs derived)
- an end-to-end API import of a share link (`test/controllers/api/v1/…`) — the
  path the share extension actually uses
- pipeline: a step test proving the provider **doesn't** call the other
  provider's services, plus that word timings and character indexes survive

**Don't assert on user-facing copy.** Assert behaviour — whether the import
action is offered, not the wording of the error beside it.

---

## Known gaps

Carried over from the TikTok work; worth closing if you touch these areas.

- The legacy `ImportCourseJob` path leaves `youtube_video_id` NULL.
  `Course#video_id` falls back to parsing `main_media_url`, so playback and
  covers work, but those courses aren't covered by
  `idx_courses_published_video_language`. Populating it would turn a repeat
  import by a different user into a raise rather than a silent duplicate.
- `youtube-form` (legacy admin form) autofills name/slug for YouTube only.
- TikTok playback is unverified on a real device: audio while the container is
  hidden, and the iOS share flow end to end.
- `courses.youtube_video_id` / `import_requests.youtube_url` keep their names but
  hold any provider's value. `youtube_video_id` backs the dedupe index, so
  renaming is a migration, not a rename.
