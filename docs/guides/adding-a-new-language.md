# Adding a New Language

This guide covers all the steps needed to add a new language to the Langlets platform. Use Italian as a running example; substitute values for your target language.

---

## Overview

Languages are stored in the `languages` table with these columns:

| Column | Purpose | Example (Italian) |
|---|---|---|
| `iso_name` | Unique ISO code. Used in `?lang=` URL params and Azure TTS lookups. | `it` |
| `english_name` | English display name. Used as a lookup key in the course creation pipeline (AI prompts, `Course#create_song!`, etc.). | `Italian` |
| `native_name` | Native display name. Shown in the onboarding language picker and user menu. | `Italiano` |
| `pronunciation_variant_name` | Locale tag for Azure text-to-speech. | `it-IT` |
| `rtl` | Boolean — `true` for right-to-left scripts (Arabic, Hebrew), `false` otherwise. | `false` |

The language record is referenced in two distinct ways throughout the codebase:

- **By `iso_name`** — URL-based filtering (`params[:lang]`), user saved-words lookup, Azure TTS voice selection.
- **By `english_name`** — the course creation pipeline (`CreateSongProgress`, `Course#create_song!`, AI prompts).

---

## Step-by-Step Checklist

### 1. Data Migration (for production)

Create a migration to insert the language into production. This ensures the record exists before any course referencing it is created.

```bash
bin/rails generate migration AddItalianLanguage
```

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_italian_language.rb
class AddItalianLanguage < ActiveRecord::Migration[7.0]
  def up
    Language.find_or_create_by!(iso_name: "it") do |lang|
      lang.english_name = "Italian"
      lang.native_name  = "Italiano"
      lang.pronunciation_variant_name = "it-IT"
      # lang.rtl defaults to false — only set to true for RTL languages
    end
  end

  def down
    Language.find_by(iso_name: "it")&.destroy
  end
end
```

Run the migration:

```bash
bin/rails db:migrate
```

### 2. Add to Seeds (`db/seeds.rb`)

Add a block so new development environments also get the language:

```ruby
l_it = Language.find_or_create_by!(iso_name: "it") do |lang|
  lang.english_name = "Italian"
  lang.native_name  = "Italiano"
  lang.pronunciation_variant_name = "it-IT"
end
```

Run seeds:

```bash
bin/rails db:seed
```

### 3. Token Translation Examples (AI Prompt Partials)

The prompt in `app/views/prompts/add_token_translations.md.erb` dynamically includes language-pair-specific examples:

```erb
<%= render partial: "prompts/add_tokens_examples_#{clip_language.downcase}_#{translation_language.downcase}" %>
```

This means you need **one partial per language direction**. For Italian ↔ English, create both:

- `app/views/prompts/_add_tokens_examples_italian_english.md.erb`
- `app/views/prompts/_add_tokens_examples_english_italian.md.erb`

#### What goes in these partials

Each partial provides 2–3 example inputs and expected outputs that teach the LLM how to handle the language pair's particular challenges — contracted articles, clitic pronouns, word order, gender, etc. They follow the same format as the existing files:

- `_add_tokens_examples_spanish_english.md.erb`
- `_add_tokens_examples_french_english.md.erb`
- `_add_tokens_examples_arabic_english.md.erb`
- `_add_tokens_examples_hebrew_english.md.erb`
- `_add_tokens_examples_hebrew_arabic.md.erb`
- `_add_tokens_examples_english_hebrew.md.erb`

Study these as templates. The format is:

```
---
## Example input 1:
<source sentence 1> => <target sentence 1>
<source sentence 2> => <target sentence 2>

## Expected output 1:
[word] rest of sentence => [translated word] rest of target
...

## Example input 2:
...
```

#### If a partial is missing

If the rendered partial doesn't exist, Rails will raise an `ActionView::MissingTemplate` error when `add_token_translation` runs during course creation. The course will get stuck in `processing` or `error` status.

### 4. Azure Text-to-Speech (`app/models/concerns/azure_text_to_speech.rb`)

Two `case` statements need entries for the new language's ISO code.

#### `get_voice(language_iso)`

Add a voice mapping. Find the appropriate Azure voice name from [Azure's voice list](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/language-support?tabs=tts):

```ruby
when "it"
  "it-IT-ElsaNeural"
```

#### `get_azure_language_code(language_iso)`

Add the Azure language code:

```ruby
when "it"
  "it-IT"
```

Without these entries, the `SpeakActivity` and any other TTS-dependent feature will fall back to the default US English voice (`"en-US-AriaNeural"`), which will sound wrong for the new language.

### 5. Verify Frontend Visibility

Once the language record exists in the database, it automatically appears in:

- **Create Course form** (`courses/new`) — queries `Language.all.order(:english_name)`
- **User menu / profile language switcher** (native app) — same query
- **Course listing filters** (`courses#index`) — filters by `current_language_code` via `params[:lang]`

**The one place it does not appear automatically is the onboarding language picker** (`/onboarding/language`), which queries `Language.onboarding_options` — a fixed allowlist, `Language::ONBOARDING_ISO_NAMES` in `app/models/language.rb`. That screen is the first thing a new native user sees, so it only lists languages with enough published content to be worth starting; a language with two courses on it is a bad first impression, and translation-only languages (English, Hebrew) do not belong there at all. **Add the new ISO code to `ONBOARDING_ISO_NAMES` once the language has real content** — and update the assertion in `test/controllers/app/screens_test.rb` ("onboarding offers only the languages we teach"), which pins the exact list.

No other view or controller changes are required.

### 6. Transcription Language Code (`pipeline/src/steps/extractLyrics.ts`)

Add the language to `LANGUAGE_TO_ISO`, keyed on the lowercased English name:

```ts
const LANGUAGE_TO_ISO: Record<string, string> = {
  // ...
  italian: "it",
};
```

This is the code `extract_lyrics` asks Supadata for, and the one it validates the returned caption
track against. **It is not read from the database**, deliberately: `Language#iso_name` is a TTS code
(Arabic is `ar-JO`), and Supadata stocks caption tracks by plain language, not regional variant.

Skipping this step does not fail loudly. The step sends no `lang` at all, Supadata answers with
whichever caption track the video happens to carry, and there is no requested code to compare it
against — so a Japanese subtitle track on an Italian song becomes the course's lyrics, and the first
visible symptom is a forced-alignment failure two steps later. The step logs
`ExtractLyrics has no transcription language code for <language>` when this happens; grep for it
after adding a language.

Also add the language to `pipeline/src/prompts/addTokenTranslations.ts`'s `examples` map if you want
a language-matched worked example — unknown languages fall back to the English one.

### 7. Test Fixtures (Optional)

Test fixtures in `test/fixtures/create_song_progress/` reference languages by their `english_name` field. If you add test courses for the new language, ensure the JSON fixture has matching values:

```json
{
  "clip_language": "Italian",
  "translation_language": "English"
}
```

---

## How Languages Are Used at Runtime

Understanding this flow helps when debugging issues after adding a language:

### Course Creation Pipeline

```
User submits a video URL; the pipeline detects `it` and maps it to the seeded
Language (`english_name: "Italian"`, `iso_name: "it"`). The request supplies
only the translation language (`"English"`).
        │
        ▼
CreateSongProgress record stored with english_name strings
        │
        ▼
CreateCourseJob → CourseBuilder::BuildSong
        │
        ├── ExtractLyrics     → prompt gets clip_language as template local
        ├── Translate         → prompt gets clip_language, translation_language
        ├── AddTokenTranslation → prompt dynamically renders language-pair partial
        ├── AddLessons        → prompt gets clip_language, translation_language
        └── AddSimilarSound   → calls fuzzyword with iso_name (strips region suffix)
        │
        ▼
Course.create_song!  → Language.find_by(english_name: ...)
```

### Runtime Language Filtering

```
User selects language (iso_name stored in session[:lang] or params[:lang])
        │
        ▼
ApplicationController#current_language_code returns iso_name
        │
        ▼
CoursesController#index:
  language = Language.find_by(iso_name: current_language_code)
  Course.where(language: language)
```

---

## Quick Reference: Existing Languages

`ISO` is `Language#iso_name`; `Transcription` is the separate `LANGUAGE_TO_ISO` entry the pipeline
asks Supadata for. They differ wherever the TTS voice needs a regional variant.

| ISO | English Name | Native Name | RTL | TTS Variant | Transcription |
|---|---|---|---|---|---|
| `en` | English | English | No | en-US | `en` |
| `es` | Spanish | Español | No | es-ES | `es` |
| `fr` | French | Français | No | fr-FR | `fr` |
| `de` | German | Deutsch | No | de-DE | `de` |
| `he` | Hebrew | עברית | Yes | he-IL | `he` |
| `ar-JO` | Arabic | العربية الفلسطينية | Yes | ar-JO | `ar` |

---

## Troubleshooting

| Symptom | Likely Cause |
|---|---|
| Language doesn't appear in picker | Record not in DB — run migration + seeds |
| Course creation stalls in `processing` | Missing `_add_tokens_examples_*.md.erb` partial for the language pair |
| TTS speaks in English | Missing `get_voice` / `get_azure_language_code` entry in `azure_text_to_speech.rb` |
| `ActionView::MissingTemplate` during course build | Prompt partial name doesn't match — check `clip_language.downcase` + `_` + `translation_language.downcase` |
| Speech recognition / TTS sounds wrong | `pronunciation_variant_name` doesn't match an Azure-supported locale |
