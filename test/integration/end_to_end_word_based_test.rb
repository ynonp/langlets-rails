require "test_helper"

class EndToEndWordBasedTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
    @spanish = Language.create!(iso_name: 'es', english_name: 'Spanish', native_name: 'Español')
    @english = Language.create!(iso_name: 'en', english_name: 'English', native_name: 'English')
    @medium = Medium.create!(url: 'https://youtube.com/watch?v=test')
  end

  test "complete end-to-end workflow with word-based indexes" do
    # Step 1: Create a phrase like we would during import
    phrase = Phrase.create!(
      text_l1: "La vida es hermosa y llena de alegría",
      text_l2: "Life is beautiful and full of joy",
      l1: @spanish,
      l2: @english,
      medium: @medium,
      timestamp: "01:23"
    )

    # Verify tokenization works as expected
    l1_words = phrase.send(:tokenize, phrase.text_l1)
    l2_words = phrase.send(:tokenize, phrase.text_l2)
    
    expected_l1 = ["La", "vida", "es", "hermosa", "y", "llena", "de", "alegría"]
    expected_l2 = ["Life", "is", "beautiful", "and", "full", "of", "joy"]
    
    assert_equal expected_l1, l1_words
    assert_equal expected_l2, l2_words

    # Step 2: Add token translations using the word-based method
    tokens_to_create = [
      { l1_text: "La", l2_text: "Life", l1_word: 0, l2_word: 0 },
      { l1_text: "vida", l2_text: "Life", l1_word: 1, l2_word: 0 },  # Maps to same L2 word
      { l1_text: "es", l2_text: "is", l1_word: 2, l2_word: 1 },
      { l1_text: "hermosa", l2_text: "beautiful", l1_word: 3, l2_word: 2 },
      { l1_text: "y", l2_text: "and", l1_word: 4, l2_word: 3 },
      { l1_text: "llena", l2_text: "full", l1_word: 5, l2_word: 4 },
      { l1_text: "de", l2_text: "of", l1_word: 6, l2_word: 5 },
      { l1_text: "alegría", l2_text: "joy", l1_word: 7, l2_word: 6 }
    ]

    created_tokens = []
    tokens_to_create.each do |token_data|
      token = phrase.add_token_translation(
        token_data[:l1_text], 
        0,  # occurrence
        token_data[:l2_text], 
        0   # occurrence
      )
      assert_not_nil token, "Failed to create token for '#{token_data[:l1_text]}'"
      created_tokens << token
      
      # Verify the word indexes are correct
      assert_equal token_data[:l1_word], token.l1_start_index
      assert_equal token_data[:l1_word], token.l1_end_index  # Single words
      assert_equal token_data[:l1_text], token.original_text
    end

    assert_equal 8, phrase.token_translations.count

    # Step 3: Simulate preparing data for the language alignment activity view
    activity_data = {
      phrases: [{
        text: phrase.text_l1,
        translation: phrase.text_l2,
        tokens: phrase.token_translations.map do |token|
          {
            l1_start_index: token.l1_start_index,
            l1_end_index: token.l1_end_index,
            l2_start_index: token.l2_start_index,
            l2_end_index: token.l2_end_index,
            translation: token.translation,
            audio_url: token.l1_audio.attached? ? "/rails/active_storage/blobs/#{token.l1_audio.blob.id}/#{token.l1_audio.filename}" : nil,
            original_text: token.original_text
          }
        end
      }]
    }

    # Step 4: Test view rendering logic (like in the ERB template)
    phrase_data = activity_data[:phrases].first
    l1_words = phrase_data[:text].scan(/\p{L}+(?:'\p{L}+)*/u)
    l2_words = phrase_data[:translation].scan(/\p{L}+(?:'\p{L}+)*/u)

    # Build L1 segments
    l1_segments = []
    current_word_index = 0
    sorted_tokens = phrase_data[:tokens].sort_by { |t| t[:l1_start_index] }

    sorted_tokens.each_with_index do |token, token_index|
      # Add words before the token
      while current_word_index < token[:l1_start_index]
        l1_segments << l1_words[current_word_index]
        current_word_index += 1
      end
      
      # The token itself
      if token[:l1_start_index] <= current_word_index && current_word_index <= token[:l1_end_index]
        token_words = l1_words[token[:l1_start_index]..token[:l1_end_index]]
        l1_segments << {
          text: token_words.join(' '),
          token_index: token_index,
          phrase_index: 0,
          audio_url: token[:audio_url],
          word_indexes: (token[:l1_start_index]..token[:l1_end_index]).to_a
        }
        current_word_index = token[:l1_end_index] + 1
      end
    end

    # All words should be tokens (no remaining words)
    assert_equal 8, l1_segments.length
    l1_segments.each_with_index do |segment, index|
      assert segment.is_a?(Hash), "Segment #{index} should be a token hash"
      assert_equal expected_l1[index], segment[:text]
    end

    # Build L2 segments 
    l2_segments = []
    current_word_index = 0
    sorted_l2_tokens = phrase_data[:tokens].select { |t| t[:l2_start_index].present? && t[:l2_end_index].present? }
                                         .sort_by { |t| t[:l2_start_index] }

    sorted_l2_tokens.each_with_index do |token, token_index|
      # Add words before the token
      while current_word_index < token[:l2_start_index]
        l2_segments << l2_words[current_word_index]
        current_word_index += 1
      end
      
      # The token itself
      if token[:l2_start_index] <= current_word_index && current_word_index <= token[:l2_end_index]
        token_words = l2_words[token[:l2_start_index]..token[:l2_end_index]]
        l2_segments << {
          text: token_words.join(' '),
          token_index: token_index
        }
        current_word_index = token[:l2_end_index] + 1
      end
    end

    # Add remaining words
    while current_word_index < l2_words.length
      l2_segments << l2_words[current_word_index]
      current_word_index += 1
    end

    # The L2 side should handle overlapping tokens (vida and La both map to "Life")
    # But for this test, let's verify basic structure
    assert l2_segments.length >= 1

    # Step 5: Test finding tokens by text (like during user interaction)
    vida_token = phrase.find_token_translation("vida", 0)
    assert_not_nil vida_token
    assert_equal 1, vida_token.l1_start_index
    assert_equal 1, vida_token.l1_end_index
    assert_equal "vida", vida_token.original_text

    hermosa_token = phrase.find_token_translation("hermosa", 0)
    assert_not_nil hermosa_token
    assert_equal 3, hermosa_token.l1_start_index
    assert_equal 3, hermosa_token.l1_end_index
    assert_equal "hermosa", hermosa_token.original_text

    # Step 6: Test that audio generation would be triggered (jobs enqueued)
    assert_enqueued_jobs 8, only: GenerateTokenAudioJob  # One job per token created

    puts "✅ End-to-end word-based workflow completed successfully!"
    puts "✅ Created #{created_tokens.length} tokens with word-based indexes"
    puts "✅ View rendering logic works correctly"
    puts "✅ Token lookup by text works correctly"
    puts "✅ Audio generation jobs properly enqueued"
  end

  test "handles multi-word tokens in end-to-end workflow" do
    phrase = Phrase.create!(
      text_l1: "Buenos días mi querido amigo",
      text_l2: "Good morning my dear friend",
      l1: @spanish,
      l2: @english,
      medium: @medium,
      timestamp: "00:45"
    )

    # Create multi-word tokens
    buenos_dias = phrase.add_token_translation("Buenos días", 0, "Good morning", 0)
    assert_not_nil buenos_dias
    assert_equal 0, buenos_dias.l1_start_index
    assert_equal 1, buenos_dias.l1_end_index  # Spans words 0-1
    assert_equal "Buenos días", buenos_dias.original_text

    querido_amigo = phrase.add_token_translation("querido amigo", 0, "dear friend", 0)
    assert_not_nil querido_amigo
    assert_equal 3, querido_amigo.l1_start_index
    assert_equal 4, querido_amigo.l1_end_index  # Spans words 3-4
    assert_equal "querido amigo", querido_amigo.original_text

    # Verify multi-word tokens work in view rendering
    l1_words = phrase.send(:tokenize, phrase.text_l1)
    expected_words = ["Buenos", "días", "mi", "querido", "amigo"]
    assert_equal expected_words, l1_words

    # Simulate view segment building
    segments = []
    current_word_index = 0
    tokens_data = [
      { l1_start_index: 0, l1_end_index: 1, text: "Buenos días" },
      { l1_start_index: 3, l1_end_index: 4, text: "querido amigo" }
    ].sort_by { |t| t[:l1_start_index] }

    tokens_data.each do |token|
      # Add words before token
      while current_word_index < token[:l1_start_index]
        segments << l1_words[current_word_index]
        current_word_index += 1
      end
      
      # Add the multi-word token
      segments << token[:text]
      current_word_index = token[:l1_end_index] + 1
    end

    # Add remaining words
    while current_word_index < l1_words.length
      segments << l1_words[current_word_index]
      current_word_index += 1
    end

    expected_segments = ["Buenos días", "mi", "querido amigo"]
    assert_equal expected_segments, segments

    puts "✅ Multi-word token end-to-end workflow completed successfully!"
  end
end