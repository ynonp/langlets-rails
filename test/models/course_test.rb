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
end
