require "test_helper"

class TranslationLanguageContextTest < ActiveSupport::TestCase
  teardown { Current.reset }

  test "the subdomain selects the translation language and the main domain uses English" do
    controller = ApplicationController.new
    request = ActionDispatch::TestRequest.create
    request.host = "he.langlets.app"
    controller.set_request!(request)
    controller.send(:set_translation_language)
    assert_equal languages(:hebrew), Current.translation_language
    assert_equal :he, I18n.locale

    request.host = "langlets.app"
    controller.send(:set_translation_language)
    assert_equal languages(:english), Current.translation_language
    assert_equal :en, I18n.locale
  end

  test "configured locales without a catalog fall back to English" do
    I18n.with_locale(:es) do
      assert_equal "Correct! Well done!", I18n.t("js.word_order.correct")
    end
  end
end
