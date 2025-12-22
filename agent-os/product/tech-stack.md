# Langlets Technical Stack Documentation

## Technology Overview

Langlets is built on a modern Rails architecture with a focus on developer productivity, performance, and maintainability. The stack emphasizes convention over configuration while leveraging cutting-edge tools for AI integration and multimedia processing.

---

## Backend Stack

### Core Framework
- **Ruby on Rails 8.0**
  - Latest stable Rails with modern conventions
  - Active Record ORM for database abstraction
  - Action Cable for WebSocket support
  - Active Storage for file management
  - Active Job for background processing
  
### Database
- **PostgreSQL 14+**
  - Primary relational database
  - JSONB columns for flexible schema (translations, metadata)
  - Full-text search capabilities
  - Advanced indexing for performance
  - Supports multi-schema (cable, cache, queue)

### Background Jobs
- **Good Job** (Rails 8 default)
  - Postgres-backed job queue
  - Reliable job processing
  - Web UI for job monitoring
  - Scheduled jobs via recurring tasks
  - Used for: TTS audio generation, media processing, cleanup tasks

### Authentication & Authorization
- **Devise**
  - User authentication
  - Session management
  - Password recovery
  - Rememberable sessions
  
- **CanCanCan**
  - Role-based access control
  - Resource authorization
  - Admin vs. user permissions
  - Content ownership enforcement

### File Storage
- **Active Storage**
  - Local disk storage (development)
  - AWS S3 (production ready)
  - Direct uploads support
  - Image variants and transformations
  - Stores: user uploads, generated audio files, thumbnails

---

## Frontend Stack

### Modern Rails Frontend
- **Hotwire** (Turbo + Stimulus)
  - **Turbo Drive**: SPA-like page transitions without full reloads
  - **Turbo Frames**: Scoped page updates
  - **Turbo Streams**: Real-time updates via WebSockets
  - **Stimulus Controllers**: Modest JavaScript for interactivity
  
### JavaScript Build System
- **esbuild** (via jsbundling-rails)
  - Extremely fast JavaScript bundling
  - Modern ES6+ support
  - Tree shaking for minimal bundle size
  - Source maps for debugging

### Package Management
- **Bun**
  - Fast JavaScript package manager
  - Replaces npm/yarn for speed
  - Compatible with npm ecosystem
  
### CSS Framework
- **Tailwind CSS** (via cssbundling-rails)
  - Utility-first CSS framework
  - Custom design system
  - Responsive design utilities
  - Dark mode support (planned)
  - JIT compiler for optimal bundle size

### JavaScript Libraries
- **Plyr** (Video Player)
  - Customizable HTML5 video player
  - Subtitle support
  - Keyboard shortcuts
  - Responsive and accessible
  
- **Sortable.js**
  - Drag-and-drop reordering
  - Used in Sort Phrases activity
  - Touch-friendly
  
- **Stimulus Components** (Custom)
  - Match Phrases controller
  - Word Alignment controller
  - Audio playback controller
  - Activity state management

---

## AI & External Services

### Text-to-Speech (TTS)
- **Azure Cognitive Services (Text-to-Speech)**
  - Primary TTS provider
  - Neural voices for natural pronunciation
  - Multiple voices per language
  - SSML support for fine-tuning
  - Batch audio generation
  
### AI Language Models
- **Google Gemini**
  - Content generation
  - Translation assistance
  - Q&A generation
  
- **OpenAI (GPT-4)**
  - Advanced text generation
  - Contextual understanding
  - Translation refinement
  
- **Anthropic Claude**
  - Conversation generation
  - Cultural context analysis
  
- **LangChain** (Framework)
  - LLM abstraction layer
  - Prompt management
  - Chain complex AI workflows

### Media Processing
- **YouTube Data API v3**
  - Video metadata retrieval
  - Subtitle/caption extraction
  - Content validation
  
- **yt-dlp** (Python tool, via system call)
  - Robust YouTube downloader
  - Subtitle extraction fallback
  - Multiple format support

---

## Infrastructure & Deployment

### Application Server
- **Puma**
  - Multi-threaded Ruby web server
  - Efficient concurrency handling
  - Cluster mode for production
  - Configured via `config/puma.rb`

### Deployment
- **Kamal (Rails 8)**
  - Docker-based deployment
  - Zero-downtime deployments
  - Automated SSL via Let's Encrypt
  - Deploy to any VPS or cloud provider
  - Configuration in `config/deploy.yml`

### Containerization
- **Docker**
  - Application containerization
  - Multi-stage builds for optimization
  - Development and production Dockerfiles
  - Docker Compose for local development

### Hosting (Production Ready)
- **AWS**
  - EC2 for compute (via Kamal)
  - S3 for file storage
  - RDS for PostgreSQL (optional)
  - CloudFront for CDN (planned)
  
- **DigitalOcean / Hetzner / Linode**
  - VPS alternatives
  - Cost-effective for mid-scale
  - Kamal-compatible

---

## Database Architecture

### Core Schema Highlights

#### Multi-Language Support
```ruby
# languages table
- id, iso_name, name_english, name_native
- rtl (boolean for right-to-left languages)
- default_script_id (reference to scripts)

# scripts table
- id, code, name (e.g., 'latn', 'arab', 'hebr')

# multi_script_texts table
- id, language_id, audio_status
- Polymorphic text representation

# script_variants table
- id, multi_script_text_id, script_id, content
- Actual text in specific script
```

#### Content Hierarchy
```ruby
# courses
- id, user_id, language_id, name, slug, main_media_url

# lessons
- id, course_id, user_id, medium_id
- name, slug, start_timestamp, end_timestamp, order

# phrases
- id, lesson_id, medium_id
- text_l1_id, text_l2_id (references multi_script_texts)
- start_timestamp, end_timestamp, order

# tokens (words within phrases)
- id, phrase_id
- text_l1_id, text_l2_id
- character_index_start, character_index_end, order
```

#### Learning Activities
```ruby
# activities
- id, lesson_id, activity_type
- activity_type: enum (watch_video, match_phrases, sort_phrases, 
                      word_alignment, speak, listen, q_and_a)
- data (JSONB - flexible activity configuration)
- order

# activity_items (for activities with discrete items)
- id, activity_id, item_type, data (JSONB)
- Used for: Q&A questions, match pairs, etc.
```

#### User & Permissions
```ruby
# users (via Devise)
- id, email, encrypted_password
- admin (boolean)
- User owns: courses, lessons

# Abilities (via CanCanCan)
- Admins: manage all
- Users: manage own courses/lessons
- Public: read published content
```

### Database Relationships
- Language → MultiScriptText (one-to-many)
- MultiScriptText → ScriptVariant (one-to-many)
- Course → Lesson (one-to-many)
- Lesson → Phrase (one-to-many)
- Phrase → Token (one-to-many)
- Lesson → Activity (one-to-many)
- Activity → ActivityItem (one-to-many)
- User → Course/Lesson (one-to-many, ownership)

---

## Audio Pipeline

### TTS Workflow

1. **Content Creation**
   - User creates lesson with phrases
   - Each phrase has L1 and L2 text (MultiScriptText)
   - Tokens are auto-generated from phrases

2. **Audio Generation Trigger**
   - Background job: `GenerateAudioJob`
   - Enqueued for each MultiScriptText
   - Processes phrase-level and word-level audio

3. **Azure TTS Integration**
   - Service: `AzureTtsService`
   - Converts text to SSML
   - Calls Azure Cognitive Services API
   - Receives audio stream (MP3)

4. **Storage**
   - Audio saved via Active Storage
   - Attached to MultiScriptText record
   - Publicly accessible via signed URLs

5. **Playback**
   - Frontend fetches audio URL
   - Stimulus controller manages playback
   - Plyr or native HTML5 audio element

### Audio Metadata
```ruby
# multi_script_texts
- audio_status: enum
  - not_required: No audio needed
  - audio_required: Needs generation
  - audio_ready: Audio generated and attached
```

---

## Development Tools

### Testing
- **Minitest** (Rails default)
  - Unit tests for models
  - Integration tests for controllers
  - System tests for end-to-end
  
- **FactoryBot** (or similar)
  - Test data generation
  - Fixtures alternative
  
- **VCR / WebMock**
  - HTTP request stubbing
  - Record/replay external API calls

### Code Quality
- **RuboCop**
  - Ruby linter and formatter
  - Rails best practices enforcement
  - Configured via `.rubocop.yml`
  
- **Brakeman**
  - Security vulnerability scanner
  - Static analysis for Rails apps
  - CI integration

### Monitoring & Logging
- **Rails Logger**
  - Structured logging
  - Log rotation
  - Separate logs: development, production, test
  
- **Error Tracking** (Planned)
  - Sentry / Rollbar / Honeybadger
  - Real-time error notifications
  - Exception grouping and tracking

### Performance
- **Bullet** (Development)
  - N+1 query detection
  - Eager loading suggestions
  
- **Rack Mini Profiler** (Development)
  - Page load time analysis
  - SQL query profiling
  - Flame graphs

---

## Scalability Considerations

### Current Architecture
- **Single server deployment** via Kamal
- **Postgres as job queue** (Good Job)
- **S3 for static assets** (production)
- **Horizontal scaling ready** (stateless app servers)

### Future Enhancements
- **Redis** for caching and session store
- **CDN** for static assets and audio files
- **Read replicas** for database scaling
- **Job queue separation** (Redis-backed Sidekiq)
- **Elasticsearch** for advanced search
- **Rate limiting** (Rack Attack)

---

## Security

### Application Security
- **HTTPS only** (SSL via Let's Encrypt)
- **CSRF protection** (Rails default)
- **SQL injection prevention** (Active Record parameterization)
- **XSS protection** (Rails HTML escaping)
- **Strong parameters** (mass assignment protection)
- **Secure headers** (via rack-attack or similar)

### Data Security
- **Password encryption** (bcrypt via Devise)
- **Environment variables** for secrets (via Rails credentials)
- **S3 bucket policies** (private by default)
- **Signed URLs** for temporary access
- **Regular backups** (automated)

### API Security
- **API key rotation** (Azure, OpenAI, etc.)
- **Rate limiting** (planned)
- **CORS policies** (if API endpoints added)

---

## Data Flow Diagrams

### Lesson Creation Flow
```
User → Creates Course
  ↓
User → Pastes YouTube URL
  ↓
Backend → Fetches video metadata (YouTube API)
  ↓
Backend → Extracts subtitles (yt-dlp)
  ↓
Backend → Creates Lesson + Phrases
  ↓
Backend → Enqueues GenerateAudioJob
  ↓
Background → Calls AzureTtsService
  ↓
Background → Saves audio to S3 (Active Storage)
  ↓
User → Sees lesson ready for activities
```

### Learning Flow
```
User → Browses Courses
  ↓
User → Selects Lesson
  ↓
Frontend → Loads Activities (Turbo Frame)
  ↓
User → Interacts with Activity (Stimulus)
  ↓
Frontend → Submits answers (Turbo Stream)
  ↓
Backend → Validates and scores
  ↓
Frontend → Shows feedback (partial update)
  ↓
User → Proceeds to next activity
```

### Audio Generation Flow
```
Content Creation → MultiScriptText saved
  ↓
after_create callback → Enqueue GenerateAudioJob
  ↓
Job → Fetch language TTS settings
  ↓
Job → Call AzureTtsService.generate(text, language)
  ↓
Service → Convert text to SSML
  ↓
Service → POST to Azure TTS API
  ↓
Service → Receive MP3 stream
  ↓
Job → Attach audio to MultiScriptText
  ↓
MultiScriptText → Update audio_status to 'audio_ready'
```

---

## Technology Rationale

### Why Rails?
- **Mature ecosystem**: Proven for web applications
- **Developer productivity**: Convention over configuration
- **Built-in features**: Authentication, job processing, storage
- **Community**: Large talent pool, extensive gems

### Why PostgreSQL?
- **Reliability**: Production-proven, ACID compliant
- **JSONB**: Flexible schema for translations and metadata
- **Full-text search**: Built-in search capabilities
- **Scalability**: Handles millions of records efficiently

### Why Hotwire?
- **Simplicity**: Less JavaScript, more HTML
- **Performance**: Minimal JS bundle, fast page transitions
- **Rails integration**: Native Rails support
- **Progressive enhancement**: Works without JavaScript

### Why Tailwind?
- **Utility-first**: Rapid UI development
- **Consistency**: Design system enforcement
- **Performance**: Purged CSS, minimal bundle
- **Customization**: Easy theming and branding

### Why Azure TTS?
- **Quality**: Neural voices sound natural
- **Language support**: 100+ languages and dialects
- **Reliability**: Enterprise-grade SLA
- **Pricing**: Competitive per-character pricing

### Why Kamal?
- **Simplicity**: Single command deployment
- **Cost-effective**: Deploy to any VPS, no platform fees
- **Zero-downtime**: Rolling deployments
- **Rails 8 native**: Official Rails deployment tool

---

## Environment Configuration

### Required Environment Variables

```bash
# Database
DATABASE_URL=postgresql://user:password@localhost/langlets_production

# Rails
RAILS_MASTER_KEY=<your-master-key>
SECRET_KEY_BASE=<your-secret-key>

# Azure TTS
AZURE_TTS_API_KEY=<azure-api-key>
AZURE_TTS_REGION=<azure-region>

# OpenAI (optional)
OPENAI_API_KEY=<openai-api-key>

# Google Gemini (optional)
GEMINI_API_KEY=<gemini-api-key>

# AWS S3 (production)
AWS_ACCESS_KEY_ID=<aws-access-key>
AWS_SECRET_ACCESS_KEY=<aws-secret-key>
AWS_REGION=<aws-region>
AWS_BUCKET=<s3-bucket-name>

# YouTube API (optional)
YOUTUBE_API_KEY=<youtube-api-key>
```

### Development Setup
```bash
# Clone repository
git clone <repo-url>
cd langlets

# Install Ruby dependencies
bundle install

# Install JavaScript dependencies
bun install

# Setup database
./bin/rails db:setup

# Run migrations
./bin/rails db:migrate

# Start development server
./bin/dev
```

---

## Future Technology Considerations

### Under Evaluation
- **Redis**: For caching, session store, real-time features
- **Sidekiq**: Alternative to Good Job for high-volume jobs
- **Elasticsearch**: Advanced search and recommendations
- **React Native / Flutter**: Native mobile apps
- **WebRTC**: Real-time voice practice
- **PWA**: Progressive Web App for offline support

### Integration Opportunities
- **Stripe**: Payment processing for premium features
- **SendGrid / Postmark**: Transactional emails
- **Plausible / Fathom**: Privacy-friendly analytics
- **Algolia**: Hosted search service
- **Cloudflare**: CDN and DDoS protection

---

*This document is maintained as the technical reference for Langlets. Update as technologies are added, changed, or deprecated.*
