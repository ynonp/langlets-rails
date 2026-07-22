require "test_helper"

class CoursesControllerTest < ActionDispatch::IntegrationTest
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
