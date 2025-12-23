# Specification: Full Song Player

## Goal
Create a dedicated page that allows users to watch the complete course video with synchronized bilingual transcripts and download a filtered vocabulary table as CSV.

## User Stories
- As a learner, I want to watch the full course video with all transcripts visible so that I can see the complete content before starting or review after finishing
- As a learner, I want to download a vocabulary table with important words filtered by my level so that I can study offline with relevant vocabulary

## Specific Requirements

**Course-Level Feature Toggle**
- Add boolean attribute `show_full_course_player` to Course model via migration
- Default value should be `false` for existing courses
- Only courses with this flag enabled will show the "Watch Full Video" button on the course show page

**Full Player Route and Controller**
- Create route `/courses/:course_slug/full-player` mapped to a new controller action
- Controller should load all phrases from the course's medium (ordered by timestamp)
- Controller should extract video_id from course's main_media_url
- Pass start timestamp (first phrase) and end timestamp (last phrase) to view

**Video Player with Complete Transcript**
- Reuse existing watch-video-activity infrastructure including Plyr player, Stimulus controllers (watch-video-activity, popover-translation, main-video-player)
- Display ALL phrases from the medium instead of lesson-specific subset
- Maintain synchronized subtitle highlighting and click-to-seek functionality
- Maintain clickable word translation popover feature
- Exclude completion message and progress tracking (no activity_users records)
- Include show/hide translation toggle control

**Responsive Layout Design**
- Mobile (default): Stack vertically - video player at top, scrollable transcript below, vocabulary table at bottom
- Desktop (lg: breakpoint): Side-by-side layout using `lg:flex-row` - video player on left, scrollable transcript on right, vocabulary table below both
- Use Tailwind responsive classes consistent with existing patterns (flex flex-col lg:flex-row)
- Video player should be in a fixed-height container to allow transcript scrolling

**Vocabulary Table with CSV Export**
- Query all unique token_translations from course's medium phrases
- Filter vocabulary based on user's language level (A1, A2, B1, B2, C1, C2) using predefined common words lists
- Display table with columns: L1 word (original_text), L2 translation, frequency count
- Show all filtered words at once (no pagination)
- Add "Download CSV" button that generates and downloads CSV file with same data
- CSV should include headers: "Word,Translation,Frequency"

**Course Show Page Integration**
- Add "Watch Full Video" button/link on course show page near lesson list
- Button only appears when `show_full_course_player` is true
- Style button consistently with existing course UI elements
- Link should navigate to `/courses/:course_slug/full-player`

## Visual Design

No visual mockups provided - follow existing watch-video-activity patterns for consistency.

## Existing Code to Leverage

**Watch Video Activity View and Controllers**
- Path: `app/views/activities/_watch_video_activity.html.erb`
- Reuse video player setup with Plyr, synchronized subtitles, bilingual transcript display
- Reuse timestamp click-to-seek functionality
- Reuse popover translation with wrap_tokens_in_spans helper
- Adapt the data-segment-start and data-segment-end to use first/last phrase timestamps from entire medium

**Stimulus Controllers**
- `watch-video-activity` controller handles video events, subtitle highlighting, translation toggle
- `main-video-player` controller manages YouTube player initialization and playback
- `popover-translation` controller handles word click translations
- All three should work without modification for full player use case

**Models and Associations**
- Course belongs_to medium, Medium has_many phrases, Phrase has_many token_translations
- Use `course.medium.phrases` to fetch all phrases ordered by timestamp
- Use `phrases.flat_map(&:token_translations)` to get all vocabulary items
- TokenTranslation has `original_text` method to extract word from phrase
- Phrases have timestamp field for video synchronization

**Responsive Layout Patterns**
- Course show page uses `flex flex-col lg:flex-row` for responsive layouts
- Use similar pattern for side-by-side video and transcript on desktop

**Helper Methods**
- `timestamp_to_seconds` helper converts "mm:ss" format to seconds for video player
- `wrap_tokens_in_spans` helper makes words clickable with popover data attributes

## Out of Scope
- Do not implement activity completion tracking or progress recording
- Do not create activity_users records for the full player
- Do not add next/previous navigation between lessons
- Do not implement pagination for vocabulary table
- Do not add sorting or search functionality to vocabulary table
- Do not create separate tabs or modal dialogs for vocabulary section
- Do not build common words filtering lists yet (use all token_translations in first iteration)
- Do not implement manual tagging of important vocabulary
- Do not add video playback controls beyond what Plyr provides by default
- Do not create new Stimulus controllers (reuse existing ones)
