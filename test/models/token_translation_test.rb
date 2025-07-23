require "test_helper"

class TokenTranslationTest < ActiveSupport::TestCase
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

    # Create test phrase
    @phrase = Phrase.create!(
      text_l1: "Hello world",
      text_l2: "Hola mundo", 
      l1: @l1_language,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )
  end

  test "should queue l1_audio generation job on create when original_text and phrase.l1 are present" do
    # Test that job is enqueued
    assert_enqueued_with(job: GenerateTokenAudioJob) do
      token_translation = TokenTranslation.create!(
        phrase: @phrase,
        l1_start_index: 0,
        l1_end_index: 5,
        l2_start_index: 0,
        l2_end_index: 4
      )
    end
  end

  test "should queue l1_audio generation job on update when l1_start_index changes" do
    token_translation = TokenTranslation.create!(
      phrase: @phrase,
      l1_start_index: 0,
      l1_end_index: 5,
      l2_start_index: 0,
      l2_end_index: 4
    )
    
    # Test that job is enqueued when updating l1_start_index
    assert_enqueued_with(job: GenerateTokenAudioJob, args: [token_translation.id]) do
      token_translation.update!(l1_start_index: 6)
    end
  end

  test "should queue l1_audio generation job on update when l1_end_index changes" do
    token_translation = TokenTranslation.create!(
      phrase: @phrase,
      l1_start_index: 0,
      l1_end_index: 5,
      l2_start_index: 0,
      l2_end_index: 4
    )
    
    # Test that job is enqueued when updating l1_end_index
    assert_enqueued_with(job: GenerateTokenAudioJob, args: [token_translation.id]) do
      token_translation.update!(l1_end_index: 11)
    end
  end

  test "should not queue l1_audio generation job when original_text is blank" do
    assert_no_enqueued_jobs do
      token_translation = TokenTranslation.create!(
        phrase: @phrase,
        l1_start_index: 15, # Beyond the phrase text length
        l1_end_index: 20,
        l2_start_index: 0,
        l2_end_index: 4
      )
    end
  end

  test "should not queue l1_audio generation job when phrase.l1 language is missing" do
    # This test might not be valid since l1 is a required field
    # Let's test with a phrase that has l1 but missing iso_name instead
    language_without_iso = Language.create!(
      iso_name: nil,
      english_name: 'Test Language',
      native_name: 'Test'
    )
    
    phrase_without_iso = Phrase.create!(
      text_l1: "Hello world",
      text_l2: "Hola mundo", 
      l1: language_without_iso,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )

    assert_no_enqueued_jobs do
      token_translation = TokenTranslation.create!(
        phrase: phrase_without_iso,
        l1_start_index: 0,
        l1_end_index: 5,
        l2_start_index: 0,
        l2_end_index: 4
      )
    end
  end

  test "should not queue l1_audio generation job on update when indices don't change" do
    token_translation = TokenTranslation.create!(
      phrase: @phrase,
      l1_start_index: 0,
      l1_end_index: 5,
      l2_start_index: 0,
      l2_end_index: 4
    )
    
    # Test that job is NOT enqueued when updating unrelated attributes
    assert_no_enqueued_jobs do
      token_translation.update!(l2_start_index: 5, l2_end_index: 9)
    end
  end

  test "should extract correct original_text based on indices" do
    token_translation = TokenTranslation.create!(
      phrase: @phrase,
      l1_start_index: 0,
      l1_end_index: 5,
      l2_start_index: 0,
      l2_end_index: 4
    )
    
    assert_equal "Hello", token_translation.original_text
    
    # Test different indices
    token_translation.update!(l1_start_index: 6, l1_end_index: 11)
    assert_equal "world", token_translation.original_text
  end

  test "should handle job queueing errors gracefully" do
    # Skip this test for now as it requires more complex mocking
    skip "Job queueing error handling needs better mocking setup"
  end

  test "should_generate_audio? returns correct boolean values" do
    # Test with valid data
    token_translation = TokenTranslation.new(
      phrase: @phrase,
      l1_start_index: 0,
      l1_end_index: 5,
      l2_start_index: 0,
      l2_end_index: 4
    )
    assert token_translation.send(:should_generate_audio?)
    
    # Test with missing phrase.l1
    phrase_without_l1 = Phrase.new(
      text_l1: "Hello world",
      l1: nil,
      l2: @l2_language,
      medium: @medium
    )
    token_translation_no_l1 = TokenTranslation.new(
      phrase: phrase_without_l1,
      l1_start_index: 0,
      l1_end_index: 5
    )
    assert_not token_translation_no_l1.send(:should_generate_audio?)
  end

  test "should_generate_audio_on_update? returns correct boolean values" do
    token_translation = TokenTranslation.create!(
      phrase: @phrase,
      l1_start_index: 0,
      l1_end_index: 5,
      l2_start_index: 0,
      l2_end_index: 4
    )
    
    # Simulate change to l1_start_index
    token_translation.l1_start_index = 6
    def token_translation.saved_change_to_l1_start_index?; true; end
    def token_translation.saved_change_to_l1_end_index?; false; end
    assert token_translation.send(:should_generate_audio_on_update?)
    
    # Simulate change to l1_end_index
    token_translation.l1_end_index = 11
    def token_translation.saved_change_to_l1_start_index?; false; end
    def token_translation.saved_change_to_l1_end_index?; true; end
    assert token_translation.send(:should_generate_audio_on_update?)
    
    # Simulate no changes to indices
    def token_translation.saved_change_to_l1_start_index?; false; end
    def token_translation.saved_change_to_l1_end_index?; false; end
    assert_not token_translation.send(:should_generate_audio_on_update?)
  end
end
