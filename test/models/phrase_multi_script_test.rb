require "test_helper"

class PhraseMultiScriptTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
    # Create test languages
    @l1_language = Language.create!(
      iso_name: 'he',
      english_name: 'Hebrew',
      native_name: 'עברית',
      rtl: true
    )
    
    @l2_language = Language.create!(
      iso_name: 'en', 
      english_name: 'English',
      native_name: 'English'
    )
    
    # Create test medium
    @medium = Medium.create!(
      url: 'https://example.com'
    )

    # Create scripts
    @hebrew_script = Script.create!(name: "hebrew", iso_code: "Hebr", rtl: true)
    @latin_script = Script.create!(name: "latin", iso_code: "Latn", rtl: false)
    @arabic_script = Script.create!(name: "arabic", iso_code: "Arab", rtl: true)

    # Create test phrase
    @phrase = Phrase.create!(
      text_l1: "שלום עולם",
      text_l2: "Hello world", 
      l1: @l1_language,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )
  end

  test "should support multiple text variants for L1" do
    # Create Hebrew text in Hebrew script (primary)
    hebrew_text = PhraseText.create!(content: "שלום עולם", script: @hebrew_script)
    PhraseTextAssignment.create!(
      phrase: @phrase, 
      phrase_text: hebrew_text, 
      language_role: :l1, 
      primary: true
    )

    # Create Hebrew text in Latin script (transliteration)
    latin_text = PhraseText.create!(content: "Shalom olam", script: @latin_script)
    PhraseTextAssignment.create!(
      phrase: @phrase, 
      phrase_text: latin_text, 
      language_role: :l1, 
      primary: false
    )

    # Test accessing primary text
    assert_equal "שלום עולם", @phrase.text_l1_for_script
    
    # Test accessing specific script text
    assert_equal "שלום עולם", @phrase.text_l1_for_script(script: "hebrew")
    assert_equal "Shalom olam", @phrase.text_l1_for_script(script: "latin")
    
    # Test variants method
    variants = @phrase.text_l1_variants
    assert_equal 2, variants.length
    
    hebrew_variant = variants.find { |v| v[:script] == "hebrew" }
    latin_variant = variants.find { |v| v[:script] == "latin" }
    
    assert_equal "שלום עולם", hebrew_variant[:text]
    assert_equal "Shalom olam", latin_variant[:text]
  end

  test "should support multiple text variants for L2" do
    # Create English text
    english_text = PhraseText.create!(content: "Hello world", script: @latin_script)
    PhraseTextAssignment.create!(
      phrase: @phrase, 
      phrase_text: english_text, 
      language_role: :l2, 
      primary: true
    )

    # Test accessing L2 text
    assert_equal "Hello world", @phrase.text_l2_for_script
    assert_equal "Hello world", @phrase.text_l2_for_script(script: "latin")
    
    # Test variants method
    variants = @phrase.text_l2_variants
    assert_equal 1, variants.length
    assert_equal "latin", variants.first[:script]
    assert_equal "Hello world", variants.first[:text]
  end

  test "should return nil for non-existent script" do
    assert_nil @phrase.text_l1_for_script(script: "nonexistent")
    assert_nil @phrase.text_l2_for_script(script: "nonexistent")
  end

  test "should return nil when no primary text exists" do
    # Create only non-primary text
    hebrew_text = PhraseText.create!(content: "שלום עולם", script: @hebrew_script)
    PhraseTextAssignment.create!(
      phrase: @phrase, 
      phrase_text: hebrew_text, 
      language_role: :l1, 
      primary: false
    )

    assert_nil @phrase.text_l1_for_script
  end

  test "should return empty array when no variants exist" do
    assert_equal [], @phrase.text_l1_variants
    assert_equal [], @phrase.text_l2_variants
  end

  test "should maintain backward compatibility with original text_l1 and text_l2 fields" do
    # The original fields should still work
    assert_equal "שלום עולם", @phrase.text_l1
    assert_equal "Hello world", @phrase.text_l2
    
    # Update original fields
    @phrase.update!(text_l1: "שלום חדש", text_l2: "New hello")
    
    assert_equal "שלום חדש", @phrase.text_l1
    assert_equal "New hello", @phrase.text_l2
  end

  test "should handle complex multi-script scenario" do
    # Hebrew phrase with multiple scripts for L1
    hebrew_text = PhraseText.create!(content: "שלום עולם", script: @hebrew_script)
    latin_text = PhraseText.create!(content: "Shalom olam", script: @latin_script)
    
    # English L2 text
    english_text = PhraseText.create!(content: "Hello world", script: @latin_script)
    
    # Create assignments
    PhraseTextAssignment.create!(phrase: @phrase, phrase_text: hebrew_text, language_role: :l1, primary: true)
    PhraseTextAssignment.create!(phrase: @phrase, phrase_text: latin_text, language_role: :l1, primary: false)
    PhraseTextAssignment.create!(phrase: @phrase, phrase_text: english_text, language_role: :l2, primary: true)
    
    # Test all access methods
    assert_equal "שלום עולם", @phrase.text_l1_for_script # Primary Hebrew
    assert_equal "שלום עולם", @phrase.text_l1_for_script(script: "hebrew")
    assert_equal "Shalom olam", @phrase.text_l1_for_script(script: "latin")
    assert_equal "Hello world", @phrase.text_l2_for_script # Primary English
    
    # Test variants
    l1_variants = @phrase.text_l1_variants
    l2_variants = @phrase.text_l2_variants
    
    assert_equal 2, l1_variants.length
    assert_equal 1, l2_variants.length
    
    # Verify variant contents
    scripts = l1_variants.map { |v| v[:script] }.sort
    assert_equal ["hebrew", "latin"], scripts
  end

  test "should support relationships through phrase_text_assignments" do
    hebrew_text = PhraseText.create!(content: "שלום עולם", script: @hebrew_script)
    assignment = PhraseTextAssignment.create!(
      phrase: @phrase, 
      phrase_text: hebrew_text, 
      language_role: :l1, 
      primary: true
    )
    
    # Test phrase -> phrase_text_assignments
    assert_includes @phrase.phrase_text_assignments, assignment
    
    # Test phrase -> phrase_texts (through association)
    assert_includes @phrase.phrase_texts, hebrew_text
    
    # Test phrase_text -> phrases (through association)
    assert_includes hebrew_text.phrases, @phrase
  end

  test "should not interfere with existing audio generation" do
    # Should still queue audio generation job for original text_l1
    assert_enqueued_jobs 1, only: GeneratePhraseAudioJob do
      Phrase.create!(
        text_l1: "שלום חדש",
        text_l2: "New hello", 
        l1: @l1_language,
        l2: @l2_language,
        medium: @medium,
        timestamp: "00:02:00"
      )
    end
  end
end