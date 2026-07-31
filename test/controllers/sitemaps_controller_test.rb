require "test_helper"

class SitemapsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @language = languages(:english)
    @user = User.create!(
      email: "sitemap-owner@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    @channel = @user.default_channel
  end

  test "lists courses published to a public channel" do
    @channel.update!(visibility: :public)
    course = create_course("Public Sitemap Course")

    get "/sitemap.xml"

    assert_response :success
    assert_includes @response.body, course_path(course)
  end

  test "omits courses that only live in a private channel" do
    @channel.update!(visibility: :private)
    course = create_course("Private Sitemap Course")

    get "/sitemap.xml"

    assert_response :success
    refute_includes @response.body, course_path(course)
  end

  test "omits courses that only live in a shared channel" do
    @channel.update!(visibility: :shared)
    course = create_course("Shared Sitemap Course")

    get "/sitemap.xml"

    assert_response :success
    refute_includes @response.body, course_path(course)
  end

  test "omits a public course that is not published yet" do
    @channel.update!(visibility: :public)
    course = create_course("Processing Sitemap Course", status: :processing)

    get "/sitemap.xml"

    assert_response :success
    refute_includes @response.body, course_path(course)
  end

  test "omits a public course whose translation is still processing" do
    @channel.update!(visibility: :public)
    course = create_course("Untranslated Sitemap Course")
    course.course_translations.create!(
      language: @language,
      name: course.name,
      status: :pending
    )

    get "/sitemap.xml"

    assert_response :success
    refute_includes @response.body, course_path(course)
  end

  test "always lists the static pages" do
    get "/sitemap.xml"

    assert_response :success
    assert_includes @response.body, "https://langlets.app#{root_path}"
    assert_includes @response.body, "https://langlets.app#{home_privacy_path}"
    assert_includes @response.body, "https://langlets.app#{home_terms_path}"
  end

  private

  def create_course(name, status: :published)
    course = Course.create!(
      name: name,
      slug: name.parameterize,
      main_media_url: "https://www.youtube.com/watch?v=#{SecureRandom.hex(6)}",
      language: @language,
      user: @user,
      status: status
    )
    @channel.publish!(course)
    course
  end
end
