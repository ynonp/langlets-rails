require "test_helper"

class PhraseTest < ActiveSupport::TestCase
  def setup
    # Use fixtures for languages and scripts
    @english = languages(:english)
    @hebrew = languages(:hebrew)
    @latin_script = scripts(:latin)
    @hebrew_script = scripts(:hebrew)
    @arabic_script = scripts(:arabic)
    
    # Create a test medium
    @medium = Medium.create!(url: 'https://example.com/test')
  end

  # Test creating phrases using nested attributes
  test "should create phrase with nested text attributes" do
    phrase = Phrase.new(
      medium: @medium,
      timestamp: "01:30",
      text_l1_attributes: {
        language: @english,
        script_variants_attributes: [
          { script: @latin_script, content: "Hello world" }
        ]
      },
      text_l2_attributes: {
        language: @hebrew,
        script_variants_attributes: [
          { script: @hebrew_script, content: "שלום עולם" }
        ]
      },
      l1: @english,
      l2: @hebrew
    )
    
    assert phrase.valid?
    assert phrase.save!
    
    # Verify the MultiScriptText objects were created
    assert_not_nil phrase.text_l1_id
    assert_not_nil phrase.text_l2_id
    
    # Verify we can read back the text content
    assert_equal "Hello world", phrase.text_l1.to_s
    assert_equal "שלום עולם", phrase.text_l2.to_s
  end

  test "should create phrase with nested attributes directly" do
    phrase = Phrase.create!(
      medium: @medium,
      timestamp: "02:15",
      text_l1_attributes: {
        language: @english,
        script_variants_attributes: [
          { script: @latin_script, content: "Good morning" }
        ]
      },
      text_l2_attributes: {
        language: @hebrew,
        script_variants_attributes: [
          { script: @hebrew_script, content: "בוקר טוב" }
        ]
      },
      l1: @english,
      l2: @hebrew
    )
    
    # Verify the text content can be read back
    assert_equal "Good morning", phrase.text_l1.to_s
    assert_equal "בוקר טוב", phrase.text_l2.to_s
    assert_not_nil phrase.text_l1_id
    assert_not_nil phrase.text_l2_id
  end

  test "should create phrase with existing MultiScriptText IDs" do
    # Create MultiScriptText objects first
    text_l1 = MultiScriptText.create_with_default_content(
      language: @english,
      content: "Thank you"
    )
    
    text_l2 = MultiScriptText.create_with_default_content(
      language: @hebrew,
      content: "תודה"
    )
    
    phrase = Phrase.create!(
      medium: @medium,
      timestamp: "03:45",
      text_l1_id: text_l1.id,
      text_l2_id: text_l2.id,
      l1: @english,
      l2: @hebrew
    )
    
    # Verify the text content can be read back
    assert_equal "Thank you", phrase.text_l1.to_s
    assert_equal "תודה", phrase.text_l2.to_s
  end

  # Test validation requirements
  test "should require text_l1 in some form" do
    phrase = Phrase.new(
      medium: @medium,
      timestamp: "01:00",
      text_l2_attributes: {
        language: @hebrew,
        script_variants_attributes: [
          { script: @hebrew_script, content: "שלום" }
        ]
      },
      l1: @english,
      l2: @hebrew
    )
    
    assert_not phrase.valid?
    assert_includes phrase.errors[:text_l1], "must be present"
  end

  test "should require text_l2 in some form" do
    phrase = Phrase.new(
      medium: @medium,
      timestamp: "01:00",
      text_l1_attributes: {
        language: @english,
        script_variants_attributes: [
          { script: @latin_script, content: "Hello" }
        ]
      },
      l1: @english,
      l2: @hebrew
    )
    
    assert_not phrase.valid?
    assert_includes phrase.errors[:text_l2], "must be present"
  end

  test "should accept text_l1_id with nested text_l2" do
    text_l1 = MultiScriptText.create_with_default_content(
      language: @english,
      content: "Hello"
    )
    
    phrase = Phrase.new(
      medium: @medium,
      timestamp: "01:00",
      text_l1_id: text_l1.id,
      text_l2_attributes: {
        language: @hebrew,
        script_variants_attributes: [
          { script: @hebrew_script, content: "שלום" }
        ]
      },
      l1: @english,
      l2: @hebrew
    )
    
    assert phrase.valid?
  end

  # Test multiple script variants using nested attributes
  test "should support multiple script variants using nested attributes" do
    phrase = Phrase.create!(
      medium: @medium,
      timestamp: "01:30",
      text_l1_attributes: {
        language: @english,
        script_variants_attributes: [
          { script: @latin_script, content: "Hello world" }
        ]
      },
      text_l2_attributes: {
        language: @hebrew,
        script_variants_attributes: [
          { script: @hebrew_script, content: "שלום עולם" },
          { script: @latin_script, content: "Shalom olam" } # Transliteration
        ]
      },
      l1: @english,
      l2: @hebrew
    )
    
    # Test reading text for different scripts
    assert_equal "Hello world", phrase.text_l1_for_script(@latin_script)
    assert_equal "שלום עולם", phrase.text_l2_for_script(@hebrew_script)
    assert_equal "Shalom olam", phrase.text_l2_for_script(@latin_script)
    
    # Test default content (uses language's default script)
    assert_equal "Hello world", phrase.text_l1.to_s # English default is Latin
    assert_equal "שלום עולם", phrase.text_l2.to_s # Hebrew default is Hebrew script
  end

  test "should fall back to default content when script variant doesn't exist" do
    phrase = Phrase.create!(
      medium: @medium,
      timestamp: "01:00",
      text_l1_attributes: {
        language: @english,
        script_variants_attributes: [
          { script: @latin_script, content: "Hello" }
        ]
      },
      text_l2_attributes: {
        language: @hebrew,
        script_variants_attributes: [
          { script: @hebrew_script, content: "שלום" }
        ]
      },
      l1: @english,
      l2: @hebrew
    )
    
    # Request content for a script that doesn't exist - should fall back to default
    assert_equal "Hello", phrase.text_l1_for_script(@arabic_script)
  end

  # Test edge cases and error handling
  test "should not create MultiScriptText if text_l1_id already exists" do
    existing_text = MultiScriptText.create_with_default_content(
      language: @english,
      content: "Existing text"
    )
    
    initial_count = MultiScriptText.count
    
    phrase = Phrase.create!(
      medium: @medium,
      timestamp: "01:00",
      text_l1_id: existing_text.id,
      text_l2_attributes: {
        language: @hebrew,
        script_variants_attributes: [
          { script: @hebrew_script, content: "שלום" }
        ]
      },
      l1: @english,
      l2: @hebrew
    )
    
    # Should not create additional MultiScriptText for text_l1
    assert_equal initial_count + 1, MultiScriptText.count # Only +1 for text_l2
    assert_equal "Existing text", phrase.text_l1.to_s
  end

  test "should handle phrase creation with nested attributes using .new followed by .save" do
    phrase = Phrase.new(
      medium: @medium,
      timestamp: "01:00",
      text_l1_attributes: {
        language: @english,
        script_variants_attributes: [
          { script: @latin_script, content: "How are you?" }
        ]
      },
      text_l2_attributes: {
        language: @hebrew,
        script_variants_attributes: [
          { script: @hebrew_script, content: "איך שלומך?" }
        ]
      },
      l1: @english,
      l2: @hebrew
    )
    
    # Should be valid
    assert phrase.valid?
    
    # After saving, MultiScriptText objects should be created
    assert phrase.save!
    assert_not_nil phrase.text_l1_id
    assert_not_nil phrase.text_l2_id
    assert_equal "How are you?", phrase.text_l1.to_s
    assert_equal "איך שלומך?", phrase.text_l2.to_s
  end

  test "should handle phrase creation with nested attributes using .create! directly" do
    phrase = Phrase.create!(
      medium: @medium,
      timestamp: "01:00",
      text_l1_attributes: {
        language: @english,
        script_variants_attributes: [
          { script: @latin_script, content: "Goodbye" }
        ]
      },
      text_l2_attributes: {
        language: @hebrew,
        script_variants_attributes: [
          { script: @hebrew_script, content: "להתראות" }
        ]
      },
      l1: @english,
      l2: @hebrew
    )
    
    # Should be saved with MultiScriptText objects created
    assert phrase.persisted?
    assert_not_nil phrase.text_l1_id
    assert_not_nil phrase.text_l2_id
    assert_equal "Goodbye", phrase.text_l1.to_s
    assert_equal "להתראות", phrase.text_l2.to_s
  end

  # Test integration with MultiScriptText model
  test "MultiScriptText.create_with_default_content should work correctly" do
    multi_text = MultiScriptText.create_with_default_content(
      language: @english,
      content: "Test content"
    )
    
    assert multi_text.persisted?
    assert_equal @english, multi_text.language
    assert_equal 1, multi_text.script_variants.count
    assert_equal @latin_script, multi_text.script_variants.first.script
    assert_equal "Test content", multi_text.script_variants.first.content
    assert_equal "Test content", multi_text.default_content
  end

  test "should handle empty or invalid nested attributes gracefully" do
    # Test with no text_l1_attributes
    phrase = Phrase.new(
      medium: @medium,
      timestamp: "01:00",
      text_l2_attributes: {
        language: @hebrew,
        script_variants_attributes: [
          { script: @hebrew_script, content: "שלום" }
        ]
      },
      l1: @english,
      l2: @hebrew
    )
    
    assert_not phrase.valid?
    assert_includes phrase.errors[:text_l1], "must be present"
    
    # Test with empty script_variants_attributes
    phrase = Phrase.new(
      medium: @medium,
      timestamp: "01:00",
      text_l1_attributes: {
        language: @english,
        script_variants_attributes: []
      },
      text_l2_attributes: {
        language: @hebrew,
        script_variants_attributes: [
          { script: @hebrew_script, content: "שלום" }
        ]
      },
      l1: @english,
      l2: @hebrew
    )
    
    assert_not phrase.valid?
    # The exact error message may vary, but it should indicate missing content
  end

  test "should create phrase with multiple script variants efficiently using nested attributes" do
    # Create a phrase with multiple script variants for each language in one operation
    phrase = Phrase.create!(
      medium: @medium,
      timestamp: "06:00",
      text_l1_attributes: {
        language: @english,
        script_variants_attributes: [
          { script: @latin_script, content: "Welcome to our platform" }
        ]
      },
      text_l2_attributes: {
        language: @hebrew,
        script_variants_attributes: [
          { script: @hebrew_script, content: "ברוכים הבאים לפלטפורמה שלנו" },
          { script: @latin_script, content: "Bruchim habaim l'platforma shelanu" }
        ]
      },
      l1: @english,
      l2: @hebrew
    )
    
    # Verify all script variants were created correctly
    assert_equal "Welcome to our platform", phrase.text_l1.to_s
    assert_equal "ברוכים הבאים לפלטפורמה שלנו", phrase.text_l2.to_s
    
    # Test accessing different script variants
    assert_equal "Welcome to our platform", phrase.text_l1_for_script(@latin_script)
    assert_equal "ברוכים הבאים לפלטפורמה שלנו", phrase.text_l2_for_script(@hebrew_script)
    assert_equal "Bruchim habaim l'platforma shelanu", phrase.text_l2_for_script(@latin_script)
    
    # Verify the correct number of script variants
    text_l1_obj = MultiScriptText.find(phrase.text_l1_id)
    text_l2_obj = MultiScriptText.find(phrase.text_l2_id)
    
    assert_equal 1, text_l1_obj.script_variants.count
    assert_equal 2, text_l2_obj.script_variants.count
  end
end
