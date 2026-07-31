require "test_helper"

class Api::V1::CoursesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      email: "api-courses@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    @spanish = languages(:spanish)

    @published = Course.create!(
      name: "API Spanish Songs", slug: "api-spanish-songs", main_media_url: "https://example.com/1",
      user: @user, language: @spanish, status: :published
    )
    @pending = Course.create!(
      name: "API Spanish Drafts", slug: "api-spanish-drafts", main_media_url: "https://example.com/2",
      user: @user, language: @spanish, status: :pending
    )

    # The endpoint is Channel-scoped to the token's resource owner.
    [ @published, @pending ].each { |course| publish_privately(course) }

    @token = create_access_token(@user)
  end

  test "requires a bearer token" do
    get api_v1_courses_url, params: { language: "es" }

    assert_response :unauthorized
    assert_includes @response.headers["WWW-Authenticate"], "resource_metadata="
  end

  test "rejects tokens without the courses:read scope" do
    wrong_scope = create_access_token(@user, scopes: "vocabulary:read")

    get api_v1_courses_url, params: { language: "es" }, headers: auth_headers(wrong_scope)

    assert_response :forbidden
  end

  test "requires the language parameter" do
    get api_v1_courses_url, headers: auth_headers(@token)

    assert_response :unprocessable_entity
    assert_equal "missing_parameter", JSON.parse(@response.body)["error"]
  end

  test "422s on unknown language" do
    get api_v1_courses_url, params: { language: "zz" }, headers: auth_headers(@token)

    assert_response :unprocessable_entity
    assert_equal "unknown_language", JSON.parse(@response.body)["error"]
  end

  test "returns published courses in the language with urls" do
    get api_v1_courses_url, params: { language: "es" }, headers: auth_headers(@token)

    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal [ "api-spanish-songs" ], body["items"].map { |i| i["slug"] }
    item = body["items"].first
    assert_equal "API Spanish Songs", item["name"]
    assert_equal "es", item["language"]
    assert_equal 0, item["lesson_count"]
    assert_includes item["url"], "/courses/api-spanish-songs"
  end
end
