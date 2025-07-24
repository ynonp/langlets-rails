require "test_helper"

class ScriptTest < ActiveSupport::TestCase
  test "creates script with valid attributes" do
    script = Script.new(code: 'Test', name: 'Test Script')
    assert script.valid?
    assert script.save
  end

  test "requires code and name" do
    script = Script.new
    assert_not script.valid?
    assert_includes script.errors[:code], "can't be blank"
    assert_includes script.errors[:name], "can't be blank"
  end

  test "code must be unique" do
    Script.create!(code: 'Test', name: 'Test Script')
    script = Script.new(code: 'Test', name: 'Another Script')
    assert_not script.valid?
    assert_includes script.errors[:code], "has already been taken"
  end
end