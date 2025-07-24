require "test_helper"

class PhraseTextAssignmentTest < ActiveSupport::TestCase
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

    # Create test phrase
    @phrase = Phrase.create!(
      text_l1: "שלום עולם",
      text_l2: "Hello world", 
      l1: @l1_language,
      l2: @l2_language,
      medium: @medium,
      timestamp: "00:01:30"
    )

    # Create scripts
    @hebrew_script = Script.create!(name: "hebrew", iso_code: "Hebr", rtl: true)
    @latin_script = Script.create!(name: "latin", iso_code: "Latn", rtl: false)

    # Create phrase texts
    @hebrew_text = PhraseText.create!(content: "שלום עולם", script: @hebrew_script)
    @latin_text = PhraseText.create!(content: "Shalom olam", script: @latin_script)
    @english_text = PhraseText.create!(content: "Hello world", script: @latin_script)
  end

  test "should create phrase_text_assignment with valid attributes" do
    assignment = PhraseTextAssignment.create!(
      phrase: @phrase,
      phrase_text: @hebrew_text,
      language_role: :l1,
      primary: true
    )
    
    assert assignment.persisted?
    assert_equal @phrase, assignment.phrase
    assert_equal @hebrew_text, assignment.phrase_text
    assert_equal "l1", assignment.language_role
    assert_equal true, assignment.primary
  end

  test "should validate enum language_role" do
    assignment = PhraseTextAssignment.new(
      phrase: @phrase,
      phrase_text: @hebrew_text
    )
    
    assert_raises(ArgumentError, /is not a valid language_role/) do
      assignment.language_role = "invalid"
    end
  end

  test "should allow only one primary assignment per phrase and language role" do
    # Create first primary assignment
    PhraseTextAssignment.create!(
      phrase: @phrase,
      phrase_text: @hebrew_text,
      language_role: :l1,
      primary: true
    )
    
    # Try to create second primary assignment for same phrase and language role
    duplicate = PhraseTextAssignment.new(
      phrase: @phrase,
      phrase_text: @latin_text,
      language_role: :l1,
      primary: true
    )
    
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:phrase_id], "can only have one primary text per language role"
  end

  test "should allow multiple non-primary assignments per phrase and language role" do
    # Create primary assignment
    PhraseTextAssignment.create!(
      phrase: @phrase,
      phrase_text: @hebrew_text,
      language_role: :l1,
      primary: true
    )
    
    # Create non-primary assignment
    secondary = PhraseTextAssignment.create!(
      phrase: @phrase,
      phrase_text: @latin_text,
      language_role: :l1,
      primary: false
    )
    
    assert secondary.persisted?
  end

  test "should allow primary assignments for different language roles" do
    # Create primary L1 assignment
    l1_assignment = PhraseTextAssignment.create!(
      phrase: @phrase,
      phrase_text: @hebrew_text,
      language_role: :l1,
      primary: true
    )
    
    # Create primary L2 assignment
    l2_assignment = PhraseTextAssignment.create!(
      phrase: @phrase,
      phrase_text: @english_text,
      language_role: :l2,
      primary: true
    )
    
    assert l1_assignment.persisted?
    assert l2_assignment.persisted?
  end

  test "should default primary to false" do
    assignment = PhraseTextAssignment.create!(
      phrase: @phrase,
      phrase_text: @hebrew_text,
      language_role: :l1
    )
    
    assert_equal false, assignment.primary
  end

  test "should require phrase" do
    assignment = PhraseTextAssignment.new(
      phrase_text: @hebrew_text,
      language_role: :l1
    )
    
    assert_not assignment.valid?
    assert_includes assignment.errors[:phrase], "must exist"
  end

  test "should require phrase_text" do
    assignment = PhraseTextAssignment.new(
      phrase: @phrase,
      language_role: :l1
    )
    
    assert_not assignment.valid?
    assert_includes assignment.errors[:phrase_text], "must exist"
  end

  test "should validate primary field inclusion" do
    assignment = PhraseTextAssignment.new(
      phrase: @phrase,
      phrase_text: @hebrew_text,
      language_role: :l1,
      primary: nil
    )
    
    assert_not assignment.valid?
    assert_includes assignment.errors[:primary], "is not included in the list"
  end
end