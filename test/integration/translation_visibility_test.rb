require "test_helper"

# Courses (and the playlists holding them) only show on a subdomain whose
# language they have a ready translation for. Courses that predate translations
# (no course_translations rows) show everywhere.
class TranslationVisibilityTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      email: "someone@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    @hebrew_only_course = Course.create!(
      user: @user,
      name: "Hebrew Only Course",
      slug: "hebrew-only-#{SecureRandom.hex(4)}",
      main_media_url: "https://www.youtube.com/watch?v=abc123",
      status: :published
    )
    @hebrew_only_course.course_translations.create!(
      language: languages(:hebrew),
      name: @hebrew_only_course.name,
      status: :ready
    )
    @untranslated_course = Course.create!(
      user: @user,
      name: "Untranslated Course",
      slug: "untranslated-#{SecureRandom.hex(4)}",
      main_media_url: "https://www.youtube.com/watch?v=def456",
      status: :published
    )
    @hebrew_playlist = Playlist.create!(name: "Hebrew Playlist", published: true, slug: "hebrew-#{SecureRandom.hex(4)}")
    @hebrew_playlist.courses << @hebrew_only_course
    @mixed_playlist = Playlist.create!(name: "Mixed Playlist", published: true, slug: "mixed-#{SecureRandom.hex(4)}")
    @mixed_playlist.courses << @hebrew_only_course
    @mixed_playlist.courses << @untranslated_course
  end

  teardown { Current.reset }

  test "the index hides playlists with no course translated to the subdomain language" do
    get root_path
    assert_response :success
    assert_select "[data-testid='tabs-panel-courses']", text: /Hebrew Playlist/, count: 0
    assert_select "[data-testid='tabs-panel-courses']", text: /Mixed Playlist/
    # Only the untranslated course counts toward the mixed playlist's clips.
    assert_select "[data-testid='tabs-panel-courses']", text: /1 clip/
  end

  test "the index shows Hebrew-translated content on the Hebrew subdomain" do
    host! "he.example.com"
    get root_path
    assert_response :success
    assert_select "[data-testid='tabs-panel-courses']", text: /Hebrew Playlist/
    assert_select "[data-testid='tabs-panel-courses']", text: /Mixed Playlist/
  end

  test "a playlist page only lists courses translated to the subdomain language" do
    get playlist_path(@mixed_playlist)
    assert_response :success
    assert_match "Untranslated Course", response.body
    assert_no_match "Hebrew Only Course", response.body

    host! "he.example.com"
    get playlist_path(@mixed_playlist)
    assert_response :success
    assert_match "Hebrew Only Course", response.body
  end
end
