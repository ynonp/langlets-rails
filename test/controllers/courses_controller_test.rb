require "test_helper"

class CoursesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @language = languages(:english)
    @user = User.create!(
      email: "course-show-queries@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    @course = Course.create!(
      name: "Query course",
      slug: "query-course",
      main_media_url: "https://www.youtube.com/watch?v=querycourse",
      language: @language,
      user: @user
    )

    3.times do |index|
      lesson = Lesson.create!(
        course: @course,
        user: @user,
        name: "Lesson #{index}",
        slug: "lesson-#{index}",
        order: index
      )
      lesson.lesson_translations.create!(language: @language, name: "Translated lesson #{index}")
    end
  end

  test "show preloads localized lesson names" do
    queries = capture_selects { get course_url(@course) }

    assert_response :success
    translation_queries = queries.grep(/FROM "lesson_translations"/)
    assert_equal 1, translation_queries.size
    assert_match(/IN \(/, translation_queries.first)
  end

  test "homepage shows at most eight videos and links to the gallery" do
    @course.update!(status: :published)
    9.times do |index|
      Course.create!(
        name: "Homepage course #{index}",
        slug: "homepage-course-#{index}",
        main_media_url: "https://www.youtube.com/watch?v=homepage#{index}",
        language: @language,
        user: @user,
        status: :published
      )
    end

    sign_in @user
    get root_url

    assert_response :success
    assert_select ".lp-card", count: 8
    assert_select "a[href='#{gallery_path}']", text: "Browse Langlets"
    assert_select "a[href='#{gallery_path}']", text: "Browse All Langlets"
  end

  test "homepage keeps French among its preview languages" do
    french_course = Course.create!(
      name: "French homepage course",
      slug: "french-homepage-course",
      main_media_url: "https://www.youtube.com/watch?v=frenchhome",
      language: languages(:french),
      user: @user,
      status: :published
    )

    8.times do |index|
      Course.create!(
        name: "Newer English course #{index}",
        slug: "newer-english-course-#{index}",
        main_media_url: "https://www.youtube.com/watch?v=newer#{index}",
        language: @language,
        user: @user,
        status: :published
      )
    end

    french_course.touch(time: 1.day.ago)
    get root_url

    assert_response :success
    assert_select ".lp-card", count: 8
    assert_select ".lp-chip", text: "French"
    assert_select ".lp-card[href='#{course_path(french_course.slug)}']"
  end

  private

  def capture_selects
    queries = []
    callback = lambda do |_name, _start, _finish, _id, payload|
      next if payload[:name] == "SCHEMA" || payload[:cached]

      queries << payload[:sql].squish if payload[:sql].to_s.lstrip.start_with?("SELECT")
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries
  end
end
