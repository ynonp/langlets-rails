require "test_helper"

class ReviewLessonBuilderTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )

    @english = languages(:english)
    @spanish = languages(:spanish)
    @hebrew = languages(:hebrew)
    @arabic = languages(:arabic)

    @medium = Medium.create!(
      url: "https://www.youtube.com/watch?v=test123",
      language: @english
    )

    @phrase_en = create_translated_phrase!(
      medium: @medium,
      l1: @english,
      l2: @spanish,
      text_l1: "Hello world",
      text_l2: "Hola mundo",
      timestamp: "00:01:30"
    )

    @phrase_ar = create_translated_phrase!(
      medium: @medium,
      l1: @arabic,
      l2: @english,
      text_l1: "مرحبا بالعالم",
      text_l2: "Hello world",
      timestamp: "00:02:00"
    )

    @phrase_he = create_translated_phrase!(
      medium: @medium,
      l1: @hebrew,
      l2: @english,
      text_l1: "שלום עולם",
      text_l2: "Hello world",
      timestamp: "00:03:00"
    )

    @token_en1 = create_translated_token!(
      phrase: @phrase_en,
      l1_start_index: 0,
      l1_end_index: 4,
      index_type: :character_index,
      translation: "Hola"
    )

    @token_en2 = create_translated_token!(
      phrase: @phrase_en,
      l1_start_index: 6,
      l1_end_index: 10,
      index_type: :character_index,
      translation: "Mundo"
    )

    @token_ar1 = create_translated_token!(
      phrase: @phrase_ar,
      l1_start_index: 0,
      l1_end_index: 4,
      index_type: :character_index,
      translation: "Hi"
    )

    @token_ar2 = create_translated_token!(
      phrase: @phrase_ar,
      l1_start_index: 6,
      l1_end_index: 10,
      index_type: :character_index,
      translation: "World"
    )

    @token_he = create_translated_token!(
      phrase: @phrase_he,
      l1_start_index: 0,
      l1_end_index: 4,
      index_type: :character_index,
      translation: "Hi"
    )
  end

  test "copied saved words do not crowd useful words out of a review" do
    11.times do |index|
      PhraseTokenUser.create_custom!(user: @user, sentence: "copy#{index}", language: @english,
        token_range: 0..0, translation: "copy#{index}", translation_language: @spanish)
    end
    @user.saved_phrase_tokens << @token_en1

    assert_equal [@token_en1.id], ReviewLessonBuilder.new(@user, language_code: "en").fetch_tokens.map(&:id)
    assert_nil @user.phrase_token_users.order(:id).first.translation
  end

  test "build! creates lesson without language filter" do
    @user.saved_phrase_tokens << @token_en1

    builder = ReviewLessonBuilder.new(@user)
    lesson = builder.build!

    assert_instance_of Lesson, lesson
    assert_equal "Review Words", lesson.name
    assert_equal @user, lesson.user
    assert_nil lesson.course
  end

  test "due words are selected before future reviews and optional practice preserves access" do
    @user.saved_phrase_tokens << @token_en1
    @user.saved_phrase_tokens << @token_en2
    first = @user.phrase_token_users.find_by!(phrase_token: @token_en1)
    first.set_familiarity!("mastered")

    builder = ReviewLessonBuilder.new(@user, language_code: "en")
    assert_equal [ @token_en2 ], builder.fetch_tokens
    assert_equal 1, @user.daily_vocab_review_due_count("en")

    @user.phrase_token_users.find_by!(phrase_token: @token_en2).set_familiarity!("familiar")
    assert_equal 2, builder.fetch_tokens.size
    assert_equal 0, @user.daily_vocab_review_due_count("en")
    assert_not @user.daily_vocab_review_available?("en")
  end

  test "a review caps its pool at ten and checks recall for every selected word" do
    12.times do |index|
      PhraseTokenUser.create_custom!(user: @user, sentence: "word#{index}", language: @english,
        token_range: 0..0, translation: "meaning#{index}", translation_language: @spanish)
    end
    lesson = ReviewLessonBuilder.new(@user, language_code: "en").build!
    all_ids = lesson.activities.flat_map { |activity| activity.phrase_token_ids }.uniq.sort
    recall_ids = lesson.activities.find_by!(type: "Activities::WriteMissingWordActivity").phrase_token_ids.sort
    assert_equal 10, all_ids.size
    assert_equal all_ids, recall_ids
  end

  test "opening a prebuilt review refreshes its selection when words become due" do
    @user.saved_phrase_tokens << @token_en1
    @user.saved_phrase_tokens << @token_en2
    @user.phrase_token_users.find_by!(phrase_token: @token_en1).set_familiarity!("learning")
    @user.phrase_token_users.find_by!(phrase_token: @token_en2).set_familiarity!("mastered")
    pending = @user.current_review_lesson("en")

    travel_to(2.days.from_now) do
      current = @user.current_review_lesson("en")
      assert_not_equal pending.id, current.id
      assert pending.reload.review_expired?
      assert_equal [ @token_en1.id ], current.activities.flat_map(&:phrase_token_ids).uniq
    end
  end

  test "build! creates lesson with language code in name" do
    @user.saved_phrase_tokens << @token_en1

    builder = ReviewLessonBuilder.new(@user, language_code: "en")
    lesson = builder.build!

    assert_equal "Review Words (en)", lesson.name
  end

  test "build! includes all tokens when no language specified" do
    @user.saved_phrase_tokens << @token_en1
    @user.saved_phrase_tokens << @token_ar1
    @user.saved_phrase_tokens << @token_he

    builder = ReviewLessonBuilder.new(@user)
    lesson = builder.build!

    all_tokens_in_lesson = lesson.activities.flat_map(&:phrase_tokens)

    assert_includes all_tokens_in_lesson, @token_en1
    assert_includes all_tokens_in_lesson, @token_ar1
    assert_includes all_tokens_in_lesson, @token_he
  end

  test "build! filters tokens by language when language_code provided" do
    @user.saved_phrase_tokens << @token_en1
    @user.saved_phrase_tokens << @token_en2
    @user.saved_phrase_tokens << @token_ar1
    @user.saved_phrase_tokens << @token_ar2
    @user.saved_phrase_tokens << @token_he

    builder = ReviewLessonBuilder.new(@user, language_code: @arabic.iso_name)
    lesson = builder.build!

    all_tokens_in_lesson = lesson.activities.flat_map(&:phrase_tokens)

    assert_includes all_tokens_in_lesson, @token_ar1
    assert_includes all_tokens_in_lesson, @token_ar2
    assert_not_includes all_tokens_in_lesson, @token_en1
    assert_not_includes all_tokens_in_lesson, @token_en2
    assert_not_includes all_tokens_in_lesson, @token_he
  end

  test "build! filters correctly by L1 language" do
    @user.saved_phrase_tokens << @token_en1
    @user.saved_phrase_tokens << @token_ar1

    builder_en = ReviewLessonBuilder.new(@user, language_code: @english.iso_name)
    lesson_en = builder_en.build!

    tokens_en = lesson_en.activities.flat_map(&:phrase_tokens)

    assert_includes tokens_en, @token_en1
    assert_not_includes tokens_en, @token_ar1

    builder_ar = ReviewLessonBuilder.new(@user, language_code: @arabic.iso_name)
    lesson_ar = builder_ar.build!

    tokens_ar = lesson_ar.activities.flat_map(&:phrase_tokens)

    assert_includes tokens_ar, @token_ar1
    assert_not_includes tokens_ar, @token_en1
  end

  test "build! creates lesson with no tokens when language has no saved words" do
    @user.saved_phrase_tokens << @token_en1

    builder = ReviewLessonBuilder.new(@user, language_code: @hebrew.iso_name)
    lesson = builder.build!

    all_tokens_in_lesson = lesson.activities.flat_map(&:phrase_tokens)

    assert_empty all_tokens_in_lesson
  end

  test "build! creates multiple tokens from same language" do
    @user.saved_phrase_tokens << @token_en1
    @user.saved_phrase_tokens << @token_en2

    builder = ReviewLessonBuilder.new(@user, language_code: @english.iso_name)
    lesson = builder.build!

    all_tokens_in_lesson = lesson.activities.flat_map(&:phrase_tokens)

    assert_includes all_tokens_in_lesson, @token_en1
    assert_includes all_tokens_in_lesson, @token_en2
    assert_equal 2, all_tokens_in_lesson.count
  end

  test "review activities fall back to the saved translation after the preferred language changes" do
    @user.phrase_token_users.create!(phrase_token: @token_ar1, language: @english)

    Current.set(translation_language: @hebrew) do
      lesson = ReviewLessonBuilder.new(@user, language_code: @arabic.iso_name).build!
      activity = lesson.activities.find_by!(type: "Activities::WriteMissingWordActivity")
      params = activity.reload.activity_params
      card = ApplicationController.helpers.prepare_flashcards_for_tokens(params.fetch(:phrase_tokens), params.fetch(:unique_words)).first

      assert_equal "Hi", card.fetch(:translation)
      assert_equal "Hello world", card.fetch(:phrase_l2)
      assert_equal @medium.extract_video_id, card.fetch(:video_id)
      assert card.fetch(:options).include?(card.fetch(:correct))
      assert_equal @english, params.fetch(:l2)
    end
  end

  test "review activities prefer the current language when that translation is available" do
    @user.phrase_token_users.create!(phrase_token: @token_ar1, language: @english)
    @phrase_ar.phrase_translations.create!(language: @hebrew, text: "שלום עולם")
    @token_ar1.token_translations.create!(language: @hebrew, translation: "שלום")

    Current.set(translation_language: @hebrew) do
      lesson = ReviewLessonBuilder.new(@user, language_code: @arabic.iso_name).build!
      activity = lesson.activities.find_by!(type: "Activities::WriteMissingWordActivity")
      params = activity.reload.activity_params
      card = ApplicationController.helpers.prepare_flashcards_for_tokens(params.fetch(:phrase_tokens), params.fetch(:unique_words)).first

      assert_equal "שלום", card.fetch(:translation)
      assert_equal "שלום עולם", card.fetch(:phrase_l2)
      assert_equal @hebrew, params.fetch(:l2)
    end
  end

  # "Stop practising" in the Vocabulary tab. The word stays saved — it is still
  # listed and editable there — but it must not turn up in a review again.
  test "a paused word is kept in the vocabulary but left out of the review" do
    @user.saved_phrase_tokens << @token_en1
    @user.saved_phrase_tokens << @token_en2
    @user.phrase_token_users.find_by(phrase_token: @token_en2).update!(practicing: false)

    tokens = ReviewLessonBuilder.new(@user, language_code: @english.iso_name).fetch_tokens

    assert_equal [ @token_en1 ], tokens
    assert_equal 2, @user.phrase_token_users.count, "the paused word must stay saved"
  end

  test "resuming practice puts the word back into the review" do
    @user.saved_phrase_tokens << @token_en1
    saved = @user.phrase_token_users.find_by(phrase_token: @token_en1)
    saved.update!(practicing: false)

    assert_empty ReviewLessonBuilder.new(@user, language_code: @english.iso_name).fetch_tokens

    saved.update!(practicing: true)

    assert_equal [ @token_en1 ], ReviewLessonBuilder.new(@user, language_code: @english.iso_name).fetch_tokens
  end

  # The daily review offer reads the same flag, so a language whose words are
  # all paused stops being offered rather than building an empty lesson.
  test "a language with only paused words is no longer offered a daily review" do
    @user.saved_phrase_tokens << @token_en1

    assert_includes @user.languages_with_saved_words, @english
    assert @user.daily_vocab_review_available?(@english.iso_name)

    @user.phrase_token_users.find_by(phrase_token: @token_en1).update!(practicing: false)

    assert_not_includes @user.reload.languages_with_saved_words, @english
    assert_not @user.daily_vocab_review_available?(@english.iso_name)
  end
end
