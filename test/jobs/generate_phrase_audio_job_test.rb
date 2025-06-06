require "test_helper"

class GeneratePhraseAudioJobTest < ActiveJob::TestCase
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

  test "should generate and attach audio successfully" do
    # Mock the Azure TTS service to avoid external API calls
    mock_wav_io = StringIO.new("fake_wav_content")
    Phrase.stubs(:synthesize_speech).returns(mock_wav_io)
    
    # Ensure no audio is initially attached
    @phrase.l1_audio.purge if @phrase.l1_audio.attached?
    
    # Perform the job
    GeneratePhraseAudioJob.perform_now(@phrase.id)
    
    # Reload phrase to get updated attachments
    @phrase.reload
    
    # Verify the audio was attached
    assert @phrase.l1_audio.attached?, "l1_audio should be attached after job execution"
    assert_equal "audio/wav", @phrase.l1_audio.content_type
    assert @phrase.l1_audio.filename.to_s.include?("phrase_#{@phrase.id}_l1_")
  end

  test "should handle missing phrase gracefully" do
    # Job should be discarded when phrase doesn't exist
    assert_nothing_raised do
      GeneratePhraseAudioJob.perform_now(99999)  # Non-existent phrase ID
    end
  end

  test "should handle phrase without text_l1" do
    # Create phrase without text_l1
    phrase_no_text = Phrase.create!(
      text_l1: "",
      text_l2: "Hola mundo",
      l1: @l1_language,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )
    
    # Job should exit early without errors
    assert_nothing_raised do
      GeneratePhraseAudioJob.perform_now(phrase_no_text.id)
    end
    
    # No audio should be attached
    phrase_no_text.reload
    assert_not phrase_no_text.l1_audio.attached?
  end

  test "should handle phrase without l1 language" do
    # Create phrase without l1 language
    phrase_no_lang = Phrase.create!(
      text_l1: "Hello world",
      text_l2: "Hola mundo",
      l1: nil,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )
    
    # Job should exit early without errors
    assert_nothing_raised do
      GeneratePhraseAudioJob.perform_now(phrase_no_lang.id)
    end
    
    # No audio should be attached
    phrase_no_lang.reload
    assert_not phrase_no_lang.l1_audio.attached?
  end

  test "should retry on TTS service errors" do
    # Mock TTS service to raise an error
    Phrase.stubs(:synthesize_speech).raises(StandardError.new("TTS service unavailable"))
    
    # Job should raise error for retry
    assert_raises(StandardError) do
      GeneratePhraseAudioJob.perform_now(@phrase.id)
    end
  end

  test "should retry when TTS returns nil" do
    # Mock TTS service to return nil
    Phrase.stubs(:synthesize_speech).returns(nil)
    
    # Job should raise error for retry
    assert_raises(StandardError) do
      GeneratePhraseAudioJob.perform_now(@phrase.id)
    end
  end

  test "should be queued on the default queue" do
    assert_equal "default", GeneratePhraseAudioJob.new.queue_name
  end
end
