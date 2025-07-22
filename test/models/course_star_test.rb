require "test_helper"

class CourseStarTest < ActiveSupport::TestCase
  def setup
    @user = users(:one) # assumes there's a user fixture
    @course = courses(:one) # assumes there's a course fixture
  end

  test "should create course star" do
    course_star = CourseStar.new(user: @user, course: @course)
    assert course_star.save
  end

  test "should not allow duplicate course stars" do
    CourseStar.create!(user: @user, course: @course)
    duplicate_star = CourseStar.new(user: @user, course: @course)
    assert_not duplicate_star.valid?
  end

  test "course should respond to star methods" do
    assert_respond_to @course, :stars_count
    assert_respond_to @course, :starred_by?
    assert_respond_to @course, :toggle_star
  end

  test "toggle_star should create and destroy stars" do
    # Initially no star
    assert_equal 0, @course.stars_count
    assert_not @course.starred_by?(@user)

    # Toggle to create star
    result = @course.toggle_star(@user)
    assert result # returns true when starred
    assert_equal 1, @course.stars_count
    assert @course.starred_by?(@user)

    # Toggle to remove star
    result = @course.toggle_star(@user)
    assert_not result # returns false when unstarred
    assert_equal 0, @course.stars_count
    assert_not @course.starred_by?(@user)
  end
end
