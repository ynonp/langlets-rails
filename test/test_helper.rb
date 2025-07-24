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

    # Add more helper methods to be used by all tests here...
    
    # Helper method to create phrases with text using the new schema
    def create_phrase_with_text(attributes)
      text_l1 = attributes.delete(:text_l1)
      text_l2 = attributes.delete(:text_l2)
      
      phrase = Phrase.create!(attributes)
      
      if text_l1.present?
        l1_script = attributes[:l1]&.default_script || Script.find_by(name: 'latin')
        l1_phrase_text = PhraseText.create!(content: text_l1, script: l1_script)
        PhraseTextAssignment.create!(
          phrase: phrase, 
          phrase_text: l1_phrase_text, 
          language_role: :l1, 
          primary: true
        )
      end
      
      if text_l2.present?
        l2_script = attributes[:l2]&.default_script || Script.find_by(name: 'latin')
        l2_phrase_text = PhraseText.create!(content: text_l2, script: l2_script)
        PhraseTextAssignment.create!(
          phrase: phrase, 
          phrase_text: l2_phrase_text, 
          language_role: :l2, 
          primary: true
        )
      end
      
      phrase
    end
  end
end
