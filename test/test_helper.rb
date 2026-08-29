ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock" # Object#stub — not loaded by rails/test_help
require "json"

Dir[Rails.root.join("test/support/**/*.rb")].sort.each { |file| require file }

# Rails draws routes lazily. Devise fills `Devise.mappings` from `devise_for`
# as part of drawing them, so a test whose very first action is `sign_in` —
# before anything has forced the routes to load — dies with "Could not find a
# valid mapping for #<User ...>". Which test that is depends on how the suite
# happens to be split across parallel workers, so it surfaces as a flake that
# follows the seed rather than the code. Draw them once, up front.
Rails.application.reload_routes_unless_loaded

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    include FactoryBot::Syntax::Methods

    # `I18n.locale` is thread-global and nothing resets it between tests, so a
    # test that visits a localized subdomain (`host! "he.langlets.app"`) leaves
    # the whole worker in Hebrew. Any later test in that process that renders a
    # translated string without making a request of its own — a service or model
    # test — then fails, but only for the seeds that happen to order them that
    # way. Resetting here makes those tests order-independent.
    teardown { I18n.locale = I18n.default_locale }
  end
end
