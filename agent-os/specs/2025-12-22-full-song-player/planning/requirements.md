# Spec Requirements: Full Song Player

## Initial Description
The feature is not in the roadmap but nonetheless important one and that is a full song player page

There should be a way for a user to view the full youtube video of a course with its transcript and translation (similar to how _watch_video_activity shows just a specific lesson). I'd like to use the same infrastructure but show all the text of the song, maybe it should be a special lesson "listen from start to finish"

This could be fun both at the start of the learning process to see what's on the table and at the end for review.

The full song player should also include a vocabulary table with important vocabulary downloadable as CSV

## Requirements Discussion

### First Round Questions

**Q1:** I assume this should be accessible as a special lesson type within a course (like "Full Song" or "Complete Video") that users can navigate to from the course page. Should it be:
- Auto-created for every course (always available)
- Created manually by the teacher when setting up a course
- Both options available?

**Answer:** It's best if this could be sort of a boolean attribute of the Course "show_full_course_player". The player will be reachable from the course index

**Q2:** For the video player, I'm thinking we should reuse the existing `watch-video-activity` infrastructure (Plyr player with synchronized subtitles) but show ALL phrases from the course's medium instead of just a lesson segment. The timestamp range would be from the first phrase to the last phrase in the course. Is that correct?

**Answer:** Yes

**Q3:** Regarding the vocabulary table with downloadable CSV, I assume this should:
- List all unique words from the entire course (from token_translations table)
- Include columns: L1 word, L2 translation, frequency count
- Be downloadable as CSV from a button on the page
- Optionally: Filter by "important" words (maybe most frequent, or manually tagged)?
Should we include all words or have some filtering criteria?

**Answer:** So one option is to use all token translations. I'm not sure if it's not too much. Maybe we should filter out basic words somehow

**Q4:** For the page layout, I'm assuming:
- Video player at top (full width or centered)
- Scrollable transcript below (bilingual, just like watch-video-activity)
- Vocabulary table at the bottom (or as a separate tab/section)
- Same "click word for translation" popover feature
Is this the right layout, or would you prefer a different arrangement?

**Answer:** That works for smaller screens (mobile). If you have full width it might be better to put the video and text side by side

**Q5:** Should this page track completion/progress like other activities, or is it purely for reference and review (no activity_users tracking)?

**Answer:** No need to track completion/progress

**Q6:** For routing and URLs, I assume it should be something like:
- `/courses/:course_slug/full-player` or `/courses/:course_slug/complete`
- Accessible from the course page via a link/button like "Watch Full Video"
Is that correct?

**Answer:** Yes

**Q7:** Are there any features from the regular watch-video-activity we should exclude (like the completion message, "show/hide translation" toggle, etc.), or should we keep everything?

**Answer:** Completion message is not needed

### Existing Code to Reference

**Similar Features Identified:**
- Feature: Watch Video Activity - Path: `app/views/activities/_watch_video_activity.html.erb`
- Components to potentially reuse: 
  - Video player with synchronized subtitles
  - Bilingual transcript display with clickable words
  - Popover translation functionality
  - Same Stimulus controllers (watch-video-activity, popover-translation, main-video-player)

### Follow-up Questions

**Follow-up 1:** How should we determine which words are "basic" and should be filtered out from the vocabulary table? Options:
- Frequency threshold (e.g., only show words that appear 2+ times)?
- Word length (exclude very short words like articles/prepositions)?
- A predefined "common words" list per language?
- Manual tagging by course creator?
- Combination of the above?

**Answer:** A predefined "common words" list per language - awesome. Even better to have multiple lists per user level (A1, A2, B1, B2, C1, C2). C1 spanish speakers don't need you to translate "casa"

**Follow-up 2:** For the vocabulary table UI, should we:
- Show all words at once (could be 100+ words)?
- Add pagination (e.g., 50 words per page)?
- Include sorting options (by frequency, alphabetically)?
- Include a search/filter box to find specific words?

**Answer:** Show all words at once.

**Follow-up 3:** When you say "reachable from the course index," do you mean:
- A button/link on the course show page (courses/:slug) that says "Watch Full Video"?
- Or should it appear in the course listing/index page?

**Answer:** A button/link on the course show page

**Follow-up 4:** Are there any other existing features I should look at:
- Any existing CSV export functionality in the app?
- Course show page layout?
- Any responsive layouts that do side-by-side on desktop and stacked on mobile?

**Answer:** No, only the watch video activity

## Visual Assets

### Files Provided:
No visual files found.

### Visual Insights:
No visual assets provided.

## Requirements Summary

### Functional Requirements

**Core Functionality:**
- Add boolean attribute `show_full_course_player` to Course model
- Create full song/video player page accessible from course show page
- Display entire video with complete bilingual transcript
- Include vocabulary table with all unique words (filtered by language level)
- Enable CSV download of vocabulary table
- Responsive layout: side-by-side on desktop, stacked on mobile

**Video Player:**
- Reuse watch-video-activity infrastructure (Plyr player)
- Show ALL phrases from the course's medium
- Timestamp range: first phrase to last phrase in entire course
- Synchronized bilingual subtitles
- Click word for popover translation (same as watch-video-activity)
- "Show/Hide Translation" toggle
- NO completion message or progress tracking

**Vocabulary Table:**
- List all unique words from entire course (from token_translations)
- Filter out common words based on language-specific word lists per CEFR level (A1-C2)
- Columns: L1 word, L2 translation, frequency count
- Display all words at once (no pagination)
- Downloadable as CSV
- User's language proficiency level determines which words to exclude

**Course Integration:**
- New boolean field: `show_full_course_player` on courses table
- When enabled, show "Watch Full Video" button on course show page
- Route: `/courses/:course_slug/full-player` or similar
- Accessible from course show page via button/link

### Reusability Opportunities
- Components that exist already:
  - `app/views/activities/_watch_video_activity.html.erb` - main template to base the player on
  - Stimulus controllers: watch-video-activity, popover-translation, main-video-player
  - Video player setup with Plyr
  - Bilingual subtitle display logic
  - Popover translation functionality
  - RTL language support
  
- New components needed:
  - Vocabulary table component
  - CSV export functionality
  - Common words filtering system (CEFR level-based)
  - Responsive side-by-side layout for desktop
  - Full course phrase aggregation logic

### Scope Boundaries

**In Scope:**
- Boolean attribute on Course model to enable/disable full player
- Full video player page with complete transcript
- Vocabulary table with CEFR-level filtering
- CSV download of vocabulary
- Responsive layout (desktop: side-by-side, mobile: stacked)
- Reuse existing watch-video-activity infrastructure
- Click-to-translate word popover
- Show/hide translation toggle

**Out of Scope:**
- Progress tracking or completion status
- Activity logging (activity_logs, activity_users)
- Achievement/XP system integration
- Social sharing features
- Commenting on vocabulary or transcript
- Manual word tagging or custom vocabulary lists
- Offline mode
- Audio-only mode
- Spaced repetition integration
- Flashcard generation from vocabulary

### Technical Considerations

**Database:**
- Add migration: `add_column :courses, :show_full_course_player, :boolean, default: false`
- Leverage existing schema:
  - `courses` table (add boolean field)
  - `phrases` table (fetch all phrases for course's medium)
  - `token_translations` table (aggregate unique words)
  - `languages` table (determine RTL/LTR, font sizing)

**Language Level Filtering:**
- Need to implement CEFR common words lists (A1, A2, B1, B2, C1, C2) per language
- Store in: YAML files, database table, or external service
- User proficiency level determines which words to filter (needs user preference or course setting)
- Filter logic: exclude words in lists at or below user's proficiency level

**Responsive Design:**
- Mobile/small screens: Stacked layout (video top, transcript below, vocab table bottom)
- Desktop/large screens: Side-by-side (video + transcript on left/right, vocab table below or as tab)
- Use Tailwind responsive classes (sm:, md:, lg:, xl:)
- Maintain existing RTL support for Arabic/Hebrew

**CSV Export:**
- Generate CSV with headers: "Word (L1)", "Translation (L2)", "Frequency"
- Use Rails CSV library
- Trigger download via controller action or JavaScript
- Filename format: `course-name-vocabulary.csv`

**Routing:**
- Add route: `get 'courses/:slug/full-player', to: 'courses#full_player', as: :course_full_player`
- OR: nested resource under courses
- Update course show page to include conditional button when `show_full_course_player` is true

**Similar Code Patterns to Follow:**
- Follow existing watch-video-activity patterns for player setup
- Use same Stimulus controllers where possible
- Maintain consistent styling with existing activities
- Follow Rails conventions for controller actions and views
- Use existing helpers: `timestamp_to_seconds`, `wrap_tokens_in_spans`
