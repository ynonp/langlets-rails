# Spec Requirements: Realtime Course Creation Progress

## Initial Description
After user approves course creation wizard a CreateSongProgress model is created to orchestrate course creation. Let's build an interactive view for this object that users can visit while course is being created.

1. The view is inspired by the #file:full_player . At the begining we can only show the youtube video. After lyrics are fetched we can show them with relevant timestamps, then after translation is generated we can add that too.

2. Under the video we should show a grayed out button saying "Start Practice", this will be a link to the course when the course will be ready. Grayed out while the course is being generated. If course creation fails this area is used to show the error message

3. You'll need to refactor course creation job to use streaming and use Action cable to stream the lyrics to the user as they are generated. Since extract lyrics returns the lyrics as text it shouldn't be a big change

4. translate also uses text responses so streaming should be handled the same. 

5. token translations, lessons and similar sounds are not relevant to this page

## Requirements Discussion

### First Round Questions

**Q1:** I assume the progress view should use Turbo Streams (already in your tech stack) to update the page in real-time as the course creation proceeds. Is that correct, or would you prefer a different approach like polling?
**Answer:** Yes, use Turbo Streams for real-time updates.

**Q2:** I'm thinking we should create a dedicated controller and route like `/create_song_progresses/:id` for viewing the progress page. Should we follow RESTful conventions with a `CreateSongProgressesController` with a `show` action?
**Answer:** Yes, create a RESTful controller with a show action.

**Q3:** For the video player, I assume we should reuse the same Plyr-based video player setup from the full_player view with the YouTube iframe embed. Is that correct?
**Answer:** Yes, reuse the same video player setup from full_player.

**Q4:** For the lyrics/translation streaming, I'm assuming we should:
- Stream each phrase as it's extracted (with timestamp and text_l1)
- Then stream updated phrases as translations are added (text_l2)
- Use Action Cable with a dedicated channel like `CreateSongProgressChannel`

Is this approach correct, or would you prefer a different streaming strategy?
**Answer:** Yes, this approach is correct. Use Action Cable with a dedicated channel.

**Q5:** For authorization, I assume we should use CanCanCan to ensure only the user who created the CreateSongProgress record can view it. Should we add a `user_id` foreign key to the `create_song_progresses` table if it doesn't exist?
**Answer:** No authorization needed. CreateSongProgress records are shared across users - if multiple users create the same course, we don't want to waste tokens and perform duplicate work. Drop the authorization requirement and allow everyone to watch any progress.

**Q6:** For the "Start Practice" button behavior, I assume:
- It should be grayed out (disabled state) while `ready?` returns false
- Once ready, it becomes clickable and links to the course page
- On error, we replace the button area with a red error message showing the exception

Is this correct?
**Answer:** Yes, this is correct.

**Q7:** I'm thinking the progress view should show status indicators for each major step (extracting lyrics, translating, etc.). Should we add a visual progress indicator (like a progress bar or step indicators) to show which phase is currently running?
**Answer:** Yes, add visual progress indicators. Can put an advancing progress below the "Start Practice" button, or have the button change from gray to blue in a gradient style (left to right) as progress advances.

**Q8:** What should happen if the user navigates away from the progress page and comes back later - should they be able to resume watching the progress if the job is still running, or just see the final state?
**Answer:** On entering the page, show current status from the DB (latest data) and stream new data as it is generated. Parse and save to the DB every chunk as it is returned from the LLM so users can leave the page and return without issues.

### Existing Code to Reference

**Similar Features Identified:**
- Feature: Full Player View - Path: `app/views/full_player/show.html.erb`
- Components to potentially reuse: Video player layout, YouTube iframe embed with Plyr, transcript display structure
- Backend logic to reference: None specifically mentioned

No other similar features identified for Action Cable streaming or progress tracking patterns.

### Follow-up Questions
None required - all requirements are clear.

## Visual Assets

### Files Provided:
No visual assets provided.

### Visual Insights:
Not applicable.

## Requirements Summary

### Functional Requirements

#### Core Functionality
- Create a public progress page for CreateSongProgress records
- Display YouTube video player from the beginning (before any processing)
- Stream and display lyrics as they are extracted (phrase by phrase with timestamps)
- Stream and display translations as they are added to each phrase
- Show a "Start Practice" button that:
  - Starts grayed out/disabled while course is being created
  - Becomes clickable and links to course when ready
  - Shows error message in red if creation fails
- Display visual progress indicator showing current creation phase
- Persist all streamed data to database incrementally
- Allow users to leave and return to see latest progress state

#### Real-time Updates
- Use Turbo Streams for real-time page updates
- Use Action Cable for streaming data from background jobs
- Create dedicated channel (e.g., `CreateSongProgressChannel`)
- Parse and save each chunk from LLM responses to database immediately

#### Data Display
- YouTube video player (reuse full_player approach)
- Lyrics list with timestamps (initially empty, populated as extracted)
- Translation text for each phrase (added after initial extraction)
- Progress indicator (below button or gradient on button from left to right)
- Status of current operation (extracting lyrics, translating, etc.)

### Reusability Opportunities
- **Video Player Component**: Reuse from `app/views/full_player/show.html.erb`
  - YouTube iframe embed structure
  - Plyr video player setup
  - Video thumbnail background
  - Player controls and layout
  
- **Transcript Display**: Similar structure to full_player's transcript section
  - Scrollable phrases container
  - Phrase items with timestamps
  - Bilingual text display (L1 and L2)
  - RTL language support

- **Existing Models**: 
  - CreateSongProgress model with extract_lyrics and translate concerns
  - JSONB data structure in `data` column

### Scope Boundaries

**In Scope:**
- CreateSongProgressesController with show action
- RESTful route: `/create_song_progresses/:id`
- Progress view page inspired by full_player
- YouTube video player display
- Real-time streaming of lyrics extraction
- Real-time streaming of translation
- Incremental database updates (save each chunk)
- Visual progress indicator
- "Start Practice" button with three states (disabled/enabled/error)
- Action Cable channel for streaming
- Refactoring extract_lyrics to support streaming
- Refactoring translate to support streaming
- Resume capability (load from DB + stream new updates)

**Out of Scope:**
- Token translations display (not relevant to this page)
- Lessons display (not relevant to this page)
- Similar sounds display (not relevant to this page)
- User authorization (CreateSongProgress is shared across users)
- Mobile-specific optimizations (can be future enhancement)
- Edit/delete functionality for progress records
- Manual retry of failed steps
- Background job monitoring dashboard

### Technical Considerations

#### Integration Points
- Action Cable for WebSocket connections
- Turbo Streams for real-time DOM updates
- CreateSongProgress model and concerns (ExtractLyrics, Translate)
- YouTube iframe API (via existing full_player pattern)
- Good Job background processing
- JSONB data column for flexible phrase storage

#### Existing System Constraints
- CreateSongProgress uses unique index on (youtubeurl, clip_language, translation_language)
- Shared progress records across users (no user ownership)
- JSONB `data` column structure: `{"phrases": [{"id": "...", "text_l1": "...", "timestamp": "...", "text_l2": "..."}]}`
- LLM streaming responses from Gemini (extract_lyrics and translate)
- Rails 8.0 with Hotwire stack

#### Technology Preferences Stated
- Use Turbo Streams (not polling)
- Use Action Cable for streaming
- Reuse full_player view patterns
- RESTful controller conventions
- Parse and save to DB incrementally (chunk by chunk)
- Gradient button style or progress bar below button

#### Similar Code Patterns to Follow
- Full player view structure: `app/views/full_player/show.html.erb`
- Video player setup with YouTube iframe and Plyr
- Transcript display with phrases and timestamps
- RTL language support patterns
- Stimulus controllers for video interaction

#### Database Schema
- Table: `create_song_progresses`
- Columns: id, youtubeurl, clip_language, translation_language, step, data (jsonb), lyrics (text), created_at, updated_at
- Unique index: (youtubeurl, clip_language, translation_language)
- No user_id column (shared across users)

#### Streaming Implementation Strategy
1. Modify `extract_lyrics` to yield/stream each phrase as parsed
2. Modify `translate` to yield/stream each translation as received
3. Create Action Cable channel to broadcast updates
4. Save to database after each chunk/phrase
5. Use Turbo Streams to append/update phrases in view
6. Update progress indicator via Turbo Streams
7. Update button state via Turbo Streams when complete

## Streaming Architecture & Approach

### How Streaming Works

#### Extract Lyrics Phase
```ruby
# Pseudocode for extract_lyrics streaming
def extract_lyrics_with_streaming
  # Stream from LLM
  llm_stream_response do |chunk|
    phrase = parse_chunk(chunk)  # Parse the streamed chunk
    
    # Save to DB immediately (incremental)
    self.data ||= {}
    self.data['phrases'] ||= []
    self.data['phrases'] << phrase
    save!
    
    # Broadcast to Action Cable for real-time UI update
    CreateSongProgressChannel.broadcast_to(
      self,
      action: 'phrase_added',
      phrase: phrase
    )
  end
end
```

**Save frequency**: After each phrase/chunk is received and parsed  
**What to save**: Each individual phrase with `id`, `text_l1`, and `timestamp` appended to JSONB `data` column  
**Broadcast**: After saving each phrase, broadcast via Action Cable to update view in real-time

#### Translation Phase
```ruby
# Pseudocode for translate streaming
def translate_with_streaming
  llm_stream_response do |chunk|
    translation = parse_translation_chunk(chunk)
    
    # Update existing phrase in DB (incremental)
    phrase = self.data['phrases'].find { |p| p['id'] == translation['id'] }
    phrase['text_l2'] = translation['text_l2']
    save!
    
    # Broadcast update to Action Cable
    CreateSongProgressChannel.broadcast_to(
      self,
      action: 'phrase_updated',
      phrase: phrase
    )
  end
end
```

**Save frequency**: After each translation chunk is received  
**What to save**: Update the existing phrase in JSONB `data` by adding `text_l2`  
**Broadcast**: After saving each translation, broadcast to update that phrase in view

### Database Save Strategy

**Incremental saves (NOT just end results):**
- ✅ Save streamed data incrementally (each chunk/phrase)
- ✅ Update `create_song_progresses.data` JSONB after each phrase
- ✅ Users can refresh/return and see latest progress from DB
- ❌ Don't wait for complete results before saving

### Benefits of Incremental Approach
1. **Resume capability**: Users can leave and return without losing progress
2. **Fault tolerance**: Partial results preserved even if job fails mid-stream
3. **Real-time feel**: Saved + broadcast immediately makes updates feel instant
4. **Database as source of truth**: DB always reflects current state of generation

### Multiple User Scenario

**Key insight**: CreateSongProgress records are shared based on unique index (youtubeurl + clip_language + translation_language)

**When second user requests same YouTube URL:**
1. User A starts course creation → CreateSongProgress created, background job runs
2. User B requests same URL while A's job is running
3. User B gets redirected to **same** CreateSongProgress record (due to unique index)
4. Both users watch the **same** progress page
5. **Only one background job runs** (single writer)
6. Both users receive updates via Action Cable (multiple viewers)

**Implications:**
- ✅ No race conditions - only one job writes to record
- ✅ No data corruption - single writer pattern
- ✅ Multiple viewers supported - many users watch via Action Cable subscription
- ✅ Token/cost savings - duplicate work avoided (design goal)

### Performance Analysis

**Typical data profile:**
- Songs: 20-50 phrases on average
- Total writes per course: ~40-100 UPDATEs (extract + translate phases)
- Write duration: Spread over 2-6 minutes (trivial DB load)
- Data size per update: ~100-200 bytes per phrase

**Performance bottlenecks:**

| Scenario | Impact | Breaking Point |
|----------|--------|----------------|
| Sequential course creations | ✅ Smooth | Never breaks |
| 5-10 concurrent (different URLs) | ✅ Fine | DB handles easily |
| 50+ concurrent (different URLs) | 🟡 Slower | Connection pool strain |
| 100+ viewers on same progress | 🟡 Minor lag | Action Cable/Redis load |
| Songs with >500 phrases | 🟡 Slower saves | Rare edge case |

**Verdict**: Performance is not a concern because:
- Single writer per progress record (no conflicts)
- 40-100 UPDATEs over several minutes (negligible DB load)
- Multiple viewers just subscribe to same Action Cable channel
- Shared records reduce duplicate work (design goal achieved)

#### Error Handling
- Display error message in button area on failure
- Preserve partial progress in database
- Allow viewing partial results even if later steps fail
