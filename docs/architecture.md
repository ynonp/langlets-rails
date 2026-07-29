# Langlets - Language Learning Platform Architecture

## Project Overview

**Langlets** is a Rails-based language learning platform that creates interactive activities from multimedia content (primarily YouTube videos) with synchronized bilingual text, word-level translations, and various learning exercises. The platform is branded as "MúsicaLingo" and focuses on song-based language learning.

## Technology Stack

- **Framework**: Ruby on Rails 8.0
- **Database**: PostgreSQL with JSONB support
- **File Storage**: Active Storage (local/cloud)
- **Frontend**: Rails views with JavaScript
- **Background Jobs**: Rails queue system
- **Package Management**: Bun (JavaScript), Bundler (Ruby)

## Core Architecture

### Channels

Every User owns one private default Channel, provisioned atomically with the
account and recoverable through `User#provision_default_channel!`. Channels are
language-neutral publishing identities, not course ownership: `courses.user_id`
remains historical creator data, while `ChannelItem` determines which identity
contributed a Course. A unique partial index guarantees one default per owner,
and `[channel_id, course_id]` makes publishing safe to retry.

Visibility is `private`, `shared`, or `public`. Private content is readable only
by its owner and administrators. Shared Channels are invite-only and become
readable only after an email-bound, expiring invitation is accepted and creates
a `ChannelSubscription`. Public Channels are ordinary administrator-owned
Channels and are readable by every signed-in user without a subscription; there
are no system Channels. Moving a Channel to private transactionally revokes
pending invitations and removes non-owner subscriptions. Only administrators
may transition a Channel to or from public.

`ChannelContentQuery` is the common authorization and feed boundary used by
native Home and Library. It selects ChannelItems from the union of public,
subscribed, and owned Channels, applies Course publication, translation
readiness, and optional learning-language filters, and orders contributions by
`channel_items.published_at`. It intentionally keeps two rows when two Channels
publish the same Course while avoiding duplicates from overlapping access
paths. Cards include the contributing Channel identity. Reading Channel content
never creates an Enrollment; enrollment remains personal learning state.

`Imports::Settlement.complete!` transactionally ensures both the existing
Enrollment and an idempotent ChannelItem in the importing user's default
Channel before marking an ImportRequest ready. The channel migration backfills
defaults and successful ready imports with set-based, restart-safe SQL, using
the earliest successful request timestamp per Channel/Course as the publication
time. A follow-up SQL-only migration handles published Courses that predate
ImportRequest: if such a Course has no ChannelItem anywhere, it is assigned to
its historical creator's default private Channel with `courses.created_at` as
the best available publication timestamp. This fallback never changes Channel
visibility and never adds a second contribution to an already assigned Course.

The Profile page manages the current default Channel's name and private/shared
visibility. Shared owners can invite multiple normalized email addresses,
resend or revoke pending invitations, and remove members. Invitations are
delivered by email and also appear in the authenticated invitations list when
the address matches an account. `/channels/:slug` returns 404 for unauthorized
private/shared access; a valid pending invitee sees only Channel identity and
accept/decline controls until acceptance. Administrators manage public Channels
under `/admin/channels`.

### Full-course video playback

The full player preloads an interactive YouTube iframe with native controls. It
loads every phrase from the course medium and plays one segment from the first
phrase start through the latest phrase-token end timestamp. This
keeps the final word audible when word timing is available. Legacy courses with
no token timing use the final phrase start as their endpoint. The shared
`main-video-player` Stimulus controller continues to enforce that server-derived
segment boundary and dispatch synchronized transcript progress events. The view
does not place custom playback chrome or click-capturing overlays over the
iframe. When the full-course
segment ends, the controller pauses and rewinds to its start, making the next
play action replay the complete video.

The phrase relation is materialized immediately after its translations, tokens,
and token audio are preloaded. Boundary calculations and rendering then reuse
that same in-memory graph; calling `first` on an unloaded eager-loaded relation
would otherwise load the first phrase and its associations separately before
loading the complete transcript. The course page's full-player link disables
Turbo hover prefetch because this route intentionally hydrates the entire
transcript and should run only when the learner chooses it. The controller also
retains the first ordered lesson used to resolve the medium and passes it to the
practice button, avoiding separate lesson-existence and first-lesson lookups in
the view.

### Watch-video activity playback

Watch-video activities preload an interactive YouTube iframe with YouTube's
native controls. Their activity parameters opt into this mode, so the shared
lesson player omits its click-capturing overlay and custom play/progress chrome
while retaining the activity's segment boundary and `video:*` event contract.
Opening a word-translation popup pauses the shared player. The token click is
stopped before it reaches the document action, so playback stays paused while
the popup is open; the next outside click closes the popup and resumes the
segment. The watch-video controller tracks the shared player's play/stop events
and only marks a translation pause when playback was active, so opening a popup
while the video is already paused cannot make a later outside click start it.
Translation-token clicks are
also excluded from the shared phrase-seek action; only clicks elsewhere on the
sentence move playback to that phrase. Clicking a word while the popup is open
closes it and resumes playback.
When native playback begins before the activity's first phrase, the activity's
play listener seeks forward to the segment start; playback already at or after
that boundary is not moved.
At the segment end, the shared controller emits `video:end`, pauses, and seeks
back to the segment start so the native play control replays the lesson.
Hidden and compact activity players remain on the custom controls path.

TikTok publishes its current playback position less frequently than the shared
player's 100ms progress polling. Its adapter keeps an interpolated monotonic
clock between authoritative `onCurrentTime` messages and resynchronizes whenever
TikTok sends a new position. This keeps transcript, karaoke, progress, and
segment boundaries moving continuously without changing stored timestamps.

### Homepage language selection

The public homepage honours the optional `lang` query parameter by initially
selecting the matching "Jump right in" client-side filter while still rendering
all available language pills. Unknown language codes are ignored and the grid
shows all languages. Picking a pill rewrites `?lang=` via `history.replaceState`,
so the address bar keeps matching what is on screen and the view stays
shareable and reload-safe. The
redesigned landing page no longer renders a per-language header subhead, so the
`homepage_subhead` helper and the `subhead.<iso>` locale copy it reads are
currently unused by the UI (kept in place for possible reuse).

### Where the learning language lives

`ApplicationController#current_language_code` resolves the language of learning,
and the two clients store it differently:

- **Web** keeps it in the URL alone. `default_url_options` merges `lang` into
  every generated URL, so the selection follows the user across links, while
  removing the param — or passing `?lang=all` — clears it. Nothing is written
  server-side, so there is no hidden state that outlives the address bar.
- **Native** picks a language during onboarding and must keep it across app
  launches, so `persist_native_language` writes it to `user.ios_lang`
  (a key in the `users.preferences` JSON) and `current_language_code` reads it
  back for signed-in native requests.

This deliberately gives signed-in web users no persistence: their selection is
per-URL, not per-account. `users.preferred_language_id` exists in the schema
with an FK and index but is currently unused; it is the natural home if durable
per-account language ever becomes a requirement.

Earlier revisions cached the selection in `session[:lang]`. Combined with
`default_url_options` re-adding the param to every link, that made the language
impossible to clear from the UI — a reload kept serving the stored language and
guests had no control that reached the session. The session copy has been
removed; do not reintroduce it without also providing a clear path.

### Public homepage (`courses#index`)

The web root (`courses#index`, rendered for everyone except signed-in native
users, who are redirected to `app_home_path`) is a self-contained warm-cream
marketing landing page imported from the Claude Design project "Langlets
Homepage". It deliberately opts **out** of the app's light/dark theme: the whole
page lives inside a `.lp` wrapper with a bespoke fixed palette and its own
scoped `<style>` block (no `dark:` utilities, no theme toggle). Bricolage
Grotesque (display) and Instrument Sans (body) load from Google Fonts in the
page's `content_for :head`. The base anchor rule is zeroed with
`:where(.lp a)` so each component sets its own link colour without a
specificity war.

Every string on the page — including the `<title>` and the Open Graph
title/description — is localized under `courses.index.*` (`meta`, `nav`, `hero`,
`library`, `create_your_own`, `footer`), so `he.langlets.app` renders a fully
Hebrew landing page. The page is laid out with logical properties where
direction matters (`inset-inline-start`, `padding-inline-start`), and the offset
drop shadow on the product frame is mirrored under `[dir="rtl"]`. Everything
else flips for free because the layout is grid/flex.

The homepage **does not sell anything**. It carries no pricing section, no
PayPal form and no free-credit copy; nothing on it mentions credits, prices or
"free". Purchases live only on the in-app credit surfaces (see *Credits and
PayPal*). Do not reintroduce a pricing block here without being asked.

Sections, all wired to real data:
- **Nav** — brand, the `#library` in-page anchor, and auth-aware controls:
  signed-out visitors get *Sign in*; signed-in get *Add a video* / *Sign out*.
- **Hero** — the marketing introduction sits beside the static
  `public/product.png` product preview. At the mobile breakpoint, its supporting
  subhead is hidden to bring the library closer to the first viewport; the
  headline and product preview remain visible.
- **"Jump right in" library** — the dark grid renders the newest
  `@all_courses` contributed through Channels visible to the viewer, mixing
  courses that belong to playlists with courses that do not. Signed-out viewers
  receive public Channel content only; signed-in viewers additionally receive
  owned and subscribed Channel content. Playlist membership does not affect
  inclusion or ordering.
  Language filter chips are derived from the complete available course set and
  filter the grid client-side via the `homepage-filter` controller (each card
  carries `data-lang`; no server round-trip). Chips only appear when more than
  one language is present.
- **"Create Your Own"** — the last content section, following the library. Two
  columns: the heading, lead, the call to action and the "ready in ~3 minutes"
  line on the left (sticky while the section scrolls), and a four-step
  numbered explainer on the right
  ("One click, fully automatic" → "Build your personal vocabulary"), whose
  markers are joined by a connector. Both columns stack below 860px. The four
  steps are rendered by iterating their key names under
  `courses.index.create_your_own.steps`.

  The call to action differs by session. Signed-in users get the
  paste-a-YouTube-link box, which GETs directly to `new_app_import_request_path`
  (`turbo: false`) with the current learning language in a hidden `lang` field.
  Guests are not asked for a link at all — they get a single **Sign in**
  button, because a pasted link is worthless until there is an account to spend
  a credit from. It POSTs (no `url`) to `GuestImportRequestsController`, which
  stores a marker for one day in the encrypted, HTTP-only
  `pending_import_request` cookie and redirects to `new_user_session_path`. The
  day-long TTL covers the confirmation email round-trip, since `User` is
  `:confirmable` and the first real sign-in happens after the user clicks that
  link.

  `ApplicationController#pending_import_path` resolves both guest markers and is
  consulted first by `after_sign_in_path_for` / `after_sign_up_path_for` (the
  latter is also overridden in `Users::RegistrationsController`). It consumes
  the cookie and sends that one authentication to Add Video; every later sign-in
  falls back to `returnto` / `omniauth.origin` / the homepage as usual. The
  older `pending_video_url` cookie still works the same way and additionally
  prefills the URL — `GuestImportRequestsController#create` keeps honouring a
  posted, canonicalized link even though the homepage no longer sends one. From
  Add Video the existing resolver asks for the clip language before its normal
  one-credit import POST redirects to Queue.
- **Footer** — copyright plus `/home/privacy` and `/home/terms`.

The controller's existing `@playlists` / `@recommended_courses` assigns are left
intact (still used for structured data and available for future sections) even
though the landing page itself only consumes `@all_courses` and
`@continue_learning_courses`.

The homepage's Open Graph and Twitter large-card metadata uses the dedicated
`public/cover.png` social sharing image. Its exact dimensions are supplied to
the shared SEO helper, alongside homepage-specific copy focused on turning
videos into comprehensible input and spaced-repetition practice. Other pages
retain the helper's video-thumbnail dimension defaults.

Canonical, Open Graph, Twitter, hreflang, and structured-data URLs preserve the
localized request host through `SeoHelper#canonical_url`. The allowed canonical
host whitelist is deliberately limited to `langlets.app` and
`he.langlets.app`; any other request host falls back to `langlets.app` so an
unexpected Host header cannot leak into public metadata. When adding another
localized subdomain, add it to `SeoHelper::CANONICAL_HOSTS` and extend the
canonical metadata tests at the same time.

### Search engine exclusion

The site is deliberately kept **out of search engines**, everywhere, on every
page. Two independent mechanisms enforce it and both must stay in place:

- `public/robots.txt` is a blanket `User-agent: * / Disallow: /`. It no longer
  advertises the sitemap.
- `app/views/layouts/_head.html.erb` emits `<meta name="robots"
  content="noindex, nofollow">`, so every page rendered through the
  `application`, `app`, and `onboarding` layouts is marked unindexable. This is
  the belt to robots.txt's braces: robots.txt stops the crawl, the meta tag
  stops indexing of URLs a crawler already knows about. Two views
  (`review_lessons/show`, `lessons/finish`) additionally set their own
  `noindex, follow` tag; the more restrictive directive wins, so they are
  harmless.

Caveat inherent to the combination: a URL blocked in robots.txt is not fetched,
so a crawler may never see the `noindex` tag. Already-indexed URLs can linger as
link-only results until removed via the search console. To force removal faster,
temporarily allow crawling so the `noindex` is actually read.

The SEO machinery around this (canonical URLs, hreflang, Open Graph/Twitter
cards, JSON-LD structured data, `/sitemap.xml`) is left intact. Those tags still
drive link previews when a page is shared in a chat app, which is unrelated to
indexing. `/sitemap.xml` still renders but is no longer referenced anywhere.

The "Jump right in" grid is a preview rather than the full catalog. It renders
the eight most recently created courses for the selected language, or the eight
most recently created courses across all languages when **All** is selected.
Playlist membership has no effect. The grid uses four columns on larger screens
and two compact columns on phones. Its filter pills are derived from the
complete available course set rather than only the visible eight cards. Both
the navigation's "Browse Langlets" item and the grid's "Browse All Langlets"
action lead to `/gallery`.

### Public gallery (`gallery#index`)

`/gallery` is the complete browsing surface. Its Course authority is ChannelItems
rather than `Course.published` alone: signed-out viewers see public Channels,
while signed-in viewers see public, subscribed, and owned Channels. Content
outside that viewer-specific set does not leak into filters, counts, playlists,
or cards. Courses and playlists share
one reverse-chronological, 16-item page rather than appearing in separate tabs.
Its YouTube-style filter bar remains a GET form and keeps filter state in the
URL. Text input is debounced for 300 ms; content and language pills submit
immediately. Both kinds of pills share one unlabeled, wrapping row and use the
same rounded chip treatment as the homepage language filters. The page heading
is "Start A Language Practice"; navigation is provided by the Langlets brand
link without a separate back-home action. All interactive requests ask for Turbo Streams and replace only
the results/count/pagination region, while an ordinary GET remains the
no-JavaScript fallback. `search` matches course/localized course names or
playlist names/descriptions. The `types[]` and `languages[]` pills are
multi-select: no selection means all, selected languages combine with OR, and
selecting one content type excludes the other. The result count and
"Clear Search" action appear only when text search is active; clearing text
preserves pill selections. Playlists follow `Playlist.visible_to`, so anonymous
visitors see published system playlists while signed-in visitors additionally
see their own.

Mixed pagination is performed in PostgreSQL with a `UNION ALL` of lightweight
course and playlist rows before `LIMIT`/`OFFSET`. Only the records for the
current page are hydrated. Course languages, localized translations, lesson
counts, playlist courses used for covers, and visible clip counts are loaded in
fixed batched queries; gallery card rendering performs no per-card association
queries. Course names in the gallery and reusable web course cards are clamped
to two lines with an overflow ellipsis and a reserved two-line title area,
matching the homepage and native library cards so unusually long provider
titles cannot misalign a grid.

The course detail hero keeps its course name to one line with an overflow
ellipsis. The complete localized name remains in the heading's `title`
attribute, preventing long provider-supplied titles from changing the hero's
vertical layout without discarding the full label.

### Interface localization

Rails chooses the interface locale from `Current.translation_language`, which
is resolved from the request subdomain. English and Hebrew catalogs live in
`config/locales/en.yml` and `config/locales/he.yml`; Spanish, Arabic, German,
and French currently fall back to English. The layouts expose the translation
language through the document's `lang` and `dir` attributes, independently of
the language of learning content. Production uses an Action Dispatch
`tld_length` of 1 because `.app` is a single-label TLD; this makes
`he.langlets.app` resolve `he` as its subdomain.

User-facing server-rendered copy uses Rails I18n lazy lookup. A single JSON
payload in the shared head exposes the `js` locale subtree to Stimulus through
`app/javascript/utils/i18n.js`, so dynamic activity feedback uses the same
request locale and fallback behavior as ERB views.

### Translation localization

Content has one shared L1 skeleton and any number of sparse L2 translations:

- `media` is unique on `(url, language_id)` and represents one transcription of
  a video in its spoken language. Adding an L2 never creates another medium or
  reruns transcription.
- `phrases` stores only L1 text. `phrase_translations` is unique on
  `(phrase_id, language_id)` and stores each localized phrase text.
- `phrase_tokens` stores an L1 span, timestamps, audio, questions, and similar
  sounds once. `token_translations` is unique on
  `(phrase_token_id, language_id)` and stores the L2 label and L2 indexes.
- Activities join spans through `activity_phrase_tokens`, so the sampled course
  skeleton and user progress are shared by every site language.
- `courses` is unique per published `(youtube_video_id, language_id)`.
  `course_translations` carries per-L2 name and readiness; `lesson_translations`
  carries localized lesson names.
- `Current.translation_language` is set from the request subdomain (`he` on
  `he.langlets.app`, English on the main domain). Phrase, token, course, and
  lesson localized associations use this request context. The existing `lang`
  parameter remains the independent L1/library filter.
- Sessions use a parent-domain cookie (`domain: :all`, `tld_length: 2`) so login
  is shared across localized subdomains.
- Saved vocabulary uses `phrase_token_users`. Each row pins `language_id` when
  the span is saved; vocabulary and review resolve that exact translation even
  when the current subdomain is different. Saving the span again updates the
  language rather than creating a second entry.

The import pipeline is also split. `CreateSongProgress` is unique on
`(youtubeurl, clip_language)`. Neutral transcription/timing/segmentation work
runs once, while `add_translation(language)` stores language-keyed output under
`data["translations"]`. A translation-only import costs one credit and attaches
phrase, token, lesson, and course translations without deleting lessons,
activities, progress, or vocabulary.

The `data` blob is versioned (`CreateSongProgress::DataFormat`,
`data["format_version"]`). Version 1 carried a single language inline
(`text_l2` on phrases, `translation` on words); version 2 is the neutral +
`data["translations"]` shape above. Course building, `add_translation`, and
both import surfaces (the admin uploader and `rake
create_song_progress:import`) refuse legacy blobs; `rake
create_song_progress:convert_files` / `convert_records` upgrade JSON exports
and DB rows.

The stored record is a cache, not a source of truth: when a published course's
progress row is missing or empty, `CreateSongProgressRebuilder` reconstructs
the blob from the course's persisted phrases, tokens, lessons, and
translations. Rebuilding from those rows (rather than re-transcribing)
guarantees the positional alignment `BuildSong#add_translation` depends on,
and keeps exports possible for any course whose original pipeline record is
long gone.

Pipeline failures are appended to `CreateSongProgress.data["errors"]` by action
through the callback. Any current-run failure wakes the import finalizer and
fails/refunds waiting downloads immediately instead of leaving them pending
until their timeout. When a resumed action succeeds, the worker sends an atomic
action-scoped clear operation through the callback, removing stale failures for
that action while preserving errors from concurrently failing actions.

For local/manual pipeline runs, `rake
"create_song_progress:pipeline[VIDEO_URL,CLIP_LANGUAGE,TRANSLATION_LANGUAGE,CREATOR_EMAIL]"`
takes a YouTube or TikTok URL. **`CreateSongPipelineCli` canonicalizes it before
keying the progress row**, which the web path gets from `Imports::Create` and
this one has to do itself. That is not cosmetic: the stored URL becomes the
course's `main_media_url`, and `Course#video_id` / `#provider` / `#thumbnail_url`
are all derived from that string, so a row keyed on a TikTok share link would
build a course with no video id — no player and no cover. Canonicalization is
offline where possible; a share link costs one oEmbed call up front and aborts
the task if it can't be resolved, rather than spending a whole pipeline run to
produce an unplayable course. A URL no provider claims passes through untouched.

`ImportCourseJob` (which the task then calls synchronously) does its own oEmbed
lookup for the title, and now takes the cover from that same response, storing it
for non-derivable providers. The lookup stays best-effort — it runs after the
pipeline has already done the expensive work, so a failure logs and continues.
Note this legacy path still leaves `youtube_video_id` NULL; `Course#video_id`
falls back to parsing `main_media_url`, so playback works, but these courses are
not covered by `idx_courses_published_video_language`.

The task resolves the target `Language`, creates or reuses the shared progress row,
exports its latest database state to a temporary file, and runs the Deno CLI
synchronously. After the Deno process succeeds, the task synchronously runs
`ImportCourseJob` to build and publish the course. The optional creator email
falls back to `COURSE_CREATOR_EMAIL`, then the administrative
`ynon@hey.com` account. Course creation is not attempted when the pipeline
fails. The callback server must already be running; its base URL is
`PIPELINE_CALLBACK_BASE_URL` (default `http://localhost:3000`). Rails and the
task must share `PIPELINE_HMAC_SECRET`, while the task process also supplies
the model provider keys inherited by Deno. A retry always re-exports first, so
completed callback work is not unnecessarily repeated, and a failed Deno exit
status fails the rake task.

The AI steps run **only** in the Deno pipeline. `CreateSongPipelineHttp` signs
the record's exported `data` with `PipelineHmac` and POSTs it to the pipeline
server's `/run`; results come back through `PipelineCallbacksController`. Both
entry points use it — `CreateCourseJob` (the `/courses/new` form) and
`AddCourseTranslationJob` (adding a language to an existing course).

### Video providers

Courses come from **YouTube or TikTok**. Which one is derived from the stored
URL, never from a column, so every row that predates TikTok answers correctly
with no backfill.

`VideoSource` (`app/services/video_source.rb`) is the only place that knows the
list. It dispatches to a pair of modules per provider — `<Provider>::Url` for
pure string work and `<Provider>::Oembed` for the one HTTP call — so adding a
third provider is two modules plus one line, not a grep across the app. Nothing
outside it should reference `Youtube::Url` or `Tiktok::Url` directly.

Three asymmetries between the two providers drive most of the design:

- **A TikTok share link has no id in it.** `vt.tiktok.com/ZSXvNVQwY` carries a
  redirect token; only oEmbed can trade it for the numeric post id, server-side.
  So `VideoSource.video_id` returns nil for one while `match?`/`importable?`
  return true. **Ask `VideoSource.importable?`, not `video_id.present?`**, when
  the question is "can this be pasted" — the Add Video sheet rejects the most
  common TikTok paste otherwise.
- **TikTok covers are not derivable.** YouTube's `img.youtube.com/vi/ID/…` is a
  public static pattern, which is why a gallery of course cards costs zero
  network calls. TikTok's are signed CDN URLs with an expiry that only oEmbed
  returns. `courses.thumbnail_url` stores them, captured during
  `Imports::Create` (which already calls oEmbed before charging a credit).
  `Course#thumbnail_url` reads the column, then falls back to derivation — that
  order is why the column is nullable and was never backfilled. It is
  deliberately left NULL for YouTube.
- **TikTok is vertical.** The full player and course preview pick their aspect
  ratio from the provider. The watch-video lesson player instead gives every
  provider the same sticky `clamp(160px, 30vh, 280px)` height so its transcript
  keeps a predictable amount of the iOS viewport. Native video is cropped by
  default and switched to `contain` when loaded metadata identifies landscape
  dimensions; provider iframes fill that same fixed box.

`courses.youtube_video_id` and `import_requests.youtube_url` keep their names but
hold whichever provider's value. `youtube_video_id` backs
`idx_courses_published_video_language`, the partial unique index that makes a
double import a database impossibility, so renaming it is a dedupe migration
rather than a rename.

`VideoSource::UnavailableVideo` is the single availability error;
`Youtube::Oembed::UnavailableVideo` and `Youtube::Oembed::Video` remain as
aliases because they appear in rescue clauses across the app, and a rescue that
silently stopped catching would fail a paid import instead of showing "video is
private".

Known gap: the legacy admin form's `youtube-form` Stimulus controller autofills
name and slug from YouTube oEmbed only. TikTok links there require typing both
by hand; the primary Add Video path resolves server-side and is unaffected.

### Transcription and timing, per provider

The two providers reach the same place — one continuous transcript of timed
words — by different routes, and converge in `phrasesFromAlignedWords`
(`pipeline/src/alignedWords.ts`). Nothing downstream of `force_alignment` knows
TikTok exists.

**TikTok** is transcribed by ElevenLabs Scribe (`scribe_v2`), which takes the
post URL as `source_url` and returns the transcript *and* per-word timestamps in
one call. Consequences worth knowing:

- **No forced alignment.** The words arrive already timed, so nothing downstream
  has to align them.
- **Normally no `yt-dlp` either** — but see "When Scribe cannot fetch the post"
  below, which is the one case where the TikTok path downloads audio.
- **No Supadata and no Gemini fallback.** Apart from the audio-upload retry
  below, a failed Scribe call fails `extract_lyrics` where it stands.
- `extract_lyrics` stashes the timed words under `data["stt_words"]` and
  `force_alignment` builds the provisional phrase from them. Two steps rather
  than one so a run that dies in between resumes without paying for
  transcription twice.
- Scribe returns `spacing` and `audio_event` entries (`[cantando]`,
  `[Applause]`) alongside words. Both are dropped, and the transcript is rebuilt
  from the surviving words rather than taken from the response's `text` — square
  brackets are reserved by the app's token markup, and more importantly
  `add_lessons` partitions the transcript by word count against those very
  words, so the two must describe the same thing.

#### When Scribe cannot fetch the post

TikTok sometimes blocks ElevenLabs' server-side fetch, and Scribe answers **400**
(`ElevenLabs speech-to-text failed (400)`). That is a rejected request, not a
flaky one: retrying the same `source_url` gets the same 400. So `extract_lyrics`
stops the retry schedule immediately (`RetryOptions.isFatal`), downloads the
audio with `yt-dlp`, and re-submits it as the multipart `file` field of the same
Scribe endpoint. The result is identical in shape — transcript plus timed words —
so the rest of the TikTok route is untouched. The temp file is deleted either
way.

Only a 400 triggers this. A 429 or a 5xx keeps being retried as before, because
uploading audio would not help. `SpeechToTextRequestError` carries the HTTP
status precisely so the two cases can be told apart without matching on message
text.

This is why the TikTok path now *can* depend on `yt-dlp` and on
`YTDLP_NETWORK_NAMESPACE`, where before it never did.

**YouTube** keeps its existing route, unchanged:

The pipeline first asks Supadata for existing provider captions with `mode=native`; this is a single
request with no application-level retry, and supports both immediate and asynchronous job responses.
When native captions are unavailable for a YouTube URL, `extract_lyrics` falls back to Gemini 2.5
Flash using the video URL and the lyric-specific transcription prompt. Non-YouTube providers do not
yet have a generated-transcript fallback. Supadata chunks are normalized into provisional text,
while Gemini supplies the fallback transcript. Both sources pass through the shared transcript
cleanup before lines are saved: bracketed and parenthetical annotations such as `[Music]`,
`[Applause]`, and `(footsteps)` are removed, as are the `♪` symbols YouTube wraps sung caption lines
in — left in, those are whitespace tokens like any other and become
"words": index slots for `add_lessons` and clickable vocabulary items whose translation is `♪`.

Supadata's `lang` parameter is a **preference, not a filter**: for a video with no caption track in
the requested language it answers with whichever track exists. So the returned `lang` is compared
against the requested code (on the primary subtag, so `en` and `en-US` agree) and a mismatch is
treated as a native-caption failure, falling through to Gemini — which reads the audio itself and is
told the clip language. Accepting the wrong track is not a visible failure: it builds a course whose
lyrics are a *translation* of the song, and the damage only surfaces two steps later at
`force_alignment`, as foreign text over the real audio. The requested code comes from
`LANGUAGE_TO_ISO` in `extractLyrics.ts`, keyed on the clip language's English name; a
`clip_language_iso` in the trigger payload overrides it, which is how the CLI asks for a regional
track. Rails deliberately does **not** send one — `Language#iso_name` is a TTS code (Arabic is
`ar-JO`, chosen for its Azure voice), and asking Supadata for a caption track in a regional variant
it does not stock is worse than asking for `ar`. `LANGUAGE_TO_ISO` therefore has to cover every
supported clip language: a language missing from it sends no `lang` at all, leaving the choice of
track to Supadata, which the step logs rather than passing off as verified. See
[Adding a New Language](guides/adding-a-new-language.md).

The pipeline downloads the
YouTube audio and sends the resulting text to ElevenLabs forced alignment, which normally supplies
the word-level timestamps used to materialize `phrases`. If any part of that path fails—including
`yt-dlp`, the ElevenLabs API, or validation of its response—the pipeline sends the video URL and the
whitespace-tokenized transcript **words** to Gemini 2.5 Flash using structured output, and Gemini
returns every word in order, with start/end seconds optional for middle words. The fallback
reconciles those entries against the transcript instead of requiring Gemini to timestamp every
token. When Gemini supplies a word start but omits its end, the fallback uses the next later
timestamped word's start as that end; if there is no later start, it uses two seconds after the
word's start. Explicit end times are preserved. Every source line must still have its first and
last lexical words timestamped, which
guarantees required phrase bounds; timed middle words keep their word timings and untimed middle
words remain untimed. This lets
the batch continue with phrase highlighting when Gemini misses individual words, while preserving
karaoke timing wherever it is available. `add_lessons` carries those phrase bounds through semantic
repartitioning without inventing persisted timestamps for the omitted words. (Before July 2026 the
fallback timestamped whole *lines*, which stopped working when `extract_lyrics` began storing the
transcript as one continuous line — Gemini re-split it and the count check failed every time, and
even a passing run would have yielded one untimed phrase.)

**ElevenLabs' tokenization is not the pipeline's.** It splits and merges the text it is given as it
likes — `don't` can come back as `don` + `'t`, a parenthetical can vanish, a script without word
spaces is split per character. But the transcript's own whitespace tokens are what `add_lessons`
indexes into and what `add_token_translations` turns into one clickable word each, so a provider
split would ship `'t` as a vocabulary item. `force_alignment` therefore takes from ElevenLabs only
what it alone can give — timings — exactly as the Gemini fallback already does, and keeps the
transcript's tokens. Reconciliation runs over a stream of timed *characters* (each aligned word's
span spread evenly across its own letters), so one transcript word drawing from several aligned words
or from a fraction of one needs no special case. Punctuation-only transcript tokens have nothing to
be timed against and are dropped from the word stream, and so from the reconstructed line text.
Text that genuinely cannot be reconciled — ElevenLabs having aligned different words, not merely
tokenized them differently — fails and falls through to Gemini. (Before July 2026 this was an
equality check on token *counts*, which rejected the whole audio-derived timing set over an
apostrophe or a `♪`, and reported it as `ElevenLabs aligned N of M transcript words` — a message
about a step downstream of whatever had actually gone wrong.)

The Gemini response is validated, not trusted: returned entries must reconcile in order with the
transcript, with every source line's first and last lexical words timed. Missing middle entries are
also tolerated defensively, although the prompt and structured schema ask Gemini to return every word.
Case, quote style and surrounding punctuation are ignored while matching. Timestamps must be
finite, non-negative and chronological, and each explicit or inferred end must be at or after its
start. An end without a start remains invalid. An added,
rewritten or reordered word, or a missing line boundary, fails the attempt and is retried once.
Phrase and word text always come from the transcript, never from the response, so a re-punctuated
word that survives normalization still cannot reach the course. The prompt states that the output
is checked and that the model must timestamp what it hears rather than extrapolate an even speaking
rate, because song rhythm (held notes, repeats, pauses, instrumental gaps) defeats that guess.

Provider cue boundaries and performance pauses are not semantic lyric lines: either can split a
translation unit in the middle (for example `que / más quisiera`). `force_alignment` therefore sends
ElevenLabs one continuous transcript and initially stores its flat timed word stream as one
provisional phrase. The lesson model then owns a two-level `lessons -> lines` partition. Its input is
the complete continuous transcript; its structured output is a `lessons` array whose entries contain
a title and an array of exact transcript line strings. It is instructed to make each line
independently comprehensible and translatable, with line length as a preference rather than a hard
character cap and an explicit maximum of 20 words. If the model nevertheless returns a longer line,
the pipeline does not retry the model call: it recursively splits the line at the period nearest its
middle, then the comma nearest its middle, or, when neither is present, at the whitespace nearest the
middle. This deterministic fallback preserves every aligned word and its timestamps. The prompt
selects a language-matched worked example for English, Spanish, French,
German, Hebrew, Russian, or Arabic; each demonstrates turning one continuous paragraph into ten
semantic lines across two lessons. Unknown languages use the English example.

The model does not calculate word indexes. Application code treats its returned
lines only as word-count boundaries and requires them to cover the complete
transcript. Phrase text and timestamps are reconstructed from the original
ElevenLabs words, so a spelling change in the model response neither changes
the transcript nor fails the run. AddLessons makes at most two model calls (the
initial attempt and one retry). The semantic lines replace
`lyric_lines` and `phrases`; both the untimestamped `lesson_outline` and final timestamped `lessons`
are saved in the same patch. A segmentation failure blocks downstream work and is safely retried from
the preserved provisional aligned phrase.

After semantic segmentation, lesson rating, sentence translation, and token translation run
concurrently. Sentence translation persists its result under
`data["translation_lines"][iso]`. Using the timed phrases, the pipeline materializes
the same timestamped `data["lessons"]` and version-2 `data["translations"][iso]["phrases"]` formats
consumed by course building. Token translation starts as soon as semantic phrases exist, without
waiting for lesson rating or sentence translation. The
token step deduplicates exact repeated phrases across the full clip before packing requests into
200-word chunks. One translated representative is fanned out to every occurrence; on resume, a
completed occurrence is reused for its still-missing duplicates without an LLM call. Deduplication
uses the complete ordered word text, preserving separate translations when context differs. The
token prompt selects its worked example by the requested target language, preventing a fixed
example language from overriding the target instruction; unknown future languages omit the example.
similar-sound step runs from the aligned phrases after the early branches settle.

**The trigger does not wait.** It POSTs `/run?async=1`, the pipeline answers
`202`, and the job returns — so a worker thread is never held for the minutes a
run takes, and one process can have any number of imports in flight. See
"Import lifecycle" below for what finishes them.

There is no in-process fallback. `CreateSongProgress#create_data`,
`#add_translation` and the six `CreateSong::*` step concerns were removed when
the pipeline became the only implementation — the model is now the store and
the guard predicates, not the worker. `CreateSong::ProgressReporting` remains,
because the percent is derived from `data`, which the pipeline fills in the
same shape. `PIPELINE_URL` is therefore required; an unset value raises
`CreateSongPipelineHttp::ConfigurationError` rather than silently degrading.

The synchronous `/run` form survives behind `CreateSongPipelineHttp.new(...,
wait: true)`, which blocks and raises unless every branch succeeded. Only the
rake tasks use it, because they run a pipeline and then export the record from
the same process. Because each branch persists as it completes, a failed run
leaves its finished work saved and retriggering with the same `data` resumes
rather than redoes.

Pipeline LLM logging is enabled by default and can be disabled with
`PIPELINE_LOG_LLM=0`. Model-backed steps log their complete responses. Supadata
transcription is an API call rather than an LLM SDK call and is not included in
LLM prompt logging.

Three variables configure it: `PIPELINE_URL` (the server), the shared
`PIPELINE_HMAC_SECRET`, and `PIPELINE_CALLBACK_BASE_URL` — where the pipeline
can reach *this* Rails. The last one is the one that bites in development: the
pipeline runs on another host, so `localhost:3000` there is itself, and it must
point at a tunnel (ngrok) to the local server. Model-provider keys now live
only on the pipeline host; Rails no longer needs them at all.

Supadata receives the video URL directly when fetching native captions; Gemini receives the YouTube
URL directly only when that native request fails. Forced alignment still requires the audio bytes,
so the pipeline downloads them with `yt-dlp`. Every invocation enables
`--remote-components ejs:github`, allowing yt-dlp to fetch its external JavaScript challenge solver
when the installed distribution does not bundle it. The host therefore needs outbound access to
GitHub as well as a supported JavaScript runtime; the pipeline's Deno runtime satisfies the latter.
`YTDLP_NETWORK_NAMESPACE` may route only that subprocess, including its EJS download, through a
configured Linux network namespace. The Deno service needs write access for the temporary file and
run permission for `yt-dlp`, `ip`, `ffprobe` and `ffmpeg`.

**A download that "succeeds" is not necessarily audio** (`pipeline/src/audio.ts`).
TikTok serves silent HEVC renditions (`bytevc1` / `media-video-hvc1`) that yt-dlp
does not flag as audio-less ([yt-dlp#15642](https://github.com/yt-dlp/yt-dlp/issues/15642)):
yt-dlp exits 0 and writes a file with either no audio stream or a stream of
digital silence, and ElevenLabs then dutifully transcribes nothing. So every
download is verified before it counts:

- `ffprobe` must report a codec for the first audio stream, and `ffmpeg
  volumedetect` must report a mean volume above **-70 dB**. A file with no
  reading at all is treated as silent — ffmpeg could not decode it either way.
- A file that fails either check is deleted and the next of five format specs is
  tried: `bestaudio[ext=m4a]` (the audio-only pick that has always served
  YouTube, and the only one needing no post-processing), then
  `ba[acodec!=none]`, then `worst[format_id!*=bytevc1][acodec!=none]` — which
  excludes the silent rendition by name — then the H.264 rendition, then
  yt-dlp's own default. Specs 2-5 are extracted to mono 16 kHz m4a, so callers
  always get m4a regardless of which one won. In practice YouTube is satisfied by
  the first spec and TikTok by the third.
- Only when all five are exhausted does the download fail, with every spec's
  reason in the message.
- **If `ffprobe`/`ffmpeg` cannot be run at all** (not installed, or not in
  `--allow-run`), verification is skipped rather than failing the download —
  deployments without ffmpeg keep the pre-verification behavior instead of
  losing every import. `runProbe` swallows *every* spawn failure to guarantee
  that, and deliberately does not enumerate error classes: the first version
  caught `Deno.errors.PermissionDenied`, which Deno 2 never throws (it throws
  `NotCapable`), and a systemd unit whose `--allow-run` list predated ffprobe
  failed every TikTok import instead of quietly skipping the check. The unit
  needs `--allow-run=yt-dlp,ip,ffprobe,ffmpeg`.

### Domain Models

#### 1. **Language** (`languages`)
- **Purpose**: Define source and target languages for translations
- **Key Features**:
  - ISO language codes (`iso_name`)
  - English and native names
  - RTL (Right-to-Left) language support
  - Pronunciation variant handling
  - **Default Script Association**: Each language has a default writing system/script
- **Relationships**: 
  - Referenced by phrases as L1 (source) and L2 (target) languages
  - Belongs to Script (as default_script)
  - One-to-many with MultiScriptTexts

#### 2. **Script** (`scripts`)
- **Purpose**: Define writing systems/scripts for languages (e.g., Latin, Arabic, Cyrillic)
- **Key Features**:
  - Unique script code identifier (`code`)
  - Human-readable script name (`name`)
  - Indexed code field for efficient lookups
- **Relationships**: 
  - One-to-many with Languages (as default_script)
  - One-to-many with ScriptVariants

#### 3. **MultiScriptText** (`multi_script_texts`)
- **Purpose**: Store text content in multiple writing systems/scripts for the same language
- **Key Features**:
  - Language association for context
  - Audio status tracking (not_required, audio_required, audio_ready)
  - Nested attributes support for script variants
  - Automatic content caching and invalidation
  - **Helper Methods**:
    - `create_with_default_content`: Creates text with default script content
    - `to_s(script)`: Returns content for specific script or default
    - `add_variant!`: Adds new script variant with cache clearing
    - `character_range`: Calculates character ranges for word tokenization
- **Relationships**: 
  - Belongs to Language
  - One-to-many with ScriptVariants
  - Referenced by Phrases as text_l1 and text_l2

#### 4. **ScriptVariant** (`script_variants`)
- **Purpose**: Store specific script representations of multi-script text
- **Key Features**:
  - Text content in specific script (`content`)
  - Unique constraint on multi_script_text + script combination
  - Automatic parent cache invalidation on changes
  - Content validation (non-null)
- **Relationships**: 
  - Belongs to MultiScriptText
  - Belongs to Script

#### 5. **Medium** (`media`)
- **Purpose**: Store one video transcription in its spoken language.
- **Identity**: `(url, language_id)`. The URL also carries the provider — see
  "Video providers"; `Medium#provider` derives it rather than storing it. L2 data is stored below phrases, so a new
  target language reuses this row and its L1 phrases.
- **Relationships**: Belongs to the clip `Language`; owns Lessons and Phrases.
  Destroying a Medium cascades through its lessons, activities, phrases,
  translations, phrase tokens, saved-token references, activity join rows,
  similar sounds, and Active Storage attachments. Historical ActivityLogs are
  retained with their optional lesson reference nullified.

#### 6. **Course** (`courses`)
- **Purpose**: Group lessons into structured playlists
- **Key Features**:
  - Hierarchical organization with slugs. **`slug` is the identifier** — uniquely indexed, and what `FriendlyName#to_param` returns.
  - **`name` is NOT unique.** It was, back when one admin typed every title. Two users importing different videos that share a title must not collide on a display field.
  - Main media URL for course overview
  - **Identity in the Library is `(youtube_video_id, language_id)`**, enforced for published courses by a partial unique index. L2 publish/readiness and name live in `course_translations`.
  - `main_media_url` is free text and unreliable for comparison (`youtu.be/X` vs `watch?v=X&t=9`) — always compare `youtube_video_id`, via `VideoSource`.
  - `youtube_video_id` holds whichever provider's id; `Course#video_id` falls back to parsing `main_media_url` for legacy rows where it is blank.
  - `thumbnail_url` is nullable and NULL for YouTube by design: `Course#thumbnail_url` reads it, then derives from `main_media_url`. Only providers whose covers cannot be derived (TikTok) store a value.
  - **User ownership**: All courses belong to a specific user (creator). Note this is *creator*, not *owner* — under dedupe, a course is a shared community artifact other users have enrollments and progress against, which is why `Ability` still grants `:manage, Course` to admins only.
- **Relationships**:
  - One-to-many with Lessons
  - Belongs to the clip Language and creator User; has many CourseTranslations
  - Many-to-many with Playlists (through CoursesPlaylist)
  - One-to-many with Enrollments
- **`localized_translation` is a conditional `has_one` filtered by the current
  translation language.** Because of the `where` lambda, plain `includes`
  (without naming it) will not preload it and listing pages will issue one
  `course_translations` query per card. Any scope that ends up rendered as
  multiple `Course` cards must add `:localized_translation` to its
  `includes` (e.g. `CoursesController#index`, the continue-learning and
  recommended-for-me subqueries).

#### 7. **Lesson** (`lessons`)
- **Purpose**: Define specific learning segments from media content
- **Key Features**:
  - Unique slugs for routing
  - Timestamp ranges (`start_timestamp`, `end_timestamp`)
  - Ordered sequence within courses (integer order field)
  - Descriptive names
  - **User ownership**: All lessons belong to a specific user (creator)
- **Relationships**: 
  - Belongs to Course, Medium, and User
  - One-to-many with Activities
  - Reaching the lesson finish page is the authoritative completion event for
    authenticated learners. It idempotently creates the `LessonUser` record, so
    a lesson is complete even when an activity (such as speaking) was skipped.
- **Show-page loading**: the course page preloads each lesson's localized
  translation before rendering the lesson list. Word-order lessons preload
  phrase tokens, localized token data, and token audio attachments once, then
  sort those loaded tokens in memory while constructing phrase segments.

#### 8. **Phrase** (`phrases`)
- **Purpose**: Store synchronized bilingual text segments with timestamps
- **Key Features**:
  - Stores L1 text; localized L2 text is normalized into PhraseTranslations
  - Media synchronization timestamps
  - L1 language reference (`l1_id`)
  - **Audio Attachment**: `has_one_attached :l1_audio` for pronunciation audio files
  - **Helper Methods**:
    - `text_l1_content`/`text_l2_content`: Get default script content
    - `text_l1_for_script`/`text_l2_for_script`: Get content for specific script
    - `with_calculated_end_timestamps`: Calculate phrase durations
- **Relationships**: 
  - Belongs to Medium and two Languages
  - Belongs to two MultiScriptText objects (text_l1, text_l2)
  - One-to-many with PhraseTranslations and PhraseTokens
  - Many-to-many with Activities (through ActivityPhrase)

#### 9. **PhraseToken / TokenTranslation**
- `phrase_tokens` is the language-neutral L1 span, unique by phrase, L1 range,
  and index type. It owns timestamps, audio, questions, L1 similar sounds, and
  the source word's `part_of_speech`.
- `token_translations` belongs to a PhraseToken and Language and owns the L2
  translation plus L2 indexes. It is unique per `(phrase_token_id, language_id)`.
- Activities and saved vocabulary reference PhraseToken, never a localized row.
- The TypeScript token-translation step emits each translated word with a
  controlled part-of-speech suffix (for example `quieres [verb]`). Rails strips
  the suffix from the learner-visible `TokenTranslation#translation` and stores
  it on the language-neutral PhraseToken. Payloads without a suffix remain
  importable for backward compatibility.
- The migration that splits legacy `token_translations` into `phrase_tokens`
  tolerates missing legacy indexes and recreates the required indexes after the
  table rename. This supports production databases whose historical index set
  differs from a freshly migrated database without risking token data.

#### 10. **User** (`users`)
- **Purpose**: User authentication and account management
- **Key Features**:
  - Email-based authentication (unique constraint)
  - Encrypted password storage using Devise
  - Password reset functionality with tokens and timestamps
  - Remember me functionality for persistent sessions
  - Email confirmation system (confirmable)
  - OAuth provider and UID fields for third-party authentication
- **Authentication System**: Powered by Devise gem with modules:
  - **Database Authenticatable**: Standard email/password authentication
  - **Recoverable**: Password reset via email tokens
  - **Rememberable**: Persistent login sessions
  - **Confirmable**: Email address verification for new accounts
  - **OAuth Integration**: Provider and UID fields for social authentication
- **Security Features**:
  - Reset password tokens with expiration timestamps (unique constraint)
  - Confirmation tokens for email verification
  - Unconfirmed email handling for email changes
  - Indexed email field for efficient lookups
- **User Interface**: Modern dark-themed login/registration forms with:
  - Social authentication buttons (Apple, Google, GitHub) rendered from the shared `devise/shared/_social_buttons` partial
  - Responsive design with Tailwind CSS
  - Password visibility controls
  - Terms and privacy policy acceptance
- **Relationships**: 
  - Many-to-many with Activities (through ActivityUser) for progress tracking
  - Many-to-many with Lessons (through LessonUser) for completion tracking
  - **Owner relationships**: One-to-many with Courses, Lessons, and Activities (content ownership)

### Activity System (Single Table Inheritance)

#### 11. **Activity** (`activities`)
- **Purpose**: Base class for interactive learning exercises
- **Architecture**: Uses STI (Single Table Inheritance) with `type` column
- **Key Features**:
  - Ordered sequence within lessons (integer order field)
  - Text headers and subheaders for UI (`text_header`, `text_subheader`)
  - Video parameter generation
  - Dictionary creation functionality
  - **User ownership**: All activities belong to a specific user (creator)
- **Relationships**: 
  - Belongs to Lesson and User
  - Many-to-many with Phrases (through ActivityPhrase)
  - Many-to-many with TokenTranslations (through ActivityTokenTranslation)

#### Activity Types:
- **ReadTranslatedActivity**: A static "before you watch" screen showing only the lesson's L2 (translated) phrase text, no L1/video/audio. Its sole purpose is priming comprehension before `WatchVideoActivity`. The instruction and phrases share one `min-h-0` overflow region; keeping them in the same flex item prevents WKWebView from collapsing a separate phrase scroller while leaving the surrounding native lesson chrome visible. It has a single "Next" button; a small Stimulus controller (`read_translated_activity_controller.js`) dispatches `activity:completed` when that button is clicked, which is caught by the ancestor `progress-tracker` controller and reported via `sendBeacon` to `/progress` exactly like every other activity type — there is no scoring, so completion is simply "reached and clicked Next." `CourseBuilder::BuildSong` inserts one at `order: 1`, immediately before `WatchVideoActivity`, in every lesson that gets a `WatchVideoActivity` (lesson 1, lessons 2-3, and lessons 4+) — never in review lessons, which start directly with `LanguageAlignmentActivity`/`AudioToTranslation`.
- **WatchVideoActivity**: Video viewing with synchronized subtitles. The "Translation" control is a 2-state L1/L2 toggle switch, labeled with the lesson's actual language names (via `localized_language_name`) on either side of the pill. It defaults to L1 (clickable, tokenized words with the tap-to-translate popover); flipping it swaps every line to the plain, non-clickable L2 text — both use identical text size/weight/color classes since only one language is ever visible at a time. The preference persists per-user under `preferences["watch_video"]["translation"]` (`false` = L1, `true` = L2; see `User#watch_video_preferences`) and is shared with the near-identical layout in `full_player/show.html.erb`, both driven by `watch_video_activity_controller.js`'s `l1Text`/`l2Text` targets.
- **FlashcardActivity**: Missing-word multiple-choice practice. It uses the standard compact question/progress header above a frameless exercise area, with a centered L1 sentence, an L2 gloss anchored below the blank, and a 2×2 grid of contrasting answer tiles.
- **MatchPhrasesActivity**: Phrase-to-translation matching exercises. Each question uses a compact progress header, an audio-enabled L1 phrase card, an L1-to-L2 language direction label, and a vertical set of L2 answer options.
- **WordOrderActivity**: Sentence-building practice whose answer row declares the
  L1 direction explicitly. The completed sentence therefore remains LTR for an
  English L1 (and RTL for an RTL L1), independently of the interface direction
  selected by the translation-language subdomain.
- **SortPhrasesActivity**: Chronological phrase ordering in a compact, frameless exercise layout. The activity presents its instruction and media hint before a draggable list with visible grip handles, followed by the check action and inline result or completion feedback. Its visual states are implemented with Tailwind utilities.
- **LanguageAlignmentActivity**: Word-level alignment exercises. Review activities
  may retain every prior phrase to define their video playback range, but rendering
  hydrates only the sampled activity tokens and their owning phrases, localized
  translations, and audio attachments. The full phrase set is consulted through
  scalar timestamp-boundary queries so long review courses do not preload every
  token, translation, and Active Storage record.
- **SpeakActivity**: Pronunciation practice
- **ListenActivity**: Audio comprehension with token identification
- **FindAnswerActivity**: Question-answer exercises

#### 12. **Playlist** (`playlists`)
- **Purpose**: Define structured curriculum pathways with YouTube-like browsing experience (formerly `LearningPath` / `learning_paths`; old `/learning_paths/:id` URLs redirect to `/playlists/:id`)
- **Ownership** (`user_id`, optional):
  - `user_id` nil = **system playlist**: curated by admins, shown to everyone on the home page, listed in the sitemap. Only admins can modify or delete them.
  - `user_id` set = **personal playlist**: belongs to that user. Any signed-in user can create playlists and add *any* course to them (via the "+" popup on a course page); only the owner (or an admin) can view, modify, or delete them. Created via `CoursePlaylistsController`; admins creating playlists there produce system playlists.
  - Home page shows published system playlists plus the current user's own (`Playlist.visible_to(user)`); `PlaylistsController#show` 404s personal playlists for anyone but their owner/admin. Authorization lives in `Ability` (`can [:update, :destroy], Playlist, user_id: user.id`; admins `can :manage, Playlist`).
- **Key Features**:
  - Named learning sequences with descriptions
  - Difficulty level classification (integer)
  - Publication status (boolean)
  - **YouTube-style View**: Dedicated show page with search, tag filtering, and grid layout
  - **Ajax Search**: Real-time course filtering by name
  - **Tag-based Filtering**: Dynamic tag system for course categorization
- **Relationships**: Many-to-many with Courses (through CoursesPlaylist); optionally belongs to a User

#### 13. **Tag** (`tags`)
- **Purpose**: Categorization system for courses within playlists
- **Key Features**:
  - Unique tag names (e.g., "Music", "French", "Beginner")
  - Used for filtering courses in playlist views
  - Supports YouTube-like tag filtering interface
- **Relationships**: Many-to-many with Courses (through CourseTag)

#### 14. **CourseTag** (`course_tags`)
- **Purpose**: Join table linking courses to their categorization tags
- **Key Features**:
  - Unique constraint on course + tag combination
  - Enables tag-based filtering and categorization
- **Relationships**: Links Courses to Tags

#### 15. **CoursesPlaylist** (`courses_playlists`)
- **Purpose**: Join table linking courses to playlists
- **Key Features**:
  - Ordered sequence within playlists (integer order field)
  - Timestamps for tracking
- **Relationships**: Links Courses to Playlists

### Join Tables

#### 16. **ActivityPhrase** (`activity_phrases`)
- Links activities to their associated phrases
- Enables many-to-many relationship between Activities and Phrases
- Includes timestamps for creation/update tracking

#### 17. **ActivityTokenTranslation** (`activity_token_translations`)
- Links activities to specific token translations for word-level exercises
- Enables many-to-many relationship between Activities and TokenTranslations
- Includes compound index for efficient querying
- Includes timestamps for creation/update tracking

### User Progress Tracking

#### 18. **ActivityUser** (`activity_users`)
- **Purpose**: Track user progress through individual activities
- **Key Features**:
  - Unique constraint on activity + user combination
  - Timestamps for completion tracking
  - Indexed on both activity_id and user_id for efficient queries
- **Relationships**: Links Users to Activities for progress monitoring

#### 19. **LessonUser** (`lesson_users`)
- **Purpose**: Track user progress through lessons
- **Key Features**:
  - Unique constraint on lesson + user combination
  - Timestamps for completion tracking
  - Lesson navigation behavior: clicking the in-lesson "Next Lesson" control sends a background progress update that marks the current lesson as completed for authenticated users
  - Indexed on both lesson_id and user_id for efficient queries
- **Relationships**: Links Users to Lessons for course progression
- **Side effect**: creating a LessonUser touches the user's `Enrollment` for that course (`last_practiced_at`), and *creates* the enrollment if there isn't one — so reaching a lesson via a shared link puts the course on the user's Home.

### Credits

Video imports cost credits. New accounts get `User::SIGNUP_CREDITS` (3).
The iOS Credits screen uses Apple consumable in-app purchases and never exposes
PayPal checkout. Web purchase surfaces use fixed PayPal packs.

#### **Credits::Ledger** (`app/services/credits/ledger.rb`)
The only supported way to move credits. Two stores, written together in one transaction:
- `users.credit_balance` — the authority. Fast to read (Home renders it on every request) and safely lockable. A CHECK constraint enforces `>= 0`.
- `credit_ledger_entries` — append-only audit (`CreditLedgerEntry#readonly?` is true once persisted, and destroy raises). This is what makes refunds and support questions answerable.

Three rules, each load-bearing:
1. **Never read-modify-write the balance.** `Ledger` spends with `UPDATE ... WHERE credit_balance >= ?`, so Postgres evaluates the guard under the row lock and exactly one of two concurrent spends wins. `user.credit_balance -= 1; user.save!` is a lost update. There's a real two-thread test for this (`test/services/credits/ledger_test.rb`).
2. **Every call passes an `idempotency_key`** (`"import:42"`, `"refund:42"`, `"signup:7"`), uniquely indexed. GoodJob retries jobs; without the key a retry double-charges. A replay returns the original entry and moves nothing.
3. **The ledger does not refresh the caller's in-memory user** — it moves the balance with an UPDATE. Call `user.reload` if you need the new value. (`User#grant_signup_credits` does exactly this, which is why `User.create!(...).credit_balance` correctly reads 3.)

`User.has_many :credit_ledger_entries, dependent: :delete_all` — **not** `:destroy`, which would trip the immutability guard and make account deletion impossible.

#### Credit purchases

Web purchase surfaces render a PayPal Payments Standard Buy Now form for each
fixed pack. Since the pricing section was removed from the public homepage, the
only such surface on the web is the out-of-credits state on Add Video
(`app/import_requests/web/new`). The form posts
directly to PayPal and includes `return`, `cancel_return`, and `notify_url`;
returning in the browser never grants credits. Development and test use
`https://www.sandbox.paypal.com/cgi-bin/webscr`, while production uses
`https://www.paypal.com/cgi-bin/webscr`.

The native-only Credits screen renders Apple purchase buttons.
`bridge--apple-purchase` asks the registered iOS
`ApplePurchaseComponent` to load and buy the server-selected StoreKit consumable
with a deterministic, user-bound `appAccountToken`. The app returns StoreKit's
signed transaction JWS to `POST /app/apple_purchases`; Rails verifies the ES256
signature and Apple certificate chain, bundle ID, consumable type, product ID,
account token, and revocation state before granting the server-defined credit
quantity. The ledger key is `apple:<transactionId>`, so repeated delivery grants
once. Only after Rails accepts the transaction does JavaScript ask StoreKit to
finish it. The sole native offer is 20 credits for $10. Its product identifier,
defined in `Apple::CreditPacks`, must exist as a $10 consumable in App Store
Connect: `com.ynonp.langlets.credits20`.

The form's `custom` value is a Rails-signed payload binding the current user to
one server-defined pack. Prices and credit quantities are never accepted from
that token or from browser state. `POST /paypal/notify` is the public IPN
listener. `Paypal::Client` authenticates an IPN by posting its exact raw body
back to the matching PayPal endpoint with `cmd=_notify-validate`; only a
`VERIFIED` response proceeds. `Paypal::ProcessNotification` then requires:

1. `payment_status == "Completed"`;
2. `receiver_id` equals the configured PayPal merchant account ID;
3. the signed user/pack token is valid;
4. `item_number`, `mc_gross`, and `mc_currency` exactly match that pack; and
5. a nonblank PayPal `txn_id`.

Fulfillment uses `Credits::Ledger.grant!` with
`idempotency_key: "paypal:<txn_id>"`, so PayPal retries and concurrent duplicate
notifications credit the account once. The ledger metadata keeps the provider,
transaction, pack, gross amount, currency, and payer ID for support/audit.
Pending notifications are acknowledged but do nothing until PayPal sends a
later Completed IPN. If the verification postback is temporarily unavailable,
the listener returns 502 so PayPal retries.

Only one environment credential is required:

```yaml
paypal:
  merchant_id: YOUR_PAYPAL_MERCHANT_ACCOUNT_ID
```

Use the sandbox business account ID in
`config/credentials/development.yml.enc` and the live business account ID in
`config/credentials/production.yml.enc`. Payments Standard/IPN does not use a
REST client ID, REST secret, SDK key, or locally verified webhook-signature
secret. In development, expose Rails over HTTPS with ngrok and allow the active
ngrok hostname in `config.hosts`; the form derives its PayPal `notify_url` from
the incoming tunneled request, so open the Credits page through the ngrok URL
before starting a sandbox checkout.

#### **Enrollment** (`enrollments`)
- **Purpose**: "this course is on my Home". Unique on `(user_id, course_id)`.
- **Why it exists**: enrollment could not be inferred. A created course is `courses.user_id`, a started course is implied by `lesson_users` — but the Library's "+ Learn this" adds a course to Home *before* any lesson is completed, so it needs a record of its own.
- `source`: `imported` (spent a credit), `library` (added from the catalog), `playlist`.
- `last_practiced_at` is Home's canonical "started" signal: "Keep it going" only includes enrollments where it is non-null, ordered newest first. Clearing it keeps the enrollment/library membership while returning the course to an un-started state.

### Workflow Management

#### **ImportRequest** (`import_requests`) — the Queue

A user's request to turn a video into a course. There are three distinct things in the import flow and it's worth being precise about which is which:

| | Scope | Keyed on |
|---|---|---|
| `CreateSongProgress` | the **shared neutral pipeline cache** — no `user_id` | `(youtubeurl, clip_language)` |
| `Course` | the **shared output** — one per video+L1 | `(youtube_video_id, language_id)` |
| `ImportRequest` | the **per-user intent** | `(user_id, youtube_video_id, clip_language, translation_language)` while active |

> **One `CreateSongProgress` → many language-keyed translations and `ImportRequest`s → one shared `Course`.**

Two users importing the same video deliberately share one pipeline and one course; the AI work happens once. That's why per-user state (status, credit linkage, retry, push idempotency) can't live on either of the shared records.

- `idx_import_requests_active_dedupe` is a **partial** unique index over active (queued/importing) rows, so a double-tapped Import button is a database impossibility. Failed imports remain visible and removable, but the Queue does not offer a user retry: an accessible info tooltip explains that the human team is reviewing the automatic import and that the user will be notified when it finishes.
- `progress_percent` is **written forward** by `CreateSongProgress#sync_import_requests_progress`, never computed on read — `data` is a multi-megabyte jsonb blob and the Queue polls.

**`ImportRequest#retry!`** is the operator's way back from a failed import — console only, never called automatically, and not exposed in the Queue. It raises `ImportRequest::NotRetryable` unless the request is `failed`, still has its course and `CreateSongProgress`, and isn't shadowed by another active request for the same tuple (which `idx_import_requests_active_dedupe` would reject anyway). It then, in one transaction:

| Move | Why it can't be skipped |
|---|---|
| status → `queued` | `CreateCourseJob#start_imports!` and `Imports::Finalizer#pending_requests` only see **active** rows: the pipeline would run for nobody. |
| `created_at` → now | `Imports::Finalizer` fails a request whose record holds an error newer than it. A resumed run clears an error only for a step it actually re-runs, so the **previous** run's entry outlives the retry and re-fails it in seconds. `since:` already exists to discount an older run's failures; the alternative — deleting entries from `data["errors"]` — edits a record shared with every other import of that video. |
| course → `pending` | `Course#process` only claims a pending course, so `CreateCourseJob` would log "already processing" and return. |
| new `ImportRequestTimeoutJob` | `schedule_timeout` is an `after_create_commit`, so a retry would otherwise have **no deadline at all**. |

Which run it starts mirrors `Imports::Create`: a **published** course keeps its status and gets an `AddCourseTranslationJob` for the failed language only (unpublishing a live course over one translation would break it for everyone); an unpublished one gets `CreateCourseJob`. If another **active** request already covers this course, no job is enqueued at all — the retry rides along on that run, exactly as `Imports::Create#join!` does, rather than putting two sets of callbacks on one blob.

Credits are deliberately untouched: the failure already refunded, a retry is us fixing our own import rather than a second sale, and leaving `refunded` set is what stops a second failure from minting a free credit in `Imports::Settlement#fail!`.

**`Course#regenerate!`** is the destructive operator tool for rebuilding an old
course with the current pipeline. It empties the matching
`CreateSongProgress.data`, deletes the old medium (and therefore its phrases,
tokens, lessons, and activities), deletes the old course, and creates a fresh
course shell with the same identity fields. Existing import-history rows are
moved to the replacement shell. The owner's most recent request is forced to
`failed` and passed through `ImportRequest#retry!`; if the course predates
`ImportRequest`, a request with the course owner's `user_id` is created first.
The normal retry path then resets it to queued, installs a new timeout, and
enqueues `CreateCourseJob`. The method returns that request.

#### **Imports::Create** (`app/services/imports/create.rb`)
The single entry point for the Add sheet, the share extension and the API. Order is deliberate: **the video is checked before a credit moves**, so a private or deleted video costs nothing (`Youtube::Oembed` doubles as the availability check). Four outcomes:
- `:created` — charged 1 credit, queued the pipeline.
- `:deduped` — already published; enrolled, free.
- `:joined` — **someone else is importing it right now**; rides along on their course, free. Without this, both users create a pending course and whichever publishes second violates `idx_courses_published_video_pair`, failing an import the user paid for.
- `:already_queued` — this user already asked; no second charge.

The job is enqueued **inside** the transaction — good_job is Postgres-backed, so the job row commits atomically with the request. Enqueuing after commit would leave a charged request nothing ever picks up.

Users are **not** enrolled at import time: the course is `pending` and has no lessons, so Home would show something unopenable. `Imports::Finalizer` enrolls everyone attached once it publishes.

#### Course-ready push notifications

Once `Imports::Finalizer` publishes a course, it marks every attached `ImportRequest` ready, enrolls that request's user, and enqueues one `SendImportReadyPushJob` per request (all three via `Imports::Settlement`). Push delivery is deliberately outside the course-building transaction: an APNs outage must not turn a successfully built course into a failed import. `ImportRequest#notified_at` makes delivery idempotent, and a user with no registered device is stamped as handled because email remains the fallback.

The iOS app registers APNs tokens through the `push` Hotwire Native bridge and `App::DeviceTokensController`; tokens are owned by a user and an installation token can move to the currently signed-in account. APNs sandbox and production tokens are stored separately by environment. Apple responses that identify dead tokens invalidate the row without deleting its diagnostic history, while transient failures leave it active.

The native Profile page exposes the installation's real iOS notification state
through the `notification-preference` bridge. Before permission is granted it
shows an **Enable Notifications** action; after permission is denied it instead
shows an **Open Settings** action that opens the app's iOS Settings page; and
after permission is granted it shows a switch. The action and switch are
mutually exclusive. Turning the switch off removes that installation's token from the
signed-in account and stores a local opt-out so ordinary page loads do not
silently register it again. Turning it back on re-registers the token. If iOS
permission was denied, enabling opens the app's system Settings because iOS
will not present its authorization prompt a second time.

`Push::CourseReadyNotification` includes the published course slug in the APNs custom payload. Notification taps are handled on both iOS paths: `UNUserNotificationCenterDelegate` for a running app and `UIScene.ConnectionOptions.notificationResponse` for a cold launch. Both reset the Home navigator to `/app?just_imported=<slug>`. `App::HomeController` only resolves that slug through the signed-in user's published enrollments, then renders the newly created course as the **JUST IMPORTED** hero whose **Start Course** button enters the standard course experience. An invalid or unauthorized slug safely falls back to ordinary Home.

The APNs badge is a return-to-app prompt rather than durable unread state.
`SceneDelegate.sceneDidBecomeActive` clears the app icon badge whenever the
native app becomes active, covering cold launches, notification taps, and
returns from the background. This is independent of the Create tab badge,
which continues to reflect active imports reported by the web layout.

#### iOS Share Extension

The `LangletsShare` extension accepts shared web URLs and plain text, extracts a
YouTube or TikTok link, and submits it directly to `POST /api/v1/import_requests`.
There is no metadata preflight or AI language detection: the source defaults to
the learning language selected in the app, the translation defaults to English,
and the extension exposes both as editable menus before spending a credit.

Its link check is **host-only, deliberately** (`isSupportedVideo`). The extension
decides "is this worth POSTing", not "which video is this" — Rails re-validates
and canonicalizes, and for TikTok it is the only thing that *can*: TikTok's own
share sheet emits a `vt.tiktok.com` link carrying a redirect token rather than a
post id, so an id parsed client-side would be nil for every share it produces.
The `NSExtensionActivationRule` is generic (`WebURLWithMaxCount` plus text), so
no plist change was needed for Langlets to appear in TikTok's share sheet. It
uses one UUID `client_token` for the lifetime of the sheet; `Imports::Create`
returns the original per-user request when that UUID is replayed, including
after its status changes, so retrying an ambiguous network response cannot
charge twice.

Extensions cannot read `WKWebsiteDataStore` cookies. Every authenticated native
app page therefore POSTs (with Rails CSRF protection) to `/app/native_token` and
passes the response through the `native-token` Hotwire bridge. The endpoint
creates or reuses the fixed public Doorkeeper client `langlets-ios-share-extension`
and issues a 30-day token limited to `imports:read imports:write credits:read`.
Swift stores it in the app/extension Keychain access group; native sign-out both
revokes those tokens server-side and clears the local Keychain item, and also
removes the stored `selectedLanguage` from standard and App Group defaults —
otherwise the next sign-in could briefly inherit the previous account's
language. The selected language is also stored per account as
`User#preferences["ios_lang"]`; after authentication Rails sends that account's
value to the native shell in the explicit `ios_lang` URL parameter, which
repopulates both defaults and prevents repeat onboarding. For the same reason,
`ApplicationController#after_sign_out_path_for` (shared by sign-out and account
deletion) sends native users straight to `/users/sign_in?signed_out=1` with
`lang` explicitly dropped: any other target would bounce a signed-out native
user to sign-in and lose the `signed_out` marker before a page rendered, so the
bridge--sign-out wipe would never fire. Once the wipe completes, the shell
re-routes every tab — the page that fired the bridge was rendered under the
now-deleted session, so its form's CSRF token is dead. Rails also deletes the
session-cached language during the redirect. As a second native safeguard, the
navigator clears its stored language as soon as it sees that signed-out URL;
account deletion therefore cannot leak `?lang=` into the next account even if
the page's JavaScript bridge has not connected yet. The bridge
also mirrors the current `Language` catalog into App Group defaults, while the
language-selection bridge mirrors `selectedLanguage`, so the extension stays
in step with languages added by Rails without an App Store release. If the
shared token or learning language is unavailable, the sheet directs the user
to open Langlets and complete sign-in/onboarding.

#### Import lifecycle — nothing waits, and nothing gets stuck

The pipeline runs out of process and has **no "run finished" callback**: it
streams patches to `PipelineCallbacksController` and then simply stops. The flow
is built around that fact. Four pieces, each with one job:

| | Responsibility |
|---|---|
| `CreateCourseJob` / `AddCourseTranslationJob` | **Trigger.** Claim the course, mark the requests `importing`, start the run, return. |
| `Imports::Finalizer` | **Decide it's done.** Re-derive completion from `data` after every callback; build, publish, enroll, mark ready. |
| `ImportRequestTimeoutJob` | **Give up.** Fixed `ImportRequest::TIMEOUT` (10 minutes) from creation. |
| `Imports::Settlement` | **Bookkeeping.** Enroll + notify, or refund + record why. |

Completion is a **property of the blob, re-derived**, not an event to subscribe
to. `CreateSongProgress#complete_for?(language)` is the question, and it has two
halves: `pipeline_complete?` (all six steps done — cheap, pure digs into `data`)
and `translation_finalized?(language)`. The second half matters because a record
can be complete for Hebrew and still owe French; the pipeline fills **one
language per run**.

`translation_finalized?` reads a single key — `translations.<iso>.lessons` —
because the pipeline's `finalize_translation` step stamps it and only runs once
both translation branches succeeded. One key, one meaning.

Because every callback asks again, `Imports::Finalizer` is **idempotent by
construction**: whichever call first finds a complete blob does the work under
the course's row lock, and the rest find it already done. The lock is
load-bearing — two languages completing at the same moment would otherwise both
see no lessons and both run `BuildSong#call`, and the second destroys the
first's lessons.

The callback controller gates on the *cheap* half (`pipeline_complete?`, or any
reported error) before enqueuing `FinalizeImportsJob`, so a run costs a handful
of jobs rather than one per patch — and building a course never happens inside
the request the pipeline is blocked on.

**The timeout is the only deadline in the system.** It is wall-clock from the
moment the user asked, scheduled by an `after_create_commit` on `ImportRequest`
itself rather than by any one caller, because there are four ways to end up with
a request and the guarantee is worth nothing unless it holds for all of them. It
asks the finalizer once more before giving up (the last patch and the finalizer
that acts on it are not atomic), then refunds with the pipeline's own reported
error as the reason when there is one.

This replaced a design where the trigger blocked on the run for up to
`PIPELINE_READ_TIMEOUT` seconds. That held a worker thread per in-flight import,
and its timeout only fired if the pipeline hung *in the HTTP read* — a run that
died any other way left the request `importing` forever.

Two failures are handled early rather than waited out:
- **The trigger never got off the ground** (unreachable pipeline, bad config).
  The trigger job still owns this one; it refunds in its rescue.
- **A blocking step failed.** `extract_lyrics` and `force_alignment` end the run
  where they stand, so an error from either means no amount of waiting helps.
  `blocking_error` ignores entries the data contradicts (phrases on record mean
  transcription landed) and entries older than the request — a resumed run skips
  steps it already finished, so it never clears their stale errors.

Riders who join an in-flight import asking for a language the run was never
started for get their own `AddCourseTranslationJob`, triggered on the course's
**publish transition**. That transition happens exactly once per course, which is
what stops a language whose run fails from being retriggered by every subsequent
callback; it waits out its deadline instead.

##### Charge lifecycle
`good_job.retry_on_unhandled_error` defaults to **false** and this app doesn't override it, so **a raise in a job is final**. That's what makes refunding in the rescue correct rather than a balance yo-yo. Do not add `retry_on` naively: the rescue sets the course to `error`, and `Course#process` only claims a `pending` course, so a second attempt would silently do nothing.

Only whoever actually paid is refunded — `:joined` riders were never charged. The `"refund:<id>"` idempotency key means a manual re-run can't mint credits.

#### 20. **CreateSongProgress** (`create_song_progresses`)
- **Purpose**: Track async content creation pipeline
- **Key Features**:
  - YouTube URL processing (`youtubeurl`)
  - Multi-step workflow management (integer step field)
  - Source and target language tracking (`clip_language`, `translation_language`)
  - JSONB data storage for flexible progress tracking
  - Unique constraint on URL + source language + target language combination
  - Compound index for efficient querying

## Active Storage Integration

The platform uses **Active Storage** for file management:

- **active_storage_blobs**: Core file metadata (filename, content_type, size, checksum)
- **active_storage_attachments**: Polymorphic join table linking files to any model
- **active_storage_variant_records**: Image/file processing variants

**Storage Configuration**:
- Development: Local disk storage
- Production: Cloud storage (S3/GCS/Azure) support configured

### Audio File Integration

The platform integrates audio files using Active Storage attachments on two core models:

#### Phrase Audio
- **Field**: `Phrase#l1_audio` (has_one_attached)
- **Purpose**: Full phrase pronunciation in source language (L1)
- **Format**: WAV files generated via Azure Text-to-Speech

#### Token Audio  
- **Field**: `TokenTranslation#l1_audio` (has_one_attached)
- **Purpose**: Individual word/token pronunciation in source language (L1)
- **Format**: WAV files generated via Azure Text-to-Speech

## Azure Text-to-Speech Integration

The platform uses **Azure Cognitive Services TTS** for generating pronunciation audio:

### Service Configuration (`AzureTextToSpeechService`)
- **Output Format**: `raw-16khz-16bit-mono-pcm` → converted to WAV
- **Audio Specs**: 16kHz sample rate, 16-bit depth, mono channel
- **Workflow**: Raw PCM → WAV conversion → Base64 encoding → Active Storage attachment

### Language Support
- **English**: `en-US-AriaNeural`
- **Spanish**: `es-ES-ElviraNeural` 
- **French**: `fr-FR-DeniseNeural`
- **German**: `de-DE-KatjaNeural`
- **Arabic**: `ar-JO-TaimNeural` (includes Palestinian Arabic fallback)
- **Hebrew**: `he-IL-AvriNeural`

### Audio Generation Process
1. **Text Input**: Phrase or token text in source language
2. **SSML Generation**: Structured markup with language/voice selection
3. **Azure TTS API**: Raw PCM audio generation
4. **WAV Conversion**: PCM → WAV using WaveFile gem
5. **Base64 Encoding**: For secure transmission
6. **Active Storage Attachment**: Audio file attachment to model record

### Audio Attachment Workflow
```ruby
# From Ai::CreateSong#attach_audio_to_record
def attach_audio_to_record(record, base64_audio_data, filename)
  decoded_audio = Base64.decode64(base64_audio_data)
  audio_io = StringIO.new(decoded_audio)
  
  record.l1_audio.attach(
    io: audio_io,
    filename: filename,
    content_type: 'audio/wav'
  )
end
```

This integration enables:
- **Pronunciation Practice**: Accurate native speaker models
- **Listening Comprehension**: High-quality audio for word identification
- **Accessibility**: Audio support for visual learners
- **Offline Capability**: Downloaded audio files for offline learning

## Data Relationships

```
# Content Hierarchy
Course (1) ──→ (many) Lesson
Lesson (many) ──→ (1) Medium
Lesson (1) ──→ (many) Activity

# Multi-Script Text System
Language (1) ──→ (many) MultiScriptText
Language (many) ──→ (1) Script (as default_script)
Script (1) ──→ (many) ScriptVariant
Script (1) ──→ (many) Language (as default_script)
MultiScriptText (1) ──→ (many) ScriptVariant
ScriptVariant (many) ──→ (1) Script
ScriptVariant (many) ──→ (1) MultiScriptText

# Language & Content
Language (1) ──→ (many) Phrase (as L1)
Language (1) ──→ (many) Phrase (as L2)
Language (1) ──→ (many) Course
Medium (1) ──→ (many) Phrase
Phrase (many) ──→ (1) MultiScriptText (as text_l1)
Phrase (many) ──→ (1) MultiScriptText (as text_l2)

# Token-level Translation
Phrase (1) ──→ (many) TokenTranslation
Phrase (many) ←──→ (many) Activity (through ActivityPhrase)
Activity (many) ←──→ (many) TokenTranslation (through ActivityTokenTranslation)

# Playlist System
Playlist (many) ←──→ (many) Course (through CoursesPlaylist)
Course (many) ←──→ (many) Tag (through CourseTag)

# User Management & Ownership (Devise)
User (1) ──→ (many) Course # Content ownership
User (1) ──→ (many) Playlist # Personal playlists (user_id nil = system playlist)
User (1) ──→ (many) Lesson # Content ownership
User (1) ──→ (many) Activity # Content ownership
User (many) ←──→ (many) Activity (through ActivityUser) # Progress tracking
User (many) ←──→ (many) Lesson (through LessonUser) # Progress tracking

# Audio Attachments via Active Storage
Phrase (1) ──→ (1) Audio File (l1_audio)
TokenTranslation (1) ──→ (1) Audio File (l1_audio)

# Active Storage Infrastructure
Any Model ←──→ Active Storage Blobs (polymorphic attachments)
Active Storage Blobs (1) ──→ (many) Active Storage Variant Records
```

## Key Features & Capabilities

### User Authentication & Management
- **Devise Integration**: Full-featured authentication system with email/password
- **Account Security**: Password reset, email confirmation, and session management
- **Modern UI/UX**: Dark-themed responsive login and registration forms
- **Progress Tracking**: Individual user progress through lessons and activities
- **Social Authentication**: OmniAuth sign-in with Google, GitHub and Apple (`omniauth-apple` uses `nonce: :local` + `provider_ignores_state` because Apple returns its callback as a cross-site form POST that drops the Lax session cookie). Both the Apple callback and OmniAuth failure action skip Rails' CSRF check because failures retain Apple's cross-site POST origin; Apple response integrity is instead checked by the encrypted nonce cookie and ID-token verification. The native iOS app has dedicated flows: Google via the Google Sign-In SDK posting a serverAuthCode to `users/auth/native_google`, and Apple via AuthenticationServices posting the identity token to `users/auth/native_apple`, where the JWT is verified against Apple's JWKS (issuer, audience = app bundle id, expiry)
- **Privacy Compliance**: Terms of service and privacy policy integration

### User Authentication UI Design

The platform implements a modern, accessible authentication system with the following design patterns:

#### Login Form (`app/views/devise/sessions/new.html.erb`)
- **Dark Theme**: Slate-900 background with contrasting white text
- **Responsive Layout**: Full-screen centered design that adapts to mobile
- **Form Elements**:
  - Email/username input with autofocus and autocomplete
  - Password field with integrated "FORGOT?" link
  - Primary "LOG IN" button with hover states
- **Visual Hierarchy**: Clear typography with proper spacing and contrast ratios
- **Interactive Elements**: Smooth transitions and hover effects throughout

#### UI Components & Patterns
- **Navigation Elements**: 
  - Close button (top-left) for modal-style interaction
  - Sign-up link (top-right) for account creation
- **Social Authentication**: 
  - Apple, Google and GitHub buttons with proper branding (shared partial `devise/shared/_social_buttons`)
  - SVG icons with consistent styling
  - Grid layout for multiple providers
- **Form Validation**: 
  - Built-in HTML5 validation with Devise backend
  - Error handling and user feedback
- **Legal Compliance**:
  - Terms of Service and Privacy Policy links

#### Accessibility Features
- **Keyboard Navigation**: Full tab-order support
- **Screen Reader Support**: Proper ARIA labels and semantic HTML
- **Color Contrast**: WCAG-compliant color schemes
- **Focus Management**: Visible focus indicators and logical flow

#### Technology Stack
- **CSS Framework**: Tailwind CSS for utility-first styling
- **Icons**: Heroicons and custom brand SVGs
- **Typography**: System font stack with proper scaling
- **Responsive Design**: Mobile-first approach with breakpoint optimization

### Mobile App (Hotwire Native iOS)

The iOS app is a Hotwire Native wrapper around the Rails web application. It uses WKWebView with shared cookies via `WKWebsiteDataStore.default()`, allowing seamless session sharing with Safari.

#### Path Configuration (which screens are modals)

`SceneDelegate` loads path configuration from two sources, **in order**:
1. `.file(...)` — the copy bundled at `langlets-ios/langlets/langlets/Configuration/path_configuration.json`. Offline fallback and first-launch seed.
2. `.server(...)` — `GET /configurations/ios_v1.json`, served by `ConfigurationsController` from `config/hotwire/ios_path_configuration.json`. **This one wins at runtime**, so routing rules can change with a Rails deploy instead of an App Store release.

> **Rule order is the opposite of what it looks like.** Hotwire Native merges the properties of *every* rule whose pattern matches, with **later rules winning** (`PathConfiguration#properties`: `properties.merge(rule.properties) { _, new in new }`), and patterns are unanchored regexes so `.*` matches everything. The catch-all therefore belongs **first**, as the baseline that later, more specific rules override.
>
> It used to sit last, which silently defeated every modal rule in the file — auth, lessons and `/new` were all presenting as plain pushes no matter what they asked for. Fixed in Phase 3; keep the most specific rules at the bottom.

Two more things to know before touching this:
- `ConfigurationsController` inherits `ActionController::API`, *not* `ApplicationController`. Under `ApplicationController`, `require_authentication_for_native_app` would answer a signed-out native request with a redirect to the sign-in page and the app would parse that HTML as path configuration.
- The bundled and served copies must stay identical in the repo; `test/controllers/configurations_controller_test.rb` enforces it. Edit both together.

#### The app screens (`/app`)

Home, Library, Queue, Add-a-video and Credits live under `App::BaseController` (`app/views/app/**`, `layouts/app.html.erb`). Home, Library, and Credits are **native-only** — `require_native_app` redirects browsers to `root_path` — with a `?native=1` session escape hatch (non-production) so the CSS can be worked on outside the simulator. `App::ImportRequestsController` skips that presentation gate so authenticated web users can use Queue and Add Video. The shared user menu always links to Queue, including at a zero credit balance, so existing and failed imports remain reachable.

**`/app/import_requests` is called "Queue" on the web and "Create" in the native app.** One controller, one set of records, two names — the browser screen is a status list of imports, while the native tab is where a user goes *to make* a langlet. The split lives entirely in the locale file: `app.import_requests.index.title`/`empty` are the web strings, and `native_title` ("Create"), `created_heading` ("My Created Langlets"), `native_empty` and `add_new` are the native ones. Native's already-importing preview links with `view_in_create`; the web preview keeps `view_in_queue`. Internal identifiers (`#queue`, `queue_update.turbo_stream.erb`, `@queue_badge_count`, `poll_controller`) still say queue — the polling contract is shared with the web view, so renaming them would fork it.

The web course UI exposes the shared Queue/Add Video flow through the user menu. Signed-in native users at the web root are redirected to `app_home_path`. That redirect and the remaining `App::BaseController#require_native_app` gates use the single `native_app?` predicate, which recognizes the stable `LangletsNative` user-agent marker. There is no version-specific native routing. Deciding the destination server-side rather than changing the app's start location means it can change without an App Store release.
On the web Add Video screen, a **Buy More** PayPal form beside the available
balance submits the server-defined 20-credit/$10 pack directly to PayPal, so
users do not visit an intermediate Credits screen before checkout. The form is
the same signed Payments Standard form used by the Credits screen; only its
button presentation and cancel destination differ.

The iOS app uses `AppTabBarController`, a native `UITabBarController` with one Hotwire `Navigator` per Home, Library and **Create** tab (the Create tab is `/app/import_requests`, drawn with the `plus.circle` SF Symbol). Navigators load lazily on first selection, then retain their webview and navigation stack, so later tab switches are immediate and preserve scroll/page state. `SceneDelegate.handle(proposal:from:)` intercepts exactly one path — `/`, which clears the source navigator and returns to the Home tab. It does **not** intercept the other tab roots: a link to `/app/library` or `/app/import_requests` from inside another tab is accepted and pushed onto that tab's stack, with a back arrow, while the tab itself keeps its own separate webview. That is deliberate for Home's first-run Create link (below); if you ever need a real tab switch from a link, it has to be added to this method. **The tab bar's selected-item colour is not set in Swift.** No `tintColor` is assigned anywhere; the tab bar inherits the window tint, which comes from the asset catalog's `AccentColor.colorset` via `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` in `project.pbxproj`. That colorset is the app's green `#1DC77C` — the same value as `--color-app-accent` in `application.tailwind.css`, kept in sync by hand, so change both together. It was coral (`#F43E36`) until the tab bar was brought in line with the web accent. Because it is the *global* accent it also tints nav-bar buttons and system controls, which is the point: one accent across native chrome and web content. Note `Assets.xcassets/Colors/Brand*.colorset` (`BrandAccent`, `BrandAccentLight`, `BrandText`, `BrandBackground`, `BrandBackgroundSecondary`) are referenced by nothing in the project and still hold the old coral palette — dead assets, not a second source of truth. The dark app background is a third, separate hard-coded value: `appBackgroundColor` in `SceneDelegate.swift`.

The native tab bar starts hidden and is revealed only after the authenticated app layout reports its active-import badge through the bridge (`setCreateBadge`); entering authentication or completing sign-out hides it again, so login screens never expose app navigation. Authentication and language changes invalidate all three navigators; the visible tab reloads immediately and background tabs reload when next selected.

**A course opened from the Queue lands on Home, not on the Queue's stack.** The Queue is a staging area for imports, so its back arrow is the wrong destination for a course that has already finished importing. `SceneDelegate` intercepts any `/courses/…` proposal originating from the Queue navigator, clears Home to its root, selects the Home tab and re-runs the proposal there, producing exactly the stack the user would have had by tapping through from Home. Courses opened from Home or the Library are untouched — back correctly leads to whichever of those the user came from.

The handoff also unwinds the Queue's own stack on the way out, which is what keeps **Add a video** behaving like a form. A form is spent once submitted and must not remain under the back arrow. An ordinary import gets that for free — `redirect_to_result` sends it to the Queue root, and the tab-root rule turns that into a `clearAll` — but a **deduped** import redirects straight to `course_path` and never passes through that rule. The same applies to the "already in your Library" preview, which offers a course link instead of a submit button. Both are unwound by `openFromHome(_:leaving:)`, which no-ops when the course was tapped on the Queue root and there is nothing to unwind.

This rule **cannot** be expressed in path configuration, and that is a structural property worth remembering rather than a limitation to work around: path configuration is a function of the URL alone, and `/courses/:id` is the same URL from all three tabs. `NavigatorDelegate.handle(proposal:from:)` is the only place the *source* of a visit is known, so any rule of the form "this destination behaves differently depending on where it was reached from" belongs there. The cross-tab root interception above uses the same lever.

The Home header profile menu is an HTML `details` element managed by `profile_menu_controller.js`: a document-level click closes it when the tap lands outside the menu. Because each native tab retains its webview and HTML state, `AppTabBarController` also closes open profile menus in tabs moving to the background whenever the user switches tabs, including programmatic cross-tab routing.

The native tab controller, navigator roots and non-opaque webviews all use the app background token (`#0A1521`). A lazily loaded tab can therefore expose its empty native surface while the first request is in flight without producing a white flash before the web page renders.

**There is no floating "+" on Home, Library or Create.** Creating a langlet is the Create tab's entire job, so it owns the single entry point: an inline full-width **Add New** button below the list. Home has no paste box either — it is for what the user already has. `app/views/app/shared/_fab.html.erb` survives only for the Started-videos screen; do not reintroduce it on the three tab roots. The native controller owns the tab bar and the `tab-badge` bridge mirrors the active-import count onto the Create item. The native web views extend beneath `UITabBar`, so every scrolling app screen uses `app-scroll-pad` to reserve the full tab-bar height plus the bottom safe-area inset; the inset by itself only clears the home indicator. The server gates native-only `/app` screens on the `LangletsNative` user-agent marker; Queue and Add Video are intentionally shared with authenticated browsers. Tab-root paths deliberately have no `replace_root` path-configuration rule because cross-tab routing is native; modal routes retain their existing rules.

- **Home is compact and action-first** (`App::HomeController#index`), one layout for every account state bar one conditional first-run affordance (see below). Product explanation lives in onboarding rather than on this repeat-use screen. Home no longer carries a YouTube/TikTok paste control — that whole flow belongs to the Create tab, so Home does not compete with it. (The old `_paste_cta` partial and its `app.home.paste_cta.*` strings are gone; `/app/import_requests/new?url=…` still auto-resolves a preview via `add_video_controller#connect`, which is how the share extension and any deep link enter the Add screen.) Home is: an optional "just imported" hero, the two most recently practiced unfinished courses under a muted **"Continue"** heading, and four compact Library suggestions in a **2×2 grid** with neutral navigation/action styling. Personal playlists follow when present. The started-videos screen uses non-null `Enrollment#last_practiced_at` as the canonical started signal and includes completed courses. Suggestions are the **newest** published courses in the learning language that the user has not enrolled in — `library_picks` orders by `created_at DESC`, not `RANDOM()`. Two reasons it is no longer random: the first-run subhead promises "any recently created Langlet", which random picks would make untrue, and a grid that reshuffles on every visit gives a returning user nothing to recognize. Playlists include empty ones but exclude system and other users' playlists.

- **Home's first run is the one conditional state** (`first_run = @hero_course.nil? && @enrollments.empty?`, computed in the view). Before this, an account with nothing enrolled saw the wordmark, the section label "Library", and four random cards — no framing and, since `_fab` is not rendered on Home, no visible way to create anything. Two things change while `first_run` holds, and only then: the grid's `<h2>` reads **"Jump right in"** (`app.home.index.first_run_library`) instead of "Library", and a secondary text link — **"Or import any YouTube / TikTok video ›"** (`first_run_create`) — sits below the grid. The heading is word-for-word the marketing root's `courses.index.library.heading`: the same moment for the same person, and the Hebrew was already written. It is duplicated rather than shared, because a later change to one is not automatically right for the other. That section's **subhead was tried and removed** — the cards say what they are, and a line of prose between the heading and the grid pushed the grid down for nothing. Do not reinstate it. The link renders **outside** the `@library_picks.any?` guard on purpose: a learning language whose library is empty produces an otherwise blank Home, which is exactly when it is the only thing on screen. Both revert the instant the user has a hero or a single enrollment, so returning users never pay for the onboarding.

  The library section's **"See all ›" is accent-coloured in both states**, matching the first-run Create link: they are the two ways off that section and should read as the same kind of affordance. The "See all" in **Continue** stays muted (`text-app-text-2`) — it sits under a muted uppercase heading, where accent would outweigh the in-progress courses it points at.

  It points at the Create tab root (`/app/import_requests`), not `/new`: that screen explains both entry points and the price, which is what a first-run user needs ahead of a paste field. Per the tab-root note above this is a plain push with a back arrow, not a tab switch. Deliberately **not** a permanent intro paragraph at the top of Home — `onboarding/welcome` already says what the product does one tap earlier, and the marketing root (`courses#index`) carries the same pitch as its `h1` plus lead, so a third copy would be a standing tax on every returning user for a one-time need. Do not add one. The Hebrew `first_run_create` string carries a `‹` because the chevron flips under RTL; keep the arrow in the locale file rather than the view.
- Native course thumbnails use the same `course_youtube_video_id` fallback as the web cards and request YouTube's `hqdefault` image. This matters for legacy courses whose `youtube_video_id` column is blank but whose `main_media_url` still contains a valid ID; using the column directly produces an empty `/vi//…` image URL.
- **Design tokens** are `--color-app-*` / `app-*` utilities at the bottom of `application.tailwind.css`. **Never use `dark:` under `app/views/app/**`** — the variant keys off `[data-theme="dark"]`, which the app layout hard-codes, so it would be unconditionally on and the intent invisible.
- Tabs use `presentation: replace_root`; the sheets use `context: modal, modal_style: medium`, which maps onto a real `UISheetPresentationController` detent with no Swift. The sheets are **full pages, not Turbo Frames** — a frame overlay inside the web view fights the native modal and you get two competing dismissal gestures.
- Course lesson sheets use `LessonViewController`, a `HotwireWebViewController` subclass selected by `SceneDelegate` for `/courses/:course/lessons/:lesson` and its activity URLs. It adds a native top-right X that dismisses the whole lesson sheet; this is deliberately a close action rather than back navigation between activities.
- The Queue **polls** (`poll_controller.js`, 3s, stops when nothing is active). See ImportRequest above for why not Action Cable. Each tick fetches `App::ImportRequestsController#index` as a Turbo Stream (`Accept: text/vnd.turbo-stream.html`) and patches only the status text, the credits pill, the queue list and the footer note in place via `Turbo.renderStreamMessage` — no full-page visit, no lost scroll position. `index.turbo_stream.erb` and the HTML view share the `_status_text`, `_credits_pill`, `_queue` and `_footer_note` partials so the two formats can't drift. **`_status_text` and `_footer_note` render an always-present wrapper (`#queue-status-text`, `#queue-footer-note`, both `class="contents"`) with content only while something is active.** The wrapper is not decoration: `turbo_stream.replace` needs its target in the DOM, and an idle screen that omits the element cannot be patched when an import appears under it — which is exactly what the share extension does while the app is backgrounded, since `poll_controller` also refreshes on `visibilitychange`. `contents` keeps the empty wrapper from occupying a line box. If you make either line conditional, keep the wrapper unconditional. The credits pill rides along because a credit is spent in the pushed Add Video screen, which would otherwise leave the balance behind it one credit high.
- Queue presentation is platform-specific. Hotwire Native renders the dark `app` layout and the compact swipe-action partials directly under `app/import_requests`, headed "Create" with the credits pill in the corner beside that title, a two-sentence intro (`app.import_requests.index.intro`) naming both ways in — sharing a YouTube or TikTok video to the app via the `LangletsShare` extension, or Add New — plus the ~3 minutes and 1 credit each langlet costs, then a "My Created Langlets" section over the list and the Add New button under it (the live status line under that heading appears **only while imports are in flight** — the idle "Nothing importing right now." was removed, since the empty card directly below already says the queue is empty; the web Queue under `app/import_requests/web` still shows its own copy of that idle line) (outside the polled `#queue` container, so a poll never redraws it — and the empty card carries only the "You haven't created any langlets yet" message, since that button is the call to action for both states); normal browsers render the `application` layout and the responsive partial set under `app/import_requests/web`. Both variants use the same controller actions, routes, import records, and polling contract, while each has its own HTML and Turbo Stream templates so web changes cannot break native navigation or gestures. The credits pill (`_credits_pill.html.erb`, `#credits-pill`) is the **only** credits pill in the app. Home's header (`app/shared/_header`) used to carry one and no longer does: the balance belongs on the screen that spends it, and on Home it was a second quiet ask on a screen with nothing to buy. Do not reintroduce it there. This pill inherits that one's styling a size up. Credits are **ambient status, not body copy**: a bolt glyph and the number in the top corner (top-left under `dir="rtl"`, which `justify-between` handles), the Duolingo-gems pattern, deliberately out of the reading flow. It was briefly a full-width row under the intro, which put a price tag inside the screen's first paragraph. The digit is the whole visible label, so the wording ("Credits remaining: N. Tap to add more") lives in `aria-label` and a test pins it there. Tapping opens `/app/credits`, the medium modal holding the Apple in-app purchase ($10 · 20 credits). After a purchase that modal reloads itself, not the tab under it, so the pill behind it stays stale until the next poll tick or a pull-to-refresh.
- The desktop Queue constrains `#queue`, its one-column grid, and every card
  with `min-width: 0` and `width: 100%`. This is necessary even though the page
  itself has a maximum width: CSS Grid items otherwise use an automatic
  min-width, and a long provider title can establish an intrinsic track wider
  than the centered container, pushing every card off the right edge. Titles
  remain single-line and truncated inside that fixed track.
- Add Video is platform-specific at the view layer too. Hotwire Native keeps the compact pushed-screen form and result partials directly under `app/import_requests`; browsers use the responsive two-column page and result partials under `app/import_requests/web`. The browser page shares the public homepage's fixed warm-cream, ink, and coral palette plus its Bricolage Grotesque/Instrument Sans typography, and deliberately has no light/dark theme switcher. Both variants resolve previews through the shared `add_video_result` Turbo Frame and the same controller/service code. The web approval form opts out of Turbo so its POST redirect replaces the whole document with Queue; native keeps the existing `_top` Turbo-frame submission handled by its navigator.
- Screens are gated by `require_language_for_native_app` too: a signed-in native user with no `?lang=` is sent to `/onboarding/welcome` before any app screen is reachable.

Deliberately **not** built from the mockup, because both would be controls that do nothing: the Library's category chips (nothing populates the taxonomy until the classifier lands) and the Add sheet's "Search YouTube" segment (needs the Data API).

#### Onboarding Flow
1. **Mandatory Authentication**: The server enforces authentication for all native app requests via `ApplicationController#require_authentication_for_native_app`. Unauthenticated native app users are redirected to the sign-in page.
2. **Welcome**: After authentication, if no `?lang=<code>` is present, the server redirects to `/onboarding/welcome`. This large, native-styled screen explains that Langlets turns YouTube **or TikTok** videos into transcribed, translated lessons with vocabulary practice. (The title said YouTube only until TikTok support had already shipped; when a provider is added, `onboarding.welcome.title` in every locale is part of the checklist — see `docs/add-new-video-provider.md`.) "Start Now" advances to language selection while preserving the originally requested app URL. The screen is sized to fit a single viewport with no scrolling on every iPhone (fluid `clamp()` title size, `h-dvh-safe` flex column — plain `h-dvh` overflows by the nav-bar inset because `body` already pads `env(safe-area-inset-top)`). Copy is a three-level hierarchy (eyebrow / title / three short body paragraphs, `body_1..body_3` locale keys) — keep it short enough to preserve the no-scroll fit.
3. **Language Selection**: `/onboarding/language` communicates the choice to iOS via `LanguageSelectionBridgeComponent`, then redirects to the preserved URL (normally `/app`) with the selected `lang` query parameter.
4. **Persistence and restoration**: The selected language ISO code is stored in iOS `UserDefaults` under key `selectedLanguage` and per account in the user's JSONB preferences under `ios_lang`. An authenticated native request carrying a valid `lang` updates that preference. Sign-out still clears the device copy to prevent cross-account leakage; after the next login Rails adds the signed-in account's value as `ios_lang` (and `lang`) to the redirect, and iOS restores both standard and App Group defaults. Only accounts without a saved value see onboarding. Until a language is selected, the native navigator also checkpoints the current welcome or language-selection URL (including `returnto`) under `pendingOnboardingURL`. The checkpoint preserves the URL's percent-encoded query rather than encoding it again, and restoration rebuilds `returnto` from its decoded query value. A cold launch resumes that page instead of rebuilding the flow from `/app`; selecting a language or signing out clears the checkpoint.
5. **URL Param Propagation**: The iOS app appends `?lang=<code>` to the root/start URL. Rails propagates this param through `default_url_options` so all generated links include it.
6. **Content Filtering**: `CoursesController#index` and `PlaylistsController` filter their listings by `Language.find_by(iso_name: params[:lang])` when the param is present.
6. **Tabbed Home Browsing**: The root page (`CoursesController#index`) renders a reusable tabs partial (`app/views/shared/_tabs.html.erb`) backed by `tabs_controller.js`, with a default **Courses** tab (playlist grid) and a secondary **Standalone clips** tab (standalone course grid).

#### Changing Learning Language
- Users can change their learning language at any time from the user dropdown menu (avatar icon) on any authenticated page.
- The dropdown shows the currently selected language and links to `/onboarding/language?returnto=<current_url>`.
- The language page is context-aware: it shows "Change Learning Language" when accessed from the profile menu. First-time product copy is kept on the preceding welcome screen.
- When a language is selected, the bridge message includes a `redirectUrl` so the app navigates back to the originating page with the updated `?lang=` parameter instead of jumping to the root URL.
- The native profile presents the current learning language in a compact select. Changing it sends the selected option's ISO code and redirect URL through the same bridge, keeping iOS `UserDefaults` and the Rails `?lang=` session in sync. Although the profile uses the regular web layout, its content clears the horizontal safe-area insets and reserves the native tab-bar height plus the bottom inset; the shared body already clears the top inset.

#### OAuth Authentication in Native App
- Google and GitHub OAuth flows use `ASWebAuthenticationSession` (Safari) instead of the embedded WKWebView, because Google blocks OAuth in embedded browsers.
- The `AuthBridgeComponent` intercepts OAuth sign-in button taps in the web view and sends a bridge message to iOS, which starts `ASWebAuthenticationSession`.
- **Native App Detection in OAuth Callback**: `ASWebAuthenticationSession` uses Safari's standard user agent, so the server cannot detect the native app via the `LangletsNative` user-agent string. Instead, the iOS app appends `?native_app=1` to the initial OAuth URL (`/users/auth/:provider?native_app=1`). OmniAuth preserves this parameter in `request.env["omniauth.params"]` during the callback phase.
- The `Users::OmniauthCallbacksController#native_app?` method checks both the user agent and `omniauth.params["native_app"]` to determine if the request came from the native app.
- On successful authentication, the server redirects to `langlets://auth-success`, which `ASWebAuthenticationSession` intercepts and closes. The app then routes back to the start location. The session cookie is shared between Safari and `WKWebsiteDataStore.default()`, so the WKWebView picks up the authenticated session on reload.
- On failure, the server redirects to `langlets://auth-failure` for native app flows.

#### Key Files
- `langlets-ios/langlets/langlets/AppTabBarController.swift` — Native tabs, per-tab navigators, lazy loading and tab state retention
- `langlets-ios/langlets/langlets/SceneDelegate.swift` — App entry point, bridge registration, and URL routing
- `langlets-ios/langlets/langlets/LessonViewController.swift` — Native lesson-sheet close control
- `langlets-ios/langlets/langlets/Bridge/TabBadgeComponent.swift` — Updates the native Queue badge from web content
- `langlets-ios/langlets/langlets/Auth/AuthBridgeComponent.swift` — Intercepts OAuth sign-in taps and triggers native auth flow
- `langlets-ios/langlets/langlets/Auth/AuthService.swift` — Manages `ASWebAuthenticationSession` for OAuth
- `langlets-ios/langlets/LangletsShare/ShareViewController.swift` — Share sheet URL extraction, language confirmation and import API submission
- `langlets-ios/langlets/LangletsShare/ShareStore.swift` — Shared Keychain token and App Group language preferences
- `langlets-ios/langlets/langlets/Bridge/NativeTokenComponent.swift` — Receives the session-bootstrapped import token and language catalog
- `app/controllers/app/native_tokens_controller.rb` — Authenticated, CSRF-protected native token bootstrap
- `app/controllers/users/omniauth_callbacks_controller.rb` — Handles OAuth callbacks and redirects to `langlets://auth-success` for native app
- `app/javascript/controllers/bridge/auth_bridge_controller.js` — Stimulus bridge controller for OAuth sign-in buttons

### Content Processing Pipeline
1. **YouTube URL Input**: Extract video metadata and audio
2. **Phrase Extraction**: Generate timestamped bilingual phrases with multi-script support
3. **Multi-Script Text Creation**: Store content in multiple writing systems (Latin, Arabic, etc.)
4. **Audio Generation**: Create TTS audio for phrases and tokens via Azure
5. **Token Mapping**: Create word-level translation mappings with audio
6. **Lesson Generation**: Structure content into pedagogical sequences
7. **Activity Creation**: Generate diverse interactive exercises with audio support

### Learning Activity Types
- **Video Comprehension**: Synchronized subtitle viewing with original audio
- **Phrase Matching**: Translation pair exercises with TTS pronunciation
- **Flashcards**: Learners choose the missing source-language word; the controller preloads the displayed card's correct-answer audio, then a correct choice fills the sentence blank with a brief flash-in animation synchronized to playback before the next card appears
- **Chronological Sorting**: Temporal sequence understanding
- **Word Alignment**: Granular translation mapping with audio feedback
- **Pronunciation Practice**: Speaking exercises with TTS model audio
- **Listening Comprehension**: Audio-based word identification using generated audio
- **Q&A Exercises**: Comprehension testing with audio support

### Multilingual Support
- **Multi-Script Text System**: Support for multiple writing systems per language
- **Script Variants**: Store text in different scripts (Latin, Arabic, Cyrillic, etc.)
- **RTL Languages**: Right-to-left text rendering
- **Pronunciation Variants**: Regional accent support
- **Sound Similarity**: Pronunciation confusion detection
- **Character Indexing**: Precise word boundary detection across scripts

### YouTube-Style Playlist Interface

The platform implements a modern, YouTube-inspired interface for browsing playlists:

#### Playlist Show View (`app/views/playlists/show.html.erb`)
- **Header Section**: 
  - Back navigation to main courses page
  - Playlist title and description
  - User authentication controls (sign up/login or user menu with XP tracking)
- **Search & Filter Section**:
  - Real-time search bar with debounced input
  - Horizontal scrolling tag filter row (All, Music, French, etc.)
  - Mobile-responsive design with proper touch interactions
- **Course Grid**: 
  - Responsive grid layout using existing course card components
  - Infinite scroll structure (ready for implementation)
  - Ajax-powered updates without page refresh

#### Interactive Features (`app/javascript/controllers/playlist_courses_controller.js`)
- **Real-time Search**: Debounced search with 300ms delay for optimal performance
- **Tag Filtering**: Dynamic filtering by course tags with visual feedback
- **Infinite Scroll**: Intersection Observer API for loading more courses
- **Error Handling**: Graceful degradation with user-friendly error messages
- **State Management**: Maintains current page, search term, and active filters
- **Native-safe playlist actions**: Playlist creation and deletion use in-page Stimulus dialogs instead of browser `prompt`/`confirm` APIs, so the controls work consistently in Hotwire Native's WKWebView. Creation stays inside the course's add-to-playlist sheet; deletion requires an explicit second tap and does not delete the playlist's courses.
- **Native tab-bar clearance**: Regular course and playlist pages mark native requests with `data-native-tabs`; the add-to-playlist and delete-playlist sheets use that state to reserve the iOS tab bar height plus the bottom safe-area inset and reduce their maximum height accordingly.

#### Backend Support (`app/controllers/playlists_controller.rb`)
- **Optimized Queries**: Single-query approach for courses with progress data
- **Ajax Endpoints**: JSON responses for search and filtering
- **Pagination**: Server-side pagination with configurable page size
- **Tag Integration**: Dynamic tag loading based on playlist content

#### Tag System for Course Categorization
- **Flexible Tagging**: Courses can have multiple tags (Music, French, Beginner, etc.)
- **Playlist Scoping**: Tags are filtered by playlist context
- **Sample Data**: Migration includes common tags for immediate functionality
- **Unique Constraints**: Prevents duplicate tag assignments

This implementation provides a modern, responsive interface that matches contemporary content platforms while maintaining the educational focus of the application.

### Progressive Learning Design
- **Ordered Sequences**: Lessons and activities follow pedagogical progression
- **Scaffolded Complexity**: From video watching to detailed word alignment
- **Contextual Learning**: Words learned within meaningful phrases
- **Multi-modal Practice**: Video, audio, text, and speaking integration

## File Structure

```
app/models/
├── activity.rb                 # Base activity class (STI)
├── activities/                 # Activity type implementations
│   ├── watch_video_activity.rb
│   ├── match_phrases_activity.rb
│   ├── sort_phrases_activity.rb
│   ├── language_alignment_activity.rb
│   ├── speak_activity.rb
│   ├── listen_activity.rb
│   └── find_answer_activity.rb
├── course.rb
├── lesson.rb
├── medium.rb
├── language.rb
├── script.rb                   # Writing system definitions
├── multi_script_text.rb        # Multi-script text container
├── script_variant.rb           # Specific script content
├── phrase.rb                   # has_one_attached :l1_audio
├── token_translation.rb        # has_one_attached :l1_audio
├── user.rb                     # Devise authentication
├── playlist.rb                 # Playlists (system-curated and user-owned)
├── tag.rb                      # Course categorization tags
├── course_tag.rb               # Course-tag associations
├── activity_phrase.rb          # Join table model
├── activity_token_translation.rb # Join table model
├── activity_user.rb            # User progress on activities
├── lesson_user.rb              # User progress on lessons
└── create_song_progress.rb     # Workflow tracking

app/views/playlists/       # YouTube-style playlist views
├── show.html.erb              # Main playlist view with search/filter
└── _courses.html.erb          # Course grid partial for Ajax updates

app/controllers/
├── playlists_controller.rb # Playlist browsing and search
└── ...                        # Other controllers

app/javascript/controllers/
├── playlist_courses_controller.js # Search, filtering, infinite scroll
└── ...                        # Other Stimulus controllers

app/views/devise/               # Devise authentication views
├── sessions/                   # Login/logout views
│   └── new.html.erb           # Modern dark-themed login form
├── registrations/             # User registration views
├── passwords/                 # Password reset views
└── confirmations/             # Email confirmation views

app/services/
└── azure_text_to_speech_service.rb # TTS integration

app/lib/ai/
└── create_song.rb              # Audio attachment logic

db/
├── schema.rb                   # Database schema
└── migrate/                    # Migration files

storage/                        # Active Storage files
├── development.sqlite3         # Local storage in development
└── [blob_directories]/         # Organized blob storage

script/
├── create_song/               # Course generation scripts
└── shorts/                    # Short-form content scripts

prompts/                       # AI prompt templates
└── system.md                  # Core system prompts
```

## Design Patterns

### Single Table Inheritance (STI)
Activities use STI to share common behavior while allowing specialized implementations for different exercise types.

### Polymorphic Associations
Active Storage attachments can be associated with any model through polymorphic relationships.

### Join Table Models
ActivityPhrase and ActivityTokenTranslation are full models (not just join tables) to allow for future extensibility.

### Workflow State Management
CreateSongProgress uses JSONB for flexible step tracking in the content creation pipeline.

### Timestamp-based Synchronization
All content is synchronized to media timestamps for precise audio-visual alignment.

### Audio Processing Pipeline
1. **Text Normalization**: Sanitize text for SSML compatibility
2. **Voice Selection**: Language-specific neural voice assignment
3. **PCM Generation**: Azure TTS API produces raw audio
4. **WAV Conversion**: PCM-to-WAV using WaveFile gem with proper headers
5. **Base64 Encoding**: Secure audio data transmission
6. **Active Storage Integration**: Polymorphic file attachment

## Technical Implementation Details

### Audio File Specifications
- **Source Format**: Raw PCM from Azure TTS (`raw-16khz-16bit-mono-pcm`)
- **Output Format**: WAV with standard headers
- **Sample Rate**: 16,000 Hz (broadcast quality)
- **Bit Depth**: 16-bit signed integers
- **Channels**: Mono (single channel)
- **Encoding**: Little-endian PCM

### Azure TTS Configuration
```ruby
# Service constants
AZURE_PCM_OUTPUT_FORMAT = 'raw-16khz-16bit-mono-pcm'
WAV_SAMPLE_RATE = 16000
WAV_CHANNELS = 1  
WAV_BITS_PER_SAMPLE = 16

# Voice mapping by language
{
  "en" => "en-US-AriaNeural",
  "es" => "es-ES-ElviraNeural", 
  "fr" => "fr-FR-DeniseNeural",
  "de" => "de-DE-KatjaNeural",
  "ar" => "ar-JO-TaimNeural",
  "he" => "he-IL-AvriNeural"
}
```

### SSML Template Structure
```xml
<speak version='1.0' xml:lang='[language_code]'>
  <voice name='[voice_name]'>[sanitized_text]</voice>
</speak>
```

## Scalability Considerations

- **JSONB Usage**: Flexible data storage for varying workflow steps
- **Indexing Strategy**: Key foreign keys and unique constraints are indexed
- **Background Processing**: Async content creation pipeline
- **Cloud Storage**: Scalable file storage via Active Storage
- **Modular Activities**: New activity types can be added through STI
- **Audio Caching**: Generated TTS audio files are cached via Active Storage
- **API Rate Limiting**: Azure TTS requests managed through service layer
- **Compression**: WAV files optimized for web delivery
- **CDN Integration**: Audio files served through content delivery networks
- **Batch Processing**: Multiple audio files can be generated simultaneously
- **Error Handling**: Graceful degradation when TTS service is unavailable

## Performance Optimizations

### Audio Delivery
- **Lazy Loading**: Audio files loaded on-demand
- **Progressive Download**: Streaming support for large audio files
- **Format Optimization**: 16kHz mono reduces file size while maintaining quality
- **Browser Caching**: Appropriate cache headers for audio assets

### Database Efficiency  
- **Eager Loading**: Minimize N+1 queries for audio attachments
- **Selective Loading**: Only load audio when needed for activities
- **Index Coverage**: Foreign key indexes support efficient joins

This architecture supports a sophisticated language learning platform that can process multimedia content, extract educational material, generate high-quality pronunciation audio, and create interactive learning experiences with precise multilingual and audio support.

### User Progress Tracking System

The platform implements comprehensive progress tracking through dedicated join tables:

#### Activity Progress (`activity_users`)
- **Completion Tracking**: Records when users complete individual activities
- **Unique Constraints**: Prevents duplicate progress entries per user/activity
- **Timestamp Logging**: Tracks completion time for analytics and achievements
- **Activity Types Supported**: All STI activity types (Watch, Match, Sort, Align, Speak, Listen, Find Answer)

#### Lesson Progress (`lesson_users`)
- **Course Progression**: Tracks user advancement through structured lessons
- **Sequential Learning**: Enforces lesson order and prerequisites
- **Completion Certificates**: Foundation for achievement and certification systems
- **Analytics Ready**: Data structure supports learning analytics and reporting

#### Progress Data Applications
- **Course completion/reset**: Mark Done creates the current user's missing `lesson_users` rows for every lesson, making the course complete and removing it from Continue. Clicking Done resets the course to not started by deleting that user's `lesson_users`, `activity_users`, and lesson-scoped `activity_logs`, then clearing the enrollment's `last_practiced_at`. The enrollment itself remains because it represents library membership, but the cleared started signal keeps the reset course out of Continue.
- **Personalized Learning**: Adaptive content delivery based on completion history
- **Performance Analytics**: User engagement and learning effectiveness metrics
- **Achievement Systems**: Badges, streaks, and milestone recognition
- **Content Recommendations**: Intelligent next-lesson suggestions
- **Retention Metrics**: User engagement and course completion rates

#### Future Extensibility
- **Scoring Systems**: Ready for point-based assessments
- **Time Tracking**: Duration-based learning analytics
- **Difficulty Adaptation**: Performance-based content difficulty adjustment
- **Social Features**: Leaderboards and peer comparison capabilities

### Devise Security Configuration

The authentication system is configured with enterprise-grade security features:

#### Password Security
- **BCrypt Encryption**: Industry-standard password hashing with configurable cost
- **Password Complexity**: Minimum length and complexity requirements
- **Reset Token Expiration**: Time-limited password reset tokens for security
- **Brute Force Protection**: Account lockout after failed login attempts

#### Session Management
- **Remember Me**: Persistent login with secure token storage
- **Session Timeout**: Configurable session expiration for inactive users
- **Cross-Site Protection**: CSRF tokens and secure session cookies
- **Device Tracking**: Foundation for multi-device session management

#### Email Verification
- **Confirmable Module**: Email address verification for new accounts
- **Confirmation Tokens**: Secure, time-limited email confirmation
- **Unconfirmed Email Handling**: Support for email address changes
- **Resend Confirmation**: User-friendly confirmation resend functionality

#### Production Security Considerations
- **HTTPS Enforcement**: SSL/TLS required for all authentication endpoints
- **Secure Headers**: Content Security Policy and security headers
- **Rate Limiting**: API and form submission rate limiting
- **Audit Logging**: User authentication and security event logging

#### Database Security
- **Unique Constraints**: Email uniqueness enforcement at database level
- **Index Security**: Efficient lookups without exposing sensitive data
- **Token Storage**: Secure storage of reset and confirmation tokens
- **Data Encryption**: Encrypted password storage with salt

---

## Personal Words Practice Feature

### Overview
Users can save individual word/token translations they encounter during lessons and videos for personal review. A "Review Words" session builds and plays a custom review lesson from the user's saved words.

### New Models

#### TokenTranslationUser (`token_translation_users`)
- **Purpose**: Join table linking users to their saved token translations
- **Key Features**:
  - Unique constraint per `(user_id, token_translation_id)` pair
  - Cascade delete when user or token translation is removed
- **Relationships**:
  - Belongs to User
  - Belongs to TokenTranslation

#### Review Lessons (Lesson without course/medium)
- Lessons now support `course_id: nil` and `medium_id: nil` — enabling standalone review lessons
- Review lessons have random slug prefixed with `review-`
- The unique index on `(course_id, slug)` is partial (`WHERE course_id IS NOT NULL`)

### New Activity Type

#### WriteMissingWordActivity (STI: `Activities::WriteMissingWordActivity`)
- **Purpose**: User types the missing L1 word in a sentence shown with a blank
- **UI**: Shows L2 translation hint, L1 sentence with `_____` blank, text input + Check button
- **Validation**: Case-insensitive exact match; 2 XP for correct answers
- **Stimulus Controller**: `write-missing-word-activity`
- **Data**: `activity_params` builds card objects with `{id, phrase_with_blank, answer, translation, audio_url}`

### New Services

#### ReviewLessonBuilder (`app/services/review_lesson_builder.rb`)
- Creates a review lesson (no course, no medium) for a user from their saved token translations
- Activity composition:
  - FlashcardActivity (if ≥3 saved tokens, up to 15)
  - MatchTokensActivity (if ≥3 saved tokens, up to 15)
  - TokensChainActivity (if ≥4 saved tokens, up to 15)
  - WriteMissingWordActivity (always, up to 10)
- TokensChainActivity uses a frameless exercise layout with an inline matched-word count and progress bar. Each correct translation becomes the next highlighted L1 prompt, while previously found translations are visually muted. Course-built chains contain 4–15 unique word pairs from one content-word category (`noun`, `verb`, `adjective`, or `adverb`); proper nouns and function words are excluded. If no category supplies at least four pairs, the builder omits the activity.
- SortPhrasesActivity, FindAnswerActivity, and FlashcardActivity replace their
  scrollable exercise content with the completion card. The card is a sibling of
  the exercise content and uses the activity's flex space to remain vertically
  centered instead of appearing below the completed exercise.
- Course-built FlashcardActivity sets contain up to five unique content-word pairs drawn from the relevant current/review phrases. Nouns and verbs are selected before adjectives and adverbs, no phrase contributes more than two cards, function words are excluded, and the final card order is shuffled.

### New Controllers

#### TokenTranslationUsersController
- `POST /token_translation_users` — save a token translation (authenticated users only)
- `DELETE /token_translation_users/:id` — unsave (uses token_translation_id as param)
- JSON responses: `{saved: true/false, token_translation_id: N}`

#### ReviewLessonsController
- `POST /review_lessons` — build review lesson and redirect to show
- `GET /review_lessons/:id` — play lesson (uses `review_lessons/show.html.erb`)
- `GET /review_lessons/:id/finish` — completion page

### Frontend Changes

#### Popover Translation Controller (`popover-translation`)
- Added `savedIds` (Array) value — JSON list of user's saved token_translation IDs
- Added `toggleSave()` action — calls API to save/unsave; updates button UI
- Reads `data-token-id` from clicked token span (already present via `wrap_tokens_in_spans` helper)
- Save button shows 🔖 Save / ✓ Saved state
- The popup displays the stored translation and, for signed-in users, the save action; it does not link to an external AI explanation service

#### _translation_popup.html.erb
- Added Save button with `saveButton`, `saveIcon`, `saveText` targets
- Shows saved/unsaved state visually

#### Views with popover-translation controller
The following views now pass `data-popover-translation-saved-ids-value` with the current user's saved token IDs:
- `full_player/show.html.erb`
- `activities/_watch_video_activity.html.erb`
- `activities/_match_phrases_activity.html.erb`
- `activities/_speak_activity.html.erb`

#### User Profile Menus
All 3 user profile menus show a "📚 Review Words" button when the user has saved token translations:
- `courses/index.html.erb`
- `courses/show.html.erb`
- `playlists/show.html.erb`

These checkbox-backed web profile menus use `profile_menu_controller.js` to clear
their toggle when a document click lands outside the menu. The same controller
also closes the native Home header's `details` menu, keeping outside-click
behavior consistent across both menu implementations. Profile links explicitly
dismiss the menu before navigation; this prevents Turbo snapshots on web and
retained tab webviews on iOS from restoring the menu in its open state.

The native app Home header is the wordmark and that avatar only — no credits pill (see the Create tab below for where the balance lives). It uses its top-right initials as a profile dropdown. It links to Profile and Logout, and shows one language-specific "Practice Words" action for each language in which the user has saved vocabulary:
- `app/views/app/shared/_header.html.erb`

On mobile, the courses index and playlist headers keep the profile avatar visible by moving the theme toggle and XP chip into the profile dropdown while keeping desktop header controls unchanged:
- `courses/index.html.erb`
- `playlists/show.html.erb`
