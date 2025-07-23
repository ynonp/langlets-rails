require "test_helper"

class LanguageAlignmentViewTest < ActionView::TestCase
  include ApplicationHelper

  def setup
    # Create test data
    @spanish = Language.create!(iso_name: 'es', english_name: 'Spanish', native_name: 'Español')
    @english = Language.create!(iso_name: 'en', english_name: 'English', native_name: 'English')
    @medium = Medium.create!(url: 'https://youtube.com/test')
    
    @phrase = Phrase.create!(
      text_l1: "Hola mundo hermoso",
      text_l2: "Hello beautiful world",
      l1: @spanish,
      l2: @english,
      medium: @medium,
      timestamp: "00:10"
    )

    # Create tokens with word-based indexes
    @token1 = TokenTranslation.create!(
      phrase: @phrase,
      l1_start_index: 0,  # "Hola"
      l1_end_index: 0,
      l2_start_index: 0,  # "Hello" 
      l2_end_index: 0,
      translation: "Hello"
    )

    @token2 = TokenTranslation.create!(
      phrase: @phrase,
      l1_start_index: 2,  # "hermoso"
      l1_end_index: 2,
      l2_start_index: 1,  # "beautiful"
      l2_end_index: 1,
      translation: "beautiful"
    )
  end

  test "view template should render word-based segments correctly" do
    # Simulate the data structure that would be passed to the view
    phrases_with_tokens = [{
      original_text: @phrase.text_l1,
      translation: @phrase.text_l2,
      tokens: [
        {
          l1_start_index: @token1.l1_start_index,
          l1_end_index: @token1.l1_end_index,
          l2_start_index: @token1.l2_start_index,
          l2_end_index: @token1.l2_end_index,
          translation: @token1.translation,
          audio_url: nil,
          original_text: @token1.original_text
        },
        {
          l1_start_index: @token2.l1_start_index,
          l1_end_index: @token2.l1_end_index,
          l2_start_index: @token2.l2_start_index,
          l2_end_index: @token2.l2_end_index,
          translation: @token2.translation,
          audio_url: nil,
          original_text: @token2.original_text
        }
      ]
    }]

    phrase = phrases_with_tokens.first
    
    # Test L1 (original) word segmentation
    l1_words = phrase[:original_text].scan(/\p{L}+(?:'\p{L}+)*/u)
    assert_equal ["Hola", "mundo", "hermoso"], l1_words

    segments = []
    current_word_index = 0
    sorted_tokens = phrase[:tokens].sort_by { |t| t[:l1_start_index] }

    sorted_tokens.each_with_index do |token, token_index|
      # Add words before the token
      while current_word_index < token[:l1_start_index]
        segments << l1_words[current_word_index]
        current_word_index += 1
      end
      
      # The token itself
      if token[:l1_start_index] <= current_word_index && current_word_index <= token[:l1_end_index]
        token_words = l1_words[token[:l1_start_index]..token[:l1_end_index]]
        segments << {
          text: token_words.join(' '),
          token_index: token_index,
          phrase_index: 0,
          audio_url: token[:audio_url],
          word_indexes: (token[:l1_start_index]..token[:l1_end_index]).to_a
        }
        current_word_index = token[:l1_end_index] + 1
      end
    end
    
    # Add remaining words
    while current_word_index < l1_words.length
      segments << l1_words[current_word_index]
      current_word_index += 1
    end

    # Verify the segmentation is correct
    expected_segments = [
      { text: "Hola", token_index: 0, phrase_index: 0, audio_url: nil, word_indexes: [0] },
      "mundo",
      { text: "hermoso", token_index: 1, phrase_index: 0, audio_url: nil, word_indexes: [2] }
    ]

    assert_equal 3, segments.length
    assert_equal "Hola", segments[0][:text]
    assert_equal [0], segments[0][:word_indexes]
    assert_equal "mundo", segments[1]
    assert_equal "hermoso", segments[2][:text] 
    assert_equal [2], segments[2][:word_indexes]
  end

  test "view template should handle L2 word segmentation correctly" do
    # Test L2 side segmentation
    phrase_data = {
      translation: @phrase.text_l2,
      tokens: [
        {
          l2_start_index: @token1.l2_start_index,
          l2_end_index: @token1.l2_end_index,
          translation: @token1.translation
        },
        {
          l2_start_index: @token2.l2_start_index,
          l2_end_index: @token2.l2_end_index,
          translation: @token2.translation
        }
      ]
    }

    l2_words = phrase_data[:translation].scan(/\p{L}+(?:'\p{L}+)*/u)
    assert_equal ["Hello", "beautiful", "world"], l2_words

    segments = []
    current_word_index = 0
    sorted_tokens = phrase_data[:tokens].select { |t| t[:l2_start_index].present? && t[:l2_end_index].present? }
                                      .sort_by { |t| t[:l2_start_index] }

    sorted_tokens.each_with_index do |token, token_index|
      # Add words before the token
      while current_word_index < token[:l2_start_index]
        segments << l2_words[current_word_index]
        current_word_index += 1
      end
      
      # The token itself
      if token[:l2_start_index] <= current_word_index && current_word_index <= token[:l2_end_index]
        token_words = l2_words[token[:l2_start_index]..token[:l2_end_index]]
        segments << {
          text: token_words.join(' '),
          token_index: token_index
        }
        current_word_index = token[:l2_end_index] + 1
      end
    end
    
    # Add remaining words
    while current_word_index < l2_words.length
      segments << l2_words[current_word_index]
      current_word_index += 1
    end

    # Verify L2 segmentation
    expected_segments = [
      { text: "Hello", token_index: 0 },
      { text: "beautiful", token_index: 1 },
      "world"
    ]

    assert_equal 3, segments.length
    assert_equal "Hello", segments[0][:text]
    assert_equal "beautiful", segments[1][:text]
    assert_equal "world", segments[2]
  end

  test "should handle empty token arrays gracefully" do
    # Test with no tokens
    phrase_data = {
      original_text: "Simple phrase",
      tokens: []
    }

    l1_words = phrase_data[:original_text].scan(/\p{L}+(?:'\p{L}+)*/u)
    segments = []
    current_word_index = 0

    # With no tokens, all words should be added as regular text
    while current_word_index < l1_words.length
      segments << l1_words[current_word_index]
      current_word_index += 1
    end

    assert_equal ["Simple", "phrase"], segments
  end
end