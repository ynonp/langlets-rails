require "test_helper"

class CourseProgressResetTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      email: "course-progress-reset@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    @course = Course.create!(
      user: @user,
      name: "Resettable course",
      slug: "resettable-course-#{SecureRandom.hex(4)}",
      main_media_url: "https://www.youtube.com/watch?v=reset123",
      status: :published
    )
    @lesson = Lesson.create!(
      course: @course,
      user: @user,
      slug: "first-lesson",
      name: "First lesson",
      order: 0
    )
    @activity = Activity.create!(lesson: @lesson, user: @user, order: 0)

    post user_session_url,
      params: { user: { email: @user.email, password: "password123" } }
  end

  test "resetting a done course removes lesson and activity progress" do
    other_user = User.create!(
      email: "other-course-progress@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    LessonUser.create!(lesson: @lesson, user: @user)
    ActivityUser.create!(activity: @activity, user: @user)
    other_lesson_progress = LessonUser.create!(lesson: @lesson, user: other_user)
    other_activity_progress = ActivityUser.create!(activity: @activity, user: other_user)

    post reset_progress_course_url(@course.slug)

    assert_redirected_to course_path(@course.slug)
    assert_not LessonUser.exists?(lesson: @lesson, user: @user)
    assert_not ActivityUser.exists?(activity: @activity, user: @user)
    assert LessonUser.exists?(other_lesson_progress.id)
    assert ActivityUser.exists?(other_activity_progress.id)

    other_lesson_progress.destroy!
    lesson_with_progress = @course.lessons.with_progress_data(@user).find(@lesson.id)
    assert lesson_with_progress.not_started?
  end
end
