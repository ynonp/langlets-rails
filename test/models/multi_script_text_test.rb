require "test_helper"

class MultiScriptTextTest < ActiveSupport::TestCase
  def setup
    @latin_script = Script.find_or_create_by(code: 'Latn') { |s| s.name = 'Latin' }
    @hebrew_script = Script.find_or_create_by(code: 'Hebr') { |s| s.name = 'Hebrew' }
    @language = Language.create!(
      iso_name: 'he',
      english_name: 'Hebrew',
      native_name: 'עברית',
      default_script: @hebrew_script
    )
    @multi_script_text = MultiScriptText.create!(language: @language)
  end

  test "belongs to language" do
    assert_equal @language, @multi_script_text.language
  end

  test "can have script variants" do
    variant = @multi_script_text.script_variants.create!(
      script: @hebrew_script,
      content: 'שלום'
    )
    assert_includes @multi_script_text.script_variants, variant
  end

  test "variant_for_script returns correct variant" do
    hebrew_variant = @multi_script_text.script_variants.create!(
      script: @hebrew_script,
      content: 'שלום'
    )
    latin_variant = @multi_script_text.script_variants.create!(
      script: @latin_script,
      content: 'shalom'
    )

    assert_equal hebrew_variant, @multi_script_text.variant_for_script(@hebrew_script)
    assert_equal latin_variant, @multi_script_text.variant_for_script(@latin_script)
  end

  test "default_content returns content in language's default script" do
    @multi_script_text.script_variants.create!(
      script: @hebrew_script,
      content: 'שלום'
    )
    assert_equal 'שלום', @multi_script_text.default_content
  end

  test "content_for_script with fallback" do
    # Only create Hebrew variant
    @multi_script_text.script_variants.create!(
      script: @hebrew_script,
      content: 'שלום'
    )

    # Should return Hebrew content for Hebrew script
    assert_equal 'שלום', @multi_script_text.content_for_script(@hebrew_script)
    
    # Should fall back to default content for Latin script
    assert_equal 'שלום', @multi_script_text.content_for_script(@latin_script)
  end
end