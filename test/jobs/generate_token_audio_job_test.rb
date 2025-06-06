require "test_helper"

class GenerateTokenAudioJobTest < ActiveJob::TestCase
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
    
    # Create test token_translation
    @token_translation = TokenTranslation.create!(
      phrase: @phrase,
      l1_start_index: 0,
      l1_end_index: 5,
      l2_start_index: 0,
      l2_end_index: 4
    )
  end

  test "performs job successfully with valid token_translation" do
    # Mock the TTS service to return a StringIO object (simulating WAV data)
    mock_wav_io = StringIO.new("fake_wav_data")
    
    TokenTranslation.stub(:synthesize_speech, mock_wav_io) do
      perform_enqueued_jobs do
        GenerateTokenAudioJob.perform_later(@token_translation.id)
      end
    end
    
    # Reload to get the attached audio
    @token_translation.reload
    assert @token_translation.l1_audio.attached?, "l1_audio should be attached after job execution"
  end

  test "skips audio generation when original_text is blank" do
    # Create token_translation with indices that result in blank original_text
    token_translation = TokenTranslation.create!(
      phrase: @phrase,
      l1_start_index: 15, # Beyond phrase text length
      l1_end_index: 20,
      l2_start_index: 0,
      l2_end_index: 4
    )
    
    # Should not call synthesize_speech
    TokenTranslation.stub(:synthesize_speech, -> (*args) { raise "Should not be called" }) do
      perform_enqueued_jobs do
        GenerateTokenAudioJob.perform_later(token_translation.id)
      end
    end
    
    token_translation.reload
    assert_not token_translation.l1_audio.attached?, "l1_audio should not be attached when original_text is blank"
  end

  test "skips audio generation when phrase.l1 language is missing" do
    # Create phrase without l1 language
    phrase_without_l1 = Phrase.create!(
      text_l1: "Hello world",
      text_l2: "Hola mundo", 
      l1: nil,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )
    
    token_translation = TokenTranslation.create!(
      phrase: phrase_without_l1,
      l1_start_index: 0,
      l1_end_index: 5,
      l2_start_index: 0,
      l2_end_index: 4
    )
    
    # Should not call synthesize_speech
    TokenTranslation.stub(:synthesize_speech, -> (*args) { raise "Should not be called" }) do
      perform_enqueued_jobs do
        GenerateTokenAudioJob.perform_later(token_translation.id)
      end
    end
    
    token_translation.reload
    assert_not token_translation.l1_audio.attached?, "l1_audio should not be attached when phrase.l1 is missing"
  end

  test "handles TTS service errors gracefully" do
    # Mock the TTS service to raise an error
    TokenTranslation.stub(:synthesize_speech, -> (*args) { raise StandardError.new("TTS service error") }) do
      assert_raises(StandardError) do
        perform_enqueued_jobs do
          GenerateTokenAudioJob.perform_later(@token_translation.id)
        end
      end
    end
    
    @token_translation.reload
    assert_not @token_translation.l1_audio.attached?, "l1_audio should not be attached when TTS fails"
  end

  test "handles TTS service returning nil" do
    # Mock the TTS service to return nil
    TokenTranslation.stub(:synthesize_speech, nil) do
      assert_raises(StandardError) do
        perform_enqueued_jobs do
          GenerateTokenAudioJob.perform_later(@token_translation.id)
        end
      end
    end
    
    @token_translation.reload
    assert_not @token_translation.l1_audio.attached?, "l1_audio should not be attached when TTS returns nil"
  end

  test "handles deleted token_translation gracefully" do
    token_translation_id = @token_translation.id
    @token_translation.destroy
    
    # Should not raise an error due to discard_on ActiveRecord::RecordNotFound
    perform_enqueued_jobs do
      GenerateTokenAudioJob.perform_later(token_translation_id)
    end
  end

  test "generates correct filename for audio attachment" do
    mock_wav_io = StringIO.new("fake_wav_data")
    
    TokenTranslation.stub(:synthesize_speech, mock_wav_io) do
      perform_enqueued_jobs do
        GenerateTokenAudioJob.perform_later(@token_translation.id)
      end
    end
    
    @token_translation.reload
    filename = @token_translation.l1_audio.filename.to_s
    assert_match(/token_translation_#{@token_translation.id}_l1_\d+\.wav/, filename)
  end

  test "uses correct text and language for TTS synthesis" do
    expected_text = @token_translation.original_text
    expected_lang = @token_translation.phrase.l1.iso_name
    
    # Capture the arguments passed to synthesize_speech
    captured_args = nil
    mock_synthesize = ->(text:, lang:) {
      captured_args = { text: text, lang: lang }
      StringIO.new("fake_wav_data")
    }
    
    TokenTranslation.stub(:synthesize_speech, mock_synthesize) do
      perform_enqueued_jobs do
        GenerateTokenAudioJob.perform_later(@token_translation.id)
      end
    end
    
    assert_equal expected_text, captured_args[:text]
    assert_equal expected_lang, captured_args[:lang]
  end

  test "retries on StandardError with exponential backoff" do
    job = GenerateTokenAudioJob.new(@token_translation.id)
    
    # Check retry configuration
    assert_equal 3, job.class.retry_on_list.first[:attempts]
    assert_equal :exponentially_longer, job.class.retry_on_list.first[:wait]
  end

  test "discards job on ActiveRecord::RecordNotFound" do
    job = GenerateTokenAudioJob.new(@token_translation.id)
    
    # Check discard configuration
    discard_config = job.class.discard_on_list.first
    assert_equal ActiveRecord::RecordNotFound, discard_config[:exception]
  end
end
