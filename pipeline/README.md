# Create Song Pipeline (Deno)

The Create Song AI pipeline: a standalone Deno + TypeScript service built on the
[Vercel AI SDK](https://ai-sdk.dev). Originally extracted from the Rails concerns that lived in
`app/models/concerns/create_song/*`, it is now the only implementation — those concerns have been
deleted. It runs on an external server while **all data stays in the Rails postgres**: every
mutation is streamed back to a callback URL the trigger request provides.

## The workflow and how it parallelizes

Semantic segmentation is the final required transcription stage; downstream work fans out after it:

```
extract_lyrics                              (Supadata native + downloaded-audio ElevenLabs)
                                            (Sol reconciliation; YouTube Gemini fallback)
     │
force_alignment                             (ElevenLabs alignment, Gemini timestamp fallback)
                                            (reuses timings for ElevenLabs-only transcripts)
     │
add_lessons                                 (semantic lines + lesson hierarchy)
     │
     ├── add_token_translations             (4 chunks in flight)
     ├── rate_lessons                       (lesson quality)
     └── translate                          (sentence translation lines)
     │                                      (all three run concurrently)
materialize translations                    (join with semantic phrases)
     │
     └── add_similar_sound                  (dictionary lookup, no LLM)
     │
finalize_translation                        (payload metadata + lessons snapshot)
```

`extract_lyrics` runs two independent paths concurrently for both providers: Supadata with
`mode=native`, and a verified `yt-dlp` audio download uploaded to ElevenLabs Scribe (`scribe_v2`).
Each success is checkpointed under `data.stt_candidates`, so interrupted runs do not repay a
provider that already finished. When both succeed, GPT-5.6 Sol reconciles their complete texts at
temperature 0. When only one succeeds it is used directly and Sol is skipped. If both fail, YouTube
uses the existing Gemini 2.5 Flash video transcription fallback; TikTok fails because no third
transcription route exists. A Sol failure falls back to the valid ElevenLabs result.

Scribe's `spacing` and `audio_event` entries (`[cantando]`, `[Applause]`) are dropped, and its text
is rebuilt from surviving timed words. An ElevenLabs-only result can therefore reuse those timings
in `force_alignment`. Reconciled and Supadata-only text is aligned against the audio by the existing
ElevenLabs forced-alignment stage. Supadata's `lang` remains a preference rather than a filter, so a
returned language mismatch makes that candidate fail without affecting ElevenLabs. All transcript
sources share cleanup that removes `[Music]`-, `(footsteps)`-, and `♪` annotations. ElevenLabs'
tokenization is reconciled back onto the transcript's own whitespace tokens — those, not the
provider's, are what `add_lessons` indexes and `add_token_translations` turns into clickable words —
so only the timings come from ElevenLabs. If audio download, ElevenLabs, or reconciliation fails,
Gemini 2.5 Flash receives the video plus the original transcript words and returns every word in
order with optional structured start/end timestamps. The first and last word of every source line
require timestamps so phrase timing survives; untimed middle words remain untimed. The pipeline
preserves the original text and keeps every word token for downstream translation.

Lesson generation receives the continuous aligned transcript and returns lesson titles and semantic
line breaks. The pipeline uses the returned word counts only as boundaries, derives internal word
ranges, and reconstructs exact text and phrase timestamps from aligned words or Gemini-timestamped
source-line bounds. This makes each line a semantic comprehension/translation unit without allowing
the model to modify the transcript. It atomically persists `lyric_lines`, `phrases`,
`lesson_outline`, and timestamped `lessons`. The prompt uses a ten-line, two-lesson worked example
in the clip language for the seven configured languages, falling back to English for unknown
languages.

Sentence translation follows the same pattern: it reads `lyric_lines` and persists
`translation_lines.<iso>`, then copies those lines into the stable
`translations.<iso>.phrases.<i>.text` payload slots.

Token translation begins after semantic segmentation, alongside lesson rating and sentence
translation.

The fan-out is safe because the branches write **disjoint keys** of `CreateSongProgress.data`:

- semantic segmentation writes `lyric_lines`, `phrases`, `lesson_outline`, and `lessons` before the
  fan-out; lesson rating then writes `lesson_ratings`;
- early sentence translation writes `translation_lines.<iso>`, then the join writes
  `translations.<iso>.phrases.<i>.text`;
- `add_token_translations` writes `translations.<iso>.phrases.<i>.words`.

This required one deliberate change from the Ruby flow: translation steps use language-keyed
intermediates and the version-2 language payload (`data.translations[iso]`) instead of writing
inline `text_l2` / word `translation` keys and packing them later (`DataFormat.pack_translation`).
The final blob shape is identical to what Rails produces — `data.phrases` stays language-neutral and
guards like `translation_complete?` keep working.

`add_similar_sound` is extracted too. The Ruby step shelled out to the `fuzzyword` Rust CLI (a
SymSpell wrapper); `src/fuzzyword.ts` ports it — OSA edit distance ≤ 2 over the per-language
frequency dictionaries in `data/`, results ordered by distance then frequency, top 3 excluding the
word itself — and the port produces byte-identical output to the binary for the checked languages.
The clip language is mapped to a dictionary by its English name (en/fr/de/he/ru/es/ar); pass
`clip_language_iso` in the trigger for anything the map doesn't cover. No dictionary means lines
pass through unchanged, same as the Ruby fallback.

After required semantic segmentation succeeds, branches settle independently (`Promise.allSettled`):
one branch failing never discards another branch's completed — and already persisted — work.
`finalize_translation` runs only when both translation branches succeeded.

### Providers and models

| Step                       | Model                                           | Provider                                               |
| -------------------------- | ----------------------------------------------- | ------------------------------------------------------ |
| extract_lyrics             | Dual STT + reconciliation / YouTube fallback    | Supadata + ElevenLabs + GPT-5.6 Sol / Gemini 2.5 Flash |
| force_alignment            | Forced Alignment API / structured line fallback | ElevenLabs / Gemini 2.5 Flash                          |
| add_lessons / rate_lessons | `gemini-3.5-flash-lite`                         | Google Generative AI                                   |
| translate                  | `deepseek-v4-pro:cloud`                         | Ollama cloud via `@ai-sdk/openai-compatible`           |
| add_token_translations     | `gemini-2.5-flash`                              | Google Generative AI, four concurrent 200-line chunks  |

`add_token_translations` is deliberately not on flash-lite: on a long chunk of a language it reads
poorly it echoes each source word back with a plausible part of speech instead of translating it,
which passes every structural check the parser makes. `assertNotEchoed` now fails a chunk whose
words come back unchanged, but the model is what keeps it from happening.

Per-target-language translate models live in `ModelRegistry.translateOverrides`, keyed by iso name;
a language with no entry there uses the default `translate` model.

## Failure handling

Every step wraps its LLM calls in retries (same counts/backoff as the Ruby code) and, on final
failure, appends an entry to `data.errors` **through the callback** before rethrowing — so the
failed LLM response is inspectable from Rails exactly like today:

```json
{
  "step": "add_token_translations",
  "occurred_at": "2026-07-19T10:00:00.000Z",
  "attempts": 3,
  "error_class": "Error",
  "error_message": "Word translation count mismatch: got 1, expected 4",
  "input_lines": ["Bonjour (*Bonjour* monde) |", "..."],
  "agent_response": "the raw model output"
}
```

When a resumed action later succeeds, it atomically removes all earlier `data.errors` entries for
that action. Errors from other concurrent actions remain available for diagnosis.

## Resumability

Every step persists its progress into `CreateSongProgress.data` as it goes, and every step is
guarded by the same predicates `create_data` used. Triggering the pipeline again with the saved
`data` (i.e. just calling `.create_data` again on the Rails side) resumes paused work and retries
only what failed:

- `extract_lyrics` keeps `extract_lyrics_in_progress` set until coverage is verified — an
  interrupted transcription reruns, a finished one is skipped.
- `add_token_translations` saves per **chunk** (whole phrases); a rerun only requests phrases whose
  `words` are still incomplete.
- `translate` / `add_lessons` / `rate_lessons` are atomic: done or rerun.
- `finalize_translation` stamps `format_version` and the payload metadata.

## Data & communication protocol

Only postgres saves data. The trigger request carries a `callback_url`; every mutation is POSTed
there as a batch of small patch operations — a key path and a value, never the whole multi-megabyte
blob:

```json
{
  "ops": [
    { "op": "set", "path": "translations.he.phrases.3.text", "value": "שלום" },
    { "op": "append", "path": "errors", "value": { "step": "translate", "...": "..." } }
  ]
}
```

- `path` is dot-separated; numeric segments index arrays; missing containers are created (array when
  the next segment is numeric, object otherwise).
- `append` pushes onto an array, creating it when missing.
- `clear_errors` removes entries from `errors` whose `step` matches its string value.

### HMAC authentication (both directions)

Every request — trigger and callback — is signed with the shared secret (`PIPELINE_HMAC_SECRET`
here, credentials on the Rails side):

```
x-pipeline-timestamp: <unix seconds>
x-pipeline-signature: hex(hmac_sha256(secret, "<timestamp>.<raw body>"))
```

Requests older than 5 minutes are rejected (replay protection), and signatures are compared in
constant time. See `src/hmac.ts`.

### Trigger format

`POST /run` (append `?async=1` to get an immediate `202` and let the run continue in the background
— progress still arrives via the callback):

```json
{
  "youtubeurl": "https://www.youtube.com/watch?v=...",
  "clip_language": "French",
  "translation_language": { "id": 3, "iso_name": "he", "english_name": "Hebrew" },
  "callback_url": "https://langlets.app/pipeline_callbacks/123",
  "data": {}
}
```

`data` is the record's exported `CreateSongProgress#data` (empty for a fresh run, the saved blob to
resume/retry). `translation_language: null` runs only transcription + lessons. The synchronous
response reports `{ ok, failed,
summary }` where `failed` maps branch → error message.

## Running

```sh
# HTTP server (what Deno Deploy runs)
PIPELINE_HMAC_SECRET=... SUPADATA_KEY=... ELEVEN_LABS_KEY=... OPENAI_API_KEY=... GOOGLE_GENERATIVE_AI_API_KEY=... OLLAMA_API_KEY=... \
  deno task serve

# CLI: same pipeline, callback URL as an argument
deno task cli https://langlets.app/pipeline_callbacks/123 \
  --input progress-export.json --iso he --lang-id 3

# tests / typecheck
deno task test
deno task check
```

`--input` accepts either a raw trigger payload or a `CreateSongProgress#export` file. Exports name
the translation language in English only, so pass `--iso` (and optionally `--lang-id`) when
targeting a language the export's data doesn't already contain.

Env vars: `PIPELINE_HMAC_SECRET` (required), `SUPADATA_KEY`, `ELEVEN_LABS_KEY`, `OPENAI_API_KEY`,
`GOOGLE_GENERATIVE_AI_API_KEY`, `OLLAMA_API_KEY`, `OLLAMA_BASE_URL` (defaults to
`https://ollama.com/v1`). For local runs copy `.env.example` to `.env` (gitignored) — the `serve`
and `cli` tasks load it via `--env-file`; real environment variables win over the file. On Deno
Deploy set them in the dashboard instead.

Set `YTDLP_NETWORK_NAMESPACE=vpn` on Linux to route only the `yt-dlp` audio download through that
network namespace. Leave it unset for direct execution. The command enables
`--remote-components ejs:github`, so the host (or configured namespace) must be able to reach
GitHub; yt-dlp uses the pipeline's Deno runtime to execute the downloaded YouTube challenge solver.

`ffprobe` and `ffmpeg` must be on `PATH`. Audio downloads are verified with them, because TikTok
serves silent HEVC renditions that yt-dlp reports as a successful download
([yt-dlp#15642](https://github.com/yt-dlp/yt-dlp/issues/15642)); a file with no audio stream or a
mean volume at or below -70 dB is discarded and the next of five format specs is tried
(`src/audio.ts`). Without ffmpeg the verification is skipped rather than failing the download, and
the silent-audio downloads come back.

## Layout

```
main.ts                 Deno Deploy entrypoint (Deno.serve)
cli.ts                  CLI entrypoint
src/pipeline.ts         orchestrator: guards + fan-out + finalize
src/steps/*.ts          one file per step
src/progress.ts         working copy of data + patch ops + step guards
src/callback.ts         HTTP sink (signed patches, retries) + MemorySink
src/hmac.ts             signing/verification
src/prompts/            one file per instruction prompt (keep in sync with app/views/prompts)
src/wordTimingParser.ts port of WordTimingParser
src/fuzzyword.ts        port of the fuzzyword Rust CLI (SymSpell-style lookup)
data/                   frequency dictionaries (copied from the repo's data/)
tests/                  full suite, run with `deno task test`
```

## Rails integration

The receiving side is implemented in the Rails app:

- **`POST /pipeline_callbacks/:id`** — `app/controllers/pipeline_callbacks_controller.rb` verifies
  the HMAC, then applies the batch under `with_lock` (the branches' callbacks can land concurrently)
  and saves. The model's `after_save` keeps `ImportRequest#progress_percent` synced, and
  `ProgressReporting` keeps deriving percent from `data` unchanged.
- **`app/services/progress_patch.rb`** — patch-op semantics, mirrored 1:1 from
  `src/progress.ts#applyOp` (both sides have tests asserting the same cases).
- **`app/lib/pipeline_hmac.rb`** — signing + verification, same `timestamp.body` scheme as
  `src/hmac.ts`. Secret comes from `ENV["PIPELINE_HMAC_SECRET"]` or the `pipeline_hmac_secret`
  credential. `PipelineHmac.signed_headers(body)` is what a trigger client uses to sign the outgoing
  request.

- **`app/services/create_song_pipeline_http.rb`** — the trigger. Signs the record's exported `data`
  and POSTs it to `/run`, blocking on the synchronous response: the run streams its mutations back
  through the callback as it goes, so the response carries only `{ ok, failed, summary }`. A failed
  branch raises, which is what makes `CreateCourseJob` refund the import rather than build a course
  from a half-filled blob. Retrying is just triggering again with the saved `data`.

This is the only implementation — the Ruby steps it was extracted from (`create_data`,
`add_translation` and the `CreateSong::*` concerns) were deleted once the pipeline took over, so
`CreateCourseJob` and `AddCourseTranslationJob` both trigger a run and there is no fallback. Rails
configures its endpoints with:

```ruby
config.x.pipeline.url = "https://pipeline.langlets.app"
config.x.pipeline.callback_base_url = "https://langlets.app"
```

`PIPELINE_HMAC_SECRET` remains secret configuration and must match the pipeline host's value.
Development maps the endpoints from `PIPELINE_URL` and `PIPELINE_CALLBACK_BASE_URL`; the latter is
the one that bites locally because the pipeline runs on another host, where `localhost:3000` is
itself. Point it at an ngrok tunnel to the local Rails.
