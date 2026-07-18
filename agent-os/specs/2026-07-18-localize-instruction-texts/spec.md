# Specification: Localize All Instruction Texts (English + Hebrew)

## Goal
Serve every UI/instruction text in the visitor's translation language based on subdomain — `he.langlets.app` fully in Hebrew, `es.langlets.app` in Spanish, etc. This phase extracts all hardcoded English texts from ERB views and Stimulus JS into standard Rails locale files and ships English + Hebrew; all other subdomains fall back to English until their locale file is added (adding a language later = adding one `config/locales/<code>.yml`).

## User Stories
- As a Hebrew-speaking learner on he.langlets.app, I want all instructions, buttons, and feedback messages in Hebrew so that I can use the app without reading English
- As a learner on a subdomain without translations yet (es, ar, de, fr), I want the app to work exactly as today in English so that nothing breaks before those translations exist
- As the product owner, I want all texts in locale files so that adding a new UI language is a single-file change

## Specific Requirements

**I18n Configuration**
- In `config/application.rb`: `default_locale = :en`, `available_locales = [:en, :he, :es, :ar, :de, :fr]` (matching `Language#iso_name` values), `fallbacks = [:en]`
- Fallbacks make every locale without a YAML file serve English transparently

**Per-request Locale from Subdomain**
- Extend the existing `set_translation_language` before_action in `app/controllers/application_controller.rb` (it already resolves the subdomain into `Current.translation_language`)
- Set `I18n.locale` to `Current.translation_language.iso_name` when it is in `available_locales`, else `:en`

**ERB Text Extraction**
- Replace every hardcoded user-facing literal with lazy-lookup `t(".key")` so `config/locales/en.yml` mirrors the view tree (e.g. `activities.word_order_activity.title`); interpolations use `%{name}`
- View clusters to sweep:
  - `app/views/activities/` (19 partials) — instructions/feedback: "Good Work!", "Tap the translation of the highlighted word", "Type the missing word...", "Accuracy"/"Fluency"/"Completeness"
  - `app/views/courses/` (11 files) — "Continue Learning", "Browse", "Next For You", "Sign in now to not lose your progress"
  - `app/views/app/home/`, `app/views/app/library/`, `app/views/app/import_requests/` — "Pick your first song", "Library", "Add a video", "Import · 1 credit", "Queue", "Nothing here yet."
  - `app/views/onboarding/`, `app/views/settings/`, `app/views/profile/`, `app/views/lessons/`, `app/views/playlists/`
  - `app/views/home/index` landing page and `app/views/layouts/_head.html.erb` `<title>`
- Normalize the existing ad-hoc `subhead_he`/`subhead_es`/… keys in `en.yml` into a nested `subhead.<lang>` structure, keeping current behavior
- Language display names in pickers: prefer `Language#native_name`/`english_name` from the DB where a record is at hand; add locale keys only where views truly hardcode names

**JS String Localization (global blob + helper)**
- Add a `js:` namespace to locale files keyed per controller (e.g. `js.word_order.question_of: "Question %{current} of %{total}"`)
- Emit the subtree once in `app/views/layouts/_head.html.erb` (shared by both layouts): `<script type="application/json" id="i18n-strings"><%= raw I18n.t("js").to_json %></script>`
- New `app/javascript/utils/i18n.js` exporting `t(key, params)`: lazily parses the blob, resolves dotted keys, interpolates `%{name}` placeholders, returns the key itself when missing
- Replace hardcoded strings with `t("...")` in these controllers (`app/javascript/controllers/`):
  - Activity feedback: `word_order_activity_controller.js`, `match_activity_controller.js`, `write_missing_word_activity_controller.js`, `flashcard_activity_controller.js`, `speak_activity_controller.js`, `audio_to_translation_activity_controller.js`, `match_tokens_activity_controller.js`, `tokens_chain_activity_controller.js` (incl. "Question X of Y" and "N / M matched" counters)
  - Vocab/buttons: `popover_translation_controller.js` ("Save"/"Saved"), `stop_practicing_controller.js` + `utils/stop_practicing_html.js`
  - Error alerts: `course_paths_controller.js`, `playlist_courses_controller.js`, `youtube_form_controller.js`
  - Bridge: `bridge/apple_auth_controller.js`, `bridge/google_auth_controller.js`, `bridge/push_controller.js`
  - Progress: `progress_tracker_controller.js` ("%{xp} XP")
- Skip `hello_controller.js` (scaffold) and `console.error` strings (developer-facing)

**Page Language and Direction**
- Both layouts (`app/views/layouts/application.html.erb`, `app/views/layouts/app.html.erb`): set `<html lang="..." dir="...">` from `Current.translation_language` (`iso_name`, `rtl?` — column already exists)
- Existing per-content `dir=` attributes (full_player, courses/show, activity partials) stay as-is — they track the content language, which is correct
- Fix only CSS that visibly breaks under RTL on `he.localhost:3000` (physical left/right Tailwind utilities)

**Hebrew Locale File**
- `config/locales/he.yml`: full Hebrew mirror of `en.yml` (view keys and `js:` subtree), drafted by the agent, reviewed by the product owner

## Verification
1. `bin/dev`; `localhost:3000` reads exactly as before (English, LTR)
2. `he.localhost:3000` (works via existing `tld_length = 0` dev config): landing, course index, onboarding, profile, settings in Hebrew with `dir="rtl"`
3. Open a lesson on `he.localhost:3000` and exercise activities end-to-end: word order wrong/right answers, flashcard counter, popover Save/Saved, stop-practicing undo toast — proves the JS blob + helper path
4. `es.localhost:3000`: English fallback, `dir="ltr"`, no missing-translation errors
5. Grep sweep for leftover literals in swept directories; run the test suite

## Visual Design
No visual assets. Only expected visual change: full page mirroring (RTL) on Hebrew subdomain.

## Existing Code to Leverage

**Subdomain → Language resolution (app/controllers/application_controller.rb)**
- `set_translation_language` before_action already maps first subdomain to `Language.find_by(iso_name:)` into `Current.translation_language`; dev subdomains already work (`config.action_dispatch.tld_length = 0` in `config/environments/development.rb`)

**Current attributes (app/models/current.rb)**
- `Current.translation_language` / `translation_language_id`, exposed to views as `current_translation_language`

**Language model (app/models/language.rb)**
- `iso_name` (unique, the de-facto locale code), `native_name`, `english_name`, and boolean `rtl` — everything needed for locale + direction

**Existing locale scaffold (config/locales/en.yml)**
- Already present with landing subhead keys; becomes the canonical English string catalog

**Server→JS data channel**
- Stimulus `data-*-value` attributes are the established pattern; the i18n blob uses a sibling mechanism (JSON script tag) because strings are needed by ~17 controllers including layout-level bridge controllers

## Out of Scope
- Long-form legal/support prose: `home/privacy`, `home/terms`, `home/support` stay hardcoded English (need careful human translation)
- Devise and Doorkeeper engine translations (`devise.he.yml`, `doorkeeper.he.yml`) — follow-up
- Locale files for Spanish/Arabic/German/French (fallback to English covers them; each is a later single-file addition)
- Translating learning content (courses, lyrics, phrases) — content language is a separate concept (`params[:lang]`/`session[:lang]`) and already handled
- A locale switcher UI (locale is determined solely by subdomain)
- `console.error` / developer-facing strings
