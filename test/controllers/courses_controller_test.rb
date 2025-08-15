require "test_helper"

class CoursesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
      confirmed_at: Time.current
    )
    
    @spanish = languages(:spanish)
    @english = languages(:english)
    
    @course = Course.create!(
      name: "Test Course",
      slug: "test-course", 
      main_media_url: "https://youtube.com/watch?v=test",
      language: @spanish,
      user: @user,
      status: :published
    )
    
    @learning_path = LearningPath.create!(
      name: "Test Learning Path",
      description: "A test learning path",
      published: true
    )
  end
  
  def teardown
    @user&.destroy
    @course&.destroy
    @learning_path&.destroy
  end

  test "course show page displays Langlets when no learning_path_id" do
    get course_path(@course)
    assert_response :success
    assert_select "header a", text: "Langlets"
  end

  test "course show page displays learning path name when learning_path_id present" do
    get course_path(@course, learning_path_id: @learning_path.id)
    assert_response :success
    assert_select "header a", text: @learning_path.name
    # The link should go back to the learning path
    assert_select "header a[href='#{learning_path_path(@learning_path)}']"
  end

  test "course show page handles invalid learning_path_id gracefully" do
    get course_path(@course, learning_path_id: 99999)
    assert_response :success
    # Should fall back to Langlets when learning path not found
    assert_select "header a", text: "Langlets"
  end
end