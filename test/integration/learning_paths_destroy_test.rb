require "test_helper"

class LearningPathsDestroyTest < ActionDispatch::IntegrationTest
  def setup
    @admin = User.create!(
      email: "ynon@hey.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    @other = User.create!(
      email: "someone@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    @course = Course.create!(
      user: @admin,
      name: "Test Course #{SecureRandom.hex(4)}",
      slug: "test-course-#{SecureRandom.hex(4)}",
      main_media_url: "https://www.youtube.com/watch?v=abc123",
      status: :published
    )
    @path = LearningPath.create!(name: "Deletable Path", published: true, slug: "deletable-#{SecureRandom.hex(4)}")
    @path.courses << @course
  end

  def sign_in(user)
    post user_session_url, params: { user: { email: user.email, password: "password123" } }
  end

  test "show page renders the Delete button for a manager" do
    sign_in(@admin)
    get learning_path_url(@path)
    assert_response :success
    assert_select "form[action=?][method=post] button", learning_path_path(@path)
    assert_select "button", text: /Delete/
  end

  test "show page hides the Delete button for a non-manager" do
    sign_in(@other)
    get learning_path_url(@path)
    assert_response :success
    assert_select "form[action=?]", learning_path_path(@path), count: 0
  end

  test "show page hides the Delete button for anonymous users" do
    get learning_path_url(@path)
    assert_response :success
    assert_select "form[action=?]", learning_path_path(@path), count: 0
  end

  test "manager can delete a learning path without destroying its courses" do
    sign_in(@admin)
    assert_difference "LearningPath.count", -1 do
      assert_no_difference "Course.count" do
        delete learning_path_url(@path)
      end
    end
    assert_redirected_to root_path
    assert Course.exists?(@course.id)
  end

  test "non-manager is forbidden from deleting a learning path" do
    sign_in(@other)
    assert_raises(CanCan::AccessDenied) do
      delete learning_path_url(@path)
    end
    assert LearningPath.exists?(@path.id)
  end

  test "anonymous users are redirected when attempting to delete" do
    delete learning_path_url(@path)
    assert_redirected_to new_user_session_path
    assert LearningPath.exists?(@path.id)
  end
end
