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
    assert_select "body[data-layout='primary-web']"
    assert_select "nav[data-testid='primary-web-header'][class*='flex-nowrap']", count: 1
    assert_select "[data-testid='primary-web-actions'][class*='flex-nowrap']", count: 1
    # Library, Vocabulary, Create.
    assert_select "[data-testid='primary-web-desktop-link'][class*='hidden'][class*='lg:inline-flex']", count: 3
    assert_select "[data-testid='daily-vocab-nav']", text: "Daily Vocab Practice"
    assert_select "[data-controller='profile-menu']", count: 1
    assert_select "a", text: "Profile"
  end

  test "homepage hero offers Android and iPhone app downloads" do
    assert_equal "application/vnd.android.package-archive", Rack::Mime.mime_type(".apk")

    get root_url

    assert_response :success
    assert_select "header.lp-hero" do
      assert_select "a.lp-android-download[data-testid='android-app-download'][href=?][download=?][aria-label=?]",
        Rails.configuration.x.mobile_apps.android_download_path,
        File.basename(Rails.configuration.x.mobile_apps.android_download_path),
        "Download the Langlets Android APK" do
        assert_select ".lp-android-kicker", text: "Download the"
        assert_select ".lp-android-name", text: "Android app"
      end
      assert_select ".lp-app-downloads" do
        assert_select "a.lp-iphone-download[data-testid='iphone-app-download'][href=?][aria-label=?]",
          Rails.configuration.x.mobile_apps.iphone_download_url,
          "Download the Langlets iPhone app with TestFlight" do
          assert_select ".lp-app-download-kicker", text: "Download the"
          assert_select ".lp-app-download-name", text: "iPhone app"
        end
      end
    end
    assert_select "[data-testid='mobile-app-subheader']", count: 0
    assert_select "[data-testid='iphone-app-placeholder']", count: 0
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

  test "a different language subdomain offers a missing course translation" do
    @course.update!(status: :published)
    host! "he.langlets.app"

    get course_path(@course)

    assert_response :success
    assert_select "[data-testid=course-translation-banner][class*='from-emerald'][class*='to-cyan']",
      text: /\u05d4\u05e7\u05d5\u05e8\u05e1 \u05d4\u05d6\u05d4 \u05e0\u05d5\u05e6\u05e8 \u05d1\u05d0\u05e0\u05d2\u05dc\u05d9\u05ea.*\u05e9\u05e4\u05ea \u05d4\u05de\u05de\u05e9\u05e7.*\u05e2\u05d1\u05e8\u05d9\u05ea.*\u05e8\u05d5\u05e6\u05d9\u05dd \u05d0\u05d5\u05ea\u05d5 \u05d2\u05dd \u05d1\u05e2\u05d1\u05e8\u05d9\u05ea/m
    assert_select "[data-testid=course-translation-banner][class*='amber']", count: 0
    assert_select "a[href*=?]", new_user_session_path, text: "כן — התחברו כדי להמשיך"
  end

  test "requesting a missing translation neither republishes nor spends a credit" do
    @course.update!(status: :published)
    sign_in @user
    host! "he.langlets.app"
    channel_items = ChannelItem.where(course: @course).count
    credits = @user.credit_balance

    get course_path(@course)
    assert_select "form[action=?] button", translate_course_path(@course), text: "כן, תרגמו אותו!"

    assert_enqueued_with(job: AddCourseTranslationJob) do
      post translate_course_path(@course)
    end

    assert_redirected_to course_path(@course)
    assert @course.reload.published?
    assert_equal channel_items, ChannelItem.where(course: @course).count
    assert_equal credits, @user.reload.credit_balance
    assert @course.course_translations.find_by!(language: languages(:hebrew)).pending?
    assert_empty @user.import_requests.where(course: @course, translation_language: "Hebrew")
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
    configured_urls = HomepageVideos.all.map(&:url)
    rendered_urls = css_select("#try .lp-card").map { |card| card["data-video-url"] }
    assert_empty rendered_urls - configured_urls
    assert_select "#try a.lp-card", count: 0
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

  test "homepage presents the product image before Try now without a duplicate creation section" do
    get root_url

    assert_response :success
    assert_select "header.lp-hero img.lp-product-img[src='/product.png']", count: 1
    assert_select "header.lp-hero h1", text: "Turn any video to a language practice"
    assert_select "header.lp-hero .lp-supported", text: "Supported languages: Spanish, French, Hebrew, Arabic"
    assert_select "header.lp-hero .lp-lead", text: /Free account required/
    refute_includes response.body, ".lp-hero .lp-lead { display:none; }"
    assert_select "header.lp-hero form", count: 0
    assert_select "#try form[action=?][method=get] input[name=url]", try_path
    assert_select "#create", count: 0

    body = response.body
    assert_operator body.index('id="try"'), :<, body.index('class="lp-footer"')
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
    configured_urls = HomepageVideos.all.map(&:url)
    assert_equal homepage_video_count, cards.size
    assert_empty cards.map { |card| card["data-video-url"] } - configured_urls
    refute_includes cards.map { |card| card["data-video-url"] }, playlist_course.main_media_url
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
    assert_select "[data-testid='primary-web-header'] a", text: "Browse Langlets", count: 0
    assert_select "[data-testid='primary-web-header'] a", text: "Library", count: 0
    assert_select "[data-testid='primary-web-header'] a[href=?]", new_user_session_path, text: "Sign in"
  end

  test "the homepage sells nothing to signed-in users either" do
    sign_in @user

    get root_url

    assert_response :success
    assert_select "#pricing", count: 0
    assert_select "form[action*=?]", "paypal.com", count: 0
    assert_select "[data-testid='primary-web-header'] a[href=?]", gallery_path, text: "Library"
    assert_select "[data-testid='primary-web-header'] a[href=?]", new_app_import_request_path, text: "Create"
    assert_select "[data-testid='primary-web-header'] a", text: "Browse Langlets", count: 0
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
