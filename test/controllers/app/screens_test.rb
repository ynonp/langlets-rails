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
      "Create" => "/app/import_requests/new"
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
      publish_covering_the_credit(attributes.fetch(:user).provision_default_channel!, course)
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

    test "a web browser can open Add Video" do
      get "/app/import_requests/new", headers: WEB
      assert_response :success
    end

    # Individual credits are not sold any more, so the sheet that sold them is
    # gone rather than merely emptied. Its callers all point at the Pro paywall.
    test "the credits screen no longer exists" do
      get "/app/credits", headers: NATIVE

      assert_response :not_found
    end

    test "the web Create tab opens Add Video instead of a dedicated queue" do
      request = @user.import_requests.create!(
        youtube_url: "https://www.youtube.com/watch?v=webqueueaaa", youtube_video_id: "webqueueaaa",
        clip_language: "Spanish", translation_language: "English",
        title: "Responsive queue item with a production-length title that must never widen the desktop grid " * 3,
        status: :queued
      )

      get new_app_import_request_path, headers: WEB

      assert_response :success
      assert_select "[data-testid='web-add-video']"
      assert_select "[data-import-request-status]", count: 0
      assert_select "nav a[href=?][aria-current=page]", new_app_import_request_path, text: "Create"
    end

    test "native Library uses the same filters and course-shaped progress cards" do
      @user.import_requests.create!(
        youtube_url: "https://www.youtube.com/watch?v=nativelib01", youtube_video_id: "nativelib01",
        clip_language: "Spanish", translation_language: "English",
        title: "Native Library Import", status: :queued
      )

      get app_library_path, headers: NATIVE

      assert_response :success
      assert_select "a[href=?]", app_library_path(filter: "pending"), text: "Pending"
      assert_select "a[href=?]", app_library_path(filter: "my_imports"), text: "My imports"
      assert_select "a", text: "Failed", count: 0
      assert_select "[data-import-request-status=queued]", text: /Native Library Import/
      assert_select "[style='width: 0%']"
    end

    test "the Library hides import status pills with no matching requests" do
      get app_library_path, headers: NATIVE

      assert_response :success
      assert_select "a", text: "Pending", count: 0
      assert_select "a", text: "Failed", count: 0
      assert_select "a", text: "My imports", count: 0

      get app_library_path(filter: "failed"), headers: NATIVE

      assert_response :success
      assert_select "a[aria-current=page]", text: "All"
      assert_select "a", text: "Failed", count: 0
    end

    test "the native Create tab directly renders the Add a video form" do
      @user.update!(credit_balance: 7)

      get new_app_import_request_path, headers: NATIVE

      assert_response :success
      assert_select "h1", text: "Add a video"
      assert_select ".app-scroll-pad[data-controller='add-video']"
      assert_select "input[data-add-video-target=input]"
      assert_match "7 credits left", response.body
      assert_match "share a YouTube or TikTok video directly to Langlets", response.body
      assert_select "#queue", count: 0
      assert_select "a[href=?]", new_app_import_request_path, text: /Add New/, count: 0
    end

    # The balance lives on the tab that spends it. Home is for what the user
    # already has, so its header is the wordmark and the avatar, nothing else.
    test "Home does not show a credits pill" do
      get "/app", headers: NATIVE

      assert_response :success
      assert_select "[data-testid='app-profile-menu']"
      assert_select "#credits-pill", count: 0
    end

    test "Library no longer floats an add button" do
      get "/app/library", headers: NATIVE

      assert_response :success
      assert_select ".app-fab-offset", count: 0
    end

    test "other app screens remain native-only" do
      (SCREENS.values - [ "/app/import_requests/new" ]).each do |path|
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

    test "signed-out app screens require sign in but onboarding is public" do
      sign_out @user

      get "/app", headers: NATIVE
      assert_redirected_to new_user_session_path(returnto: "/app")

      get onboarding_welcome_path, headers: NATIVE
      assert_response :success
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
      assert_select "a[href=?]", onboarding_video_path

      get onboarding_language_path(returnto: "/app"), headers: NATIVE
      assert_response :success
      assert_select "button[data-bridge--language-selection-redirect-url-value='/app?lang=es']"

      get "/app?lang=es", headers: NATIVE
      assert_response :success
    end

    # The `languages` table holds every language the platform knows about,
    # including translation-only ones (English, Hebrew) and any that still carry
    # legacy courses. Onboarding offers a much shorter list.
    test "onboarding offers only the languages we teach" do
      @user.update!(ios_lang: nil)
      reset!
      sign_in @user

      get onboarding_language_path(returnto: "/app"), headers: NATIVE
      assert_response :success

      offered = css_select("button[data-bridge--language-selection-iso-value]")
        .map { |button| button["data-bridge--language-selection-iso-value"] }
      assert_equal %w[ar-JO fr es], offered
    end

    test "onboarding language screen asks for a target language" do
      @user.update!(ios_lang: nil)
      reset!
      sign_in @user

      get onboarding_language_path(returnto: "/app"), headers: NATIVE
      assert_select "h1", text: "Choose target language"
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
      assert_select "a[data-testid='first-run-create'][href=?]", new_app_import_request_path
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
      assert_select "a[data-testid='first-run-create'][href=?]", new_app_import_request_path
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

    test "public courses stay out of Library but appear on Home after enrollment" do
      owner = User.create!(email: "unlisted-owner@example.com", password: "password123", confirmed_at: Time.zone.now)
      public_course = Course.create!(
        name: "Unlisted Public Video", slug: "unlisted-public-video",
        main_media_url: "https://www.youtube.com/watch?v=unlistedpub",
        youtube_video_id: "unlistedpub", language: @spanish, user: owner, status: :published
      )
      public_channel = owner.default_channel
      public_channel.update!(visibility: :public)
      publish_covering_the_credit(public_channel, public_course)
      Lesson.create!(course: public_course, user: owner, name: "Public lesson", slug: "public-lesson", order: 0)

      get app_library_path, headers: NATIVE
      assert_response :success
      assert_no_match "Unlisted Public Video", response.body

      Enrollment.create!(user: @user, course: public_course, source: :library, last_practiced_at: 1.minute.ago)
      get app_home_path, headers: NATIVE
      assert_response :success
      assert_match "Unlisted Public Video", response.body
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

    # The Pro row is a block notice, not a standing advertisement: it only has
    # something true to say once the account cannot import at all.
    test "Home hides the Pro upsell while the user still has credits" do
      @user.update!(credit_balance: 900)

      get "/app", headers: NATIVE

      assert_response :success
      assert_select "[data-testid='pro-upsell']", count: 0
    end

    test "Home shows the Pro upsell with a clear CTA at zero credits" do
      @user.update!(credit_balance: 0)

      get "/app", headers: NATIVE

      assert_response :success
      assert_select "a[data-testid='pro-upsell'][href=?]", app_pro_path do
        assert_select "p", text: "Upgrade to Pro to import more content"
        assert_select "span", text: "Upgrade to Pro"
      end
      # The keys used to sit under `home.index` while the partial looked them up
      # lazily, which rendered Rails' humanised key names instead.
      assert_no_match "translation missing", response.body
    end

    test "Home shows the subscribed row instead of the upsell for Pro users" do
      @user.update!(credit_balance: 0)
      Subscription.create!(user: @user,
                           product_id: Apple::SubscriptionPlans.yearly.product_id,
                           plan: :yearly, status: :active,
                           original_transaction_id: "2000000333333333",
                           purchased_at: Time.zone.now, expires_at: 1.year.from_now)

      get "/app", headers: NATIVE

      assert_response :success
      assert_select "[data-testid='pro-upsell']", count: 0
      assert_match "Langlets Pro", response.body
      assert_match "ACTIVE", response.body
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

    # A tab root has no back arrow, so the avatar is the only way off it to
    # Notifications, Profile or Sign out. Library and Create shipped without one
    # because the menu lived inside a header only Home rendered; both were dead
    # ends. One shared header on every root is what keeps that from recurring.
    test "all three tab roots carry the profile menu" do
      [ app_home_path, app_library_path, new_app_import_request_path ].each do |path|
        get path, headers: NATIVE

        assert_response :success
        assert_select "details[data-testid='app-profile-menu'][data-controller='profile-menu']",
                      count: 1, message: "#{path} is missing the profile menu"
        assert_select "a[href=?]", profile_path, count: 1
      end
    end

    # The header's `title:` decides its left-hand side and nothing else: a screen
    # that names itself gets its own <h1>, and only Home — which has no title,
    # because the brand is its title — falls back to the wordmark. Never both.
    test "the shared header shows the wordmark only where a screen has no title" do
      get app_home_path, headers: NATIVE
      assert_response :success
      assert_select "span", text: "langlets.", count: 1

      { app_library_path => "Library", new_app_import_request_path => "Add a video" }.each do |path, title|
        get path, headers: NATIVE

        assert_response :success
        assert_select "h1", text: title
        assert_select "span", text: "langlets.", count: 0,
                      message: "#{path} names itself; it should not also carry the wordmark"
      end
    end

    test "all three tabs invite vocabulary review until today's language review is completed" do
      phrase = create_translated_phrase!(medium: @medium, l1: @spanish, l2: @english,
                              text_l1: "Hola", text_l2: "Hello", timestamp: "00:00:01")
      token = create_translated_token!(phrase: phrase, l1_start_index: 0, l1_end_index: 3,
                                       index_type: :character_index, translation: "Hello")
      @user.saved_phrase_tokens << token

      [app_home_path, app_library_path, new_app_import_request_path].each do |path|
        get path, headers: NATIVE
        assert_response :success
        assert_select "[data-testid='daily-vocab-banner']", count: 1
      end

      review = ReviewLessonBuilder.new(@user, language_code: @spanish.iso_name).build!
      LessonUser.create!(user: @user, lesson: review)

      [app_home_path, app_library_path, new_app_import_request_path].each do |path|
        get path, headers: NATIVE
        assert_response :success
        assert_select "[data-testid='daily-vocab-banner']", count: 0
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

    # Cancelling costs nothing and gives nothing back, because a queued import
    # has not been paid for yet — the credit moves when the course is published
    # into the user's channel, which a cancelled import never reaches.
    test "cancelling a queued import leaves the balance alone" do
      queued = @user.import_requests.create!(
        youtube_url: "https://www.youtube.com/watch?v=cancelaaaaa", youtube_video_id: "cancelaaaaa",
        clip_language: "Spanish", translation_language: "English", title: "Waiting",
        status: :queued
      )
      before = @user.reload.credit_balance

      delete app_import_request_path(queued), headers: NATIVE

      assert_redirected_to new_app_import_request_path
      assert queued.reload.canceled?
      assert_equal before, @user.reload.credit_balance
      assert_equal 0, @user.credit_ledger_entries.import_refund.count
    end

    test "an import that has already started cannot be cancelled" do
      importing = @user.import_requests.create!(
        youtube_url: "https://www.youtube.com/watch?v=runningaaaa", youtube_video_id: "runningaaaa",
        clip_language: "Spanish", translation_language: "English", title: "Running",
        status: :importing
      )

      delete app_import_request_path(importing), headers: NATIVE

      assert importing.reload.importing?
    end

    test "the Library derives language pills from visible courses and filters by them" do
      french = languages(:french)
      other_medium = Medium.create!(url: "https://www.youtube.com/watch?v=bbbbbbbbbbb",
                                    language: french)
      create_translated_course!(name: "Bonjour", slug: "bonjour-x", main_media_url: other_medium.url,
                     youtube_video_id: "bbbbbbbbbbb", language: french,
                     translation_language: @english, user: @user, status: :published)

      get app_library_path, headers: NATIVE

      assert_response :success
      assert_match "Despacito", response.body
      assert_match "Bonjour", response.body
      assert_select "turbo-frame#library-results"
      assert_select "a[href*='language=es'][data-turbo-frame='library-results']", text: /Spanish/
      assert_select "a[href*='language=fr'][data-turbo-frame='library-results']", text: /French/
      assert_select "form[data-turbo-frame='library-results']"

      get app_library_path(language: french.iso_name), headers: NATIVE

      assert_response :success
      assert_match "Bonjour", response.body
      assert_no_match "Despacito", response.body
      assert_select "a[aria-current=page]", text: /French/
    end

    test "the Library offers Playlists only when the user has one" do
      get app_library_path, headers: NATIVE
      assert_select "a", text: "Playlists", count: 0

      playlist = Playlist.create!(name: "Mobile Favorites", slug: "mobile-favorites", user: @user)
      playlist.courses << @course

      get app_library_path, headers: NATIVE
      assert_select "a[href*='filter=playlists']", text: "Playlists"

      get app_library_path(filter: "playlists"), headers: NATIVE
      assert_response :success
      assert_select "a[href=?][data-turbo-frame=_top]", playlist_path(playlist), text: /Mobile Favorites/
      assert_select ".grid.grid-cols-2", count: 0
    end

    # Course (and channel) cards live inside <turbo-frame id="library-results">.
    # Without data-turbo-frame="_top" a tap is captured by that frame, Turbo
    # fetches CoursesController#show looking for a matching #library-results
    # frame in the response, finds none, and the native app renders "Content
    # missing" instead of navigating to the course.
    test "the Library course cards break out of the results frame" do
      get app_library_path, headers: NATIVE

      assert_response :success
      assert_select "turbo-frame#library-results a[href=?][data-turbo-frame=_top]", course_path(@course)
      assert_select "turbo-frame#library-results a[href^='/channels/']", count: 0
      assert_no_match @user.default_channel.name, response.body
    end

    test "the Library search accepts a pasted link" do
      get "/app/library", params: { q: "https://youtu.be/kJQP7kiw5Fk" }, headers: NATIVE

      assert_response :success
      assert_match "Despacito", response.body
    end
  end
end
