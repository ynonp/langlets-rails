require "test_helper"

class CoursesHomepageSubheadTest < ActionDispatch::IntegrationTest
  test "shows the generic subhead without a language" do
    get root_path(lang: "all")

    assert_response :success
    assert_select "header h1", text: "Langlets"
    assert_select "header p", text: "Learn languages from youtube"
  end

  test "shows the configured language subhead for a short language code" do
    get root_path(lang: "ar")

    assert_response :success
    assert_select "header p", text: "Learn Arabic from YouTube"
  end

  test "uses the base language for a regional language code" do
    get root_path(lang: "ar-JO")

    assert_response :success
    assert_select "header p", text: "Learn Arabic from YouTube"
  end

  test "falls back to the generic subhead for an unconfigured language" do
    get root_path(lang: "unknown")

    assert_response :success
    assert_select "header p", text: "Learn languages from youtube"
  end
end
