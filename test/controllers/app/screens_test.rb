require "test_helper"

module App
  # Smoke coverage for the mobile app screens and their web access rules.
  class ScreensTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers

    NATIVE = { "User-Agent" => "LangletsNative" }.freeze
    WEB = { "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" }.freeze

    SCREENS = {
      "Home" => "/app",
      "Started videos" => "/app/started_courses",
      "Library" => "/app/library",
      "Create" => "/app/import_requests",
      "Add a video" => "/app/import_requests/new",
      "Credits" => "/app/credits"
    }.freeze

    setup do
      @user = User.create!(email: "screens@example.com", password: "password123", confirmed_at: Time.zone.now)
      @spanish = languages(:spanish)
      @english = languages(:english)
      @medium = Medium.create!(url: "https://www.youtube.com/watch?v=kJQP7kiw5Fk",
                               language: @spanish)
      @course = create_translated_course!(name: "Despacito", slug: "despacito-x", main_media_url: @medium.url,
                               youtube_video_id: "kJQP7kiw5Fk", language: @spanish,
                               translation_language: @english, user: @user, status: :published)
      @user.provision_default_channel!.publish!(@course)
      Lesson.create!(course: @course, medium: @medium, user: @user, slug: "l1", name: "L1", order: 0)
      Enrollment.create!(user: @user, course: @course, source: :imported, last_practiced_at: 1.hour.ago)
      sign_in @user

      # ApplicationController#require_language_for_native_app sends native users
      # to /onboarding/language until they've chosen one, so every app screen is
      # unreachable without it. One request stores the language on the user.
      get "/app?lang=es", headers: NATIVE
    end

    # Screen fixtures represent content already contributed to the signed-in
    # user's Channel; Course creator ownership alone is no longer Library
    # authority.
    def create_translated_course!(**attributes)
      course = super
      attributes.fetch(:user).provision_default_channel!.publish!(course)
      course
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

    test "a web browser can open Queue and Add Video" do
      [ "/app/import_requests", "/app/import_requests/new" ].each do |path|
        get path, headers: WEB
        assert_response :success, "#{path} should be shared with the web app"
      end
    end

    test "a web browser cannot open native Credits" do
      get "/app/credits", headers: WEB

      assert_redirected_to root_path
    end

    test "the web queue uses its own responsive application view" do
      request = @user.import_requests.create!(
        youtube_url: "https://www.youtube.com/watch?v=webqueueaaa", youtube_video_id: "webqueueaaa",
        clip_language: "Spanish", translation_language: "English",
        title: "Responsive queue item with a production-length title that must never widen the desktop grid " * 3,
        status: :queued, charged: true
      )

      get app_import_requests_path, headers: WEB

      assert_response :success
      assert_select "html[data-theme]"
      assert_select "meta[name='view-transition'][content='same-origin']", count: 1
      assert_select "header a[href=?]", root_path, text: /Langlets/
      assert_select "[data-testid='web-queue'].max-w-5xl"
      assert_select "#queue.min-w-0.w-full"
      assert_select "#queue-list.min-w-0.w-full"
      assert_select "article#wrapper_import_request_#{request.id}.min-w-0.w-full" do
        assert_select ".sm\\:flex-row"
        assert_select "form[action=?]", app_import_request_path(request)
      end
      assert_select "[data-controller='swipe-to-delete']", count: 0
      assert_select "a[href=?]", new_app_import_request_path, text: /Add a video/
    end

    test "the native queue keeps the native-only presentation" do
      @user.import_requests.create!(
        youtube_url: "https://www.youtube.com/watch?v=nativequeuea", youtube_video_id: "nativequeuea",
        clip_language: "Spanish", translation_language: "English", title: "Native queue item",
        status: :ready
      )

      get app_import_requests_path, headers: NATIVE

      assert_response :success
      assert_select "body[data-native-tabs]"
      assert_select "[data-controller='swipe-to-delete']"
      assert_select "[data-testid='web-queue']", count: 0
    end

    # The native screen is "Create": the user's own langlets, then one Add New
    # button in the flow. The web queue keeps its own wording.
    test "Create lists the user's langlets above an Add New button" do
      @user.import_requests.create!(
        youtube_url: "https://www.youtube.com/watch?v=createdaaaa", youtube_video_id: "createdaaaa",
        clip_language: "Spanish", translation_language: "English", title: "Created langlet",
        status: :ready
      )

      get app_import_requests_path, headers: NATIVE

      assert_response :success
      assert_select "h1", text: "Create"
      assert_select "h2", text: "My Created Langlets"
      assert_match "Created langlet", response.body
      assert_select "a[href=?]", new_app_import_request_path, text: /Add New/
      assert_select ".app-fab-offset", count: 0
    end

    # The intro is the only place either entry point is named, and the corner
    # pill is the only place the balance shows on this tab — the tab roots get no
    # app header, so the header's credits pill isn't here to carry it. The pill
    # shows the digit alone, so the wording has to survive in its aria-label.
    test "Create explains both entry points and pills the balance to Credits" do
      @user.update!(credit_balance: 7)

      get app_import_requests_path, headers: NATIVE

      assert_response :success
      assert_match "sharing a YouTube or TikTok video to the app", response.body
      assert_match "costs 1 credit", response.body
      assert_select "a#credits-pill[href=?][aria-label=?]",
                    app_credits_path,
                    "Credits remaining: 7. Tap to add more"
      assert_select "a#credits-pill", text: /7/
    end

    # Spending happens in the pushed Add Video screen, so the poll refreshes the
    # balance along with the queue rather than leaving it a credit high.
    test "the queue poll patches the credits pill" do
      @user.update!(credit_balance: 3)
      @user.import_requests.create!(
        youtube_url: "https://www.youtube.com/watch?v=pollcreditx", youtube_video_id: "pollcreditx",
        clip_language: "Spanish", translation_language: "English", title: "In flight",
        status: :queued, charged: true
      )

      get app_import_requests_path, headers: NATIVE, as: :turbo_stream

      assert_response :success
      assert_match "turbo-stream", response.media_type
      assert_select "turbo-stream[action='replace'][target='credits-pill']"
      assert_match "Credits remaining: 3. Tap to add more", response.body
    end

    test "Create with nothing created says so and still offers Add New" do
      get app_import_requests_path, headers: NATIVE

      assert_response :success
      assert_select "#queue-empty", text: /You haven't created any langlets yet/
      assert_select "a[href=?]", new_app_import_request_path, text: /Add New/
    end

    # The balance lives on the tab that spends it. Home is for what the user
    # already has, so its header is the wordmark and the avatar, nothing else.
    test "Home does not show a credits pill" do
      get "/app", headers: NATIVE

      assert_response :success
      assert_select "[data-testid='app-profile-menu']"
      assert_select "a[href=?]", app_credits_path, count: 0
    end

    test "Library no longer floats an add button" do
      get "/app/library", headers: NATIVE

      assert_response :success
      assert_select ".app-fab-offset", count: 0
    end

    test "other app screens remain native-only" do
      (SCREENS.values - [ "/app/import_requests", "/app/import_requests/new", "/app/credits" ]).each do |path|
        get path, headers: WEB
        assert_redirected_to root_path, "#{path} should be web-gated"
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

      get onboarding_welcome_path, headers: NATIVE
      assert_redirected_to new_user_session_path(returnto: onboarding_welcome_path)
    end

    test "new native users see welcome before language selection and Home" do
      @user.update!(ios_lang: nil)
      reset!
      sign_in @user

      get "/app", headers: NATIVE
      assert_redirected_to onboarding_welcome_path(returnto: "/app")

      get onboarding_welcome_path(returnto: "/app"), headers: NATIVE
      assert_response :success
      assert_select "h1", count: 1
      assert_select "a[href=?]", onboarding_language_path(returnto: "/app")

      get onboarding_language_path(returnto: "/app"), headers: NATIVE
      assert_response :success
      assert_select "button[data-bridge--language-selection-redirect-url-value='/app?lang=es']"

      get "/app?lang=es", headers: NATIVE
      assert_response :success
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

    # "Lesson 16 of 16" with a full bar under "Continue" reads
    # as broken. The web's continue-learning list drops finished courses the same
    # way.
    test "Home drops finished courses from the pick-up-where-you-left-off list" do
      @course.lessons.each { |lesson| LessonUser.create!(lesson: lesson, user: @user) }

      get "/app", headers: NATIVE

      assert_response :success
      assert_no_match(/<h2[^>]*>Continue<\/h2>/, response.body)
    end

    test "Home keeps a part-finished course in the pick-up-where-you-left-off list" do
      second = Lesson.create!(course: @course, medium: @medium, user: @user,
                              slug: "l2", name: "L2", order: 1)
      LessonUser.create!(lesson: @course.lessons.first, user: @user)

      get "/app", headers: NATIVE

      assert_response :success
      assert_match "Continue", response.body
      assert_match "Lesson 2 of 2", response.body
      assert second.persisted?
    end

    test "Home shows the two latest courses with See all below them" do
      older_medium = Medium.create!(url: "https://www.youtube.com/watch?v=oldercourse1",
                                    language: @spanish)
      older_course = create_translated_course!(name: "Older Course", slug: "older-course",
                                    main_media_url: older_medium.url, youtube_video_id: "oldercourse1",
                                    language: @spanish, translation_language: @english,
                                    user: @user, status: :published)
      Lesson.create!(course: older_course, medium: older_medium, user: @user,
                     slug: "older-lesson", name: "Older lesson", order: 0)
      Enrollment.create!(user: @user, course: older_course, source: :library,
                         last_practiced_at: 2.hours.ago)

      latest_medium = Medium.create!(url: "https://www.youtube.com/watch?v=latestcours",
                                     language: @spanish)
      latest_course = create_translated_course!(name: "Latest Course", slug: "latest-course",
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
        assert_select "div:first-child" do
          assert_select "h2", text: "Continue"
          assert_select "a[href=?]", app_started_courses_path, text: "See all", count: 1
        end
        assert_select "a[href=?]", app_started_courses_path, text: "See all", count: 1
        assert_select "a", text: /Latest Course/
        assert_select "a", text: /Despacito/
        assert_select "a", text: /Older Course/, count: 0
      end
    end

    test "Started videos shows every practiced course in recent order" do
      older_medium = Medium.create!(url: "https://www.youtube.com/watch?v=oldercourse1",
                                    language: @spanish)
      older_course = create_translated_course!(name: "Older Course", slug: "older-course",
                                    main_media_url: older_medium.url, youtube_video_id: "oldercourse1",
                                    language: @spanish, translation_language: @english,
                                    user: @user, status: :published)
      older_lesson = Lesson.create!(course: older_course, medium: older_medium, user: @user,
                                    slug: "older-lesson", name: "Older lesson", order: 0)
      older_enrollment = Enrollment.create!(user: @user, course: older_course, source: :library,
                                            last_practiced_at: 2.hours.ago)
      LessonUser.create!(user: @user, lesson: older_lesson)
      older_enrollment.update_column(:last_practiced_at, 2.hours.ago)

      unstarted = create_translated_course!(name: "Not Started", slug: "not-started",
                                 main_media_url: "https://www.youtube.com/watch?v=notstarted1",
                                 youtube_video_id: "notstarted1", language: @spanish,
                                 translation_language: @english, user: @user, status: :published)
      Enrollment.create!(user: @user, course: unstarted, source: :library)

      get "/app/started_courses", headers: NATIVE

      assert_response :success
      assert_select "h1", text: "Started videos"
      assert_match(/Despacito.*Older Course/m, response.body)
      assert_no_match "Not Started", response.body
      assert_select "a[href=?]", course_path(older_course), text: /Older Course/
    end

    # With nothing to continue, Home leads with the library grid (courses in the
    # user's language they aren't enrolled in) — there is no separate first-run
    # picker, and no paste box either: importing lives in the Create tab.
    test "Home with an empty account shows library courses and no paste box" do
      Enrollment.delete_all

      get "/app", headers: NATIVE

      assert_response :success
      assert_no_match "Turn any YouTube video into a Spanish lesson.", response.body
      assert_select "form[action^='/app/import_requests/new']", count: 0
      assert_select "input[name='url']", count: 0
      assert_match "Despacito", response.body
      assert_no_match(/<h2[^>]*>Continue<\/h2>/, response.body)
    end

    # First run: the grid is the whole screen, so it gets an instruction rather
    # than the "Library" section label, and the only other way in gets named.
    test "Home with an empty account instructs and links to Create" do
      Enrollment.delete_all

      get "/app", headers: NATIVE

      assert_response :success
      assert_select "h2", text: "Jump right in"
      assert_select "h2", text: "Library", count: 0
      assert_select "a[data-testid='first-run-create'][href=?]", app_import_requests_path
    end

    # Newest-first, not random: a shelf that reshuffles every visit gives a
    # returning user nothing to recognize.
    test "the library grid shows the newest courses first" do
      Enrollment.delete_all
      %w[oldest middle newest].each_with_index do |name, index|
        create_translated_course!(name: name, slug: "pick-#{name}",
                       main_media_url: "https://www.youtube.com/watch?v=pick#{index}aaaaaa",
                       youtube_video_id: "pick#{index}aaaaaa", language: @spanish,
                       translation_language: @english, user: @user, status: :published)
          .update_column(:created_at, index.days.from_now)
      end

      get "/app", headers: NATIVE

      assert_response :success
      # @course predates all three and takes the last of the four slots.
      assert_match(/newest.*middle.*oldest.*Despacito/m, response.body)
    end

    # Both ways off the library section are accent-coloured, in both states.
    # Enrolled here, so it needs a course to keep the section on screen at all.
    test "the library See all link uses the accent colour" do
      create_translated_course!(name: "Bailando", slug: "bailando-z", main_media_url: "https://www.youtube.com/watch?v=bailandoaaa",
                     youtube_video_id: "bailandoaaa", language: @spanish,
                     translation_language: @english, user: @user, status: :published)

      get "/app", headers: NATIVE

      assert_response :success
      assert_select "a.text-app-accent[href=?]", app_library_path
    end

    # Even with no library courses to show — a language nobody has imported yet —
    # the way into Create is still on screen. That is the blank-Home case.
    test "Home with an empty account links to Create even with an empty library" do
      Enrollment.delete_all
      Course.update_all(status: Course.statuses[:pending])

      get "/app", headers: NATIVE

      assert_response :success
      assert_select ".grid a[href^='/courses/']", count: 0
      assert_select "a[data-testid='first-run-create'][href=?]", app_import_requests_path
    end

    # The whole point of gating it: a returning user never sees the onboarding.
    # Needs a second course so the library grid actually renders — otherwise the
    # heading assertion would pass on an absent section.
    test "Home drops the first-run heading and Create link once enrolled" do
      create_translated_course!(name: "Bailando", slug: "bailando-y", main_media_url: "https://www.youtube.com/watch?v=bailandoaaa",
                     youtube_video_id: "bailandoaaa", language: @spanish,
                     translation_language: @english, user: @user, status: :published)

      get "/app", headers: NATIVE

      assert_response :success
      assert_select "h2", text: "Library"
      assert_select "h2", text: "Jump right in", count: 0
      assert_select "a[data-testid='first-run-create']", count: 0
    end

    test "the library grid only offers courses in the user's language" do
      Enrollment.delete_all
      french = languages(:french)
      create_translated_course!(name: "La Vie en Rose", slug: "la-vie-en-rose", main_media_url: "https://www.youtube.com/watch?v=frenchaaaaa",
                     youtube_video_id: "frenchaaaaa", language: french,
                     translation_language: @english, user: @user, status: :published)

      get "/app", headers: NATIVE

      assert_response :success
      assert_match "Despacito", response.body
      assert_no_match "La Vie en Rose", response.body
    end

    test "Home suggests library courses the user is not enrolled in" do
      create_translated_course!(name: "Bailando", slug: "bailando-x", main_media_url: "https://www.youtube.com/watch?v=bailandoaaa",
                     youtube_video_id: "bailandoaaa", language: @spanish,
                     translation_language: @english, user: @user, status: :published)

      get "/app", headers: NATIVE

      assert_response :success
      assert_match "Continue", response.body
      assert_match "Library", response.body
      assert_match "Bailando", response.body
      assert_no_match "Turn any YouTube video into a Spanish lesson.", response.body
    end

    test "Home uses the main media URL for legacy course thumbnails like the web app" do
      Enrollment.delete_all
      @course.update_column(:youtube_video_id, nil)

      get "/app", headers: NATIVE

      assert_response :success
      assert_select "img[src='https://img.youtube.com/vi/kJQP7kiw5Fk/hqdefault.jpg']"
      assert_no_match %r{img\.youtube\.com/vi//}, response.body
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
      phrase = create_translated_phrase!(medium: @medium, l1: @spanish, l2: @english,
                              text_l1: "Hola", text_l2: "Hello", timestamp: "00:00:01")
      token = create_translated_token!(phrase: phrase, l1_start_index: 0, l1_end_index: 3,
                                       index_type: :character_index, translation: "Hello")
      @user.saved_phrase_tokens << token

      get "/app", headers: NATIVE

      assert_response :success
      assert_select "details[data-testid='app-profile-menu'][data-controller='profile-menu']" do
        assert_select "[data-action='click@document->profile-menu#close']"
        assert_select "summary[aria-label='Open profile menu']", text: "S"
        assert_select "a[href=?][data-action='click->profile-menu#dismiss']", profile_path,
                      text: "Profile"
        assert_select "form[action=?]", review_lessons_path(language_code: @spanish.iso_name) do
          assert_select "button", text: "Practice Words (#{@spanish.iso_name})"
        end
        assert_select "a[href=?][data-turbo-method='delete']",
                      destroy_user_session_path(returnto: app_home_path), text: "Logout"
      end
    end

    test "Home invites vocabulary review until today's language review is completed" do
      phrase = create_translated_phrase!(medium: @medium, l1: @spanish, l2: @english,
                              text_l1: "Hola", text_l2: "Hello", timestamp: "00:00:01")
      token = create_translated_token!(phrase: phrase, l1_start_index: 0, l1_end_index: 3,
                                       index_type: :character_index, translation: "Hello")
      @user.saved_phrase_tokens << token

      get "/app", headers: NATIVE

      assert_response :success
      assert_select "[data-testid='daily-vocab-banner']"

      review = ReviewLessonBuilder.new(@user, language_code: @spanish.iso_name).build!
      LessonUser.create!(user: @user, lesson: review)

      get "/app", headers: NATIVE

      assert_response :success
      assert_select "[data-testid='daily-vocab-banner']", count: 0
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

    # Every card state has its own markup. Render all of them so state-specific
    # actions and guidance stay covered.
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
      assert_match "Ready", response.body
      assert_match "Import failed — credit refunded", response.body
      assert_match "Cancelled", response.body
    end

    test "a failed import explains the review process without retry and a queued one offers a cancel" do
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
      assert_select "form[action=?]", retry_app_import_request_path(failed), count: 0
      assert_select "button[aria-describedby=?]", dom_id(failed, :failed_help)
      assert_select "##{dom_id(failed, :failed_help)}[role='tooltip']", text: /human team is checking/
      assert_select "form[action=?]", app_import_request_path(queued)
    end

    test "the web queue replaces failed import retry with the review tooltip" do
      failed = @user.import_requests.create!(
        youtube_url: "https://www.youtube.com/watch?v=failedwebbb", youtube_video_id: "failedwebbb",
        clip_language: "Spanish", translation_language: "English", title: "Broken",
        status: :failed, charged: true, refunded: true
      )

      get app_import_requests_path, headers: WEB

      assert_response :success
      assert_select "form[action=?]", retry_app_import_request_path(failed), count: 0
      assert_select "button[aria-describedby=?]", dom_id(failed, :failed_help)
      assert_select "##{dom_id(failed, :failed_help)}[role='tooltip']", text: /human team is checking/
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
                                    language: french)
      create_translated_course!(name: "Bonjour", slug: "bonjour-x", main_media_url: other_medium.url,
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

    test "out of credits offers Apple purchases in the native app" do
      User.where(id: @user.id).update_all(credit_balance: 0)

      get "/app/credits", headers: NATIVE

      assert_response :success
      assert_match "out of credits", response.body
      assert_select "[data-controller='bridge--apple-purchase']", count: 1
      assert_no_match "PayPal", response.body
    end
  end
end
