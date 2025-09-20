source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.2"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use sqlite3 as the database for Active Record
gem "sqlite3", ">= 2.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Bundle and transpile JavaScript [https://github.com/rails/jsbundling-rails]
gem "jsbundling-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Bundle and process CSS [https://github.com/rails/cssbundling-rails]
gem "cssbundling-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end

gem "solargraph", "~> 0.54.1", :group => :development

gem "pycall", "~> 1.5"

gem "gemini-ai", "~> 4.2"

gem "httparty", "~> 0.23.1"


gem "pg", "~> 1.5"

gem "ruby-openai", "~> 8.1"

gem "fiddle", "~> 1.1"

gem "langchainrb", "~> 0.19.5"

gem "ruby-anthropic", "~> 0.4.2"

gem "wavefile", "~> 1.1"

gem "aws-sdk-s3", "~> 1.189"

gem "devise", "~> 4.9"

gem "omniauth", "~> 2.1"

gem "omniauth-rails_csrf_protection", "~> 1.0"
gem "omniauth-google-oauth2", "~> 1.2"

gem "omniauth-github", "~> 2.0"

gem "cancancan", "~> 3.6"

gem "good_job", "~> 4.11"

gem "factory_bot", "~> 6.5"

gem "ruby_llm", "~> 1.8"

gem "ruby_llm-schema", "~> 0.1.0"

gem "opentelemetry-exporter-otlp", "~> 0.30.0"

gem "opentelemetry-instrumentation-net_http", "~> 0.23.0"

gem "tidewave", "~> 0.2.0", group: :development

gem "opentelemetry-instrumentation-all", "~> 0.80.0"

gem "deepl-rb", "~> 3.2"
