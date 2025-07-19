require "test_helper"

class CourseLikeTest < ActiveSupport::TestCase
  def setup
    # Create test data directly instead of using fixtures for now
    @user = User.create!(
      email: 'test@example.com',
      password: 'password123',
      confirmed_at: Time.current
    )
    @user2 = User.create!(
      email: 'test2@example.com', 
      password: 'password123',
      confirmed_at: Time.current
    )
    @course = Course.create!(
      name: 'Test Course',
      slug: 'test-course',
      main_media_url: 'https://youtube.com/watch?v=test',
      user: @user
    )
    @course2 = Course.create!(
      name: 'Test Course 2',
      slug: 'test-course-2',
      main_media_url: 'https://youtube.com/watch?v=test2',
      user: @user
    )
    @course_like = CourseLike.new(user: @user, course: @course)
  end

  test "should be valid with valid attributes" do
    assert @course_like.valid?
  end

  test "should require user" do
    @course_like.user = nil
    assert_not @course_like.valid?
    assert_includes @course_like.errors[:user], "must exist"
  end

  test "should require course" do
    @course_like.course = nil
    assert_not @course_like.valid?
    assert_includes @course_like.errors[:course], "must exist"
  end

  test "should not allow duplicate likes for same user and course" do
    @course_like.save!
    duplicate_like = CourseLike.new(user: @user, course: @course)
    assert_not duplicate_like.valid?
    assert_includes duplicate_like.errors[:user_id], "has already been taken"
  end

  test "should allow same user to like different courses" do
    @course_like.save!
    other_like = CourseLike.new(user: @user, course: @course2)
    assert other_like.valid?
  end

  test "should allow different users to like same course" do
    @course_like.save!
    other_like = CourseLike.new(user: @user2, course: @course)
    assert other_like.valid?
  end
end
