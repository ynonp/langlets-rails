require "test_helper"

class PlayControllerTest < ActionDispatch::IntegrationTest
  # Skip fixture loading for this test class
  self.use_transactional_tests = true
  
  # Clear fixtures for this test class
  def self.fixture_table_names
    []
  end

  setup do
    # Create languages directly
    @english = Language.find_or_create_by!(iso_name: "en") do |l|
      l.english_name = "English"
      l.native_name = "English"
      l.rtl = false
    end
    @spanish = Language.find_or_create_by!(iso_name: "es") do |l|
      l.english_name = "Spanish"
      l.native_name = "Español"
      l.rtl = false
    end

    @user = User.create!(email: "play_test_#{SecureRandom.hex(4)}@example.com", password: "password123")
    @medium = Medium.create!(url: "https://www.youtube.com/watch?v=testid#{SecureRandom.hex(4)}", language: @english)
    
    @course = Course.create!(
      name: "Test Song #{SecureRandom.hex(4)}",
      slug: "test-song-#{SecureRandom.hex(4)}",
      main_media_url: @medium.url,
      user: @user
    )
    
    @lesson = Lesson.create!(
      slug: "#{@course.slug}-0",
      medium: @medium,
      course: @course,
      order: 0,
      name: "Test Lesson",
      user: @user
    )
    
    @phrase = Phrase.create!(
      text_l1: "Hello world",
      text_l2: "Hola mundo",
      timestamp: "00:01:30",
      medium: @medium,
      l1: @english,
      l2: @spanish
    )
    
    @token = TokenTranslation.create!(
      phrase: @phrase,
      l1_start_index: 0,
      l1_end_index: 0,
      l2_start_index: 0,
      l2_end_index: 0,
      translation: "Hola"
    )
  end

  test "should get show with valid course slug" do
    get play_path(slug: @course.slug)
    assert_response :success
    assert_select "h1", text: @course.name
  end

  test "should redirect to root when course not found" do
    get play_path(slug: "non-existent-course")
    assert_redirected_to root_path
  end

  test "should display lyrics tab content" do
    get play_path(slug: @course.slug)
    assert_response :success
    # Check that lyrics content is present
    assert_select "[data-standalone-player-target='lyricsContent']"
    # Check that L1 text appears (may be split into spans)
    assert_match "Hello", response.body
    # Check that L2 translation appears
    assert_match @phrase.text_l2, response.body
  end

  test "should display vocabulary tab content" do
    get play_path(slug: @course.slug)
    assert_response :success
    # Check that vocabulary content is present
    assert_select "[data-standalone-player-target='vocabularyContent']"
    # Check that vocabulary table exists
    assert_select "table"
    # Check for Download CSV link
    assert_select "a[href*='vocabulary.csv']"
  end

  test "should download vocabulary CSV" do
    get play_vocabulary_csv_path(slug: @course.slug)
    assert_response :success
    assert_equal "text/csv", response.content_type.split(";").first
    assert_match "Word,Translation", response.body
    assert_match @token.original_text, response.body
    assert_match @token.translation, response.body
  end

  test "should return 404 for CSV when course not found" do
    get play_vocabulary_csv_path(slug: "non-existent-course")
    assert_response :not_found
  end

  test "should display video player" do
    get play_path(slug: @course.slug)
    assert_response :success
    assert_select "iframe[src*='youtube.com/embed']"
  end

  test "should have tabs for lyrics and vocabulary" do
    get play_path(slug: @course.slug)
    assert_response :success
    assert_select "[data-standalone-player-target='lyricsTab']"
    assert_select "[data-standalone-player-target='vocabularyTab']"
  end

  test "should include back to course link" do
    get play_path(slug: @course.slug)
    assert_response :success
    assert_select "a[href='#{course_path(@course.slug)}']"
  end
end
