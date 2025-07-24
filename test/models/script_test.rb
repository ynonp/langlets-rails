require "test_helper"

class ScriptTest < ActiveSupport::TestCase
  test "should create script with valid attributes" do
    script = Script.create!(
      name: "latin",
      iso_code: "Latn",
      rtl: false
    )
    
    assert script.persisted?
    assert_equal "latin", script.name
    assert_equal "Latn", script.iso_code
    assert_equal false, script.rtl
  end

  test "should require name" do
    script = Script.new(iso_code: "Latn")
    assert_not script.valid?
    assert_includes script.errors[:name], "can't be blank"
  end

  test "should require unique name" do
    Script.create!(name: "latin", iso_code: "Latn")
    
    duplicate = Script.new(name: "latin", iso_code: "Latn")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "should allow blank iso_code" do
    script = Script.create!(name: "custom", iso_code: "")
    assert script.persisted?
    assert_equal "", script.iso_code
  end

  test "should default rtl to false" do
    script = Script.create!(name: "latin", iso_code: "Latn")
    assert_equal false, script.rtl
  end

  test "should support rtl languages" do
    script = Script.create!(name: "hebrew", iso_code: "Hebr", rtl: true)
    assert_equal true, script.rtl
  end

  test "should prevent deletion when phrase_texts exist" do
    script = Script.create!(name: "latin", iso_code: "Latn")
    PhraseText.create!(content: "Hello", script: script)
    
    assert_raises(ActiveRecord::RecordNotDestroyed) do
      script.destroy!
    end
  end
end