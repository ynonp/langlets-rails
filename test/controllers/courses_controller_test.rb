require "test_helper"

class CoursesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(email: 'test@example.com', password: 'password123', confirmed_at: Time.current)
    @course = Course.create!(
      name: 'Test Course',
      slug: 'test-course', 
      main_media_url: 'https://youtube.com/watch?v=test',
      user: @user
    )
  end

  test "should get index" do
    get courses_index_url
    assert_response :success
  end

  test "should get show" do
    get course_url(@course)
    assert_response :success
  end

  test "toggle_like should require authentication" do
    post toggle_like_course_path(@course)
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "toggle_like should like a course when not liked" do
    sign_in @user
    
    assert_equal 0, @course.likes_count
    assert_not @course.liked_by?(@user)
    
    post toggle_like_course_path(@course)
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['liked']
    assert_equal 1, response_data['likes_count']
    
    @course.reload
    assert_equal 1, @course.likes_count
    assert @course.liked_by?(@user)
  end

  test "toggle_like should unlike a course when already liked" do
    sign_in @user
    @user.course_likes.create!(course: @course)
    
    assert_equal 1, @course.likes_count
    assert @course.liked_by?(@user)
    
    post toggle_like_course_path(@course)
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert_not response_data['liked']
    assert_equal 0, response_data['likes_count']
    
    @course.reload
    assert_equal 0, @course.likes_count
    assert_not @course.liked_by?(@user)
  end

  test "toggle_like should work with course slug" do
    sign_in @user
    
    post toggle_like_course_path(@course.slug)
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['liked']
    assert_equal 1, response_data['likes_count']
  end
end
