# Creating a Course from a YouTube URL

This guide covers how to create a new language-learning course from a YouTube video — both via the web UI and programmatically from the Rails console. It also documents the pipeline internals, common failure modes, and debugging strategies.

---

## Overview

Creating a course runs an AI pipeline that:

1. **Extracts lyrics** — transcribes/syncs timestamped phrases from the YouTube video
2. **Translates** — translates all phrases to the target language
3. **Adds token translations** — word-by-word alignment between source and target
4. **Adds lessons** — groups phrases into pedagogically structured lessons
5. **Adds similar sounds** — generates pronunciation-confusion pairs
6. **Builds the course** — creates Lesson, Phrase, TokenTranslation, and Activity records

The pipeline is driven by two records:

| Record | Purpose |
|---|---|
| `CreateSongProgress` | Tracks pipeline state, stores intermediate AI results in a JSONB `data` column |
| `Course` | The final course that students interact with |

---

## Web UI (Recommended)

1. Start the dev server: `./bin/dev`
2. Log in at `/users/sign_in` (ynon@hey.com / 10203040)
3. Go to `/courses/new`
4. Fill in the form:
   - **YouTube URL** — the video
   - **Clip Language** — the source language (e.g., "German")
   - **Translation Language** — the target language (e.g., "English")
   - **Course Name & Slug** — auto-generated, can be customized
5. Submit — a `CreateCourseJob` is enqueued and processes in the background
6. You'll receive an email when the course is ready (or if it fails)

---

## Programmatic Creation (Rails Console)

Use this when you need to create a course without the UI, retry a failed course, or debug the pipeline.

### Basic Flow

```ruby
admin = User.find_by(email: "ynon@hey.com")
german = Language.find_by(iso_name: "de")
english = Language.find_by(iso_name: "en")

url = "https://www.youtube.com/watch?v=VIDEO_ID"
slug = "my-course-slug"

# 1. Create the progress tracker
progress = CreateSongProgress.find_or_create_by!(
  youtubeurl: url,
  clip_language: "German",       # Must match Language.english_name
  translation_language: "English"
)
progress.data = {}               # Initialize empty JSONB
progress.save!

# 2. Create the course
course = Course.create!(
  slug: slug,
  name: "My Course Name",
  main_media_url: url,
  language: german,
  user: admin,
  status: :pending
)

# 3. Enqueue the job
CreateCourseJob.perform_later(progress.id, course.id)
```

### Monitoring Progress

Check the pipeline state:

```ruby
progress = CreateSongProgress.find(id)
course = Course.find(id)

# What steps have completed?
progress.data.keys  # => ["phrases", "phrases_with_token_translations", "lessons", ...]

# Course status: pending → processing → published (or error)
course.status
```

Pipeline states via `data` keys:

| Key present | Step completed |
|---|---|
| (empty) | Nothing yet |
| `"phrases"` | Extract lyrics + translate |
| `"phrases_with_token_translations"` | Token-level alignment |
| `"lessons"` | Lesson grouping |
| `"similar_sounds"` | Pronunciation pairs |

---

## Where the Pipeline Runs

The AI steps run **only** in the Deno pipeline, on a separate host. Rails triggers a run with `CreateSongPipelineHttp` and stores what comes back; it no longer performs any of the steps itself, and needs no model-provider keys.

Both entry points go through it:

| Entry point | Trigger |
|---|---|
| `/courses/new` → `CreateCourseJob` | one run for the course's own language; extra languages other imports asked for get their own `AddCourseTranslationJob` when the course publishes |
| Adding a language → `AddCourseTranslationJob` | one run for that language |

**The trigger does not wait for the run.** It POSTs `/run?async=1`, gets a `202`, and the job returns — so one worker can start any number of imports. Results arrive continuously via `POST /pipeline_callbacks/:id`, and after every batch `Imports::Finalizer` re-derives whether the blob now holds everything the waiting requests asked for. When it does, that's when the course is built, published and the requests marked ready.

Nothing can hang: each `ImportRequest` schedules an `ImportRequestTimeoutJob` for `ImportRequest::TIMEOUT` (10 minutes) from creation, which refunds the import — using the pipeline's own reported error as the reason when there is one. A failure in `extract_lyrics` or `force_alignment` ends the run outright, so those failures fail the import as soon as the error lands rather than waiting out the clock.

Retriggering resumes: each branch persists as it completes, and the saved `data` goes back with the next trigger.

There is no in-process fallback. `create_data`, `add_translation` and the `CreateSong::*` step concerns were removed when the pipeline became the only implementation, so `Rails.configuration.x.pipeline.url` is required — unset, it raises `CreateSongPipelineHttp::ConfigurationError`.

### Configuration

```ruby
# config/environments/production.rb
config.x.pipeline.url = "https://pipeline.langlets.app"
config.x.pipeline.callback_base_url = "https://langlets.app"
```

`PIPELINE_HMAC_SECRET` remains secret configuration and must be identical on
both sides. Development maps the endpoint settings from `PIPELINE_URL` and
`PIPELINE_CALLBACK_BASE_URL`. The callback URL is the one that catches people
out locally: the pipeline runs on a different host, so `localhost:3000` there
refers to itself, and callbacks silently go nowhere — which aborts the run,
since the pipeline treats undeliverable callbacks as fatal. Point it at an
ngrok tunnel:

```sh
ngrok http 3000        # → https://XXXX.ngrok-free.app
```

and allow the host in `config/environments/development.rb`:

```ruby
config.hosts << /.*\.ngrok-free\.app/
```

Note that ngrok is only needed for the **callback** direction. The trigger goes straight from Rails to the pipeline's public URL.

Watch a run with `journalctl -u langlets-pipeline -f` on the pipeline host. See `pipeline/README.md` for the pipeline's own internals.

---

## Models & Providers

Model selection lives entirely in the pipeline, in `pipeline/src/models.ts`. Rails has no say in it and holds no provider keys.

| Step | Model | Provider |
|---|---|---|
| `extract_lyrics` (transcript text) | Native captions; YouTube AI fallback | Supadata; Gemini 2.5 Flash |
| `force_alignment` (word timings) | Forced Alignment API | ElevenLabs |
| `add_lessons` | `deepseek-v4-pro:cloud` | Ollama cloud |
| `rate_lessons` | `deepseek-v4-pro:cloud` | Ollama cloud |
| `add_token_translations` | `deepseek-v4-pro:cloud` | Ollama cloud |
| `translate` | `qwen3.5:397b-cloud` | Ollama cloud |
| `translate` (target language Hebrew) | `nemotron-3-super:cloud` | Ollama cloud |

`extract_lyrics` makes one `mode=native` Supadata request. When that fails for a YouTube URL, it asks Gemini 2.5 Flash to transcribe the video with the lyric-specific prompt; other providers currently fail instead of using generated transcription. TikTok skips Supadata entirely for ElevenLabs Scribe — and when Scribe answers 400 because TikTok blocked its fetch of the post, the pipeline downloads the audio and sends Scribe the bytes instead. A `(400)` in `data.errors` for `extract_lyrics` therefore means both attempts failed; check `yt-dlp` and `ffmpeg` on the pipeline host, since silent-audio downloads are rejected on purpose. `force_alignment` downloads the audio and asks ElevenLabs to locate the continuous transcript. The lesson model then partitions those exact timed words into a `lessons -> lines` hierarchy, choosing complete comprehension and translation units rather than trusting provider cue boundaries or performance pauses.

Ollama cloud speaks the OpenAI chat-completions dialect, so it goes through `@ai-sdk/openai-compatible`. To change a model, edit `defaultModels()` and restart the service on the pipeline host:

```bash
sudo systemctl restart langlets-pipeline
```

Keys are set in `pipeline/.env` on that host: `SUPADATA_KEY`, `ELEVEN_LABS_KEY`, `GOOGLE_GENERATIVE_AI_API_KEY`, `OLLAMA_API_KEY`, plus the shared `PIPELINE_HMAC_SECRET`. Full LLM outputs are logged by default; set `PIPELINE_LOG_LLM=0` to silence them.

---

## Debugging Failed Courses

### Check Logs

```bash
tail -100 log/development.log | grep -E "Error|failed|Course creation"
```

### Common Failures

| Symptom | Cause | Fix |
|---|---|---|
| `PIPELINE_URL is not configured` | No pipeline host set | Set `PIPELINE_URL`; there is no in-process fallback |
| `pipeline returned 401` | `PIPELINE_HMAC_SECRET` differs between the two sides | Make them identical, then restart both |
| `could not reach the pipeline at ...` | Host down, DNS, or firewall | `curl https://<host>/health`; check `systemctl status langlets-pipeline` |
| `pipeline run failed: {"translate": ...}` | Only the `wait: true` form raises this; one branch failed and its error is in `data["errors"]` | Fix the cause and re-trigger — finished branches are not redone |
| Run starts, then nothing persists | Pipeline can't reach the callback URL | Check `PIPELINE_CALLBACK_BASE_URL` — in dev it must be the ngrok URL, not localhost |
| `You exceeded your current quota` | Provider rate limit | Change the model in `pipeline/src/models.ts` and restart the service |
| `Import timed out after 10 minutes` | No callback ever completed the blob | Check `data["errors"]` and the pipeline host's logs; the credit was already refunded |
| Import ready but course still `processing` | Data landed but the finalizer never ran | `Imports::Finalizer.call(progress)` — it is idempotent and safe to run by hand |
| Course stuck in `processing` | Job crashed without updating status | Check logs, fix issue, reset: `course.update!(status: :pending)` |

### Retrying a Failed Import

When the failure has an `ImportRequest` behind it (anything that came from the app, the share extension or the API), use the model — it resets the request, the course, the finalizer's view of the previous run's errors, and the deadline, which is all four of the things a hand-rolled retry usually forgets:

```ruby
ir = ImportRequest.find(ID)          # or: user.import_requests.recent_first.first
puts ir.failure_reason
puts ir.create_song_progress.pipeline_errors.last   # what the pipeline actually said

# fix the cause, then:
ir.retry!
```

It raises `ImportRequest::NotRetryable` if the request isn't `failed`, has no course or progress record, or the user already has that video importing. Credits are untouched — the failure refunded already. See the ImportRequest section in [architecture.md](../architecture.md) for what each move is for.

### Retrying a Failed Course

For a course with no `ImportRequest` (console-created, rake, legacy):

1. Diagnose and fix the root cause (model name, rate limit, etc.)
2. Reset the course:
   ```ruby
   course = Course.find(id)
   course.lessons.destroy_all if course.lessons.any?
   course.update!(status: :pending)
   ```
3. If pipeline made partial progress, optionally clear and start fresh:
   ```ruby
   progress = CreateSongProgress.find(progress_id)
   progress.data = {}
   progress.step = nil
   progress.save!
   ```
4. Re-enqueue: `CreateCourseJob.perform_later(progress.id, course.id)`

### The Pipeline Is Idempotent

Every branch is guarded on the contents of `data` before it runs (`pipeline/src/progress.ts`), and each one persists through the callback as it completes. The trigger sends the record's saved `data` back with every run, so a re-trigger resumes: finished branches are skipped and only the failed ones retry.

So if a step failed, resetting the course to `pending` and re-enqueuing picks up where it left off. The same holds for a run that died mid-flight — whatever had already been delivered is in postgres.

---

## Queue Adapter

| Environment | Adapter |
|---|---|
| `development` | `:async` (in-process thread pool) |
| `production` | `:solid_queue` |

In development, the async adapter runs jobs in background threads. You don't need to start Solid Queue. Jobs run as soon as they're enqueued, within the same process. In production, the dedicated Kamal `job` role runs `bin/jobs`.

To run a job synchronously (for debugging):
```ruby
CreateCourseJob.new.perform(progress.id, course.id)
```
This returns as soon as the pipeline accepts the run — it does not wait for the course. To watch the run itself, poll `CreateSongProgress#progress_percent` / `#current_step_label`, or trigger it in the foreground with `CreateSongPipelineHttp.new(progress: progress, wait: true).call` (what the rake tasks use).

---

## Pre-Pipeline Checklist

Before creating a course, verify these are in place:

- [ ] The language exists in the database: `Language.find_by(iso_name: "de")`
- [ ] The language has Azure TTS entries in `app/models/concerns/azure_text_to_speech.rb`
- [ ] Token translation prompt partials exist for the language pair (e.g., `_add_tokens_examples_german_english.md.erb`)
- [ ] `config.x.pipeline.url`, `config.x.pipeline.callback_base_url`, and `PIPELINE_HMAC_SECRET` are set
- [ ] The pipeline host answers: `curl https://<host>/health` → `{"ok":true}`
- [ ] In development: ngrok is running and its host is allowed in `development.rb`
