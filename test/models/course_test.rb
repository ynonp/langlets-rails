require "test_helper"

class CourseTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
  end

  test "show_full_course_player defaults to true for new courses" do
    course = Course.new(
      name: "Test Course",
      slug: "test-course-#{Time.zone.now.to_i}",
      main_media_url: "https://www.youtube.com/watch?v=test123",
      user: @user
    )
    
    assert course.show_full_course_player, "show_full_course_player should default to true"
  end

  test "show_full_course_player can be set to false" do
    course = Course.create!(
      name: "Test Course No Player",
      slug: "test-course-no-player-#{Time.zone.now.to_i}",
      main_media_url: "https://www.youtube.com/watch?v=test456",
      user: @user,
      show_full_course_player: false
    )
    
    assert_not course.show_full_course_player, "show_full_course_player should be false when explicitly set"
  end

  test "with_full_player scope returns only courses with full player enabled" do
    # Create courses with different show_full_course_player values
    course_with_player = Course.create!(
      name: "Course With Player",
      slug: "course-with-player-#{Time.zone.now.to_i}",
      main_media_url: "https://www.youtube.com/watch?v=test789",
      user: @user,
      show_full_course_player: true
    )
    
    course_without_player = Course.create!(
      name: "Course Without Player",
      slug: "course-without-player-#{Time.zone.now.to_i}",
      main_media_url: "https://www.youtube.com/watch?v=test101",
      user: @user,
      show_full_course_player: false
    )
    
    courses_with_player = Course.with_full_player
    
    assert_includes courses_with_player, course_with_player
    assert_not_includes courses_with_player, course_without_player
  end

  test "show_full_course_player cannot be nil" do
    course = Course.new(
      name: "Test Course Nil",
      slug: "test-course-nil-#{Time.zone.now.to_i}",
      main_media_url: "https://www.youtube.com/watch?v=test202",
      user: @user
    )
    
    # Try to set to nil - should raise a database constraint error
    course.show_full_course_player = nil
    
    assert_raises(ActiveRecord::NotNullViolation) do
      course.save!
    end
  end

  # --- sync_lesson_timestamps tests ---

  def setup_sync_test
    @english = languages(:english)
    @spanish = languages(:spanish)

    @medium = Medium.create!(
      url: "https://www.youtube.com/watch?v=sync-test",
      language: @english
    )

    @course = Course.create!(
      name: "Sync Test Course",
      slug: "sync-test-course-#{Time.zone.now.to_i}",
      main_media_url: "https://www.youtube.com/watch?v=sync-test",
      user: @user
    )

    @lesson1 = Lesson.create!(
      medium: @medium,
      slug: "lesson-1",
      course: @course,
      order: 0,
      name: "Lesson 1",
      user: @user
    )

    @lesson2 = Lesson.create!(
      medium: @medium,
      slug: "lesson-2",
      course: @course,
      order: 1,
      name: "Lesson 2",
      user: @user
    )

    @activity1 = Activities::WatchVideoActivity.create!(lesson: @lesson1, order: 1, user: @user)
    @activity2 = Activities::WatchVideoActivity.create!(lesson: @lesson2, order: 1, user: @user)

    @phrase1 = Phrase.create!(medium: @medium, l1: @english, l2: @spanish, text_l1: "A", text_l2: "A", timestamp: "00:01:00")
    @phrase2 = Phrase.create!(medium: @medium, l1: @english, l2: @spanish, text_l1: "B", text_l2: "B", timestamp: "00:02:00")
    @phrase3 = Phrase.create!(medium: @medium, l1: @english, l2: @spanish, text_l1: "C", text_l2: "C", timestamp: "00:03:00")
    @phrase4 = Phrase.create!(medium: @medium, l1: @english, l2: @spanish, text_l1: "D", text_l2: "D", timestamp: "00:04:00")

    @activity1.phrases << @phrase1
    @activity1.phrases << @phrase2
    @activity2.phrases << @phrase3
    @activity2.phrases << @phrase4
  end

  test "sync_lesson_timestamps sets start_timestamp to first phrase" do
    setup_sync_test

    @course.sync_lesson_timestamps

    assert_equal "00:01:00", @lesson1.reload.start_timestamp
    assert_equal "00:03:00", @lesson2.reload.start_timestamp
  end

  test "sync_lesson_timestamps sets end_timestamp to first phrase of next lesson" do
    setup_sync_test

    @course.sync_lesson_timestamps

    # Lesson 1 ends when Lesson 2 starts (first phrase of lesson 2)
    assert_equal "00:03:00", @lesson1.reload.end_timestamp
  end

  test "sync_lesson_timestamps sets end_timestamp of last lesson to last phrase + 5 seconds" do
    setup_sync_test

    @course.sync_lesson_timestamps

    # Last lesson: end = last phrase timestamp + 5 seconds
    expected_end = Phrase.to_string_timestamp(@phrase4.timestamp_seconds + 5)
    assert_equal expected_end, @lesson2.reload.end_timestamp
  end

  test "sync_lesson_timestamps skips lessons with no phrases" do
    setup_sync_test

    empty_lesson = Lesson.create!(
      medium: @medium,
      slug: "empty-lesson",
      course: @course,
      order: 2,
      name: "Empty",
      user: @user
    )

    # Should not raise
    @course.sync_lesson_timestamps

    # Empty lesson should remain unchanged
    assert_nil empty_lesson.reload.start_timestamp
    assert_nil empty_lesson.reload.end_timestamp
  end

  test "sync_lesson_timestamps handles single lesson" do
    setup_sync_test
    @lesson2.destroy!

    @course.sync_lesson_timestamps

    assert_equal "00:01:00", @lesson1.reload.start_timestamp
    expected_end = Phrase.to_string_timestamp(@phrase2.timestamp_seconds + 5)
    assert_equal expected_end, @lesson1.reload.end_timestamp
  end
end
