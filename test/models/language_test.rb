require "test_helper"

class LanguageTest < ActiveSupport::TestCase
  test "Greek uses the supported Azure locale and voice" do
    assert_equal "el-GR", Phrase.get_azure_language_code(languages(:greek).iso_name)
    assert_equal "el-GR-AthinaNeural", Phrase.get_voice(languages(:greek).iso_name)
  end

  test "Swedish uses the supported Azure locale and voice" do
    assert_equal "sv-SE", Phrase.get_azure_language_code(languages(:swedish).iso_name)
    assert_equal "sv-SE-SofieNeural", Phrase.get_voice(languages(:swedish).iso_name)
  end
end
