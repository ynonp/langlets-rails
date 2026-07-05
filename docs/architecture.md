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
- **Purpose**: Store references to external media content (YouTube videos)
- **Key Features**:
  - Unique URL constraint
  - YouTube video ID extraction
- **Relationships**: 
  - One-to-many with Lessons
  - One-to-many with Phrases

#### 6. **Course** (`courses`)
- **Purpose**: Group lessons into structured learning paths
- **Key Features**:
  - Hierarchical organization with slugs
  - Main media URL for course overview
  - Language association for target learning language
  - **User ownership**: All courses belong to a specific user (creator)
- **Relationships**: 
  - One-to-many with Lessons
  - Belongs to Language and User
  - Many-to-many with LearningPaths (through CoursesLearningPath)

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
  - **Multi-Script Text Support**: References to MultiScriptText objects (`text_l1_id`, `text_l2_id`)
  - Media synchronization timestamps
  - Language pair references (`l1_id`, `l2_id`)
  - **Audio Attachment**: `has_one_attached :l1_audio` for pronunciation audio files
  - **Helper Methods**:
    - `text_l1_content`/`text_l2_content`: Get default script content
    - `text_l1_for_script`/`text_l2_for_script`: Get content for specific script
    - `with_calculated_end_timestamps`: Calculate phrase durations
- **Relationships**: 
  - Belongs to Medium and two Languages
  - Belongs to two MultiScriptText objects (text_l1, text_l2)
  - One-to-many with TokenTranslations
  - Many-to-many with Activities (through ActivityPhrase)

#### 9. **TokenTranslation** (`token_translations`)
- **Purpose**: Provide word/token-level translations within phrases
- **Key Features**:
  - Character range indices for both languages (`l1_start_index`, `l1_end_index`, `l2_start_index`, `l2_end_index`)
  - Translation text
  - Practice questions array (PostgreSQL array type)
  - Similar sound arrays for pronunciation practice (PostgreSQL array type)
  - Unique constraint on phrase + L1 start/end indices
  - **Audio Attachment**: `has_one_attached :l1_audio` for pronunciation audio files
- **Relationships**: 
  - Belongs to Phrase
  - Many-to-many with Activities (through ActivityTokenTranslation)

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
  - Social authentication placeholders (Google, Facebook)
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
- **MatchPhrasesActivity**: Phrase-to-translation matching exercises
- **SortPhrasesActivity**: Chronological phrase ordering
- **LanguageAlignmentActivity**: Word-level alignment exercises
- **SpeakActivity**: Pronunciation practice
- **ListenActivity**: Audio comprehension with token identification
- **FindAnswerActivity**: Question-answer exercises

#### 12. **LearningPath** (`learning_paths`)
- **Purpose**: Define structured curriculum pathways with YouTube-like browsing experience
- **Key Features**:
  - Named learning sequences with descriptions
  - Difficulty level classification (integer)
  - Publication status (boolean)
  - **YouTube-style View**: Dedicated show page with search, tag filtering, and grid layout
  - **Ajax Search**: Real-time course filtering by name
  - **Tag-based Filtering**: Dynamic tag system for course categorization
- **Relationships**: Many-to-many with Courses (through CoursesLearningPath)

#### 13. **Tag** (`tags`)
- **Purpose**: Categorization system for courses within learning paths
- **Key Features**:
  - Unique tag names (e.g., "Music", "French", "Beginner")
  - Used for filtering courses in learning path views
  - Supports YouTube-like tag filtering interface
- **Relationships**: Many-to-many with Courses (through CourseTag)

#### 14. **CourseTag** (`course_tags`)
- **Purpose**: Join table linking courses to their categorization tags
- **Key Features**:
  - Unique constraint on course + tag combination
  - Enables tag-based filtering and categorization
- **Relationships**: Links Courses to Tags

#### 15. **CoursesLearningPath** (`courses_learning_paths`)
- **Purpose**: Join table linking courses to learning paths
- **Key Features**:
  - Ordered sequence within learning paths (integer order field)
  - Timestamps for tracking
- **Relationships**: Links Courses to LearningPaths

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

### Workflow Management

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

# Learning Path System
LearningPath (many) ←──→ (many) Course (through CoursesLearningPath)
Course (many) ←──→ (many) Tag (through CourseTag)

# User Management & Ownership (Devise)
User (1) ──→ (many) Course # Content ownership
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
- **Social Authentication Ready**: UI prepared for Google and Facebook integration
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
- **Social Authentication Ready**: 
  - Google and Facebook buttons with proper branding
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

#### Onboarding Flow
1. **Mandatory Authentication**: The server enforces authentication for all native app requests via `ApplicationController#require_authentication_for_native_app`. Unauthenticated native app users are redirected to the sign-in page.
2. **Language Selection**: After authentication, if no `?lang=<code>` param is present, the server redirects to `/onboarding/language`. The user selects their learning language from a web page that communicates the choice to iOS via a Hotwire Native bridge component (`LanguageSelectionBridgeComponent`).
3. **Local Persistence**: The selected language ISO code is stored in iOS `UserDefaults` under key `selectedLanguage`. It is not persisted server-side.
4. **URL Param Propagation**: The iOS app appends `?lang=<code>` to the root/start URL. Rails propagates this param through `default_url_options` so all generated links include it.
5. **Content Filtering**: `CoursesController#index` and `LearningPathsController` filter their listings by `Language.find_by(iso_name: params[:lang])` when the param is present.

#### Changing Learning Language
- Users can change their learning language at any time from the user dropdown menu (avatar icon) on any authenticated page.
- The dropdown shows the currently selected language and links to `/onboarding/language?returnto=<current_url>`.
- The onboarding page is context-aware: it shows "Change Learning Language" when accessed from the profile menu, and "Welcome to Langlets" during first-time onboarding.
- When a language is selected, the bridge message includes a `redirectUrl` so the app navigates back to the originating page with the updated `?lang=` parameter instead of jumping to the root URL.

#### OAuth Authentication in Native App
- Google and GitHub OAuth flows use `ASWebAuthenticationSession` (Safari) instead of the embedded WKWebView, because Google blocks OAuth in embedded browsers.
- The `AuthBridgeComponent` intercepts OAuth sign-in button taps in the web view and sends a bridge message to iOS, which starts `ASWebAuthenticationSession`.
- **Native App Detection in OAuth Callback**: `ASWebAuthenticationSession` uses Safari's standard user agent, so the server cannot detect the native app via the `LangletsNative` user-agent string. Instead, the iOS app appends `?native_app=1` to the initial OAuth URL (`/users/auth/:provider?native_app=1`). OmniAuth preserves this parameter in `request.env["omniauth.params"]` during the callback phase.
- The `Users::OmniauthCallbacksController#native_app?` method checks both the user agent and `omniauth.params["native_app"]` to determine if the request came from the native app.
- On successful authentication, the server redirects to `langlets://auth-success`, which `ASWebAuthenticationSession` intercepts and closes. The app then routes back to the start location. The session cookie is shared between Safari and `WKWebsiteDataStore.default()`, so the WKWebView picks up the authenticated session on reload.
- On failure, the server redirects to `langlets://auth-failure` for native app flows.

#### Key Files
- `langlets-ios/langlets/langlets/SceneDelegate.swift` — App entry point, bridge registration, and URL routing
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

### YouTube-Style Learning Path Interface

The platform implements a modern, YouTube-inspired interface for browsing learning paths:

#### Courses Index View (`app/views/courses/index.html.erb`)
- **Header**: Site branding, streak/XP display, user profile dropdown with mobile-responsive controls.
- **Continue Learning** (signed-in users only): Responsive grid of courses the user has already started.
- **Tab Navigation** (Stimulus `tabs` controller):
  - **Courses** tab (default): Displays all published learning paths in a responsive 4-column grid. Cards link to the learning path detail page.
  - **Standalone Clips** tab: Displays all published courses not belonging to any learning path in the same responsive grid.
- **Next For You** (signed-in users only): Responsive grid of AI-recommended courses.

#### Learning Path Show View (`app/views/learning_paths/show.html.erb`)
- **Header Section**: 
  - Back navigation to main courses page
  - Learning path title and description
  - User authentication controls (sign up/login or user menu with XP tracking)
- **Search & Filter Section**:
  - Real-time search bar with debounced input
  - Horizontal scrolling tag filter row (All, Music, French, etc.)
  - Mobile-responsive design with proper touch interactions
- **Course Grid**: 
  - Responsive grid layout using existing course card components
  - Infinite scroll structure (ready for implementation)
  - Ajax-powered updates without page refresh

#### Interactive Features (`app/javascript/controllers/learning_path_courses_controller.js`)
- **Real-time Search**: Debounced search with 300ms delay for optimal performance
- **Tag Filtering**: Dynamic filtering by course tags with visual feedback
- **Infinite Scroll**: Intersection Observer API for loading more courses
- **Error Handling**: Graceful degradation with user-friendly error messages
- **State Management**: Maintains current page, search term, and active filters

#### Backend Support (`app/controllers/learning_paths_controller.rb`)
- **Optimized Queries**: Single-query approach for courses with progress data
- **Ajax Endpoints**: JSON responses for search and filtering
- **Pagination**: Server-side pagination with configurable page size
- **Tag Integration**: Dynamic tag loading based on learning path content

#### Tag System for Course Categorization
- **Flexible Tagging**: Courses can have multiple tags (Music, French, Beginner, etc.)
- **Learning Path Scoping**: Tags are filtered by learning path context
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
├── learning_path.rb            # Learning path curriculum
├── tag.rb                      # Course categorization tags
├── course_tag.rb               # Course-tag associations
├── activity_phrase.rb          # Join table model
├── activity_token_translation.rb # Join table model
├── activity_user.rb            # User progress on activities
├── lesson_user.rb              # User progress on lessons
└── create_song_progress.rb     # Workflow tracking

app/views/learning_paths/       # YouTube-style learning path views
├── show.html.erb              # Main learning path view with search/filter
└── _courses.html.erb          # Course grid partial for Ajax updates

app/controllers/
├── learning_paths_controller.rb # Learning path browsing and search
└── ...                        # Other controllers

app/javascript/controllers/
├── learning_path_courses_controller.js # Search, filtering, infinite scroll
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
- `learning_paths/show.html.erb`

On mobile, the courses index and learning path headers keep the profile avatar visible by moving the theme toggle and XP chip into the profile dropdown while keeping desktop header controls unchanged:
- `courses/index.html.erb`
- `learning_paths/show.html.erb`
