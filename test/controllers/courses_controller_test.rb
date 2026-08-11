require "test_helper"

class CoursesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @language = languages(:english)
    @user = User.create!(
      email: "course-show-queries@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    @public_channel = @user.default_channel
    @public_channel.update!(visibility: :public)
    User.create!(email: User::ADMIN_EMAIL, password: "password123", confirmed_at: Time.zone.now)
    @course = create_public_course!(
      name: "Query course",
      slug: "query-course",
      main_media_url: "https://www.youtube.com/watch?v=querycourse",
      language: @language,
      user: @user
    )
    publish_system(@course)

    3.times do |index|
      lesson = Lesson.create!(
        course: @course,
        user: @user,
        name: "Lesson #{index}",
        slug: "lesson-#{index}",
        order: index
      )
      lesson.lesson_translations.create!(language: @language, name: "Translated lesson #{index}")
    end
  end

  test "homepage examples do not depend on channel visibility" do
    @course.update!(status: :published)
    Channel.system.unpublish!(@course)
    @public_channel.update!(visibility: :private)

    get root_url

    assert_response :success
    assert_select "#try .lp-card", count: homepage_video_count
    assert_select ".lp-card[href=?]", course_path(@course.slug), count: 0
  end

  test "signed-in owners see the same Try now examples" do
    @course.update!(status: :published)
    Channel.system.unpublish!(@course)
    @public_channel.update!(visibility: :private)
    sign_in @user

    get root_url

    assert_response :success
    assert_select "#try .lp-card", count: homepage_video_count
    assert_select ".lp-card[href=?]", course_path(@course.slug), count: 0
  end

  test "signed-in homepage shows the user menu and highlighted daily vocabulary practice" do
    save_word_for(@language)
    sign_in @user

    get root_url

    assert_response :success
    assert_select "[data-testid='daily-vocab-nav']", text: "Daily Vocab Practice"
    assert_select "[data-controller='profile-menu']", count: 1
    assert_select "a", text: "Profile"
  end

  test "show preloads localized lesson names" do
    queries = capture_selects { get course_url(@course) }

    assert_response :success
    translation_queries = queries.grep(/FROM "lesson_translations"/)
    assert_equal 1, translation_queries.size
    assert_match(/IN \(/, translation_queries.first)
  end

  test "show does not prefetch the full player link" do
    get course_url(@course)

    assert_response :success
    assert_select "a[href=?][data-turbo-prefetch=false]", course_full_player_path(@course)
  end

  test "show truncates long course titles in the hero" do
    @course.update!(name: "A very long provider title that must remain on one line")

    get course_url(@course)

    assert_response :success
    assert_select "h1.truncate[title=?]", @course.name, text: @course.name
  end

  test "homepage shows only configured Try now videos" do
    @course.update!(status: :published)
    9.times do |index|
      course = create_public_course!(
        name: "Homepage course #{index}",
        slug: "homepage-course-#{index}",
        main_media_url: "https://www.youtube.com/watch?v=homepage#{index}",
        language: @language,
        user: @user,
        status: :published
      )
      publish_system(course)
    end

    sign_in @user
    get root_url

    assert_response :success
    assert_select "#try .lp-card", count: homepage_video_count
    configured_paths = HomepageVideos.all.map { |video| try_path(url: video.url) }
    rendered_paths = css_select("#try .lp-card").map { |card| card["href"] }
    assert_empty rendered_paths - configured_paths
  end

  test "homepage exposes its social sharing cover" do
    get root_url

    assert_response :success
    assert_select "meta[property='og:image'][content='https://langlets.app/cover.png']"
    assert_select "meta[property='og:image:width'][content='1731']"
    assert_select "meta[property='og:image:height'][content='909']"
    assert_select "meta[property='og:title']"
    assert_select "meta[property='og:description']"
    assert_select "meta[name='twitter:card'][content='summary_large_image']"
    assert_select "meta[name='twitter:image'][content='https://langlets.app/cover.png']"
    assert_select "meta[name='twitter:title']"
  end

  test "homepage canonical and sharing URLs preserve the Hebrew subdomain" do
    host! "he.langlets.app"

    get root_path

    assert_response :success
    assert_select "link[rel='canonical'][href='https://he.langlets.app/']", minimum: 1
    assert_select "meta[property='og:url'][content='https://he.langlets.app/']"
    assert_select "meta[name='twitter:url'][content='https://he.langlets.app/']"
    assert_select "meta[property='og:image'][content='https://he.langlets.app/cover.png']"
  end

  test "homepage canonical and sharing URLs use the main domain on the main host" do
    host! "langlets.app"

    get root_path

    assert_response :success
    assert_select "meta[property='og:url'][content='https://langlets.app/']"
    assert_select "meta[name='twitter:url'][content='https://langlets.app/']"
  end

  test "homepage canonical URLs reject hosts outside the whitelist" do
    host! "unrecognized.langlets.app"

    get root_path

    assert_response :success
    assert_select "meta[property='og:url'][content='https://langlets.app/']"
    assert_select "meta[name='twitter:url'][content='https://langlets.app/']"
    assert_select "meta[property='og:image'][content='https://langlets.app/cover.png']"
  end

  test "homepage presents the product image before Try now and the creation explainer" do
    get root_url

    assert_response :success
    assert_select "header.lp-hero img.lp-product-img[src='/product.png']", count: 1
    assert_includes response.body, ".lp-hero .lp-lead { display:none; }"
    assert_select "header.lp-hero form", count: 0
    assert_select "#create h2", text: "Create Your Own"
    assert_select "#create", text: /full transcript, translation and vocabulary exercises/
    assert_select "#try form[action=?][method=get] input[name=url]", try_path
    assert_select "#create a[href='#try']", text: "Try now"

    body = response.body
    assert_operator body.index('id="try"'), :<, body.index('id="create"')
  end

  test "homepage Try now examples are unchanged when a language is selected" do
    french_course = create_public_course!(
      name: "French homepage course",
      slug: "french-homepage-course",
      main_media_url: "https://www.youtube.com/watch?v=frenchhome",
      language: languages(:french),
      user: @user,
      status: :published
    )
    publish_system(french_course)

    8.times do |index|
      course = create_public_course!(
        name: "Newer English course #{index}",
        slug: "newer-english-course-#{index}",
        main_media_url: "https://www.youtube.com/watch?v=newer#{index}",
        language: @language,
        user: @user,
        status: :published
      )
      publish_system(course)
    end

    french_course.touch(time: 1.day.ago)
    get root_url(lang: "fr")

    assert_response :success
    assert_select "#try .lp-card", count: homepage_video_count
    assert_select ".lp-card[href='#{course_path(french_course.slug)}']", count: 0
  end

  test "homepage tolerates an unsupported language while showing Try now" do
    @course.update!(status: :published)

    get root_url(lang: "xx")

    assert_response :success
    assert_select "#try .lp-card", count: homepage_video_count
  end

  test "homepage examples are sampled from YAML rather than course creation order" do
    @course.update!(status: :published, created_at: 2.days.ago)
    playlist_course = create_public_course!(
      name: "Newest playlist course",
      slug: "newest-playlist-course",
      main_media_url: "https://www.youtube.com/watch?v=playlistnewest",
      language: @language,
      user: @user,
      status: :published,
      created_at: 1.hour.ago
    )
    publish_system(playlist_course)
    playlist = Playlist.create!(name: "Homepage playlist", published: true)
    playlist.courses << playlist_course

    get root_url

    assert_response :success
    cards = css_select("#try .lp-card")
    configured_paths = HomepageVideos.all.map { |video| try_path(url: video.url) }
    assert_equal homepage_video_count, cards.size
    assert_empty cards.map { |card| card["href"] } - configured_paths
    refute_includes cards.map { |card| card["href"] }, course_path(playlist_course.slug)
  end

  test "a public-only course is link-readable but unlisted on the homepage" do
    Channel.system.unpublish!(@course)

    get course_url(@course)
    assert_response :success

    get root_url
    assert_response :success
    assert_select ".lp-card[href=?]", course_path(@course.slug), count: 0
  end

  test "the homepage sells nothing and points guests at sign in" do
    get root_url

    assert_response :success
    assert_select "#pricing", count: 0
    assert_select "a[href='#pricing']", count: 0
    assert_select "a[href=?]", new_user_registration_path(returnto: "/"), count: 0
    assert_select "form[action*=?]", "paypal.com", count: 0
    assert_select ".lp-nav a[href=?]", new_user_session_path, text: "Sign in"
  end

  test "the homepage sells nothing to signed-in users either" do
    sign_in @user

    get root_url

    assert_response :success
    assert_select "#pricing", count: 0
    assert_select "form[action*=?]", "paypal.com", count: 0
  end

  private

  def homepage_video_count
    [ HomepageVideos.all.size, HomepageVideos::PAGE_LIMIT ].min
  end

  def save_word_for(language)
    translation_language = languages(:spanish)
    medium = Medium.create!(url: "https://example.com/vocab-#{SecureRandom.hex(4)}", language: language)
    phrase = create_translated_phrase!(
      medium: medium, l1: language, l2: translation_language,
      text_l1: "Hello", text_l2: "Hola", timestamp: "00:00:01"
    )
    token = create_translated_token!(
      phrase: phrase, l1_start_index: 0, l1_end_index: 4,
      index_type: :character_index, translation: "Hola"
    )
    @user.phrase_token_users.create!(phrase_token: token, language: translation_language)
  end

  def create_public_course!(**attributes)
    course = Course.create!(**attributes)
    publish_covering_the_credit(@public_channel, course)
    course
  end

  def capture_selects
    queries = []
    callback = lambda do |_name, _start, _finish, _id, payload|
      next if payload[:name] == "SCHEMA" || payload[:cached]

      queries << payload[:sql].squish if payload[:sql].to_s.lstrip.start_with?("SELECT")
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries
  end
end
