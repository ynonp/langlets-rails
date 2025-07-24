require "test_helper"

class ScriptVariantTest < ActiveSupport::TestCase
  def setup
    @script = Script.find_or_create_by(code: 'Latn') { |s| s.name = 'Latin' }
    @language = Language.create!(
      iso_name: 'en',
      english_name: 'English',
      native_name: 'English',
      default_script: @script
    )
    @multi_script_text = MultiScriptText.create!(language: @language)
  end

  test "creates script variant with valid attributes" do
    variant = ScriptVariant.new(
      multi_script_text: @multi_script_text,
      script: @script,
      content: 'hello'
    )
    assert variant.valid?
    assert variant.save
  end

  test "requires content" do
    variant = ScriptVariant.new(
      multi_script_text: @multi_script_text,
      script: @script
    )
    assert_not variant.valid?
    assert_includes variant.errors[:content], "can't be blank"
  end

  test "script_id must be unique per multi_script_text" do
    ScriptVariant.create!(
      multi_script_text: @multi_script_text,
      script: @script,
      content: 'hello'
    )
    
    variant = ScriptVariant.new(
      multi_script_text: @multi_script_text,
      script: @script,
      content: 'hello again'
    )
    assert_not variant.valid?
    assert_includes variant.errors[:script_id], "has already been taken"
  end
end