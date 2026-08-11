# Langlets - Language Learning Platform Architecture

## Project Overview

**Langlets** is a Rails-based language learning platform that creates interactive activities from multimedia content (primarily YouTube videos) with synchronized bilingual text, word-level translations, and various learning exercises. The platform is branded as "MúsicaLingo" and focuses on song-based language learning.

## Technology Stack

- **Framework**: Ruby on Rails 8.0
- **Database**: PostgreSQL with JSONB support
- **File Storage**: Active Storage (local/cloud)
- **Frontend**: Rails views with JavaScript
- **Background Jobs**: Solid Queue
- **Package Management**: Bun (JavaScript), Bundler (Ruby)

## Production deployment

Production is deployed with Kamal to `langlets.app` and `he.langlets.app`. Kamal Proxy terminates
TLS and routes requests to the `web` role. A dedicated `job` role runs
`bin/jobs`; jobs are not run inside Puma. Application images are delivered
through Kamal's temporary `localhost:5555` registry, so deployment does not
depend on a persistent third-party container registry. PostgreSQL 17 is a Kamal
accessory on the same private Docker network, persists in its `data` accessory
directory, and does not publish port 5432 on the host.

The application, Solid Cache, Solid Queue, and Solid Cable share the
`langlets_production` database and use separate `public`, `cache`, `queue`, and
`cable` schemas. `DATABASE_URL` is injected from the encrypted
`db.kamal.url` production credential; `db.production.url` is retained as the
legacy production database source during migration. Active Storage remains on
S3, so application containers do not need a persistent file volume.

The single-server deployment deliberately uses one Puma worker, one Solid Queue
worker process, and one three-thread job worker. The host has swap to absorb
short memory spikes, but sustained workload growth should be handled by
increasing the VM size before raising concurrency.

The worker polls two Solid Queue queues in priority order, `[ default, audio ]`
(`config/queue.yml`) — it only pulls from `audio` once `default` is empty.
`GeneratePhraseAudioJob` and `GenerateTokenAudioJob` run on `audio` because
course imports and `BackfillMissingTokenAudioJob` can enqueue hundreds of them
at once; without the split that flood sits ahead of time-sensitive `default`
jobs like `CreateCourseJob` and starves the pipeline for as long as the backlog
takes to drain.

## Core Architecture

### Console transcript correction

Production transcript repairs are exposed as transactional model methods for
Rails console use. `Phrase#correct_text(old_text, new_text)` requires
`old_text` to equal the complete persisted phrase and a uniform token index
type. It computes every difference between the complete old and new texts,
removes tokens that do not map wholly and contiguously across those changes,
and remaps preserved token indexes. Character-indexed phrases compare
characters; word-indexed phrases compare `String#tokenize` results. It returns
a hash keyed by affected `Activity` records with the number of removed token
joins for each. Identical old and new text is valid for translation-only
repairs and preserves every token.

`Phrase#create_token(text, translations)` selects the first occurrence that
does not overlap an existing token, preserves the phrase's index type, creates
translations by language ISO code, and relies on the PhraseToken creation
callback to enqueue fresh TTS audio outside development. A Phrase instance
retains the verified index type after `correct_text`, allowing replacement
tokens to be created even when the correction removed every old token.

`Course#correct_text(old_text, new_text, tokens:, translations:)` finds every
phrase in the Course medium whose complete L1 text exactly equals `old_text`,
delegates each repair, creates the requested tokens for each corrected phrase,
and upserts each phrase-level translation supplied by language ISO code. It
restores each affected activity's previous token count by randomly selecting
from the new tokens belonging to that same phrase when replacement tokens were
supplied. When `tokens:` is omitted, invalidated tokens and their activity joins
remain deleted while the returned hash still reports the affected activities.
All matching phrase
corrections, token and translation creation, and activity restoration share one
database transaction. When the Course has a `CreateSongProgress`, the same
transaction finally force-rebuilds its cached data from the corrected persisted
course, so later translation runs and exports cannot reuse stale phrase,
translation, or token data. `translations:` is required and `tokens:` is
optional; token specs accept either nested `[text, translation_hash]` pairs or
the equivalent flat alternating console form.

### Channels

Every User owns one private default Channel, provisioned atomically with the
account and recoverable through `User#provision_default_channel!`. Channels are
language-neutral publishing identities, not course ownership: `courses.user_id`
remains historical creator data, while `ChannelItem` determines which identity
contributed a Course. A unique partial index guarantees one default per owner,
and `[channel_id, course_id]` makes publishing safe to retry.

`Channel` is an **STI base class**. Its one subclass is `ProChannel`, a private
Channel holding everything a Langlets Pro subscriber imports, whose defining
property is that owning it is not enough to read it — see *Langlets Pro* below.
Because it is a base class, **an unscoped `Channel.where(…)` sees ProChannel
rows**: any query that means "ordinary channels" has to say `type: nil`, and the
two that do (`Channel.owned_grant` and `Ability`'s `can :manage`) each say why.

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
`channel_items.published_at`. When the same Course is published in multiple
visible Channels (e.g. the user's own default Channel and a public Channel),
the query deduplicates by `course_id` with `DISTINCT ON`, preferring the user's
own Channel so the same course never appears twice in a feed. Cards include the
contributing Channel identity. Reading Channel content never creates an
Enrollment; enrollment remains personal learning state.

### Course readability

Channel visibility governs **reading** a Course, not just listing it. Only
Courses published to a public Channel are readable by the world; everything
else requires ownership, an accepted subscription, or admin.

`Course#readable_by?(user)` is the single definition, and it is deliberately
expressed through `ChannelContentQuery.courses_visible_to` rather than a
parallel condition — listing and direct access drifting apart is exactly the
class of bug it exists to prevent. `Ability` exposes it as `can :read, Course`
via a block, declared *before* the `return if user.blank?` guard so guests
carry the public-Channel rule. The block form means `accessible_by` cannot be
used for Course; listings go through `ChannelContentQuery` instead.

`Course#status` is orthogonal. `published` is a pipeline state meaning the AI
build finished — it never implied visibility, which is why
`status: :published` alone used to be enough to reach a Course by URL.

The `CourseReadable` controller concern applies the rule wherever course
content renders: `courses#show`, `#mark_done`, `#reset_progress`,
`lessons#show`, `#finish`, `full_player#show`, and `course_playlists`. A
signed-out visitor is redirected to sign in carrying `?returnto=` (the param
this app's `after_sign_in_path_for` honours — not Devise's stored location),
because authenticating may genuinely grant access. A signed-in user who still
lacks access gets a 404 rather than a 403, so the response never confirms which
imports exist.

Listing surfaces apply the same scope: the home page grid and gallery already
did; `playlists#show` now intersects playlist membership with the readable
scope, since membership is not access and a Channel can go private after a
Course was added; native Home and `started_courses` re-check readability on
every render because an Enrollment outlives its Channel's visibility; and
`CoursesQuery` — which backs both the bearer API and the MCP `get_courses`
tool — takes a required `user:` so neither can enumerate private imports.

Tests that render course content must publish it first. `publish_publicly` and
`publish_privately` in `test/support/channel_publishing_helpers.rb` exist for
this; `test/integration/course_access_test.rb` covers the matrix of guest,
owner, subscriber, non-subscriber, stranger, and admin.

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

`Channel#unpublish!(course)` is the inverse of `publish!`: it destroys that
Channel's `ChannelItem` for the course, `<<`'s symmetric counterpart. Course
deletion (`courses#destroy`, `DELETE /courses/:id`) is built on it and is
scoped entirely to the current user: it unpublishes the course from their own
default Channel, destroys their `Enrollment`, and clears their personal
`LessonUser`/`ActivityUser`/`ActivityLog` rows for that course's lessons (the
same clearing `courses#reset_progress` performs, now factored into
`clear_lesson_progress!`). The shared `Course` row, its lessons, and any other
Channel that also publishes it are untouched — deleting only removes the
course from the acting user's own library. Because the Course itself survives,
re-importing the same video later matches it in `Imports::Create` and simply
republishes it to the user's default Channel via a fresh `Enrollment`, without
the progress that was cleared on deletion. The course page's "..." menu
(`course-menu` Stimulus controller, alongside the existing `course-paths`
"Add to playlist" controller on the same element) only renders the Delete
option when the course is currently published to the viewer's own default
Channel; deletion asks for confirmation in an in-page sheet rather than
`window.confirm`, which the Hotwire Native app does not support — the same
pattern the playlist delete flow uses.

Channel name, visibility, and invitations are no longer self-service: the
Profile page's former "My channel" card (name/visibility form, invite form,
and member/invitation management) was removed, since Channels are now managed
by the system rather than by their owner. `ProfileController#update_channel`
and the `profile_channel` route are gone with it; `Channel#change_visibility!`
still enforces the admin-only-to-public rule for whatever path does change
visibility. The invitation *acceptance* side is untouched: `ChannelInvitationsController`
still serves `/invitations` (the authenticated pending-invitations list),
`/channel_invitations/:token` (an emailed invitation link), and
accept/decline, so existing pending invitations keep working end to end.
`/channels/:slug` returns 404 for unauthorized private/shared access; a valid
pending invitee sees only Channel identity and accept/decline controls until
acceptance.

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
Saved words in the transcript have a solid emerald underline. The translation
popover controller derives that marker from its saved token IDs and refreshes
it immediately when the learner saves or removes a word.
When the watch-video popover controller connects, it refreshes those IDs from a
small authenticated `no-store` JSON endpoint. Cached or prefetched activity
frames therefore retain their ten-minute lifetime without treating their
serialized vocabulary state as authoritative. Save/remove actions still update
the controller locally for an immediate response.
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

### Lesson activity navigation bar

`app/views/lessons/_activity_navigation.html.erb` renders the top bar shown
above every activity: a close icon back to the course (hidden in the native
app, which has its own chrome), one segmented progress track with one segment
per activity in the lesson, and a "Skip lesson" button. Each segment is a
`link_to course_lesson_path(@course, @lesson, a: activity.order)`, so tapping
the track still jumps directly to any activity, the same way the old
per-circle stepper did; only the previous-lesson arrow was dropped, since the
close icon already returns to the course where every lesson is reachable. The
link's own box is only the bar's 8px height, so each segment carries `py-2
-my-2` to grow its tap target without changing what's visually drawn.
`review_lessons/_activity_navigation.html.erb` is a separate, older partial
for review lessons (numbered circles, no lesson bar) and is untouched by this
design; it still owns the shared `lessons.activity_navigation.activity`
locale key.

Each segment's done/current/upcoming state is computed server-side the same
way the old per-circle stepper was: `done` (activity.order <
current_activity_order) renders solid emerald, `upcoming` renders empty gray,
and only the single `current` segment is taller (`h-3` vs. `h-2`) and carries
an inner fill div (`data-progress-target="fill"`) plus a leading dot
(`data-progress-target="dot"`) that starts at 0%. The dot rides the same
percentage as the fill but lives outside the fill track's `overflow-hidden`
box (a sibling inside a shared `relative` wrapper), so it's never clipped and
stays visible as a "you are here" playhead even at 0% or 100% — height and
shape carry that meaning, not color alone. Those two elements are the only
thing JavaScript ever touches — segments never change on their own between
full-frame reloads, since navigating to a different activity re-renders the
whole nav bar from the server with a fresh "current" segment.

The fill and dot are driven by one shared `progress` Stimulus controller
(`app/javascript/controllers/progress_controller.js`), mounted on the
segment track and wired via `data-action` on `document` (the bubbling events
below reach it regardless of DOM nesting inside the turbo-frame). It is the
single place that knows how to render sub-progress — no activity controller
touches nav bar markup directly. Instead, every activity controller reports
its own progress by dispatching two bubbling `CustomEvent`s from
`this.element`:

- `activity:progress` (detail: `{ ratio }`, 0–1) — the `progress` controller
  sets the current segment's fill width, dot position, and `aria-valuenow`
  accordingly. `app/javascript/utils/activity_progress.js` exports
  `reportActivityProgress(element, ratio)` as the one call site every
  activity controller uses instead of duplicating the dispatch.
- `activity:completed` — already dispatched by every activity controller
  before this change (consumed by `progress-tracker#sendProgressUpdate` for
  XP/analytics); the `progress` controller now also listens for it and snaps
  the current segment's fill and dot to 100%, so a final `activity:progress`
  ratio that rounds short of 1 never leaves a visibly incomplete segment.

Activities that used to render their own local progress bar (flashcard,
find-answers, find-words/language-alignment, match-activity, match-tokens,
audio-to-translation, speak-activity, tokens-chain-activity, word-order-activity)
had that bar markup and its `progressBar`/`progressTrack` Stimulus targets
removed — the nav bar segment is now the only progress bar on screen. Textual
counters ("3 / 8 matched", "Question 2 of 5") were kept where they already
existed; only the redundant visual bar was removed. `_activity_progress_bar.html.erb`
(the shared partial the find-answers activity used to render) was deleted as
now-unused.

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

The homepage **does not sell anything**. It carries no pricing section and no
free-credit copy; nothing on it mentions credits, prices or "free". Nothing is
sold anywhere any more — Langlets Pro (see *Langlets Pro*) is granted by hand
from the console after someone asks on Discord, not purchased. Do not
reintroduce a pricing block here without being asked.

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
  Add Video the resolver previews the video and the one-credit import POST
  automatically detects its language before redirecting to Queue.
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

### Search engine indexing

The site is now open to search engines:

- `public/robots.txt` is `User-agent: * / Allow: /`.
- `app/views/layouts/_head.html.erb` no longer emits a blanket `noindex`
  meta tag, so pages rendered through the `application`, `app`, and
  `onboarding` layouts are indexable by default.
- Two views (`review_lessons/show`, `lessons/finish`) still set their own
  `noindex, follow` tag. These are transient, session-specific screens (a
  lesson's completion state) rather than content worth surfacing in search
  results, so they intentionally stay excluded even though the rest of the
  site is now open.

The SEO machinery (canonical URLs, hreflang, Open Graph/Twitter cards,
JSON-LD structured data, `/sitemap.xml`) was left intact throughout, so no
changes were needed there — it now also serves its primary purpose of
driving actual indexing rather than only link previews.

### Sitemap scope

`/sitemap.xml` (`SitemapsController#show`, rendered by
`app/views/sitemaps/show.xml.erb` with `layout: false`) is generated on every
request and lists three collections: three hardcoded static pages, published
system Playlists, and courses.

The course scope is deliberately `ChannelContentQuery.public_courses`, not
`Course.published_courses`. `status: :published` is a *pipeline* state meaning
the AI build finished; it says nothing about visibility, so on its own it also
matched every user's personal import sitting in its default **private**
Channel. The sitemap must advertise only what a logged-out visitor can browse
from the home page and gallery, which is the public-Channel set. `ready_in` is
applied for the same reason: a course whose translation is still `pending`
should not be indexed mid-build. Playlists were already correct —
`system_playlists.published` is exactly `Playlist.visible_to(nil)`.

Note that this is a *discoverability* boundary, not an authorization one.
`CoursesController#show` has no channel check, so any published course still
renders for a guest who has its slug. Adding authorization there is a separate
decision, since it would also break existing shared links.

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
link without a separate back-home action. Signed-in navigation also exposes an
"Add A Video" link to the shared Create flow. All interactive requests ask for Turbo Streams and replace only
the results/count/pagination region, while an ordinary GET remains the
no-JavaScript fallback. `search` matches course/localized course names or
playlist names/descriptions. Languages are multi-select and combine with OR.
Playlists is the only content-type pill: unchecked shows courses and playlists
together, while checked shows playlists only. The result count and
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

The import pipeline begins with automatic source-language detection. Add Video
on web and native sends only the URL and translation language; source-language
selection is not rendered. After the synchronous oEmbed availability check,
`Imports::Create` immediately creates a provisional `CreateSongProgress` and a
provisional `ImportRequest`; both have `clip_language` NULL, while the request
is `detecting`, has no Course, and has not been charged. The form can therefore
redirect immediately. `DetectImportLanguageJob` calls the pipeline's signed
`/detect-language` endpoint, maps its result back to an existing `Language`
row, rejects source = translation, and promotes the same request through the
normal dedupe/credit/course transaction. A detection error is recorded on the
provisional progress row, marks the visible request failed, and costs no
credit.

YouTube detection is a dedicated Gemini 2.5 Flash video request constrained to
the database language ISO codes. TikTok detection first downloads verified
audio with yt-dlp and sends it to ElevenLabs Scribe without a language hint;
this is the cheaper path and rejects silent/audio-less renditions before they
reach ElevenLabs. If every configured yt-dlp format and network namespace
fails, detection falls back to asking ElevenLabs to fetch the canonical TikTok
URL directly. Scribe's returned ISO-639 code selects the language. Its
transcript and timed words seed `data["stt_candidates"]["elevenlabs"]`, so
extraction reuses that paid result while still requesting the independent
Supadata native candidate. Scribe v2's three-letter codes (`eng`, `spa`, `deu`,
`fra`, `heb`, `ara`) and regional seeded codes (notably `ar-JO`) are normalized
to the database's base ISO language.

After detection the import pipeline is split. `CreateSongProgress` is unique on
`(youtubeurl, clip_language)` when `clip_language IS NOT NULL`; NULL provisional
rows are deliberately outside that partial unique index. Neutral transcription/timing/segmentation work
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
create_song_progress:convert_files` upgrades legacy JSON exports/fixtures in
place. All DB rows were converted once (there is no `translation_language`
column to name a legacy blob's language from any more, so a new legacy row
could no longer be upgraded — moot in practice, since the pipeline has written
only version-2 blobs since the conversion).

`CreateSongProgress` carries no language of its own — it is a shared cache
keyed only on `(youtubeurl, clip_language)`, and every language it might hold
lives under `data["translations"][iso]`. Every caller that needs a specific
language receives it explicitly rather than reading it off the record:
`CreateCourseJob`/`ImportCourseJob`/`AddCourseTranslationJob` all take a
`language_id`, `CreateSongPipelineHttp.new(language:)` has no fallback (`nil`
means "transcription + lessons only, no translation branch"), and
`CourseBuilder::BuildSong#call(language)` takes the language as an argument
rather than deriving it.

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
fails. The callback server must already be running; its base URL comes from
`Rails.configuration.x.pipeline.callback_base_url` (default
`http://localhost:3000` in development). Rails and the task must share
`PIPELINE_HMAC_SECRET`, while the task process also supplies
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
  deliberately left NULL for YouTube. `RefreshTiktokThumbnailUrlsJob` runs
  daily through Solid Queue and replaces every TikTok course's signed URL with
  a fresh oEmbed value before its roughly two-day lifetime ends. Each course is
  isolated: an unavailable post or transient TikTok failure keeps the previous
  URL and cannot prevent later courses from refreshing. Rendering never performs
  this network request.
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

Every fresh extraction attempts two independent STT sources concurrently for both providers:

- Supadata receives the original video URL with `mode=native`, `text=false`, and the preferred
  source-language code. The call has no application-level retry and supports both immediate and
  asynchronous job responses.
- The pipeline downloads verified audio with `yt-dlp` and uploads it to ElevenLabs Scribe
  (`scribe_v2`), which returns text plus per-word timestamps. Scribe `spacing` and `audio_event`
  entries are dropped and its text is rebuilt from the surviving speech words.

Each successful raw result is immediately checkpointed under
`data["stt_candidates"]`, keyed by provider. This makes an interrupted run resume only the missing
provider instead of repaying both. When both candidates exist, GPT-5.6 Sol reconciles the complete
texts with structured output, reasoning effort `none`, and temperature 0. Neither source is treated
as authoritative: the prompt asks Sol to preserve speech while resolving disagreement through
context, grammar, and proper names. The reconciled transcript is aligned in the normal timing stage.
When exactly one candidate succeeds, Sol is skipped. An ElevenLabs-only transcript reuses Scribe's
timed words; a Supadata-only transcript proceeds through forced alignment. If Sol itself fails, the
valid ElevenLabs transcript and timings are used rather than failing the import.

If both STT candidates fail, provider behavior diverges at the final fallback only. YouTube invokes
the existing Gemini 2.5 Flash video transcription prompt. TikTok has no third route and fails
`extract_lyrics`. Both sources and the Gemini fallback pass through the shared transcript
cleanup before lines are saved: bracketed and parenthetical annotations such as `[Music]`,
`[Applause]`, and `(footsteps)` are removed, as are the `♪` symbols YouTube wraps sung caption lines
in — left in, those are whitespace tokens like any other and become
"words": index slots for `add_lessons` and clickable vocabulary items whose translation is `♪`.

Supadata's `lang` parameter is a **preference, not a filter**: for a video with no caption track in
the requested language it answers with whichever track exists. So the returned `lang` is compared
against the requested code (on the primary subtag, so `en` and `en-US` agree) and a mismatch is
treated as a failed Supadata candidate. ElevenLabs remains usable; Gemini is reached only if that
candidate also fails on YouTube. Accepting the wrong track is not a visible failure: it builds a course whose
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

For reconciled and Supadata-only transcripts, the pipeline downloads the
video audio and sends the resulting text to ElevenLabs forced alignment, which normally supplies
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
spaces is split per character. The transcript's whitespace tokens are the base vocabulary units,
then `learnerTokens.ts` greedily merges language-specific dictionary entries before `add_lessons`
plans semantic lines. The English dictionary currently contains only `The United States`. A merged
entry is one clickable learner token and retains the first source word's start and the last source
word's end. This merge must happen before line planning so the model's boundary counts and the
materialized phrase word arrays use the same units. Apart from those explicit entries, the
transcript's tokens are what `add_lessons`
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
the transcript nor fails the run. Every reconstructed semantic line and its first learner token are
capitalized in application code; sentence translation and token translation therefore receive the
same capitalized source phrases. AddLessons makes at most two model calls (the
initial attempt and one retry). The semantic lines replace
`lyric_lines` and `phrases`; both the untimestamped `lesson_outline` and final timestamped `lessons`
are saved in the same patch. A segmentation failure blocks downstream work and is safely retried from
the preserved provisional aligned phrase.

After semantic segmentation, lesson rating, sentence translation, and token translation run
concurrently. Sentence translation persists its result under
`data["translation_lines"][iso]`.

Sentence translation enforces its 1:1 line mapping with explicit line numbers rather than with a
line count. Each input line is sent as `<n>. <text>` and each output line must repeat that number;
numbering is global across chunks, so a number identifies a line in the whole transcript. Source
lines are packed into chunks of at most 200 and run through a four-worker pool. Whatever comes back
correctly numbered is kept, and up to two repair passes ask again for only the numbers still
missing, with the full chunk still in the prompt as context so a one-word fragment is never
translated in isolation. Blank source lines are filled in place and never requested. A response
that fails the echo guard is discarded whole rather than banked, since echo means the task was
misunderstood rather than half-answered; the assembled result is echo-checked once more before it
is persisted. The step fails only when lines are still missing after the third attempt, and the
error names the missing line numbers — the reason for numbering in the first place. A bare count
check could say only "82 != 84": on a transcript with a long run of one-word fragment lines
(`وكل.` / `كل.` / `اللي.`) the model merges neighbours into the one natural clause they make
together, and an unnumbered response gives no way to tell which lines were merged or to ask for
them again.

Using the timed phrases, the pipeline materializes
the same timestamped `data["lessons"]` and version-2 `data["translations"][iso]["phrases"]` formats
consumed by course building. Token translation starts as soon as semantic phrases exist, without
waiting for lesson rating or sentence translation. The
token step deduplicates exact repeated phrases across the full clip before packing requests into
200-input-line chunks (one line per learner token). Complete semantic phrases are never split, so a
single phrase longer than the cap occupies its own oversized chunk. One translated representative
is fanned out to every occurrence; on resume, a
completed occurrence is reused for its still-missing duplicates without an LLM call. Deduplication
uses the complete ordered word text, preserving separate translations when context differs. The
chunks run through the existing four-worker pool against DeepSeek V4 Pro through Ollama with
reasoning effort `none` and temperature 0. The local pool remains concurrent even when the Ollama
endpoint serializes requests upstream. The
token prompt retains the established contextual, natural-translation policy and target-language
examples. One narrow guard says to translate only the marked token and not meaning contributed by
adjacent words. A broader standalone-gloss/bound-morpheme policy was tested and rejected because it
degraded contextual inflection and produced incorrect dictionary-like glosses such as Hebrew
`has → יש`. `deno task compare:roosevelt` runs the Roosevelt diagnostic block through the unmodified
legacy prompt and the guarded production prompt and prints every learner token with its gloss;
`--prompt legacy` or
`--prompt current` runs one side only. `--sample edge-cases` selects the built-in possessive,
preposition, and fixed-expression probes, while `--sample all` runs both sample sets.
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
same shape. `Rails.configuration.x.pipeline.url` is therefore required; an unset value raises
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

Rails configuration supplies the endpoints:
`Rails.configuration.x.pipeline.url` is the pipeline server and
`Rails.configuration.x.pipeline.callback_base_url` is where the pipeline can
reach *this* Rails. Production fixes these to `https://pipeline.langlets.app`
and `https://langlets.app` in `config/environments/production.rb`. Development
maps them from `PIPELINE_URL` and `PIPELINE_CALLBACK_BASE_URL`, with the callback
defaulting to `http://localhost:3000`; the callback must point at a tunnel
(ngrok) because `localhost` on the pipeline host refers to itself. The shared
`PIPELINE_HMAC_SECRET` remains secret configuration. Model-provider keys now
live only on the pipeline host; Rails no longer needs them at all.

Supadata receives the video URL directly while the ElevenLabs candidate requires audio bytes, so
the pipeline downloads them with `yt-dlp` during extraction. Reconciled and Supadata-only
transcripts require another audio download for forced alignment; ElevenLabs-only transcripts reuse
Scribe timings. Gemini receives a YouTube URL only when both STT paths fail. Every download enables
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
- **ReadTranslatedActivity**: A static "before you watch" screen showing only the lesson's L2 (translated) phrase text, no L1/video/audio. Its sole purpose is priming comprehension before `WatchVideoActivity`. The instruction and phrases share one `min-h-0` overflow region; keeping them in the same flex item prevents WKWebView from collapsing a separate phrase scroller while leaving the surrounding native lesson chrome visible. It has a single "Next" button; a small Stimulus controller (`read_translated_activity_controller.js`) dispatches `activity:completed` when that button is clicked, which is caught by the ancestor `progress-tracker` controller and reported via `sendBeacon` to `/progress` exactly like every other activity type — there is no scoring, so completion is simply "reached and clicked Next." `CourseBuilder::BuildSong` inserts one at `order: 1`, immediately before `WatchVideoActivity`, in every lesson that gets a `WatchVideoActivity` (lesson 1, lessons 2-3, and lessons 4+) — never in review lessons, whose `WatchVideoActivity` (see below) needs no priming screen.
- **WatchVideoActivity**: Video viewing with synchronized subtitles. The "Translation" control is a 2-state L1/L2 toggle switch, labeled with the lesson's actual language names (via `localized_language_name`) on either side of the pill. It defaults to L1 (clickable, tokenized words with the tap-to-translate popover); flipping it swaps every line to the plain, non-clickable L2 text — both use identical text size/weight/color classes since only one language is ever visible at a time. The preference persists per-user under `preferences["watch_video"]["translation"]` (`false` = L1, `true` = L2; see `User#watch_video_preferences`) and is shared with the near-identical layout in `full_player/show.html.erb`, both driven by `watch_video_activity_controller.js`'s `l1Text`/`l2Text` targets. In review lessons, `CourseBuilder::BuildSong#create_review_lesson_activities` opens with one at `order: 1` scoped to just the new ground since the last review: its phrases start at the previous review lesson's `end_timestamp` (or the course start, for the first review) and run through the current review lesson's `end_timestamp` (`Activity#video_params` derives the clip bounds from the first attached phrase and `lesson.end_timestamp`), so consecutive review lessons play back-to-back segments rather than replaying everything from the start each time.
- **FlashcardActivity**: Missing-word multiple-choice practice. It uses the standard compact question/progress header above a frameless exercise area, with a centered L1 sentence, an L2 gloss anchored below the blank, and a 2×2 grid of contrasting answer tiles.
- **MatchPhrasesActivity**: Phrase-to-translation matching exercises. Each question uses a compact progress header, an audio-enabled L1 phrase card, an L1-to-L2 language direction label, and a vertical set of L2 answer options.
- **WordOrderActivity**: Sentence-building practice whose answer row declares the
  L1 direction explicitly. The completed sentence therefore remains LTR for an
  English L1 (and RTL for an RTL L1), independently of the interface direction
  selected by the translation-language subdomain. `CourseBuilder::BuildSong`
  only assigns phrases containing between one and ten `PhraseToken` records—the
  draggable units learners place—and requires at least two such phrases in a
  lesson. If a lesson does not meet that threshold, early lessons use their
  flashcard alternative and later lessons exclude word order before randomly
  selecting from the remaining activity pool.
- **SortPhrasesActivity**: Chronological phrase ordering in a compact, frameless exercise layout. The activity presents its instruction and media hint before a draggable list with visible grip handles, followed by the check action and inline result or completion feedback. Its visual states are implemented with Tailwind utilities.
- **LanguageAlignmentActivity**: Word-level alignment exercises. Review activities
  may retain every prior phrase to define their video playback range, but rendering
  hydrates only the sampled activity tokens and their owning phrases, localized
  translations, and audio attachments. The full phrase set is consulted through
  scalar timestamp-boundary queries so long review courses do not preload every
  token, translation, and Active Storage record.
- **SpeakActivity**: Pronunciation practice
- **ListenActivity**: Video-led audio comprehension with token identification.
  It shows the lesson's native-controls video and begins only when the learner
  presses Play. The transcript is a clipped two-line window rather than a full
  list. When every phrase token has timing, each word appears at its start time
  and playback stops immediately before an unanswered blank; only then are the
  token translation and two choices shown. Legacy phrase-timed content shows
  the current highlighted phrase plus the next phrase, exposes choices as the
  missing phrase begins, and pauses at that phrase's end if it remains
  unanswered. Correct answers fill the selected indexed token occurrence, so
  repeated words elsewhere in the phrase are not blanked accidentally. Answer
  distractors support both normalized `SimilarSound` rows and the legacy
  `phrase_tokens.similar_sound` array used by older phrase-timed courses.
  Legacy data is upgraded with
  `bin/rails data:migrate_legacy_similar_sounds`; the idempotent task creates
  missing normalized rows in a transaction per token and clears that token's
  legacy array only after every row succeeds. `DRY_RUN=1` reports the work
  without writing, and `PHRASE_TOKEN_ID=<id>` can safely scope a trial run.
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

New accounts get `User::SIGNUP_CREDITS` (3), and that is the whole of it —
**credits cannot be bought**. There is no top-up, on any platform. Past the
signup allowance the way forward is Langlets Pro, whose imports are not metered
at all, so credits are strictly a free-tier meter with a fixed size rather than
a currency.

#### What a credit buys — one rule, one place

**A credit buys a course in your channel.** Not a pipeline run, not an import
request: a `ChannelItem`. So the charge lives in `Channel#publish!`, which is the
only place a course becomes somebody's, and `ProChannel#charge_for!` overrides it
to nothing — that override is the whole of "Pro imports are not metered".

```
publishing a course into a default Channel   → 1 credit
publishing a course into a Pro library       → free
```

Everything else follows, and deliberately nothing else decides a price:

| Situation | What happens | Cost |
|---|---|---|
| Nobody has this video | pipeline runs, publishes on completion | 1 |
| Somebody else is importing it right now | rides along on their run (`:joined`) | 1 |
| Somebody else already built it | published into your channel on the spot (`:adopted`), no pipeline at all | 1 |
| It is already in **your** channel | nothing to publish (`:deduped`) | 0 |
| It is in your channel but not in your language | pipeline runs for the language; `publish!` finds the item already there | 0 |
| Any of the above, on Pro | published into the Pro library | 0 |

The old design priced each of those separately in `Imports::Create` and got three
different answers for the same end state — "already published" and "someone else
is importing it" were free, building it was a credit. Who executed the pipeline,
and whether it ran a minute ago or a year ago, cannot change the price now,
because the price is not attached to the pipeline.

**Charged on delivery, not on request.** Nothing moves when the user taps
Approve; the credit moves when `Imports::Settlement#complete!` publishes. Three
consequences worth knowing:

- **There are no refunds in the import path.** A failed, timed-out or cancelled
  import never published, so it never charged. `Imports::Settlement#fail!` only
  records the reason, and the Queue says "Import failed — no credit used".
  `Credits::Ledger.refund!` remains for console and support use.
- **The ledger key is the publication** — `"publish:<channel_id>:<course_id>"`,
  with the Course as `subject`. A retried job, a second settlement, an operator
  re-running `ImportRequest#retry!`, and delete-then-re-import all buy the course
  exactly once.
- **`Imports::Pricing.ensure_affordable!` is a guard, not a reservation.** It
  refuses an import the user could not take delivery of, counting requests
  already in flight (each wants a credit of its own when it lands) so one credit
  cannot queue five imports. The residual race — the balance running out between
  request and delivery — surfaces as `Credits::InsufficientCredits` inside
  `complete!`, which rolls the publication back and fails that import. Failing is
  correct; the alternative is handing over a course nobody paid for.
  `Imports::Finalizer` catches that one exception separately and records
  `ImportRequest::INSUFFICIENT_CREDITS` as the reason: `failure_reason` is read by
  people (the Queue renders it, the share extension reads it from the API) and
  the ledger's own message names an internal user id. `ImportRequest#insufficient_credits?`
  is what the Queue branches on — the ordinary failure copy promises a human is
  reviewing the import, which is true of a pipeline error and false of this one.
  The shared Course is untouched: it is already `published` by the time
  `complete!` runs, so `mark_course_failed` no-ops and everyone else riding that
  run keeps it.

`Imports::Pricing` is the read-only half: `cost_for` quotes, `already_published?`
asks the destination channel (`Pricing.destination_channel` — `publishing_channel`
without the provisioning, so a Preview never creates a Pro library just by being
looked at) whether the item is already there. `Imports::Preview` quotes with it
and `Channel#publish!` charges, so the number on the button is the number taken.

`import_requests` therefore has **no** `charged`, `refunded` or `pro_covered`
columns; they were mirrors of a fact that now belongs to the publication.
`credit_ledger_entries` remains the record of every credit that ever moved.

#### **Credits::Ledger** (`app/services/credits/ledger.rb`)
The only supported way to move credits. Two stores, written together in one transaction:
- `users.credit_balance` — the authority. Fast to read (Home renders it on every request) and safely lockable. A CHECK constraint enforces `>= 0`.
- `credit_ledger_entries` — append-only audit (`CreditLedgerEntry#readonly?` is true once persisted, and destroy raises). This is what makes refunds and support questions answerable.

Three rules, each load-bearing:
1. **Never read-modify-write the balance.** `Ledger` spends with `UPDATE ... WHERE credit_balance >= ?`, so Postgres evaluates the guard under the row lock and exactly one of two concurrent spends wins. `user.credit_balance -= 1; user.save!` is a lost update. There's a real two-thread test for this (`test/services/credits/ledger_test.rb`).
2. **Every call passes an `idempotency_key`** (`"publish:7:42"`, `"signup:7"`, `"apple:<transactionId>"`), uniquely indexed. GoodJob retries jobs; without the key a retry double-charges. A replay returns the original entry and moves nothing.
3. **The ledger does not refresh the caller's in-memory user** — it moves the balance with an UPDATE. Call `user.reload` if you need the new value. (`User#grant_signup_credits` does exactly this, which is why `User.create!(...).credit_balance` correctly reads 3.)

`User.has_many :credit_ledger_entries, dependent: :delete_all` — **not** `:destroy`, which would trip the immutability guard and make account deletion impossible.

#### Credit purchases — removed

**Individual credits are no longer sold, on any surface.** Two purchase paths
used to exist and both are gone from the tree:

- **PayPal Payments Standard**, on the web. `Paypal::Client`,
  `Paypal::CreditPacks`, `Paypal::ProcessNotification`, the `paypal/_form`
  partial and the `POST /paypal/notify` IPN listener were all deleted, along with
  the "Buy More" form that sat beside the balance on the web Add Video sidebar.
  The `paypal:` credential (`merchant_id`) in the development and production
  credential files is now unused and can be dropped at the next edit.
- **Apple consumable in-app purchases**, in the iOS app. `Apple::CreditPacks`,
  `App::ApplePurchasesController`, `POST /app/apple_purchases`, and the whole
  `/app/credits` screen (controller, views, route, and its `modal_style: medium`
  rule in both copies of the iOS path configuration) were deleted. The
  `com.ynonp.langlets.credits20` consumable in App Store Connect is orphaned and
  should be removed there too.

What replaced them is a link, not a screen: every surface that used to offer a
top-up now points at the Pro screen — the Queue's credits pill, the Add Video
preview's out-of-balance CTA (`get_pro`), and the insufficient-credits card in
the Queue. `App::ImportRequestsController#redirect_to_out_of_credits` does the
same for the residual race, with one branch that matters: `/app/pro` keeps
`App::BaseController`'s native gate, so a browser that hits an empty balance is
sent back to Add Video with an explanation rather than to a screen it would be
bounced out of. The web Add Video sidebar and web preview carry that same
sentence (`out_of_credits_web_hint`) instead of a button, exactly as the
`:paused` state does — the browser can explain where the user stands but has no
Pro screen of its own to send them to.

The purchase-shaped state went with it. Nothing had ever been bought outside
development, so there was no history to preserve:

- `CreditLedgerEntry`'s `iap_purchase` reason is gone, and **3 is left as a hole
  in the enum** rather than renumbered. The remaining members keep the values
  they were written with; a number that once meant "bought a pack" must not come
  back meaning something else.
- `User#purchased_credits?` is gone, and with it the branch it drove in
  `app/home/_pro_card`. The card no longer counts free imports at all (see
  [Langlets Pro](#langlets-pro)); the progress bar that replaced the branch has
  since been removed too, along with `home.index.upsell.credits_left`.
- `User#free_imports_used` keeps its clamp, on a narrower justification: nothing
  an account does can push its spend count past the grant, but a console
  `admin_adjustment` or `promo_grant` still can. Its only caller now is the
  Pro screen's two-lead copy — Home stopped asking.

`Apple::VerifyTransaction`'s `catalog:` argument does survive, and it lost its
`CreditPacks` default in the process: with one catalog left there is nothing to
disambiguate today, but the point of the argument is that an endpoint states
which kind of product it will grant, and a default would let a second catalog
added later be accepted somewhere by omission.

### Langlets Pro

Credits are the free tier's meter. **Pro** is the entitlement that removes it,
and it is deliberately *not* "a big pile of credits":

- Every new account, web or native, still gets `User::SIGNUP_CREDITS` (3). Pro
  changes nothing about signup. Since credits stopped being sold, those 3 are
  also the *only* credits a free account will ever have.
- **Pro is not sold anywhere any more.** `User#pro!` is the only way an
  account becomes Pro: a console-only method, called by hand after someone
  reaches out on the Discord the `/app/pro` screen now links to (see *The Pro
  screens* below and *Apple subscriptions* for the dormant purchase machinery
  it replaced). It writes a `Subscription` row exactly like a real Apple
  purchase would — `product_id: "console_grant"`, `status: :active`, a
  far-future `expires_at` — so `pro?` and everything built on it need no
  separate branch for a console grant. `Apple::SubscriptionPlans.find` returns
  `nil` for that product id by design, which is what keeps any screen that
  reads `Subscription#apple_plan` from inventing a price for a grant that
  never had one.
- Everything a Pro account imports is published to a **Pro library** they hold
  on loan. The entitlement lapsing (an old Apple subscription expiring, or a
  console grant's `expires_at` passing) withdraws it; granting it again hands
  it straight back.
- A Pro subscriber imports without limit, and that is a *consequence* of the
  library rather than a rule of its own: the charge lives in `Channel#publish!`
  and `ProChannel` overrides it to nothing, so a subscriber's imports are free
  because of where they land. There is no meter to drain and none of the credit
  machinery runs. One override, no second code path that has to remember to skip
  the meter, and no way for the import service to bill a subscriber by forgetting
  to ask whether they are one.

`User#pro?` is the single entitlement predicate, defined as
`subscriptions.entitling.exists?` — active status *and* an expiry still in the
future. It is memoised per instance and cleared by `reload`, exactly like
`credit_balance`, so a purchase needs a reload before the new answer shows.

#### The Pro library (`ProChannel`)

The subscription's second half, and the reason it is a Channel rather than a
flag on `courses`.

`ProChannel < Channel` is a private Channel **the subscriber owns**. What makes
it different from any other private Channel is that ownership does not grant
access:

```ruby
class ProChannel < Channel
  def self.owned_grant(user)
    return nil unless user.pro?
    where(user_id: user.id)
  end
end
```

`Channel.visible_to` is a **union of independent grants** — public, owned,
subscribed, plus whatever `ProChannel` contributes — so each kind of Channel
states its own rule instead of adding a clause to somebody else's `WHERE`. A
lapsed subscriber's rows simply stop being contributed. Every grant is wrapped as
`Channel.where(id: …)` before being OR-ed, because `or` needs structurally
compatible relations and `ProChannel.where(…)` is not compatible with
`Channel.where(…)` on its own.

The entitlement therefore lives in **exactly one place** — `User#pro?`, derived
from the subscription's `expires_at`. There is deliberately no `ChannelSubscription`
mirroring it. An earlier cut had the platform administrator own the Pro library
so access could be withdrawn by deleting such a row; it worked, but it stored the
entitlement twice, and the window in which the two disagreed was either a paying
subscriber locked out or a cancelled one still reading. That design also needed
an hourly sweeper to re-derive the copy, depended on an administrator account
existing, and could not give the administrator Pro at all. Deriving access
removes all four problems.

The rest of the rules:

- `User#publishing_channel` decides where a finished import lands —
  `provision_pro_channel!` for a subscriber, `provision_default_channel!`
  otherwise. `Imports::Settlement.complete!` is the only caller, because the
  choice is a fact about *that import*, not about the account today. Courses
  imported before subscribing stay in the default Channel and are kept forever:
  Pro adds a second home, it never moves the first.
- The Pro library is provisioned **lazily, on the first import made while
  subscribed**, so an account that subscribes and never imports carries no empty
  channel.
- Cancelling deletes nothing. The `ChannelItem`s stay exactly where they are,
  which is what makes reactivation restore the entire library at once instead of
  rebuilding it.
- **Saved vocabulary is outside all of this, by design.** `phrase_token_users`
  belongs to the learner, not to the channel the words were met in, so a lapsed
  subscriber keeps every word they saved and can still take review lessons —
  they just cannot open the courses until they come back.
- `ProChannel#change_visibility!` raises for every actor, administrator
  included: public would publish one person's private imports to the world, and
  shared would let the subscriber hand out access that outlives their
  subscription.
- `ProChannel#readable_by?` requires `actor.pro?` on top of ownership, which is
  what `/channels/:slug` and `discoverable_by?` go through.
- `Ability`'s `can :manage, Channel` is scoped `type: nil`. A subscriber owns
  their Pro library, but renaming it, resharing it or inviting people into it is
  not something the subscription buys.
- `courses#destroy` unpublishes from **both** the user's default Channel and
  their Pro library, and `User#owns_publication_of?` (which gates the Delete item
  in the course "..." menu) checks both. An import made while subscribed has to
  stay deletable after the subscription ends.

**`Imports::Paused` is the consequence of the library being revocable**, and the
easiest thing to get wrong. `Imports::Preview` and `Imports::Create` both dedupe
against published courses, and both used to ask only *is it published?* — which,
for your own imports, was the same question as *can you read it?* while a library
was permanent. Once it isn't, pasting a link to your own paused course produced
"Already in your library" and an Open button that 404s, plus a dead Enrollment on
Home. Both now consult `Imports::Paused.for?`, which is deliberately narrow: it
matches only a course in *this user's own* ProChannel. A published course
unreadable for some other reason (somebody else's private Channel) is a separate,
pre-existing case and is left exactly as it was.

That produces a `:paused` state in both services. The Add Video sheet renders it
as an explanation plus a **Reactivate Pro** button rather than a price — meeting
your own paused library is the best moment there is to offer the subscription
back — and `App::ImportRequestsController#redirect_to_result` sends an approved
one to `/app/pro`. Nothing is charged, no request is created, and no second
Enrollment is made. The web preview explains the same state but cannot offer a
way out of it, since the Pro screen is native-only. The bearer API answers `402`
with `status: "paused"`, because the share extension has no such screen to
present. The
Enrollment from the *original* import is deliberately left alone throughout: it
is what puts the course back on Home the moment they resubscribe, and Home and
`started_courses` re-check readability on every render, which is what keeps it off
the screen meanwhile.

#### Apple subscriptions

**This machinery is dormant.** Nothing in the app links to a purchase any
more — the `/app/pro` screen sends people to Discord instead (see *The Pro
screens*) and `User#pro!` is now the only path to the entitlement. Everything
below is kept in place rather than deleted (an explicit choice — see *Pro is
no longer sold* below) so `Apple::VerifyTransaction`, `ActivateSubscription`
and the App Store Server Notifications webhook keep working exactly as
described if a purchase path is ever reintroduced, and so a `Subscription` row
written by a real historical purchase still verifies and renews the same way.

The offers live in `Apple::SubscriptionPlans` — `$10 / month` and `$100 / year`
(`com.ynonp.langlets.pro.monthly` / `.yearly`), which must exist in App Store
Connect as **auto-renewable** products in one subscription group. The "SAVE 17%"
badge and the "$8.33 / mo" equivalent are computed from those prices rather than
written down, so the three numbers cannot drift apart. The price strings are US
display copy shown before the StoreKit sheet opens; the sheet itself always shows
the localized price.

Verification is the machinery the consumable credit packs used to share.
`Apple::SignedPayload` owns the JWS work — Apple's envelope carries its own
certificate chain, so authentication is entirely offline with no key to fetch and
no shared secret — and `Apple::VerifyTransaction` keeps the checks that are about
*us*: right bundle, right `appAccountToken`, not revoked, and a product in the
caller's `catalog:`. `App::AppleSubscriptionsController` passes
`SubscriptionPlans`, and it is now the only caller: the sibling
`App::ApplePurchasesController` that passed `CreditPacks` is gone with the packs.
`catalog:` nonetheless stayed **required** rather than defaulting to the one
remaining catalog — it exists so that an endpoint names the kind of product it
will grant, which is what stopped a $10 consumable being redeemed as a year of
Pro, and a default would quietly extend acceptance to whatever catalog is added
next.

`Apple::ActivateSubscription` writes the verified transaction into
`subscriptions`, keyed on `original_transaction_id` — the identifier Apple keeps
stable for a subscription's whole life, so a renewal updates the row it renews
instead of appending a second entitlement. Ordering is by the transaction's own
`purchaseDate`, not by arrival and not by the expiry it claims: each renewal in a
chain has a later purchase date, while a notification *about* the transaction on
file (EXPIRED, DID_FAIL_TO_RENEW) carries the same one and is applied, which is
what lets an entitlement legitimately end early. Only a genuinely older
transaction is ignored — and even then a revocation still lands, because a refund
is authoritative whenever it arrives. Writing that row is the *only* thing it
does — library access is derived from it, so there is nothing else to keep in
step.

That comparison is a read-check-write, so it runs **under a row lock**
(`apply_locked!`). Apple neither orders nor deduplicates notifications, it retries
them, and the app's restore POST can land at the same moment: without the lock two
payloads both read the same `purchased_at`, both conclude they are current, and
whichever writes *last* wins — an old EXPIRED overwriting a fresh DID_RENEW, and
the subscriber silently losing Pro until the next notification happens to arrive.
`with_lock` reloads inside the transaction so the comparison reads committed
state. `ActivateSubscriptionConcurrencyTest` is a real two-thread test for it; it
fails most runs with the lock removed. A first purchase has no row to lock, and
the unique index on `original_transaction_id` arbitrates that race instead, with
the `RecordNotUnique` rescue re-applying against whichever write won.

A transaction with no `expiresDate` at all lands as `expired`, not `active`. It
could never have granted Pro either way — `entitling` compares
`expires_at >= now` and NULL never matches — but since keeping `status` honest is
now that column's only job, a row reading "active" while entitling nothing would
be a lie told to whoever reads the table next.

**`POST /apple/notifications` is what keeps Pro true after the first billing
period.** StoreKit tells us about the original purchase and nothing else; every
renewal, cancellation, billing failure, refund and expiry afterwards arrives as
an App Store Server Notification V2. Public and unauthenticated — the JWS
carries its own proof — and it always answers
2xx for a notification it understood, because Apple retries any other status for
days and no retry can turn a notification for an unknown subscription into one we
can attribute (the `appAccountToken` is a one-way HMAC, so a notification
identifies a subscription, not an account). Configure the Production and Sandbox
URLs in App Store Connect under App Information → App Store Server Notifications.

`ExpireSubscriptionsJob` runs daily and is deliberately **not** load-bearing.
`Subscription.entitling` reads `expires_at`, so an unrenewed subscription stops
entitling Pro the moment it lapses whether or not the job has run and whether or
not Apple's notification arrived — imports go back to costing credits and
`ProChannel` stops contributing its grant on the very next request. The job only
keeps `status` honest for support and reporting. That a dropped notification
costs accuracy in a column rather than an entitlement somebody keeps for free is
precisely what the derived design bought.

#### Pro is no longer sold

There used to be a paywall here: `/app/pro` showed plan cards with prices
("$10 / month" / "$100 / year", a "SAVE 17%" badge), a `pro_plan_controller`
that carried the chosen product id onto a purchase button, and a "Restore
purchases" action wired to the `bridge--apple-purchase` Stimulus controller and
StoreKit. All of that UI is gone: `/app/pro` now explains that Pro is free to
ask for and links out to the Langlets Discord
(`App::ProController::DISCORD_INVITE_URL`) so someone can introduce themselves
and get it granted by console (`User#pro!`, see *Langlets Pro* above). The
`pro_plan_controller` Stimulus controller was deleted outright — it existed
only for the plan cards. `bridge--apple-purchase` (the JS controller and the
native Swift/Kotlin bridge component behind it) was deliberately **left in
place but disconnected**, along with the whole Apple verification/webhook
stack described in *Apple subscriptions* above, rather than removed with the
purchase UI.

`can_view_pro_screen?` (`ApplicationController`, renamed from
`can_purchase_pro?`) is the gate: it used to be `native_app? && !android_app?`,
because only iOS could drive StoreKit. Now that the screen has nothing to
transact — just a link — it is plain `native_app?`, so both native shells show
it; a browser is still redirected away, since every Pro CTA in the app is
written for the native shell and the web equivalents keep their own
`out_of_credits_web_hint` copy instead of linking here.

#### The Pro screens

`/app/pro` and `/app/pro/success` are one full-screen native modal sharing a
stack, so `#show` redirecting an already-entitled user to `#success` stays
inside the sheet the user opened. `modal_style: full` rather than `medium`
survives from the paywall days but still earns its keep: the Discord
explanation, the CTA and the fine print need to be visible without scrolling on
the smallest supported iPhone. The confirmation redirects a visitor with no
entitlement back to the offer, so neither screen can assert something the
database disagrees with. `/app/pro/success` also drops the price receipt it
used to show (`%{plan} plan · %{price} · renews %{renews_on}`) — there is no
price to name any more — and only shows the "Manage or cancel anytime in
Settings" line when `@subscription.apple_plan` is present, i.e. for a genuine
historical Apple purchase; a console grant has nothing in App Store Settings to
point at.

Home renders `app/home/_pro_card` directly under the header. It has two states
and a third in which it renders nothing:

- **Out of credits, no subscription** (`!current_user.credits?`) — the upsell.
  Headline "Upgrade to Pro to import more content", one line saying the free
  imports are spent, and a filled accent pill reading "Upgrade to Pro". The
  whole card is the link to `app_pro_path`; the pill is a `<span>`, since a
  button inside an anchor is invalid and unreadable to VoiceOver.
- **Subscribed** — a plain "Langlets Pro · ACTIVE" statement, never hidden. A
  subscription the app stops mentioning is one people forget they are paying
  for, and then dispute.
- **Free, with credits left** — nothing. The upsell used to render for every
  free account behind a "used N of 3 free imports" meter, which put a full
  progress bar and a nag above everything else on Home for any account holding a
  balance (a tester with 900 credits saw a maxed-out bar). `credits?` — the same
  question the import path asks before accepting a paste — is what gates the
  card now, so it appears exactly when the next import would be refused, and the
  free-import count it used to display is gone from Home entirely.

Its strings are keyed `app.home.pro_card.*`, matching the partial that looks
them up lazily. They sat under `app.home.index.*` for a while, which resolved to
nothing and rendered Rails' humanised key names — the card literally read
"Title" / "Free Used" on device.

Add Video reflects the entitlement on both platforms — Pro is granted to the
*account*, not a device, so the browser honours it too. `pro` suppresses
the insufficient-balance state, the price line reads "Included with Pro", the
approve label comes from `AppHelper#app_approve_label` (shared by both previews so
the two surfaces cannot describe one charge differently), and the web sidebar
replaces its balance block with "Langlets Pro — unlimited" rather than quoting a
meter that no longer runs. (That sidebar also held a "Buy More" PayPal form; it
is gone for everyone, not only for subscribers.)

The native Profile page carries the same entitlement as a plain status card
(`profile.account.*`), gated behind `native_app?` since the Pro screen it links
to is native-only — the web profile page never renders it. A free account shows
the "Free" pill and a full-width "Upgrade to Pro for unlimited imports" button
linking to `app_pro_path`; a Pro account shows the "Pro" pill and a one-line
description instead of the button. It reads `current_user.pro?` directly
rather than duplicating Home's `credits?` gating, since unlike the Home
upsell — which appears only once the free tier is actually exhausted — this
card's job is to state the account's plan whenever the user goes looking for
it, not to nag.

`import_requests` carries no billing columns at all. `charged`, `refunded` and
`pro_covered` were all removed: the first two mirrored a ledger that now keys on
the publication rather than on the request, and the third existed only so
`Imports::Settlement#enroll!` could tell a subscriber's own import from a
`:joined` rider who had paid nothing. Riders pay now, so every `ImportRequest`
settles as `imported` and the question no longer arises.

#### **Enrollment** (`enrollments`)
- **Purpose**: "this course is on my Home". Unique on `(user_id, course_id)`.
- **Why it exists**: enrollment could not be inferred. A created course is `courses.user_id`, a started course is implied by `lesson_users` — but the Library's "+ Learn this" adds a course to Home *before* any lesson is completed, so it needs a record of its own.
- `source`: `imported` (this user asked for this course, and it was published into their own channel), `library` (added from the catalog with "+ Learn this", which enrolls without publishing and is free), `playlist`. Every `ImportRequest` now settles as `imported`: there is no free rider to tell apart, because riding along on somebody else's run still ends in a publication of your own.
- `last_practiced_at` is Home's canonical "started" signal: "Keep it going" only includes enrollments where it is non-null, ordered newest first. Clearing it keeps the enrollment/library membership while returning the course to an un-started state.

### Notifications

Everything the app tells a user goes through one subsystem. Before it, "your
course is ready" existed twice — a mailer view and an APNs payload builder that
each wrote the same sentence — and nothing recorded that the user had been told,
so there was no list to show and nothing to mark read.

**`Notifications.deliver(user:, kind:, **context)` is the only entry point.**
Callers must not reach past it into `Notification`, `DeliverNotificationJob` or
`Push::Notifier` — those are how it works, not what it does.

The order matters: **record first, deliver second.**

1. `Notifications::Content.build` says what the notification is *about* — where
   it points (`url`) and the values its sentence is built from (`data`). It does
   not word it. An unknown kind raises `Content::UnknownKind` rather than
   producing an empty notification.
2. A `Notification` row is created from that: `kind`, `url`, and a `data` JSONB
   holding the interpolation values (`video_title`, `count`) alongside anything a
   client needs (`course_slug` for the iOS deep link). **No copy is stored.**
3. `DeliverNotificationJob` sends it over the channels the user asked for. The
   job means a delivery failure cannot fail the thing that caused it — both
   callers are operations that have already succeeded.

Supported kinds: `course_ready`, `course_failed`, `pro_activated`. Treat the
enum values as **append-only**: renaming or repurposing one silently rewords
every historical row that carries it.

**Copy is a template, not a column.** `Notification#title` / `#body` render
`notifications.kinds.<kind>.*` from the locale files against `data`, at the
moment someone reads it. Two things follow, and they are the point: a wording
edit reaches notifications that have **already been sent**, and the list renders
in the reader's language. Pluralization is i18n's (`count`), not
`String#pluralize`, so languages whose plural rules are not "add an s" — Hebrew,
Arabic — can be right.

What is *not* re-derived is the values. `"Despacito"` and `2` are snapshots
copied onto the row, which is what lets a notification still read correctly
after the course it is about has been deleted. The rule that keeps that true:
**`data` holds values, never ids.** A `course_id` there would put the copy back
at the mercy of the course existing. The `course_ready` lesson count is read
from persisted lesson rows when that snapshot is created; it deliberately does
not use the Course instance's association cache, which the build pipeline may
have populated before lessons existed.

The cost is that a template and the rows that feed it are a contract. Adding an
interpolation to a template that older rows have no value for makes them
unrenderable; `Notification#render` catches that (and a kind whose entry was
renamed away), logs it, and degrades that one row to
`notifications.unavailable` so a single bad template cannot cost the reader the
other ninety-nine rows on the page.

**Locale.** Only the `/notifications` page renders in the reader's language
today, because `I18n.locale` is set per request from the subdomain
(`ApplicationController#set_translation_language`) and there is no persisted
per-user locale. The mailer and the APNs payload render inside
`DeliverNotificationJob`, which has no request, so they get
`I18n.default_locale` — English. `#title(locale:)` / `#body(locale:)` take the
locale explicitly, so giving those two the recipient's own language is a matter
of persisting a user locale and passing it here; nothing else has to move.
(Note `users.preferred_language_id` exists in the schema but is dead — no
association, never written.)

`sent_at` means delivery was *attempted*, and makes the job idempotent — a retry
must not mail or push twice. It is stamped even when a channel failed and even
when there was nothing to deliver to (a push-only user with no device), because
a user who receives neither still has the notification on `/notifications`; that
is exactly what makes turning a channel off safe to offer. Email and push are
isolated from each other: a dead mail server must not cost the user their push.

Failed-course copy is deliberately generic on every user-facing surface: it
says the import failed and that the team is looking into it, without exposing
or storing the pipeline error on the Notification. `Imports::Settlement.fail!`
separately enqueues `ImportFailureMailer`, which sends the persisted failure
reason and request context only to `ynon@hey.com`. This diagnostic is independent
of the requester's notification preferences and keeps import escalation policy
out of the generic notification delivery job.

`read_at` is independent. `Notification.mark_all_read!` is one UPDATE, not a
load-and-save loop, because it runs on every app launch.

**Delivery preference.** `users.preferences["notification_delivery"]` is the
**list** of channels that are on — any of `email` and `push`, defaulting to
both, chosen with a checkbox each on the Profile page. A list rather than an
enum because the channels are independent: it says everything a `both` option
did and adds the empty list, meaning the notification is recorded and delivered
nowhere. Unset (anything not a list) reads as the default; `[]` is a real
choice and survives the round trip, which is why the form carries a hidden
blank — an all-unchecked form otherwise submits nothing under that name.
`User#notification_delivery=` intersects with the known channels, so what is
stored is always canonical and never holds a channel the job can't read.

It governs this subsystem **only** — Devise confirmations and password resets,
and Channel invitations, are answers to something the user just did, and
silently dropping them would break the flow that asked for them.

**The list.** `/notifications` (`NotificationsController`) is one controller and
one view for web and the native shell; only the layout differs, picked the way
the Profile page picks it, so the read/unread rules cannot drift between
clients. It is reached from the profile menu on both clients, which also carries
an unread count badge (`ApplicationController#unread_notifications_count`).
Unread rows are marked **NEW** and carry an X that marks that one read over Turbo
Stream; "Mark all as read" does the lot. Nothing is ever deleted from the list —
it is the record of what the app has told this user.

`index` snapshots which rows were unread **before** rendering (`@unread_ids`),
which matters because of the next paragraph.

**"Entering the app" means you read everything.** The native app layout mounts
`notifications-reader`, which POSTs `read_all` on connect and again whenever the
page becomes visible — iOS has two ways in, a cold launch (a page load) and a
return from background (no page load). That is what zeroes the app icon badge
count. Because the list snapshots unread state before that report lands, a user
who opened the app *to look at what is new* still sees it.

`import_requests.notified_at` was the old push idempotency stamp, sent straight
from the request. It has been dropped: the Notification row is what makes
delivery happen once now, and the column was a second copy of a fact that moved.

### Workflow Management

#### **ImportRequest** (`import_requests`) — the Queue

A user's request to turn a video into a course. There are three distinct things in the import flow and it's worth being precise about which is which:

| | Scope | Keyed on |
|---|---|---|
| `CreateSongProgress` | the **shared neutral pipeline cache** — no `user_id` | `(youtubeurl, clip_language)` |
| `Course` | the **shared output** — one per video+L1 | `(youtube_video_id, language_id)` |
| `ImportRequest` | the **per-user intent** | `(user_id, youtube_video_id, clip_language, translation_language)` while active |

> **One `CreateSongProgress` → many language-keyed translations and `ImportRequest`s → one shared `Course`.**

Two users importing the same video deliberately share one pipeline and one course; the AI work happens once. That's why per-user state (status, credit linkage, retry) can't live on either of the shared records — and why being told about it is per-user too: a `Notification` belongs to the requester, not to the course.

- An `:adopted` request is created directly as `ready` rather than passing through `queued`: there is nothing to wait for, and an active row would sit under `idx_import_requests_active_dedupe` for a course that is already finished.
- `idx_import_requests_active_dedupe` is a **partial** unique index over active (queued/importing) rows, so a double-tapped Import button is a database impossibility. While the language is unknown, `idx_import_requests_detecting_dedupe` separately enforces one detecting row per user, video, and translation language; an ordinary nullable unique key would allow duplicates because PostgreSQL treats NULLs as distinct. Failed imports remain visible and removable, but the Queue does not offer a user retry: an accessible info tooltip explains that the human team is reviewing the automatic import and that the user will be notified when it finishes.
- `clip_language` and `translation_language` must differ. `Imports::Create` rejects the pair before charging, and the `ImportRequest` model enforces the invariant for console and other direct writes as well.
- `progress_percent` is **written forward** by `CreateSongProgress#sync_import_requests_progress`, never computed on read — `data` is a multi-megabyte jsonb blob and the Queue polls.

**`ImportRequest#retry!`** is the operator's way back from a failed import — console only, never called automatically, and not exposed in the Queue. It raises `ImportRequest::NotRetryable` unless the request is `failed`, still has its course and `CreateSongProgress`, and isn't shadowed by another active request for the same tuple (which `idx_import_requests_active_dedupe` would reject anyway). It then, in one transaction:

| Move | Why it can't be skipped |
|---|---|
| status → `queued` | `CreateCourseJob#start_imports!` and `Imports::Finalizer#pending_requests` only see **active** rows: the pipeline would run for nobody. |
| `created_at` → now | `Imports::Finalizer` fails a request whose record holds an error newer than it. A resumed run clears an error only for a step it actually re-runs, so the **previous** run's entry outlives the retry and re-fails it in seconds. `since:` already exists to discount an older run's failures; the alternative — deleting entries from `data["errors"]` — edits a record shared with every other import of that video. |
| course → `pending` | `Course#process` only claims a pending course, so `CreateCourseJob` would log "already processing" and return. |
| new `ImportRequestTimeoutJob` | `schedule_timeout` is an `after_create_commit`, so a retry would otherwise have **no deadline at all**. |

Which run it starts mirrors `Imports::Create`: a **published** course keeps its status and gets an `AddCourseTranslationJob` for the failed language only (unpublishing a live course over one translation would break it for everyone); an unpublished one gets `CreateCourseJob`. If another **active** request already covers this course, no job is enqueued at all — the retry rides along on that run, exactly as `Imports::Create#join!` does, rather than putting two sets of callbacks on one blob.

Credits do not enter into it: the failure took nothing, a retry is us fixing our own import rather than a second sale, and however many times an operator restarts it the user buys the course once — the ledger key is the `(channel, course)` pair.

**`ImportRequest#destroy_with_artifacts!`** is the destructive operator tool
for permanently removing a non-active request together with its exclusive
Course, media, and `CreateSongProgress`. The entire cleanup is transactional
and raises `ImportRequest::ArtifactsNotDestroyable` without deleting anything
when the request is queued/importing, another ImportRequest references its
Course or progress, another Course references its progress, or a lesson outside
the Course references one of its media. Ordinary Queue deletion does not call
this method: shared artifacts remain the normal case, and ready/failed Queue
deletion removes only the per-user request.

**`Course#regenerate!`** is the destructive operator tool for rebuilding an old
course with the current pipeline. It empties the matching
`CreateSongProgress.data`, deletes the old medium (and therefore its phrases,
tokens, lessons, and activities), deletes the old course, and creates a fresh
course shell with the same identity fields. Existing import-history rows are
moved to the replacement shell.

It regenerates **every language the course was built in**, not just one: one
`ImportRequest` per `course_translations` row (reusing an existing request for
that owner/course/language where one already exists, the same way the
single-language version used to), each forced to `failed` and passed through
`ImportRequest#retry!` in `course_translations` order. Only the first actually
starts a run — `ImportRequest#covered_by_sibling?` finds the rest already
covered by that active sibling on the still-unpublished course and leaves them
`queued` — and `Imports::Finalizer#request_missing_languages!` picks the
remaining languages up as outstanding once the first one publishes, exactly
the mechanism an ordinary multi-language import uses. The method returns the
first (primary) request — the one that actually enqueued `CreateCourseJob`.

#### **Imports::Create** (`app/services/imports/create.rb`)
The single import service for the Add sheet, the share extension and the API. It decides **what has to happen** and deliberately does not decide what it costs — `Channel#publish!` charges for the publication every path ends in (see *What a credit buys*). Order is deliberate: **the video is checked before anything is committed**, so a private or deleted video costs nothing and leaves nothing behind (`Youtube::Oembed` doubles as the availability check). The interactive Add sheet omits `clip_language` and gets the provisional background-detection path. The API detects first and supplies `clip_language`, preserving its synchronous response contract for share-extension callers. Six outcomes:
- `:created` — queued the pipeline (or, with no source language, a detecting request and `DetectImportLanguageJob`). Charged when it publishes.
- `:adopted` — **somebody else already built it**. There is no pipeline to run, so the course is published into this user's channel on the spot and charged there; the request is written straight to `ready`. This is the case the old `:deduped` handled for free, and getting it free was the inconsistency this design removes.
- `:deduped` — already in **this user's own** channel and ready. Nothing to publish, so nothing to charge; enrolls if the enrollment had been removed.
- `:joined` — **someone else is importing it right now**; rides along on their course rather than starting a rival one. Without this, both users create a pending course and whichever publishes second violates `idx_courses_published_video_pair`. Sharing the run is not a discount — the rider's own publication is charged when the run lands.
- `:already_queued` — this user already asked; one publication, one charge. Checked inside the published-course branch as well, so a course that publishes while their request is in flight cannot be sold to them twice.
- `:paused` — theirs, in a Pro library the subscription no longer lends back. Nothing charged, nothing enrolled.

Jobs are enqueued **inside** their transactions — Solid Queue is Postgres-backed, so each job row commits atomically with the state it acts on. Enqueuing after commit would leave a request nothing ever picks up.

Successful Add Video submissions redirect to `/gallery?imports=pending`, where
the provisional request is immediately visible as “Detecting language…”.

Users are **not** enrolled at import time: the course is `pending` and has no lessons, so Home would show something unopenable. `Imports::Finalizer` enrolls everyone attached once it publishes.

#### Course-ready notifications

Once `Imports::Finalizer` publishes a course, it marks every attached
`ImportRequest` ready, enrolls that request's user, and — through
`Imports::Settlement.complete!` — records one `course_ready` Notification per
request. Delivery is deliberately outside the course-building transaction: an
APNs outage or a bouncing mailbox must not turn a successfully built course into
a failed import. See *Notifications* below for how the row becomes an email
and/or a push.

`complete!` locks the `ImportRequest` row before writing `ready` to it, and
only notifies if *that* write is the one that actually flips the status
(`saved_change_to_status?`). This is what makes "one notification per request"
true even though the pipeline's concurrent callbacks can enqueue more than one
`FinalizeImportsJob` for the same completed run (see *Course-ready
notifications* above and `PipelineCallbacksController#finalize_later`): the
loser of the row lock finds the request already `ready` and its own write is a
no-op, so it skips the notify step. `publish!` and `enroll!` stay unguarded
inside the same lock — they were already safe to repeat — so `Imports::Create
#adopt!`, which writes `ready` itself before calling `complete!`, still gets
its publish/enroll done; it just never reaches the notify step, because it
always calls with `notify: false`.

`Imports::Settlement.fail!` is the mirror image and the single place a
`course_failed` notification comes from, which is why every failure path — the
finalizer, `ImportRequestTimeoutJob`, `CreateCourseJob`,
`AddCourseTranslationJob`, `DetectImportLanguageJob` — routes through it. It
notifies the user who **asked**, not the course's creator: on a joined import
those are different people and only one of them is waiting. Re-failing an
already-failed request is silent, so the finalizer and the timeout job racing
cannot notify twice.

The same first failure also enqueues the admin-only `ImportFailureMailer` with
the technical reason, requester, source URL, and import/course identifiers.
That operational email is deliberately initiated here rather than by
`Notifications::Deliver` or `DeliverNotificationJob`: the notification system
only delivers the generic user message and has no failed-import policy.

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

`Push::Notifier` puts the published course slug in the APNs custom payload
(`course_slug`, alongside `url` and `notification_id`). Notification taps are handled on both iOS paths: `UNUserNotificationCenterDelegate` for a running app and `UIScene.ConnectionOptions.notificationResponse` for a cold launch. Both reset the Home navigator to `/app?just_imported=<slug>`. `App::HomeController` only resolves that slug through the signed-in user's published enrollments, then renders the newly created course as the **JUST IMPORTED** hero whose **Start Course** button enters the standard course experience. An invalid or unauthorized slug safely falls back to ordinary Home.

Note the notification's own `url` is the course page (`/courses/:slug`), not
`/app?just_imported=…`: that screen is native-only and bounces a web reader to
the home page, and the native deep link does not read `url` anyway.

**No tab carries a badge.** The Library tab used to show active imports, which
competed with the app icon badge for the same attention while meaning something
else entirely. `AppTabBarController.setLibraryBadge` is gone. The `tab-badge`
bridge message survives because receipt of it is how `SceneDelegate` knows an
authenticated app layout rendered and the tab bar is safe to reveal; its `count`
is now vestigial.

The app icon badge is the unread notification count, sent with every push
(`Push::Notifier#badge`) and cleared from two sides when the user comes back:
`SceneDelegate.sceneDidBecomeActive` clears the icon locally, and the
`notifications-reader` controller in the app layout reports `read_all` to the
server, so the *next* push carries a fresh, smaller number rather than
re-badging what the user has already seen.

#### iOS Share Extension

The `LangletsShare` extension accepts shared web URLs and plain text, extracts a
YouTube or TikTok link, and immediately submits it to
`POST /api/v1/import_requests`. It has no language menus, confirmation button,
or success screen: after the API accepts the idempotent request it calls
`completeRequest`. Errors remain visible so authentication, credit, or network
problems are actionable. The translation language is English on this main-host
API; the source language is always detected by the pipeline.

**The endpoint queues; it does not detect.** `Api::V1::ImportRequestsController#create`
used to run `CreateSongPipelineHttp.detect_language` inline so the response could
carry a post-dedupe status and the final credit balance. That is a pipeline round
trip which downloads and analyses the video, and the sheet held a spinner for
roughly ten seconds waiting for it — long enough that users cancelled. It now
calls `Imports::Create` with no `clip_language`, taking the same provisional
`detecting` path the Add Video form takes, so `DetectImportLanguageJob` does the
detection and the reply is one oEmbed call away. The extension's request carries
an 8-second `timeoutInterval`: its only control is Cancel, so a stalled network
has to become a sentence rather than a spinner, and the `client_token` makes the
retry that invites free.

Two consequences of moving detection off the request:

- **`status` comes back `detecting`, never `ready`, on a first POST.** Which
  course a link resolves to depends on the source language, so "already in your
  Library — no credit used" cannot be known yet. Adoption, the paused-library
  refusal, and the charge all happen in the job moments later; the Queue and the
  "your course is ready" push are what report them. The extension's `ready`
  branch now only fires when a `client_token` replay finds a finished request.
- **A detection failure is a failed Queue card, not a 422.** The
  `language_detection_failed` response is gone, because nothing is waiting for
  it.

An unresolved edge inherited from the Add Video form, now reachable from the
share sheet too: when detection resolves to a course in the user's *paused* Pro
library, `Imports::Create` returns `:paused` and the job discards it, leaving the
row `detecting` until `ImportRequestTimeoutJob` fails it ten minutes later.

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
| `Imports::Settlement` | **Delivery.** Publish into the user's channel (which is where it is charged), enroll, notify — or record why it failed. |

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
that acts on it are not atomic), then fails with the pipeline's own reported
error as the reason when there is one. Nothing was charged, so nothing is
returned.

This replaced a design where the trigger blocked on the run for up to
`PIPELINE_READ_TIMEOUT` seconds. That held a worker thread per in-flight import,
and its timeout only fired if the pipeline hung *in the HTTP read* — a run that
died any other way left the request `importing` forever.

Two failures are handled early rather than waited out:
- **The trigger never got off the ground** (unreachable pipeline, bad config).
  The trigger job still owns this one; it fails the attached requests in its
  rescue, at no cost to any of them.
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
Nothing is charged until `Imports::Settlement#complete!` publishes the course into
the user's channel, which makes every failure path free by construction: a raise
in a trigger job, a blocking pipeline error, a timeout, a cancelled queue item —
none of them ever reached `Channel#publish!`, so none of them has anything to give
back. That is why there is no refund in any of them and no `refunded` column to
keep straight.

Solid Queue records an unhandled execution as failed and does not retry it unless
the job declares a retry policy, so **a raise in a job is final**. Do not add
`retry_on` naively: the rescue sets the course to `error`, and `Course#process`
only claims a `pending` course, so a second attempt would silently do nothing.

#### 20. **CreateSongProgress** (`create_song_progresses`)
- **Purpose**: Track async content creation pipeline
- **Key Features**:
  - YouTube URL processing (`youtubeurl`)
  - Multi-step workflow management (integer step field)
  - Source language only (`clip_language`) — no language of its own for the
    translation side; `data["translations"][iso]` holds one payload per
    language the pipeline has produced, and every caller names the language it
    wants explicitly (see above)
  - JSONB data storage for flexible progress tracking
  - Unique on `(youtubeurl, clip_language)` where `clip_language IS NOT NULL`
    (`idx_create_song_progresses_video_language`)

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

Token audio jobs explicitly enqueue after the surrounding database transaction
commits. Course building creates tokens inside one transaction, so making those
jobs visible to the dedicated Solid Queue worker any earlier would let it look
up an uncommitted `PhraseToken`, discard the resulting `RecordNotFound`, and
leave the token without audio.

Both `GeneratePhraseAudioJob` and `GenerateTokenAudioJob` run on the `audio`
Solid Queue queue, not `default` — see "Production deployment" above for why.

For an existing course with missing token audio, operators can enqueue repairs
from a production Rails console with
`Course.find(id).enqueue_missing_token_audio!`. The method enqueues only tokens
that do not currently have an `l1_audio` attachment and returns the number of
jobs enqueued.

`BackfillMissingTokenAudioJob` is the automatic safety net. Solid Queue runs it
daily at 05:30; it finds every `PhraseToken` that is more than six hours old and
still lacks an `l1_audio` attachment, then enqueues the normal
`GenerateTokenAudioJob` for each one. The age threshold gives freshly created
tokens time to finish their normal post-commit audio jobs before the backfill
considers them missed.

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
  - Browser auth pages have a top-left close button; native auth is a non-dismissible full-screen root and omits it
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

#### Path Configuration (screen presentation)

`SceneDelegate` loads path configuration from two sources, **in order**:
1. `.file(...)` — the copy bundled at `langlets-ios/langlets/langlets/Configuration/path_configuration.json`. Offline fallback and first-launch seed.
2. `.server(...)` — `GET /configurations/ios_v1.json`, served by `ConfigurationsController` from `config/hotwire/ios_path_configuration.json`. **This one wins at runtime**, so routing rules can change with a Rails deploy instead of an App Store release.

> **Rule order is the opposite of what it looks like.** Hotwire Native merges the properties of *every* rule whose pattern matches, with **later rules winning** (`PathConfiguration#properties`: `properties.merge(rule.properties) { _, new in new }`), and patterns are unanchored regexes so `.*` matches everything. The catch-all therefore belongs **first**, as the baseline that later, more specific rules override.
>
> It used to sit last, which silently defeated every modal rule in the file — lessons and `/new` were presenting as plain pushes no matter what they asked for. Fixed in Phase 3; keep the most specific rules at the bottom.

Two more things to know before touching this:
- `ConfigurationsController` inherits `ActionController::API`, *not* `ApplicationController`. Under `ApplicationController`, `require_authentication_for_native_app` would answer a signed-out native request with a redirect to the sign-in page and the app would parse that HTML as path configuration.
- The bundled and served copies must stay identical in the repo; `test/controllers/configurations_controller_test.rb` enforces it. Edit both together.

#### The app screens (`/app`)

Home, mobile Library, Create/Add-a-video and the Pro screens live under `App::BaseController` (`app/views/app/**`, `layouts/app.html.erb`). Home, `/app/library`, and `/app/pro` are **native-only** — `require_native_app` redirects browsers to `root_path` — with a `?native=1` session escape hatch (non-production) so the CSS can be worked on outside the simulator. (There was a `/app/credits` screen here too; it existed to sell consumable credit packs and was deleted with them.) `App::ImportRequestsController` skips that presentation gate so authenticated browsers can use Create/Add Video. The web Library is `/gallery`, and the shared authenticated web menu links to Gallery and Create.

**`/app/import_requests/new` is the Create entry point on both platforms, and also the Create tab's root** — there is no `#index` action or route; the bare `/app/import_requests` collection path only accepts `POST` (`#create`). Earlier the tab root was the bare path and `#index` redirected browsers to `/new`; that indirection was removed since nothing ever needed the bare path to resolve on its own. In the native app `/new` renders the Add-a-video form directly; there is no intermediate status list or Add New button. A browser hitting `/new` gets the responsive web variant of the same form. Import status lives in Library: `/app/library` on mobile and `/gallery` on web. The old Queue templates and polling controller remain in the tree but are no longer rendered by anything reachable.

The web course UI exposes the shared Queue/Add Video flow through the user menu. Signed-in native users at the web root are redirected to `app_home_path`. That redirect and the remaining `App::BaseController#require_native_app` gates use the single `native_app?` predicate, which recognizes the stable `LangletsNative` user-agent marker. There is no version-specific native routing. Deciding the destination server-side rather than changing the app's start location means it can change without an App Store release.
The web Add Video sidebar states the available balance and nothing more. It
carried a **Buy More** PayPal form beside it until individual credits stopped
being sold; there is now no checkout on the web at all, and the sidebar closes
with the sentence explaining that the Pro screen is native-only.

The iOS app uses `AppTabBarController`, a native `UITabBarController` with one Hotwire `Navigator` per Home, Library and **Create** tab (the Create tab is `/app/import_requests/new`, drawn with the `plus.circle` SF Symbol). Navigators load lazily on first selection, then retain their webview and navigation stack, so later tab switches are immediate and preserve scroll/page state. `SceneDelegate.handle(proposal:from:)` intercepts exactly one path — `/`, which clears the source navigator and returns to the Home tab. It does **not** intercept the other tab roots: a link to `/app/library` or `/app/import_requests/new` from inside another tab is accepted and pushed onto that tab's stack, with a back arrow, while the tab itself keeps its own separate webview. That is deliberate for Home's first-run Create link (below); if you ever need a real tab switch from a link, it has to be added to this method. **The tab bar's selected-item colour is not set in Swift.** No `tintColor` is assigned anywhere; the tab bar inherits the window tint, which comes from the asset catalog's `AccentColor.colorset` via `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` in `project.pbxproj`. That colorset is the app's green `#1DC77C` — the same value as `--color-app-accent` in `application.tailwind.css`, kept in sync by hand, so change both together. It was coral (`#F43E36`) until the tab bar was brought in line with the web accent. Because it is the *global* accent it also tints nav-bar buttons and system controls, which is the point: one accent across native chrome and web content. Note `Assets.xcassets/Colors/Brand*.colorset` (`BrandAccent`, `BrandAccentLight`, `BrandText`, `BrandBackground`, `BrandBackgroundSecondary`) are referenced by nothing in the project and still hold the old coral palette — dead assets, not a second source of truth. The dark app background is a third, separate hard-coded value: `appBackgroundColor` in `SceneDelegate.swift`.

Authentication (`/users/sign_in`, `/users/sign_up`, password recovery, and provider handoffs) is a default-context `replace_root` flow on both platforms, not a modal. A signed-out user has no meaningful underlying app screen to dismiss back to, so the native auth pages also omit the HTML close X. The tab bar starts hidden and is revealed only after the authenticated app layout reports through the tab-badge bridge. Entering an auth URL hides tabs immediately in the iOS proposal delegate or Android route handler, while the rendered application layout independently sends `bridge--tab-visibility visible=false`; that second assertion covers server redirects because native proposal handlers may only see the pre-redirect URL. Sign-out hides tabs through its bridge as well. Authentication and language changes invalidate all three navigators; the visible tab reloads immediately and background tabs reload when next selected.

Email/password registration does not return an unconfirmed user to the home or
sign-in page. `Users::RegistrationsController#after_inactive_sign_up_path_for`
redirects to `/users/sign_up/check_email`, which tells the user to open the
confirmation email and press its link before continuing, with a route to resend
the message. This is one shared Devise-rendered page for web, iOS, and Android.
Its `/users/sign_up` prefix keeps it inside the native authentication
`replace_root` rule, and the application layout keeps both native tab bars
hidden. Confirmation resend is part of the same native authentication rule and
omits the browser-only close control.

**A course opened from the Create navigator lands on Home, not on Create's stack.** `SceneDelegate` intercepts any `/courses/…` proposal originating from that navigator, clears Home to its root, selects the Home tab and re-runs the proposal there. Courses opened from Home or the Library are untouched.

The handoff also unwinds Create's own stack on the way out. A deduped import redirects straight to `course_path`; `openFromHome(_:leaving:)` prevents the spent form from remaining under the back arrow. An already-importing preview links to the Pending filter in Library instead of back to Create, because Create now contains only the form.

This rule **cannot** be expressed in path configuration, and that is a structural property worth remembering rather than a limitation to work around: path configuration is a function of the URL alone, and `/courses/:id` is the same URL from all three tabs. `NavigatorDelegate.handle(proposal:from:)` is the only place the *source* of a visit is known, so any rule of the form "this destination behaves differently depending on where it was reached from" belongs there. The cross-tab root interception above uses the same lever.

The tab-root profile menu is an HTML `details` element managed by `profile_menu_controller.js`: a document-level click closes it when the tap lands outside the menu. Because each native tab retains its webview and HTML state, `AppTabBarController` also closes open profile menus in tabs moving to the background whenever the user switches tabs, including programmatic cross-tab routing.

**Every tab root renders `app/views/app/shared/_header.html.erb`, and there is only one of these.** A tab root has no back arrow and no native chrome of its own, so the header's avatar is the only route from it to Notifications, Profile, Invitations and Sign out; a root without one is a dead end the user can leave only by switching tabs. Library and Create were exactly that until this partial became shared, because the menu was inline in a header only Home rendered. Rendering it is what makes the omission impossible to repeat — a new tab root gets the menu by existing.

Its optional `title:` local decides the left-hand side and nothing else. Pass a screen name and the header draws it as that page's `<h1>` (Library, Create); omit it and it falls back to the wordmark, which is what Home wants — Home has no title of its own, the brand *is* its title. Do not render both: `langlets.` above `Library` is two heavy rows naming a brand the user is already inside. The avatar lands in the same place either way. The menu is guarded on `current_user`, so the header is safe to drop into a title row on screens that can render without one.

Screen furniture belonging to a single tab stays out of the header — see the credits pill on Create.

The native tab controller, navigator roots and non-opaque webviews all use the app background token (`#0A1521`). A lazily loaded tab can therefore expose its empty native surface while the first request is in flight without producing a white flash before the web page renders.

**App icons on both stores are ports of `public/icon.svg`** — a rose speech bubble (`#F43F5E` → `#FB7185`) with a play triangle, on a slate gradient (`#0F172A` → `#1E293B`). Note this is *not* the app accent green: the icon is the brand mark, and `colors.xml` / `AccentColor.colorset` remain the palette for native chrome only. There is no build step that regenerates either icon, so changing `icon.svg` means porting it twice:
- iOS: `Assets.xcassets/AppIcon.appiconset`, three flattened 1024px PNGs (light, dark, tinted).
- Android: an adaptive icon in `res/mipmap-anydpi-v26/ic_launcher.xml` over three vector drawables — `ic_launcher_background` (the gradient, with stops anchored at 18,18 → 90,90 so the full ramp falls inside the 72dp a launcher actually shows), `ic_launcher_foreground` (the mark), and `ic_launcher_monochrome` (the same geometry, flat black, for themed icons — the launcher tints it from the wallpaper, so only its alpha survives). The two mark drawables carry `icon.svg`'s path data verbatim in its own 1024 viewport and reach this 108dp canvas through nested `<group>` transforms, so a change to the SVG can be pasted straight in. Android was a green wordmark period until this port.

**There is no floating "+" on Home, Library or Create.** Creating a langlet is the Create tab's entire job, so its root is the form itself. Home has no paste box. `app/views/app/shared/_fab.html.erb` survives only for the Started-videos screen; do not reintroduce it on the three tab roots. The native controller owns the tab bar and the `tab-badge` bridge mirrors the active-import count onto the Library item. The native web views extend beneath `UITabBar`, so every scrolling app screen uses `app-scroll-pad` to reserve the full tab-bar height plus the bottom safe-area inset.

- **Home is compact and action-first** (`App::HomeController#index`), one layout for every account state bar one conditional first-run affordance (see below). Product explanation lives in onboarding rather than on this repeat-use screen. Home no longer carries a YouTube/TikTok paste control — that whole flow belongs to the Create tab, so Home does not compete with it. (The old `_paste_cta` partial and its `app.home.paste_cta.*` strings are gone; `/app/import_requests/new?url=…` still auto-resolves a preview via `add_video_controller#connect`, which is how the share extension and any deep link enter the Add screen.) Home is: an optional "just imported" hero, the two most recently practiced unfinished courses under a muted **"Continue"** heading, and four compact Library suggestions in a **2×2 grid** with neutral navigation/action styling. Personal playlists follow when present. The started-videos screen uses non-null `Enrollment#last_practiced_at` as the canonical started signal and includes completed courses. Suggestions are the **newest** published courses in the learning language that the user has not enrolled in — `library_picks` orders by `created_at DESC`, not `RANDOM()`. Two reasons it is no longer random: the first-run subhead promises "any recently created Langlet", which random picks would make untrue, and a grid that reshuffles on every visit gives a returning user nothing to recognize. Playlists include empty ones but exclude system and other users' playlists.

- **Home's first run is the one conditional state** (`first_run = @hero_course.nil? && @enrollments.empty?`, computed in the view). Before this, an account with nothing enrolled saw the wordmark, the section label "Library", and four random cards — no framing and, since `_fab` is not rendered on Home, no visible way to create anything. Two things change while `first_run` holds, and only then: the grid's `<h2>` reads **"Jump right in"** (`app.home.index.first_run_library`) instead of "Library", and a secondary text link — **"Or import any YouTube / TikTok video ›"** (`first_run_create`) — sits below the grid. The heading is word-for-word the marketing root's `courses.index.library.heading`: the same moment for the same person, and the Hebrew was already written. It is duplicated rather than shared, because a later change to one is not automatically right for the other. That section's **subhead was tried and removed** — the cards say what they are, and a line of prose between the heading and the grid pushed the grid down for nothing. Do not reinstate it. The link renders **outside** the `@library_picks.any?` guard on purpose: a learning language whose library is empty produces an otherwise blank Home, which is exactly when it is the only thing on screen. Both revert the instant the user has a hero or a single enrollment, so returning users never pay for the onboarding.

  The library section's **"See all ›" is accent-coloured in both states**, matching the first-run Create link: they are the two ways off that section and should read as the same kind of affordance. The "See all" in **Continue** stays muted (`text-app-text-2`) — it sits under a muted uppercase heading, where accent would outweigh the in-progress courses it points at.

  It points at the Create tab root (`/app/import_requests/new`), which is the Add-a-video form itself. Per the tab-root note above this is a plain push with a back arrow, not a tab switch. Deliberately **not** a permanent intro paragraph at the top of Home — `onboarding/welcome` already says what the product does one tap earlier. The Hebrew `first_run_create` string carries a `‹` because the chevron flips under RTL; keep the arrow in the locale file rather than the view.
- Native course thumbnails use the same `course_youtube_video_id` fallback as the web cards and request YouTube's `hqdefault` image. This matters for legacy courses whose `youtube_video_id` column is blank but whose `main_media_url` still contains a valid ID; using the column directly produces an empty `/vi//…` image URL.
- **Design tokens** are `--color-app-*` / `app-*` utilities at the bottom of `application.tailwind.css`. **Never use `dark:` under `app/views/app/**`** — the variant keys off `[data-theme="dark"]`, which the app layout hard-codes, so it would be unconditionally on and the intent invisible.
- Tabs use `presentation: replace_root`; the sheets use `context: modal, modal_style: medium`, which maps onto a real `UISheetPresentationController` detent with no Swift. The sheets are **full pages, not Turbo Frames** — a frame overlay inside the web view fights the native modal and you get two competing dismissal gestures.
- Course lesson sheets use `LessonViewController`, a `HotwireWebViewController` subclass selected by `SceneDelegate` for `/courses/:course/lessons/:lesson` and its activity URLs. It adds a native top-right X that dismisses the whole lesson sheet; this is deliberately a close action rather than back navigation between activities.
- Review lessons get the same modal treatment as course lessons, and for the same reason: taking a review lesson is one continuous session that shouldn't expose the tab bar underneath. `ios_path_configuration.json` marks both `/review_lessons/.*` and `/review_lesson_builds/.*` (the async build's waiting/failed screens) as `context: modal` with no `modal_style`, and `SceneDelegate.isLessonURL` — the same predicate that picks `LessonViewController` for course lessons — also matches these paths, so the waiting screen, the activities and the finish page all share one modal sheet with the native close X, from the "Review words" tap through to completion. `review_lesson_builds` needs its own pattern because the `_builds` suffix doesn't match `/review_lessons/.*`. Because `NavigationHierarchyController` pushes onto the existing modal navigation stack rather than presenting a second modal when a new proposal arrives while already in modal context, the waiting page's Turbo Stream `visit` to the finished lesson stays inside the same sheet instead of stacking another one on top.
- Create presentation is platform-specific only in styling. Both platforms hit `/app/import_requests/new`; the controller branches on `native_app?` to render the compact dark form for Hotwire Native versus the responsive two-column form for browsers, with no redirect between them. Both resolve and submit through the same controller and services.
- Add Video is platform-specific at the view layer too. Hotwire Native keeps the compact pushed-screen form and result partials directly under `app/import_requests`; browsers use the responsive two-column page and result partials under `app/import_requests/web`. The browser page shares the public homepage's fixed warm-cream, ink, and coral palette plus its Bricolage Grotesque/Instrument Sans typography. Both variants resolve previews through the shared `add_video_result` Turbo Frame and the same controller/service code. The web approval form opts out of Turbo so its POST redirect replaces the whole document and returns through the Create entry point; native keeps the existing `_top` Turbo-frame submission handled by its navigator.
  The native form explicitly tells users that, instead of copying a link, they
  can share a YouTube or TikTok video directly to Langlets from the provider's
  share menu.
  The shared controller never reads `navigator.clipboard`; users paste into the
  ordinary URL field themselves, so opening either variant cannot trigger a
  browser or native pasteboard permission prompt.
- Screens are gated by `require_language_for_native_app` too: a signed-in native user with no `?lang=` is sent to `/onboarding/welcome` before any app screen is reachable.

Deliberately **not** built from the mockup, because both would be controls that do nothing: the Library's category chips (nothing populates the taxonomy until the classifier lands) and the Add sheet's "Search YouTube" segment (needs the Data API).

The two Library surfaces are `/app/library` for mobile and `/gallery` for web.
They have separate controllers and presentation, but the same ImportRequest
filter semantics. Published cards still come only from
`ChannelContentQuery`; showing an ImportRequest never grants access to a Course.
Both surfaces render All, Pending, Failed, and My imports pills:

- All shows visible published courses plus the signed-in user's active imports.
- Pending shows only that user's queued/importing requests.
- Failed shows only that user's failed requests.
- My imports shows visible published courses referenced by that user's ready
  ImportRequests, plus their queued, importing, and failed requests.

Pending, Failed, and My imports are only rendered when the current user has at
least one matching ImportRequest; All remains the stable default. A stale URL
that names a now-empty filter falls back to All.

Queued/importing requests are course-shaped cards with the provider thumbnail
when available, a status label, and the denormalized progress percentage.
Failed requests use the same footprint and retain the human-review explanation.
Ready imports are not rendered twice: once their Course is visible, the normal
Channel-backed course card represents it. The filter and search query are GET
parameters, and search applies independently to both authorized course content
and the current user's displayed requests. Gallery retains its existing Course,
Playlist, language, and search filters; ImportRequest status is an additional
single-select dimension. Its Turbo Stream result replacement redraws import and
published cards together. The web Add Video header links Library to `/gallery`
and Create to `/app/import_requests/new`.

Mobile Library additionally derives one language pill per learning language
present in the complete `ChannelContentQuery` result visible to that user. It
does not derive the pills from the current 60-card render limit, and inaccessible
Channel content cannot create a pill. All shows authorized courses across those
languages; choosing a language filters both published cards and the user's
displayed active imports. A Playlists pill appears only when the current user
owns at least one playlist and renders those personal playlists using the same
rows as Home. Search and the selected language/status are preserved in pill and
form URLs. The pills, selected state, and result list share the
`#library-results` Turbo Frame. Pill links and the search form target that frame,
so filtering replaces only the Library controls/results and does not produce a
full-page or Hotwire Native navigation event.

Empty mobile pills are omitted. Language pills already come only from visible
Channel content; Pending requires an active request, Failed requires a failed
request, My imports requires at least one non-cancelled request, and Playlists
requires a personal playlist. A URL naming a filter that has since become empty
falls back to All rather than leaving a selected pill with no corresponding
option.

#### Onboarding Flow
1. **Mandatory Authentication**: The server enforces authentication for all native app requests via `ApplicationController#require_authentication_for_native_app`. Unauthenticated native app users are redirected to the sign-in page.
2. **Welcome**: After authentication, if no `?lang=<code>` is present, the server redirects to `/onboarding/welcome`. This large, native-styled screen explains that Langlets turns YouTube **or TikTok** videos into transcribed, translated lessons with vocabulary practice. (The title said YouTube only until TikTok support had already shipped; when a provider is added, `onboarding.welcome.title` in every locale is part of the checklist — see `docs/add-new-video-provider.md`.) "Start Now" advances to language selection while preserving the originally requested app URL. The screen is sized to fit a single viewport with no scrolling on every iPhone (fluid `clamp()` title size, `h-dvh-safe` flex column — plain `h-dvh` overflows by the nav-bar inset because `body` already pads `env(safe-area-inset-top)`). Copy is a three-level hierarchy (eyebrow / title / three short body paragraphs, `body_1..body_3` locale keys) — keep it short enough to preserve the no-scroll fit.
3. **Language Selection**: `/onboarding/language` communicates the choice to iOS via `LanguageSelectionBridgeComponent`, then redirects to the preserved URL (normally `/app`) with the selected `lang` query parameter. The heading is **"Choose target language"** (`onboarding.language.title`) — a single string, not the returnto-dependent pair it used to be: the welcome screen always passes a `returnto`, so the "first visit" variant was unreachable and the screen read "Change Learning Language" to users who had never chosen one.

   The list comes from `Language.onboarding_options`, not `Language.all`. The `languages` table holds every language the platform knows about — translation-only ones (English, Hebrew, which are what the subdomain selects) and any still carrying legacy courses — while onboarding offers only the three we have enough content to teach: **French, Spanish, Arabic** (`Language::ONBOARDING_ISO_NAMES = %w[fr es ar-JO]`). Adding a language to the platform therefore does **not** put it on this screen; see `docs/guides/adding-a-new-language.md`. The profile language control is deliberately *not* narrowed — an account already learning something outside the list keeps it and can still see it selected.

   **No tab bar during onboarding.** Both onboarding screens use `layouts/onboarding`, which renders `bridge--tab-visibility` with `visible=false`; iOS `TabVisibilityComponent` posts `.tabVisibilityDidChange` and `SceneDelegate` calls `AppTabBarController#setTabsVisible(false)`. Onboarding is mandatory and every tab behind it just redirects back into it, so tabs there are both meaningless and an escape hatch out of a required flow. This is the mirror image of `bridge--tab-badge`, which the authenticated app layout renders and which reveals the tabs again — **both fire on `connect` only**, so each rendered page asserts its own chrome and leaving onboarding (forward *or* back) restores the tabs without either component having to undo anything. A cold launch already starts with the tabs hidden (`AppTabBarController.init`); the bridge covers the case that motivated it — an in-app screen server-redirecting to `/onboarding/welcome` after the tabs were already revealed. Note this could **not** be done from `NavigatorDelegate#handle(proposal:)`: a proposal carries the pre-redirect URL, which is exactly the case that matters.
4. **Persistence and restoration**: The selected language ISO code is stored in iOS `UserDefaults` under key `selectedLanguage` and per account in the user's JSONB preferences under `ios_lang`. An authenticated native request carrying a valid `lang` updates that preference. Sign-out still clears the device copy to prevent cross-account leakage; after the next login Rails adds the signed-in account's value as `ios_lang` (and `lang`) to the redirect, and iOS restores both standard and App Group defaults. Only accounts without a saved value see onboarding. Until a language is selected, the native navigator also checkpoints the current welcome or language-selection URL (including `returnto`) under `pendingOnboardingURL`. The checkpoint preserves the URL's percent-encoded query rather than encoding it again, and restoration rebuilds `returnto` from its decoded query value. A cold launch resumes that page instead of rebuilding the flow from `/app`; selecting a language or signing out clears the checkpoint.
5. **URL Param Propagation**: The iOS app appends `?lang=<code>` to the root/start URL. Rails propagates this param through `default_url_options` so all generated links include it.
6. **Content Filtering**: `CoursesController#index` and `PlaylistsController` filter their listings by `Language.find_by(iso_name: params[:lang])` when the param is present.
6. **Tabbed Home Browsing**: The root page (`CoursesController#index`) renders a reusable tabs partial (`app/views/shared/_tabs.html.erb`) backed by `tabs_controller.js`, with a default **Courses** tab (playlist grid) and a secondary **Standalone clips** tab (standalone course grid).

#### Changing Learning Language
- Users can change their learning language at any time from the user dropdown menu (avatar icon) on any authenticated page.
- The dropdown shows the currently selected language and links to `/onboarding/language?returnto=<current_url>`.
- The language page has one heading, "Choose target language", for every entry point. It used to branch on `returnto` and show "Change Learning Language"; since the welcome screen also passes a `returnto`, that branch was what first-time users actually saw. First-time product copy is kept on the preceding welcome screen.
- When a language is selected, the bridge message includes a `redirectUrl` so the app navigates back to the originating page with the updated `?lang=` parameter instead of jumping to the root URL.
- The native profile presents the current learning language in a compact select. Changing it sends the selected option's ISO code and redirect URL through the same bridge, keeping iOS `UserDefaults` and the Rails `?lang=` session in sync. Although the profile uses the regular web layout, its content clears the horizontal safe-area insets and reserves the native tab-bar height plus the bottom inset; the shared body already clears the top inset.

#### OAuth Authentication in Native App

OAuth cannot run inside a native shell's web view. The providers refuse to serve
consent screens to embedded browsers, and lifting the flow out of the web view
splits it across two cookie jars. Every difference between the two platforms
below follows from how far each one can close that split.

**Shared shape.** Both shells intercept the sign-in buttons in
`devise/shared/_social_buttons` with a bridge component, run the flow outside the
web view, and are told the outcome by a `langlets://auth-success` or
`langlets://auth-failure` redirect. Both mark the flow with `?native_app=1` on
the initial OAuth URL, which OmniAuth keeps in `request.env["omniauth.params"]`
through the callback — the browser sends its own user agent, so the
`LangletsNative` marker is not available there.
`Users::OmniauthCallbacksController#native_app?` reads the user agent, that
parameter, and (Android only) the handoff cookie described below.

**iOS** uses `ASWebAuthenticationSession`, which shares a cookie jar with
`WKWebsiteDataStore.default()`. The session the browser establishes is therefore
already the web view's session, and `auth-success` only has to trigger a reload.
Apple sign-in goes further and never reaches a browser at all: `apple-auth`
drives the native AuthenticationServices sheet and posts the resulting identity
token to `/users/auth/native_apple`, which verifies it against Apple's JWKS.

**Android has no shared jar.** A Custom Tab's cookies belong to Chrome. So:

- **Google** avoids the browser entirely — `google-auth` obtains an ID token from
  Credential Manager and posts it to `/users/auth/native_google`, verified
  against Google's JWKS. This is the only provider that must work this way:
  Google refuses any app-launched browser.
- **GitHub and Apple** go through the browser, and are the reason
  `NativeAuthHandoff` exists. The `web-auth` bridge component (Android's stand-in
  for `auth-bridge` and `apple-auth`, all three living on the same buttons with
  only the registered one enabled) opens a Custom Tab at
  `/users/auth/native_handoff_start`. Running the *whole* flow there — request
  phase and callback in one jar — is what makes OmniAuth's `state` and
  omniauth-apple's nonce verifiable again; the previous behaviour started the
  request phase in the web view and left the callback with nothing to check
  against, which is why both providers were broken on Android.

**The handoff.** `native_handoff_start` records the app's PKCE-style challenge in
an encrypted `native_auth_handoff` cookie and redirects into the omniauth request
phase. That cookie is `SameSite=None; Secure` for the same reason
omniauth-apple's own nonce cookie is: Apple answers with a cross-site form POST,
which no `Lax` cookie accompanies, so at that callback both the session and
`omniauth.params` are gone and this cookie is the only surviving evidence that
the flow is native. After sign-in, `native_success` mints a `NativeAuthHandoff`
and redirects to `langlets://auth-success?handoff=<token>`. The app spends it at
`/users/auth/native_handoff` from a throwaway `WebView`, whose `Set-Cookie`
lands in the process-global `CookieManager` shared by every tab web view, and
only then resets the tabs.

The token is a live session for someone's account travelling over a custom
scheme any installed app may also claim, so it is 256 random bits, lives for
`NativeAuthHandoff::TTL` (2 minutes), is stored only as a SHA-256 digest, can be
redeemed exactly once (enforced by the row delete, not a flag), and requires the
verifier whose digest was registered as the challenge — RFC 7636's S256
exchange, so an intercepted redirect yields a value the interceptor cannot spend.
`HANDOFF_PROVIDERS` allowlists what `native_handoff_start` will redirect to,
since it is an unauthenticated endpoint that redirects on a supplied parameter.

#### Key Files
- `langlets-ios/langlets/langlets/AppTabBarController.swift` — Native tabs, per-tab navigators, lazy loading and tab state retention
- `langlets-ios/langlets/langlets/SceneDelegate.swift` — App entry point, bridge registration, and URL routing
- `langlets-ios/langlets/langlets/LessonViewController.swift` — Native lesson-sheet close control
- `langlets-ios/langlets/langlets/Bridge/TabBadgeComponent.swift` — the signal that reveals the tab bar (no tab is badged any more; its `count` is vestigial)
- `langlets-ios/langlets/langlets/Bridge/TabVisibilityComponent.swift` — Lets a layout hide the native tab bar (onboarding); paired with `app/javascript/controllers/bridge/tab_visibility_controller.js`
- `langlets-ios/langlets/langlets/Auth/AuthBridgeComponent.swift` — Intercepts OAuth sign-in taps and triggers native auth flow
- `langlets-ios/langlets/langlets/Auth/AuthService.swift` — Manages `ASWebAuthenticationSession` for OAuth
- `langlets-ios/langlets/LangletsShare/ShareViewController.swift` — Share sheet URL extraction, language confirmation and import API submission
- `langlets-ios/langlets/LangletsShare/ShareStore.swift` — Shared Keychain token and App Group language preferences
- `langlets-ios/langlets/langlets/Bridge/NativeTokenComponent.swift` — Receives the session-bootstrapped import token and language catalog
- `app/controllers/app/native_tokens_controller.rb` — Authenticated, CSRF-protected native token bootstrap
- `app/controllers/users/omniauth_callbacks_controller.rb` — Handles OAuth callbacks and redirects to `langlets://auth-success` for native app; also both ends of the Android handoff
- `app/javascript/controllers/bridge/auth_bridge_controller.js` — Stimulus bridge controller for OAuth sign-in buttons (iOS)
- `app/javascript/controllers/bridge/web_auth_controller.js` — Stimulus bridge controller that hands GitHub/Apple to the Android shell's browser flow
- `app/models/native_auth_handoff.rb` — Single-use, PKCE-bound ticket that moves a browser session into the Android web view
- `langlets-android/app/src/main/java/com/ynonp/langlets/AuthHandoff.kt` — App side of the handoff: verifier generation, storage, and the two URLs
- `langlets-android/app/src/main/java/com/ynonp/langlets/bridge/WebAuthComponent.kt` — Receives the sign-in tap and asks MainActivity for a Custom Tab
- `langlets-android/app/src/main/java/com/ynonp/langlets/bridge/GoogleAuthComponent.kt` — Credential Manager sign-in, the one provider that cannot use a browser

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
├── notification.rb             # One thing the app told one user (see Notifications)
└── create_song_progress.rb     # Workflow tracking

app/services/notifications/     # The notification subsystem
├── deliver.rb                  # Record first, deliver second
└── content.rb                  # Every word the app says, one branch per kind
app/services/notifications.rb   # Notifications.deliver — the only entry point
app/services/push/notifier.rb   # One Notification → every registered device

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

#### ReviewLessonBuild
- A lightweight, durable request record with a random `request_id`, user,
  optional learning language, `pending`/`ready`/`failed` status, and the
  resulting Lesson.
- Build state lives here rather than on Lesson: a Lesson is created only after
  the background job has assembled the complete practice transactionally.
- The request ID correlates one browser tab with one job and prevents
  simultaneous reviews or languages from receiving each other's completion
  signal.

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
- Review creation is asynchronous. `POST /review_lessons` synchronously creates
  only a `ReviewLessonBuild`, enqueues `BuildReviewLessonJob`, and redirects to
  its animated waiting page. No vocabulary graph is loaded and no Lesson is
  inserted in the request.
- The waiting page subscribes to the build's signed Turbo Stream over Action
  Cable. The job creates the Lesson and all activities in one transaction,
  marks the build ready, then broadcasts a request-scoped Turbo visit to the
  lesson. The build show action also redirects when it observes ready state, so
  a job that finishes before the browser subscribes cannot strand the user.
  A low-frequency ten-second page refresh is the fallback for a socket outage;
  Action Cable remains the normal instant path. Failures persist on the build,
  broadcast a visit back to the build page, and offer a retry without losing
  saved vocabulary. On the native iOS app the whole sequence — waiting screen,
  activities, finish page — presents as one modal sheet with the tab bar
  hidden; see the mobile app section's path configuration notes.
- Activity composition:
  - FlashcardActivity (if ≥3 saved tokens, up to 15)
  - MatchTokensActivity (if ≥3 saved tokens, up to 15)
  - TokensChainActivity (if ≥4 saved tokens, up to 15)
  - WriteMissingWordActivity (always, up to 10)
- TokensChainActivity uses a frameless exercise layout with an inline matched-word count and progress bar. Each correct translation becomes the next highlighted L1 prompt, while previously found translations are visually muted. Course-built chains contain 4–15 unique word pairs from one content-word category (`noun`, `verb`, `adjective`, or `adverb`); proper nouns and function words are excluded. If no category supplies at least four pairs, the builder omits the activity.
- MatchTokensActivity uses the same frameless header (inline `0 / X matched` counter + progress bar + small instruction line) and a 2-column grid. Pairs are built as one list, shuffled, and sliced into pages whose size is `ceil(total / ceil(total / max_tokens_in_page))` so the pairs spread as evenly as possible across pages while keeping every page at or below `max_tokens_in_page` (4) pairs. With 5 pairs and `max=4` this gives 3+2 instead of 4+1. Each page's pairs are then split into an L1 list and an L2 list and shuffled independently; the L1 list is rendered in the left column and the L2 list in the right column, so the L1 and L2 cells of the same pair are guaranteed not to be in the same row (cells still match each other via the shared `data-token-id`). Both columns share the same center-aligned cell styling (matching `justify-center text-center` on the box, `text-center` on the word span) so a row reads as a balanced pair regardless of which language is LTR or RTL. Tapping an L1 cell always plays the L1 audio for that pair (first tap, second tap, or switch); tapping an L2 cell is silent. Correct pairs flash green, then stay in place dimmed (lower opacity + grayscale + emerald ✓) instead of being hidden or replaced, mirroring the AudioToTranslation pattern. The next page is revealed only once every pair on the current page is matched.
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
- `POST /review_lessons` — create and enqueue a review build, then redirect to
  its request-specific waiting page
- `GET /review_lessons/:id` — play a completed review lesson
- `GET /review_lessons/:id/finish` — completion page

#### ReviewLessonBuildsController
- `GET /review_lesson_builds/:request_id` — authorize the request by its owner,
  render waiting/failed state, or redirect to the completed Lesson

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

The native app avatar is a top-right initials dropdown linking to Notifications, Profile, Invitations and Logout, plus one language-specific "Practice Words" action for each language in which the user has saved vocabulary. It is part of the one shared header, so it appears on all three tab roots:
- `app/views/app/shared/_header.html.erb` — the header: `title:` or the wordmark on the left, the avatar and its menu on the right. No credits pill (see the Create tab below for where the balance lives)
- `app/views/app/home/index.html.erb` — renders it with no `title:`, so Home gets the wordmark
- `app/views/app/library/show.html.erb` and `app/views/app/import_requests/new.html.erb` — pass `title:`, so the header draws each screen's own name where Home draws the brand. Library keeps its description in a wrapper with the header so it holds its 4px gap under the title rather than the column's 16px

Daily vocabulary invitations use `User#daily_vocab_review_available?`. The user
must have a saved span whose phrase is in the current learning language, and
must not have a `LessonUser` completion for a review lesson pinned to that
language during `Time.zone.now.all_day`. Merely generating or starting a review
does not dismiss the invitation. The final activity emits the shared
`activity:completed` browser event; `progress-tracker` submits the review
lesson id and the server creates the `LessonUser` that dismisses the invitation.
Activity controllers must use that shared event name rather than Stimulus's
controller-prefixed `this.dispatch("completed")` event. `App::BaseController`
resolves the invitation once for every native app request, and the shared card appears at the top of all
three tab roots: Home, Library, and Create. The web homepage and gallery put a highlighted
"Daily Vocab Practice" action first in their navigation and now both render the
shared authenticated user menu. Web prefers the `?lang=` learning language; on
an unfiltered URL it uses the first saved-vocabulary language that is still due
today, so the action does not disappear merely because the catalog is showing
all languages.

On mobile, the courses index and playlist headers keep the profile avatar visible by moving the theme toggle and XP chip into the profile dropdown while keeping desktop header controls unchanged:
- `courses/index.html.erb`
- `playlists/show.html.erb`
