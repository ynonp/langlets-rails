# Contributing to Langlets

Thank you for your interest in contributing to Langlets! We're excited to have you join our community of developers, educators, and language enthusiasts working to make language learning accessible to everyone.

## 🌟 How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates. When creating a bug report, include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples** - Include links, screenshots, or code snippets
- **Describe the behavior you observed** and explain what you expected to see
- **Include details about your environment** (OS, browser, Ruby version, etc.)

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:

- **Use a clear and descriptive title**
- **Provide a detailed description** of the suggested enhancement
- **Explain why this enhancement would be useful** to most Langlets users
- **List any similar features** in other applications if applicable

### Your First Code Contribution

Unsure where to begin? Look for issues labeled:

- `good first issue` - Issues suitable for newcomers
- `help wanted` - Issues where we need community help
- `documentation` - Improvements or additions to documentation

### Pull Requests

1. **Fork the repository** and create your branch from `main`
2. **Follow the coding style** of the project
3. **Write clear, commented code**
4. **Add tests** for any new functionality
5. **Ensure the test suite passes** - Run `./bin/rails test`
6. **Update documentation** as needed
7. **Write a good commit message** - Be clear and descriptive

## 📋 Development Process

### Before You Start

1. **Read the architecture document** - `architecture.md` contains crucial information
2. **Review the database schema** - `db/schema.rb` shows the data model
3. **Create a plan** - Think through your changes before coding
4. **Discuss large changes** - Open an issue first for significant features

### Setting Up Your Development Environment

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/langlets-rails.git
cd langlets-rails

# Add upstream remote
git remote add upstream https://github.com/ynonp/langlets-rails.git

# Install dependencies
bundle install
npm install

# Setup database
./bin/rails db:create db:migrate db:seed

# Start development server
./bin/dev
```

### Development Guidelines

#### General Principles

- **Make minimal changes** - Focus on solving the specific problem
- **Don't break existing functionality** - The system is in production
- **Follow existing patterns** - Match the style of surrounding code
- **Test your changes** - Add tests and ensure existing tests pass
- **Update architecture.md** - Document new features and changes

#### Ruby/Rails Best Practices

- Follow Rails conventions and community standards
- Use `Time.zone.now` instead of `Time.current`
- Prefer strong parameters and model validations
- Use ActiveRecord associations properly
- Keep controllers thin, models fat

#### JavaScript/Stimulus Best Practices

- Use `data-action` attributes for Stimulus controllers
- Keep controllers focused and single-purpose
- After adding new Stimulus controllers, run:
  ```bash
  ./bin/rails stimulus:manifest:update
  ```

#### Database

- Write reversible migrations
- Add appropriate indexes for performance
- Use foreign keys for referential integrity
- Test migrations in both directions

#### Testing

- Write unit tests for models
- Write integration tests for complex workflows
- Use system tests for end-to-end features
- Aim for meaningful test coverage

### Code Style

We follow standard Ruby and JavaScript conventions:

- **Ruby**: Follow Rubocop Rails Omakase guidelines
- **JavaScript**: Use consistent modern ES6+ syntax
- **CSS**: Use Tailwind CSS utility classes
- **Indentation**: 2 spaces (no tabs)
- **Line length**: Keep lines under 120 characters when possible

Run linters before submitting:

```bash
# Ruby
bundle exec rubocop

# Run auto-fix for simple issues
bundle exec rubocop -a
```

## 🧪 Testing

### Running Tests

```bash
# Run all tests
./bin/rails test

# Run specific test file
./bin/rails test test/models/lesson_test.rb

# Run system tests
./bin/rails test:system

# Run with coverage
COVERAGE=true ./bin/rails test
```

### Writing Tests

- Test files go in `test/` directory
- Use fixtures for test data when appropriate
- Use factories for complex object creation
- Mock external API calls

## 📝 Commit Guidelines

### Commit Message Format

```
<type>: <subject>

<body>

<footer>
```

### Types

- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation only changes
- `style`: Code style changes (formatting, semicolons, etc.)
- `refactor`: Code refactoring without behavior change
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Maintenance tasks, dependency updates

### Example

```
feat: Add Arabic language support

- Add Arabic language to language selection
- Configure RTL text rendering
- Add Arabic TTS voice mapping
- Update tests for Arabic text processing

Closes #123
```

## 🔒 Security

If you discover a security vulnerability, please email security@langlets.app instead of using the issue tracker. We take security seriously and will address issues promptly.

## 📚 Resources

- [Architecture Documentation](architecture.md)
- [Database Schema](db/schema.rb)
- [Rails Guides](https://guides.rubyonrails.org/)
- [Stimulus Handbook](https://stimulus.hotwired.dev/handbook/introduction)
- [Tailwind CSS Docs](https://tailwindcss.com/docs)

## 🎯 Areas Seeking Contributors

We especially welcome contributions in these areas:

### High Priority

- 🌐 **Adding more languages** - Expand language pair support
- ♿ **Accessibility improvements** - WCAG compliance, screen reader support
- 🐛 **Bug fixes** - Help us maintain quality
- 📝 **Documentation** - Tutorials, guides, API docs

### Medium Priority

- 🎨 **UI/UX enhancements** - Improve user experience
- 🧪 **Test coverage** - Increase automated test coverage
- 🚀 **Performance optimization** - Speed and efficiency improvements
- 🔌 **New integrations** - Connect with more services

### Long Term

- 📱 **Mobile app development** - iOS/Android native apps
- 🎮 **Gamification** - Badges, achievements, leaderboards
- 🤖 **AI enhancements** - Smarter personalization
- 🌍 **Community features** - Social learning, sharing

## 💬 Communication

- **GitHub Issues** - Bug reports and feature requests
- **GitHub Discussions** - Questions and community chat
- **Pull Request Comments** - Code review and technical discussion

## 📜 Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inspiring community for all. We pledge to make participation in our project a harassment-free experience for everyone, regardless of age, body size, disability, ethnicity, gender identity, level of experience, nationality, personal appearance, race, religion, or sexual identity and orientation.

### Our Standards

**Positive behaviors include:**
- Being respectful and inclusive
- Welcoming newcomers warmly
- Accepting constructive criticism gracefully
- Focusing on what's best for the community
- Showing empathy towards others

**Unacceptable behaviors include:**
- Harassment, trolling, or insulting comments
- Personal or political attacks
- Public or private harassment
- Publishing others' private information
- Conduct that could be considered inappropriate in a professional setting

### Enforcement

Project maintainers have the right to remove, edit, or reject comments, commits, code, issues, and other contributions that don't align with this Code of Conduct. Instances of abusive, harassing, or otherwise unacceptable behavior may be reported by contacting the project team.

## 🙏 Thank You!

Your contributions make Langlets better for everyone. Whether you're fixing bugs, adding features, improving documentation, or helping other users, every contribution matters.

Together, we're making language learning accessible to everyone! 🌍

---

**Questions?** Feel free to open a discussion or reach out to the maintainers.
