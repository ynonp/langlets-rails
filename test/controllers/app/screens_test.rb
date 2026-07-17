require "test_helper"

module App
  # Smoke coverage for the mobile app screens, plus the two guards that matter:
  # the screens are native-only, and the web UI doesn't regress.
  class ScreensTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers

    NATIVE = { "User-Agent" => "LangletsNative/2.0" }.freeze
    LEGACY_NATIVE = { "User-Agent" => "LangletsNative/1.0" }.freeze
    WEB = { "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" }.freeze

    SCREENS = {
      "Home" => "/app",
      "Library" => "/app/library",
      "Queue" => "/app/import_requests",
      "Add a video" => "/app/import_requests/new",
      "Credits" => "/app/credits"
    }.freeze

    setup do
      @user = User.create!(email: "screens@example.com", password: "password123", confirmed_at: Time.zone.now)
      @spanish = languages(:spanish)
      @english = languages(:english)
      @medium = Medium.create!(url: "https://www.youtube.com/watch?v=kJQP7kiw5Fk",
                               language: @spanish, translation_language: @english)
      @course = Course.create!(name: "Despacito", slug: "despacito-x", main_media_url: @medium.url,
                               youtube_video_id: "kJQP7kiw5Fk", language: @spanish,
                               translation_language: @english, user: @user, status: :published)
      Lesson.create!(course: @course, medium: @medium, user: @user, slug: "l1", name: "L1", order: 0)
      Enrollment.create!(user: @user, course: @course, source: :imported, last_practiced_at: 1.hour.ago)
      sign_in @user

      # ApplicationController#require_language_for_native_app sends native users
      # to /onboarding/language until they've chosen one, so every app screen is
      # unreachable without it. One request seeds session[:lang].
      get "/app?lang=es", headers: NATIVE
    end

    test "every screen renders for the native app" do
      SCREENS.each do |name, path|
        get path, headers: NATIVE
        assert_response :success, "#{name} (#{path}) returned #{response.status}"
      end
    end

    test "screens render with an empty account" do
      Enrollment.delete_all

      SCREENS.each do |name, path|
        get path, headers: NATIVE
        assert_response :success, "#{name} (#{path}) returned #{response.status} with no content"
      end
    end

    # These screens are native-only; a browser must never land on them.
    test "a web browser is redirected away from every screen" do
      SCREENS.each_value do |path|
        get path, headers: WEB
        assert_redirected_to root_path, "#{path} should be web-gated"
      end
    end

    test "a legacy app build is redirected away from native-tab screens" do
      SCREENS.each_value do |path|
        get path, headers: LEGACY_NATIVE
        assert_redirected_to root_path, "#{path} should be gated to native-tab builds"
      end
    end

    # Iterating on this CSS in a simulator would be miserable.
    test "the ?native=1 escape hatch opens the screens in a browser" do
      get "/app?native=1", headers: WEB
      assert_response :success

      # Sticks for the session, so links keep working.
      get "/app/library", headers: WEB
      assert_response :success

      get "/app/library?native=0", headers: WEB
      assert_redirected_to root_path
    end

    test "signed-out users are sent to sign in" do
      sign_out @user

      get "/app", headers: NATIVE
      assert_redirected_to new_user_session_path(returnto: "/app")
    end

    # The one line this project adds to the web UI.
    test "native users land on the app home instead of the web index" do
      get "/", headers: NATIVE
      assert_redirected_to app_home_path
    end

    test "the web index still renders for browsers" do
      get "/", headers: WEB
      assert_response :success
    end

    test "the web index still renders for signed-out visitors" do
      sign_out @user

      get "/", headers: WEB
      assert_response :success
    end

    # "Lesson 16 of 16" with a full bar under a heading that says "Keep it going"
    # reads as broken. The web's continue-learning list drops finished courses
    # the same way.
    test "Home drops finished courses from Keep it going" do
      @course.lessons.each { |lesson| LessonUser.create!(lesson: lesson, user: @user) }

      get "/app", headers: NATIVE

      assert_response :success
      assert_no_match "Keep it going", response.body
    end

    test "Home keeps a part-finished course in Keep it going" do
      second = Lesson.create!(course: @course, medium: @medium, user: @user,
                              slug: "l2", name: "L2", order: 1)
      LessonUser.create!(lesson: @course.lessons.first, user: @user)

      get "/app", headers: NATIVE

      assert_response :success
      assert_match "Keep it going", response.body
      assert_match "Lesson 2 of 2", response.body
      assert second.persisted?
    end

    test "Home shows the two latest courses with See all below them" do
      older_medium = Medium.create!(url: "https://www.youtube.com/watch?v=oldercourse1",
                                    language: @spanish, translation_language: @english)
      older_course = Course.create!(name: "Older Course", slug: "older-course",
                                    main_media_url: older_medium.url, youtube_video_id: "oldercourse1",
                                    language: @spanish, translation_language: @english,
                                    user: @user, status: :published)
      Lesson.create!(course: older_course, medium: older_medium, user: @user,
                     slug: "older-lesson", name: "Older lesson", order: 0)
      Enrollment.create!(user: @user, course: older_course, source: :library,
                         last_practiced_at: 2.hours.ago)

      latest_medium = Medium.create!(url: "https://www.youtube.com/watch?v=latestcours",
                                     language: @spanish, translation_language: @english)
      latest_course = Course.create!(name: "Latest Course", slug: "latest-course",
                                     main_media_url: latest_medium.url, youtube_video_id: "latestcours",
                                     language: @spanish, translation_language: @english,
                                     user: @user, status: :published)
      Lesson.create!(course: latest_course, medium: latest_medium, user: @user,
                     slug: "latest-lesson", name: "Latest lesson", order: 0)
      Enrollment.create!(user: @user, course: latest_course, source: :library,
                         last_practiced_at: 30.minutes.ago)

      get "/app", headers: NATIVE

      assert_response :success
      assert_select "[data-testid='keep-it-going']" do
        assert_select "h2:first-child", text: "Keep it going"
        assert_select "a[href=?]", app_library_path, text: "See all", count: 1
        assert_select "a", text: /Latest Course/
        assert_select "a", text: /Despacito/
        assert_select "a", text: /Older Course/, count: 0
        assert_select "p:last-child a", text: "See all"
      end
    end

    # With nothing to continue, Home becomes the first-run song picker: library
    # courses in the user's language, none of which they're enrolled in.
    test "Home with an empty account shows the song picker with library courses" do
      Enrollment.delete_all

      get "/app", headers: NATIVE

      assert_response :success
      assert_match "Pick your first song", response.body
      assert_match "Despacito", response.body
      assert_match "Bring your own song", response.body
      assert_no_match "Keep it going", response.body
    end

    test "the song picker only offers courses in the user's language" do
      Enrollment.delete_all
      french = languages(:french)
      Course.create!(name: "La Vie en Rose", slug: "la-vie-en-rose", main_media_url: "https://www.youtube.com/watch?v=frenchaaaaa",
                     youtube_video_id: "frenchaaaaa", language: french,
                     translation_language: @english, user: @user, status: :published)

      get "/app", headers: NATIVE

      assert_response :success
      assert_match "Despacito", response.body
      assert_no_match "La Vie en Rose", response.body
    end

    test "Home suggests library courses the user is not enrolled in" do
      Course.create!(name: "Bailando", slug: "bailando-x", main_media_url: "https://www.youtube.com/watch?v=bailandoaaa",
                     youtube_video_id: "bailandoaaa", language: @spanish,
                     translation_language: @english, user: @user, status: :published)

      get "/app", headers: NATIVE

      assert_response :success
      assert_match "Keep it going", response.body
      assert_match "More from the library", response.body
      assert_match "Bailando", response.body
      assert_match "Make your own lesson", response.body
    end

    test "Home shows an enrolled course and the credit balance" do
      get "/app", headers: NATIVE

      assert_select "a", text: /Start Course|Despacito/
      assert_match "langlets", response.body
      assert_match @user.credit_balance.to_s, response.body
    end

    test "Home shows only the current user's playlists" do
      own_playlist = Playlist.create!(name: "Road Trip Songs", slug: "road-trip-songs", user: @user)
      own_playlist.courses << @course
      empty_playlist = Playlist.create!(name: "Empty Favorites", slug: "empty-favorites", user: @user)
      Playlist.create!(name: "Featured Songs", slug: "featured-songs", published: true)
      other_user = User.create!(email: "other@example.com", password: "password123", confirmed_at: Time.zone.now)
      Playlist.create!(name: "Someone Else's Mix", slug: "someone-elses-mix", user: other_user)

      get "/app", headers: NATIVE

      assert_response :success
      assert_select "h2", text: "Your playlists"
      assert_select "a[href=?]", playlist_path(own_playlist), text: /Road Trip Songs.*1 song/m
      assert_select "a[href=?]", playlist_path(empty_playlist), text: /Empty Favorites.*0 songs/m
      assert_no_match "Featured Songs", response.body
      assert_no_match "Someone Else's Mix", response.body
    end

    test "Home profile menu exposes profile, word practice, and logout" do
      phrase = Phrase.create!(medium: @medium, l1: @spanish, l2: @english,
                              text_l1: "Hola", text_l2: "Hello", timestamp: "00:00:01")
      token = TokenTranslation.create!(phrase: phrase, l1_start_index: 0, l1_end_index: 3,
                                       index_type: :character_index, translation: "Hello")
      @user.saved_token_translations << token

      get "/app", headers: NATIVE

      assert_response :success
      assert_select "details[data-testid='app-profile-menu'][data-controller='profile-menu']" do
        assert_select "[data-action='click@document->profile-menu#close']"
        assert_select "summary[aria-label='Open profile menu']", text: "S"
        assert_select "a[href=?]", profile_path, text: "Profile"
        assert_select "form[action=?]", review_lessons_path(language_code: @spanish.iso_name) do
          assert_select "button", text: "Practice Words (#{@spanish.iso_name})"
        end
        assert_select "a[href=?][data-turbo-method='delete']",
                      destroy_user_session_path(returnto: app_home_path), text: "Logout"
      end
    end

    test "the queue badge counts only active imports" do
      @user.import_requests.create!(youtube_url: @medium.url, youtube_video_id: "kJQP7kiw5Fk",
                                    clip_language: "Spanish", translation_language: "English",
                                    status: :importing, progress_percent: 68)
      @user.import_requests.create!(youtube_url: "https://www.youtube.com/watch?v=aaaaaaaaaaa",
                                    youtube_video_id: "aaaaaaaaaaa",
                                    clip_language: "Spanish", translation_language: "English",
                                    status: :ready)

      get "/app", headers: NATIVE

      assert_response :success
      assert_equal 1, controller.view_assigns["queue_badge_count"]
    end

    # Every card state has its own markup and its own route helpers. Rendering
    # only the happy ones is how `app_retry_import_request_path` (which doesn't
    # exist — it's retry_app_import_request_path) shipped past a green suite.
    test "the queue renders every state" do
      %w[queued importing ready failed canceled].each_with_index do |status, i|
        @user.import_requests.create!(
          youtube_url: "https://www.youtube.com/watch?v=vid#{i}aaaaaaa",
          youtube_video_id: "vid#{i}aaaaaaa",
          clip_language: "Spanish", translation_language: "English",
          title: "Import #{status}", status: status, progress_percent: (status == "importing" ? 68 : 0),
          failure_reason: (status == "failed" ? "Transcription only covered 12% of the video" : nil),
          charged: true, refunded: status == "failed"
        )
      end

      get "/app/import_requests", headers: NATIVE

      assert_response :success
      assert_match "Importing · 68%", response.body
      assert_match "Queued — up next", response.body
      assert_match "Ready — waiting on Home", response.body
      assert_match "Import failed — credit refunded", response.body
      assert_match "Cancelled", response.body
    end

    test "a failed import offers a retry and a queued one offers a cancel" do
      failed = @user.import_requests.create!(
        youtube_url: "https://www.youtube.com/watch?v=failedaaaaa", youtube_video_id: "failedaaaaa",
        clip_language: "Spanish", translation_language: "English", title: "Broken",
        status: :failed, charged: true, refunded: true
      )
      queued = @user.import_requests.create!(
        youtube_url: "https://www.youtube.com/watch?v=queuedaaaaa", youtube_video_id: "queuedaaaaa",
        clip_language: "Spanish", translation_language: "English", title: "Waiting",
        status: :queued, charged: true
      )

      get "/app/import_requests", headers: NATIVE

      assert_response :success
      assert_select "form[action=?]", retry_app_import_request_path(failed)
      assert_select "form[action=?]", app_import_request_path(queued)
    end

    test "cancelling a queued import refunds the credit" do
      queued = @user.import_requests.create!(
        youtube_url: "https://www.youtube.com/watch?v=cancelaaaaa", youtube_video_id: "cancelaaaaa",
        clip_language: "Spanish", translation_language: "English", title: "Waiting",
        status: :queued, charged: true
      )
      Credits::Ledger.spend!(user: @user, subject: queued, idempotency_key: "import:#{queued.id}")
      assert_equal 2, @user.reload.credit_balance

      delete app_import_request_path(queued), headers: NATIVE

      assert_redirected_to app_import_requests_path
      assert queued.reload.canceled?
      assert queued.refunded?
      assert_equal 3, @user.reload.credit_balance
    end

    test "an import that has already started cannot be cancelled" do
      importing = @user.import_requests.create!(
        youtube_url: "https://www.youtube.com/watch?v=runningaaaa", youtube_video_id: "runningaaaa",
        clip_language: "Spanish", translation_language: "English", title: "Running",
        status: :importing, charged: true
      )

      delete app_import_request_path(importing), headers: NATIVE

      assert importing.reload.importing?
      assert_not importing.refunded?
    end

    test "the Library only lists courses in the language being learned" do
      french = languages(:french)
      other_medium = Medium.create!(url: "https://www.youtube.com/watch?v=bbbbbbbbbbb",
                                    language: french, translation_language: @english)
      Course.create!(name: "Bonjour", slug: "bonjour-x", main_media_url: other_medium.url,
                     youtube_video_id: "bbbbbbbbbbb", language: french,
                     translation_language: @english, user: @user, status: :published)

      get "/app/library?lang=es", headers: NATIVE

      assert_response :success
      assert_match "Despacito", response.body
      assert_no_match "Bonjour", response.body
    end

    test "the Library search accepts a pasted link" do
      get "/app/library", params: { q: "https://youtu.be/kJQP7kiw5Fk" }, headers: NATIVE

      assert_response :success
      assert_match "Despacito", response.body
    end

    test "out of credits says so rather than offering a button that does nothing" do
      User.where(id: @user.id).update_all(credit_balance: 0)

      get "/app/credits", headers: NATIVE

      assert_response :success
      assert_match "out of credits", response.body
      # StoreKit is deferred — there must be no purchase controls anywhere.
      assert_no_match(/Get 15 credits|Restore purchases|\$\d/, response.body)
    end
  end
end
