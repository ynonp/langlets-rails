require "test_helper"
require "minitest/mock"

module App
  # The Add Video sheet: which state #resolve draws for what the user typed.
  # Preview's own rules are covered in test/services/imports/preview_test.rb —
  # this is about mode detection and what actually reaches the screen.
  class AddVideoTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers

    NATIVE = { "User-Agent" => "LangletsNative" }.freeze
    VIDEO_ID = "kJQP7kiw5Fk".freeze
    CANONICAL = "https://www.youtube.com/watch?v=#{VIDEO_ID}".freeze

    setup do
      @user = User.create!(email: "add-video@example.com", password: "password123",
                           confirmed_at: Time.zone.now)
      @spanish = languages(:spanish)
      @english = languages(:english)
      sign_in @user
      # Native app screens are unreachable until a language is chosen.
      get "/app?lang=es", headers: NATIVE
    end

    test "the sheet opens on the empty state, with the guidance line and no card" do
      get "/app/import_requests/new", headers: NATIVE

      assert_response :success
      assert_select "input[data-add-video-target=input]"
    end

    test "the form and pipeline submission are available to web browsers" do
      web = { "User-Agent" => "Mozilla/5.0" }
      paypal_client = Paypal::Client.new(merchant_id: "SANDBOXMERCHANT")
      Paypal::Client.stub(:new, paypal_client) do
        get "/app/import_requests/new", headers: web
      end
      assert_response :success
      assert_select "[data-testid='web-add-video'].lg\\:grid-cols-\\[minmax\\(0\\,1fr\\)_22rem\\]"
      assert_select "input#web-video-url[data-add-video-target=input]"
      assert_select "[data-controller='theme']", count: 0
      assert_select ".bg-\\[\\#FAF6EF\\]"
      assert_select ".bg-\\[\\#C4451C\\]"
      assert_select ".app-scroll-pad", count: 0
      assert_select "form[action=?][method=post][data-turbo=false]", Paypal::Client::SANDBOX_URL do
        assert_select "input[name=item_number][value=credits_20]"
        assert_select "input[name=amount][value='10.00']"
        assert_select "button[type=submit]", text: "Buy More"
      end
      assert_match "3 credits left", response.body

      stub_video do
        post "/app/import_requests",
             params: { url: CANONICAL, clip_language: "Spanish", translation_language: "English" },
             headers: web
      end

      assert_redirected_to app_import_requests_path
      assert_equal 2, @user.reload.credit_balance
      assert @user.import_requests.sole.charged?
    end

    test "an empty query resolves back to the empty state, not to an error" do
      get resolve_path(q: ""), headers: NATIVE

      assert_response :success
      assert_no_match(/Approve/, response.body)
    end

    test "a pasted link resolves to a preview with the cost on the button" do
      stub_video { get resolve_path(q: CANONICAL), headers: NATIVE }

      assert_response :success
      assert_match "Despacito", response.body
      # §5: the price is stated in the explanation card and again on the button,
      # so a credit can't leave without having been seen twice.
      assert_match "Imports as a lesson", response.body
      assert_match "Approve · use 1 credit", response.body
      assert_select "form[action=?][data-turbo-frame=_top]", app_import_requests_path
      assert_select "form[data-turbo=false]", count: 0
    end

    test "the web preview uses a full-page submission" do
      stub_video { get resolve_path(q: CANONICAL), headers: { "User-Agent" => "Mozilla/5.0" } }

      assert_response :success
      assert_select "turbo-frame#add_video_result .sm\\:grid-cols-\\[14rem_minmax\\(0\\,1fr\\)\\]"
      assert_select "form[action=?][data-turbo=false]", app_import_requests_path
      assert_select "form[data-turbo-frame=_top]", count: 0
      assert_select ".app-inset-hairline", count: 0
    end

    test "the native add-video screen keeps the native-only form" do
      get new_app_import_request_path, headers: NATIVE

      assert_response :success
      assert_select ".app-scroll-pad[data-controller='add-video']"
      assert_select "[data-testid='web-add-video']", count: 0
    end

    test "a bare video id resolves the same as a full link" do
      stub_video { get resolve_path(q: VIDEO_ID), headers: NATIVE }

      assert_response :success
      assert_match "Despacito", response.body
      assert_match "Approve · use 1 credit", response.body
    end

    test "a youtu.be short link resolves" do
      stub_video { get resolve_path(q: "https://youtu.be/#{VIDEO_ID}"), headers: NATIVE }

      assert_response :success
      assert_match "Approve · use 1 credit", response.body
    end

    test "text that isn't a link offers no import" do
      get resolve_path(q: "easy spanish interviews"), headers: NATIVE

      assert_response :success
      assert_no_match(/Approve/, response.body)
    end

    test "a video the provider won't serve offers no import" do
      VideoSource.stub(:fetch, ->(_url) { raise VideoSource::UnavailableVideo, "private" }) do
        get resolve_path(q: CANONICAL), headers: NATIVE
      end

      assert_response :success
      assert_no_match(/Approve/, response.body)
    end

    test "resolving charges nothing" do
      stub_video { get resolve_path(q: CANONICAL), headers: NATIVE }

      assert_equal 3, @user.reload.credit_balance
      assert_equal 0, @user.import_requests.count
    end

    # §5.1: the paywall replaces the button, not the card. Seeing the video is
    # the reason to buy, so it has to still be on screen.
    test "an empty balance shows Get credits but keeps the preview card" do
      User.where(id: @user.id).update_all(credit_balance: 0)

      stub_video { get resolve_path(q: CANONICAL), headers: NATIVE }

      assert_response :success
      assert_match "Despacito", response.body, "the card must stay rendered"
      assert_match "Get credits", response.body
      assert_no_match(/Approve · use 1 credit/, response.body)
    end

    test "the credits screen offers a way back to the video, so nothing is re-pasted" do
      get "/app/credits?url=#{CGI.escape(CANONICAL)}", headers: NATIVE

      assert_response :success
      # The app carries ?lang= on every generated URL, so match on the part
      # that matters: the sheet reopens already pointed at this video.
      assert_select "a[href*=?][href*=?]", "/app/import_requests/new", "url=#{CGI.escape(CANONICAL)}"
    end

    # §4: duplicates short-circuit before the balance is consulted, so this must
    # be the library state and not the paywall.
    test "a video already in the library offers Open lesson, even at zero credits" do
      publish_course!
      User.where(id: @user.id).update_all(credit_balance: 0)

      stub_video { get resolve_path(q: CANONICAL), headers: NATIVE }

      assert_response :success
      assert_match "Already in your library.", response.body
      assert_match "Open lesson", response.body
      assert_no_match(/Get credits/, response.body)
      assert_no_match(/Approve/, response.body)
    end

    test "a video already importing offers the queue instead of a second charge" do
      stub_video do
        Imports::Create.call(user: @user, url: CANONICAL,
                             clip_language: "Spanish", translation_language: "English")
      end

      stub_video { get resolve_path(q: CANONICAL), headers: NATIVE }

      assert_response :success
      assert_match "Already importing.", response.body
      assert_match "View in queue", response.body
      assert_no_match(/Approve/, response.body)
    end

    test "approving from the preview charges once and lands in the queue" do
      stub_video do
        post "/app/import_requests",
             params: { url: CANONICAL, clip_language: "Spanish", translation_language: "English" },
             headers: NATIVE
      end

      assert_match %r{/app/import_requests}, response.location
      assert_equal 2, @user.reload.credit_balance
      assert @user.import_requests.sole.charged?
    end

    private

    def resolve_path(q:)
      "/app/import_requests/resolve?q=#{CGI.escape(q)}"
    end

    def stub_video(&block)
      video = Youtube::Oembed::Video.new(
        video_id: VIDEO_ID, title: "Despacito", author_name: "Luis Fonsi",
        thumbnail_url: "https://i.ytimg.com/vi/#{VIDEO_ID}/hqdefault.jpg",
        canonical_url: CANONICAL
      )
      Youtube::Oembed.stub(:fetch, ->(_url) { video }, &block)
    end

    def publish_course!
      Course.create!(
        name: "Despacito", slug: "despacito-lib", main_media_url: CANONICAL,
        youtube_video_id: VIDEO_ID, language: @spanish, user: @user, status: :published
      ).tap do |course|
        course.course_translations.create!(language: @english, name: "Despacito", status: :ready)
      end
    end
  end
end
