require "test_helper"

class LanguageTest < ActiveSupport::TestCase
  test "Chinese uses Mandarin speech for its catalog code and locale" do
    chinese = languages(:chinese)
    assert_equal "Chinese", chinese.english_name
    assert_equal "中文", chinese.native_name
    assert_not chinese.rtl?

    [chinese.iso_name, chinese.pronunciation_variant_name, "ZH-CN"].each do |code|
      assert_equal "zh-CN", Phrase.get_azure_language_code(code)
      assert_equal "zh-CN-XiaoxiaoNeural", Phrase.get_voice(code)
    end
  end

  test "Greek uses the supported Azure locale and voice" do
    assert_equal "el-GR", Phrase.get_azure_language_code(languages(:greek).iso_name)
    assert_equal "el-GR-AthinaNeural", Phrase.get_voice(languages(:greek).iso_name)
  end

  test "Swedish uses the supported Azure locale and voice" do
    assert_equal "sv-SE", Phrase.get_azure_language_code(languages(:swedish).iso_name)
    assert_equal "sv-SE-SofieNeural", Phrase.get_voice(languages(:swedish).iso_name)
  end
end
