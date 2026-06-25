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

## Model Parameters & Providers

The `CreateSongProgress` model has four sets of model parameters that control which AI model is used for each pipeline step:

| Parameter | Used by | Default model |
|---|---|---|
| `model_params_youtube` | Extract lyrics | `gemini-3.5-flash` (Gemini) |
| `model_params_quick` | (not in main pipeline) | `gemini-3-flash-preview` (Gemini) |
| `model_params_smart` | Token translations | `gemini-3.1-pro-preview` (Gemini) |
| `model_params_translate` | Translate phrases | `gemini-3-flash-preview` (Gemini) |

These are **virtual attributes** (declared with `attribute` — not backed by a DB column). They are initialized from defaults every time the record is loaded from the database.

### Switching to Local Ollama Models

If Gemini rate limits are hit (or for offline dev), switch to local models:

```ruby
# Option A: Per-instance (must be done on the object that runs the job)
progress = CreateSongProgress.find(id)
progress.save!
# WARNING: This does NOT persist model_params changes across job reloads!
# The job loads a fresh progress from DB → defaults are restored.
```

**The right way to switch providers:** temporarily change the defaults in `app/models/create_song_progress.rb`:

```ruby
# Change from gemini to ollama:
attribute :model_params_smart, default: {model: 'deepseek-v4-pro:cloud', provider: :openai, assume_model_exists: true }
attribute :model_params_translate, default: {model: 'qwen3.5:397b-cloud', provider: :openai, assume_model_exists: true }
```

The `provider: :openai` with an Ollama cloud model works because `config/initializers/ruby_llm.rb` routes the OpenAI provider to the local Ollama server (`http://localhost:11434/v1`).

**Revert after use!** The Geminis defaults are for production.

### Validating Model Names

Before creating a course, verify the model names actually exist:

```ruby
# For Gemini:
key = Rails.application.credentials.dig(:google_api_key)
uri = URI("https://generativelanguage.googleapis.com/v1beta/models?key=#{key}")
JSON.parse(Net::HTTP.get(uri))["models"].map { |m| m["name"].gsub("models/", "") }.grep(/gemini/).sort

# For Ollama:
# Check http://localhost:11434/api/tags
```

Common gotcha: Google model names often have a `-preview` suffix (e.g., `gemini-3.1-pro-preview`, not `gemini-3.1-pro`).

---

## Debugging Failed Courses

### Check Logs

```bash
tail -100 log/development.log | grep -E "Error|failed|Course creation"
```

### Common Failures

| Symptom | Cause | Fix |
|---|---|---|
| `models/gemini-X.Y-pro is not found` | Invalid model name | Fix model name in `CreateSongProgress` defaults |
| `You exceeded your current quota` | Gemini rate limit | Switch to Ollama models or wait |
| `ContextLengthExceededError` | Prompt too long for model | Split into smaller batches or use a larger-context model |
| `undefined method '[]' for nil` in `create_data` | `progress.data` is `nil` | Initialize with `progress.data = {}; progress.save!` |
| Course stuck in `processing` | Job crashed without updating status | Check logs, fix issue, reset: `course.update!(status: :pending)` |

### Retrying a Failed Course

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

Each step in `create_data` checks whether its output already exists before running:

```ruby
extract_lyrics unless data["phrases"].present?
translate unless data.dig("phrases", 0, "text_l2")
add_token_translation unless data["phrases_with_token_translations"].present?
add_lessons unless data["lessons"].present?
add_similar_sound unless similar_sounds_complete?
```

So if a step failed, resetting the course to `pending` and re-enqueuing will pick up from where it left off.

---

## Queue Adapter

| Environment | Adapter |
|---|---|
| `development` | `:async` (in-process thread pool) |
| `production` | `:good_job` |

In development, the async adapter runs jobs in background threads. You don't need to start GoodJob. Jobs run as soon as they're enqueued, within the same process.

To run a job synchronously (blocking, for debugging):
```ruby
CreateCourseJob.new.perform(progress.id, course.id)
```
But note: API calls can take minutes — better to use `perform_later` and monitor via the console.

---

## Pre-Pipeline Checklist

Before creating a course, verify these are in place:

- [ ] The language exists in the database: `Language.find_by(iso_name: "de")`
- [ ] The language has Azure TTS entries in `app/models/concerns/azure_text_to_speech.rb`
- [ ] Token translation prompt partials exist for the language pair (e.g., `_add_tokens_examples_german_english.md.erb`)
- [ ] Model names in `CreateSongProgress` defaults point to real, accessible models
- [ ] If using Ollama: `ollama serve` is running and the models are pulled
