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

  test "build! creates lesson without language filter" do
    @user.saved_phrase_tokens << @token_en1

    builder = ReviewLessonBuilder.new(@user)
    lesson = builder.build!

    assert_instance_of Lesson, lesson
    assert_equal "Review Words", lesson.name
    assert_equal @user, lesson.user
    assert_nil lesson.course
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

      assert_equal "Hi", params.fetch(:cards).first.fetch(:translation)
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

      assert_equal "שלום", params.fetch(:cards).first.fetch(:translation)
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
