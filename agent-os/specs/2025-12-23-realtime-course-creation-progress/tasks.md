# Task Breakdown: Realtime Course Creation Progress

## Overview
Total Tasks: 4 Task Groups

## Task List

### Backend: Controller and Routing

#### Task Group 1: Public Progress Controller
**Dependencies:** None

- [ ] 1.0 Complete public progress controller
  - [ ] 1.1 Write 2-8 focused tests for CreateSongProgressesController
    - Test show action returns success for valid ID
    - Test show action renders correct view with video player
    - Test show action loads existing phrases from database
    - Test 404 behavior for non-existent records
    - Limit to critical controller functionality only
  - [ ] 1.2 Create CreateSongProgressesController with show action
    - RESTful route: GET /create_song_progresses/:id
    - Load CreateSongProgress record by ID
    - No authorization required (public records shared across users)
    - Set instance variables for view: @progress, @video_url, @phrases
  - [ ] 1.3 Add route to config/routes.rb
    - `resources :create_song_progresses, only: [:show]`
    - Follow Rails RESTful conventions
  - [ ] 1.4 Ensure controller tests pass
    - Run ONLY the 2-8 tests written in 1.1
    - Verify show action works correctly
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 1.1 pass
- Show action loads and displays progress record
- Route is accessible at /create_song_progresses/:id
- No authorization blocking access

### Backend: Action Cable Channel and Streaming

#### Task Group 2: Real-time Updates Infrastructure
**Dependencies:** Task Group 1

- [ ] 2.0 Complete Action Cable streaming infrastructure
  - [ ] 2.1 Write 2-8 focused tests for CreateSongProgressChannel
    - Test channel subscription with valid progress ID
    - Test phrase_added broadcast updates view
    - Test phrase_updated broadcast for translations
    - Test progress_updated broadcast for button state
    - Focus on critical streaming behaviors only
  - [ ] 2.2 Create CreateSongProgressChannel
    - Subscribe to specific CreateSongProgress by ID
    - Broadcast actions: phrase_added, phrase_updated, progress_updated
    - Support multiple simultaneous viewers
    - Minimal data payloads for efficiency
  - [ ] 2.3 Refactor ExtractLyrics concern for streaming
    - Modify extract_lyrics to yield each phrase as parsed from LLM
    - Save each phrase to data JSONB column incrementally
    - Broadcast phrase_added after each save
    - Handle streaming errors gracefully
    - Preserve existing functionality for non-streaming contexts
  - [ ] 2.4 Refactor Translate concern for streaming
    - Modify translate to stream translation updates per phrase
    - Update existing phrase in JSONB by ID with text_l2
    - Broadcast phrase_updated after each translation save
    - Maintain phrase structure while adding translations
  - [ ] 2.5 Implement incremental database saves
    - Parse LLM chunks into phrase objects
    - Save to JSONB data column after each phrase/translation
    - Structure: `{"phrases": [{"id": "uuid", "text_l1": "...", "timestamp": "00:01.23", "text_l2": "..."}]}`
    - Support page refresh to show latest progress
  - [ ] 2.6 Ensure Action Cable and streaming tests pass
    - Run ONLY the 2-8 tests written in 2.1
    - Verify critical broadcast behaviors work
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 2.1 pass
- CreateSongProgressChannel broadcasts updates in real-time
- ExtractLyrics streams phrases incrementally
- Translate streams translations incrementally
- Database saves occur after each chunk

### Frontend: Progress View with Video and Transcript

#### Task Group 3: Progress Page UI
**Dependencies:** Task Group 2

- [ ] 3.0 Complete progress page view
  - [ ] 3.1 Write 2-8 focused tests for progress view rendering
    - Test video player displays with YouTube iframe
    - Test transcript section renders existing phrases
    - Test Start Practice button displays in correct state
    - Test RTL language support for Arabic/Hebrew
    - Focus on critical view behaviors only
  - [ ] 3.2 Create app/views/create_song_progresses/show.html.erb
    - Reuse video player structure from full_player view
    - YouTube iframe with thumbnail background and play button overlay
    - Mobile-first responsive flex layout: `flex flex-col lg:flex-row`
    - Video container with aspect-video ratio
    - Use main-video-player Stimulus controller
  - [ ] 3.3 Build scrollable transcript section
    - Display phrases from database on initial load
    - Each phrase shows timestamp and text_l1
    - Bilingual text display with text_l2 when available
    - RTL support for Arabic and Hebrew languages
    - Scrollable container for growing phrase list
  - [ ] 3.4 Implement Start Practice button with progress indicator
    - Button initially disabled/grayed out
    - Visual progress: gradient fill (left-to-right) or progress bar below
    - Becomes enabled and links to course when ready? returns true
    - Replaced with red error message if creation fails
    - Turbo Stream target for dynamic updates
  - [ ] 3.5 Add Turbo Stream integration
    - Subscribe to CreateSongProgressChannel via Stimulus or inline JS
    - Turbo Stream templates for phrase_added (append new phrase)
    - Turbo Stream templates for phrase_updated (update existing phrase)
    - Turbo Stream templates for progress_updated (update button state)
  - [ ] 3.6 Implement responsive design
    - Mobile-first approach with stacked layout
    - Desktop side-by-side: video left, transcript right
    - Breakpoints: mobile (320px-768px), tablet (768px-1024px), desktop (1024px+)
    - Follow existing full_player responsive patterns
  - [ ] 3.7 Ensure progress view tests pass
    - Run ONLY the 2-8 tests written in 3.1
    - Verify critical view behaviors work
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 3.1 pass
- Video player displays YouTube content correctly
- Transcript shows existing and streamed phrases
- Start Practice button displays with progress indicator
- Responsive design works across devices
- RTL languages display correctly

### Testing: Feature Integration and Workflow Coverage

#### Task Group 4: Test Review & Gap Analysis
**Dependencies:** Task Groups 1-3

- [ ] 4.0 Review existing tests and fill critical gaps only
  - [ ] 4.1 Review tests from Task Groups 1-3
    - Review the 2-8 tests for CreateSongProgressesController (Task 1.1)
    - Review the 2-8 tests for CreateSongProgressChannel (Task 2.1)
    - Review the 2-8 tests for progress view rendering (Task 3.1)
    - Total existing tests: approximately 6-24 tests
  - [ ] 4.2 Analyze test coverage gaps for THIS feature only
    - Identify critical end-to-end workflows lacking coverage
    - Focus: user loads page → sees video → phrases stream → translations appear → button enables
    - Do NOT assess entire application test coverage
    - Prioritize integration points between channel, concerns, and view
  - [ ] 4.3 Write up to 10 additional strategic tests maximum
    - End-to-end test: full course creation flow with streaming
    - Test: page refresh shows latest database state + new streams
    - Test: multiple viewers receive same broadcasts
    - Test: graceful error handling when LLM streaming fails
    - Test: progress indicator updates correctly
    - Do NOT write comprehensive coverage for all edge cases
  - [ ] 4.4 Run feature-specific tests only
    - Run ONLY tests related to this realtime progress feature
    - Expected total: approximately 16-34 tests maximum
    - Do NOT run the entire application test suite
    - Verify critical workflows pass

**Acceptance Criteria:**
- All feature-specific tests pass (approximately 16-34 tests total)
- Critical end-to-end workflow is covered
- No more than 10 additional tests added
- Testing focused exclusively on realtime progress feature

## Execution Order

Recommended implementation sequence:
1. Backend Controller and Routing (Task Group 1)
2. Action Cable Channel and Streaming (Task Group 2)
3. Progress Page UI (Task Group 3)
4. Test Review and Gap Analysis (Task Group 4)

## Implementation Notes

### Key Technical Patterns to Follow

**Video Player Reuse:**
- Copy YouTube iframe structure from `app/views/full_player/show.html.erb`
- Use `main-video-player` Stimulus controller (already exists)
- Maintain aspect-video ratio and responsive layout
- Include thumbnail background and play button overlay

**Streaming Architecture:**
- ExtractLyrics yields phrase objects: `{id: uuid, text_l1: string, timestamp: string}`
- Translate yields updates: `{id: uuid, text_l2: string}`
- Save to database after each yield
- Broadcast via Action Cable after each save
- Turbo Streams append/update DOM elements

**JSONB Data Structure:**
```ruby
{
  "phrases": [
    {
      "id": "uuid-string",
      "text_l1": "Original text",
      "timestamp": "00:01.23",
      "text_l2": "Translated text"  # Added after translation
    }
  ]
}
```

**Database Incremental Updates:**
- Initial page load: fetch all phrases from data column
- Stream new data: append phrases or update existing ones
- Users can refresh and see latest state without losing progress

**Progress Button States:**
1. Disabled/grayed (while processing)
2. Enabled/linked (when ready? returns true)
3. Error message (if creation fails)

### Reference Files

**Existing Code to Study:**
- `app/views/full_player/show.html.erb` - Video player layout
- `app/javascript/controllers/main_video_player_controller.js` - Video interactions
- `app/models/create_song_progress.rb` - Model with concerns
- `app/models/concerns/extract_lyrics.rb` - To be refactored for streaming
- `app/models/concerns/translate.rb` - To be refactored for streaming

**Testing Patterns:**
- Focus on critical paths only during development
- Write minimal tests (2-8 per task group)
- Run only feature-specific tests, not entire suite
- Add up to 10 strategic tests in gap analysis phase
