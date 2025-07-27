require 'test_helper'

class ActivitiesHelperTest < ActionView::TestCase
  setup do
    @medium = medium(:a_dios_le_pido)
    @english = languages(:english)
    @spanish = languages(:spanish)
    @latin_script = scripts(:latin)
  end

  def create_phrase(
    text_l1_content: "Hello world",
    text_l2_content: "Hola mundo",
    text_l1_variants: [],
    text_l2_variants: [])
    Phrase.create!(
      medium: @medium,
      timestamp: "01:30",
      l1: @english,
      l2: @spanish,
      text_l1_attributes: {
        language: @english,
        script_variants_attributes: [
          { script: @latin_script, content: text_l1_content },
          *text_l1_variants
        ]
      },
      text_l2_attributes: {
        language: @spanish,
        script_variants_attributes: [
          { script: @latin_script, content: text_l2_content },
          *text_l2_variants
        ]
      }
    )
  end

  def create_token_translation(phrase:, l1_start_index:, l1_end_index:, translation: nil, l2_start_index: nil, l2_end_index: nil)
    TokenTranslation.create!(
      phrase: phrase,
      l1_start_index: l1_start_index,
      l1_end_index: l1_end_index,
      l2_start_index: l2_start_index,
      l2_end_index: l2_end_index,
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

  # Tests for render_phrase_with_blanks method
  test "render_phrase_with_blanks should return text with no blanks when phrase has no token translations" do
    phrase = create_phrase(text_l1_content: "Hello world")
    
    result = render_phrase_with_blanks(phrase)
    
    assert_equal "Hello world", result
  end

  test "render_phrase_with_blanks should replace single token with blank" do
    phrase = create_phrase(text_l1_content: "Hello world")
    token = create_token_translation(
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      translation: "Hola"
    )
    
    result = render_phrase_with_blanks(phrase)
    parsed = Nokogiri::HTML::DocumentFragment.parse(result)
    
    # Should have a blank span for the token
    blank_span = parsed.css('span.blank-line').first
    assert_not_nil blank_span
    assert_equal "________", blank_span.text
    assert_equal "blank-line underline text-gray-400", blank_span['class']
    
    # Should contain token data
    token_data = JSON.parse(blank_span['data-token'])
    assert_equal "Hello", token_data['original_text']
    
    # Should preserve remaining text
    assert_match(/ world/, result)
  end

  test "render_phrase_with_blanks should replace multiple tokens with blanks" do
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
    
    result = render_phrase_with_blanks(phrase)
    parsed = Nokogiri::HTML::DocumentFragment.parse(result)
    
    # Should have two blank spans
    blank_spans = parsed.css('span.blank-line')
    assert_equal 2, blank_spans.length
    
    # Verify both spans have the right structure
    blank_spans.each do |span|
      assert_equal "________", span.text
      assert_equal "blank-line underline text-gray-400", span['class']
      assert_not_nil span['data-token']
    end
    
    # Should preserve non-token text
    assert_match(/ beautiful /, result)
  end

  test "render_phrase_with_blanks should handle token at beginning of phrase" do
    phrase = create_phrase(text_l1_content: "Hello world")
    create_token_translation(
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      translation: "Hola"
    )
    
    result = render_phrase_with_blanks(phrase)
    parsed = Nokogiri::HTML::DocumentFragment.parse(result)
    
    # Should start with a blank span
    blank_span = parsed.css('span.blank-line').first
    assert_not_nil blank_span
    
    token_data = JSON.parse(blank_span['data-token'])
    assert_equal "Hello", token_data['original_text']
    
    # Should preserve remaining text
    assert_match(/ world/, result)
  end

  test "render_phrase_with_blanks should handle token at end of phrase" do
    phrase = create_phrase(text_l1_content: "Hello world")
    create_token_translation(
      phrase: phrase,
      l1_start_index: 1,
      l1_end_index: 1,
      translation: "mundo"
    )
    
    result = render_phrase_with_blanks(phrase)
    parsed = Nokogiri::HTML::DocumentFragment.parse(result)
    
    blank_span = parsed.css('span.blank-line').first
    assert_not_nil blank_span
    
    token_data = JSON.parse(blank_span['data-token'])
    assert_equal "world", token_data['original_text']
    
    # Should preserve preceding text
    assert_match(/Hello /, result)
  end

  test "render_phrase_with_blanks should handle multi-word tokens" do
    phrase = create_phrase(text_l1_content: "New York City is amazing")
    create_token_translation(
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 2,  # "New York City"
      translation: "Nueva York"
    )
    
    result = render_phrase_with_blanks(phrase)
    parsed = Nokogiri::HTML::DocumentFragment.parse(result)
    
    blank_span = parsed.css('span.blank-line').first
    assert_not_nil blank_span
    
    token_data = JSON.parse(blank_span['data-token'])
    assert_equal "New York City", token_data['original_text']
    
    # Should preserve remaining text
    assert_match(/ is amazing/, result)
  end

  test "render_phrase_with_blanks should include similar_sound data when available" do
    phrase = create_phrase(text_l1_content: "Hello world")
    token = create_token_translation(
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      translation: "Hola"
    )
    
    # Set similar_sound data (this would typically be done through a model method)
    token.update!(similar_sound: ["Ola", "Holla"])
    
    result = render_phrase_with_blanks(phrase)
    parsed = Nokogiri::HTML::DocumentFragment.parse(result)
    
    blank_span = parsed.css('span.blank-line').first
    token_data = JSON.parse(blank_span['data-token'])
    
    assert_equal "Hello", token_data['original_text']
    assert_equal ["Ola", "Holla"], token_data['similar_sound']
  end

  test "render_phrase_with_blanks should handle adjacent tokens correctly" do
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
    
    result = render_phrase_with_blanks(phrase)
    parsed = Nokogiri::HTML::DocumentFragment.parse(result)
    
    # Should have two blank spans
    blank_spans = parsed.css('span.blank-line')
    assert_equal 2, blank_spans.length
    
    # Should preserve the space between them - check for the span structure
    expected_pattern = /<span[^>]*>________<\/span> <span[^>]*>________<\/span>/
    assert_match(expected_pattern, result)
  end

  test "render_phrase_with_blanks should properly escape quotes in token data" do
    phrase = create_phrase(text_l1_content: "He said hello to me")
    token = create_token_translation(
      phrase: phrase,
      l1_start_index: 2,  # "hello"
      l1_end_index: 2,
      translation: "hola"
    )
    
    # Set similar_sound with quotes to test escaping
    token.update!(similar_sound: ["'hola'", "\"hello\""])
    
    result = render_phrase_with_blanks(phrase)
    
    # Should not break HTML due to quotes
    parsed = Nokogiri::HTML::DocumentFragment.parse(result)
    blank_span = parsed.css('span.blank-line').first
    assert_not_nil blank_span
    
    # Should properly escape quotes in data attribute
    token_data_attr = blank_span['data-token']
    assert_not_nil token_data_attr
    
    # Should contain escaped quotes
    assert_includes result, "&#39;"
    
    # Should be parseable JSON
    token_data = JSON.parse(token_data_attr)
    assert_equal "hello", token_data['original_text']  # Token itself doesn't have quotes
    assert_includes token_data['similar_sound'], "'hola'"
    assert_includes token_data['similar_sound'], "\"hello\""
  end

  test "render_phrase_with_blanks should preserve complete original text structure" do
    original_text = "The quick brown fox jumps"
    phrase = create_phrase(text_l1_content: original_text)
    create_token_translation(
      phrase: phrase,
      l1_start_index: 1,  # "quick"
      l1_end_index: 1,
      translation: "rápido"
    )
    create_token_translation(
      phrase: phrase,
      l1_start_index: 3,  # "fox"
      l1_end_index: 3,
      translation: "zorro"
    )
    
    result = render_phrase_with_blanks(phrase)
    
    # Remove the blank spans and their content to check remaining text
    text_without_blanks = result.gsub(/<span[^>]*class[^>]*blank-line[^>]*>.*?<\/span>/, 'TOKEN')
    
    # Should maintain the structure with tokens replaced
    assert_equal "The TOKEN brown TOKEN jumps", text_without_blanks
  end

  test "render_phrase_with_blanks integration test with complex phrase" do
    phrase = create_phrase(text_l1_content: "I love New York City very much today")
    
    # Create multiple tokens including multi-word
    create_token_translation(
      phrase: phrase,
      l1_start_index: 1,  # "love"
      l1_end_index: 1,
      translation: "amo"
    )
    create_token_translation(
      phrase: phrase,
      l1_start_index: 2,  # "New York City" 
      l1_end_index: 4,
      translation: "Nueva York"
    )
    create_token_translation(
      phrase: phrase,
      l1_start_index: 6,  # "much"
      l1_end_index: 6,
      translation: "mucho"
    )
    
    result = render_phrase_with_blanks(phrase)
    parsed = Nokogiri::HTML::DocumentFragment.parse(result)
    
    # Should have 3 blank spans
    blank_spans = parsed.css('span.blank-line')
    assert_equal 3, blank_spans.length
    
    # Verify token data for multi-word token
    multi_word_span = blank_spans.find do |span|
      token_data = JSON.parse(span['data-token'])
      token_data['original_text'] == "New York City"
    end
    assert_not_nil multi_word_span
    
    # Should preserve structure - check that blanks are in right positions
    # The regex should account for the full HTML spans, not just ________
    expected_pattern = /I <span[^>]*>________<\/span> <span[^>]*>________<\/span> very <span[^>]*>________<\/span> today/
    assert_match(expected_pattern, result)
  end

  test "should handle Hebrew text with no token translations" do
    phrase = create_phrase(text_l1_content: "שלום עולם")
    result = wrap_tokens_in_spans(phrase)
    assert_equal "<span>שלום עולם</span>", result
  end

  test "should handle Hebrew text with token translations" do
    phrase = create_phrase(text_l1_content: "שלום עולם")
    create_token_translation(phrase:, l1_start_index: 0, l1_end_index: 0, translation: 'hello')
    result = wrap_tokens_in_spans(phrase)

    spans = Nokogiri::HTML::DocumentFragment.parse(result).css('span')     
    
    # First span should have the token with translation data
    assert_equal "שלום", spans[0].text
    assert_equal " עולם", spans[1].text
  end

  test "hebrew que mis ojos 1" do
    phrase = create_phrase(text_l1_content: 'קה מיס אוחוס סה דספיירטן')
    create_token_translation(phrase:, l1_start_index: 0, l1_end_index: 0)
    create_token_translation(phrase:, l1_start_index: 1, l1_end_index: 1)
    create_token_translation(phrase:, l1_start_index: 2, l1_end_index: 2)
    create_token_translation(phrase:, l1_start_index: 3, l1_end_index: 4)
    result = wrap_tokens_in_spans(phrase)

    spans = Nokogiri::HTML::DocumentFragment.parse(result).css('span')
    
    # First span should have the token with translation data
    assert_equal "קה", spans.first.text
  end

  test "hebrew que mis ojos 2" do
    phrase = create_phrase(text_l1_content: "que mis ojos se despiertan", text_l1_variants: [
      {script: Script.find_by(code: 'hebr'), content: 'קה מיס אוחוס סה דספיירטן'}
    ])
    create_token_translation(phrase:, l1_start_index: 0, l1_end_index: 0)
    create_token_translation(phrase:, l1_start_index: 1, l1_end_index: 1)
    create_token_translation(phrase:, l1_start_index: 2, l1_end_index: 2)
    create_token_translation(phrase:, l1_start_index: 3, l1_end_index: 4)
    result = wrap_tokens_in_spans(phrase, script: Script.find_by(code: 'hebr'))

    spans = Nokogiri::HTML::DocumentFragment.parse(result).css('span')
    
    # First span should have the token with translation data
    assert_equal "קה", spans.first.text
  end

  # Tests for new script-aware helper methods

  test "token_original_text should return token text in default script" do
    phrase = create_phrase(text_l1_content: "Hello world")
    token = create_token_translation(
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      translation: "Hola"
    )
    
    result = token_original_text(token)
    assert_equal "Hello", result
  end

  test "token_original_text should return token text in specified script" do
    @hebrew_script = scripts(:hebrew)
    phrase = create_phrase(
      text_l1_content: "que mis ojos",
      text_l1_variants: [
        {script: @hebrew_script, content: 'קה מיס אוחוס'}
      ]
    )
    token = create_token_translation(
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      translation: "what"
    )
    
    # Default script should return Latin text
    result_default = token_original_text(token)
    assert_equal "que", result_default
    
    # Hebrew script should return Hebrew text
    result_hebrew = token_original_text(token, @hebrew_script)
    assert_equal "קה", result_hebrew
  end

  test "phrase_text_l1 should return L1 text in default script" do
    phrase = create_phrase(text_l1_content: "Hello world")
    
    result = phrase_text_l1(phrase)
    assert_equal "Hello world", result
  end

  test "phrase_text_l1 should return L1 text in specified script" do
    @hebrew_script = scripts(:hebrew)
    phrase = create_phrase(
      text_l1_content: "Hello world",
      text_l1_variants: [
        {script: @hebrew_script, content: 'שלום עולם'}
      ]
    )
    
    # Default script
    result_default = phrase_text_l1(phrase)
    assert_equal "Hello world", result_default
    
    # Hebrew script
    result_hebrew = phrase_text_l1(phrase, @hebrew_script)
    assert_equal "שלום עולם", result_hebrew
  end

  test "phrase_text_l2 should return L2 text in default script" do
    phrase = create_phrase(text_l2_content: "Hola mundo")
    
    result = phrase_text_l2(phrase)
    assert_equal "Hola mundo", result
  end

  test "phrase_text_l2 should return L2 text in specified script" do
    @hebrew_script = scripts(:hebrew)
    phrase = create_phrase(
      text_l2_content: "Hola mundo",
      text_l2_variants: [
        {script: @hebrew_script, content: 'הולה מונדו'}
      ]
    )
    
    # Default script
    result_default = phrase_text_l2(phrase)
    assert_equal "Hola mundo", result_default
    
    # Hebrew script
    result_hebrew = phrase_text_l2(phrase, @hebrew_script)
    assert_equal "הולה מונדו", result_hebrew
  end

  test "prepare_tokens_for_matching should process tokens without script" do
    phrase = create_phrase(text_l1_content: "Hello beautiful world")
    token1 = create_token_translation(
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      translation: "Hola"
    )
    token2 = create_token_translation(
      phrase: phrase,
      l1_start_index: 2,
      l1_end_index: 2,
      translation: "mundo"
    )
    
    tokens = [token1, token2]
    result = prepare_tokens_for_matching(tokens)
    
    assert_equal 2, result.length
    
    first_token = result.first
    assert_equal "Hello", first_token[:l1_word]
    assert_equal "Hola", first_token[:l2_translation]
    assert_equal token1.id, first_token[:id]
    assert_nil first_token[:audio_url]
    
    second_token = result.last
    assert_equal "world", second_token[:l1_word]
    assert_equal "mundo", second_token[:l2_translation]
    assert_equal token2.id, second_token[:id]
  end

  test "prepare_tokens_for_matching should process tokens with specified script" do
    @hebrew_script = scripts(:hebrew)
    phrase = create_phrase(
      text_l1_content: "que mis ojos",
      text_l1_variants: [
        {script: @hebrew_script, content: 'קה מיס אוחוס'}
      ]
    )
    token1 = create_token_translation(
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      translation: "what"
    )
    token2 = create_token_translation(
      phrase: phrase,
      l1_start_index: 2,
      l1_end_index: 2,
      translation: "eyes"
    )
    
    tokens = [token1, token2]
    
    # Default script should return Latin text
    result_default = prepare_tokens_for_matching(tokens)
    assert_equal "que", result_default.first[:l1_word]
    assert_equal "ojos", result_default.last[:l1_word]
    
    # Hebrew script should return Hebrew text
    result_hebrew = prepare_tokens_for_matching(tokens, @hebrew_script)
    assert_equal "קה", result_hebrew.first[:l1_word]
    assert_equal "אוחוס", result_hebrew.last[:l1_word]
  end

  test "prepare_tokens_for_matching should filter duplicate L1 texts" do
    phrase = create_phrase(text_l1_content: "hello hello world")
    token1 = create_token_translation(
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      translation: "hola"
    )
    token2 = create_token_translation(
      phrase: phrase,
      l1_start_index: 1,
      l1_end_index: 1,
      translation: "saludo"  # Different translation for same word
    )
    token3 = create_token_translation(
      phrase: phrase,
      l1_start_index: 2,
      l1_end_index: 2,
      translation: "mundo"
    )
    
    tokens = [token1, token2, token3]
    result = prepare_tokens_for_matching(tokens)
    
    # Should only have 2 tokens (first "hello" and "world")
    assert_equal 2, result.length
    assert_equal "hello", result.first[:l1_word]
    assert_equal "hola", result.first[:l2_translation]
    assert_equal "world", result.last[:l1_word]
    assert_equal "mundo", result.last[:l2_translation]
  end

  test "prepare_tokens_for_matching should filter duplicate L2 texts" do
    phrase = create_phrase(text_l1_content: "hello goodbye world")
    token1 = create_token_translation(
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      translation: "hola"
    )
    token2 = create_token_translation(
      phrase: phrase,
      l1_start_index: 1,
      l1_end_index: 1,
      translation: "hola"  # Same translation for different word
    )
    token3 = create_token_translation(
      phrase: phrase,
      l1_start_index: 2,
      l1_end_index: 2,
      translation: "mundo"
    )
    
    tokens = [token1, token2, token3]
    result = prepare_tokens_for_matching(tokens)
    
    # Should only have 2 tokens (first "hello" and "world")
    assert_equal 2, result.length
    assert_equal "hello", result.first[:l1_word]
    assert_equal "hola", result.first[:l2_translation]
    assert_equal "world", result.last[:l1_word]
    assert_equal "mundo", result.last[:l2_translation]
  end

  test "prepare_tokens_for_matching should handle empty token list" do
    result = prepare_tokens_for_matching([])
    assert_equal [], result
  end

  test "prepare_phrases_for_sorting should process phrases without script" do
    phrase1 = create_phrase(text_l1_content: "Hello world")
    phrase2 = create_phrase(text_l1_content: "Goodbye world")
    
    phrases = [phrase1, phrase2]
    result = prepare_phrases_for_sorting(phrases)
    
    assert_equal 2, result.length
    assert_equal "Hello world", result.first
    assert_equal "Goodbye world", result.last
  end

  test "prepare_phrases_for_sorting should process phrases with specified script" do
    @hebrew_script = scripts(:hebrew)
    phrase1 = create_phrase(
      text_l1_content: "Hello world",
      text_l1_variants: [
        {script: @hebrew_script, content: 'שלום עולם'}
      ]
    )
    phrase2 = create_phrase(
      text_l1_content: "Goodbye world",
      text_l1_variants: [
        {script: @hebrew_script, content: 'להתראות עולם'}
      ]
    )
    
    phrases = [phrase1, phrase2]
    
    # Default script
    result_default = prepare_phrases_for_sorting(phrases)
    assert_equal ["Hello world", "Goodbye world"], result_default
    
    # Hebrew script
    result_hebrew = prepare_phrases_for_sorting(phrases, @hebrew_script)
    assert_equal ["שלום עולם", "להתראות עולם"], result_hebrew
  end

  test "prepare_phrases_for_sorting should handle empty phrase list" do
    result = prepare_phrases_for_sorting([])
    assert_equal [], result
  end

  test "prepare_phrases_with_tokens_for_alignment should process phrases without script" do
    phrase = create_phrase(
      text_l1_content: "Hello world",
      text_l2_content: "Hola mundo"
    )
    token = create_token_translation(
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      l2_start_index: 0,
      l2_end_index: 0,
      translation: "Hola"
    )
    
    phrases_with_tokens = [
      {
        phrase: phrase,
        tokens: [
          {
            l1_start_index: 0,
            l1_end_index: 0,
            l2_start_index: 0,
            l2_end_index: 0,
            translation: "Hola"
          }
        ]
      }
    ]
    
    result = prepare_phrases_with_tokens_for_alignment(phrases_with_tokens)
    
    assert_equal 1, result.length
    phrase_data = result.first
    assert_equal "Hello world", phrase_data[:original_text]
    assert_equal "Hola mundo", phrase_data[:translation]
    assert_equal 1, phrase_data[:tokens].length
    
    token_data = phrase_data[:tokens].first
    assert_equal "Hola", token_data[:translation]
    # Character ranges should be updated based on script
    assert_not_nil token_data[:l1_start_index]
    assert_not_nil token_data[:l1_end_index]
  end

  test "prepare_phrases_with_tokens_for_alignment should process phrases with specified script" do
    @hebrew_script = scripts(:hebrew)
    phrase = create_phrase(
      text_l1_content: "Hello world",
      text_l1_variants: [
        {script: @hebrew_script, content: 'שלום עולם'}
      ],
      text_l2_content: "Hola mundo",
      text_l2_variants: [
        {script: @hebrew_script, content: 'הולה מונדו'}
      ]
    )
    token = create_token_translation(
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      l2_start_index: 0,
      l2_end_index: 0,
      translation: "Hola"
    )
    
    phrases_with_tokens = [
      {
        phrase: phrase,
        tokens: [
          {
            l1_start_index: 0,
            l1_end_index: 0,
            l2_start_index: 0,
            l2_end_index: 0,
            translation: "Hola"
          }
        ]
      }
    ]
    
    # Default script
    result_default = prepare_phrases_with_tokens_for_alignment(phrases_with_tokens)
    assert_equal "Hello world", result_default.first[:original_text]
    assert_equal "Hola mundo", result_default.first[:translation]
    
    # Hebrew script
    result_hebrew = prepare_phrases_with_tokens_for_alignment(phrases_with_tokens, @hebrew_script)
    assert_equal "שלום עולם", result_hebrew.first[:original_text]
    assert_equal "הולה מונדו", result_hebrew.first[:translation]
  end

  test "prepare_phrases_with_tokens_for_alignment should filter phrases without tokens" do
    phrase1 = create_phrase(text_l1_content: "Hello world")
    phrase2 = create_phrase(text_l1_content: "Goodbye world")
    
    phrases_with_tokens = [
      {
        phrase: phrase1,
        tokens: []  # No tokens
      },
      {
        phrase: phrase2,
        tokens: nil  # Nil tokens
      }
    ]
    
    result = prepare_phrases_with_tokens_for_alignment(phrases_with_tokens)
    
    # Should filter out phrases without tokens
    assert_equal [], result
  end

  test "prepare_phrases_with_tokens_for_alignment should handle empty input" do
    result = prepare_phrases_with_tokens_for_alignment([])
    assert_equal [], result
  end

  test "prepare_phrases_with_tokens_for_alignment should handle missing token_translation" do
    phrase = create_phrase(text_l1_content: "Hello world")
    
    phrases_with_tokens = [
      {
        phrase: phrase,
        tokens: [
          {
            l1_start_index: 0,
            l1_end_index: 0,
            l2_start_index: 0,
            l2_end_index: 0,
            translation: "Hola"
          }
        ]
      }
    ]
    
    # No actual token_translation created, so it should fall back to original data
    result = prepare_phrases_with_tokens_for_alignment(phrases_with_tokens)
    
    assert_equal 1, result.length
    phrase_data = result.first
    token_data = phrase_data[:tokens].first
    
    # Should preserve original indices when token_translation is not found
    assert_equal 0, token_data[:l1_start_index]
    assert_equal 0, token_data[:l1_end_index]
    assert_equal 0, token_data[:l2_start_index]
    assert_equal 0, token_data[:l2_end_index]
  end
end
