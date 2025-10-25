# 🎵 Langlets - Language Learning Through Music

<p align="center">
  <strong>Transform YouTube videos into interactive language lessons</strong>
</p>

<p align="center">
  <a href="https://langlets.app/">🌐 Live Demo</a> •
  <a href="#features">✨ Features</a> •
  <a href="#getting-started">🚀 Getting Started</a> •
  <a href="#contributing">🤝 Contributing</a>
</p>

---

## 🎯 About Langlets

**Langlets** (branded as **MúsicaLingo**) is an open-source language learning platform that revolutionizes how people learn languages through music and multimedia content. By converting YouTube videos into synchronized, interactive lessons with bilingual subtitles, word-level translations, and pronunciation practice, Langlets makes language learning engaging and effective.

🔗 **[Try it live at langlets.app](https://langlets.app/)**

### Why Langlets?

- 🎵 **Learn through music** - Songs are proven to enhance language retention
- 🎯 **Word-level precision** - Click any word for instant translation
- 🗣️ **Pronunciation practice** - AI-generated audio for every phrase and word
- 📱 **Interactive exercises** - Multiple activity types keep learning engaging
- 🆓 **Open source** - Free to use, free to contribute, free to learn

---

## ✨ Features

### 🎬 Intelligent Content Processing
- **YouTube Integration** - Paste any YouTube URL to create a lesson
- **Automatic Subtitle Extraction** - Extract and synchronize bilingual text
- **Multi-Script Text Support** - Display content in multiple writing systems (Latin, Arabic, Hebrew, etc.)
- **Timestamped Phrases** - Every phrase synced perfectly with the video

### 🎓 Rich Learning Activities
- **Watch Video Activity** - Synchronized subtitles with original media
- **Match Phrases** - Connect translations to build comprehension
- **Sort Phrases** - Practice temporal and logical sequencing
- **Word Alignment** - Master word-level translation mapping
- **Pronunciation Practice** - Speak exercises with AI-generated reference audio
- **Listening Comprehension** - Identify words from audio
- **Q&A Exercises** - Test comprehension with targeted questions

### 🗣️ Advanced Audio Features
- **Azure Text-to-Speech Integration** - High-quality neural voices
- **Per-Phrase Audio** - Listen to complete sentences
- **Per-Word Audio** - Hear individual word pronunciations
- **Multiple Languages** - English, Spanish, French, Arabic, Hebrew support

### 🌐 Multilingual Architecture
- **Language Pairs** - Learn any supported language from any other
- **RTL Support** - Full right-to-left text rendering
- **Pronunciation Variants** - Regional accent support

### 📊 Progress Tracking
- **Activity Completion** - Track progress through exercises
- **Lesson Progress** - Monitor course advancement
- **User Authentication** - Personalized learning journeys
- **Achievement Ready** - Foundation for badges and certifications

---

## 🛠️ Technology Stack

### Backend
- **Ruby on Rails 8.0** - Modern full-stack framework
- **PostgreSQL** - Robust database with JSONB support
- **Active Storage** - Scalable file management
- **Devise** - Secure user authentication
- **Good Job** - Background job processing

### Frontend
- **Stimulus** - Modern JavaScript framework
- **Turbo** - SPA-like page acceleration
- **Tailwind CSS** - Utility-first styling
- **esbuild** - Fast JavaScript bundling

### External Services
- **Azure Cognitive Services** - Text-to-speech audio generation
- **YouTube API** - Video content extraction
- **AWS S3** - Production file storage

### AI & Machine Learning
- **Gemini AI** - Content generation and processing
- **OpenAI** - Language processing capabilities
- **Anthropic Claude** - Advanced AI features
- **LangChain** - LLM orchestration

---

## 🚀 Getting Started

### Prerequisites

- **Ruby 3.3.5** or higher
- **PostgreSQL** - Database server
- **Node.js** - For JavaScript dependencies
- **Bun** - Fast JavaScript package manager
- **Python** (optional) - For some AI features

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/ynonp/langlets-rails.git
   cd langlets-rails
   ```

2. **Install Ruby dependencies**
   ```bash
   bundle install
   ```

3. **Install JavaScript dependencies**
   ```bash
   npm install
   # or
   bun install
   ```

4. **Setup the database**
   ```bash
   ./bin/rails db:create
   ./bin/rails db:migrate
   ./bin/rails db:seed
   ```

5. **Configure environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your API keys (Azure, OpenAI, etc.)
   ```

6. **Start the development server**
   ```bash
   ./bin/dev
   ```

7. **Visit the application**
   
   Open [http://localhost:3000](http://localhost:3000) in your browser

### Development Credentials

For development, you can login with:
- **Username**: ynon@hey.com
- **Password**: 10203040

---

## 📚 Documentation

- **[Architecture Overview](architecture.md)** - Detailed system architecture
- **[Database Schema](db/schema.rb)** - Complete database structure
- **[API Integration](docs/api.md)** - External service integration (coming soon)

---

## 🏗️ Architecture Highlights

### Data Models
- **Courses & Lessons** - Hierarchical content organization
- **Activities** - Polymorphic exercise system using STI
- **Phrases & Tokens** - Granular text and translation storage
- **Multi-Script Texts** - Support for multiple writing systems
- **User Progress** - Comprehensive tracking system

### Key Design Patterns
- **Single Table Inheritance** - Flexible activity types
- **Polymorphic Associations** - Scalable file attachments
- **JSONB Storage** - Flexible workflow state management
- **Timestamp Synchronization** - Precise media alignment

### Content Pipeline
```
YouTube URL → Extract Audio/Subtitles → Generate Translations → 
Create Token Mappings → Generate TTS Audio → Build Activities → 
Structure into Lessons → Ready for Learning!
```

---

## 🧪 Testing

Run the test suite:

```bash
# Run all tests
./bin/rails test

# Run specific test file
./bin/rails test test/models/lesson_test.rb

# Run system tests
./bin/rails test:system
```

---

## 🤝 Contributing

We love contributions! Langlets is an open-source project, and we welcome contributions from developers, designers, educators, and language enthusiasts of all skill levels.

### How to Contribute

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. **Make your changes**
   - Write clear, commented code
   - Follow the existing code style
   - Add tests for new features
4. **Commit your changes**
   ```bash
   git commit -m 'Add some amazing feature'
   ```
5. **Push to your branch**
   ```bash
   git push origin feature/amazing-feature
   ```
6. **Open a Pull Request**

### Areas for Contribution

- 🌐 **Language Support** - Add new languages and voices
- 🎨 **UI/UX Improvements** - Enhance the user experience
- 🎯 **New Activity Types** - Create innovative learning exercises
- 🐛 **Bug Fixes** - Help us squash bugs
- 📝 **Documentation** - Improve guides and tutorials
- 🧪 **Testing** - Increase test coverage
- ♿ **Accessibility** - Make the platform more accessible
- 🚀 **Performance** - Optimize speed and efficiency
- 🔌 **Integrations** - Connect with more services

### Development Guidelines

- Read [architecture.md](architecture.md) before starting
- Review [db/schema.rb](db/schema.rb) to understand the data model
- Create a detailed plan before implementing features
- Follow Rails and React best practices
- Watch for breaking changes - the system is in production
- Update `architecture.md` after adding new features

### Code Style

- Follow Ruby community standards
- Use Stimulus controllers with `data-action` attributes
- Prefer `Time.zone.now` over `Time.current`
- Run `./bin/rails stimulus:manifest:update` after adding controllers

---

## 📋 Roadmap

- [ ] Mobile app (iOS/Android)
- [ ] Offline learning mode
- [ ] Community-contributed lessons
- [ ] Advanced progress analytics
- [ ] Gamification features
- [ ] Social learning features
- [ ] More language pairs
- [ ] AI-powered personalization
- [ ] Video upload support
- [ ] Speaking assessment with AI

---

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

---

## 🙏 Acknowledgments

- Thanks to all contributors who help make language learning accessible
- Azure Cognitive Services for text-to-speech capabilities
- The Rails community for an amazing framework
- YouTube for providing multimedia content

---

## 📞 Contact & Support

- **Website**: [langlets.app](https://langlets.app/)
- **Issues**: [GitHub Issues](https://github.com/ynonp/langlets-rails/issues)
- **Discussions**: [GitHub Discussions](https://github.com/ynonp/langlets-rails/discussions)

---

<p align="center">
  <strong>Made with ❤️ for language learners worldwide</strong>
  <br>
  <em>Learn languages through music, contribute to open source, make an impact</em>
</p>

---

## 🌟 Star Us!

If you find Langlets useful, please consider giving us a star ⭐ on GitHub. It helps others discover the project and motivates us to keep improving!
