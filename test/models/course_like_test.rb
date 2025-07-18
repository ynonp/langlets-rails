require "test_helper"

class CourseLikeTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: 'test@example.com', password: 'password123', confirmed_at: Time.current)
    @course = Course.create!(
      name: 'Test Course',
      slug: 'test-course',
      main_media_url: 'https://youtube.com/watch?v=test',
      user: @user
    )
  end

  test "user can like a course" do
    like = @user.course_likes.create!(course: @course)
    assert like.persisted?
    assert_equal @user, like.user
    assert_equal @course, like.course
  end

  test "user cannot like the same course twice" do
    @user.course_likes.create!(course: @course)
    
    duplicate_like = @user.course_likes.build(course: @course)
    assert_not duplicate_like.valid?
    assert_includes duplicate_like.errors[:user_id], "has already been taken"
  end

  test "course likes_count works" do
    other_user = User.create!(email: 'other@example.com', password: 'password123', confirmed_at: Time.current)
    
    assert_equal 0, @course.likes_count
    
    @user.course_likes.create!(course: @course)
    assert_equal 1, @course.reload.likes_count
    
    other_user.course_likes.create!(course: @course)
    assert_equal 2, @course.reload.likes_count
  end

  test "course liked_by? works" do
    assert_not @course.liked_by?(@user)
    
    @user.course_likes.create!(course: @course)
    assert @course.liked_by?(@user)
  end

  test "liked_by? returns false for nil user" do
    assert_not @course.liked_by?(nil)
  end

  test "destroying course_like decreases likes_count" do
    like = @user.course_likes.create!(course: @course)
    assert_equal 1, @course.reload.likes_count
    
    like.destroy
    assert_equal 0, @course.reload.likes_count
  end

  test "user association works both ways" do
    @user.course_likes.create!(course: @course)
    
    assert_includes @user.liked_courses, @course
    assert_includes @course.liked_by_users, @user
  end
end