require "test_helper"

class CourseProgressResetTest < ActionDispatch::IntegrationTest
  NATIVE = { "User-Agent" => "LangletsNative" }.freeze

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
      main_media_url: "https://www.youtube.com/watch?v=reset123abc",
      youtube_video_id: "reset123abc",
      status: :published
    )
    publish_privately(@course)
    @lesson = Lesson.create!(
      course: @course,
      user: @user,
      slug: "first-lesson",
      name: "First lesson",
      order: 0
    )
    @activity = Activity.create!(lesson: @lesson, user: @user, order: 0)
    @enrollment = Enrollment.create!(
      user: @user,
      course: @course,
      source: :library,
      last_practiced_at: 1.hour.ago
    )
    post user_session_url,
      params: { user: { email: @user.email, password: "password123" } }
  end

  test "marking a course done removes it from Continue Learning" do
    get app_home_url, headers: NATIVE
    assert_select "[data-testid='keep-it-going'] a[href='#{course_path(@course)}']"

    post mark_done_course_url(@course.slug)

    assert_redirected_to course_path(@course.slug)
    assert_equal @course.lessons.count,
                 LessonUser.where(lesson: @course.lessons, user: @user).count

    get app_home_url, headers: NATIVE
    assert_select "[data-testid='keep-it-going'] a[href='#{course_path(@course)}']", count: 0
  end

  test "resetting a done course removes all course activity and keeps it out of Continue Learning" do
    other_user = User.create!(
      email: "other-course-progress@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    LessonUser.create!(lesson: @lesson, user: @user)
    ActivityUser.create!(activity: @activity, user: @user)
    other_lesson_progress = LessonUser.create!(lesson: @lesson, user: other_user)
    other_activity_progress = ActivityUser.create!(activity: @activity, user: other_user)
    course_log = ActivityLog.create!(
      lesson: @lesson, user: @user, active_time: 30, xp_gained: 10
    )
    other_user_log = ActivityLog.create!(
      lesson: @lesson, user: other_user, active_time: 20, xp_gained: 5
    )
    unrelated_log = ActivityLog.create!(
      user: @user, active_time: 10, xp_gained: 2
    )

    post reset_progress_course_url(@course.slug)

    assert_redirected_to course_path(@course.slug)
    assert_not LessonUser.exists?(lesson: @lesson, user: @user)
    assert_not ActivityUser.exists?(activity: @activity, user: @user)
    assert_not ActivityLog.exists?(course_log.id)
    assert_nil @enrollment.reload.last_practiced_at
    assert LessonUser.exists?(other_lesson_progress.id)
    assert ActivityUser.exists?(other_activity_progress.id)
    assert ActivityLog.exists?(other_user_log.id)
    assert ActivityLog.exists?(unrelated_log.id)

    other_lesson_progress.destroy!
    lesson_with_progress = @course.lessons.with_progress_data(@user).find(@lesson.id)
    assert lesson_with_progress.not_started?

    get app_home_url, headers: NATIVE
    assert_select "[data-testid='keep-it-going'] a[href='#{course_path(@course)}']", count: 0
  end
end
