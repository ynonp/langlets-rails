# Specification: Realtime Course Creation Progress

> **SUPERSEDED — not implemented, do not implement.**
>
> Import progress is now surfaced by the mobile app's Queue screen, which polls a
> `progress_percent` column on `import_requests` every 3s rather than streaming
> over Action Cable. The reasoning: this app has no `app/channels` at all (even
> `ApplicationCable::Connection` would be new), WKWebView sockets drop whenever
> iOS backgrounds the app, and pipeline updates only arrive at LLM-step
> boundaries — tens of seconds apart — so sub-second delivery buys nothing. The
> signal that actually matters when an import finishes is an APNs push.
>
> Two artifacts of this spec leaked onto `main` and have been cleaned up: a dead
> `resources :create_song_progress` route pointing at a controller that never
> existed, and the unbacked `courses.create_song_progress_id` column (now covered
> by `db/migrate/20251225152852_connect_course_to_creator.rb`).
>
> Earlier attempts live on `origin/copilot/create-song-progress-view` (850c820)
> and the local `create-song-progress-view` branch (685da3e). Neither is an
> ancestor of `main`.

## Goal
Build a public progress page that displays real-time updates as a CreateSongProgress record generates a course, allowing users to watch lyrics extraction and translation streaming live via Action Cable and Turbo Streams.

## User Stories
- As a user who requested course creation, I want to watch the progress in real-time so that I can see lyrics and translations being generated without refreshing the page
- As a user who left the progress page, I want to return later and see the current state so that I can track progress without losing my place

## Specific Requirements

**Public Progress Page with Video Player**
- Create `CreateSongProgressesController` with RESTful `show` action at route `/create_song_progresses/:id`
- Display YouTube video player from beginning (before any lyrics are extracted)
- Reuse video player structure from full_player view: YouTube iframe, thumbnail background, play button overlay
- Use existing `main-video-player` Stimulus controller for video interactions
- No authorization required - progress records are shared across users based on unique index
- Support RTL languages (Arabic, Hebrew) using existing patterns from full_player
- Mobile-first responsive design with flex layout

**Real-time Lyrics Streaming**
- Stream each phrase as it's extracted from LLM response (id, text_l1, timestamp)
- Display phrases in scrollable transcript section below video player
- Parse and save each phrase to `create_song_progresses.data` JSONB column immediately upon receipt
- Broadcast each saved phrase via Action Cable `CreateSongProgressChannel`
- Use Turbo Streams to append new phrases to transcript view in real-time
- Initial page load shows existing phrases from database plus new streamed updates
- Phrases displayed with timestamp and L1 text in bilingual format

**Real-time Translation Streaming**
- Stream translation updates as they're received from LLM (updating existing phrases with text_l2)
- Update existing phrase records in database with L2 translation incrementally
- Broadcast translation updates via Action Cable for specific phrase IDs
- Use Turbo Streams to update individual phrase elements in view
- Display both L1 and L2 text once translation arrives

**Progress Indicator and Start Practice Button**
- Display "Start Practice" button below video player, initially disabled/grayed out
- Progress indicator shown either as gradient on button (left-to-right fill) or as progress bar below button
- Button becomes enabled and links to course page when `ready?` returns true
- Button area replaced with red error message if course creation fails
- Progress updates broadcast via Turbo Streams to update button state and visual indicator

**Action Cable Channel for Streaming**
- Create `CreateSongProgressChannel` for WebSocket communication
- Channel subscribes to specific CreateSongProgress record by ID
- Broadcast actions: `phrase_added` (new phrase), `phrase_updated` (translation added), `progress_updated` (status change)
- Support multiple simultaneous viewers on same progress record
- Each broadcast includes minimal data payload (phrase object or status update)

**Refactor ExtractLyrics Concern for Streaming**
- Modify `extract_lyrics` method to yield/stream each phrase as parsed from LLM response
- Parse streamed chunks from Gemini API into individual phrase objects
- Save each phrase to JSONB data column incrementally (append to phrases array)
- Broadcast via CreateSongProgressChannel after each save
- Handle streaming errors gracefully, preserving partial results in database

**Refactor Translate Concern for Streaming**
- Modify `translate` method to stream translation updates for each phrase
- Parse translation chunks from LLM to identify phrase ID and text_l2
- Update existing phrase in JSONB data by finding matching ID and adding text_l2
- Broadcast phrase update via Action Cable after each save
- Maintain existing phrase structure while adding translation field

**Database Incremental Saves Strategy**
- Save to database after every phrase extraction (not batch at end)
- Save translation updates phrase-by-phrase as received
- JSONB data structure: `{"phrases": [{"id": "uuid", "text_l1": "...", "timestamp": "00:01.23", "text_l2": "..."}]}`
- Users can refresh page and see latest progress from database
- Combine database state with new streaming updates on page load

## Visual Design
No visual assets provided.

## Existing Code to Leverage

**Full Player View (app/views/full_player/show.html.erb)**
- YouTube video player layout with thumbnail background and play button overlay
- Responsive flex layout: `flex flex-col lg:flex-row` for desktop side-by-side
- Video container with aspect-video ratio and background thumbnail image
- Transcript section with scrollable phrases container
- Bilingual text display with RTL support for L1 and L2
- Integration with main-video-player Stimulus controller

**Main Video Player Stimulus Controller (app/javascript/controllers/main_video_player_controller.js)**
- YouTube iframe initialization with YouTubePlayer library
- Video playback control methods: togglePlayPause, fullPlayerStartPlayback, fullPlayerStopPlayback
- Custom progress bar with seek functionality
- Event dispatching for video state changes (play, stop, end, progress)
- Player lifecycle management (connect, disconnect, initialize)

**Turbo Streams Pattern (app/controllers/progress_controller.rb)**
- Existing pattern: `format.turbo_stream { render turbo_stream: turbo_stream.replace(...) }`
- Shows how to respond with Turbo Stream updates for real-time DOM updates
- Pattern for replacing/updating specific elements by ID
- Integration with Accept header: 'text/vnd.turbo-stream.html'

**CreateSongProgress Model (app/models/create_song_progress.rb)**
- Existing concerns: ExtractLyrics, Translate, AddTokenTranslations, AddLessons, AddSimilarSound
- JSONB data column with flexible structure for phrases
- Unique index on (youtubeurl, clip_language, translation_language) ensures shared records
- ready? method to check if course generation is complete

**Database Schema (create_song_progresses table)**
- Columns: id, youtubeurl, clip_language, translation_language, step, data (jsonb), lyrics (text)
- Unique index prevents duplicate processing for same URL + language combination
- JSONB data column supports incremental updates without schema changes

## Out of Scope
- Token translations display (not relevant to progress page)
- Lessons display (not relevant to progress page)
- Similar sounds display (not relevant to progress page)
- User authentication or authorization (records are publicly shared)
- User-specific progress tracking (no user_id on model)
- Mobile-specific UI optimizations beyond responsive flex layout
- Edit or delete functionality for progress records
- Manual retry of failed generation steps
- Background job monitoring dashboard
- Progress page for other model types (only CreateSongProgress)
- Custom video player controls beyond existing main-video-player functionality
