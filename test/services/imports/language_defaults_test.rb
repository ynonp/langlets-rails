require "test_helper"

module Imports
  class LanguageDefaultsTest < ActiveSupport::TestCase
    test "chooses useful translations for supported same-language pairs" do
      assert_equal "Hebrew", translation_language(clip_language: "English", translation_language: "English")
      assert_equal "English", translation_language(clip_language: "Hebrew", translation_language: "Hebrew")
      assert_equal "English", translation_language(clip_language: "Spanish", translation_language: "Spanish")
    end

    test "preserves an already distinct translation language" do
      assert_equal "Hebrew", translation_language(clip_language: "Spanish", translation_language: "Hebrew")
    end

    test "leaves unsupported same-language pairs for validation" do
      assert_equal "French", translation_language(clip_language: "French", translation_language: "French")
    end

    private

    def translation_language(**)
      LanguageDefaults.translation_language(**)
    end
  end
end
