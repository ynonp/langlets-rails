require "test_helper"

class MarketingTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    @admin = User.create!(email: User::ADMIN_EMAIL, password: "password123", confirmed_at: Time.zone.now)
    @channel = @admin.default_channel
    @channel.update!(visibility: :public)
    medium = Medium.create!(url: "https://www.youtube.com/watch?v=marketing1", language: languages(:english))
    @course = Course.create!(user: @admin, name: "Marketing langlet", slug: "marketing-langlet", main_media_url: medium.url, language: languages(:english), status: :published)
    @lesson = Lesson.create!(course: @course, medium: medium, user: @admin, name: "First lesson", slug: "first", order: 1)
    @next_lesson = Lesson.create!(course: @course, medium: medium, user: @admin, name: "Second lesson", slug: "second", order: 2)
    @channel.publish!(@course)
  end

  test "every lesson finishes with marketing and allows continuing" do
    enter_marketing
    [ @lesson, @next_lesson ].each do |lesson|
      get finish_course_lesson_path(@course, lesson)
      assert_response :success
      assert_select "h1", I18n.t("marketing.reveal")
      assert_select "form[action=?]", course_lesson_prospects_path(@course, lesson)
    end
    get finish_course_lesson_path(@course, @lesson)
    assert_select "a[href=?]", course_lesson_path(@course, @next_lesson)
  end

  test "ordinary visits use the regular finish and cannot submit prospects" do
    get finish_course_lesson_path(@course, @lesson)
    assert_response :success
    assert_select "#marketing-title", count: 0
    assert_no_difference "Prospect.count" do
      submit("test@example.com")
    end
    assert_response :not_found
  end

  test "attribution persists across courses but does not grant access" do
    enter_marketing
    @channel.unpublish!(@course)
    get finish_course_lesson_path(@course, @lesson)
    assert_redirected_to new_user_session_path(returnto: finish_course_lesson_path(@course, @lesson))
    assert_no_difference "Prospect.count" do
      submit("private@example.com")
    end
    assert_redirected_to new_user_session_path

    other_course = Course.create!(user: @admin, name: "Other", slug: "other-marketing", main_media_url: "https://www.youtube.com/watch?v=marketing2", language: languages(:english), status: :published)
    other_lesson = Lesson.create!(course: other_course, medium: @lesson.medium, user: @admin, name: "Other", slug: "other", order: 1)
    @channel.publish!(other_course)
    get finish_course_lesson_path(other_course, other_lesson)
    assert_response :success
    assert_select "#marketing-title"
  end

  test "blank and malformed sources are ignored and later campaigns replace the session source" do
    [ "", "   ", [ "campaign" ], { campaign: "bad" } ].each do |source|
      get finish_course_lesson_path(@course, @lesson), params: { utm_source: source }
      assert_response :success
      assert_select "#marketing-title", count: 0
    end
    enter_marketing
    get course_path(@course), params: { utm_source: "   " }
    submit("first@example.com")
    assert_equal "newsletter", Prospect.last.utm_source
    get course_path(@course), params: { utm_source: "  second-campaign  " }
    submit("second@example.com")
    assert_equal "second-campaign", Prospect.last.utm_source
    enter_marketing
    submit("first@example.com")
    assert_equal "newsletter", Prospect.find_by!(email: "first@example.com").utm_source
  end

  test "tagged landing outside a course survives sign in and ordinary navigation" do
    get new_user_session_path, params: { utm_source: "landing" }
    post user_session_path, params: { user: { email: @admin.email, password: "password123" } }
    assert_response :redirect
    get finish_course_lesson_path(@course, @lesson)
    assert_response :success
    assert_select "#marketing-title"
    submit("landing@example.com")
    assert_equal "landing", Prospect.last.utm_source
  end

  test "source is bounded and sessions are isolated" do
    get course_path(@course), params: { utm_source: "x" * 5000 }
    submit("bounded@example.com")
    assert_equal "x" * 255, Prospect.last.utm_source
    open_session do |visitor|
      visitor.get finish_course_lesson_path(@course, @lesson)
      visitor.assert_response :success
      visitor.assert_select "#marketing-title", count: 0
    end
  end

  test "signed in marketing visits still record lesson completion" do
    sign_in @admin
    enter_marketing
    assert_difference "LessonUser.count", 1 do
      get finish_course_lesson_path(@course, @lesson)
    end
    assert_select "#marketing-title"
    assert Enrollment.exists?(user: @admin, course: @course)
  end

  test "submission records source and sends both emails without creating an unverified account" do
    enter_marketing
    assert_difference "Prospect.count", 1 do
      assert_no_difference "User.count" do
        assert_enqueued_with(job: DeliverProspectEmailsJob) do
          submit("  New@Example.com ")
        end
      end
    end
    assert_nil request.session[:utm_source]
    prospect = Prospect.last
    assert_equal "new@example.com", prospect.email
    assert_equal [ "newsletter", @course.id, @lesson.id ], [ prospect.utm_source, prospect.course_id, prospect.lesson_id ]
    assert_redirected_to finish_course_lesson_path(@course, @lesson)
    follow_redirect!
    assert_select '[role="status"]', I18n.t("marketing.email_next")
    assert_select "input[type=email]", count: 0
    get finish_course_lesson_path(@course, @next_lesson)
    assert_select "#marketing-title", count: 0
    assert_no_difference "Prospect.count" do
      assert_no_enqueued_jobs { submit("another@example.com") }
    end
    assert_response :not_found
    assert_difference "ActionMailer::Base.deliveries.size", 2 do
      DeliverProspectEmailsJob.perform_now(prospect.id)
    end
    mail = ActionMailer::Base.deliveries.find { |message| message.to == [ prospect.email ] }
    assert_includes mail.text_part.body.decoded, "marketing/setup?token="
    assert_includes mail.text_part.body.decoded, prospect.email
    assert ActionMailer::Base.deliveries.any? { |message| message.to == [ User::ADMIN_EMAIL ] }
    assert_no_difference "ActionMailer::Base.deliveries.size" do
      DeliverProspectEmailsJob.perform_now(prospect.id)
    end
  end

  test "duplicate and invalid submissions" do
    enter_marketing
    submit("same@example.com")
    assert_no_difference "Prospect.count" do
      enter_marketing
      submit(" SAME@example.com ")
      assert_nil request.session[:utm_source]
      enter_marketing
      submit("invalid")
    end
    follow_redirect!
    assert_select '[role="alert"]', I18n.t("marketing.invalid_email")
    assert_equal "newsletter", request.session[:utm_source]
    assert_select "input[type=email]"
  end

  test "new prospect chooses password verifies email and receives Pro once" do
    prospect = Prospect.create!(email: "activate@example.com")
    token = prospect.generate_token_for(:setup)
    get marketing_setup_path(token: token)
    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "strict-origin", response.headers["Referrer-Policy"]
    assert_select "input[name=password]"
    assert_difference "User.count", 1 do
      assert_difference "Subscription.count", 1 do
        post marketing_setup_path, params: { token: token, password: "securepassword", password_confirmation: "securepassword" }
      end
    end
    assert_redirected_to new_user_session_path
    account = prospect.reload.user
    assert account.confirmed?
    assert account.pro?
    assert account.valid_password?("securepassword")
    assert_not_nil account.default_channel
    assert_no_difference "Subscription.count" do
      post marketing_setup_path, params: { token: token, password: "somethingelse" }
    end
    assert_response :gone
  end

  test "invalid passwords do not consume offer or create account" do
    prospect = Prospect.create!(email: "invalid-password@example.com")
    token = prospect.generate_token_for(:setup)
    assert_no_difference "User.count" do
      post marketing_setup_path, params: { token: token, password: "short", password_confirmation: "different" }
    end
    assert_response :unprocessable_entity
    assert_nil prospect.reload.activated_at
    assert Prospect.find_by_token_for(:setup, token)
  end

  test "existing account gets Pro without changing password or signing in the visitor" do
    prospect = Prospect.create!(email: @admin.email)
    token = prospect.generate_token_for(:setup)
    get marketing_setup_path(token: token)
    assert_select "input[name=password]", count: 0
    assert_no_difference "User.count" do
      post marketing_setup_path, params: { token: token, password: "attacker-password" }
    end
    assert @admin.reload.valid_password?("password123")
    assert @admin.pro?
    get admin_channels_path
    assert_redirected_to new_user_session_path
  end

  test "existing Pro entitlement is preserved" do
    subscription = @admin.pro!
    prospect = Prospect.create!(email: @admin.email)
    assert_no_difference "Subscription.count" do
      post marketing_setup_path, params: { token: prospect.generate_token_for(:setup) }
    end
    assert_equal subscription, @admin.reload.pro_subscription
  end

  test "expired and tampered setup links are rejected without mutation" do
    prospect = Prospect.create!(email: "expired@example.com")
    token = prospect.generate_token_for(:setup)
    travel 8.days do
      assert_no_difference "User.count" do
        post marketing_setup_path, params: { token: token, password: "password123" }
      end
      assert_response :gone
    end
    get marketing_setup_path(token: "#{token}tampered")
    assert_response :gone
  end

  test "Hebrew finish and setup pages and mail are localized" do
    host! "he.langlets.app"
    enter_marketing
    get finish_course_lesson_path(@course, @lesson)
    assert_select 'html[dir="rtl"]'
    assert_select "h1", I18n.t("marketing.reveal", locale: :he)
    submit("hebrew@example.com")
    prospect = Prospect.last
    assert_equal "he", prospect.locale
    host! "langlets.app"
    get marketing_setup_path(token: prospect.generate_token_for(:setup))
    assert_select 'html[dir="rtl"]'
    mail = ProspectMailer.with(prospect: prospect).invitation
    assert_equal I18n.t("marketing.email_subject", locale: :he), mail.subject
    assert_includes mail.text_part.body.decoded, I18n.t("marketing.email_intro", locale: :he)
    html = Nokogiri::HTML(mail.html_part.body.decoded)
    assert_equal "he", html.at_css("html")["lang"]
    assert_equal "rtl", html.at_css("html")["dir"]
    setup_link = html.at_css("a[href*='marketing/setup']")
    assert_equal I18n.t("marketing.email_link", locale: :he), setup_link.text.strip
    assert_includes setup_link["style"], "display: inline-block"
    assert_includes setup_link.parent["style"], "background-color: #059669"
  end

  test "admin can review prospects and their source" do
    Prospect.create!(email: "recent-prospect@example.com", utm_source: "newsletter", course: @course)
    sign_in @admin
    get admin_prospects_path
    assert_response :success
    assert_select "td a", "recent-prospect@example.com"
    assert_select "td", "newsletter"
    assert_includes response.body, "1 prospects"
  end

  test "non admin cannot review prospects" do
    user = User.create!(email: "outsider@example.com", password: "password123", confirmed_at: Time.zone.now)
    sign_in user
    get admin_prospects_path
    assert_response :forbidden
  end

  test "submission rate limit rejects without storing or sending" do
    ProspectsController.cache_store.stub :increment, 11 do
      assert_no_difference "Prospect.count" do
        assert_no_enqueued_jobs { submit("limited@example.com") }
      end
      assert_response :too_many_requests
    end
  end

  test "rate limit is shared by sessions on one IP and resets after an hour" do
    store = ActiveSupport::Cache::MemoryStore.new
    ProspectsController.cache_store.stub :increment, ->(*args, **options) { store.increment(*args, **options) } do
      enter_marketing
      10.times do
        post course_lesson_prospects_path(@course, @lesson),
          params: { prospect: { email: "invalid" } }, env: { "REMOTE_ADDR" => "203.0.113.1" }
        assert_response :see_other
      end

      open_session do |visitor|
        visitor.post course_lesson_prospects_path(@course, @lesson),
          params: { prospect: { email: "limited@example.com" } }, env: { "REMOTE_ADDR" => "203.0.113.1" }
        visitor.assert_response :too_many_requests
      end

      post course_lesson_prospects_path(@course, @lesson),
        params: { prospect: { email: "invalid" } }, env: { "REMOTE_ADDR" => "203.0.113.2" }
      assert_response :see_other
      assert_equal "newsletter", request.session[:utm_source]

      travel 1.hour + 1.second do
        post course_lesson_prospects_path(@course, @lesson),
          params: { prospect: { email: "invalid" } }, env: { "REMOTE_ADDR" => "203.0.113.1" }
        assert_response :see_other
      end
    end
  end

  test "a lesson from another course cannot be used as attribution" do
    enter_marketing
    assert_no_difference "Prospect.count" do
      post course_lesson_prospects_path(@course, "unknown-lesson"), params: { prospect: { email: "wrong-source@example.com" } }
    end
    assert_response :not_found
  end

  test "setup does not accept a substituted email and remains public in native clients" do
    prospect = Prospect.create!(email: "intended@example.com")
    token = prospect.generate_token_for(:setup)
    get marketing_setup_path(token: token), headers: { "User-Agent" => "LangletsNative (Android)" }
    assert_response :success
    post marketing_setup_path, params: { token: token, email: "substituted@example.com", password: "password123", password_confirmation: "password123" }
    assert_equal "intended@example.com", prospect.reload.user.email
    assert_nil User.find_by(email: "substituted@example.com")
  end

  test "signup and account setup submit successfully with CSRF origin checks enabled" do
    previous_protection = ActionController::Base.allow_forgery_protection
    previous_origin_check = ActionController::Base.forgery_protection_origin_check
    ActionController::Base.allow_forgery_protection = true
    ActionController::Base.forgery_protection_origin_check = true

    enter_marketing
    get finish_course_lesson_path(@course, @lesson)
    assert_select 'meta[name="referrer"][content="strict-origin"]'
    csrf_token = css_select('input[name="authenticity_token"]').first["value"]
    post course_lesson_prospects_path(@course, @lesson),
      params: { authenticity_token: csrf_token, prospect: { email: "browser-csrf@example.com" } },
      headers: { "Origin" => request.base_url }
    assert_redirected_to finish_course_lesson_path(@course, @lesson)

    prospect = Prospect.find_by!(email: "browser-csrf@example.com")
    setup_token = prospect.generate_token_for(:setup)
    get marketing_setup_path(token: setup_token)
    assert_select 'meta[name="referrer"][content="strict-origin"]'
    assert_equal "strict-origin", response.headers["Referrer-Policy"]
    csrf_token = css_select('input[name="authenticity_token"]').first["value"]
    post marketing_setup_path,
      params: { authenticity_token: csrf_token, token: setup_token, password: "password123", password_confirmation: "password123" },
      headers: { "Origin" => request.base_url }
    assert_redirected_to new_user_session_path
    assert prospect.reload.user.confirmed?
    assert prospect.user.pro?
  ensure
    ActionController::Base.allow_forgery_protection = previous_protection
    ActionController::Base.forgery_protection_origin_check = previous_origin_check
  end

  private

  def enter_marketing
    get course_path(@course), params: { utm_source: "newsletter" }
    assert_response :success
  end

  def submit(email)
    post course_lesson_prospects_path(@course, @lesson), params: { prospect: { email: email } }
  end
end
