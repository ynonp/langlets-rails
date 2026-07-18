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

    request.host = "langlets.app"
    controller.send(:set_translation_language)
    assert_equal languages(:english), Current.translation_language
  end
end
