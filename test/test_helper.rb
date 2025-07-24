ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "json"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Set up required scripts before each test
    setup :setup_scripts

    # Set up required scripts for multi-script text functionality
    def setup_scripts
      Script.find_or_create_by(code: 'Latn') { |s| s.name = 'Latin' }
      Script.find_or_create_by(code: 'Hebr') { |s| s.name = 'Hebrew' }
      Script.find_or_create_by(code: 'Cyrl') { |s| s.name = 'Cyrillic' }
      Script.find_or_create_by(code: 'Arab') { |s| s.name = 'Arabic' }
    end

    # Helper method to create a phrase with multi-script texts
    def create_phrase_with_texts(l1:, l2:, medium:, text_l1:, text_l2:, **attrs)
      latin_script = Script.find_or_create_by(code: 'Latn') { |s| s.name = 'Latin' }
      
      # Create multi-script texts
      l1_text = MultiScriptText.create!(language: l1)
      l1_script = l1.default_script || latin_script
      l1_text.script_variants.create!(script: l1_script, content: text_l1)
      
      l2_text = MultiScriptText.create!(language: l2)
      l2_script = l2.default_script || latin_script
      l2_text.script_variants.create!(script: l2_script, content: text_l2)
      
      # Create phrase
      Phrase.create!(
        text_l1_multi: l1_text,
        text_l2_multi: l2_text,
        l1: l1,
        l2: l2,
        medium: medium,
        **attrs
      )
    end

    # Add more helper methods to be used by all tests here...
  end
end
