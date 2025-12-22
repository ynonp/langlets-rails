# Langlets Product Roadmap

## Current State (December 2025)

### ✅ Implemented Features

#### Content Infrastructure
- ✅ YouTube video integration and subtitle extraction
- ✅ Multi-language support (language pairs)
- ✅ Multi-script text support (Latin, Arabic, Hebrew, etc.)
- ✅ RTL language support
- ✅ Course and lesson organization
- ✅ Phrase-level timestamped content
- ✅ Word-level tokenization and translation

#### Learning Activities
- ✅ **Watch Video**: Synchronized bilingual subtitles
- ✅ **Match Phrases**: Translation matching exercise
- ✅ **Sort Phrases**: Temporal sequencing practice
- ✅ **Word Alignment**: Word-to-word translation mapping
- ✅ **Speak**: Pronunciation practice with reference audio
- ✅ **Listen**: Audio-based word identification
- ✅ **Q&A**: Comprehension questions

#### Audio & TTS
- ✅ Azure Text-to-Speech integration
- ✅ Phrase-level audio generation
- ✅ Word-level audio generation
- ✅ Multi-voice support per language
- ✅ Background audio processing jobs

#### User Management
- ✅ User authentication (Devise)
- ✅ User-owned content (courses, lessons)
- ✅ Admin panel for content management
- ✅ Role-based access control (CanCanCan)

#### Technical Foundation
- ✅ Rails 8.0 application
- ✅ PostgreSQL database with JSONB
- ✅ Active Storage for file management
- ✅ Hotwire (Stimulus + Turbo) for interactivity
- ✅ Background job processing
- ✅ Kamal deployment setup

### 🔍 Known Limitations & Technical Debt
- ⚠️ No mobile apps (web-only)
- ⚠️ Limited progress tracking
- ⚠️ No spaced repetition system
- ⚠️ Manual content creation workflow could be smoother
- ⚠️ No social/community features
- ⚠️ Limited analytics and insights
- ⚠️ No offline mode
- ⚠️ Performance optimization needed for large lessons
- ⚠️ Test coverage could be improved

---

## Near-Term Roadmap (Q1-Q2 2026)

### Priority 1: User Experience & Engagement

#### Easier course creation
- [ ] **1 Click Course Creation Wizard**: Easy wizard to quickly create a course and start practicing
- [ ] **Smarter templates**: Gradual, pedagogical and gamified learning experience
- [ ] **Achievement Badges**: Milestone celebrations (lessons completed, words learned, streaks)
- [ ] **Personal Flashcards**: Mark words for practice and daily review them in spaced repetition

#### Activity Improvements
- [ ] **Hint System**: Progressive hints for struggling learners
- [ ] **Difficulty Levels**: Easy/Medium/Hard variants for activities
- [ ] **Activity Recommendations**: Smart suggestions based on progress
- [ ] **Quick Review Mode**: Rapid review of previously learned content
- [ ] **Mistake Review**: Focus on words/phrases user struggled with

**Success Criteria**: 15% increase in activity completion rate

#### Mobile Responsiveness
- [ ] **Touch Optimizations**: Better mobile interactions for all activities
- [ ] **Responsive Layout**: Improved mobile/tablet layouts
- [ ] **Audio Playback**: Better mobile audio controls
- [ ] **Offline Indication**: Clear messaging when features need connectivity

**Success Criteria**: 25% of traffic from mobile, <3s mobile load time

### Priority 2: Content Creation & Quality

#### Simplified Lesson Creation
- [ ] **One-Click Lesson Import**: Single URL → complete lesson workflow
- [ ] **AI-Generated Questions**: Automatic Q&A generation from content
- [ ] **Bulk Operations**: Edit multiple phrases at once
- [ ] **Template Library**: Pre-configured activity sets for common use cases
- [ ] **Preview Mode**: See lesson before publishing

**Success Criteria**: 50% reduction in lesson creation time, 3x more user-created content

#### Content Discovery
- [ ] **Browse by Language**: Filter courses by target language
- [ ] **Search Lessons**: Full-text search across content
- [ ] **Featured Content**: Curated high-quality lessons
- [ ] **Recently Added**: Highlight new content
- [ ] **Popular Lessons**: Trending content based on engagement

**Success Criteria**: 40% increase in lesson discovery and enrollment

#### Quality Assurance
- [ ] **Subtitle Accuracy Scoring**: Confidence metrics for extracted subtitles
- [ ] **Manual Override**: Edit auto-generated translations
- [ ] **Community Reporting**: Flag inaccurate translations
- [ ] **Audio Quality Check**: Detect TTS failures
- [ ] **Content Moderation**: Review flagged content

**Success Criteria**: 90%+ subtitle accuracy, <1% flagged content

### Priority 3: Performance & Infrastructure

#### Speed Optimizations
- [ ] **Database Indexing**: Optimize query performance
- [ ] **Caching Strategy**: Implement fragment and page caching
- [ ] **Lazy Loading**: Load activities on-demand
- [ ] **Image Optimization**: Compress and serve optimized images
- [ ] **CDN Integration**: Serve static assets from CDN

**Success Criteria**: <2s page load, <500ms API response time

#### Reliability
- [ ] **Error Monitoring**: Implement Sentry or similar
- [ ] **Background Job Monitoring**: Track job failures and retries
- [ ] **Health Checks**: Automated uptime monitoring
- [ ] **Automated Backups**: Daily database backups
- [ ] **Rate Limiting**: Protect against abuse

**Success Criteria**: 99.9% uptime, <0.1% error rate

#### Developer Experience
- [ ] **Expanded Test Coverage**: Aim for 80%+ coverage
- [ ] **CI/CD Pipeline**: Automated testing and deployment
- [ ] **Code Documentation**: Improve inline documentation
- [ ] **Developer Guide**: Onboarding docs for contributors
- [ ] **Staging Environment**: Test features before production

**Success Criteria**: <10 min deploy time, 80%+ test coverage

---

## Medium-Term Roadmap (Q3-Q4 2026)

### Priority 1: Social & Community Features

#### Learner Profiles
- [ ] **Public Profiles**: Showcase learning progress and achievements
- [ ] **Following System**: Follow other learners and content creators
- [ ] **Activity Feed**: See what friends are learning
- [ ] **Leaderboards**: Friendly competition (weekly/monthly)

#### Collaborative Learning
- [ ] **Study Groups**: Create private learning groups
- [ ] **Shared Progress**: Group challenges and goals
- [ ] **Comments**: Discuss lessons and content
- [ ] **Content Sharing**: Share favorite lessons via social media

#### Content Creator Tools
- [ ] **Creator Dashboard**: Analytics for lesson creators
- [ ] **Follower Notifications**: Notify when new content is published
- [ ] **Creator Badges**: Recognition for quality content
- [ ] **Monetization Options**: Optional paid premium lessons (future)

### Priority 2: Advanced Learning Features

#### Spaced Repetition System (SRS)
- [ ] **Vocabulary Deck**: Auto-generated from encountered words
- [ ] **Smart Review Scheduling**: Spaced repetition algorithm (SM-2 or similar)
- [ ] **Flashcards**: Integrated flashcard review
- [ ] **Retention Analytics**: Track what's being remembered/forgotten

#### Adaptive Learning
- [ ] **AI Difficulty Adjustment**: Dynamically adjust content difficulty
- [ ] **Personalized Recommendations**: ML-based lesson suggestions
- [ ] **Learning Path Generator**: Custom curriculum based on goals
- [ ] **Weakness Detection**: Identify and target weak areas

#### Multi-Modal Learning
- [ ] **Reading Comprehension**: Text-only exercises
- [ ] **Dictation**: Type what you hear
- [ ] **Speaking Assessment**: Speech recognition and scoring
- [ ] **Writing Prompts**: Creative writing exercises based on content

### Priority 3: Content & Language Expansion

#### New Content Types
- [ ] **Podcast Integration**: Support for audio-only content
- [ ] **TV Show/Movie Support**: Long-form video content
- [ ] **User-Uploaded Media**: Allow custom video uploads
- [ ] **Text-Based Lessons**: Support non-video content (articles, stories)

#### Language Support
- [ ] **Expand to 20+ Languages**: Prioritize high-demand languages
- [ ] **Rare Language Support**: Community-driven content for less common languages
- [ ] **Dialect Variations**: Support regional variations (e.g., Mexican vs. Spanish Spanish)
- [ ] **Sign Languages**: Video-based sign language learning (experimental)

#### Teacher & Classroom Tools
- [ ] **Classroom Mode**: Teacher dashboard for student management
- [ ] **Assignment System**: Assign lessons to students
- [ ] **Student Analytics**: Track class progress
- [ ] **LMS Integration**: Export to Google Classroom, Canvas, etc.
- [ ] **Bulk Account Creation**: Easy student onboarding

---

## Long-Term Vision (2027+)

### Priority 1: AI Intelligence Layer

#### AI Tutoring
- [ ] **Conversational AI**: Real-time chat-based language practice
- [ ] **Contextual Feedback**: Explain why answers are right/wrong
- [ ] **Question Answering**: Ask questions about grammar, vocabulary, culture
- [ ] **Pronunciation Coaching**: AI analysis of spoken attempts

#### Content Intelligence
- [ ] **Auto-Generated Lessons**: AI creates complete lessons from any video
- [ ] **Cultural Context**: AI-powered cultural notes and explanations
- [ ] **Translation Improvement**: Fine-tuned models for better translations
- [ ] **Difficulty Estimation**: AI-based content difficulty scoring

### Priority 2: Native Mobile Apps

#### iOS & Android Apps
- [ ] **Native Performance**: Fast, smooth mobile experience
- [ ] **Offline Mode**: Download lessons for offline learning
- [ ] **Push Notifications**: Reminders and streak notifications
- [ ] **Mobile-First Activities**: Touch-optimized interactive exercises
- [ ] **Background Audio**: Listen while using other apps

#### Cross-Platform Sync
- [ ] **Progress Syncing**: Seamless sync across devices
- [ ] **Cloud Saves**: Automatic backup of user data
- [ ] **Handoff**: Start on web, continue on mobile

### Priority 3: Marketplace & Monetization

#### Content Marketplace
- [ ] **Premium Content**: Creators can sell high-quality lessons
- [ ] **Revenue Sharing**: Creators earn from their content
- [ ] **Subscriptions**: Monthly/yearly subscriptions for premium features
- [ ] **Enterprise Plans**: Bulk licensing for schools/organizations

#### Premium Features
- [ ] **Unlimited TTS Audio**: Remove limits for paid users
- [ ] **Advanced Analytics**: Detailed learning insights
- [ ] **AI Tutor Access**: Premium conversational AI
- [ ] **Ad-Free Experience**: Remove ads for subscribers
- [ ] **Priority Support**: Fast customer service

### Priority 4: Accessibility & Inclusion

#### Accessibility Features
- [ ] **Screen Reader Support**: Full WCAG 2.1 AA compliance
- [ ] **Keyboard Navigation**: Complete keyboard accessibility
- [ ] **High Contrast Mode**: Visual accessibility options
- [ ] **Adjustable Text Size**: User-controlled font sizing
- [ ] **Dyslexia-Friendly**: OpenDyslexic font option

#### Global Reach
- [ ] **Low-Bandwidth Mode**: Optimized for slow connections
- [ ] **Simplified UI**: Lite version for feature phones
- [ ] **Multi-Currency**: Support local payment methods
- [ ] **Localized Interface**: Platform UI in multiple languages

---

## Prioritization Framework

### Impact vs. Effort Matrix

**High Impact, Low Effort (Do First)**
- Progress tracking & motivation
- Content discovery improvements
- Performance optimizations
- Mobile responsiveness

**High Impact, High Effort (Plan & Execute)**
- Spaced repetition system
- Native mobile apps
- AI tutoring
- Adaptive learning

**Low Impact, Low Effort (Fill Gaps)**
- Social media sharing
- Profile customization
- Theme options

**Low Impact, High Effort (Avoid/Defer)**
- VR/AR integration
- Blockchain features
- Overly complex gamification

### Decision Criteria
1. **User Value**: Does this solve a real user problem?
2. **Technical Feasibility**: Can we build this with current resources?
3. **Strategic Alignment**: Does this support our mission and vision?
4. **Resource Requirements**: Time, cost, expertise needed?
5. **Risk Assessment**: What could go wrong? How do we mitigate?
6. **Metrics Impact**: Will this move our key metrics?

---

## Success Criteria by Phase

### Near-Term (Q1-Q2 2026)
- 📈 30% increase in 7-day retention
- 📈 20% increase in daily active users
- 📈 50% reduction in lesson creation time
- 📈 3x more user-created content
- ⚡ <2s page load time
- ⚡ 99.9% uptime

### Medium-Term (Q3-Q4 2026)
- 👥 10,000+ registered users
- 👥 100+ active content creators
- 🎓 1,000+ teachers using platform
- 📚 500+ publicly available lessons
- 🌍 Support for 20+ languages
- 💰 Pilot monetization program launched

### Long-Term (2027+)
- 👥 100,000+ registered users
- 📱 50% mobile app usage
- 💵 Sustainable revenue model
- 🏆 Recognized leader in video-based language learning
- 🌍 50+ languages supported
- 🤖 Advanced AI features live

---

## Risk Mitigation

### Technical Risks
- **TTS API Costs**: Monitor usage, implement rate limiting, explore alternative providers
- **YouTube API Changes**: Build robust scraping fallbacks, diversify content sources
- **Scalability Bottlenecks**: Regular performance audits, horizontal scaling strategy
- **Data Loss**: Automated backups, disaster recovery plan

### Business Risks
- **User Acquisition**: Content marketing, SEO, teacher partnerships, word-of-mouth
- **Monetization Challenges**: Freemium model, premium features, B2B sales
- **Competition**: Focus on unique differentiators, community building
- **Regulatory Compliance**: Copyright concerns (fair use), GDPR/CCPA compliance

### Operational Risks
- **Content Quality**: Community moderation, quality standards, creator guidelines
- **Support Burden**: Self-service help, comprehensive documentation, community forums
- **Team Capacity**: Prioritize ruthlessly, open-source contributions, automation

---

*This roadmap is reviewed and updated quarterly based on user feedback, metrics, and strategic priorities.*
