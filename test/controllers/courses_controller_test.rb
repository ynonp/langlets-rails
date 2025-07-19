require "test_helper"

class CoursesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      email: 'test@example.com',
      password: 'password123',
      confirmed_at: Time.current
    )
    @course = Course.create!(
      name: 'Test Course',
      slug: 'test-course',
      main_media_url: 'https://youtube.com/watch?v=test',
      user: @user,
      status: :published
    )
  end

  test "should get index" do
    get courses_path
    assert_response :success
  end

  test "should get show" do
    get course_path(@course)
    assert_response :success
  end

  test "like action requires authentication" do
    post like_course_path(@course)
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "unlike action requires authentication" do
    delete unlike_course_path(@course)
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "like action creates course like when authenticated" do
    sign_in @user
    
    assert_difference 'CourseLike.count', 1 do
      post like_course_path(@course), as: :json
    end
    
    assert_response :success
    response_json = JSON.parse(response.body)
    assert_equal true, response_json['liked']
    assert_equal 1, response_json['likes_count']
  end

  test "like action returns error for duplicate like" do
    sign_in @user
    @course.course_likes.create!(user: @user)
    
    assert_no_difference 'CourseLike.count' do
      post like_course_path(@course), as: :json
    end
    
    assert_response :unprocessable_entity
    response_json = JSON.parse(response.body)
    assert response_json['error']
  end

  test "unlike action removes course like when authenticated" do
    sign_in @user
    @course.course_likes.create!(user: @user)
    
    assert_difference 'CourseLike.count', -1 do
      delete unlike_course_path(@course), as: :json
    end
    
    assert_response :success
    response_json = JSON.parse(response.body)
    assert_equal false, response_json['liked']
    assert_equal 0, response_json['likes_count']
  end

  test "unlike action returns error when no like exists" do
    sign_in @user
    
    assert_no_difference 'CourseLike.count' do
      delete unlike_course_path(@course), as: :json
    end
    
    assert_response :unprocessable_entity
    response_json = JSON.parse(response.body)
    assert response_json['error']
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: { email: user.email, password: 'password123' }
    }
  end
end
