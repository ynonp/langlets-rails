require "test_helper"

class PlayControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Create a user
    @user = User.create!(email: "test#{SecureRandom.hex(4)}@example.com", password: "password123", confirmed_at: Time.zone.now)
    
    # Create a medium with a unique YouTube URL
    @test_video_id = "test_#{SecureRandom.hex(4)}"
    @medium = Medium.create!(url: "https://www.youtube.com/watch?v=#{@test_video_id}", language: languages(:spanish))
    
    # Create a course
    @course = Course.create!(
      name: "Test Course #{SecureRandom.hex(4)}",
      slug: "test-course-#{SecureRandom.hex(4)}",
      main_media_url: "https://www.youtube.com/watch?v=#{@test_video_id}",
      user: @user,
      language: languages(:spanish),
      status: :published
    )
    
    # Create a lesson
    @lesson = Lesson.create!(
      slug: "test-lesson-#{SecureRandom.hex(4)}",
      medium: @medium,
      course: @course,
      user: @user,
      name: "Test Lesson"
    )
    
    # Create a phrase
    @phrase = Phrase.create!(
      text_l1: "Hola mundo",
      text_l2: "Hello world",
      timestamp: "00:01",
      medium: @medium,
      l1: languages(:spanish),
      l2: languages(:english)
    )
    
    # Create a token translation
    @token = TokenTranslation.create!(
      phrase: @phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      l2_start_index: 0,
      l2_end_index: 0,
      translation: "Hello"
    )
  end

  test "should show standalone player for valid course slug" do
    get play_path(slug: @course.slug)
    assert_response :success
    assert_select "h1", @course.name
  end

  test "should redirect to root for invalid course slug" do
    get play_path(slug: "nonexistent-course")
    assert_redirected_to root_path
    assert_equal "Course not found", flash[:alert]
  end

  test "should display lyrics tab by default" do
    get play_path(slug: @course.slug)
    assert_response :success
    # Check for phrases in the view
    assert_match "Hola", response.body
  end

  test "should display vocabulary data" do
    get play_path(slug: @course.slug)
    assert_response :success
    # Check for vocabulary content
    assert_match "Hello", response.body
  end

  test "should download vocabulary CSV" do
    get play_vocabulary_csv_path(slug: @course.slug)
    assert_response :success
    assert_equal "text/csv", response.content_type
    
    # Check CSV content
    csv_content = response.body
    assert_match "Word,Translation", csv_content
    assert_match "Hola,Hello", csv_content
  end

  test "should return 404 for vocabulary CSV of nonexistent course" do
    get play_vocabulary_csv_path(slug: "nonexistent-course")
    assert_response :not_found
  end
end
