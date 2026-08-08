# Working With Langlets

Langlets is an online language learning platform.

Before working on a new feature make sure to:
1. Read `docs/architecture.md`.
2. Read `db/schema.rb` to understand the database schema.
3. Create a detailed plan and follow it step by step.

The system is in production. Use Rails and React best practices when implementing new features and watch for breaking changes.

We use `docs/architecture.md` to reflect the state of the platform and for future coding agents so after every feature also update this file.

## DB Setup
Your environment has a full Rails environment installed with a postgres database.
There are 2 databases described in `config/database.yml`, one for development and the other for tests.
Verify you can connect to the DB for development with:
`./bin/rails db:version`

Verify you can connect to the test DB to run tests with:
`RAILS_ENV=test ./bin/rails db:version`

### Copilot database config behavior
The Copilot setup workflow marks `config/database.yml` with `git update-index --skip-worktree` before applying agent-local database settings. This keeps agent-specific database changes out of PR diffs.

If you intentionally need to edit `config/database.yml` in a Copilot session:
1. Run `git update-index --no-skip-worktree config/database.yml`
2. Make the change
3. Commit or otherwise save the change you want Git to notice
4. Run `git update-index --skip-worktree config/database.yml` again
5. Continue working normally; this re-hides future agent-local edits without changing the file contents already on disk

## App Setup
Your environment has a full Rails environment installed.
Start the development server with: `./bin/dev`.
After the app starts you can login to the admin page with development credentials:
   - Username: ynon@hey.com
   - Password: 10203040

# Docs

All project documentation lives in the `docs/` folder. Read the relevant doc
before starting work on a topic, and keep these files up to date when you change
the related behavior.

| Doc | Description |
|---|---|
| [Architecture](docs/architecture.md) | The state of the platform — domain model, data flow, and system architecture. Read this before any new feature, and update it after every feature. |
| [Video Players](docs/video-player.md) | The four kinds of video players in the app (full course player, watch-video activity, hidden audio player, and the compact "mini" layout) — what each is for, what they share, and what to check when changing playback. |
| [Adding a New Video Provider](docs/add-new-video-provider.md) | Checklist for adding a third video provider alongside YouTube and TikTok — the provider contract, the asymmetries that break assumptions (missing ids, non-derivable covers, aspect ratio), the player adapter, the pipeline, and every place a provider is assumed. |
| [Adding a New Language](docs/guides/adding-a-new-language.md) | Complete checklist for adding a new language to the platform — migrations, AI prompts, Azure TTS, and more. |
| [Creating a Course from a YouTube URL](docs/guides/creating-a-course.md) | How to create a course via UI or console, understand the AI pipeline, debug failures, and switch AI providers. |

# Coding Context

## Stimulus Controllers
1. Prefer `data-action` when writing stimulus controllers instead of binding event handlers from the controller.
2. All stimulus controllers are listed in file: `app/javascript/controllers/index.js`.
   When you add new controllers it's mandatory to update the file by running: `./bin/rails stimulus:manifest:update`

## Time and date
1. Use Time.zone.now instead of Time.current

## iOS Hotwire Native App
1. Use CSS safe areas

```
env(safe-area-inset-right, 1em);
env(titlebar-area-y, 40px);
env(viewport-segment-width 0 0, 40%);
```

## Native App Tabs
1. Every time we change paths in the app also check the links on the native (iOS + Android) apps tabs.
   - iOS tab URLs are defined in `langlets-ios/langlets/langlets/AppTabBarController.swift` (the `tabs` array).
   - Android tab URLs are defined in `langlets-android/app/src/main/java/com/ynonp/langlets/MainActivity.kt` (the `tabs` property).
   - Path configuration rules that affect tab routing are in `config/hotwire/ios_path_configuration.json` and `config/hotwire/android_path_configuration.json`.
   - Offline fallback copies live in the native app bundles and must stay identical (enforced by test).