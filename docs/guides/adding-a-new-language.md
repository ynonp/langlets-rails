# Adding a New Language

This guide covers the current steps for adding a source and translation language to Langlets. It uses Italian as an example; substitute the target language's values.

## Language Record

Languages live in `languages`:

| Column | Purpose | Italian example |
|---|---|---|
| `iso_name` | Unique ISO-639-1 code used in URLs, translation keys, and speech lookups. A regional value is retained only where the catalog deliberately requires one (Arabic is `ar-JO`). | `it` |
| `english_name` | Pipeline and application lookup name. | `Italian` |
| `native_name` | Display name shown in language pickers. | `Italiano` |
| `pronunciation_variant_name` | Azure Speech BCP-47 locale. | `it-IT` |
| `rtl` | Right-to-left layout flag. | `false` |

The application uses both `iso_name` and `english_name`, so both must remain stable.

## Checklist

### 1. Add a production data migration

Use SQL rather than the application `Language` model so the migration remains runnable if that model later changes. Make it idempotent and repair an existing partial row with `ON CONFLICT`.

```ruby
class AddItalianLanguage < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      INSERT INTO languages
        (iso_name, english_name, native_name, pronunciation_variant_name, rtl, created_at, updated_at)
      VALUES
        ('it', 'Italian', 'Italiano', 'it-IT', FALSE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ON CONFLICT (iso_name) DO UPDATE SET
        english_name = EXCLUDED.english_name,
        native_name = EXCLUDED.native_name,
        pronunciation_variant_name = EXCLUDED.pronunciation_variant_name,
        rtl = EXCLUDED.rtl,
        updated_at = CURRENT_TIMESTAMP
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "Italian may be referenced by production content and cannot be removed safely"
  end
end
```

Deleting a language after courses, translations, vocabulary, or reviews reference it is unsafe, so language-catalog migrations are intentionally irreversible.

Run `bin/rails db:migrate` and `RAILS_ENV=test bin/rails db:migrate`.

### 2. Add the record to seeds

Add an idempotent block to `db/seeds.rb` so fresh development databases include the language:

```ruby
l_it = Language.find_or_create_by!(iso_name: "it") do |language|
  language.english_name = "Italian"
  language.native_name = "Italiano"
  language.pronunciation_variant_name = "it-IT"
end
```

Set `rtl = true` only for a right-to-left language.

### 3. Add transcription and detection codes

The AI pipeline runs in Deno. The old Rails prompt partials under `app/views/prompts/` are not used by course creation.

Required mappings:

- Add the lowercased English name and ISO-639-1 code to `LANGUAGE_TO_ISO` in `pipeline/src/steps/extractLyrics.ts`. Supadata uses this code to request and validate the native caption track. This mapping is intentionally separate from the database because a database code can include a TTS region, while Supadata expects a base language.
- Add the ISO-639-3 code returned by ElevenLabs Scribe to `SCRIBE_ISO_639_3_TO_1` in `pipeline/src/languageDetection.ts`. Include terminology and bibliographic aliases when both exist (Greek has `ell` and `gre`). Without this mapping, TikTok detection rejects an otherwise supported language.
- Add the English name to `ENGLISH_NAMES` in `pipeline/src/fuzzyword.ts`. Similar-sound generation additionally requires a matching frequency dictionary in `pipeline/data` and `DICTIONARIES`. Without a dictionary, course creation succeeds but no substituted alternatives are produced for that language.

YouTube detection needs no static entry: Rails sends every database language and Gemini must choose one of those ISO codes.

### 4. Review pipeline prompt examples

Examples are not required for the pipeline to run, but an example must never demonstrate the wrong output language:

- `pipeline/src/prompts/addTokenTranslations.ts` selects examples by **translation language**. Unknown targets get no token example. Add a target-language example for better word-level translations.
- `pipeline/src/prompts/translate.ts` uses an exact source/target example when available, then a Spanish-source example in the requested target language, and finally Spanish → English. Add a target-language fallback for every supported translation language.
- `pipeline/src/prompts/addLessons.ts` and `pipeline/src/prompts/extractCompounds.ts` select examples by **source language** and safely fall back to English. Add both the language-code mapping and an example when the language needs script- or grammar-specific guidance.

Add or extend the corresponding Deno tests under `pipeline/tests/` whenever a mapping or example changes.

### 5. Add Azure text-to-speech support

Update both mappings in `app/models/concerns/azure_text_to_speech.rb`:

```ruby
when "it", "it-it"
  "it-IT-ElsaNeural" # get_voice

when "it", "it-it"
  "it-IT" # get_azure_language_code
```

Verify the locale and voice against Microsoft's current Azure Speech language-support table. Without explicit entries, speech falls back to US English.

Add a focused Rails test for both the base ISO code and selected locale/voice.

### 6. Add fixtures and verify automatic UI visibility

Add the language to `test/fixtures/languages.yml`. A database language automatically appears in the admin course form and in database-driven language filters; no locale catalog is required. Interface copy falls back to English when `config/locales/<iso>.yml` does not exist.

If adding pipeline fixture data, `clip_language` must exactly match `Language#english_name`. Translation payloads live under `data.translations`, keyed by `Language#iso_name`; the old top-level `translation_language` fixture field is vestigial.

### 7. Verify

Run at least:

```bash
bin/rails db:version
RAILS_ENV=test bin/rails db:version
bin/rails db:migrate
RAILS_ENV=test bin/rails db:migrate
bin/rails test test/models/language_test.rb
cd pipeline && deno task test
```

Also check that the migrations created the exact records and that pipeline type-checking passes.

## Runtime Flow

1. Detection chooses one of the database languages. YouTube returns the supplied ISO code; TikTok's Scribe ISO-639-3 result is normalized to the database code.
2. Transcript extraction maps the English source-language name to the base code Supadata understands and rejects a returned caption track in a different language.
3. Translation output is stored under `data["translations"][language.iso_name]`.
4. `CourseBuilder::BuildSong` resolves the source by `english_name` and materializes the selected translation language.
5. Phrase and token audio use the source language's Azure locale and voice.

## Current Languages

| ISO | English | Native | RTL | Azure locale | Transcription | Scribe detection |
|---|---|---|---|---|---|---|
| `en` | English | English | No | `en-US` | `en` | `eng` |
| `es` | Spanish | Español | No | `es-ES` | `es` | `spa` |
| `fr` | French | Français | No | `fr-FR` | `fr` | `fra`, `fre` |
| `de` | German | Deutsch | No | `de-DE` | `de` | `deu` |
| `he` | Hebrew | עברית | Yes | `he-IL` | `he` | `heb` |
| `ar-JO` | Arabic | العربية الفلسطينية | Yes | `ar-JO` | `ar` | `ara` |
| `el` | Greek | Ελληνικά | No | `el-GR` | `el` | `ell`, `gre` |
| `sv` | Swedish | Svenska | No | `sv-SE` | `sv` | `swe` |

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Language is absent from a picker | Migration or seeds have not created the record |
| Supadata selects an unrelated caption track | Missing `LANGUAGE_TO_ISO` entry |
| TikTok reports a supported detected language as unsupported | Missing Scribe ISO-639-3 normalization |
| TTS uses an English voice | Missing Azure voice or locale mapping |
| Sentence prompt demonstrates English for a non-English target | Missing target-language fallback in `translate.ts` |
| Similar-sound activity has no substitutions | No frequency dictionary is configured for the source language |
