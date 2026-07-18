require "test_helper"

class LessonsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "lesson-finish@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    @medium = Medium.create!(
      url: "https://www.youtube.com/watch?v=lessonfinish",
      language: languages(:english)
    )
    @course = Course.create!(
      name: "Lesson finish course",
      slug: "lesson-finish-course",
      main_media_url: @medium.url,
      language: languages(:english),
      user: @user
    )
    @lesson = Lesson.create!(
      course: @course,
      medium: @medium,
      user: @user,
      slug: "speech-lesson",
      name: "Speech lesson",
      order: 1
    )
    @speech_activity = Activities::SpeakActivity.create!(
      lesson: @lesson,
      order: 1,
      user: @user
    )

    post user_session_url, params: {
      user: { email: @user.email, password: "password123" }
    }
  end

  test "finish marks lesson complete when an activity was skipped" do
    assert_not ActivityUser.exists?(activity: @speech_activity, user: @user)

    assert_difference -> { LessonUser.where(lesson: @lesson, user: @user).count }, 1 do
      get finish_course_lesson_url(@course, @lesson)
    end

    assert_response :success
    assert @lesson.completed_by?(@user)
    assert_not ActivityUser.exists?(activity: @speech_activity, user: @user)
  end

  test "finish is idempotent for an already completed lesson" do
    LessonUser.create!(lesson: @lesson, user: @user)

    assert_no_difference -> { LessonUser.where(lesson: @lesson, user: @user).count } do
      get finish_course_lesson_url(@course, @lesson)
    end

    assert_response :success
  end
end
