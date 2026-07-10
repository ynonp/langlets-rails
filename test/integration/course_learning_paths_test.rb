require "test_helper"

class CourseLearningPathsTest < ActionDispatch::IntegrationTest
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
    @path = LearningPath.create!(name: "Existing Path", published: true, slug: "existing-#{SecureRandom.hex(4)}")
  end

  def sign_in(user)
    post user_session_url, params: { user: { email: user.email, password: "password123" } }
  end

  test "show page renders the + button for a manager" do
    sign_in(@admin)
    get course_url(@course.slug)
    assert_response :success
    assert_select 'button[data-action="course-paths#open"]'
    assert_select '[data-controller="course-paths"]'
  end

  test "show page hides the + button for anonymous users" do
    get course_url(@course.slug)
    assert_response :success
    assert_select 'button[data-action="course-paths#open"]', count: 0
  end

  test "index returns paths with membership flags" do
    @course.learning_paths << @path
    sign_in(@admin)
    get course_learning_paths_url(@course.slug), headers: { "Accept" => "application/json" }
    assert_response :success
    body = JSON.parse(response.body)
    entry = body["paths"].find { |p| p["id"] == @path.id }
    assert entry["member"]
  end

  test "create attaches an existing path" do
    sign_in(@admin)
    assert_difference "CoursesLearningPath.count", 1 do
      post course_learning_paths_url(@course.slug),
        params: { learning_path_id: @path.id }.to_json,
        headers: { "Content-Type" => "application/json", "Accept" => "application/json" }
    end
    assert_response :success
    assert JSON.parse(response.body)["path"]["member"]
    assert_includes @course.reload.learning_paths, @path
  end

  test "create builds a brand new learning path" do
    sign_in(@admin)
    assert_difference [ "LearningPath.count", "CoursesLearningPath.count" ], 1 do
      post course_learning_paths_url(@course.slug),
        params: { name: "Fresh Path" }.to_json,
        headers: { "Content-Type" => "application/json", "Accept" => "application/json" }
    end
    assert_response :success
    new_path = LearningPath.find_by(name: "Fresh Path")
    assert new_path.published
    assert_includes @course.reload.learning_paths, new_path
  end

  test "destroy detaches a path" do
    @course.learning_paths << @path
    sign_in(@admin)
    assert_difference "CoursesLearningPath.count", -1 do
      delete course_learning_path_url(@course.slug, @path.id),
        headers: { "Accept" => "application/json" }
    end
    assert_response :success
    assert_not_includes @course.reload.learning_paths, @path
  end

  test "non-manager is forbidden from modifying paths" do
    sign_in(@other)
    assert_raises(CanCan::AccessDenied) do
      post course_learning_paths_url(@course.slug),
        params: { learning_path_id: @path.id }.to_json,
        headers: { "Content-Type" => "application/json", "Accept" => "application/json" }
    end
  end
end
