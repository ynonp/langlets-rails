# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Development Commands

### Build and Asset Compilation
```bash
# Build JavaScript assets
npm run build

# Watch mode for JavaScript development
npm run build:watch

# Build CSS with Tailwind
npm run build:css

# Watch mode for CSS development
npm run build:css:watch
```

### Rails Development
```bash
# Start Rails server
rails server

# Start with Procfile.dev (if using foreman)
foreman start -f Procfile.dev

# Run Rails console
rails console

# Database operations
rails db:migrate
rails db:seed
rails db:setup
```

### Testing
```bash
# Run all tests
rails test

# Run specific test file
rails test test/models/activity_test.rb

# Run system tests
rails test:system

# Run linting
bundle exec rubocop

# Run security scan
bundle exec brakeman
```

## Project Architecture

### Technology Stack
- **Framework**: Ruby on Rails 8.0 with modern Rails features
- **Database**: PostgreSQL with SQLite for development/testing
- **Frontend**: Rails views + Stimulus JS controllers + Tailwind CSS
- **Asset Pipeline**: esbuild for JavaScript, Tailwind CLI for CSS
- **Authentication**: Devise with email/password and OAuth support
- **File Storage**: Active Storage for audio files
- **Audio Generation**: Azure Text-to-Speech integration
- **Background Jobs**: Solid Queue (Rails 8 default)

### Core Domain Models

**Language Learning Content Hierarchy:**
- `Course` → `Lesson` → `Activity` (with STI for different activity types)
- `Medium` (YouTube videos) → `Phrase` (timestamped bilingual text) → `TokenTranslation` (word-level translations)

**User Progress Tracking:**
- `User` (Devise authentication) with progress tracking through:
  - `ActivityUser` (activity completion)
  - `LessonUser` (lesson completion)

**Audio Integration:**
- `Phrase#l1_audio` and `TokenTranslation#l1_audio` attachments via Active Storage
- Azure TTS generates pronunciation audio for learning content

### Single Table Inheritance Activities
All activities inherit from `Activity` base class:
- `WatchVideoActivity` - Video viewing with synchronized subtitles
- `MatchPhrasesActivity` - Translation matching exercises
- `SortPhrasesActivity` - Chronological phrase ordering
- `LanguageAlignmentActivity` - Word-level alignment exercises
- `SpeakActivity` - Pronunciation practice
- `ListenActivity` - Audio comprehension
- `FindAnswerActivity` - Q&A exercises

### Key Directories
```
app/models/activities/     # STI activity implementations
app/javascript/controllers/ # Stimulus JS controllers for interactive features
app/services/             # Azure TTS and other service integrations
app/lib/ai/              # AI-powered content creation utilities
script/create_song/      # Content generation pipeline scripts
storage/                 # Active Storage files (audio, etc.)
```

### Content Creation Pipeline
The platform processes YouTube content through:
1. URL extraction and media processing
2. AI-powered phrase extraction with timestamps
3. Token-level translation mapping
4. Azure TTS audio generation for phrases and tokens
5. Structured lesson and activity creation

### Database Design Patterns
- **Polymorphic associations** for Active Storage attachments
- **Join table models** (not just tables) for extensibility
- **JSONB fields** for flexible workflow state tracking
- **Timestamp synchronization** for media alignment
- **Unique constraints** preventing duplicate progress entries

### Audio System Architecture
- **Format**: 16kHz mono WAV files from Azure TTS
- **Languages Supported**: English, Spanish, French, Arabic, Hebrew
- **Storage**: Active Storage with cloud provider support
- **Integration**: Polymorphic attachments on Phrase and TokenTranslation models
- **Workflow**: SSML → Azure TTS → PCM → WAV conversion → Base64 → Active Storage

### Authentication & User Management
- **Devise modules**: Database Authenticatable, Recoverable, Rememberable, Confirmable
- **Modern UI**: Dark-themed responsive authentication forms
- **Security**: BCrypt encryption, CSRF protection, session management
- **Progress tracking**: Comprehensive user advancement through content
- **OAuth ready**: UI prepared for Google/Facebook integration

## Development Guidelines

### Code Patterns
- Follow Rails conventions and existing patterns in the codebase
- Use Stimulus controllers for interactive JavaScript features
- Leverage STI for new activity types rather than separate models
- Utilize Active Storage for any file attachments
- Implement proper error handling for Azure TTS integration

### Database Considerations
- Use migrations for schema changes
- Maintain referential integrity with proper foreign keys
- Index frequently queried columns (user_id, activity_id, etc.)
- Use JSONB for flexible data structures in workflow tracking

### Audio Integration Best Practices
- Always attach audio files through the established service layer
- Handle TTS failures gracefully with fallback mechanisms
- Use appropriate file naming conventions for audio attachments
- Consider file size optimization for mobile users

### Testing Approach
- Model tests cover validations and associations
- Controller tests verify authentication and response handling
- System tests for user workflows and JavaScript interactions
- Service tests for Azure TTS integration

## Important Notes

- The project uses Rails 8 features including Solid Queue for background jobs
- Audio generation is async and should handle Azure TTS rate limits
- User progress tracking is comprehensive but requires careful handling of concurrent updates
- The STI activity system allows for easy extension of new learning exercise types
- All timestamps are synchronized to media content for precise audio-visual alignment