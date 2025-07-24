require "test_helper"

class PhraseTest < ActiveSupport::TestCase
  def setup
    @latin_script = Script.find_or_create_by(code: 'Latn') { |s| s.name = 'Latin' }
    @hebrew_script = Script.find_or_create_by(code: 'Hebr') { |s| s.name = 'Hebrew' }
    
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
    
    @medium = Medium.create!(url: 'https://example.com/test')
  end

  test "creates phrase with backward compatibility" do
    phrase = Phrase.create!(
      medium: @medium,
      l1: @english,
      l2: @hebrew,
      text_l1: 'hello',
      text_l2: 'שלום',
      timestamp: '00:30'
    )

    # Should create multi-script texts automatically
    assert phrase.text_l1_multi.present?
    assert phrase.text_l2_multi.present?
    
    # Should return the correct text via backward compatibility methods
    assert_equal 'hello', phrase.text_l1
    assert_equal 'שלום', phrase.text_l2
  end

  test "text setters create multi-script texts" do
    phrase = Phrase.new(
      medium: @medium,
      l1: @english,
      l2: @hebrew,
      timestamp: '00:30'
    )

    phrase.text_l1 = 'hello'
    phrase.text_l2 = 'שלום'
    phrase.save!

    assert phrase.text_l1_multi.present?
    assert phrase.text_l2_multi.present?
    assert_equal @english, phrase.text_l1_multi.language
    assert_equal @hebrew, phrase.text_l2_multi.language
    
    # Check script variants were created
    l1_variant = phrase.text_l1_multi.variant_for_script(@latin_script)
    l2_variant = phrase.text_l2_multi.variant_for_script(@hebrew_script)
    
    assert l1_variant.present?
    assert l2_variant.present?
    assert_equal 'hello', l1_variant.content
    assert_equal 'שלום', l2_variant.content
  end

  test "multi-script functionality" do
    phrase = Phrase.create!(
      medium: @medium,
      l1: @hebrew,
      l2: @english,
      text_l1: 'שלום',
      text_l2: 'hello',
      timestamp: '00:30'
    )

    # Add Latin script variant for Hebrew text (transliteration)
    latin_variant = phrase.text_l1_multi.script_variants.create!(
      script: @latin_script,
      content: 'shalom'
    )

    # Test script-specific access
    assert_equal 'שלום', phrase.text_l1_for_script(@hebrew_script)
    assert_equal 'shalom', phrase.text_l1_for_script(@latin_script)
    
    # Test default content (should be Hebrew script for Hebrew language)
    assert_equal 'שלום', phrase.text_l1
    
    # Test has_script_variants detection
    assert phrase.has_script_variants?
  end

  test "requires multi-script texts for text access" do
    # Create phrase without setting text (should require multi-script texts now)
    phrase = Phrase.new(
      medium: @medium,
      l1: @english,
      l2: @hebrew,
      timestamp: '00:30'
    )
    
    # Create multi-script texts explicitly
    l1_text = MultiScriptText.create!(language: @english)
    l1_text.script_variants.create!(script: @latin_script, content: 'hello')
    
    l2_text = MultiScriptText.create!(language: @hebrew)
    l2_text.script_variants.create!(script: @hebrew_script, content: 'שלום')
    
    phrase.text_l1_multi = l1_text
    phrase.text_l2_multi = l2_text
    phrase.save!

    # Should access text via multi-script texts
    assert_equal 'hello', phrase.text_l1
    assert_equal 'שלום', phrase.text_l2
  end

  test "updating text creates or updates script variants" do
    phrase = Phrase.create!(
      medium: @medium,
      l1: @english,
      l2: @hebrew,
      text_l1: 'hello',
      text_l2: 'שלום',
      timestamp: '00:30'
    )

    original_l1_text_id = phrase.text_l1_id
    
    # Update text
    phrase.text_l1 = 'hi there'
    phrase.save!

    # Should reuse the same multi-script text
    assert_equal original_l1_text_id, phrase.text_l1_id
    
    # Content should be updated
    assert_equal 'hi there', phrase.text_l1
    
    # Verify the variant was updated
    variant = phrase.text_l1_multi.variant_for_script(@latin_script)
    assert_equal 'hi there', variant.content
  end
end