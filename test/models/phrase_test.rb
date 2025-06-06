require "test_helper"

class PhraseTest < ActiveSupport::TestCase
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
      name: 'Test Medium',
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
    assert_no_enqueued_jobs do
      phrase = Phrase.create!(
        text_l1: "Hello world",
        text_l2: "Hola mundo", 
        l1: nil,
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

  test "should handle job queueing errors gracefully" do
    # Mock GeneratePhraseAudioJob to raise an error
    GeneratePhraseAudioJob.stubs(:perform_later).raises(StandardError.new("Queue error"))
    
    # Phrase should still be created even if job queueing fails
    phrase = Phrase.create!(
      text_l1: "Hello world",
      text_l2: "Hola mundo",
      l1: @l1_language,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )
    
    assert phrase.persisted?, "Phrase should be saved even if job queueing fails"
  end
end
