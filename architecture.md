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
- **Relationships**: Referenced by phrases as L1 (source) and L2 (target) languages

#### 2. **Medium** (`media`)
- **Purpose**: Store references to external media content (YouTube videos)
- **Key Features**:
  - Unique URL constraint
  - YouTube video ID extraction
- **Relationships**: 
  - One-to-many with Lessons
  - One-to-many with Phrases

#### 3. **Course** (`courses`)
- **Purpose**: Group lessons into structured learning paths
- **Key Features**:
  - Hierarchical organization with slugs
  - Main media URL for course overview
- **Relationships**: One-to-many with Lessons

#### 4. **Lesson** (`lessons`)
- **Purpose**: Define specific learning segments from media content
- **Key Features**:
  - Unique slugs for routing
  - Timestamp ranges (`start_timestamp`, `end_timestamp`)
  - Ordered sequence within courses
  - Descriptive names
- **Relationships**: 
  - Belongs to Course and Medium
  - One-to-many with Activities

#### 5. **Phrase** (`phrases`)
- **Purpose**: Store synchronized bilingual text segments with timestamps
- **Key Features**:
  - Bilingual text pairs (`text_l1`, `text_l2`)
  - Media synchronization timestamps
  - Language pair references (`l1_id`, `l2_id`)
  - **Audio Attachment**: `has_one_attached :l1_audio` for pronunciation audio files
- **Relationships**: 
  - Belongs to Medium and two Languages
  - One-to-many with TokenTranslations
  - Many-to-many with Activities (through ActivityPhrase)

#### 6. **TokenTranslation** (`token_translations`)
- **Purpose**: Provide word/token-level translations within phrases
- **Key Features**:
  - Character range indices for both languages (`l1_start_index`, `l1_end_index`, `l2_start_index`, `l2_end_index`)
  - Translation text
  - Practice questions array
  - Similar sound arrays for pronunciation practice
  - Unique constraint on phrase + L1 indices
  - **Audio Attachment**: `has_one_attached :l1_audio` for pronunciation audio files
- **Relationships**: 
  - Belongs to Phrase
  - Many-to-many with Activities (through ActivityTokenTranslation)

#### 7. **User** (`users`)
- **Purpose**: User authentication and account management
- **Key Features**:
  - Email-based authentication (unique constraint)
  - Encrypted password storage using Devise
  - Password reset functionality with tokens and timestamps
  - Remember me functionality for persistent sessions
  - Email confirmation system (confirmable)
- **Authentication System**: Powered by Devise gem with modules:
  - **Database Authenticatable**: Standard email/password authentication
  - **Recoverable**: Password reset via email tokens
  - **Rememberable**: Persistent login sessions
  - **Confirmable**: Email address verification for new accounts
- **Security Features**:
  - Reset password tokens with expiration timestamps
  - Confirmation tokens for email verification
  - Unconfirmed email handling for email changes
- **User Interface**: Modern dark-themed login/registration forms with:
  - Social authentication placeholders (Google, Facebook)
  - Responsive design with Tailwind CSS
  - Password visibility controls
  - Terms and privacy policy acceptance
- **Relationships**: 
  - Many-to-many with Activities (through ActivityUser) for progress tracking
  - Many-to-many with Lessons (through LessonUser) for completion tracking

### Activity System (Single Table Inheritance)

#### 8. **Activity** (`activities`)
- **Purpose**: Base class for interactive learning exercises
- **Architecture**: Uses STI (Single Table Inheritance) with `type` column
- **Key Features**:
  - Ordered sequence within lessons
  - Text headers and subheaders for UI
  - Video parameter generation
  - Dictionary creation functionality
- **Relationships**: 
  - Belongs to Lesson
  - Many-to-many with Phrases and TokenTranslations

#### Activity Types:
- **WatchVideoActivity**: Video viewing with synchronized subtitles
- **MatchPhrasesActivity**: Phrase-to-translation matching exercises
- **SortPhrasesActivity**: Chronological phrase ordering
- **LanguageAlignmentActivity**: Word-level alignment exercises
- **SpeakActivity**: Pronunciation practice
- **ListenActivity**: Audio comprehension with token identification
- **FindAnswerActivity**: Question-answer exercises

### Join Tables

#### 9. **ActivityPhrase** (`activity_phrases`)
- Links activities to their associated phrases
- Enables many-to-many relationship between Activities and Phrases

#### 10. **ActivityTokenTranslation** (`activity_token_translations`)
- Links activities to specific token translations for word-level exercises
- Enables many-to-many relationship between Activities and TokenTranslations

### User Progress Tracking

#### 11. **ActivityUser** (`activity_users`)
- **Purpose**: Track user progress through individual activities
- **Key Features**:
  - Unique constraint on activity + user combination
  - Timestamps for completion tracking
- **Relationships**: Links Users to Activities for progress monitoring

#### 12. **LessonUser** (`lesson_users`)
- **Purpose**: Track user progress through lessons
- **Key Features**:
  - Unique constraint on lesson + user combination
  - Timestamps for completion tracking
- **Relationships**: Links Users to Lessons for course progression

### Workflow Management

#### 13. **CreateSongProgress** (`create_song_progresses`)
- **Purpose**: Track async content creation pipeline
- **Key Features**:
  - YouTube URL processing
  - Multi-step workflow management
  - JSONB data storage for flexible progress tracking
  - Unique constraint on URL + language combination

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
Course (1) ──→ (many) Lesson
Lesson (many) ──→ (1) Medium
Lesson (1) ──→ (many) Activity

Language (1) ──→ (many) Phrase (as L1)
Language (1) ──→ (many) Phrase (as L2)
Medium (1) ──→ (many) Phrase

Phrase (1) ──→ (many) TokenTranslation
Phrase (many) ←──→ (many) Activity (through ActivityPhrase)

Activity (many) ←──→ (many) TokenTranslation (through ActivityTokenTranslation)

# User Management & Progress Tracking (Devise)
User (many) ←──→ (many) Activity (through ActivityUser) # Activity completion tracking
User (many) ←──→ (many) Lesson (through LessonUser) # Lesson progress tracking

# Audio Attachments via Active Storage
Phrase (1) ──→ (1) Audio File (l1_audio)
TokenTranslation (1) ──→ (1) Audio File (l1_audio)

# Active Storage Infrastructure
Any Model ←──→ Active Storage Blobs (polymorphic attachments)
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
  - reCAPTCHA Enterprise integration placeholder

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

### Content Processing Pipeline
1. **YouTube URL Input**: Extract video metadata and audio
2. **Phrase Extraction**: Generate timestamped bilingual phrases
3. **Audio Generation**: Create TTS audio for phrases and tokens via Azure
4. **Token Mapping**: Create word-level translation mappings with audio
5. **Lesson Generation**: Structure content into pedagogical sequences
6. **Activity Creation**: Generate diverse interactive exercises with audio support

### Learning Activity Types
- **Video Comprehension**: Synchronized subtitle viewing with original audio
- **Phrase Matching**: Translation pair exercises with TTS pronunciation
- **Chronological Sorting**: Temporal sequence understanding
- **Word Alignment**: Granular translation mapping with audio feedback
- **Pronunciation Practice**: Speaking exercises with TTS model audio
- **Listening Comprehension**: Audio-based word identification using generated audio
- **Q&A Exercises**: Comprehension testing with audio support

### Multilingual Support
- **RTL Languages**: Right-to-left text rendering
- **Pronunciation Variants**: Regional accent support
- **Sound Similarity**: Pronunciation confusion detection
- **Character Indexing**: Precise word boundary detection

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
├── phrase.rb                   # has_one_attached :l1_audio
├── token_translation.rb        # has_one_attached :l1_audio
├── user.rb                     # Devise authentication
├── activity_phrase.rb          # Join table model
├── activity_token_translation.rb # Join table model
├── activity_user.rb            # User progress on activities
├── lesson_user.rb              # User progress on lessons
└── create_song_progress.rb     # Workflow tracking

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
