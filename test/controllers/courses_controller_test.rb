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
    @course = Course.create!(
      name: "Query course",
      slug: "query-course",
      main_media_url: "https://www.youtube.com/watch?v=querycourse",
      language: @language,
      user: @user
    )

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

  test "homepage shows at most eight videos and links to the gallery" do
    @course.update!(status: :published)
    9.times do |index|
      Course.create!(
        name: "Homepage course #{index}",
        slug: "homepage-course-#{index}",
        main_media_url: "https://www.youtube.com/watch?v=homepage#{index}",
        language: @language,
        user: @user,
        status: :published
      )
    end

    sign_in @user
    get root_url

    assert_response :success
    assert_select ".lp-card:not([hidden])", count: 8
    assert_select "a[href='#{gallery_path}']", text: "Browse Langlets"
    assert_select "a[href='#{gallery_path}']", text: "Browse All Langlets"
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

  test "homepage presents the product image before the library and creation form" do
    get root_url

    assert_response :success
    assert_select "header.lp-hero img.lp-product-img[src='/product.png']", count: 1
    assert_includes response.body, ".lp-hero .lp-lead { display:none; }"
    assert_select "header.lp-hero form", count: 0
    assert_select "#create h2", text: "Create Your Own"
    assert_select "#create", text: /full transcript, translation and vocabulary exercises/
    assert_select "#create form[action=?][method=post]", guest_import_requests_path

    body = response.body
    assert_operator body.index('id="library"'), :<, body.index('id="create"')
    assert_operator body.index('id="create"'), :<, body.index('id="pricing"')
  end

  test "homepage keeps all language pills when French is selected" do
    french_course = Course.create!(
      name: "French homepage course",
      slug: "french-homepage-course",
      main_media_url: "https://www.youtube.com/watch?v=frenchhome",
      language: languages(:french),
      user: @user,
      status: :published
    )

    8.times do |index|
      Course.create!(
        name: "Newer English course #{index}",
        slug: "newer-english-course-#{index}",
        main_media_url: "https://www.youtube.com/watch?v=newer#{index}",
        language: @language,
        user: @user,
        status: :published
      )
    end

    french_course.touch(time: 1.day.ago)
    get root_url(lang: "fr")

    assert_response :success
    assert_select ".lp-card:not([hidden])", count: 1
    assert_select ".lp-card:not([hidden])[href='#{course_path(french_course.slug)}']"
    assert_select ".lp-chip", text: "French"
    assert_select "#library[data-homepage-filter-initial-lang-value='fr']"
    assert_select ".lp-chip[data-homepage-filter-lang-param='en']", text: "English"
  end

  test "homepage ignores an unsupported initial language filter" do
    @course.update!(status: :published)

    get root_url(lang: "xx")

    assert_response :success
    assert_select "#library[data-homepage-filter-initial-lang-value='xx']"
    assert_select ".lp-chip[data-homepage-filter-lang-param='xx']", count: 0
  end

  test "homepage mixes playlist and standalone courses newest first" do
    @course.update!(status: :published, created_at: 2.days.ago)
    playlist_course = Course.create!(
      name: "Newest playlist course",
      slug: "newest-playlist-course",
      main_media_url: "https://www.youtube.com/watch?v=playlistnewest",
      language: @language,
      user: @user,
      status: :published,
      created_at: 1.hour.ago
    )
    playlist = Playlist.create!(name: "Homepage playlist", published: true)
    playlist.courses << playlist_course

    get root_url

    assert_response :success
    cards = css_select(".lp-card:not([hidden])")
    assert_equal course_path(playlist_course.slug), cards.first["href"]
    assert_includes cards.map { |card| card["href"] }, course_path(@course.slug)
  end

  test "guest pricing CTA starts signup" do
    get root_url

    assert_response :success
    assert_select "a[href=?]", new_user_registration_path(returnto: "/"),
                  text: "Start Creating Langlets"
    assert_select "#pricing", text: /Buy 20 credits/, count: 0
  end

  test "signed-in pricing CTA submits the 20 credit pack directly to PayPal" do
    paypal_client = Paypal::Client.new(merchant_id: "SANDBOXMERCHANT")
    sign_in @user

    Paypal::Client.stub(:new, paypal_client) do
      get root_url
    end

    assert_response :success
    assert_select "#pricing form[action=?][method=post][data-turbo=false]",
                  Paypal::Client::SANDBOX_URL do
      assert_select "input[name=item_number][value=credits_20]"
      assert_select "input[name=amount][value='10.00']"
      assert_select "button[type=submit]", text: "Buy 20 credits"
    end
    assert_select "#pricing", text: /Start Creating Langlets/, count: 0
  end

  private

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
