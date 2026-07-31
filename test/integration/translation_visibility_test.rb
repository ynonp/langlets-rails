require "test_helper"

# Courses only show on a subdomain whose language they have a ready translation
# for. Courses that predate translations (no course_translations rows) show
# everywhere. This gate applies both to the homepage "Jump right in" grid and
# to the course list on a playlist page.
class TranslationVisibilityTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      email: "someone@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )

    # Both standalone and playlist courses can appear in the homepage grid.
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

    # A playlist applies the same per-language gate to its own course list. Its
    # courses are distinct from the standalone pair.
    @playlist_hebrew_course = Course.create!(
      user: @user,
      name: "Playlist Hebrew Course",
      slug: "pl-hebrew-#{SecureRandom.hex(4)}",
      main_media_url: "https://www.youtube.com/watch?v=ghi789",
      status: :published
    )
    @playlist_hebrew_course.course_translations.create!(
      language: languages(:hebrew),
      name: @playlist_hebrew_course.name,
      status: :ready
    )
    @playlist_untranslated_course = Course.create!(
      user: @user,
      name: "Playlist Untranslated Course",
      slug: "pl-untranslated-#{SecureRandom.hex(4)}",
      main_media_url: "https://www.youtube.com/watch?v=jkl012",
      status: :published
    )
    # Both surfaces under test are viewed signed-out, and readability is
    # Channel-based, so every course here needs a public Channel. The gate
    # being tested is the translation one, not access.
    [ @hebrew_only_course, @untranslated_course,
      @playlist_hebrew_course, @playlist_untranslated_course ].each { |course| publish_publicly(course) }

    @mixed_playlist = Playlist.create!(name: "Mixed Playlist", published: true, slug: "mixed-#{SecureRandom.hex(4)}")
    @mixed_playlist.courses << @playlist_hebrew_course
    @mixed_playlist.courses << @playlist_untranslated_course
  end

  teardown { Current.reset }

  test "the homepage grid hides courses not translated to the subdomain language" do
    get root_path
    assert_response :success
    assert_select ".lp-card-title", text: /Untranslated Course/
    assert_select ".lp-card-title", text: /Hebrew Only Course/, count: 0
  end

  test "the homepage grid shows Hebrew-translated content on the Hebrew subdomain" do
    host! "he.example.com"
    get root_path
    assert_response :success
    assert_select ".lp-card-title", text: /Hebrew Only Course/
  end

  test "a playlist page only lists courses translated to the subdomain language" do
    get playlist_path(@mixed_playlist)
    assert_response :success
    assert_match "Playlist Untranslated Course", response.body
    assert_no_match "Playlist Hebrew Course", response.body

    host! "he.example.com"
    get playlist_path(@mixed_playlist)
    assert_response :success
    assert_match "Playlist Hebrew Course", response.body
  end
end
