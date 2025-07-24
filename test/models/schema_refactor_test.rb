require "test_helper"

class SchemaRefactorTest < ActiveSupport::TestCase
  def setup
    # Create scripts
    @latin_script = Script.create!(name: 'latin', iso_code: 'Latn', rtl: false)
    @hebrew_script = Script.create!(name: 'hebrew', iso_code: 'Hebr', rtl: true)
    
    # Create languages
    @english = Language.create!(
      iso_name: 'en',
      english_name: 'English', 
      native_name: 'English',
      default_script: @latin_script
    )
    
    @hebrew = Language.create!(
      iso_name: 'he',
      english_name: 'Hebrew',
      native_name: 'עברית',
      default_script: @hebrew_script
    )
    
    # Create medium
    @medium = Medium.create!(url: 'https://example.com/video')
  end
  
  test "should create phrase with multiple script variants" do
    # Create phrase
    phrase = Phrase.create!(
      l1: @hebrew,
      l2: @english,
      medium: @medium,
      timestamp: "00:01:30"
    )
    
    # Add Hebrew text in Hebrew script (primary)
    hebrew_text = PhraseText.create!(content: "שלום עולם", script: @hebrew_script)
    PhraseTextAssignment.create!(
      phrase: phrase, 
      phrase_text: hebrew_text, 
      language_role: :l1, 
      primary: true
    )
    
    # Add Hebrew text in Latin script (transliteration)
    latin_text = PhraseText.create!(content: "Shalom olam", script: @latin_script)
    PhraseTextAssignment.create!(
      phrase: phrase, 
      phrase_text: latin_text, 
      language_role: :l1, 
      primary: false
    )
    
    # Add English translation
    english_text = PhraseText.create!(content: "Hello world", script: @latin_script)
    PhraseTextAssignment.create!(
      phrase: phrase, 
      phrase_text: english_text, 
      language_role: :l2, 
      primary: true
    )
    
    # Test convenience methods
    assert_equal "שלום עולם", phrase.text_l1 # Uses default script
    assert_equal "Shalom olam", phrase.text_l1(script: 'latin')
    assert_equal "Hello world", phrase.text_l2
    
    # Test variants method
    variants = phrase.text_l1_variants
    assert_equal 2, variants.length
    assert_includes variants, { script: 'hebrew', text: 'שלום עולם' }
    assert_includes variants, { script: 'latin', text: 'Shalom olam' }
  end
  
  test "should support token translations with new schema" do
    # Create phrase with text
    phrase = create_phrase_with_text(
      text_l1: "Hello world",
      text_l2: "Hola mundo",
      l1: @english,
      l2: @english, # Using English for both to keep test simple
      medium: @medium,
      timestamp: "00:01:30"
    )
    
    # Create token translation
    token = TokenTranslation.create!(
      phrase: phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      l2_start_index: 0,
      l2_end_index: 0,
      translation: "Hello"
    )
    
    # Test that original_text works with new schema
    assert_equal "Hello", token.original_text
  end
  
  test "should maintain unique primary constraint" do
    phrase = Phrase.create!(
      l1: @english,
      l2: @hebrew,
      medium: @medium,
      timestamp: "00:01:30"
    )
    
    text1 = PhraseText.create!(content: "First text", script: @latin_script)
    text2 = PhraseText.create!(content: "Second text", script: @latin_script)
    
    # Create first primary assignment
    PhraseTextAssignment.create!(
      phrase: phrase,
      phrase_text: text1,
      language_role: :l1,
      primary: true
    )
    
    # Attempt to create second primary assignment should fail
    assert_raises(ActiveRecord::RecordInvalid) do
      PhraseTextAssignment.create!(
        phrase: phrase,
        phrase_text: text2,
        language_role: :l1,
        primary: true
      )
    end
  end
  
  test "should have proper model relationships" do
    # Test Script relationships
    assert_equal 0, @latin_script.phrase_texts.count
    assert_equal [@english], @latin_script.languages.to_a
    
    # Test Language relationship
    assert_equal @latin_script, @english.default_script
    
    # Create phrase text to test relationships
    phrase_text = PhraseText.create!(content: "Test", script: @latin_script)
    phrase = Phrase.create!(l1: @english, l2: @hebrew, medium: @medium, timestamp: "00:01:00")
    assignment = PhraseTextAssignment.create!(
      phrase: phrase,
      phrase_text: phrase_text,
      language_role: :l1,
      primary: true
    )
    
    # Test relationships
    assert_equal @latin_script, phrase_text.script
    assert_equal [assignment], phrase_text.phrase_text_assignments.to_a
    assert_equal [phrase], phrase_text.phrases.to_a
    assert_equal [assignment], phrase.phrase_text_assignments.to_a
    assert_equal [phrase_text], phrase.phrase_texts.to_a
  end
end