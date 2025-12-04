require "test_helper"

class PlayersControllerTest < ActionDispatch::IntegrationTest
  fixtures :languages

  setup do
    # Create user first
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )

    # Create language
    @spanish = languages(:spanish)
    @english = languages(:english)

    # Create medium with unique URL
    @medium = Medium.create!(
      url: "https://www.youtube.com/watch?v=test123abc",
      language: @spanish
    )

    # Create course
    @course = Course.create!(
      name: "Test Course",
      slug: "test-course",
      main_media_url: @medium.url,
      user: @user,
      status: :published
    )

    # Create lesson
    @lesson = Lesson.create!(
      slug: "test-course0",
      medium: @medium,
      course: @course,
      user: @user
    )

    # Create phrases with token translations
    # "Hola mundo" - Hola=Hello (word index 0), mundo=world (word index 1)
    @phrase1 = Phrase.create!(
      text_l1: "Hola mundo",
      text_l2: "Hello world",
      timestamp: "00:01",
      medium: @medium,
      l1: @spanish,
      l2: @english
    )

    # "Hola" is the first word (index 0), translates to "Hello" (index 0)
    TokenTranslation.create!(
      phrase: @phrase1,
      l1_start_index: 0,
      l1_end_index: 0,
      l2_start_index: 0,
      l2_end_index: 0,
      translation: "Hello"
    )

    # "Buenos días" - Buenos=Good (word index 0), días=morning (word index 1)
    @phrase2 = Phrase.create!(
      text_l1: "Buenos días",
      text_l2: "Good morning",
      timestamp: "00:05",
      medium: @medium,
      l1: @spanish,
      l2: @english
    )

    # "Buenos" is the first word (index 0), translates to "Good" (index 0)
    TokenTranslation.create!(
      phrase: @phrase2,
      l1_start_index: 0,
      l1_end_index: 0,
      l2_start_index: 0,
      l2_end_index: 0,
      translation: "Good"
    )

    # "días" is the second word (index 1), translates to "morning" (index 1)
    TokenTranslation.create!(
      phrase: @phrase2,
      l1_start_index: 1,
      l1_end_index: 1,
      l2_start_index: 1,
      l2_end_index: 1,
      translation: "morning"
    )
  end

  test "should show player page for existing course" do
    get play_path(@course.slug)
    assert_response :success
    assert_select "h1", text: @course.name
  end

  test "should redirect to root for non-existent course" do
    get play_path("non-existent-course")
    assert_redirected_to root_path
  end

  test "should display phrases in lyrics tab" do
    get play_path(@course.slug)
    assert_response :success
    # Check for phrase content (may be split by HTML tags)
    assert_match "Hola", @response.body
    assert_match "mundo", @response.body
    assert_match "Hello world", @response.body
    assert_match "Buenos", @response.body
    assert_match "días", @response.body
  end

  test "should have vocabulary tab content" do
    get play_path(@course.slug)
    assert_response :success
    assert_match "Vocabulary", @response.body
    assert_match "Download CSV", @response.body
  end

  test "should download vocabulary as CSV" do
    get play_vocabulary_csv_path(@course.slug)
    assert_response :success
    assert_equal "text/csv", @response.content_type.split(";").first

    csv_content = @response.body
    assert_includes csv_content, "Word,Definition"
    assert_includes csv_content, "Hola,Hello"
    assert_includes csv_content, "Buenos,Good"
    assert_includes csv_content, "días,morning"
  end

  test "vocabulary csv should have correct filename" do
    get play_vocabulary_csv_path(@course.slug)
    assert_response :success

    content_disposition = @response.headers["Content-Disposition"]
    assert_includes content_disposition, "test-course-vocabulary.csv"
  end

  test "should return 404 for vocabulary csv of non-existent course" do
    get play_vocabulary_csv_path("non-existent-course")
    assert_response :not_found
  end
end
