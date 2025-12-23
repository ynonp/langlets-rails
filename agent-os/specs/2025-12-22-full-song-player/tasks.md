# Task Breakdown: Full Song Player

## Overview
Total Tasks: 4 major task groups with strategic sub-tasks

## Task List

### Database Layer

#### Task Group 1: Course Model Enhancement
**Dependencies:** None

- [x] 1.0 Complete database layer changes
  - [x] 1.1 Write 2-8 focused tests for Course model enhancement
    - Test `show_full_course_player` boolean attribute defaults to false
    - Test scope/query methods for finding courses with full player enabled
    - Test validation behavior if applicable
    - Limit to 2-8 highly focused tests maximum
  - [x] 1.2 Create migration for Course model
    - Add `show_full_course_player` boolean column to courses table
    - Set default value to `true`
    - Add NOT NULL constraint for data integrity
  - [x] 1.3 Update Course model
    - Add validation if needed for boolean attribute
    - Add scope method for courses with full player enabled (e.g., `scope :with_full_player, -> { where(show_full_course_player: true) }`)
  - [x] 1.4 Run migration
    - Execute `./bin/rails db:migrate`
    - Verify column added successfully with `./bin/rails db:version`
  - [x] 1.5 Ensure database layer tests pass
    - Run ONLY the 2-8 tests written in 1.1
    - Verify migrations run successfully
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 1.1 pass
- Migration runs successfully with `show_full_course_player` column added
- Existing courses default to `true` for the new attribute
- Course model properly handles the new boolean attribute

### Backend Controller & Routes

#### Task Group 2: Full Player Controller and Routes
**Dependencies:** Task Group 1

- [x] 2.0 Complete backend routing and controller logic
  - [x] 2.1 Write 2-8 focused tests for FullPlayerController
    - Test routing to `/courses/:course_slug/full-player` works correctly
    - Test controller loads all phrases from course's medium ordered by timestamp
    - Test controller extracts video_id from course's main_media_url
    - Test controller passes start/end timestamps to view
    - Test controller handles course not found gracefully
    - Limit to 2-8 highly focused tests maximum
  - [x] 2.2 Add route to config/routes.rb
    - Add route: `get 'courses/:course_slug/full-player', to: 'full_player#show', as: :course_full_player`
    - Follow existing routing patterns in routes.rb
  - [x] 2.3 Create FullPlayerController
    - Create `app/controllers/full_player_controller.rb`
    - Implement `show` action that:
      - Finds course by slug
      - Loads all phrases from `course.medium.phrases.order(:timestamp)`
      - Extracts video_id from course's main_media_url (YouTube URL parsing)
      - Calculates start timestamp (first phrase timestamp) and end timestamp (last phrase timestamp)
      - Passes all necessary data to view (course, phrases, video_id, start_timestamp, end_timestamp)
  - [x] 2.4 Add authentication/authorization
    - Use existing auth pattern (require user login if applicable)
    - Check if user has access to view the course
  - [x] 2.5 Ensure backend layer tests pass
    - Run ONLY the 2-8 tests written in 2.1
    - Verify routing works correctly
    - Verify controller logic loads correct data
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 2.1 pass
- Route `/courses/:course_slug/full-player` resolves correctly
- Controller loads all course phrases ordered by timestamp
- Video ID extracted correctly from YouTube URL
- Start and end timestamps calculated from phrase data

### Frontend Views & Vocabulary Table

#### Task Group 3: Full Player View and Vocabulary Table
**Dependencies:** Task Group 2

- [x] 3.0 Complete frontend view and vocabulary table
  - [x] 3.1 Write 2-8 focused tests for view rendering and vocabulary logic
  - [x] 3.2 Create full player view file
  - [x] 3.3 Implement video player section
  - [x] 3.4 Implement bilingual transcript section
  - [x] 3.5 Implement vocabulary table section
  - [x] 3.6 Add CSV download functionality
  - [x] 3.7 Apply responsive layout
  - [x] 3.8 Ensure frontend tests pass

**Acceptance Criteria:**
- The 2-8 tests written in 3.1 pass
- Video player displays full course video with synchronized subtitles
- Transcript shows all phrases with clickable words and translation popovers
- Show/hide translation toggle works correctly
- Vocabulary table displays all unique words with L1, L2, and frequency columns
- CSV download generates correct file with vocabulary data
- Responsive layout works: stacked on mobile, side-by-side on desktop

### Course Integration & UI Polish

#### Task Group 4: Course Show Page Integration
**Dependencies:** Task Group 3

- [x] 4.0 Complete course show page integration
  - [x] 4.1 Write 2-8 focused tests for course integration
  - [x] 4.2 Add "Watch Full Video" button to course show page
  - [x] 4.3 Style button consistently with existing UI
  - [x] 4.4 Test full user workflow manually
  - [x] 4.5 Ensure course integration tests pass

**Acceptance Criteria:**
- The 2-8 tests written in 4.1 pass
- "Watch Full Video" button appears only when course has `show_full_course_player: true`
- Button navigates correctly to full player page
- Button styling matches existing course UI
- Full user workflow from course page to full player to CSV download works end-to-end

### Testing & Quality Assurance

#### Task Group 5: Strategic Test Coverage Review
**Dependencies:** Task Groups 1-4

- [x] 5.0 Review existing tests and fill critical gaps only
  - [x] 5.1 Review tests from Task Groups 1-4
  - [x] 5.2 Analyze test coverage gaps for THIS feature only
  - [x] 5.3 Write up to 10 additional strategic tests maximum
  - [x] 5.4 Run feature-specific tests only

**Acceptance Criteria:**
- All feature-specific tests pass (approximately 18-42 tests total)
- Critical user workflows for full song player are covered by tests
- No more than 10 additional tests added when filling in testing gaps
- Testing focused exclusively on full song player feature requirements

## Execution Order

Recommended implementation sequence:
1. Database Layer (Task Group 1) - Add Course model boolean attribute
2. Backend Controller & Routes (Task Group 2) - Create routing and controller logic
3. Frontend Views & Vocabulary Table (Task Group 3) - Build full player view with video, transcript, and vocabulary
4. Course Integration & UI Polish (Task Group 4) - Add button to course show page
5. Testing & Quality Assurance (Task Group 5) - Review test coverage and fill critical gaps

## Notes

- **Reuse Existing Code:** Heavily reuse patterns from `app/views/activities/_watch_video_activity.html.erb` and associated Stimulus controllers
- **No New Stimulus Controllers:** Reuse existing `watch-video-activity`, `main-video-player`, and `popover-translation` controllers
- **No Progress Tracking:** This feature does NOT create activity_users records or track completion
- **CEFR Filtering Deferred:** Initial implementation shows ALL token_translations; CEFR-level filtering (A1-C2) is out of scope for now
- **Responsive Design:** Follow existing patterns from course show page using Tailwind's `flex flex-col lg:flex-row` for desktop side-by-side layout
- **CSV Export:** Implement simple CSV generation and download (can use Ruby CSV library or JavaScript approach)
- **Testing Philosophy:** Follow minimal test-driven approach with 2-8 tests per task group during development, then strategic gap filling at end
