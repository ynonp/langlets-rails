# Langlets — Multiple L2 Translations per Phrase

Restructure the schema so one medium (video) transcribed once in its clip language (L1) can carry translations into **many** target languages (L2), instead of duplicating the medium/phrase/course stack per language pair. This is the foundation for localized sites (`he.langlets.app`, `fr.langlets.app`, …) where all content is translated into — and all UI chrome is written in — the site's language.

## Why

- The current scheme stores the translation language on `media` (`unique [url, language_id, translation_language_id]`), which forces saving the same video multiple times, each with its own transcription run and possibly *different* L1 text. The video's source text does not depend on the translation language — the schema shouldn't either.
- Product goal: localized subdomains. First one: **he.langlets.app** (most production content is translated to English; a few videos to Hebrew).

## Constraints & context (agreed)

- **No production data blocks us**: there is currently no medium translated into multiple languages, and it's acceptable to delete/reset user vocabulary and progress. Getting the schema right matters more than preserving data.
- **Pipeline cost stays 1 credit** per import, including translation-only imports of an existing video.
- Site UI localization (Rails i18n for instruction texts/labels) is a **separate workstream** — the app currently has zero `I18n` usage. This spec covers the data model only.

## Decisions

1. **`phrase_translations` table** (not a jsonb dict on `phrases`). Token L2 indexes must point into an exact translation string; a normalized table gives an FK, a language id to join on, and per-language validation. jsonb would let indexes silently drift from the text they index into.
2. **Split token model (Option B)**: language-neutral *span* + per-language *translation*. Activities and saved vocabulary reference the span, so they stay language-neutral; the translation is resolved at render time.
3. **`Current.translation_language`** request context: resolved from subdomain — English on the main domain, Hebrew on `he.langlets.app`.
4. **Multi-language courses**: one course per `(video, L1)`; per-language state lives in `course_translations`. A visitor still experiences the course in exactly one language (resolved via `Current.translation_language`), but the skeleton (lessons, activities, exercise sampling, user progress) is shared across languages, Wikipedia-style.
5. **`CreateSongProgress#add_translation(lang)`**: a partial pipeline that runs only the per-language steps for a new target language. The main pipeline should be refactored to call it, so full import = neutral steps + `add_translation(primary_lang)`.
6. **Vocabulary is language-pinned**: `phrase_token_users` records the translation language that was active when the user saved the word, and that language is what displays everywhere — a word saved as כחול on `he.langlets.app` shows as כחול even on `fr.langlets.app`. This is also the only *total* resolution: translations are sparse (a medium may exist in only one L2), and the save-time translation is the one guaranteed to exist.
7. **Sessions are shared across subdomains**: the session cookie is scoped to the parent domain (`.langlets.app`), so logging in on any subdomain logs the user in on all of them.

## Target schema

```
phrases              medium_id, l1_id, text_l1, timestamp
                     (drop l2_id, text_l2, presence validation on text_l2)

phrase_translations  phrase_id, language_id, text
                     unique(phrase_id, language_id)

phrase_tokens        phrase_id, l1_start_index, l1_end_index, index_type,
                     start_timestamp, end_timestamp,       -- karaoke
                     l1_audio (ActiveStorage), similar_sound[], questions[]
                     unique(phrase_id, l1_start_index, l1_end_index, index_type)
                     -- everything L1-side lives here: audio, timestamps,
                     -- similar_sound, and questions (they're written in L1)

token_translations   phrase_token_id, language_id, translation,
                     l2_start_index, l2_end_index          -- indexes into
                     unique(phrase_token_id, language_id)  -- phrase_translations.text

media                url, language_id                      -- drop translation_language_id
                     unique(url, language_id)

courses              youtube_video_id, language_id, ...    -- drop translation_language_id
                     idx published unique(youtube_video_id, language_id) where status=1

course_translations  course_id, language_id, status, name
                     -- per-language publish/readiness state; a course can be
                     -- live in English while Hebrew is mid-pipeline

lesson_translations  lesson_id, language_id, name
                     -- lesson names are generated in the translation language
                     -- (jsonb name_i18n on lessons is acceptable here — nothing
                     -- indexes into it — pick whichever is simpler)
```

Join tables repointed at the span (language-neutral):

- `activity_token_translations` → **`activity_phrase_tokens`** (`activity_id`, `phrase_token_id`)
- `token_translation_users` → **`phrase_token_users`** (`user_id`, `phrase_token_id`, `language_id`, unique on `(user_id, phrase_token_id)`) — a user saves a *span in a language*: `language_id` is `Current.translation_language` at save time, and the saved word always renders in that language, on every subdomain (decision #6). Re-saving the same span from another subdomain updates `language_id` on the existing row (one entry per span per user). Consequences: a review lesson **can** mix translation languages if the user saved words on different subdomains — accepted; XP counts (`Activity#xp_value` counts token rows ×2) stay correct. Do **not** resolve vocabulary through the `Current`-scoped `localized_translation` association — on a subdomain whose language lacks the translation it would return nil (blank flashcards, broken pairs); resolve from the row's own `language_id` instead.

Note: the old `idx_token_translations_unique` on `[phrase_id, l1_start_index, l1_end_index, index_type]` would collide the moment a second language adds a token for the same L1 span — the split resolves this by design (span is unique once; translations unique per language).

## Request context & access pattern

```ruby
class Phrase < ApplicationRecord
  has_many :phrase_translations
  has_one  :localized_translation,
           -> { where(language_id: Current.translation_language_id) },
           class_name: "PhraseTranslation"

  def text_l2 = localized_translation&.text   # keeps ~40 call sites working
end
```

Same pattern on `PhraseToken` for its `token_translations`. Scoped associations evaluate `Current` at query time, so `includes(:localized_translation)` works normally.

- Note the existing `current_language_code` / `lang` param is the **learning** language (L1) — Library filters on it. `Current.translation_language` is a new, orthogonal concept sourced from the subdomain.
- **Shared sessions**: configure the session cookie for the parent domain — Rails session store `domain: :all` (or explicit `domain: ".langlets.app"`) with the correct `tld_length` — so one login covers `langlets.app`, `he.langlets.app`, `fr.langlets.app`, …. The subdomain changes `Current.translation_language`, never the authenticated user. Existing cookies scoped to the bare host are invalidated by the domain change; users log in once again after deploy — acceptable.

## Query performance (analyzed against existing activity queries)

**Verdict: +1 indexed preload per collection; no meaningful cost. The entire risk is N+1 discipline.**

- Token-based activities (MatchTokens, Flashcard, TokensChain, WriteMissingWord) currently run `token_translations.includes(phrase: [:l1, :l2], l1_audio_attachment: :blob)` (~6 queries). After the split: spans + one preload `token_translations WHERE phrase_token_id IN (...) AND language_id = ?`, served exactly by the new unique index. The `:l2` preload disappears (language comes from `Current`), so it's roughly a wash.
- Phrase-based activities (WatchVideo, Listen, Speak, AudioToTranslation, MatchPhrases, WordOrder, SortPhrases, FindAnswer, LanguageAlignment) read `text_l2` as a column today (0 queries). After: one preload against `unique(phrase_id, language_id)` over 5–20 rows. Sub-millisecond.
- Row counts stay trivial: `phrase_translations` = phrases × languages; `token_translations` = spans × languages.

### Known N+1 hot spots (must preload `localized_translation`)

1. **`MatchPhrasesActivity` distractors** — walks the *whole medium* (`all_l2_phrases: lesson.medium.phrases.to_a`, mapped through `phrase_text_l2` in the view). 50–100 phrases → 100 queries if forgotten. Worst offender.
2. **Full player** (`full_player/show.html.erb`) — renders `phrase.text_l2` and `wrap_tokens_in_spans` (reads `token.translation`) for every phrase in the medium.
3. **Write-path validations** — `TokenTranslation` l2-index validations and `word_to_char_l2` read the phrase translation per token; a 2,000-token song must not lazy-load 2,000 rows at import time. Pass the translation text down explicitly in the pipeline.

Mitigation: the `Current`-scoped `localized_translation` association everywhere + `strict_loading` on `phrase_translations` / `token_translations` in development so a forgotten preload raises instead of silently N+1-ing.

### Queries that change shape (build-time, harmless)

- `BuildSong#distinct_phrases_by_text_l2` (`select("distinct on (text_l2) *")`) → `joins(:phrase_translations).where(phrase_translations: { language_id: }).select("DISTINCT ON (phrase_translations.text) phrases.*")`.
- `FindAnswerActivity` questions move to the span table (questions are L1-side) — that query loses its language dependency entirely.

## Multi-language courses — rationale (decision #4)

With Option B, everything *below* the course is already language-neutral. Per-pair courses would have forced, for each new language, a **full course rebuild**: the builder samples randomly (`phrases.sample(4)`, `token_translations.sample(15)`, random activity pool picks), so sibling courses get different exercises; user progress/enrollment/XP would reset across subdomains; and `add_translation(lang)` couldn't be "just translate".

With multi-language courses:

- `add_translation(lang)` is pure data: insert `phrase_translations` + `token_translations` (+ `lesson_translations`, `course_translations`) rows. Zero course surgery, no re-sampling.
- Exercises are identical across languages; progress and streaks carry across subdomains.
- **"Languages" link** (Wikipedia-style, inside a course): list the course's `course_translations` — same course, same slug, other subdomain. Clean hreflang cluster for SEO.
- Library per subdomain: `joins(:course_translations).where(course_translations: { language_id: current, status: :ready })`.

Costs accepted: dedupe key changes (see **Import / create-course flow** below for the full mechanism), per-language publish state, and per-language lesson/course names.

## Pipeline changes

`CreateSongProgress` steps split into:

- **Neutral, once per `(video, L1)`**: `extract_lyrics`, word timing, lesson segmentation/rating, similar sounds.
- **Per target language — `add_translation(lang)`**: `translate` (phrase texts), `add_token_translation` (per-word translations), lesson/course name generation. Progress `data` restructured so per-language output is keyed by language instead of written inline (`phrase["text_l2"]`, `word["translation"]`).
- Full import = neutral steps + `add_translation(primary_lang)`. Importing a new language for an existing video = `add_translation(lang)` only — still **1 credit**.
- `create_song_progresses` uniqueness moves from `(youtubeurl, clip_language, translation_language)` to `(youtubeurl, clip_language)`; `import_requests` dedupe adjusts accordingly.

### Import / create-course flow (explicit)

An import request is `(video, L1, L2)` where L2 = `Current.translation_language` of the requesting subdomain. `Imports::Create` resolves it in order; the invariant throughout is **match on `(video, L1)` first, then check the L2 translation separately**:

1. **Published course, translation ready** — `published_course_for` finds a course for `(video, L1)` whose `course_translations` has a `ready` row for L2 → redirect to the course. No pipeline runs, no credit spent.
2. **Published course, translation missing or not ready** — the course skeleton exists but L2 doesn't: look up the existing `CreateSongProgress` for `(youtubeurl, clip_language)` (guaranteed present by the new uniqueness key) and enqueue `add_translation(L2)` on it — 1 credit. Neutral steps never re-run. On completion the course's `course_translations` row for L2 flips to `ready`; lessons, activities, and everyone's progress are untouched.
3. **In-flight pipeline** — `in_flight_course_for` finds a running progress for `(video, L1)`: `join!` the requester to it. Whether the run already covers L2 is a direct check on the progress `data` (per-language output is keyed by language). If L2 is covered, joining is all that's needed; if not, queue `add_translation(L2)` to run once the neutral steps complete.
4. **Nothing exists** — full pipeline: neutral steps + `add_translation(L2)`; the new course gets a single `course_translations` row for L2.

Creating a course therefore always starts by locating the existing `CreateSongProgress` for `(video, L1)` and inspecting **which translations it already carries**, and only then chooses between redirect, translate-only, join, and full import.
- Re-import must **stop destroying shared data**: today `medium.phrases.destroy_all` runs on every build (`BuildSong#call`, `Course#create_short!`/`create_song!`) — under shared media that would wipe every language's tokens and users' saved vocabulary. Rebuilds must be scoped to what's being rebuilt.

## Consumers to update (inventory from exploration)

- **Activity models** — every one derives the L2 label from data (`phrases.first.l2`, `token.phrase.l2`); all switch to `Current.translation_language`. `LanguageAlignmentActivity` additionally filters tokens by language-scoped preload.
- **Views** — direct `phrase.text_l2` calls: `_watch_video_activity`, `_listen_activity`, `_speak_activity`, `_audio_to_translation` (also matched in JS via `dataset.textL2`), `_match_phrases_activity` (via helper), `full_player/show` (incl. `l2` RTL direction — now from `Current`).
- **Helpers** — `phrase_text_l2`, `wrap_tokens_in_spans`, `prepare_tokens_for_matching` (dedupes on `t.translation`), `prepare_flashcards_for_tokens`.
- **Vocabulary surfaces** — `VocabularyQuery` (`translation`, `context_translation`), API `v1/vocabulary`, MCP `get_vocabulary`: resolve each entry from the row's **saved** `language_id`, never from `Current.translation_language` (decision #6 — the current subdomain's language may not even have a translation for that span). External contract change: each vocabulary entry carries its own language; no language param needed. Preload shape changes too — `token_translations` fetched by `(phrase_token_id, language_id)` *pairs*, not one language for the whole list.
- **`ReviewLessonBuilder`** — builds from saved spans; resolves each span's translation from its `phrase_token_users.language_id`, so a review lesson renders every word exactly as the user saved it and works on any subdomain regardless of translation sparsity. Cannot use the `Current`-scoped `localized_translation` association — preload the exact `(span, saved language)` pairs.
- **Strays** — `Phrase` `text_l2` presence validation (moves to `phrase_translations`), `TokenTranslationBlockParser#process_line` (compares against `text_l2`, legacy parser), `PhraseTokenParserService`, `CreateSong::ProgressReporting` step detection.
- **Unaffected** — `similar_sounds`, `l1_audio`, `questions`, karaoke timestamps: all L1-side, live on the span.

## Migration plan

Since there are no multi-L2 media in production and user data may be reset:

1. Ship the new schema; migrate existing single-pair data mechanically (each `phrases.text_l2` → one `phrase_translations` row; each `token_translations` row → span + one translation row; courses get one `course_translations` row from their current `translation_language_id`; each `token_translation_users` row → `phrase_token_users` with `language_id` backfilled from its medium's `translation_language_id`).
2. No merge problem exists **today** — but had the same video been imported twice for different L2s, the two transcription runs would have differing `text_l1`/segmentation and could not be merged. Doing this now, before that data exists, is the point.
3. Drop `media.translation_language_id`, `phrases.l2_id`/`text_l2`, `courses.translation_language_id` after backfill.

## Out of scope

- Rails i18n for UI chrome / instruction texts (separate workstream, required before a subdomain actually launches).
- Subdomain routing infrastructure beyond resolving `Current.translation_language` and the shared session cookie (see Request context above).
- iOS app changes (consumes the API; revisit vocabulary/courses endpoints when the API contract gains the language param).
