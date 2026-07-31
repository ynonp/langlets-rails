require "test_helper"

class CourseDeleteTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      email: "course-delete@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    @course = Course.create!(
      user: @user,
      name: "Deletable course",
      slug: "deletable-course-#{SecureRandom.hex(4)}",
      main_media_url: "https://www.youtube.com/watch?v=delete123",
      youtube_video_id: "delete123",
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
    @user.default_channel.publish!(@course)
    @enrollment = Enrollment.create!(user: @user, course: @course, source: :library)

    post user_session_url,
      params: { user: { email: @user.email, password: "password123" } }
  end

  test "deleting a course unpublishes it from the user's default channel and clears their progress" do
    LessonUser.create!(lesson: @lesson, user: @user)
    ActivityUser.create!(activity: @activity, user: @user)
    ActivityLog.create!(lesson: @lesson, user: @user, active_time: 30, xp_gained: 10)

    delete course_url(@course.slug)

    assert_redirected_to root_path
    assert_not @user.default_channel.channel_items.exists?(course: @course)
    assert_not Enrollment.exists?(user: @user, course: @course)
    assert_not LessonUser.exists?(lesson: @lesson, user: @user)
    assert_not ActivityUser.exists?(activity: @activity, user: @user)
    assert_not ActivityLog.exists?(lesson: @lesson, user: @user)
    # The shared course row itself is untouched.
    assert @course.reload.published?
  end

  test "deleting a course leaves other users' progress and channels untouched" do
    other_user = User.create!(
      email: "other-course-delete@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    other_user.default_channel.publish!(@course)
    other_enrollment = Enrollment.create!(user: other_user, course: @course, source: :library)
    other_lesson_progress = LessonUser.create!(lesson: @lesson, user: other_user)

    delete course_url(@course.slug)

    assert_redirected_to root_path
    assert other_user.default_channel.channel_items.exists?(course: @course)
    assert Enrollment.exists?(other_enrollment.id)
    assert LessonUser.exists?(other_lesson_progress.id)
  end

  test "re-importing after deletion republishes the course to the user's channel" do
    delete course_url(@course.slug)
    assert_not @user.default_channel.channel_items.exists?(course: @course)

    @user.default_channel.publish!(@course)

    assert @user.default_channel.channel_items.exists?(course: @course)
    assert_not Enrollment.exists?(user: @user, course: @course)
  end
end
