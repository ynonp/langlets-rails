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

- `pipeline/src/prompts/addTokenTranslations.ts` selects **source-language** examples for English targets. Chinese targets have an English → Chinese example; other targets omit examples. Always match the example output to the requested translation language.
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
| `zh` | Chinese | 中文 | No | `zh-CN` | `zh` | `zho`, `chi` |

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Language is absent from a picker | Migration or seeds have not created the record |
| Supadata selects an unrelated caption track | Missing `LANGUAGE_TO_ISO` entry |
| TikTok reports a supported detected language as unsupported | Missing Scribe ISO-639-3 normalization |
| TTS uses an English voice | Missing Azure voice or locale mapping |
| Sentence prompt demonstrates English for a non-English target | Missing target-language fallback in `translate.ts` |
| Similar-sound activity has no substitutions | No frequency dictionary is configured for the source language |

Chinese defaults to Mandarin speech using `zh-CN-XiaoxiaoNeural`, verified against
[Microsoft's voice catalog](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/language-support).
Chinese examples use Simplified characters, while source-processing prompts preserve
both Simplified and Traditional input. The timed transcription example demonstrates
multi-character words; compound extraction can merge existing timed tokens but
cannot split them. Chinese similar-sound activities use a bundled frequency and
pinyin dictionary with pronunciation matching and support for short words; see
[Chinese dictionary sources and rebuilding](../../pipeline/data/CHINESE.md).
The matching step preserves existing word boundaries and skips words with no
usable reading or audible alternative.

## Adding an interface/native language

Learning languages and interface languages are separate lists. Spanish already
has a language record, speech support and pipeline mappings; enabling it as a
native language needs no database migration.

English (`en`), Hebrew (`he`) and Spanish (`es`) are supported native languages
in `User::NATIVE_LANGUAGE_CODES`. Web requests select the language from the
host (`langlets.app`, `he.langlets.app`, `es.langlets.app`). Signed-in native
requests use the account's `preferences["native_language"]` on every host.
The native profile picker saves this preference. Password signup stores the
request language before sending confirmation; web OAuth preserves the original
language host and stores its language after the canonical callback.

When adding another interface language:

1. Add it to `User::NATIVE_LANGUAGE_CODES` and `config.i18n.available_locales`.
   Prospect locale validation shares the native-language list.
2. Translate all application, Devise, Doorkeeper and marketing keys, including
   plural forms and interpolation names. Supply Rails date, time, validation
   and number translations. `test/integration/spanish_locale_test.rb` checks
   Spanish coverage directly from YAML, so English fallbacks cannot hide gaps.
3. Translate any localized full-page templates, including privacy and terms.
   Spanish uses `privacy.es.html.erb` and `terms.es.html.erb`; keep their content
   synchronized when the source documents change. Operations/admin pages remain
   the intentionally English operations area.
4. Add the host to Kamal's `proxy.hosts`, `SeoHelper::CANONICAL_HOSTS`, the
   OmniAuth canonical-callback allowlist and `WEB_LANGUAGE_BY_HOST`. Add a DNS
   A record pointing to the production server **before deploying**; otherwise
   automatic TLS provisioning can fail. Do not add OAuth provider callbacks for
   each language: callbacks remain on canonical `langlets.app`.
5. Add native string resources: Android `values-<locale>/strings.xml`, iOS
   `<locale>.lproj/Localizable.strings` (main app and share extension), and
   translated iOS privacy permission descriptions. Add the locale to Xcode's
   `knownRegions`. The optional tab-badge payload contains localized tab titles
   and the account locale; old clients ignore these fields and new clients
   tolerate old pages without them. Both the app layout and native profile emit
   it. iOS remembers the locale in its app group for share-extension messages.
6. Check all four native tab paths and both bundled path configurations. This
   language addition changes labels only; paths and bundle IDs stay the same.
7. Run locale/profile/OAuth/email tests, then build both native targets using
   the [mobile build guide](mobile-builds.md).

Notification email and push use the recipient's native language. Devise account
email does too. In production, mail links use the matching language host;
marketing invitation mail uses the prospect's locale.
