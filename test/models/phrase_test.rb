require "test_helper"

class PhraseTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  def setup
    # Create test languages
    @l1_language = Language.create!(
      iso_name: 'en',
      english_name: 'English',
      native_name: 'English'
    )
    
    @l2_language = Language.create!(
      iso_name: 'es', 
      english_name: 'Spanish',
      native_name: 'Español'
    )
    
    # Create test medium
    @medium = Medium.create!(
      url: 'https://example.com'
    )
  end

  test "should queue l1_audio generation job on create when text_l1 and l1 are present" do
    # Test that job is enqueued
    assert_enqueued_with(job: GeneratePhraseAudioJob) do
      phrase = Phrase.create!(
        text_l1: "Hello world",
        text_l2: "Hola mundo", 
        l1: @l1_language,
        l2: @l2_language,
        medium: @medium,
        timestamp: "00:01:30"
      )
    end
  end

  test "should queue l1_audio generation job on update when text_l1 changes" do
    phrase = Phrase.create!(
      text_l1: "Hello world",
      text_l2: "Hola mundo",
      l1: @l1_language,
      l2: @l2_language, 
      medium: @medium,
      timestamp: "00:01:30"
    )
    
    # Test that job is enqueued when updating text_l1
    assert_enqueued_with(job: GeneratePhraseAudioJob, args: [phrase.id]) do
      phrase.update!(text_l1: "Goodbye world")
    end
  end

  test "should queue l1_audio generation job on update when l1 language changes" do
    phrase = Phrase.create!(
      text_l1: "Hello world",
      text_l2: "Hola mundo",
      l1: @l1_language,
      l2: @l2_language,
      medium: @medium, 
      timestamp: "00:01:30"
    )
    
    # Create another language for testing
    new_language = Language.create!(
      iso_name: 'fr',
      english_name: 'French', 
      native_name: 'Français'
    )
    
    # Test that job is enqueued when updating l1 language
    assert_enqueued_with(job: GeneratePhraseAudioJob, args: [phrase.id]) do
      phrase.update!(l1: new_language)
    end
  end

  test "should not queue l1_audio generation job when text_l1 is blank" do
    assert_no_enqueued_jobs do
      phrase = Phrase.create!(
        text_l1: "",
        text_l2: "Hola mundo",
        l1: @l1_language,
        l2: @l2_language,
        medium: @medium,
        timestamp: "00:01:30"
      )
    end
  end

  test "should not queue l1_audio generation job when l1 language is missing" do
    # Test with a phrase that has l1 but missing iso_name instead
    language_without_iso = Language.create!(
      iso_name: nil,
      english_name: 'Test Language',
      native_name: 'Test'
    )
    
    assert_no_enqueued_jobs do
      phrase = Phrase.create!(
        text_l1: "Hello world",
        text_l2: "Hola mundo", 
        l1: language_without_iso,
        l2: @l2_language,
        medium: @medium,
        timestamp: "00:01:30"
      )
    end
  end

  test "should not queue job on update when text_l1 and l1 haven't changed" do
    phrase = Phrase.create!(
      text_l1: "Hello world",
      text_l2: "Hola mundo",
      l1: @l1_language,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )
    
    # Clear any jobs from create
    clear_enqueued_jobs
    
    # Update something other than text_l1 or l1 - should not enqueue job
    assert_no_enqueued_jobs do
      phrase.update!(text_l2: "Adios mundo")
    end
  end

  test "add_token_translation should use word indexes" do
    phrase = Phrase.create!(
      text_l1: "Hello beautiful world",  # Words: ["Hello", "beautiful", "world"]
      text_l2: "Hola mundo hermoso",     # Words: ["Hola", "mundo", "hermoso"]
      l1: @l1_language,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )
    
    token = phrase.add_token_translation("beautiful", 0, "mundo", 0)
    
    assert_not_nil token
    assert_equal 1, token.l1_start_index  # "beautiful" is word index 1
    assert_equal 1, token.l1_end_index
    assert_equal 1, token.l2_start_index  # "mundo" is word index 1  
    assert_equal 1, token.l2_end_index
  end

  test "add_token_translation should handle multi-word phrases" do
    phrase = Phrase.create!(
      text_l1: "Hello beautiful world",
      text_l2: "Hola mundo hermoso",
      l1: @l1_language,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )
    
    token = phrase.add_token_translation("beautiful world", 0, "mundo hermoso", 0)
    
    assert_not_nil token
    assert_equal 1, token.l1_start_index  # "beautiful world" starts at word 1
    assert_equal 2, token.l1_end_index    # ends at word 2
    assert_equal 1, token.l2_start_index  # "mundo hermoso" starts at word 1
    assert_equal 2, token.l2_end_index    # ends at word 2
  end

  test "find_token_translation should use word indexes" do
    phrase = Phrase.create!(
      text_l1: "Hello beautiful world",
      text_l2: "Hola mundo hermoso",
      l1: @l1_language,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )
    
    # Create a token translation
    original_token = phrase.add_token_translation("beautiful", 0, "mundo", 0)
    
    # Find it using the word-based method
    found_token = phrase.find_token_translation("beautiful", 0)
    
    assert_not_nil found_token
    assert_equal original_token.id, found_token.id
  end
end
