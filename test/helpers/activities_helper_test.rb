require 'test_helper'

class ActivitiesHelperTest < ActionView::TestCase
  setup do
    @medium = medium(:a_dios_le_pido)
    @english = languages(:english)
    @spanish = languages(:spanish)
    @latin_script = scripts(:latin)
  end

  def create_phrase(text_l1_content: "Hello world", text_l2_content: "Hola mundo")
    Phrase.create!(
      medium: @medium,
      timestamp: "01:30",
      l1: @english,
      l2: @spanish,
      text_l1_attributes: {
        language: @english,
        script_variants_attributes: [
          { script: @latin_script, content: text_l1_content }
        ]
      },
      text_l2_attributes: {
        language: @spanish,
        script_variants_attributes: [
          { script: @latin_script, content: text_l2_content }
        ]
      }
    )
  end

  def create_token_translation(phrase:, l1_start_index:, l1_end_index:, translation:)
    TokenTranslation.create!(
      phrase: phrase,
      l1_start_index: l1_start_index,
      l1_end_index: l1_end_index,
      translation: translation
    )
  end

  test "should return simple span when phrase has no token translations" do
    phrase = create_phrase(text_l1_content: "Hello world")
    
    result = wrap_tokens_in_spans(phrase)
    
    assert_equal "<span>Hello world</span>", result
  end

  test "should wrap single token translation in span with translation data" do
    phrase = create_phrase(text_l1_content: "Hello world")
    token = create_token_translation(
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      translation: "Hola"
    )
    
    result = wrap_tokens_in_spans(phrase)
    
    # Parse the result to verify structure
    parsed = Nokogiri::HTML::DocumentFragment.parse(result)
    spans = parsed.css('span')
    
    assert_equal 2, spans.length
    
    # First span should have the token with translation data
    first_span = spans.first
    assert_equal "Hello", first_span.text
    assert_equal "Hola", first_span['data-translation']
    assert_equal token.id.to_s, first_span['data-token-id']
    
    # Second span should have the remaining text
    second_span = spans.last
    assert_equal " world", second_span.text
    assert_nil second_span['data-translation']
  end

  test "should wrap multiple token translations in correct order" do
    phrase = create_phrase(text_l1_content: "Hello beautiful world")
    create_token_translation(
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      translation: "Hola"
    )
    create_token_translation(
      phrase: phrase, 
      l1_start_index: 2,
      l1_end_index: 2,
      translation: "mundo"
    )
    
    result = wrap_tokens_in_spans(phrase)
    parsed = Nokogiri::HTML::DocumentFragment.parse(result)
    spans = parsed.css('span')
    
    assert_equal 3, spans.length
    
    # Verify text content and order
    assert_equal "Hello", spans[0].text
    assert_equal "Hola", spans[0]['data-translation']
    
    assert_equal " beautiful ", spans[1].text
    assert_nil spans[1]['data-translation']
    
    assert_equal "world", spans[2].text
    assert_equal "mundo", spans[2]['data-translation']
  end

  test "should handle token at beginning of phrase" do
    phrase = create_phrase(text_l1_content: "Hello world")
    create_token_translation(
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      translation: "Hola"
    )
    
    result = wrap_tokens_in_spans(phrase)
    parsed = Nokogiri::HTML::DocumentFragment.parse(result)
    spans = parsed.css('span')
    
    assert_equal 2, spans.length
    assert_equal "Hello", spans[0].text
    assert_equal "Hola", spans[0]['data-translation']
    assert_equal " world", spans[1].text
  end

  test "should handle token at end of phrase" do
    phrase = create_phrase(text_l1_content: "Hello world")
    create_token_translation(
      phrase: phrase,
      l1_start_index: 1,
      l1_end_index: 1,
      translation: "mundo"
    )
    
    result = wrap_tokens_in_spans(phrase)
    parsed = Nokogiri::HTML::DocumentFragment.parse(result)
    spans = parsed.css('span')
    
    assert_equal 2, spans.length
    assert_equal "Hello ", spans[0].text
    assert_nil spans[0]['data-translation']
    assert_equal "world", spans[1].text
    assert_equal "mundo", spans[1]['data-translation']
  end

  test "should handle adjacent tokens" do
    phrase = create_phrase(text_l1_content: "Hello world")
    create_token_translation(
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      translation: "Hola"
    )
    create_token_translation(
      phrase: phrase,
      l1_start_index: 1,
      l1_end_index: 1,
      translation: "mundo"
    )
    
    result = wrap_tokens_in_spans(phrase)
    parsed = Nokogiri::HTML::DocumentFragment.parse(result)
    spans = parsed.css('span')
    
    assert_equal 3, spans.length
    assert_equal "Hello", spans[0].text
    assert_equal "Hola", spans[0]['data-translation']
    assert_equal " ", spans[1].text  # Space between words
    assert_nil spans[1]['data-translation']
    assert_equal "world", spans[2].text
    assert_equal "mundo", spans[2]['data-translation']
  end

  test "should preserve complete original text" do
    original_text = "The quick brown fox jumps"
    phrase = create_phrase(text_l1_content: original_text)
    create_token_translation(
      phrase: phrase,
      l1_start_index: 1,
      l1_end_index: 1,
      translation: "rápido"
    )
    create_token_translation(
      phrase: phrase,
      l1_start_index: 3,
      l1_end_index: 3,
      translation: "zorro"
    )
    
    result = wrap_tokens_in_spans(phrase)
    parsed = Nokogiri::HTML::DocumentFragment.parse(result)
    
    # Extract all text content from spans
    combined_text = parsed.css('span').map(&:text).join
    
    assert_equal original_text, combined_text
  end

  test "should apply custom attributes to token spans" do
    phrase = create_phrase(text_l1_content: "Hello world")
    create_token_translation(
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      translation: "Hola"
    )
    
    attributes_map = {
      class: "highlight",
      data: { target: "translation.token" }
    }
    
    result = wrap_tokens_in_spans(phrase, attributes_map)
    parsed = Nokogiri::HTML::DocumentFragment.parse(result)
    token_span = parsed.css('span').find { |span| span['data-translation'] }
    
    assert_equal "highlight", token_span['class']
    assert_equal "translation.token", token_span['data-target']
    assert_equal "Hola", token_span['data-translation']
  end

  test "should not apply custom attributes to non-token spans" do
    phrase = create_phrase(text_l1_content: "Hello world")
    create_token_translation(
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      translation: "Hola"
    )
    
    attributes_map = { class: "highlight" }
    
    result = wrap_tokens_in_spans(phrase, attributes_map)
    parsed = Nokogiri::HTML::DocumentFragment.parse(result)
    non_token_span = parsed.css('span').find { |span| !span['data-translation'] }
    
    assert_nil non_token_span['class']
  end

  # TODO: Enable when S3 bucket is properly configured
  # test "should handle audio URL when present" do
  #   phrase = create_phrase(text_l1_content: "Hello world")
  #   token = create_token_translation(
  #     phrase: phrase,
  #     l1_start_index: 0,
  #     l1_end_index: 0,
  #     translation: "Hola"
  #   )
  #   
  #   # Mock audio attachment
  #   token.l1_audio.attach(
  #     io: StringIO.new("fake audio data"),
  #     filename: "hello.mp3",
  #     content_type: "audio/mpeg"
  #   )
  #   
  #   result = wrap_tokens_in_spans(phrase)
  #   parsed = Nokogiri::HTML::DocumentFragment.parse(result)
  #   
  #   # Should have a div wrapper when audio is present
  #   div = parsed.css('div').first
  #   assert_not_nil div
  #   
  #   # Should contain both span and audio elements
  #   span = div.css('span').first
  #   audio = div.css('audio').first
  #   
  #   assert_equal "Hello", span.text
  #   assert_equal "Hola", span['data-translation']
  #   assert_not_nil audio
  #   assert_not_nil audio['src']
  # end

  test "should handle multi-word tokens correctly" do
    phrase = create_phrase(text_l1_content: "New York City is amazing")
    create_token_translation(
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 2,  # "New York City"
      translation: "Nueva York"
    )
    
    result = wrap_tokens_in_spans(phrase)
    parsed = Nokogiri::HTML::DocumentFragment.parse(result)
    spans = parsed.css('span')
    
    assert_equal 2, spans.length
    assert_equal "New York City", spans[0].text
    assert_equal "Nueva York", spans[0]['data-translation']
    assert_equal " is amazing", spans[1].text
  end

  test "integration test: complex phrase with multiple tokens and gaps" do
    phrase = create_phrase(text_l1_content: "The quick brown fox jumps over the lazy dog")
    
    # Create multiple non-adjacent tokens
    create_token_translation(
      phrase: phrase,
      l1_start_index: 1, # "quick" 
      l1_end_index: 1,
      translation: "rápido"
    )
    create_token_translation(
      phrase: phrase,
      l1_start_index: 3, # "fox"
      l1_end_index: 3,
      translation: "zorro"
    )
    create_token_translation(
      phrase: phrase,
      l1_start_index: 7, # "lazy"
      l1_end_index: 7,
      translation: "perezoso"
    )
    
    result = wrap_tokens_in_spans(phrase)
    parsed = Nokogiri::HTML::DocumentFragment.parse(result)
    
    # Should preserve the original text completely
    combined_text = parsed.css('span').map(&:text).join
    assert_equal "The quick brown fox jumps over the lazy dog", combined_text
    
    spans = parsed.css('span')
    assert_equal 7, spans.length
    
    # Verify structure: non-token, token, non-token, token, non-token, token, remaining
    assert_equal "The ", spans[0].text
    assert_nil spans[0]['data-translation']
    
    assert_equal "quick", spans[1].text
    assert_equal "rápido", spans[1]['data-translation']
    
    assert_equal " brown ", spans[2].text
    assert_nil spans[2]['data-translation']
    
    assert_equal "fox", spans[3].text
    assert_equal "zorro", spans[3]['data-translation']
    
    assert_equal " jumps over the ", spans[4].text
    assert_nil spans[4]['data-translation']
    
    assert_equal "lazy", spans[5].text
    assert_equal "perezoso", spans[5]['data-translation']
    
    assert_equal " dog", spans[6].text
    assert_nil spans[6]['data-translation']
  end

  test "edge case: phrase with only translated tokens and no gaps" do
    phrase = create_phrase(text_l1_content: "Hello world")
    create_token_translation(
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 1, # "Hello world" - both words
      translation: "Hola mundo"
    )
    
    result = wrap_tokens_in_spans(phrase)
    parsed = Nokogiri::HTML::DocumentFragment.parse(result)
    spans = parsed.css('span')
    
    assert_equal 1, spans.length
    assert_equal "Hello world", spans[0].text
    assert_equal "Hola mundo", spans[0]['data-translation']
  end

  test "edge case: empty translation should still create span" do
    phrase = create_phrase(text_l1_content: "Hello world")
    create_token_translation(
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      translation: "" # Empty translation
    )
    
    result = wrap_tokens_in_spans(phrase)
    parsed = Nokogiri::HTML::DocumentFragment.parse(result)
    spans = parsed.css('span')
    
    assert_equal 2, spans.length
    assert_equal "Hello", spans[0].text
    assert_equal "", spans[0]['data-translation']
    assert_equal " world", spans[1].text
  end

  test "token spans should contain exact token text without surrounding spaces" do
    phrase = create_phrase(text_l1_content: "Hello beautiful world!")
    create_token_translation(
      phrase: phrase,
      l1_start_index: 1, # "beautiful"
      l1_end_index: 1,
      translation: "hermoso"
    )
    
    result = wrap_tokens_in_spans(phrase)
    parsed = Nokogiri::HTML::DocumentFragment.parse(result)
    spans = parsed.css('span')
    
    # Find the token span
    token_span = spans.find { |span| span['data-translation'] }
    non_token_spans = spans.reject { |span| span['data-translation'] }
    
    # Token span should contain only the exact word without spaces
    assert_equal "beautiful", token_span.text
    assert_equal "hermoso", token_span['data-translation']
    
    # Verify no leading/trailing spaces in token span
    assert_equal token_span.text.strip, token_span.text, "Token span should not have leading/trailing spaces"
    
    # Non-token spans should contain the spaces
    assert_equal "Hello ", non_token_spans[0].text
    assert_equal " world!", non_token_spans[1].text
  end

  test "multiple token spans should not leak spaces between each other" do
    phrase = create_phrase(text_l1_content: "The quick brown fox")
    create_token_translation(
      phrase: phrase,
      l1_start_index: 1, # "quick"
      l1_end_index: 1,
      translation: "rápido"
    )
    create_token_translation(
      phrase: phrase,
      l1_start_index: 3, # "fox"
      l1_end_index: 3,
      translation: "zorro"
    )
    
    result = wrap_tokens_in_spans(phrase)
    parsed = Nokogiri::HTML::DocumentFragment.parse(result)
    spans = parsed.css('span')
    
    # Get token and non-token spans
    token_spans = spans.select { |span| span['data-translation'] }
    non_token_spans = spans.reject { |span| span['data-translation'] }
    
    # Each token span should contain exact word only
    assert_equal 2, token_spans.length
    assert_equal "quick", token_spans[0].text
    assert_equal "fox", token_spans[1].text
    
    # Verify no spaces in token spans
    token_spans.each do |span|
      assert_equal span.text.strip, span.text, "Token span '#{span.text}' should not have leading/trailing spaces"
      if span.text.split.length == 1  # Single word token should not contain spaces
        refute_match(/\s/, span.text, "Single word token should not contain spaces")
      end
    end
    
    # Non-token spans should contain the spaces and other text
    assert_equal 2, non_token_spans.length
    assert_equal "The ", non_token_spans[0].text
    assert_equal " brown ", non_token_spans[1].text
    # No trailing text after "fox" in this case
  end

  test "token at start and end should not have space leakage" do
    phrase = create_phrase(text_l1_content: "Hello world")
    create_token_translation(
      phrase: phrase,
      l1_start_index: 0, # "Hello" at start
      l1_end_index: 0,
      translation: "Hola"
    )
    create_token_translation(
      phrase: phrase,
      l1_start_index: 1, # "world" at end
      l1_end_index: 1,
      translation: "mundo"
    )
    
    result = wrap_tokens_in_spans(phrase)
    parsed = Nokogiri::HTML::DocumentFragment.parse(result)
    spans = parsed.css('span')
    
    token_spans = spans.select { |span| span['data-translation'] }
    non_token_spans = spans.reject { |span| span['data-translation'] }
    
    # Token spans should be exact words
    assert_equal 2, token_spans.length
    assert_equal "Hello", token_spans[0].text
    assert_equal "world", token_spans[1].text
    
    # Verify no spaces in token spans
    token_spans.each do |span|
      assert_equal span.text.strip, span.text, "Token span should not have spaces"
    end
    
    # Only one non-token span for the space between words
    assert_equal 1, non_token_spans.length
    assert_equal " ", non_token_spans[0].text
  end

  test "multi-word token should not leak spaces to adjacent spans" do
    phrase = create_phrase(text_l1_content: "Visit New York City today")
    create_token_translation(
      phrase: phrase,
      l1_start_index: 1, # "New York City" (3 words)
      l1_end_index: 3,
      translation: "Nueva York"
    )
    
    result = wrap_tokens_in_spans(phrase)
    parsed = Nokogiri::HTML::DocumentFragment.parse(result)
    spans = parsed.css('span')
    
    token_span = spans.find { |span| span['data-translation'] }
    non_token_spans = spans.reject { |span| span['data-translation'] }
    
    # Multi-word token should contain exactly the words with their internal spaces
    assert_equal "New York City", token_span.text
    assert_equal "Nueva York", token_span['data-translation']
    
    # But should not have leading or trailing spaces
    assert_equal token_span.text.strip, token_span.text, "Multi-word token should not have leading/trailing spaces"
    
    # Non-token spans should contain the boundary spaces
    assert_equal 2, non_token_spans.length
    assert_equal "Visit ", non_token_spans[0].text
    assert_equal " today", non_token_spans[1].text
  end

  test "token spans should not include punctuation from adjacent text" do
    phrase = create_phrase(text_l1_content: "Hello, beautiful world!")
    create_token_translation(
      phrase: phrase,
      l1_start_index: 1, # "beautiful" (without punctuation)
      l1_end_index: 1,
      translation: "hermoso"
    )
    
    result = wrap_tokens_in_spans(phrase)
    parsed = Nokogiri::HTML::DocumentFragment.parse(result)
    spans = parsed.css('span')
    
    token_span = spans.find { |span| span['data-translation'] }
    non_token_spans = spans.reject { |span| span['data-translation'] }
    
    # Token span should contain only the word without punctuation
    assert_equal "beautiful", token_span.text
    assert_equal "hermoso", token_span['data-translation']
    
    # Verify token doesn't have punctuation
    refute_match(/[,!.]/, token_span.text, "Token span should not contain punctuation")
    
    # Non-token spans should contain the punctuation and spaces
    # There should be 2 non-token spans: "Hello, " and " world!"
    assert_equal 2, non_token_spans.length
    assert_equal "Hello, ", non_token_spans[0].text
    assert_equal " world!", non_token_spans[1].text
    
    # Verify punctuation is in non-token spans
    assert_match(/,/, non_token_spans[0].text, "Comma should be in non-token span")
    assert_match(/!/, non_token_spans[1].text, "Exclamation should be in non-token span")
  end
end
