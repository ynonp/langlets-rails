# Langlets - Language Learning Platform Architecture

## Project Overview

**Langlets** is a Rails-based language learning platform that creates interactive activities from multimedia content (primarily YouTube videos) with synchronized bilingual text, word-level translations, and various learning exercises. The platform is branded as "MúsicaLingo" and focuses on song-based language learning.

## Technology Stack

- **Framework**: Ruby on Rails 8.0
- **Database**: PostgreSQL with JSONB support
- **File Storage**: Active Storage (local/cloud)
- **Frontend**: Rails views with JavaScript
- **Background Jobs**: Rails queue system
- **Package Management**: Bun (JavaScript), Bundler (Ruby)

## Core Architecture

### Translation localization

Content has one shared L1 skeleton and any number of sparse L2 translations:

- `media` is unique on `(url, language_id)` and represents one transcription of
  a video in its spoken language. Adding an L2 never creates another medium or
  reruns transcription.
- `phrases` stores only L1 text. `phrase_translations` is unique on
  `(phrase_id, language_id)` and stores each localized phrase text.
- `phrase_tokens` stores an L1 span, timestamps, audio, questions, and similar
  sounds once. `token_translations` is unique on
  `(phrase_token_id, language_id)` and stores the L2 label and L2 indexes.
- Activities join spans through `activity_phrase_tokens`, so the sampled course
  skeleton and user progress are shared by every site language.
- `courses` is unique per published `(youtube_video_id, language_id)`.
  `course_translations` carries per-L2 name and readiness; `lesson_translations`
  carries localized lesson names.
- `Current.translation_language` is set from the request subdomain (`he` on
  `he.langlets.app`, English on the main domain). Phrase, token, course, and
  lesson localized associations use this request context. The existing `lang`
  parameter remains the independent L1/library filter.
- Sessions use a parent-domain cookie (`domain: :all`, `tld_length: 2`) so login
  is shared across localized subdomains.
- Saved vocabulary uses `phrase_token_users`. Each row pins `language_id` when
  the span is saved; vocabulary and review resolve that exact translation even
  when the current subdomain is different. Saving the span again updates the
  language rather than creating a second entry.

The import pipeline is also split. `CreateSongProgress` is unique on
`(youtubeurl, clip_language)`. Neutral transcription/timing/segmentation work
runs once, while `add_translation(language)` stores language-keyed output under
`data["translations"]`. A translation-only import costs one credit and attaches
phrase, token, lesson, and course translations without deleting lessons,
activities, progress, or vocabulary.

### Domain Models

#### 1. **Language** (`languages`)
- **Purpose**: Define source and target languages for translations
- **Key Features**:
  - ISO language codes (`iso_name`)
  - English and native names
  - RTL (Right-to-Left) language support
  - Pronunciation variant handling
  - **Default Script Association**: Each language has a default writing system/script
- **Relationships**: 
  - Referenced by phrases as L1 (source) and L2 (target) languages
  - Belongs to Script (as default_script)
  - One-to-many with MultiScriptTexts

#### 2. **Script** (`scripts`)
- **Purpose**: Define writing systems/scripts for languages (e.g., Latin, Arabic, Cyrillic)
- **Key Features**:
  - Unique script code identifier (`code`)
  - Human-readable script name (`name`)
  - Indexed code field for efficient lookups
- **Relationships**: 
  - One-to-many with Languages (as default_script)
  - One-to-many with ScriptVariants

#### 3. **MultiScriptText** (`multi_script_texts`)
- **Purpose**: Store text content in multiple writing systems/scripts for the same language
- **Key Features**:
  - Language association for context
  - Audio status tracking (not_required, audio_required, audio_ready)
  - Nested attributes support for script variants
  - Automatic content caching and invalidation
  - **Helper Methods**:
    - `create_with_default_content`: Creates text with default script content
    - `to_s(script)`: Returns content for specific script or default
    - `add_variant!`: Adds new script variant with cache clearing
    - `character_range`: Calculates character ranges for word tokenization
- **Relationships**: 
  - Belongs to Language
  - One-to-many with ScriptVariants
  - Referenced by Phrases as text_l1 and text_l2

#### 4. **ScriptVariant** (`script_variants`)
- **Purpose**: Store specific script representations of multi-script text
- **Key Features**:
  - Text content in specific script (`content`)
  - Unique constraint on multi_script_text + script combination
  - Automatic parent cache invalidation on changes
  - Content validation (non-null)
- **Relationships**: 
  - Belongs to MultiScriptText
  - Belongs to Script

#### 5. **Medium** (`media`)
- **Purpose**: Store one video transcription in its spoken language.
- **Identity**: `(url, language_id)`. L2 data is stored below phrases, so a new
  target language reuses this row and its L1 phrases.
- **Relationships**: Belongs to the clip `Language`; has many Lessons and Phrases.

#### 6. **Course** (`courses`)
- **Purpose**: Group lessons into structured playlists
- **Key Features**:
  - Hierarchical organization with slugs. **`slug` is the identifier** — uniquely indexed, and what `FriendlyName#to_param` returns.
  - **`name` is NOT unique.** It was, back when one admin typed every title. Two users importing different videos that share a title must not collide on a display field.
  - Main media URL for course overview
  - **Identity in the Library is `(youtube_video_id, language_id)`**, enforced for published courses by a partial unique index. L2 publish/readiness and name live in `course_translations`.
  - `main_media_url` is free text and unreliable for comparison (`youtu.be/X` vs `watch?v=X&t=9`) — always compare `youtube_video_id`, via `Youtube::Url`.
  - Course thumbnails use the stored `youtube_video_id` rather than parsing `main_media_url`; a `Youtube::Url` fallback supports legacy rows where the stored ID is blank.
  - **User ownership**: All courses belong to a specific user (creator). Note this is *creator*, not *owner* — under dedupe, a course is a shared community artifact other users have enrollments and progress against, which is why `Ability` still grants `:manage, Course` to admins only.
- **Relationships**:
  - One-to-many with Lessons
  - Belongs to the clip Language and creator User; has many CourseTranslations
  - Many-to-many with Playlists (through CoursesPlaylist)
  - One-to-many with Enrollments

#### 7. **Lesson** (`lessons`)
- **Purpose**: Define specific learning segments from media content
- **Key Features**:
  - Unique slugs for routing
  - Timestamp ranges (`start_timestamp`, `end_timestamp`)
  - Ordered sequence within courses (integer order field)
  - Descriptive names
  - **User ownership**: All lessons belong to a specific user (creator)
- **Relationships**: 
  - Belongs to Course, Medium, and User
  - One-to-many with Activities

#### 8. **Phrase** (`phrases`)
- **Purpose**: Store synchronized bilingual text segments with timestamps
- **Key Features**:
  - Stores L1 text; localized L2 text is normalized into PhraseTranslations
  - Media synchronization timestamps
  - L1 language reference (`l1_id`)
  - **Audio Attachment**: `has_one_attached :l1_audio` for pronunciation audio files
  - **Helper Methods**:
    - `text_l1_content`/`text_l2_content`: Get default script content
    - `text_l1_for_script`/`text_l2_for_script`: Get content for specific script
    - `with_calculated_end_timestamps`: Calculate phrase durations
- **Relationships**: 
  - Belongs to Medium and two Languages
  - Belongs to two MultiScriptText objects (text_l1, text_l2)
  - One-to-many with PhraseTranslations and PhraseTokens
  - Many-to-many with Activities (through ActivityPhrase)

#### 9. **PhraseToken / TokenTranslation**
- `phrase_tokens` is the language-neutral L1 span, unique by phrase, L1 range,
  and index type. It owns timestamps, audio, questions, and L1 similar sounds.
- `token_translations` belongs to a PhraseToken and Language and owns the L2
  translation plus L2 indexes. It is unique per `(phrase_token_id, language_id)`.
- Activities and saved vocabulary reference PhraseToken, never a localized row.

#### 10. **User** (`users`)
- **Purpose**: User authentication and account management
- **Key Features**:
  - Email-based authentication (unique constraint)
  - Encrypted password storage using Devise
  - Password reset functionality with tokens and timestamps
  - Remember me functionality for persistent sessions
  - Email confirmation system (confirmable)
  - OAuth provider and UID fields for third-party authentication
- **Authentication System**: Powered by Devise gem with modules:
  - **Database Authenticatable**: Standard email/password authentication
  - **Recoverable**: Password reset via email tokens
  - **Rememberable**: Persistent login sessions
  - **Confirmable**: Email address verification for new accounts
  - **OAuth Integration**: Provider and UID fields for social authentication
- **Security Features**:
  - Reset password tokens with expiration timestamps (unique constraint)
  - Confirmation tokens for email verification
  - Unconfirmed email handling for email changes
  - Indexed email field for efficient lookups
- **User Interface**: Modern dark-themed login/registration forms with:
  - Social authentication buttons (Apple, Google, GitHub) rendered from the shared `devise/shared/_social_buttons` partial
  - Responsive design with Tailwind CSS
  - Password visibility controls
  - Terms and privacy policy acceptance
- **Relationships**: 
  - Many-to-many with Activities (through ActivityUser) for progress tracking
  - Many-to-many with Lessons (through LessonUser) for completion tracking
  - **Owner relationships**: One-to-many with Courses, Lessons, and Activities (content ownership)

### Activity System (Single Table Inheritance)

#### 11. **Activity** (`activities`)
- **Purpose**: Base class for interactive learning exercises
- **Architecture**: Uses STI (Single Table Inheritance) with `type` column
- **Key Features**:
  - Ordered sequence within lessons (integer order field)
  - Text headers and subheaders for UI (`text_header`, `text_subheader`)
  - Video parameter generation
  - Dictionary creation functionality
  - **User ownership**: All activities belong to a specific user (creator)
- **Relationships**: 
  - Belongs to Lesson and User
  - Many-to-many with Phrases (through ActivityPhrase)
  - Many-to-many with TokenTranslations (through ActivityTokenTranslation)

#### Activity Types:
- **WatchVideoActivity**: Video viewing with synchronized subtitles
- **FlashcardActivity**: Missing-word multiple-choice practice. It uses the standard compact question/progress header above a frameless exercise area, with a centered L1 sentence, an L2 gloss anchored below the blank, and a 2×2 grid of contrasting answer tiles.
- **MatchPhrasesActivity**: Phrase-to-translation matching exercises. Each question uses a compact progress header, an audio-enabled L1 phrase card, an L1-to-L2 language direction label, and a vertical set of L2 answer options.
- **SortPhrasesActivity**: Chronological phrase ordering in a compact, frameless exercise layout. The activity presents its instruction and media hint before a draggable list with visible grip handles, followed by the check action and inline result or completion feedback. Its visual states are implemented with Tailwind utilities.
- **LanguageAlignmentActivity**: Word-level alignment exercises
- **SpeakActivity**: Pronunciation practice
- **ListenActivity**: Audio comprehension with token identification
- **FindAnswerActivity**: Question-answer exercises

#### 12. **Playlist** (`playlists`)
- **Purpose**: Define structured curriculum pathways with YouTube-like browsing experience (formerly `LearningPath` / `learning_paths`; old `/learning_paths/:id` URLs redirect to `/playlists/:id`)
- **Ownership** (`user_id`, optional):
  - `user_id` nil = **system playlist**: curated by admins, shown to everyone on the home page, listed in the sitemap. Only admins can modify or delete them.
  - `user_id` set = **personal playlist**: belongs to that user. Any signed-in user can create playlists and add *any* course to them (via the "+" popup on a course page); only the owner (or an admin) can view, modify, or delete them. Created via `CoursePlaylistsController`; admins creating playlists there produce system playlists.
  - Home page shows published system playlists plus the current user's own (`Playlist.visible_to(user)`); `PlaylistsController#show` 404s personal playlists for anyone but their owner/admin. Authorization lives in `Ability` (`can [:update, :destroy], Playlist, user_id: user.id`; admins `can :manage, Playlist`).
- **Key Features**:
  - Named learning sequences with descriptions
  - Difficulty level classification (integer)
  - Publication status (boolean)
  - **YouTube-style View**: Dedicated show page with search, tag filtering, and grid layout
  - **Ajax Search**: Real-time course filtering by name
  - **Tag-based Filtering**: Dynamic tag system for course categorization
- **Relationships**: Many-to-many with Courses (through CoursesPlaylist); optionally belongs to a User

#### 13. **Tag** (`tags`)
- **Purpose**: Categorization system for courses within playlists
- **Key Features**:
  - Unique tag names (e.g., "Music", "French", "Beginner")
  - Used for filtering courses in playlist views
  - Supports YouTube-like tag filtering interface
- **Relationships**: Many-to-many with Courses (through CourseTag)

#### 14. **CourseTag** (`course_tags`)
- **Purpose**: Join table linking courses to their categorization tags
- **Key Features**:
  - Unique constraint on course + tag combination
  - Enables tag-based filtering and categorization
- **Relationships**: Links Courses to Tags

#### 15. **CoursesPlaylist** (`courses_playlists`)
- **Purpose**: Join table linking courses to playlists
- **Key Features**:
  - Ordered sequence within playlists (integer order field)
  - Timestamps for tracking
- **Relationships**: Links Courses to Playlists

### Join Tables

#### 16. **ActivityPhrase** (`activity_phrases`)
- Links activities to their associated phrases
- Enables many-to-many relationship between Activities and Phrases
- Includes timestamps for creation/update tracking

#### 17. **ActivityTokenTranslation** (`activity_token_translations`)
- Links activities to specific token translations for word-level exercises
- Enables many-to-many relationship between Activities and TokenTranslations
- Includes compound index for efficient querying
- Includes timestamps for creation/update tracking

### User Progress Tracking

#### 18. **ActivityUser** (`activity_users`)
- **Purpose**: Track user progress through individual activities
- **Key Features**:
  - Unique constraint on activity + user combination
  - Timestamps for completion tracking
  - Indexed on both activity_id and user_id for efficient queries
- **Relationships**: Links Users to Activities for progress monitoring

#### 19. **LessonUser** (`lesson_users`)
- **Purpose**: Track user progress through lessons
- **Key Features**:
  - Unique constraint on lesson + user combination
  - Timestamps for completion tracking
  - Lesson navigation behavior: clicking the in-lesson "Next Lesson" control sends a background progress update that marks the current lesson as completed for authenticated users
  - Indexed on both lesson_id and user_id for efficient queries
- **Relationships**: Links Users to Lessons for course progression
- **Side effect**: creating a LessonUser touches the user's `Enrollment` for that course (`last_practiced_at`), and *creates* the enrollment if there isn't one — so reaching a lesson via a shared link puts the course on the user's Home.

### Credits

Video imports cost credits. New accounts get `User::SIGNUP_CREDITS` (3). **There is no way to buy more yet** — StoreKit is deferred, so when a user runs out, that's the end.

#### **Credits::Ledger** (`app/services/credits/ledger.rb`)
The only supported way to move credits. Two stores, written together in one transaction:
- `users.credit_balance` — the authority. Fast to read (Home renders it on every request) and safely lockable. A CHECK constraint enforces `>= 0`.
- `credit_ledger_entries` — append-only audit (`CreditLedgerEntry#readonly?` is true once persisted, and destroy raises). This is what makes refunds and support questions answerable.

Three rules, each load-bearing:
1. **Never read-modify-write the balance.** `Ledger` spends with `UPDATE ... WHERE credit_balance >= ?`, so Postgres evaluates the guard under the row lock and exactly one of two concurrent spends wins. `user.credit_balance -= 1; user.save!` is a lost update. There's a real two-thread test for this (`test/services/credits/ledger_test.rb`).
2. **Every call passes an `idempotency_key`** (`"import:42"`, `"refund:42"`, `"signup:7"`), uniquely indexed. GoodJob retries jobs; without the key a retry double-charges. A replay returns the original entry and moves nothing.
3. **The ledger does not refresh the caller's in-memory user** — it moves the balance with an UPDATE. Call `user.reload` if you need the new value. (`User#grant_signup_credits` does exactly this, which is why `User.create!(...).credit_balance` correctly reads 3.)

`User.has_many :credit_ledger_entries, dependent: :delete_all` — **not** `:destroy`, which would trip the immutability guard and make account deletion impossible.

#### **Enrollment** (`enrollments`)
- **Purpose**: "this course is on my Home". Unique on `(user_id, course_id)`.
- **Why it exists**: enrollment could not be inferred. A created course is `courses.user_id`, a started course is implied by `lesson_users` — but the Library's "+ Learn this" adds a course to Home *before* any lesson is completed, so it needs a record of its own.
- `source`: `imported` (spent a credit), `library` (added from the catalog), `playlist`.
- `last_practiced_at` drives Home's "Keep it going" ordering; `recently_practiced` sorts NULLS LAST so never-opened courses fall below in-progress ones.

### Workflow Management

#### **ImportRequest** (`import_requests`) — the Queue

A user's request to turn a video into a course. There are three distinct things in the import flow and it's worth being precise about which is which:

| | Scope | Keyed on |
|---|---|---|
| `CreateSongProgress` | the **shared neutral pipeline cache** — no `user_id` | `(youtubeurl, clip_language)` |
| `Course` | the **shared output** — one per video+L1 | `(youtube_video_id, language_id)` |
| `ImportRequest` | the **per-user intent** | `(user_id, youtube_video_id, clip_language, translation_language)` while active |

> **One `CreateSongProgress` → many language-keyed translations and `ImportRequest`s → one shared `Course`.**

Two users importing the same video deliberately share one pipeline and one course; the AI work happens once. That's why per-user state (status, credit linkage, retry, push idempotency) can't live on either of the shared records.

- `idx_import_requests_active_dedupe` is a **partial** unique index over active (queued/importing) rows, so a double-tapped Import button is a database impossibility, while a failed import can still be retried.
- `progress_percent` is **written forward** by `CreateSongProgress#sync_import_requests_progress`, never computed on read — `data` is a multi-megabyte jsonb blob and the Queue polls.

#### **Imports::Create** (`app/services/imports/create.rb`)
The single entry point for the Add sheet, the share extension and the API. Order is deliberate: **the video is checked before a credit moves**, so a private or deleted video costs nothing (`Youtube::Oembed` doubles as the availability check). Four outcomes:
- `:created` — charged 1 credit, queued the pipeline.
- `:deduped` — already published; enrolled, free.
- `:joined` — **someone else is importing it right now**; rides along on their course, free. Without this, both users create a pending course and whichever publishes second violates `idx_courses_published_video_pair`, failing an import the user paid for.
- `:already_queued` — this user already asked; no second charge.

The job is enqueued **inside** the transaction — good_job is Postgres-backed, so the job row commits atomically with the request. Enqueuing after commit would leave a charged request nothing ever picks up.

Users are **not** enrolled at import time: the course is `pending` and has no lessons, so Home would show something unopenable. `CreateCourseJob` enrolls everyone attached once it publishes.

#### Course-ready push notifications

Once `CreateCourseJob` publishes a course, it marks every attached `ImportRequest` ready, enrolls that request's user, and enqueues one `SendImportReadyPushJob` per request. Push delivery is deliberately outside the course-building transaction: an APNs outage must not turn a successfully built course into a failed import. `ImportRequest#notified_at` makes delivery idempotent, and a user with no registered device is stamped as handled because email remains the fallback.

The iOS app registers APNs tokens through the `push` Hotwire Native bridge and `App::DeviceTokensController`; tokens are owned by a user and an installation token can move to the currently signed-in account. APNs sandbox and production tokens are stored separately by environment. Apple responses that identify dead tokens invalidate the row without deleting its diagnostic history, while transient failures leave it active.

`Push::CourseReadyNotification` includes the published course slug in the APNs custom payload. Notification taps are handled on both iOS paths: `UNUserNotificationCenterDelegate` for a running app and `UIScene.ConnectionOptions.notificationResponse` for a cold launch. Both reset the Home navigator to `/app?just_imported=<slug>`. `App::HomeController` only resolves that slug through the signed-in user's published enrollments, then renders the newly created course as the **JUST IMPORTED** hero whose **Start Course** button enters the standard course experience. An invalid or unauthorized slug safely falls back to ordinary Home.

#### **CreateCourseJob** — charge lifecycle
`good_job.retry_on_unhandled_error` defaults to **false** and this app doesn't override it, so **a raise here is final**. That's what makes refunding in the rescue correct rather than a balance yo-yo. Do not add `retry_on` naively: the rescue sets the course to `error`, and `Course#process` only claims a `pending` course, so a second attempt would silently do nothing.

Only whoever actually paid is refunded — `:joined` riders were never charged. The `"refund:<id>"` idempotency key means a manual re-run can't mint credits.

#### 20. **CreateSongProgress** (`create_song_progresses`)
- **Purpose**: Track async content creation pipeline
- **Key Features**:
  - YouTube URL processing (`youtubeurl`)
  - Multi-step workflow management (integer step field)
  - Source and target language tracking (`clip_language`, `translation_language`)
  - JSONB data storage for flexible progress tracking
  - Unique constraint on URL + source language + target language combination
  - Compound index for efficient querying

## Active Storage Integration

The platform uses **Active Storage** for file management:

- **active_storage_blobs**: Core file metadata (filename, content_type, size, checksum)
- **active_storage_attachments**: Polymorphic join table linking files to any model
- **active_storage_variant_records**: Image/file processing variants

**Storage Configuration**:
- Development: Local disk storage
- Production: Cloud storage (S3/GCS/Azure) support configured

### Audio File Integration

The platform integrates audio files using Active Storage attachments on two core models:

#### Phrase Audio
- **Field**: `Phrase#l1_audio` (has_one_attached)
- **Purpose**: Full phrase pronunciation in source language (L1)
- **Format**: WAV files generated via Azure Text-to-Speech

#### Token Audio  
- **Field**: `TokenTranslation#l1_audio` (has_one_attached)
- **Purpose**: Individual word/token pronunciation in source language (L1)
- **Format**: WAV files generated via Azure Text-to-Speech

## Azure Text-to-Speech Integration

The platform uses **Azure Cognitive Services TTS** for generating pronunciation audio:

### Service Configuration (`AzureTextToSpeechService`)
- **Output Format**: `raw-16khz-16bit-mono-pcm` → converted to WAV
- **Audio Specs**: 16kHz sample rate, 16-bit depth, mono channel
- **Workflow**: Raw PCM → WAV conversion → Base64 encoding → Active Storage attachment

### Language Support
- **English**: `en-US-AriaNeural`
- **Spanish**: `es-ES-ElviraNeural` 
- **French**: `fr-FR-DeniseNeural`
- **German**: `de-DE-KatjaNeural`
- **Arabic**: `ar-JO-TaimNeural` (includes Palestinian Arabic fallback)
- **Hebrew**: `he-IL-AvriNeural`

### Audio Generation Process
1. **Text Input**: Phrase or token text in source language
2. **SSML Generation**: Structured markup with language/voice selection
3. **Azure TTS API**: Raw PCM audio generation
4. **WAV Conversion**: PCM → WAV using WaveFile gem
5. **Base64 Encoding**: For secure transmission
6. **Active Storage Attachment**: Audio file attachment to model record

### Audio Attachment Workflow
```ruby
# From Ai::CreateSong#attach_audio_to_record
def attach_audio_to_record(record, base64_audio_data, filename)
  decoded_audio = Base64.decode64(base64_audio_data)
  audio_io = StringIO.new(decoded_audio)
  
  record.l1_audio.attach(
    io: audio_io,
    filename: filename,
    content_type: 'audio/wav'
  )
end
```

This integration enables:
- **Pronunciation Practice**: Accurate native speaker models
- **Listening Comprehension**: High-quality audio for word identification
- **Accessibility**: Audio support for visual learners
- **Offline Capability**: Downloaded audio files for offline learning

## Data Relationships

```
# Content Hierarchy
Course (1) ──→ (many) Lesson
Lesson (many) ──→ (1) Medium
Lesson (1) ──→ (many) Activity

# Multi-Script Text System
Language (1) ──→ (many) MultiScriptText
Language (many) ──→ (1) Script (as default_script)
Script (1) ──→ (many) ScriptVariant
Script (1) ──→ (many) Language (as default_script)
MultiScriptText (1) ──→ (many) ScriptVariant
ScriptVariant (many) ──→ (1) Script
ScriptVariant (many) ──→ (1) MultiScriptText

# Language & Content
Language (1) ──→ (many) Phrase (as L1)
Language (1) ──→ (many) Phrase (as L2)
Language (1) ──→ (many) Course
Medium (1) ──→ (many) Phrase
Phrase (many) ──→ (1) MultiScriptText (as text_l1)
Phrase (many) ──→ (1) MultiScriptText (as text_l2)

# Token-level Translation
Phrase (1) ──→ (many) TokenTranslation
Phrase (many) ←──→ (many) Activity (through ActivityPhrase)
Activity (many) ←──→ (many) TokenTranslation (through ActivityTokenTranslation)

# Playlist System
Playlist (many) ←──→ (many) Course (through CoursesPlaylist)
Course (many) ←──→ (many) Tag (through CourseTag)

# User Management & Ownership (Devise)
User (1) ──→ (many) Course # Content ownership
User (1) ──→ (many) Playlist # Personal playlists (user_id nil = system playlist)
User (1) ──→ (many) Lesson # Content ownership
User (1) ──→ (many) Activity # Content ownership
User (many) ←──→ (many) Activity (through ActivityUser) # Progress tracking
User (many) ←──→ (many) Lesson (through LessonUser) # Progress tracking

# Audio Attachments via Active Storage
Phrase (1) ──→ (1) Audio File (l1_audio)
TokenTranslation (1) ──→ (1) Audio File (l1_audio)

# Active Storage Infrastructure
Any Model ←──→ Active Storage Blobs (polymorphic attachments)
Active Storage Blobs (1) ──→ (many) Active Storage Variant Records
```

## Key Features & Capabilities

### User Authentication & Management
- **Devise Integration**: Full-featured authentication system with email/password
- **Account Security**: Password reset, email confirmation, and session management
- **Modern UI/UX**: Dark-themed responsive login and registration forms
- **Progress Tracking**: Individual user progress through lessons and activities
- **Social Authentication**: OmniAuth sign-in with Google, GitHub and Apple (`omniauth-apple` uses `nonce: :local` + `provider_ignores_state` because Apple returns its callback as a cross-site form POST that drops the Lax session cookie). Both the Apple callback and OmniAuth failure action skip Rails' CSRF check because failures retain Apple's cross-site POST origin; Apple response integrity is instead checked by the encrypted nonce cookie and ID-token verification. The native iOS app has dedicated flows: Google via the Google Sign-In SDK posting a serverAuthCode to `users/auth/native_google`, and Apple via AuthenticationServices posting the identity token to `users/auth/native_apple`, where the JWT is verified against Apple's JWKS (issuer, audience = app bundle id, expiry)
- **Privacy Compliance**: Terms of service and privacy policy integration

### User Authentication UI Design

The platform implements a modern, accessible authentication system with the following design patterns:

#### Login Form (`app/views/devise/sessions/new.html.erb`)
- **Dark Theme**: Slate-900 background with contrasting white text
- **Responsive Layout**: Full-screen centered design that adapts to mobile
- **Form Elements**:
  - Email/username input with autofocus and autocomplete
  - Password field with integrated "FORGOT?" link
  - Primary "LOG IN" button with hover states
- **Visual Hierarchy**: Clear typography with proper spacing and contrast ratios
- **Interactive Elements**: Smooth transitions and hover effects throughout

#### UI Components & Patterns
- **Navigation Elements**: 
  - Close button (top-left) for modal-style interaction
  - Sign-up link (top-right) for account creation
- **Social Authentication**: 
  - Apple, Google and GitHub buttons with proper branding (shared partial `devise/shared/_social_buttons`)
  - SVG icons with consistent styling
  - Grid layout for multiple providers
- **Form Validation**: 
  - Built-in HTML5 validation with Devise backend
  - Error handling and user feedback
- **Legal Compliance**:
  - Terms of Service and Privacy Policy links

#### Accessibility Features
- **Keyboard Navigation**: Full tab-order support
- **Screen Reader Support**: Proper ARIA labels and semantic HTML
- **Color Contrast**: WCAG-compliant color schemes
- **Focus Management**: Visible focus indicators and logical flow

#### Technology Stack
- **CSS Framework**: Tailwind CSS for utility-first styling
- **Icons**: Heroicons and custom brand SVGs
- **Typography**: System font stack with proper scaling
- **Responsive Design**: Mobile-first approach with breakpoint optimization

### Mobile App (Hotwire Native iOS)

The iOS app is a Hotwire Native wrapper around the Rails web application. It uses WKWebView with shared cookies via `WKWebsiteDataStore.default()`, allowing seamless session sharing with Safari.

#### Path Configuration (which screens are modals)

`SceneDelegate` loads path configuration from two sources, **in order**:
1. `.file(...)` — the copy bundled at `langlets-ios/langlets/langlets/Configuration/path_configuration.json`. Offline fallback and first-launch seed.
2. `.server(...)` — `GET /configurations/ios_v1.json`, served by `ConfigurationsController` from `config/hotwire/ios_path_configuration.json`. **This one wins at runtime**, so routing rules can change with a Rails deploy instead of an App Store release.

> **Rule order is the opposite of what it looks like.** Hotwire Native merges the properties of *every* rule whose pattern matches, with **later rules winning** (`PathConfiguration#properties`: `properties.merge(rule.properties) { _, new in new }`), and patterns are unanchored regexes so `.*` matches everything. The catch-all therefore belongs **first**, as the baseline that later, more specific rules override.
>
> It used to sit last, which silently defeated every modal rule in the file — auth, lessons and `/new` were all presenting as plain pushes no matter what they asked for. Fixed in Phase 3; keep the most specific rules at the bottom.

Two more things to know before touching this:
- `ConfigurationsController` inherits `ActionController::API`, *not* `ApplicationController`. Under `ApplicationController`, `require_authentication_for_native_app` would answer a signed-out native request with a redirect to the sign-in page and the app would parse that HTML as path configuration.
- The bundled and served copies must stay identical in the repo; `test/controllers/configurations_controller_test.rb` enforces it. Edit both together.

#### The app screens (`/app`)

Home, Library, Queue, Add-a-video and Credits live under `App::BaseController` (`app/views/app/**`, `layouts/app.html.erb`). They are **native-only** — `require_native_app` redirects browsers to `root_path` — with a `?native=1` session escape hatch (non-production) so the CSS can be worked on outside the simulator.

The **only** place the web knows about them is one line in `CoursesController#index`: signed-in native users are redirected to `app_home_path`. Both this redirect and `App::BaseController#require_native_app` use the single `native_app?` predicate, which recognizes the stable `LangletsNative` user-agent marker. There is no version-specific native routing. Deciding the destination server-side rather than changing the app's start location means it can change without an App Store release.

The iOS app uses `AppTabBarController`, a native `UITabBarController` with one Hotwire `Navigator` per Home, Library and Queue tab. Navigators load lazily on first selection, then retain their webview and navigation stack, so later tab switches are immediate and preserve scroll/page state. Links to another tab root are intercepted by `SceneDelegate` and select that tab instead of pushing a duplicate root onto the current stack. The native tab bar starts hidden and is revealed only after the authenticated app layout reports its Queue badge through the bridge; entering authentication or completing sign-out hides it again, so login screens never expose app navigation. Authentication and language changes invalidate all three navigators; the visible tab reloads immediately and background tabs reload when next selected.

The Home header profile menu is an HTML `details` element managed by `profile_menu_controller.js`: a document-level click closes it when the tap lands outside the menu. Because each native tab retains its webview and HTML state, `AppTabBarController` also closes open profile menus in tabs moving to the background whenever the user switches tabs, including programmatic cross-tab routing.

The native tab controller, navigator roots and non-opaque webviews all use the app background token (`#0A1521`). A lazily loaded tab can therefore expose its empty native surface while the first request is in flight without producing a white flash before the web page renders.

The app pages render only the floating Add button (except Home, which swaps it for an inline dashed "bring your own" card, `app/views/app/home/_import_card.html.erb`); the native controller owns the tab bar and the `tab-badge` bridge mirrors the active-import count onto the Queue item. The native web views extend beneath `UITabBar`, so every scrolling app screen uses `app-scroll-pad` to reserve the full tab-bar height plus the bottom safe-area inset; the inset by itself only clears the home indicator. The server gates `/app` screens on the `LangletsNative` user-agent marker. Tab-root paths deliberately have no `replace_root` path-configuration rule because cross-tab routing is native; modal routes retain their existing rules.

- **Home has two states** (`App::HomeController#index`). With something to continue: greeting, optional "just imported" hero, the two most recently practiced unfinished courses under "Keep it going" with a centered "See all" link to `/app/started_courses`, and two Library suggestions under "More from the library". The started-videos screen uses non-null `Enrollment#last_practiced_at` as the canonical started signal and shows every published course the user has opened, including completed courses, in recent-practice order. With nothing to continue (`@first_run`): a "Pick your first song" picker of four Library suggestions. Suggestions are random published courses in the learning language the user isn't enrolled in — deliberately dumb until real selection lands. Both states also show the signed-in user's personal playlists, including empty playlists; system playlists and other users' playlists are excluded from this section. Playlist rows link to the existing authorized playlist page and count only published courses.
- **Design tokens** are `--color-app-*` / `app-*` utilities at the bottom of `application.tailwind.css`. **Never use `dark:` under `app/views/app/**`** — the variant keys off `[data-theme="dark"]`, which the app layout hard-codes, so it would be unconditionally on and the intent invisible.
- Tabs use `presentation: replace_root`; the sheets use `context: modal, modal_style: medium`, which maps onto a real `UISheetPresentationController` detent with no Swift. The sheets are **full pages, not Turbo Frames** — a frame overlay inside the web view fights the native modal and you get two competing dismissal gestures.
- Course lesson sheets use `LessonViewController`, a `HotwireWebViewController` subclass selected by `SceneDelegate` for `/courses/:course/lessons/:lesson` and its activity URLs. It adds a native top-right X that dismisses the whole lesson sheet; this is deliberately a close action rather than back navigation between activities.
- The Queue **polls** (`poll_controller.js`, 3s, stops when nothing is active). See ImportRequest above for why not Action Cable.
- Screens are gated by `require_language_for_native_app` too: a native user with no `?lang=` is sent to `/onboarding/language` before any of this is reachable.

Deliberately **not** built from the mockup, because both would be controls that do nothing: the Library's category chips (nothing populates the taxonomy until the classifier lands) and the Add sheet's "Search YouTube" segment (needs the Data API).

#### Onboarding Flow
1. **Mandatory Authentication**: The server enforces authentication for all native app requests via `ApplicationController#require_authentication_for_native_app`. Unauthenticated native app users are redirected to the sign-in page.
2. **Language Selection**: After authentication, if no `?lang=<code>` param is present, the server redirects to `/onboarding/language`. The user selects their learning language from a web page that communicates the choice to iOS via a Hotwire Native bridge component (`LanguageSelectionBridgeComponent`).
3. **Local Persistence**: The selected language ISO code is stored in iOS `UserDefaults` under key `selectedLanguage`. It is not persisted server-side.
4. **URL Param Propagation**: The iOS app appends `?lang=<code>` to the root/start URL. Rails propagates this param through `default_url_options` so all generated links include it.
5. **Content Filtering**: `CoursesController#index` and `PlaylistsController` filter their listings by `Language.find_by(iso_name: params[:lang])` when the param is present.
6. **Tabbed Home Browsing**: The root page (`CoursesController#index`) renders a reusable tabs partial (`app/views/shared/_tabs.html.erb`) backed by `tabs_controller.js`, with a default **Courses** tab (playlist grid) and a secondary **Standalone clips** tab (standalone course grid).

#### Changing Learning Language
- Users can change their learning language at any time from the user dropdown menu (avatar icon) on any authenticated page.
- The dropdown shows the currently selected language and links to `/onboarding/language?returnto=<current_url>`.
- The onboarding page is context-aware: it shows "Change Learning Language" when accessed from the profile menu, and "Welcome to Langlets" during first-time onboarding.
- When a language is selected, the bridge message includes a `redirectUrl` so the app navigates back to the originating page with the updated `?lang=` parameter instead of jumping to the root URL.
- The native profile presents the current learning language in a compact select. Changing it sends the selected option's ISO code and redirect URL through the same bridge, keeping iOS `UserDefaults` and the Rails `?lang=` session in sync.

#### OAuth Authentication in Native App
- Google and GitHub OAuth flows use `ASWebAuthenticationSession` (Safari) instead of the embedded WKWebView, because Google blocks OAuth in embedded browsers.
- The `AuthBridgeComponent` intercepts OAuth sign-in button taps in the web view and sends a bridge message to iOS, which starts `ASWebAuthenticationSession`.
- **Native App Detection in OAuth Callback**: `ASWebAuthenticationSession` uses Safari's standard user agent, so the server cannot detect the native app via the `LangletsNative` user-agent string. Instead, the iOS app appends `?native_app=1` to the initial OAuth URL (`/users/auth/:provider?native_app=1`). OmniAuth preserves this parameter in `request.env["omniauth.params"]` during the callback phase.
- The `Users::OmniauthCallbacksController#native_app?` method checks both the user agent and `omniauth.params["native_app"]` to determine if the request came from the native app.
- On successful authentication, the server redirects to `langlets://auth-success`, which `ASWebAuthenticationSession` intercepts and closes. The app then routes back to the start location. The session cookie is shared between Safari and `WKWebsiteDataStore.default()`, so the WKWebView picks up the authenticated session on reload.
- On failure, the server redirects to `langlets://auth-failure` for native app flows.

#### Key Files
- `langlets-ios/langlets/langlets/AppTabBarController.swift` — Native tabs, per-tab navigators, lazy loading and tab state retention
- `langlets-ios/langlets/langlets/SceneDelegate.swift` — App entry point, bridge registration, and URL routing
- `langlets-ios/langlets/langlets/LessonViewController.swift` — Native lesson-sheet close control
- `langlets-ios/langlets/langlets/Bridge/TabBadgeComponent.swift` — Updates the native Queue badge from web content
- `langlets-ios/langlets/langlets/Auth/AuthBridgeComponent.swift` — Intercepts OAuth sign-in taps and triggers native auth flow
- `langlets-ios/langlets/langlets/Auth/AuthService.swift` — Manages `ASWebAuthenticationSession` for OAuth
- `app/controllers/users/omniauth_callbacks_controller.rb` — Handles OAuth callbacks and redirects to `langlets://auth-success` for native app
- `app/javascript/controllers/bridge/auth_bridge_controller.js` — Stimulus bridge controller for OAuth sign-in buttons

### Content Processing Pipeline
1. **YouTube URL Input**: Extract video metadata and audio
2. **Phrase Extraction**: Generate timestamped bilingual phrases with multi-script support
3. **Multi-Script Text Creation**: Store content in multiple writing systems (Latin, Arabic, etc.)
4. **Audio Generation**: Create TTS audio for phrases and tokens via Azure
5. **Token Mapping**: Create word-level translation mappings with audio
6. **Lesson Generation**: Structure content into pedagogical sequences
7. **Activity Creation**: Generate diverse interactive exercises with audio support

### Learning Activity Types
- **Video Comprehension**: Synchronized subtitle viewing with original audio
- **Phrase Matching**: Translation pair exercises with TTS pronunciation
- **Flashcards**: Learners choose the missing source-language word; the controller preloads the displayed card's correct-answer audio, then a correct choice fills the sentence blank with a brief flash-in animation synchronized to playback before the next card appears
- **Chronological Sorting**: Temporal sequence understanding
- **Word Alignment**: Granular translation mapping with audio feedback
- **Pronunciation Practice**: Speaking exercises with TTS model audio
- **Listening Comprehension**: Audio-based word identification using generated audio
- **Q&A Exercises**: Comprehension testing with audio support

### Multilingual Support
- **Multi-Script Text System**: Support for multiple writing systems per language
- **Script Variants**: Store text in different scripts (Latin, Arabic, Cyrillic, etc.)
- **RTL Languages**: Right-to-left text rendering
- **Pronunciation Variants**: Regional accent support
- **Sound Similarity**: Pronunciation confusion detection
- **Character Indexing**: Precise word boundary detection across scripts

### YouTube-Style Playlist Interface

The platform implements a modern, YouTube-inspired interface for browsing playlists:

#### Playlist Show View (`app/views/playlists/show.html.erb`)
- **Header Section**: 
  - Back navigation to main courses page
  - Playlist title and description
  - User authentication controls (sign up/login or user menu with XP tracking)
- **Search & Filter Section**:
  - Real-time search bar with debounced input
  - Horizontal scrolling tag filter row (All, Music, French, etc.)
  - Mobile-responsive design with proper touch interactions
- **Course Grid**: 
  - Responsive grid layout using existing course card components
  - Infinite scroll structure (ready for implementation)
  - Ajax-powered updates without page refresh

#### Interactive Features (`app/javascript/controllers/playlist_courses_controller.js`)
- **Real-time Search**: Debounced search with 300ms delay for optimal performance
- **Tag Filtering**: Dynamic filtering by course tags with visual feedback
- **Infinite Scroll**: Intersection Observer API for loading more courses
- **Error Handling**: Graceful degradation with user-friendly error messages
- **State Management**: Maintains current page, search term, and active filters
- **Native-safe playlist actions**: Playlist creation and deletion use in-page Stimulus dialogs instead of browser `prompt`/`confirm` APIs, so the controls work consistently in Hotwire Native's WKWebView. Creation stays inside the course's add-to-playlist sheet; deletion requires an explicit second tap and does not delete the playlist's courses.
- **Native tab-bar clearance**: Regular course and playlist pages mark native requests with `data-native-tabs`; the add-to-playlist and delete-playlist sheets use that state to reserve the iOS tab bar height plus the bottom safe-area inset and reduce their maximum height accordingly.

#### Backend Support (`app/controllers/playlists_controller.rb`)
- **Optimized Queries**: Single-query approach for courses with progress data
- **Ajax Endpoints**: JSON responses for search and filtering
- **Pagination**: Server-side pagination with configurable page size
- **Tag Integration**: Dynamic tag loading based on playlist content

#### Tag System for Course Categorization
- **Flexible Tagging**: Courses can have multiple tags (Music, French, Beginner, etc.)
- **Playlist Scoping**: Tags are filtered by playlist context
- **Sample Data**: Migration includes common tags for immediate functionality
- **Unique Constraints**: Prevents duplicate tag assignments

This implementation provides a modern, responsive interface that matches contemporary content platforms while maintaining the educational focus of the application.

### Progressive Learning Design
- **Ordered Sequences**: Lessons and activities follow pedagogical progression
- **Scaffolded Complexity**: From video watching to detailed word alignment
- **Contextual Learning**: Words learned within meaningful phrases
- **Multi-modal Practice**: Video, audio, text, and speaking integration

## File Structure

```
app/models/
├── activity.rb                 # Base activity class (STI)
├── activities/                 # Activity type implementations
│   ├── watch_video_activity.rb
│   ├── match_phrases_activity.rb
│   ├── sort_phrases_activity.rb
│   ├── language_alignment_activity.rb
│   ├── speak_activity.rb
│   ├── listen_activity.rb
│   └── find_answer_activity.rb
├── course.rb
├── lesson.rb
├── medium.rb
├── language.rb
├── script.rb                   # Writing system definitions
├── multi_script_text.rb        # Multi-script text container
├── script_variant.rb           # Specific script content
├── phrase.rb                   # has_one_attached :l1_audio
├── token_translation.rb        # has_one_attached :l1_audio
├── user.rb                     # Devise authentication
├── playlist.rb                 # Playlists (system-curated and user-owned)
├── tag.rb                      # Course categorization tags
├── course_tag.rb               # Course-tag associations
├── activity_phrase.rb          # Join table model
├── activity_token_translation.rb # Join table model
├── activity_user.rb            # User progress on activities
├── lesson_user.rb              # User progress on lessons
└── create_song_progress.rb     # Workflow tracking

app/views/playlists/       # YouTube-style playlist views
├── show.html.erb              # Main playlist view with search/filter
└── _courses.html.erb          # Course grid partial for Ajax updates

app/controllers/
├── playlists_controller.rb # Playlist browsing and search
└── ...                        # Other controllers

app/javascript/controllers/
├── playlist_courses_controller.js # Search, filtering, infinite scroll
└── ...                        # Other Stimulus controllers

app/views/devise/               # Devise authentication views
├── sessions/                   # Login/logout views
│   └── new.html.erb           # Modern dark-themed login form
├── registrations/             # User registration views
├── passwords/                 # Password reset views
└── confirmations/             # Email confirmation views

app/services/
└── azure_text_to_speech_service.rb # TTS integration

app/lib/ai/
└── create_song.rb              # Audio attachment logic

db/
├── schema.rb                   # Database schema
└── migrate/                    # Migration files

storage/                        # Active Storage files
├── development.sqlite3         # Local storage in development
└── [blob_directories]/         # Organized blob storage

script/
├── create_song/               # Course generation scripts
└── shorts/                    # Short-form content scripts

prompts/                       # AI prompt templates
└── system.md                  # Core system prompts
```

## Design Patterns

### Single Table Inheritance (STI)
Activities use STI to share common behavior while allowing specialized implementations for different exercise types.

### Polymorphic Associations
Active Storage attachments can be associated with any model through polymorphic relationships.

### Join Table Models
ActivityPhrase and ActivityTokenTranslation are full models (not just join tables) to allow for future extensibility.

### Workflow State Management
CreateSongProgress uses JSONB for flexible step tracking in the content creation pipeline.

### Timestamp-based Synchronization
All content is synchronized to media timestamps for precise audio-visual alignment.

### Audio Processing Pipeline
1. **Text Normalization**: Sanitize text for SSML compatibility
2. **Voice Selection**: Language-specific neural voice assignment
3. **PCM Generation**: Azure TTS API produces raw audio
4. **WAV Conversion**: PCM-to-WAV using WaveFile gem with proper headers
5. **Base64 Encoding**: Secure audio data transmission
6. **Active Storage Integration**: Polymorphic file attachment

## Technical Implementation Details

### Audio File Specifications
- **Source Format**: Raw PCM from Azure TTS (`raw-16khz-16bit-mono-pcm`)
- **Output Format**: WAV with standard headers
- **Sample Rate**: 16,000 Hz (broadcast quality)
- **Bit Depth**: 16-bit signed integers
- **Channels**: Mono (single channel)
- **Encoding**: Little-endian PCM

### Azure TTS Configuration
```ruby
# Service constants
AZURE_PCM_OUTPUT_FORMAT = 'raw-16khz-16bit-mono-pcm'
WAV_SAMPLE_RATE = 16000
WAV_CHANNELS = 1  
WAV_BITS_PER_SAMPLE = 16

# Voice mapping by language
{
  "en" => "en-US-AriaNeural",
  "es" => "es-ES-ElviraNeural", 
  "fr" => "fr-FR-DeniseNeural",
  "de" => "de-DE-KatjaNeural",
  "ar" => "ar-JO-TaimNeural",
  "he" => "he-IL-AvriNeural"
}
```

### SSML Template Structure
```xml
<speak version='1.0' xml:lang='[language_code]'>
  <voice name='[voice_name]'>[sanitized_text]</voice>
</speak>
```

## Scalability Considerations

- **JSONB Usage**: Flexible data storage for varying workflow steps
- **Indexing Strategy**: Key foreign keys and unique constraints are indexed
- **Background Processing**: Async content creation pipeline
- **Cloud Storage**: Scalable file storage via Active Storage
- **Modular Activities**: New activity types can be added through STI
- **Audio Caching**: Generated TTS audio files are cached via Active Storage
- **API Rate Limiting**: Azure TTS requests managed through service layer
- **Compression**: WAV files optimized for web delivery
- **CDN Integration**: Audio files served through content delivery networks
- **Batch Processing**: Multiple audio files can be generated simultaneously
- **Error Handling**: Graceful degradation when TTS service is unavailable

## Performance Optimizations

### Audio Delivery
- **Lazy Loading**: Audio files loaded on-demand
- **Progressive Download**: Streaming support for large audio files
- **Format Optimization**: 16kHz mono reduces file size while maintaining quality
- **Browser Caching**: Appropriate cache headers for audio assets

### Database Efficiency  
- **Eager Loading**: Minimize N+1 queries for audio attachments
- **Selective Loading**: Only load audio when needed for activities
- **Index Coverage**: Foreign key indexes support efficient joins

This architecture supports a sophisticated language learning platform that can process multimedia content, extract educational material, generate high-quality pronunciation audio, and create interactive learning experiences with precise multilingual and audio support.

### User Progress Tracking System

The platform implements comprehensive progress tracking through dedicated join tables:

#### Activity Progress (`activity_users`)
- **Completion Tracking**: Records when users complete individual activities
- **Unique Constraints**: Prevents duplicate progress entries per user/activity
- **Timestamp Logging**: Tracks completion time for analytics and achievements
- **Activity Types Supported**: All STI activity types (Watch, Match, Sort, Align, Speak, Listen, Find Answer)

#### Lesson Progress (`lesson_users`)
- **Course Progression**: Tracks user advancement through structured lessons
- **Sequential Learning**: Enforces lesson order and prerequisites
- **Completion Certificates**: Foundation for achievement and certification systems
- **Analytics Ready**: Data structure supports learning analytics and reporting

#### Progress Data Applications
- **Course reset**: The Done button on a completed course resets it to not started by deleting the current user's `lesson_users` and `activity_users` rows for every lesson/activity in that course. Enrollment and XP/activity logs are retained because they represent library membership and historical rewards rather than resumable course progress.
- **Personalized Learning**: Adaptive content delivery based on completion history
- **Performance Analytics**: User engagement and learning effectiveness metrics
- **Achievement Systems**: Badges, streaks, and milestone recognition
- **Content Recommendations**: Intelligent next-lesson suggestions
- **Retention Metrics**: User engagement and course completion rates

#### Future Extensibility
- **Scoring Systems**: Ready for point-based assessments
- **Time Tracking**: Duration-based learning analytics
- **Difficulty Adaptation**: Performance-based content difficulty adjustment
- **Social Features**: Leaderboards and peer comparison capabilities

### Devise Security Configuration

The authentication system is configured with enterprise-grade security features:

#### Password Security
- **BCrypt Encryption**: Industry-standard password hashing with configurable cost
- **Password Complexity**: Minimum length and complexity requirements
- **Reset Token Expiration**: Time-limited password reset tokens for security
- **Brute Force Protection**: Account lockout after failed login attempts

#### Session Management
- **Remember Me**: Persistent login with secure token storage
- **Session Timeout**: Configurable session expiration for inactive users
- **Cross-Site Protection**: CSRF tokens and secure session cookies
- **Device Tracking**: Foundation for multi-device session management

#### Email Verification
- **Confirmable Module**: Email address verification for new accounts
- **Confirmation Tokens**: Secure, time-limited email confirmation
- **Unconfirmed Email Handling**: Support for email address changes
- **Resend Confirmation**: User-friendly confirmation resend functionality

#### Production Security Considerations
- **HTTPS Enforcement**: SSL/TLS required for all authentication endpoints
- **Secure Headers**: Content Security Policy and security headers
- **Rate Limiting**: API and form submission rate limiting
- **Audit Logging**: User authentication and security event logging

#### Database Security
- **Unique Constraints**: Email uniqueness enforcement at database level
- **Index Security**: Efficient lookups without exposing sensitive data
- **Token Storage**: Secure storage of reset and confirmation tokens
- **Data Encryption**: Encrypted password storage with salt

---

## Personal Words Practice Feature

### Overview
Users can save individual word/token translations they encounter during lessons and videos for personal review. A "Review Words" session builds and plays a custom review lesson from the user's saved words.

### New Models

#### TokenTranslationUser (`token_translation_users`)
- **Purpose**: Join table linking users to their saved token translations
- **Key Features**:
  - Unique constraint per `(user_id, token_translation_id)` pair
  - Cascade delete when user or token translation is removed
- **Relationships**:
  - Belongs to User
  - Belongs to TokenTranslation

#### Review Lessons (Lesson without course/medium)
- Lessons now support `course_id: nil` and `medium_id: nil` — enabling standalone review lessons
- Review lessons have random slug prefixed with `review-`
- The unique index on `(course_id, slug)` is partial (`WHERE course_id IS NOT NULL`)

### New Activity Type

#### WriteMissingWordActivity (STI: `Activities::WriteMissingWordActivity`)
- **Purpose**: User types the missing L1 word in a sentence shown with a blank
- **UI**: Shows L2 translation hint, L1 sentence with `_____` blank, text input + Check button
- **Validation**: Case-insensitive exact match; 2 XP for correct answers
- **Stimulus Controller**: `write-missing-word-activity`
- **Data**: `activity_params` builds card objects with `{id, phrase_with_blank, answer, translation, audio_url}`

### New Services

#### ReviewLessonBuilder (`app/services/review_lesson_builder.rb`)
- Creates a review lesson (no course, no medium) for a user from their saved token translations
- Activity composition:
  - FlashcardActivity (if ≥3 saved tokens, up to 15)
  - MatchTokensActivity (if ≥3 saved tokens, up to 15)
  - TokensChainActivity (if ≥4 saved tokens, up to 15)
  - WriteMissingWordActivity (always, up to 10)
- TokensChainActivity uses a frameless exercise layout with an inline matched-word count and progress bar. Each correct translation becomes the next highlighted L1 prompt, while previously found translations are visually muted.

### New Controllers

#### TokenTranslationUsersController
- `POST /token_translation_users` — save a token translation (authenticated users only)
- `DELETE /token_translation_users/:id` — unsave (uses token_translation_id as param)
- JSON responses: `{saved: true/false, token_translation_id: N}`

#### ReviewLessonsController
- `POST /review_lessons` — build review lesson and redirect to show
- `GET /review_lessons/:id` — play lesson (uses `review_lessons/show.html.erb`)
- `GET /review_lessons/:id/finish` — completion page

### Frontend Changes

#### Popover Translation Controller (`popover-translation`)
- Added `savedIds` (Array) value — JSON list of user's saved token_translation IDs
- Added `toggleSave()` action — calls API to save/unsave; updates button UI
- Reads `data-token-id` from clicked token span (already present via `wrap_tokens_in_spans` helper)
- Save button shows 🔖 Save / ✓ Saved state
- The popup displays the stored translation and, for signed-in users, the save action; it does not link to an external AI explanation service

#### _translation_popup.html.erb
- Added Save button with `saveButton`, `saveIcon`, `saveText` targets
- Shows saved/unsaved state visually

#### Views with popover-translation controller
The following views now pass `data-popover-translation-saved-ids-value` with the current user's saved token IDs:
- `full_player/show.html.erb`
- `activities/_watch_video_activity.html.erb`
- `activities/_match_phrases_activity.html.erb`
- `activities/_speak_activity.html.erb`

#### User Profile Menus
All 3 user profile menus show a "📚 Review Words" button when the user has saved token translations:
- `courses/index.html.erb`
- `courses/show.html.erb`
- `playlists/show.html.erb`

These checkbox-backed web profile menus use `profile_menu_controller.js` to clear
their toggle when a document click lands outside the menu. The same controller
also closes the native Home header's `details` menu, keeping outside-click
behavior consistent across both menu implementations.

The native app Home header also uses its top-right initials as a profile dropdown. It links to Profile and Logout, and shows one language-specific "Practice Words" action for each language in which the user has saved vocabulary:
- `app/views/app/shared/_header.html.erb`

On mobile, the courses index and playlist headers keep the profile avatar visible by moving the theme toggle and XP chip into the profile dropdown while keeping desktop header controls unchanged:
- `courses/index.html.erb`
- `playlists/show.html.erb`
