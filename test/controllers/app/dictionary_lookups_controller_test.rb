require "test_helper"

module App
  # The Dictionary on the native Vocabulary tab: choosing (or inferring) the
  # target language, looking something up, polling the card, and saving it.
  class DictionaryLookupsControllerTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include ActiveJob::TestHelper

    NATIVE = { "User-Agent" => "LangletsNative" }.freeze
    WEB = { "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" }.freeze

    setup do
      @user = User.create!(email: "dictionary-ui@example.com", password: "password123", confirmed_at: Time.zone.now,
        preferences: { "native_language" => "he" })
      @other = User.create!(email: "dictionary-other@example.com", password: "password123", confirmed_at: Time.zone.now)
      @arabic = languages(:arabic)
      @hebrew = languages(:hebrew)
      @spanish = languages(:spanish)
      @english = languages(:english)
      sign_in @user
    end

    def learn(language)
      @user.update!(preferences: @user.preferences.merge("target_language" => language.iso_name))
    end

    def ready_lookup(user: @user, **attributes)
      lookup = DictionaryLookup.new({
        user: user, query: "מנהיג", target_language: @arabic, native_language: @hebrew, status: :ready,
        illustration_status: :drawn, direction: "to_target", detected_language: "he", headword: "زعيم",
        transliteration: "zaʿīm", part_of_speech: "שם עצם", grammar_notes: [ "זכר" ],
        translation: "מנהיג", explanation: "מנהיג בעל השפעה.",
        examples: [ { "sentence" => "هو زعيم سياسي.", "highlight" => "زعيم", "translation" => "הוא מנהיג פוליטי." } ]
      }.merge(attributes))
      lookup.save!(validate: false)
      lookup
    end

    def save_word(language, text)
      phrase = @user.custom_phrases.create!(l1: language, text_l1: text)
      token = phrase.phrase_tokens.create!(l1_start_index: 0, l1_end_index: 1, index_type: :character_index)
      token.token_translations.create!(language: @english, translation: "w#{text}")
      @user.phrase_token_users.create!(phrase_token: token, language: @english)
    end

    # ----------------------------------------------------- target language

    test "a learner with no words and no videos is asked what they are learning" do
      get "/app/vocabulary", headers: NATIVE

      assert_response :success
      assert_select "[data-testid=dictionary-choose-language]"
      assert_select "[data-testid=dictionary-form]", false
      # The native language is not offered as something to learn.
      assert_select "input[type=radio][value=he]", false
      assert_select "input[type=radio][value='ar-JO']"
    end

    test "choosing a language saves it and opens the tab" do
      patch "/profile/target_language", params: { user: { target_language: "ar-JO" }, return_to: "/app/vocabulary" },
        headers: NATIVE

      assert_redirected_to "/app/vocabulary"
      assert_equal @arabic, @user.reload.target_language

      follow_redirect!(headers: NATIVE.dup)
      assert_select "[data-testid=dictionary-form]"
      assert_select "[data-testid=dictionary-languages]"
    end

    test "a learner with saved words gets the majority language without being asked" do
      save_word(@spanish, "el gato")
      save_word(@spanish, "la casa")
      save_word(languages(:french), "le chat")

      get "/app/vocabulary", headers: NATIVE

      assert_response :success
      assert_select "[data-testid=dictionary-form]"
      assert_equal @spanish, @user.reload.target_language
    end

    test "a target language equal to the native language is asked again" do
      learn(@hebrew)

      get "/app/vocabulary", headers: NATIVE

      assert_select "[data-testid=dictionary-choose-language]"
    end

    test "the web vocabulary list is not gated on a target language" do
      get "/vocabulary", headers: WEB

      assert_response :success
      assert_select "[data-testid=dictionary-choose-language]", false
    end

    test "profile rejects an unknown or native language and ignores foreign return paths" do
      patch "/profile/target_language", params: { user: { target_language: "he" }, return_to: "https://evil.example" },
        headers: NATIVE

      assert_redirected_to "/profile"
      assert_nil @user.reload.target_language
    end

    test "the profile page offers the target language on the web too" do
      get "/profile", headers: WEB

      assert_select "[data-testid=profile-target-language] select[name='user[target_language]'] option[value='']"
    end

    test "the profile page preselects a chosen target language on both surfaces" do
      learn(@arabic)

      [ WEB, NATIVE ].each do |headers|
        get "/profile", headers: headers

        assert_response :success
        assert_select "select[name='user[target_language]'] option[value='ar-JO'][selected=selected]"
      end

      # The native app speaks Hebrew to this user (their preference), so it is
      # not offered as something to learn. The web speaks the subdomain's
      # language instead and follows its own rule.
      get "/profile", headers: NATIVE
      assert_select "select[name='user[target_language]'] option[value=he]", false
    end

    test "profile edits the dictionary instructions for the current target language" do
      learn(@arabic)

      get "/profile", headers: NATIVE
      assert_select "[data-testid=profile-dictionary-instructions] input[name='user[language]'][value='ar-JO']"

      patch "/profile/dictionary_instructions",
        params: { user: { language: "ar-JO", dictionary_instructions: "Palestinian colloquial, not MSA" } }, headers: NATIVE

      assert_redirected_to "/profile"
      assert_equal "Palestinian colloquial, not MSA", @user.reload.dictionary_instructions(@arabic)
    end

    test "profile offers no dictionary instructions before a target language exists" do
      get "/profile", headers: NATIVE

      assert_select "[data-testid=profile-dictionary-instructions]", false
    end

    # ------------------------------------------------------------ lookups

    test "looking something up creates a lookup, queues its generation and opens it" do
      learn(@arabic)

      assert_enqueued_with(job: GenerateDictionaryEntryJob) do
        post "/app/vocabulary/lookups", params: { query: "  מנהיג  " }, headers: NATIVE
      end

      lookup = @user.dictionary_lookups.last
      assert_redirected_to "/app/vocabulary/lookups/#{lookup.id}"
      assert_equal [ "מנהיג", @arabic, @hebrew ], [ lookup.query, lookup.target_language, lookup.native_language ]
    end

    test "an empty lookup or a missing target language goes back to the tab" do
      learn(@arabic)
      assert_no_difference -> { DictionaryLookup.count } do
        post "/app/vocabulary/lookups", params: { query: "   " }, headers: NATIVE
      end
      assert_redirected_to "/app/vocabulary"

      @user.update!(preferences: { "native_language" => "he" })
      assert_no_difference -> { DictionaryLookup.count } do
        post "/app/vocabulary/lookups", params: { query: "x" }, headers: NATIVE
      end
    end

    test "a card being written polls and shows its skeleton" do
      lookup = ready_lookup(status: :generating, illustration_status: :drawing)

      get "/app/vocabulary/lookups/#{lookup.id}", headers: NATIVE

      assert_response :success
      assert_select "[data-controller=dictionary-card][data-state=generating][data-dictionary-card-pending-value=true]"
    end

    test "a ready card shows the word, its meaning, explanation and examples, and stops polling" do
      lookup = ready_lookup
      lookup.pronunciation.attach(io: StringIO.new("mp3"), filename: "a.mp3", content_type: "audio/mpeg")

      get "/app/vocabulary/lookups/#{lookup.id}/card", headers: NATIVE

      assert_response :success
      assert_select "[data-controller=dictionary-card][data-state=ready][data-dictionary-card-pending-value=false]"
      assert_select "[data-testid=dictionary-headword][lang='ar-JO'][dir=rtl]", text: "زعيم"
      assert_select "[data-testid=dictionary-translation]", text: "מנהיג"
      assert_select "[data-testid=dictionary-explanation]", text: /מנהיג בעל השפעה/
      assert_select "[data-testid=dictionary-examples] mark", text: "زعيم"
      assert_select "[data-testid=dictionary-save]"
      assert_select "audio[data-dictionary-card-target=audio]"
    end

    test "a lost generation is shown as failed with a retry" do
      lookup = ready_lookup(status: :generating, created_at: 10.minutes.ago)

      get "/app/vocabulary/lookups/#{lookup.id}", headers: NATIVE

      assert_select "[data-testid=dictionary-failed]"
      assert_select "[data-dictionary-card-pending-value=false]"
    end

    test "saving adds the word, returns to the tab and marks it new with an undo" do
      learn(@arabic)
      lookup = ready_lookup

      post "/app/vocabulary/lookups/#{lookup.id}/save", headers: NATIVE

      assert_redirected_to "/app/vocabulary"
      entry = @user.phrase_token_users.last
      assert_equal "زعيم", entry.word

      follow_redirect!(headers: NATIVE.dup)
      assert_select "[data-testid=vocabulary-entry]", 1
      assert_select "[data-testid=vocabulary-entry-new]"
      assert_select "[data-testid=dictionary-undo]"
    end

    test "undoing a save removes the word without offering to restore it" do
      learn(@arabic)
      entry = ready_lookup.save_to_vocabulary!

      delete "/app/vocabulary/#{entry.id}", params: { undo_save: 1 }, headers: NATIVE

      assert_redirected_to "/app/vocabulary"
      assert_not PhraseTokenUser.exists?(entry.id)
      assert_nil flash[:undo]
    end

    test "a saved card says so instead of offering to save again" do
      lookup = ready_lookup
      lookup.save_to_vocabulary!

      get "/app/vocabulary/lookups/#{lookup.id}", headers: NATIVE

      assert_select "[data-testid=dictionary-saved]"
      assert_select "[data-testid=dictionary-save]", false
    end

    test "regenerating the illustration queues a new drawing" do
      lookup = ready_lookup

      assert_enqueued_with(job: IllustrateDictionaryEntryJob, args: [ lookup.id ]) do
        post "/app/vocabulary/lookups/#{lookup.id}/illustrate", headers: NATIVE
      end
      assert lookup.reload.illustration_drawing?
    end

    test "another user's lookup is not reachable" do
      lookup = ready_lookup(user: @other, native_language: @english)

      get "/app/vocabulary/lookups/#{lookup.id}", headers: NATIVE
      assert_not response.successful?, "another user's lookup must never render"

      post "/app/vocabulary/lookups/#{lookup.id}/save", headers: NATIVE
      assert_empty @user.phrase_token_users
      assert_empty @other.phrase_token_users
    end

    test "the dictionary is native-only" do
      lookup = ready_lookup

      get "/app/vocabulary/lookups/#{lookup.id}", headers: WEB
      assert_redirected_to root_path
    end
  end
end
