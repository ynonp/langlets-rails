require "test_helper"

class PhraseTextTest < ActiveSupport::TestCase
  def setup
    @script = Script.create!(name: "latin", iso_code: "Latn")
  end

  test "should create phrase_text with valid attributes" do
    phrase_text = PhraseText.create!(
      content: "Hello world",
      script: @script
    )
    
    assert phrase_text.persisted?
    assert_equal "Hello world", phrase_text.content
    assert_equal @script, phrase_text.script
  end

  test "should require content" do
    phrase_text = PhraseText.new(script: @script)
    assert_not phrase_text.valid?
    assert_includes phrase_text.errors[:content], "can't be blank"
  end

  test "should require script" do
    phrase_text = PhraseText.new(content: "Hello world")
    assert_not phrase_text.valid?
    assert_includes phrase_text.errors[:script], "must exist"
  end

  test "should support unicode content" do
    hebrew_script = Script.create!(name: "hebrew", iso_code: "Hebr", rtl: true)
    phrase_text = PhraseText.create!(
      content: "שלום עולם",
      script: hebrew_script
    )
    
    assert phrase_text.persisted?
    assert_equal "שלום עולם", phrase_text.content
  end

  test "should allow long content" do
    long_content = "This is a very long phrase that contains many words and should be able to be stored without any issues in the database as text field."
    phrase_text = PhraseText.create!(
      content: long_content,
      script: @script
    )
    
    assert phrase_text.persisted?
    assert_equal long_content, phrase_text.content
  end
end