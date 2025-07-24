require "test_helper"

class CourseTest < ActiveSupport::TestCase
  def setup
    # Create scripts
    @latin_script = Script.find_or_create_by!(name: 'latin') do |s|
      s.iso_code = 'Latn'
      s.rtl = false
    end
    
    # Create test user
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
      confirmed_at: Time.current
    )
    
    # Create test languages
    @spanish = Language.find_or_create_by!(iso_name: "es") do |l|
      l.english_name = "Spanish"
      l.native_name = "Español"
      l.default_script = @latin_script
    end
    
    @english = Language.find_or_create_by!(iso_name: "en") do |l|
      l.english_name = "English"
      l.native_name = "English"
      l.default_script = @latin_script
    end
    
    # Load test data from fixtures
    @juanes_data = JSON.parse(File.read(Rails.root.join("test", "fixtures", "courses", "juanes.json")))
    @minimal_data = JSON.parse(File.read(Rails.root.join("test", "fixtures", "courses", "minimal_data.json")))
  end
  
  def teardown
    # Clean up test data
    @user&.destroy
  end

  test "create_song! works with hash data" do
    course = Course.create!(
      name: "Test Song Course",
      slug: "test-song-course",
      main_media_url: @minimal_data["youtubeurl"],
      language: @english,
      user: @user,
      status: :processing
    )

    assert_nothing_raised do
      course.create_song!(@minimal_data)
    end

    # Verify course content was created
    course.reload
    assert_equal 2, course.lessons.count # 1 lesson + 1 review lesson
    
    lesson = course.lessons.first
    assert_equal "Test Lesson", lesson.name
    assert_equal 7, lesson.activities.count # Watch, Match/Word, Tokens, Sort, Alignment, Speak, Listen
    
    # Verify phrases were created
    watch_activity = lesson.activities.find_by(type: "Activities::WatchVideoActivity")
    assert_equal 1, watch_activity.phrases.count
    phrase = watch_activity.phrases.first
    assert_equal "Hola mundo", phrase.text_l1
    assert_equal "Hello world", phrase.text_l2
    
    # Verify token translations were created
    assert_equal 2, phrase.token_translations.count
  end

  test "create_short! works with hash data" do
    course = Course.create!(
      name: "Test Short Course",
      slug: "test-short-course",
      main_media_url: @minimal_data["youtubeurl"],
      language: @english,
      user: @user,
      status: :processing
    )

    assert_nothing_raised do
      course.create_short!(@minimal_data)
    end

    # Verify course content was created
    course.reload
    assert_equal 2, course.lessons.count # 1 lesson + 1 review lesson
    
    lesson = course.lessons.first
    assert_equal "Test Lesson", lesson.name
    assert_equal 5, lesson.activities.count # Watch, Match, Word Order, Alignment, Tokens
    
    # Verify phrases were created
    watch_activity = lesson.activities.find_by(type: "Activities::WatchVideoActivity")
    assert_equal 1, watch_activity.phrases.count
    phrase = watch_activity.phrases.first
    assert_equal "Hola mundo", phrase.text_l1
    assert_equal "Hello world", phrase.text_l2
  end

  test "create_song! works with full juanes data" do
    course = Course.create!(
      name: "Juanes Course",
      slug: "juanes-course",
      main_media_url: @juanes_data["youtubeurl"],
      language: @english,
      user: @user,
      status: :processing
    )

    assert_nothing_raised do
      course.create_song!(@juanes_data)
    end

    # Verify course content was created from the full dataset
    course.reload
    expected_lessons = @juanes_data["lessons"].count + 1 # lessons + review lesson
    assert_equal expected_lessons, course.lessons.count
    
    # Verify first lesson
    first_lesson = course.lessons.first
    assert_equal @juanes_data["lessons"].first["title"], first_lesson.name
    
    # Verify phrases from first lesson
    first_lesson_watch_activity = first_lesson.activities.find_by(type: "Activities::WatchVideoActivity")
    expected_phrases = @juanes_data["lessons"].first["phrases"].count
    assert_equal expected_phrases, first_lesson_watch_activity.phrases.count
  end

  test "create_song! raises error with missing required fields" do
    course = Course.create!(
      name: "Test Course",
      slug: "test-course",
      main_media_url: "https://example.com",
      language: @english,
      user: @user,
      status: :processing
    )

    # Test missing lessons
    assert_raises(RuntimeError, "Missing creation data") do
      course.create_song!({})
    end

    # Test missing youtubeurl
    assert_raises(RuntimeError, "Missing YouTube URL") do
      course.create_song!({"lessons" => []})
    end

    # Test missing clip_language
    assert_raises(RuntimeError, "Missing clip language") do
      course.create_song!({"lessons" => [], "youtubeurl" => "https://example.com"})
    end

    # Test missing translation_language
    assert_raises(RuntimeError, "Missing translation language") do
      course.create_song!({
        "lessons" => [],
        "youtubeurl" => "https://example.com",
        "clip_language" => "Spanish"
      })
    end
  end

  test "create_short! raises error with missing required fields" do
    course = Course.create!(
      name: "Test Course",
      slug: "test-course",
      main_media_url: "https://example.com",
      language: @english,
      user: @user,
      status: :processing
    )

    # Test missing lessons
    assert_raises(RuntimeError, "Missing creation data") do
      course.create_short!({})
    end

    # Test missing youtubeurl
    assert_raises(RuntimeError, "Missing YouTube URL") do
      course.create_short!({"lessons" => []})
    end
  end

  test "create_song! handles token translations with activity flags" do
    course = Course.create!(
      name: "Test Activity Course",
      slug: "test-activity-course",
      main_media_url: @minimal_data["youtubeurl"],
      language: @english,
      user: @user,
      status: :processing
    )

    course.create_song!(@minimal_data)
    course.reload

    lesson = course.lessons.first
    alignment_activity = lesson.activities.find_by(type: "Activities::LanguageAlignmentActivity")
    listen_activity = lesson.activities.find_by(type: "Activities::ListenActivity")

    # Check that token translations were assigned to correct activities
    assert alignment_activity.token_translations.count > 0
    assert listen_activity.token_translations.count > 0
  end

  test "create_song! creates proper lesson structure" do
    course = Course.create!(
      name: "Structure Test Course",
      slug: "structure-test-course",
      main_media_url: @minimal_data["youtubeurl"],
      language: @english,
      user: @user,
      status: :processing
    )

    course.create_song!(@minimal_data)
    course.reload

    lesson = course.lessons.first
    
    # Verify all expected activities are created
    expected_activity_types = [
      "Activities::WatchVideoActivity",
      "Activities::MatchTokensActivity",
      "Activities::SortPhrasesActivity", 
      "Activities::LanguageAlignmentActivity",
      "Activities::SpeakActivity",
      "Activities::ListenActivity"
    ]
    
    actual_activity_types = lesson.activities.pluck(:type)
    expected_activity_types.each do |activity_type|
      assert_includes actual_activity_types, activity_type, "Missing activity: #{activity_type}"
    end
    
    # Verify either MatchPhrasesActivity or WordOrderActivity is created (random choice)
    match_or_word_activities = lesson.activities.where(
      type: ["Activities::MatchPhrasesActivity", "Activities::WordOrderActivity"]
    )
    assert_equal 1, match_or_word_activities.count
  end

  test "create_song! cleans up existing lessons before creating new ones" do
    course = Course.create!(
      name: "Cleanup Test Course",
      slug: "cleanup-test-course",
      main_media_url: @minimal_data["youtubeurl"],
      language: @english,
      user: @user,
      status: :processing
    )

    # Create some initial lessons
    course.create_song!(@minimal_data)
    initial_lesson_count = course.lessons.count

    # Create again with same data - should replace, not add
    course.create_song!(@minimal_data)
    course.reload
    
    assert_equal initial_lesson_count, course.lessons.count
  end
end
