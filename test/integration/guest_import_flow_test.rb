require "test_helper"

class GuestImportFlowTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  VIDEO_ID = "kJQP7kiw5Fk".freeze
  SHARED_URL = "https://youtu.be/#{VIDEO_ID}?si=homepage".freeze
  CANONICAL_URL = "https://www.youtube.com/watch?v=#{VIDEO_ID}".freeze
  NATIVE = { "User-Agent" => "LangletsNative" }.freeze

  setup do
    @admin = User.create!(email: User::ADMIN_EMAIL, password: "password123", confirmed_at: Time.zone.now)
    @video = VideoSource::Video.new(
      provider: :youtube,
      video_id: VIDEO_ID,
      title: "Despacito",
      author_name: "Luis Fonsi",
      thumbnail_url: "https://i.ytimg.com/vi/#{VIDEO_ID}/hqdefault.jpg",
      canonical_url: CANONICAL_URL
    )
  end

  test "homepage offers an explicit build form and example selectors" do
    get root_path

    assert_select "[data-testid=beta-notice]", text: "Free while in beta"
    assert_select ".lp-hero h1", text: "Turn any video to a language practice"
    assert_select ".lp-hero .lp-lead", text: /Free account required/
    assert_select "#try h2", count: 0
    assert_select "#try", text: /Free account required/, count: 0
    assert_select "#try .lp-try-label", text: "Paste any YouTube or TikTok link to build"
    assert_select "#try form[action=?][method=get] input[name=url][data-homepage-video-picker-target=input]", try_path
    assert_select "#try form button", text: "Build my langlet"
    assert_select "#try .lp-try-or", text: /No link handy?/
    assert_select "#try button.lp-card[data-video-url][data-action='homepage-video-picker#select']", count: homepage_video_count
    assert_select "#try a.lp-card", count: 0
  end

  test "configured example saves its full evaluation snapshot and reuses a legacy course" do
    configured = HomepageVideos.all.first
    clip_language = Language.find_by!(english_name: configured.clip_language)
    translation_language = languages(:english)
    video_id = VideoSource.video_id(configured.url)
    video = VideoSource::Video.new(
      provider: :youtube,
      video_id: video_id,
      title: configured.title,
      author_name: "Example author",
      thumbnail_url: VideoSource.derived_thumbnail_url(configured.url),
      canonical_url: configured.url
    )
    published = Course.create!(
      name: configured.title,
      slug: "configured-legacy-example",
      main_media_url: configured.url,
      youtube_video_id: nil,
      language: clip_language,
      user: @admin,
      status: :published
    )
    published.course_translations.create!(
      language: translation_language,
      name: configured.title,
      status: :ready
    )

    assert_no_enqueued_jobs only: [ DetectImportLanguageJob, CreateCourseJob ] do
      VideoSource.stub(:fetch, video) do
        post guest_import_requests_path, params: { url: configured.url }
      end
    end

    source = @admin.import_requests.find_by!(youtube_video_id: video_id)
    evaluation = EvaluationSignup.find_by!(admin_import_request: source)
    assert source.ready?
    assert source.guest_started?
    assert_equal published, source.course
    assert_equal configured.url, evaluation.video_url
    assert_equal video_id, evaluation.video_id
    assert_equal "youtube", evaluation.provider
    assert_equal configured.title, evaluation.title
    assert_equal configured.clip_language, evaluation.clip_language
    assert_equal "English", evaluation.translation_language
    assert_equal published, evaluation.course

    learner = User.create!(email: "configured-example@example.com", password: "password123", confirmed_at: Time.zone.now)
    claim = evaluation.claim!(learner)
    assert claim.ready?
    assert_equal published, claim.course
    assert learner.default_channel.channel_items.exists?(course: published)
  end

  test "try page shows a large preview and both authentication choices" do
    info = TryVideoInfo::Info.new(
      language: "French",
      duration: "4:12",
      line_count: 96,
      unique_word_count: 340
    )
    VideoSource.stub(:fetch, @video) do
      TryVideoInfo.stub(:for, info) { get try_path(url: SHARED_URL) }
    end

    assert_response :success
    assert_select "img.aspect-video[src=?]", @video.thumbnail_url
    assert_select "h2", text: @video.title
    assert_select "h1", text: "Ready to build: #{@video.title}"
    assert_select "body", text: /French · 4:12 · 96 lines of dialogue · ~340 unique words/
    assert_select "body", text: /Loud and clear:/
    assert_select "body", text: /Your Langlets are yours/
    assert_select "body", text: /No card needed\./
    assert_select "form[action=?][method=post] button", guest_import_requests_path, text: "Signup to create"
    assert_select "form[action=?][method=post] input[name=authentication][value=login]", guest_import_requests_path
  end

  test "signup links EvaluationSignup and first login opens its waiting course" do
    VideoSource.stub(:fetch, @video) do
      assert_enqueued_with(job: DetectImportLanguageJob) do
        post guest_import_requests_path, params: { url: SHARED_URL }
      end
    end

    assert_redirected_to new_user_registration_path
    source = @admin.import_requests.find_by!(youtube_video_id: VIDEO_ID)
    evaluation_signup = EvaluationSignup.find_by!(admin_import_request: source)
    assert source.guest_started?
    assert source.detecting?
    assert source.course.pending?
    assert_equal source.course, evaluation_signup.course
    assert_includes response.headers["Set-Cookie"], GuestImportRequestsController::EVALUATION_SIGNUP_COOKIE.to_s

    post user_registration_path, params: {
      user: {
        email: "pending-video@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }
    assert_redirected_to user_registration_check_email_path

    user = User.find_by!(email: "pending-video@example.com")
    assert_equal evaluation_signup, user.reload.evaluation_signup
    assert_equal user, evaluation_signup.reload.user
    claim = user.import_requests.find_by!(youtube_video_id: VIDEO_ID)
    assert claim.detecting?
    assert_equal source.course, claim.course

    user.confirm
    reset! # Confirmation may be opened on a different device with no evaluation cookie.
    post user_session_path, params: { user: { email: user.email, password: "password123" } }

    assert_redirected_to course_path(source.course)
    assert_equal source.create_song_progress, claim.create_song_progress
    refute claim.guest_started?
    assert evaluation_signup.reload.consumed_at?

    follow_redirect!
    assert_response :success
    assert_select "h1", text: "Despacito"
    assert_select "meta[http-equiv=refresh][content='5']", count: 1
    assert_select "body", text: /already in your account/
  end

  test "signup deletes the browser evaluation so another person cannot inherit it" do
    VideoSource.stub(:fetch, @video) do
      post guest_import_requests_path, params: { url: SHARED_URL }
    end
    evaluation = EvaluationSignup.find_by!(video_id: VIDEO_ID)

    post user_registration_path, params: {
      user: {
        email: "first-browser-user@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }
    first_user = User.find_by!(email: "first-browser-user@example.com")
    assert_equal evaluation, first_user.evaluation_signup

    post user_registration_path, params: {
      user: {
        email: "second-browser-user@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }
    second_user = User.find_by!(email: "second-browser-user@example.com")
    assert_nil second_user.evaluation_signup
    assert_equal first_user, evaluation.reload.user
  end

  test "login starts the same import before redirecting to the existing login page" do
    VideoSource.stub(:fetch, @video) do
      post guest_import_requests_path, params: { url: SHARED_URL, authentication: "login" }
    end

    assert_redirected_to new_user_session_path
    assert @admin.import_requests.find_by!(youtube_video_id: VIDEO_ID).guest_started?
  end

  test "another guest reuses the same admin-started clip" do
    VideoSource.stub(:fetch, @video) do
      post guest_import_requests_path, params: { url: SHARED_URL }
      first = @admin.import_requests.find_by!(youtube_video_id: VIDEO_ID)

      post guest_import_requests_path, params: { url: SHARED_URL }
      assert_equal [ first.id ], @admin.import_requests.where(youtube_video_id: VIDEO_ID).pluck(:id)
      assert_equal 2, EvaluationSignup.where(admin_import_request: first).count
    end
  end

  test "native signed-out flow is welcome then video selection then preview" do
    get root_path, headers: NATIVE
    assert_redirected_to onboarding_welcome_path

    get onboarding_welcome_path, headers: NATIVE
    assert_select "[data-testid=beta-notice]", text: "Free while in beta"
    assert_select "a[href=?]", onboarding_video_path

    get onboarding_video_path, headers: NATIVE
    assert_response :success
    assert_select "form[action=?] input[name=url][data-homepage-video-picker-target=input]", try_path
    assert_select "form[action=?] button", try_path, text: "Build my langlet"
    assert_select "button[data-video-url][data-action='homepage-video-picker#select']", count: homepage_video_count
    assert_select "a[href^='/try?url=']", count: 0

    VideoSource.stub(:fetch, @video) { get try_path(url: SHARED_URL), headers: NATIVE }
    assert_response :success
    assert_select "button", text: "Signup to create"
  end

  test "the pending import cookie is consumed only once" do
    VideoSource.stub(:fetch, @video) do
      post guest_import_requests_path, params: { url: SHARED_URL }
    end
    user = User.create!(email: "single-use-video@example.com", password: "password123", confirmed_at: Time.zone.now)

    post user_session_path, params: { user: { email: user.email, password: "password123" } }
    evaluation_signup = user.reload.evaluation_signup
    assert_redirected_to course_path(evaluation_signup.course)

    delete destroy_user_session_path
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
    assert_redirected_to root_path
  end

  test "an invalid video is not saved" do
    post guest_import_requests_path, params: { url: "https://example.com/not-youtube" }

    assert_redirected_to root_path
    assert_empty @admin.import_requests
    assert_empty EvaluationSignup.all
  end

  private

  def homepage_video_count
    [ HomepageVideos.all.size, HomepageVideos::PAGE_LIMIT ].min
  end
end
