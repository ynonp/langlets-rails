require "test_helper"
require "securerandom"

class LanguageSelectionTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "language-selection-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      confirmed_at: Time.current
    )

    @french_course = Course.create!(
      user: @user,
      language: languages(:french),
      status: :published,
      slug: "french-#{SecureRandom.hex(4)}",
      name: "French course #{SecureRandom.hex(4)}",
      main_media_url: "https://www.youtube.com/watch?v=#{SecureRandom.hex(8)}"
    )

    @hebrew_course = Course.create!(
      user: @user,
      language: languages(:hebrew),
      status: :published,
      slug: "hebrew-#{SecureRandom.hex(4)}",
      name: "Hebrew course #{SecureRandom.hex(4)}",
      main_media_url: "https://www.youtube.com/watch?v=#{SecureRandom.hex(8)}"
    )
  end

  test "language filter shows only selected language" do
    get root_path(lang: "fr")

    assert_response :success
    assert_includes response.body, @french_course.name
    assert_not_includes response.body, @hebrew_course.name
  end

  test "no lang param keeps all languages visible" do
    get root_path(lang: "fr")
    assert_response :success

    get "/"

    assert_response :success
    assert_includes response.body, @french_course.name
    assert_includes response.body, @hebrew_course.name
  end

  test "language selector is rendered in top bar" do
    get root_path

    assert_response :success
    assert_includes response.body, "All languages"
    assert_includes response.body, "data-controller=\"language-filter\""
    assert_includes response.body, "lang=fr"
    assert_includes response.body, "lang=he"
  end
end
