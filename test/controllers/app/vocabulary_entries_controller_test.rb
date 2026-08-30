require "test_helper"

module App
  # The Vocabulary tab: listing saved words, editing what one means in its
  # phrase, pausing it out of reviews, deleting it, and typing a new one in.
  class VocabularyEntriesControllerTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers

    NATIVE = { "User-Agent" => "LangletsNative" }.freeze
    WEB = { "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" }.freeze

    setup do
      @user = User.create!(email: "vocab@example.com", password: "password123", confirmed_at: Time.zone.now)
      @spanish = languages(:spanish)
      @french = languages(:french)
      @english = languages(:english)
      # Created before signing in: Devise's test sign_in only takes effect on
      # the next request, and creating a second user between the two loses it.
      @other = User.create!(email: "other@example.com", password: "password123", confirmed_at: Time.zone.now)
      sign_in @user
    end

    # Builds a saved word: a phrase, a span inside it, what the span means, and
    # this user's claim on it.
    def save_word(text:, span:, translation:, language: @spanish, source_name: nil, practicing: true, owner: nil)
      medium = Medium.find_or_create_by!(url: "https://www.youtube.com/watch?v=#{language.iso_name}#{text.hash.abs}",
                                         language: language)
      phrase = Phrase.create!(medium: medium, l1: language, text_l1: text)
      token = phrase.phrase_tokens.create!(l1_start_index: span.first, l1_end_index: span.last,
                                           index_type: :character_index)
      token.token_translations.create!(language: @english, translation: translation)

      if source_name
        course = Course.create!(name: source_name, slug: "c-#{source_name.parameterize}-#{phrase.id}",
                                user: @user, language: language, main_media_url: medium.url)
        Lesson.create!(course: course, medium: medium, user: @user, slug: "l#{phrase.id}", name: "L", order: 0)
      end

      (owner || @user).phrase_token_users.create!(phrase_token: token, language: @english, practicing: practicing)
    end

    test "the empty state offers adding a word and nothing else" do
      get "/app/vocabulary", headers: NATIVE

      assert_response :success
      assert_select "[data-testid=vocabulary-empty]"
      assert_select "[data-testid=vocabulary-entry]", false
    end

    test "the list shows each word inside its phrase with the saved span marked" do
      save_word(text: "no queda tiempo", span: [ 9, 14 ], translation: "time", source_name: "Despacito")

      get "/app/vocabulary", headers: NATIVE

      assert_response :success
      assert_select "[data-testid=vocabulary-entry]", 1
      assert_select "[data-testid=vocabulary-entry]" do
        assert_select "p", text: "tiempo"
        # The span is highlighted in place rather than repeated on its own.
        assert_select "span.text-app-accent", text: "tiempo"
      end
      assert_match "Despacito", response.body
    end

    test "the language filter narrows the list to that language" do
      save_word(text: "no queda tiempo", span: [ 9, 14 ], translation: "time")
      save_word(text: "elle est folle", span: [ 9, 13 ], translation: "crazy", language: @french)

      get "/app/vocabulary", params: { filter: "fr" }, headers: NATIVE

      assert_select "[data-testid=vocabulary-entry]", 1
      assert_match "folle", response.body
      assert_no_match(/tiempo/, response.body)
    end

    test "search matches the word, its translation and its phrase" do
      save_word(text: "no queda tiempo", span: [ 9, 14 ], translation: "time")
      save_word(text: "elle est folle", span: [ 9, 13 ], translation: "crazy", language: @french)

      get "/app/vocabulary", params: { q: "queda" }, headers: NATIVE

      assert_select "[data-testid=vocabulary-entry]", 1
      assert_match "tiempo", response.body
    end

    test "the not-practising filter is offered only once something is paused" do
      save_word(text: "no queda tiempo", span: [ 9, 14 ], translation: "time")

      get "/app/vocabulary", headers: NATIVE
      assert_no_match(/Not practising/, response.body)

      save_word(text: "elle est folle", span: [ 9, 13 ], translation: "crazy",
                language: @french, practicing: false)

      get "/app/vocabulary", headers: NATIVE
      assert_match "Not practising", response.body

      get "/app/vocabulary", params: { filter: "paused" }, headers: NATIVE
      assert_select "[data-testid=vocabulary-entry]", 1
      assert_match "folle", response.body
    end

    test "editing saves the translation of that span only" do
      saved = save_word(text: "no queda tiempo", span: [ 9, 14 ], translation: "time")

      patch "/app/vocabulary/#{saved.id}", params: { translation: "weather" }, headers: NATIVE

      assert_redirected_to "/app/vocabulary"
      assert_equal "weather", saved.reload.token_translation.translation
      assert_equal "Translation saved", flash[:notice]
    end

    test "pausing a word keeps it listed but takes it out of reviews" do
      saved = save_word(text: "no queda tiempo", span: [ 9, 14 ], translation: "time")

      patch "/app/vocabulary/#{saved.id}", params: { practicing: "false" }, headers: NATIVE

      assert_not saved.reload.practicing?
      assert_equal "Stopped practising — word kept in your list", flash[:notice]

      get "/app/vocabulary", headers: NATIVE
      assert_select "[data-testid=vocabulary-entry]", 1
      assert_match "Paused", response.body

      assert_empty ReviewLessonBuilder.new(@user, language_code: @spanish.iso_name).fetch_tokens
    end

    test "resuming practice puts the word back into reviews" do
      saved = save_word(text: "no queda tiempo", span: [ 9, 14 ], translation: "time", practicing: false)

      patch "/app/vocabulary/#{saved.id}", params: { practicing: "true" }, headers: NATIVE

      assert saved.reload.practicing?
      assert_equal "Practice resumed", flash[:notice]
      assert_equal 1, ReviewLessonBuilder.new(@user, language_code: @spanish.iso_name).fetch_tokens.size
    end

    test "the native practice switch updates through a Turbo Stream without saving the translation" do
      saved = save_word(text: "no queda tiempo", span: [ 9, 14 ], translation: "time")

      patch "/app/vocabulary/#{saved.id}",
            params: { practicing: "false", translation: "unsaved edit" },
            headers: NATIVE.merge("Accept" => "text/vnd.turbo-stream.html")

      assert_response :success
      assert_equal "text/vnd.turbo-stream.html", response.media_type
      assert_not saved.reload.practicing?
      assert_equal "time", saved.token_translation.translation
      assert_select "turbo-stream[action=replace][target=?]", dom_id(saved, :practice) do
        assert_select "button[name=practicing][value=true][aria-pressed=false]"
        assert_select "p, span", text: /skipped in reviews/i
      end
    end

    test "deleting detaches the word and leaves an undo behind that restores it" do
      saved = save_word(text: "no queda tiempo", span: [ 9, 14 ], translation: "time")
      token_id = saved.phrase_token_id

      delete "/app/vocabulary/#{saved.id}", headers: NATIVE

      assert_redirected_to "/app/vocabulary"
      assert_equal 0, @user.phrase_token_users.count
      assert_equal "“tiempo” deleted", flash[:notice]
      assert_equal token_id, flash[:undo]["phrase_token_id"]
      # The phrase and token survive — for a shared course word they were never
      # this user's to destroy, and it is what makes undo a plain re-save.
      assert PhraseToken.exists?(token_id)

      post "/app/vocabulary/restore",
           params: { phrase_token_id: token_id, language_id: @english.id }, headers: NATIVE

      assert_equal 1, @user.phrase_token_users.count
      assert_equal "tiempo", @user.phrase_token_users.first.word
    end

    # Every action scopes through current_user.phrase_token_users, so another
    # user's word raises RecordNotFound before any of them can touch it — which
    # is a 404 in production. Asserted on the outcome rather than the status
    # code, because this app's test environment renders the debug exception
    # page instead, and what matters is that nothing renders and nothing moves.
    test "a word saved by another user is neither readable nor changeable" do
      saved = save_word(text: "no queda tiempo", span: [ 9, 14 ], translation: "time", owner: @other)

      get "/app/vocabulary/#{saved.id}", headers: NATIVE
      assert_not response.successful?, "another user's word must never render"
      assert_select "[data-testid=vocabulary-detail-form]", false

      patch "/app/vocabulary/#{saved.id}", params: { translation: "hijacked" }, headers: NATIVE
      assert_equal "time", saved.reload.token_translation.translation

      delete "/app/vocabulary/#{saved.id}", headers: NATIVE
      assert PhraseTokenUser.exists?(saved.id), "another user's word must survive"
    end

    test "adding a custom word stores it as a span inside the phrase the user typed" do
      save_word(text: "no queda tiempo", span: [ 9, 14 ], translation: "time")
      Current.translation_language = @english

      assert_difference -> { @user.phrase_token_users.count }, 1 do
        post "/app/vocabulary", headers: NATIVE, params: {
          sentence: "No queda tiempo — rápido, gira a la izquierda",
          language: @spanish.iso_name, token_start: 8, token_end: 8,
          translation: "left", word: "izquierda"
        }
      end

      assert_redirected_to "/app/vocabulary"
      entry = @user.phrase_token_users.order(:id).last
      assert_equal "izquierda", entry.word
      assert_equal "left", entry.translation
      assert_equal "No queda tiempo — rápido, gira a la izquierda", entry.context
      assert_equal "Added by you", entry.source
    end

    test "adding a compound keeps the whole span as one entry" do
      Current.translation_language = @english

      post "/app/vocabulary", headers: NATIVE, params: {
        sentence: "hay que darse prisa", language: @spanish.iso_name,
        token_start: 2, token_end: 3, translation: "to hurry up", word: "darse prisa"
      }

      entry = @user.phrase_token_users.order(:id).last
      assert_equal "darse prisa", entry.word
      assert_equal "hay que ", entry.before
      assert_equal "darse prisa", entry.mark
    end

    test "adding without a translation re-renders the form and saves nothing" do
      Current.translation_language = @english

      assert_no_difference -> { PhraseTokenUser.count } do
        post "/app/vocabulary", headers: NATIVE, params: {
          sentence: "no queda tiempo", language: @spanish.iso_name,
          token_start: 2, token_end: 2, translation: ""
        }
      end

      assert_response :unprocessable_entity
      assert_select "[data-testid=vocabulary-add-error]", text: I18n.t!(
        "app.vocabulary_entries.new.errors.translation_required"
      )
    end

    test "a malformed selection shows the generic localized save error" do
      Current.translation_language = @english

      assert_no_difference -> { PhraseTokenUser.count } do
        post "/app/vocabulary", headers: NATIVE, params: {
          sentence: "no queda tiempo", language: @spanish.iso_name,
          token_start: 9, token_end: 9, translation: "time"
        }
      end

      assert_response :unprocessable_entity
      assert_select "[data-testid=vocabulary-add-error]", text: I18n.t!(
        "app.vocabulary_entries.new.errors.save_failed"
      )
    end

    test "the add screen renders" do
      get "/app/vocabulary/new", headers: NATIVE

      assert_response :success
      assert_select "title", text: I18n.t!("app.vocabulary_entries.new.page_title")
      assert_select "[data-testid=vocabulary-add-form]"
    end

    # --- The web surface -----------------------------------------------------
    #
    # Separate route and controller identity, shared inherited behavior. These
    # assert the route selects the surface, and that the parts most
    # likely to be forgotten in a second surface — the empty state, the add
    # form, the write actions — come with it.

    test "a browser gets the web templates and the web layout" do
      save_word(text: "no queda tiempo", span: [ 9, 14 ], translation: "time")

      get "/vocabulary", headers: WEB

      assert_response :success
      assert_select "[data-testid=web-vocabulary]"
      assert_select "[data-testid=primary-web-header]"
      assert_select "[data-testid=vocabulary-entry]", 1
      # The native shell must not have quietly followed it over.
      assert_select "[data-native-tabs]", false
    end

    test "the web entry contains long source titles and sentences inside the card" do
      source = "عنوان عربي طويل جداً " * 12
      sentence = "هذه جملة عربية طويلة تحتوي على كلمات كثيرة " * 8
      save_word(text: sentence, span: [ 0, 2 ], translation: "this", source_name: source)

      get "/vocabulary", headers: WEB

      assert_select "[data-testid=vocabulary-entry-source][dir=auto][class*='truncate']", text: source.strip
      assert_select "[data-testid=vocabulary-entry] p[dir=auto][class*='break-words']"
    end

    test "the native app still gets the native templates" do
      save_word(text: "no queda tiempo", span: [ 9, 14 ], translation: "time")

      get "/app/vocabulary", headers: NATIVE

      assert_response :success
      assert_select "[data-testid=web-vocabulary]", false
      assert_select "[data-testid=vocabulary-entry]", 1
    end

    test "the route selects the web surface even for a native user agent" do
      get "/vocabulary", headers: NATIVE
      assert_response :success
      assert_select "[data-testid=web-vocabulary]"
      assert_select "[data-testid=primary-web-header]"
    end

    test "the web Vocabulary page always offers a way back to the site" do
      get "/vocabulary", headers: WEB

      assert_select "[data-testid=primary-web-header] a[href='/']"
    end

    test "the native Vocabulary route remains native-only" do
      get "/app/vocabulary", headers: WEB

      assert_redirected_to root_path
    end

    test "the web header links to Vocabulary and marks it as the current page" do
      get "/vocabulary", headers: WEB

      assert_select "[data-testid=primary-web-header] a[href='/vocabulary'][aria-current=page]"
    end

    test "the web empty state and add form render" do
      get "/vocabulary", headers: WEB
      assert_select "[data-testid=vocabulary-empty]"

      get "/vocabulary/new", headers: WEB
      assert_response :success
      assert_select "[data-testid=vocabulary-add-form]"
    end

    test "the web detail screen renders with its practice switch and delete guard" do
      saved = save_word(text: "no queda tiempo", span: [ 9, 14 ], translation: "time")

      get "/vocabulary/#{saved.id}", headers: WEB

      assert_response :success
      assert_select "[data-testid=vocabulary-practice-toggle]"
      assert_select "[data-testid=vocabulary-delete]"
      assert_select "dialog"
    end

    test "the web practice switch returns the web Turbo Stream partial" do
      saved = save_word(text: "no queda tiempo", span: [ 9, 14 ], translation: "time", practicing: false)

      patch "/vocabulary/#{saved.id}", params: { practicing: "true" },
            headers: WEB.merge("Accept" => "text/vnd.turbo-stream.html")

      assert_response :success
      assert saved.reload.practicing?
      assert_select "turbo-stream[action=replace][target=?]", dom_id(saved, :practice) do
        assert_select "button[name=practicing][value=false][aria-pressed=true]"
        assert_select "span[class*='bg-[#0F6E56]']"
      end
    end

    test "editing, pausing and deleting all work from the web surface" do
      saved = save_word(text: "no queda tiempo", span: [ 9, 14 ], translation: "time")

      patch "/vocabulary/#{saved.id}", params: { translation: "weather" }, headers: WEB
      assert_redirected_to "/vocabulary"
      assert_equal "weather", saved.reload.token_translation.translation

      patch "/vocabulary/#{saved.id}", params: { practicing: "false" }, headers: WEB
      assert_not saved.reload.practicing?

      delete "/vocabulary/#{saved.id}", headers: WEB
      assert_equal 0, @user.phrase_token_users.count
    end

    test "adding a custom word works from the web surface" do
      Current.translation_language = @english

      assert_difference -> { @user.phrase_token_users.count }, 1 do
        post "/vocabulary", headers: WEB, params: {
          sentence: "no queda tiempo", language: @spanish.iso_name,
          token_start: 2, token_end: 2, translation: "time", word: "tiempo"
        }
      end

      assert_redirected_to "/vocabulary"
      assert_equal "tiempo", @user.phrase_token_users.last.word
    end

    test "a failed web add re-renders the web form rather than the native one" do
      Current.translation_language = @english

      post "/vocabulary", headers: WEB, params: {
        sentence: "no queda tiempo", language: @spanish.iso_name,
        token_start: 2, token_end: 2, translation: ""
      }

      assert_response :unprocessable_entity
      assert_select "[data-testid=vocabulary-add-error]"
      assert_select "[data-testid=primary-web-header]"
    end

    test "the detail screen renders with its practice switch and delete guard" do
      saved = save_word(text: "no queda tiempo", span: [ 9, 14 ], translation: "time")

      get "/app/vocabulary/#{saved.id}", headers: NATIVE

      assert_response :success
      assert_select "[data-testid=vocabulary-practice-toggle]"
      assert_select "[data-testid=vocabulary-delete]"
      assert_select "dialog"
    end
  end
end
