require "test_helper"

# Review Words actions live in the shared user menu rendered across authenticated
# web navigation, course, and playlist surfaces. These tests use a playlist as a
# compact host for exercising the shared partial's language behavior.
class ReviewWordsMenuTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )

    @english = languages(:english)
    @spanish = languages(:spanish)
    @hebrew = languages(:hebrew)
    @arabic = languages(:arabic)

    # A system playlist (no owner) renders the shared user menu for signed-in
    # users and is viewable by guests, so it stands in for the old root page.
    @menu_playlist = Playlist.create!(
      name: "Menu Test Playlist",
      slug: "menu-#{SecureRandom.hex(4)}",
      published: true
    )

    @medium = Medium.create!(
      url: "https://www.youtube.com/watch?v=test123",
      language: @english
    )

    @phrase_en = create_translated_phrase!(
      medium: @medium,
      l1: @english,
      l2: @spanish,
      text_l1: "Hello world",
      text_l2: "Hola mundo",
      timestamp: "00:01:30"
    )

    @phrase_ar = create_translated_phrase!(
      medium: @medium,
      l1: @arabic,
      l2: @english,
      text_l1: "مرحبا بالعالم",
      text_l2: "Hello world",
      timestamp: "00:02:00"
    )

    @phrase_he = create_translated_phrase!(
      medium: @medium,
      l1: @hebrew,
      l2: @english,
      text_l1: "שלום עולם",
      text_l2: "Hello world",
      timestamp: "00:03:00"
    )

    @token_en = create_translated_token!(
      phrase: @phrase_en,
      l1_start_index: 0,
      l1_end_index: 4,
      index_type: :character_index,
      translation: "Hola"
    )

    @token_ar1 = create_translated_token!(
      phrase: @phrase_ar,
      l1_start_index: 0,
      l1_end_index: 4,
      index_type: :character_index,
      translation: "Hi"
    )

    @token_ar2 = create_translated_token!(
      phrase: @phrase_ar,
      l1_start_index: 6,
      l1_end_index: 10,
      index_type: :character_index,
      translation: "World"
    )

    @token_he = create_translated_token!(
      phrase: @phrase_he,
      l1_start_index: 0,
      l1_end_index: 4,
      index_type: :character_index,
      translation: "Hi"
    )
  end

  test "menu shows no review words when user has no saved tokens" do
    sign_in(@user)

    get playlist_path(@menu_playlist)
    assert_response :success

    assert_select "a.btn", text: /Review Words/, count: 0
  end

  test "menu always links to Create even when the user has no credits" do
    sign_in(@user)

    get playlist_path(@menu_playlist)
    assert_select "a[href=?]", new_app_import_request_path, text: "Create", count: 1

    User.where(id: @user.id).update_all(credit_balance: 0)
    get playlist_path(@menu_playlist)
    assert_select "a[href=?]", new_app_import_request_path, text: "Create", count: 1
  end

  test "menu shows single language when user has tokens from one language" do
    @user.saved_phrase_tokens << @token_en

    sign_in(@user)
    get playlist_path(@menu_playlist)
    assert_response :success

    assert_select "a", text: /Review Words/, count: 1
    assert_select "a", text: "📚 Review Words (#{@english.iso_name})"
  end

  test "menu shows multiple languages when user has tokens from multiple languages" do
    @user.saved_phrase_tokens << @token_en
    @user.saved_phrase_tokens << @token_ar1
    @user.saved_phrase_tokens << @token_he

    sign_in(@user)
    get playlist_path(@menu_playlist)
    assert_response :success

    assert_select "a", text: /Review Words/, count: 3

    assert_select "a", text: "📚 Review Words (#{@arabic.iso_name})"
    assert_select "a", text: "📚 Review Words (#{@english.iso_name})"
    assert_select "a", text: "📚 Review Words (#{@hebrew.iso_name})"
  end

  test "menu shows language buttons alphabetically ordered by iso_name" do
    @user.saved_phrase_tokens << @token_en
    @user.saved_phrase_tokens << @token_ar1
    @user.saved_phrase_tokens << @token_he

    sign_in(@user)
    get playlist_path(@menu_playlist)
    assert_response :success

    body = response.body

    ar_pos = body.index("Review Words (#{@arabic.iso_name})")
    en_pos = body.index("Review Words (#{@english.iso_name})")
    he_pos = body.index("Review Words (#{@hebrew.iso_name})")

    assert ar_pos < en_pos, "Arabic should appear before English"
    assert en_pos < he_pos, "English should appear before Hebrew"
  end

  test "menu groups tokens by L1 language" do
    @user.saved_phrase_tokens << @token_ar1
    @user.saved_phrase_tokens << @token_ar2

    sign_in(@user)
    get playlist_path(@menu_playlist)
    assert_response :success

    assert_select "a", text: /Review Words/, count: 1

    assert_select "a", text: "📚 Review Words (#{@arabic.iso_name})"
    assert_select "a", text: "Review Words (#{@hebrew.iso_name})", count: 0
  end

  test "courses show page shows language-specific review buttons" do
    course = publish_privately(Course.create!(
      name: "Test Course",
      slug: "test-course-#{Time.zone.now.to_i}",
      main_media_url: "https://www.youtube.com/watch?v=test123",
      user: @user
    ))

    @user.saved_phrase_tokens << @token_en
    @user.saved_phrase_tokens << @token_ar1

    sign_in(@user)
    get course_path(course)
    assert_response :success

    assert_select "a", text: "📚 Review Words (#{@english.iso_name})"
    assert_select "a", text: "📚 Review Words (#{@arabic.iso_name})"
    assert_web_profile_menu
  end

  test "playlist show page shows language-specific review buttons" do
    playlist = Playlist.create!(
      name: "Test Path",
      slug: "test-path-#{Time.zone.now.to_i}",
      published: true
    )

    @user.saved_phrase_tokens << @token_he

    sign_in(@user)
    get playlist_path(playlist)
    assert_response :success

    assert_select "a", text: "📚 Review Words (#{@hebrew.iso_name})"
    assert_web_profile_menu
  end

  test "playlist header keeps theme and xp controls in mobile profile menu" do
    playlist = Playlist.create!(
      name: "Mobile Header Test Path",
      slug: "mobile-header-test-path-#{Time.zone.now.to_i}",
      published: true
    )

    sign_in(@user)
    get playlist_path(playlist)
    assert_response :success

    assert_select "[data-testid='header-theme-desktop']", count: 1
    assert_select "[data-testid='header-xp-desktop']", count: 1
    assert_select "[data-testid='header-theme-mobile-menu']", count: 1
    assert_select "[data-testid='header-xp-mobile-menu']", count: 1
  end

  test "menu doesn't show for unauthenticated users" do
    @user.saved_phrase_tokens << @token_en

    get playlist_path(@menu_playlist)
    assert_response :success

    assert_select "a", text: /Review Words/, count: 0
  end

  private

  def assert_web_profile_menu
    assert_select "[data-controller='profile-menu'][data-action='click@document->profile-menu#close']" do
      assert_select "input[data-profile-menu-target='toggle']", count: 1
      assert_select "a[href=?][data-action='click->profile-menu#dismiss']", profile_path, count: 1
    end
  end

  def sign_in(user)
    post user_session_url, params: {
      user: {
        email: user.email,
        password: "password123"
      }
    }
  end
end
