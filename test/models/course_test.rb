require "test_helper"

class CourseTest < ActiveSupport::TestCase
  def setup
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
  end

  test "liked_by? returns false when user is nil" do
    assert_not @course.liked_by?(nil)
  end

  test "liked_by? returns false when user has not liked course" do
    assert_not @course.liked_by?(@user)
  end

  test "liked_by? returns true when user has liked course" do
    @course.course_likes.create!(user: @user)
    assert @course.liked_by?(@user)
  end

  test "likes_count returns 0 when no likes" do
    assert_equal 0, @course.likes_count
  end

  test "likes_count returns correct count" do
    @course.course_likes.create!(user: @user)
    @course.course_likes.create!(user: @user2)
    assert_equal 2, @course.likes_count
  end

  test "has_many course_likes association" do
    like1 = @course.course_likes.create!(user: @user)
    like2 = @course.course_likes.create!(user: @user2)
    
    assert_includes @course.course_likes, like1
    assert_includes @course.course_likes, like2
  end

  test "has_many liked_by_users through course_likes" do
    @course.course_likes.create!(user: @user)
    @course.course_likes.create!(user: @user2)
    
    assert_includes @course.liked_by_users, @user
    assert_includes @course.liked_by_users, @user2
  end

  test "destroying course destroys associated course_likes" do
    @course.course_likes.create!(user: @user)
    @course.course_likes.create!(user: @user2)
    
    assert_difference 'CourseLike.count', -2 do
      @course.destroy
    end
  end
end
